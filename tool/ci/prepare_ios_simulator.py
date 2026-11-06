"""Select and boot an available iPhone simulator on CI, without fixed models.

JSON shape follows Flutter's SimControl fixtures:
https://github.com/flutter/flutter/blob/master/packages/flutter_tools/test/general.shard/ios/simulators_test.dart
Use --select-only FILE to inspect a saved inventory without executing OS tools.
"""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys


UDID_PATTERN = re.compile(r"[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}")


def validated_udid(device):
    udid = device.get("udid")
    if not isinstance(udid, str) or not UDID_PATTERN.fullmatch(udid):
        raise ValueError("selected simulator has no valid UUID")
    return udid


def preferred_runtime(runtime_matches, runtime_inventory):
    """Resolve the selected Xcode's exact available iOS runtime build.

    Preserve explicit overrides and support both current chosen/default keys
    and Flutter's legacy preferredBuild contract. Missing or ambiguous metadata
    fails closed instead of selecting an unrelated installed runtime.
    https://github.com/flutter/flutter/blob/3.47.9/dev/devicelab/lib/framework/ios.dart#L43-L113
    """
    if not isinstance(runtime_matches, dict):
        raise ValueError("selected-Xcode runtime matches must be an object")
    ios_matches = [value for key, value in runtime_matches.items() if "iphoneos" in key]
    if len(ios_matches) != 1 or not isinstance(ios_matches[0], dict):
        raise ValueError("selected Xcode must identify exactly one iPhoneOS runtime match")
    match = ios_matches[0]
    build_key = next((key for key in ("userOverriddenBuild", "chosenRuntimeBuild", "preferredBuild", "defaultBuild")
                      if key in match), "preferredBuild")
    build = match.get(build_key)
    if not isinstance(build, str) or not build or build.strip() != build:
        raise ValueError(f"selected Xcode has no valid {build_key} runtime build")
    if not isinstance(runtime_inventory, dict) or not isinstance(runtime_inventory.get("runtimes"), list):
        raise ValueError("simctl runtime inventory has no runtimes array")
    matches = []
    for runtime in runtime_inventory["runtimes"]:
        if not isinstance(runtime, dict) or not isinstance(runtime.get("identifier"), str):
            raise ValueError("simctl runtime has no valid identifier")
        identifier = runtime["identifier"]
        if not identifier.startswith("com.apple.CoreSimulator.SimRuntime.iOS-"):
            continue
        runtime_build = runtime.get("buildversion")
        if not isinstance(runtime_build, str) or not runtime_build:
            raise ValueError("simctl iOS runtime has no valid buildversion")
        if runtime_build == build and runtime.get("isAvailable") is True:
            matches.append(identifier)
    if len(matches) != 1:
        raise ValueError(f"selected Xcode runtime build {build} has {len(matches)} exact available iOS matches; expected one")
    return matches[0]


def select_device(inventory, runtime_identifier=None):
    if not isinstance(inventory, dict) or not isinstance(inventory.get("devices"), dict):
        raise ValueError("simctl inventory has no devices map")
    if runtime_identifier is not None and (not isinstance(runtime_identifier, str)
            or not runtime_identifier.startswith("com.apple.CoreSimulator.SimRuntime.iOS-")):
        raise ValueError("preferred runtime identifier must name an iOS runtime")
    candidates = []
    for runtime, devices in inventory["devices"].items():
        if not runtime.startswith("com.apple.CoreSimulator.SimRuntime.iOS-"):
            continue
        if runtime_identifier is not None and runtime != runtime_identifier:
            continue
        if not isinstance(devices, list):
            raise ValueError("simctl runtime devices must be an array")
        for device in devices:
            if not isinstance(device, dict):
                raise ValueError("simctl device must be an object")
            kind = device.get("deviceTypeIdentifier", "")
            if (device.get("isAvailable") is True
                    and isinstance(kind, str)
                    and kind.startswith("com.apple.CoreSimulator.SimDeviceType.iPhone-")
                    and device.get("state") in ("Booted", "Shutdown")):
                udid = validated_udid(device)
                candidates.append((device["state"] != "Booted", runtime, kind, udid, device))
    if not candidates:
        raise ValueError("no available iPhone simulator in an installed iOS runtime")
    return min(candidates, key=lambda item: item[:4])[4]


def selected_simulator_app():
    # xcrun resolves the selected Xcode and honors an inherited DEVELOPER_DIR.
    # Use its tool path instead of assuming a particular /Applications/Xcode*.
    result = subprocess.run(["xcrun", "--find", "simctl"], capture_output=True,
                            text=True, check=True, timeout=30)
    tool_path = result.stdout.strip()
    simctl = Path(tool_path)
    if (not simctl.is_absolute() or "\n" in tool_path or "\r" in tool_path
            or simctl.parts[-3:] != ("usr", "bin", "simctl")
            or simctl.parents[2].name != "Developer"):
        raise ValueError("xcrun returned an invalid selected-Xcode simctl path")
    developer = simctl.parents[2]
    # Match Flutter's Xcode.getSimulatorPath, including Xcode 27 DeviceHub.
    candidates = (
        developer.parent / "Applications" / "DeviceHub.app",
        developer / "Applications" / "Simulator.app",
    )
    for candidate in candidates:
        if candidate.is_dir():
            return candidate
    raise ValueError("selected Xcode has no Simulator.app or DeviceHub.app")


def confirm_already_booted(udid, evidence_directory):
    result = subprocess.run(["xcrun", "simctl", "list", "devices", "available", "--json"],
                            capture_output=True, text=True, check=True, timeout=60)
    (evidence_directory / "native-ios-ready-devices.json").write_text(result.stdout, encoding="utf-8")
    inventory = json.loads(result.stdout)
    if not isinstance(inventory, dict) or not isinstance(inventory.get("devices"), dict):
        raise ValueError("fresh simctl inventory has no devices map")
    matches = []
    for runtime, devices in inventory["devices"].items():
        if not runtime.startswith("com.apple.CoreSimulator.SimRuntime.iOS-"):
            continue
        if not isinstance(devices, list):
            raise ValueError("fresh simctl runtime devices must be an array")
        for device in devices:
            if not isinstance(device, dict):
                raise ValueError("fresh simctl device must be an object")
            if device.get("udid") == udid:
                validated_udid(device)
                matches.append(device)
    if (len(matches) != 1 or matches[0].get("isAvailable") is not True
            or matches[0].get("state") != "Booted"):
        raise ValueError("already-booted response was not confirmed by a fresh available Booted UUID")


def wait_for_successful_boot(udid, evidence_directory):
    output = ""
    try:
        result = subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, check=True, timeout=600)
        output = result.stdout or ""
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        output = error.output or ""
        raise
    finally:
        # TimeoutExpired may carry bytes even with text=True. Preserve evidence
        # before reporting either a subprocess error or a semantic boot failure.
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        (evidence_directory / "native-ios-bootstatus.log").write_text(output, encoding="utf-8")
        print(output, end="" if output.endswith("\n") else "\n", flush=True)
    statuses = re.findall(r"\bStatus=(\d+),\s*isTerminal=(YES|NO)\b", output)
    # CoreSimulator's terminal status 3 means DataMigrationFailed; simctl can
    # nevertheless exit zero. Finished is the distinct terminal value below.
    # https://github.com/meta/idb/blob/main/PrivateHeaders/CoreSimulator/SimDeviceBootInfo.h
    if any(status == "3" for status, _ in statuses) or "Data Migration Failed" in output:
        raise ValueError("simulator data migration failed despite bootstatus process completion")
    if statuses:
        if statuses[-1] == ("4294967295", "YES") and re.search(r"^\s*Finished\s*$", output, re.MULTILINE):
            return
        raise ValueError("bootstatus did not report a successful terminal Finished state")
    already_booted = "Device already booted, nothing to do."
    response_lines = output.strip().splitlines()
    if (response_lines == [already_booted]
            or (len(response_lines) == 2 and response_lines[1] == already_booted
                and re.fullmatch(rf"Monitoring boot status for [^\r\n]+ \({re.escape(udid)}\)\.", response_lines[0]))):
        confirm_already_booted(udid, evidence_directory)
        return
    raise ValueError("bootstatus returned no recognized successful readiness response")


def boot_and_export(device, environment_file, evidence_directory=None):
    udid = validated_udid(device)
    evidence_directory = Path(evidence_directory) if evidence_directory is not None else Path(environment_file).parent
    evidence_directory.mkdir(parents=True, exist_ok=True)
    simulator_app = selected_simulator_app()
    if device.get("state") != "Booted":
        subprocess.run(["xcrun", "simctl", "boot", udid], check=True, timeout=120)
    wait_for_successful_boot(udid, evidence_directory)
    # Match Flutter IOSEmulator.launch: -n starts the GUI, then a second open
    # without -n brings it to the foreground. Keep the selected device explicit.
    # A headless CoreSimulator boot does not establish foreground UI readiness.
    for options in (("-n",), ()):
        subprocess.run(["open", *options, "-a", str(simulator_app), "--args",
                        "-CurrentDeviceUDID", udid], check=True, timeout=30)
    # Only a regex-validated UUID reaches GITHUB_ENV. No simulator label or JSON
    # string is ever interpolated into a shell command or workflow expression.
    with Path(environment_file).open("a", encoding="utf-8") as destination:
        destination.write(f"STEADY_IOS_SIMULATOR_ID={udid}\n")
    print(f"Ready iPhone simulator: {udid}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--select-only", type=Path, metavar="FILE")
    parser.add_argument("--evidence-directory", type=Path, default=Path("build"))
    arguments = parser.parse_args()
    try:
        if arguments.select_only:
            device = select_device(json.loads(arguments.select_only.read_text(encoding="utf-8")))
            print(validated_udid(device))
            return 0
        environment_file = os.environ.get("GITHUB_ENV")
        if not environment_file:
            raise ValueError("GITHUB_ENV is required for CI simulator preparation")
        arguments.evidence_directory.mkdir(parents=True, exist_ok=True)
        inventories = []
        for command, filename in (
                (["xcrun", "simctl", "runtime", "match", "list", "--json"], "native-ios-runtime-matches.json"),
                (["xcrun", "simctl", "list", "runtimes", "--json"], "native-ios-runtimes.json"),
                (["xcrun", "simctl", "list", "devices", "available", "--json"], "native-ios-devices.json")):
            result = subprocess.run(command, capture_output=True, text=True, check=True, timeout=60)
            (arguments.evidence_directory / filename).write_text(result.stdout, encoding="utf-8")
            inventories.append(result.stdout)
        runtime_matches, runtimes, devices = (json.loads(value) for value in inventories)
        runtime_identifier = preferred_runtime(runtime_matches, runtimes)
        selected = select_device(devices, runtime_identifier=runtime_identifier)
        selection = {**selected, "udid": validated_udid(selected), "runtimeIdentifier": runtime_identifier}
        # Diagnostic identity is recorded before boot, independently of the
        # readiness gate. Only boot_and_export may publish GITHUB_ENV readiness.
        (arguments.evidence_directory / "native-ios-selection.json").write_text(
            json.dumps(selection, indent=2) + "\n", encoding="utf-8")
        boot_and_export(selection, environment_file, arguments.evidence_directory)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Simulator preparation failed: {error}", file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            print(error.stderr, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
