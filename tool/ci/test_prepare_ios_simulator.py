"""Simulator selection fixtures; no test invokes real simulator commands."""

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).with_name("prepare_ios_simulator.py")
PHONE_ID = "A1B2C3D4-1111-2222-3333-123456789ABC"
BOOTED_ID = "A1B2C3D4-1111-2222-3333-123456789DEF"


def device(udid=PHONE_ID, state="Shutdown", available=True, kind="iPhone-Future"):
    return {"udid": udid, "isAvailable": available, "state": state,
            "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType." + kind,
            "name": "A renamed simulator"}


def inventory(*devices):
    return {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-99-3": list(devices)}}


class SimulatorSelectionCliTest(unittest.TestCase):
    def select(self, data):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "devices.json"
            fixture.write_text(json.dumps(data), encoding="utf-8")
            return subprocess.run([sys.executable, str(SCRIPT), "--select-only", str(fixture)], capture_output=True, text=True, check=False)

    def test_selects_available_iphone_without_hardcoded_model_or_runtime(self):
        result = self.select(inventory(device()))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), PHONE_ID)

    def test_prefers_already_booted_iphone(self):
        result = self.select(inventory(device(), device(BOOTED_ID, state="Booted")))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), BOOTED_ID)

    def test_ignores_unavailable_devices_and_other_device_families(self):
        data = inventory(device(available=False), device(kind="iPad-Pro"), device(BOOTED_ID))
        data["devices"]["com.apple.CoreSimulator.SimRuntime.tvOS-99-0"] = [device()]
        result = self.select(data)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), BOOTED_ID)

    def test_rejects_absent_available_iphone(self):
        for data in ({"devices": {}}, inventory(device(available=False)), inventory(device(kind="iPad-Pro"))):
            with self.subTest(data=data):
                result = self.select(data)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Simulator preparation failed:", result.stderr)

    def test_rejects_malformed_inventory(self):
        for data in ([], {}, {"devices": []}, {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-99": {}}}):
            with self.subTest(data=data):
                self.assertNotEqual(self.select(data).returncode, 0)

    def test_rejects_malformed_or_injected_udid(self):
        for udid in ("$(touch /tmp/unwanted)", PHONE_ID + "\nEVIL=value", "not-a-uuid", None):
            with self.subTest(udid=udid):
                self.assertNotEqual(self.select(inventory(device(udid))).returncode, 0)

    def test_requires_boolean_availability_and_known_state(self):
        for change in ({"isAvailable": "true"}, {"isAvailable": 1}, {"state": "Creating"}):
            with self.subTest(change=change):
                phone = device()
                phone.update(change)
                self.assertNotEqual(self.select(inventory(phone)).returncode, 0)


class SimulatorBootTest(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location("simulator_helper", SCRIPT)
        self.helper = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.helper)

    def test_boots_shutdown_device_waits_and_exports_only_validated_udid(self):
        with tempfile.TemporaryDirectory() as directory:
            env = Path(directory) / "environment"
            with patch.object(self.helper.subprocess, "run") as run:
                self.helper.boot_and_export(device(), env)
            self.assertEqual([call.args[0] for call in run.call_args_list], [
                ["xcrun", "simctl", "boot", PHONE_ID],
                ["xcrun", "simctl", "bootstatus", PHONE_ID, "-b"],
            ])
            self.assertTrue(all(call.kwargs["check"] for call in run.call_args_list))
            self.assertTrue(all(0 < call.kwargs["timeout"] <= 600 for call in run.call_args_list))
            self.assertEqual(env.read_text(), f"STEADY_IOS_SIMULATOR_ID={PHONE_ID}\n")

    def test_booted_device_still_waits_for_ready(self):
        with tempfile.TemporaryDirectory() as directory:
            env = Path(directory) / "environment"
            with patch.object(self.helper.subprocess, "run") as run:
                self.helper.boot_and_export(device(state="Booted"), env)
            self.assertEqual(run.call_count, 1)
            self.assertEqual(run.call_args.args[0], ["xcrun", "simctl", "bootstatus", PHONE_ID, "-b"])

    def test_boot_failure_or_timeout_never_exports_device(self):
        for error in (subprocess.CalledProcessError(1, "fake boot"), subprocess.TimeoutExpired("fake boot", 600)):
            with self.subTest(error=error), tempfile.TemporaryDirectory() as directory:
                env = Path(directory) / "environment"
                with patch.object(self.helper.subprocess, "run", side_effect=error):
                    with self.assertRaises(type(error)):
                        self.helper.boot_and_export(device(), env)
                self.assertFalse(env.exists())


if __name__ == "__main__":
    unittest.main()
