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

# Captured terminal failure from run 42163816733's native-ios-simulator.log;
# only the device UUID is replaced with the fixture UUID. A zero process exit
# did not prevent this failed migration from being exported as "Ready".
# CoreSimulator enum distinguishes DataMigrationFailed=3 from Finished=4294967295:
# https://github.com/meta/idb/blob/main/PrivateHeaders/CoreSimulator/SimDeviceBootInfo.h#L8-L15
BOOTSTATUS_MIGRATION_FAILED = f"""Monitoring boot status for iPhone Air ({PHONE_ID}).
[2026-11-06 04:48:58 +0000] Status=2, isTerminal=NO, Elapsed=01:19.
\tWaiting on Data Migration
\t\tReason:Running plugin com.apple.MobileSafari.migrator (MobileSafari.migrator)
\t\tMigration Elapsed:01:06 seconds

[2026-11-06 04:49:01 +0000] Status=3, isTerminal=YES, Elapsed=01:22.
\tData Migration Failed
"""

# Positive protocol fixture: Finished is a different terminal state, rather
# than assuming that every isTerminal=YES or zero process exit means success.
BOOTSTATUS_FINISHED = f"""Monitoring boot status for iPhone Air ({PHONE_ID}).
[2026-11-06 04:48:58 +0000] Status=4, isTerminal=NO, Elapsed=01:19.
\tWaiting on System App

[2026-11-06 04:49:01 +0000] Status=4294967295, isTerminal=YES, Elapsed=01:22.
\tFinished
"""


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

    def command_result(self, simctl, command, boot_output=BOOTSTATUS_FINISHED, fresh_inventory=None):
        output = ""
        if command == ["xcrun", "--find", "simctl"]:
            output = str(simctl) + "\n"
        elif command == ["xcrun", "simctl", "bootstatus", PHONE_ID, "-b"]:
            output = boot_output
        elif command == ["xcrun", "simctl", "list", "devices", "available", "--json"]:
            output = json.dumps(fresh_inventory if fresh_inventory is not None else inventory(device(state="Booted")))
        return subprocess.CompletedProcess(command, 0, stdout=output, stderr="")

    def test_boots_shutdown_device_waits_and_exports_only_validated_udid(self):
        with tempfile.TemporaryDirectory() as directory:
            env = Path(directory) / "environment"
            simctl, gui = self.toolchain(directory)
            with patch.object(self.helper.subprocess, "run") as run:
                run.side_effect = lambda command, **kwargs: self.command_result(simctl, command)
                self.helper.boot_and_export(device(), env)
            self.assertEqual([call.args[0] for call in run.call_args_list], self.expected_commands(simctl, gui))
            self.assertTrue(all(call.kwargs["check"] for call in run.call_args_list))
            self.assertTrue(all(0 < call.kwargs["timeout"] <= 600 for call in run.call_args_list))
            self.assertTrue(all(not call.kwargs.get("shell", False) for call in run.call_args_list))
            self.assertEqual(env.read_text(), f"STEADY_IOS_SIMULATOR_ID={PHONE_ID}\n")

    def test_zero_exit_data_migration_failed_stops_before_gui_or_readiness_export(self):
        with tempfile.TemporaryDirectory() as directory:
            env = Path(directory) / "environment"
            simctl, gui = self.toolchain(directory)

            def fixture_run(command, **kwargs):
                output = ""
                if command == ["xcrun", "--find", "simctl"]:
                    output = str(simctl) + "\n"
                elif command == ["xcrun", "simctl", "bootstatus", PHONE_ID, "-b"]:
                    output = BOOTSTATUS_MIGRATION_FAILED
                return subprocess.CompletedProcess(command, 0, stdout=output, stderr="")

            with patch.object(self.helper.subprocess, "run", side_effect=fixture_run) as run:
                with self.assertRaises(ValueError):
                    self.helper.boot_and_export(device(), env)
            self.assertEqual([call.args[0] for call in run.call_args_list], self.expected_commands(simctl, gui)[:3])
            self.assertFalse(env.exists(), "A failed native migration must never export readiness")
            self.assertEqual((Path(directory) / "native-ios-bootstatus.log").read_text(), BOOTSTATUS_MIGRATION_FAILED)
            self.assertEqual(run.call_args_list[2].kwargs["stderr"], subprocess.STDOUT)
            self.assertEqual(run.call_args_list[2].kwargs["stdout"], subprocess.PIPE)

    def test_zero_exit_finished_allows_gui_and_readiness_export(self):
        with tempfile.TemporaryDirectory() as directory:
            env = Path(directory) / "environment"
            simctl, gui = self.toolchain(directory)

            def fixture_run(command, **kwargs):
                output = ""
                if command == ["xcrun", "--find", "simctl"]:
                    output = str(simctl) + "\n"
                elif command == ["xcrun", "simctl", "bootstatus", PHONE_ID, "-b"]:
                    output = BOOTSTATUS_FINISHED
                return subprocess.CompletedProcess(command, 0, stdout=output, stderr="")

            with patch.object(self.helper.subprocess, "run", side_effect=fixture_run) as run:
                self.helper.boot_and_export(device(), env)
            self.assertEqual([call.args[0] for call in run.call_args_list], self.expected_commands(simctl, gui))
            self.assertEqual(env.read_text(), f"STEADY_IOS_SIMULATOR_ID={PHONE_ID}\n")
            self.assertEqual((Path(directory) / "native-ios-bootstatus.log").read_text(), BOOTSTATUS_FINISHED)

    def test_already_booted_response_requires_fresh_available_booted_matching_uuid(self):
        with tempfile.TemporaryDirectory() as directory:
            env = Path(directory) / "environment"
            simctl, gui = self.toolchain(directory)
            with patch.object(self.helper.subprocess, "run", side_effect=lambda command, **kwargs: self.command_result(
                    simctl, command, boot_output="Device already booted, nothing to do.\n")) as run:
                self.helper.boot_and_export(device(state="Booted"), env)
            commands = [call.args[0] for call in run.call_args_list]
            self.assertEqual(commands, self.expected_commands(simctl, gui, state="Booted")[:2] + [
                ["xcrun", "simctl", "list", "devices", "available", "--json"],
            ] + self.expected_commands(simctl, gui, state="Booted")[2:])
            self.assertEqual(env.read_text(), f"STEADY_IOS_SIMULATOR_ID={PHONE_ID}\n")
            self.assertEqual(json.loads((Path(directory) / "native-ios-ready-devices.json").read_text()), inventory(device(state="Booted")))

    def test_already_booted_response_rejects_stale_missing_unavailable_or_other_uuid(self):
        snapshots = (
            inventory(device(state="Shutdown")),
            inventory(device(state="Booted", available=False)),
            inventory(device(BOOTED_ID, state="Booted")),
            {"devices": {}},
            {"devices": []},
        )
        for snapshot in snapshots:
            with self.subTest(snapshot=snapshot), tempfile.TemporaryDirectory() as directory:
                env = Path(directory) / "environment"
                simctl, gui = self.toolchain(directory)
                with patch.object(self.helper.subprocess, "run", side_effect=lambda command, **kwargs: self.command_result(
                        simctl, command, boot_output="Device already booted, nothing to do.\n", fresh_inventory=snapshot)) as run:
                    with self.assertRaises(ValueError):
                        self.helper.boot_and_export(device(state="Booted"), env)
                self.assertFalse(any(call.args[0][0] == "open" for call in run.call_args_list))
                self.assertFalse(env.exists())

    def test_unknown_or_incomplete_boot_output_never_exports_readiness(self):
        for output in ("", "Unknown boot response\n", "Status=2, isTerminal=NO\nWaiting on Data Migration\n",
                       "Status=7, isTerminal=YES\nUnknown terminal result\n", "Status=3, isTerminal=YES\n",
                       "Status=4294967295, isTerminal=YES\nData Migration Failed\n"):
            with self.subTest(output=output), tempfile.TemporaryDirectory() as directory:
                env = Path(directory) / "environment"
                simctl, gui = self.toolchain(directory)
                with patch.object(self.helper.subprocess, "run", side_effect=lambda command, **kwargs: self.command_result(
                        simctl, command, boot_output=output)) as run:
                    with self.assertRaises(ValueError):
                        self.helper.boot_and_export(device(), env)
                self.assertFalse(any(call.args[0][0] == "open" for call in run.call_args_list))
                self.assertFalse(env.exists())

    def test_bootstatus_subprocess_failure_retains_partial_combined_output(self):
        partial = "Status=2, isTerminal=NO\nWaiting on Data Migration\n"
        for error in (subprocess.CalledProcessError(1, "fixture bootstatus", output=partial),
                      subprocess.TimeoutExpired("fixture bootstatus", 600, output=partial.encode("utf-8"))):
            with self.subTest(error=error), tempfile.TemporaryDirectory() as directory:
                env = Path(directory) / "environment"
                simctl, gui = self.toolchain(directory)
                completed = [self.command_result(simctl, command) for command in self.expected_commands(simctl, gui)[:2]]
                with patch.object(self.helper.subprocess, "run", side_effect=completed + [error]) as run:
                    with self.assertRaises(type(error)):
                        self.helper.boot_and_export(device(), env)
                self.assertEqual((Path(directory) / "native-ios-bootstatus.log").read_text(), partial)
                self.assertEqual(run.call_count, 3)
                self.assertFalse(env.exists())

    def test_booted_device_still_waits_for_ready(self):
        with tempfile.TemporaryDirectory() as directory:
            env = Path(directory) / "environment"
            simctl, gui = self.toolchain(directory)
            with patch.object(self.helper.subprocess, "run") as run:
                run.side_effect = lambda command, **kwargs: self.command_result(simctl, command)
                self.helper.boot_and_export(device(state="Booted"), env)
            self.assertEqual([call.args[0] for call in run.call_args_list], self.expected_commands(simctl, gui, state="Booted"))

    def test_uses_device_hub_when_selected_xcode_has_it(self):
        with tempfile.TemporaryDirectory() as directory:
            env = Path(directory) / "environment"
            simctl, gui = self.toolchain(directory, device_hub=True)
            # Flutter prefers DeviceHub when both are present.
            self.toolchain(directory)
            with patch.object(self.helper.subprocess, "run") as run:
                run.side_effect = lambda command, **kwargs: self.command_result(simctl, command)
                self.helper.boot_and_export(device(), env)
            self.assertEqual([call.args[0] for call in run.call_args_list], self.expected_commands(simctl, gui))

    def test_missing_gui_for_selected_xcode_fails_before_boot_or_export(self):
        with tempfile.TemporaryDirectory() as directory:
            env = Path(directory) / "environment"
            simctl = Path(directory) / "Selected Xcode.app/Contents/Developer/usr/bin/simctl"
            with patch.object(self.helper.subprocess, "run") as run:
                run.side_effect = lambda command, **kwargs: self.command_result(simctl, command)
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
                run.side_effect = lambda command, **kwargs: self.command_result(simctl, command)
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
                    completed = [self.command_result(simctl, command) for command in self.expected_commands(simctl, gui)]
                    with patch.object(self.helper.subprocess, "run", side_effect=completed[:command_index] + [error]) as run:
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
                run.side_effect = lambda command, **kwargs: self.command_result(simctl, command)
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
                    completed = [self.command_result(simctl, command) for command in self.expected_commands(simctl, gui)]
                    with patch.object(self.helper.subprocess, "run", side_effect=completed[:command_index] + [error]) as run:
                        with self.assertRaises(type(error)):
                            self.helper.boot_and_export(device(), env)
                    self.assertEqual(run.call_count, command_index + 1)
                    self.assertFalse(env.exists())


if __name__ == "__main__":
    unittest.main()
