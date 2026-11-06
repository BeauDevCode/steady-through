"""Simulator selection fixtures; no test invokes real simulator commands."""

import importlib.util
import json
import os
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

    def toolchain(self, directory, device_hub=False):
        contents = Path(directory) / "Selected Xcode.app" / "Contents"
        developer = contents / "Developer"
        simctl = developer / "usr" / "bin" / "simctl"
        gui = (contents if device_hub else developer) / "Applications" / ("DeviceHub.app" if device_hub else "Simulator.app")
        gui.mkdir(parents=True)
        return simctl, gui

    def expected_commands(self, simctl, gui, state="Shutdown"):
        commands = [["xcrun", "--find", "simctl"]]
        if state != "Booted":
            commands.append(["xcrun", "simctl", "boot", PHONE_ID])
        commands.extend([
            ["xcrun", "simctl", "bootstatus", PHONE_ID, "-b"],
            ["open", "-n", "-a", str(gui), "--args", "-CurrentDeviceUDID", PHONE_ID],
            ["open", "-a", str(gui), "--args", "-CurrentDeviceUDID", PHONE_ID],
        ])
        return commands

    def test_boots_shutdown_device_waits_and_exports_only_validated_udid(self):
        with tempfile.TemporaryDirectory() as directory:
            env = Path(directory) / "environment"
            simctl, gui = self.toolchain(directory)
            with patch.object(self.helper.subprocess, "run") as run:
                run.return_value.stdout = str(simctl) + "\n"
                self.helper.boot_and_export(device(), env)
            self.assertEqual([call.args[0] for call in run.call_args_list], self.expected_commands(simctl, gui))
            self.assertTrue(all(call.kwargs["check"] for call in run.call_args_list))
            self.assertTrue(all(0 < call.kwargs["timeout"] <= 600 for call in run.call_args_list))
            self.assertTrue(all(not call.kwargs.get("shell", False) for call in run.call_args_list))
            self.assertEqual(env.read_text(), f"STEADY_IOS_SIMULATOR_ID={PHONE_ID}\n")

    def test_booted_device_still_waits_for_ready(self):
        with tempfile.TemporaryDirectory() as directory:
            env = Path(directory) / "environment"
            simctl, gui = self.toolchain(directory)
            with patch.object(self.helper.subprocess, "run") as run:
                run.return_value.stdout = str(simctl) + "\n"
                self.helper.boot_and_export(device(state="Booted"), env)
            self.assertEqual([call.args[0] for call in run.call_args_list], self.expected_commands(simctl, gui, state="Booted"))

    def test_uses_device_hub_when_selected_xcode_has_it(self):
        with tempfile.TemporaryDirectory() as directory:
            env = Path(directory) / "environment"
            simctl, gui = self.toolchain(directory, device_hub=True)
            # Flutter prefers DeviceHub when both are present.
            self.toolchain(directory)
            with patch.object(self.helper.subprocess, "run") as run:
                run.return_value.stdout = str(simctl) + "\n"
                self.helper.boot_and_export(device(), env)
            self.assertEqual([call.args[0] for call in run.call_args_list], self.expected_commands(simctl, gui))

    def test_missing_gui_for_selected_xcode_fails_before_boot_or_export(self):
        with tempfile.TemporaryDirectory() as directory:
            env = Path(directory) / "environment"
            simctl = Path(directory) / "Selected Xcode.app/Contents/Developer/usr/bin/simctl"
            with patch.object(self.helper.subprocess, "run") as run:
                run.return_value.stdout = str(simctl) + "\n"
                with self.assertRaisesRegex(ValueError, "Simulator|DeviceHub"):
                    self.helper.boot_and_export(device(), env)
            self.assertEqual([call.args[0] for call in run.call_args_list], [["xcrun", "--find", "simctl"]])
            self.assertFalse(env.exists())

    def test_invalid_tool_path_fails_before_boot_or_export(self):
        for tool_path in ("simctl", "/usr/bin/not-simctl", "\n", "/usr/bin/simctl\nINJECTED=value"):
            with self.subTest(tool_path=tool_path), tempfile.TemporaryDirectory() as directory:
                env = Path(directory) / "environment"
                with patch.object(self.helper.subprocess, "run") as run:
                    run.return_value.stdout = tool_path
                    with self.assertRaises(ValueError):
                        self.helper.boot_and_export(device(), env)
                self.assertEqual(run.call_count, 1)
                self.assertFalse(env.exists())

    def test_xcrun_inherits_selected_developer_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            simctl, gui = self.toolchain(directory)
            selected = str(simctl.parents[2])
            with patch.dict(os.environ, {"DEVELOPER_DIR": selected}), patch.object(self.helper.subprocess, "run") as run:
                run.return_value.stdout = str(simctl) + "\n"
                self.helper.boot_and_export(device(), Path(directory) / "environment")
                self.assertEqual(os.environ["DEVELOPER_DIR"], selected)
            self.assertNotIn("env", run.call_args_list[0].kwargs)
            self.assertEqual(run.call_args_list[0].args[0], ["xcrun", "--find", "simctl"])

    def test_gui_failure_or_timeout_never_exports_device(self):
        for command_index in (3, 4):
            for error in (subprocess.CalledProcessError(1, "fake open"), subprocess.TimeoutExpired("fake open", 30)):
                with self.subTest(command_index=command_index, error=error), tempfile.TemporaryDirectory() as directory:
                    env = Path(directory) / "environment"
                    simctl, gui = self.toolchain(directory)
                    completed = subprocess.CompletedProcess(["fixture"], 0, stdout=str(simctl) + "\n")
                    with patch.object(self.helper.subprocess, "run", side_effect=[completed] * command_index + [error]) as run:
                        with self.assertRaises(type(error)):
                            self.helper.boot_and_export(device(), env)
                    self.assertEqual(run.call_count, command_index + 1)
                    self.assertFalse(env.exists())

    def test_invalid_uuid_never_reaches_any_external_command(self):
        with tempfile.TemporaryDirectory() as directory:
            env = Path(directory) / "environment"
            with patch.object(self.helper.subprocess, "run") as run:
                with self.assertRaises(ValueError):
                    self.helper.boot_and_export(device(PHONE_ID + "\nEVIL=value"), env)
            run.assert_not_called()
            self.assertFalse(env.exists())

    def test_foregrounds_real_gui_without_synthetic_lifecycle_commands(self):
        with tempfile.TemporaryDirectory() as directory:
            simctl, gui = self.toolchain(directory)
            with patch.object(self.helper.subprocess, "run") as run:
                run.return_value.stdout = str(simctl) + "\n"
                self.helper.boot_and_export(device(), Path(directory) / "environment")
            commands = [call.args[0] for call in run.call_args_list]
            self.assertEqual(commands[-2:], self.expected_commands(simctl, gui)[-2:])
            self.assertFalse(any("resumed" in argument or "lifecycle" in argument for command in commands for argument in command))

    def test_boot_failure_or_timeout_never_exports_device(self):
        for command_index in (0, 1, 2):
            for error in (subprocess.CalledProcessError(1, "fake boot"), subprocess.TimeoutExpired("fake boot", 600)):
                with self.subTest(command_index=command_index, error=error), tempfile.TemporaryDirectory() as directory:
                    env = Path(directory) / "environment"
                    simctl, gui = self.toolchain(directory)
                    completed = subprocess.CompletedProcess(["fixture"], 0, stdout=str(simctl) + "\n")
                    with patch.object(self.helper.subprocess, "run", side_effect=[completed] * command_index + [error]) as run:
                        with self.assertRaises(type(error)):
                            self.helper.boot_and_export(device(), env)
                    self.assertEqual(run.call_count, command_index + 1)
                    self.assertFalse(env.exists())


if __name__ == "__main__":
    unittest.main()
