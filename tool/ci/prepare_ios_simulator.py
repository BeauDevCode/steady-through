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


def select_device(inventory):
    if not isinstance(inventory, dict) or not isinstance(inventory.get("devices"), dict):
        raise ValueError("simctl inventory has no devices map")
    candidates = []
    for runtime, devices in inventory["devices"].items():
        if not runtime.startswith("com.apple.CoreSimulator.SimRuntime.iOS-"):
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
                candidates.append((device["state"] != "Booted", runtime, udid, device))
    if not candidates:
        raise ValueError("no available iPhone simulator in an installed iOS runtime")
    return min(candidates, key=lambda item: item[:3])[3]


def boot_and_export(device, environment_file):
    udid = validated_udid(device)
    if device.get("state") != "Booted":
        subprocess.run(["xcrun", "simctl", "boot", udid], check=True, timeout=120)
    subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True, timeout=600)
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
        result = subprocess.run(["xcrun", "simctl", "list", "devices", "available", "--json"],
                                capture_output=True, text=True, check=True, timeout=60)
        arguments.evidence_directory.mkdir(parents=True, exist_ok=True)
        (arguments.evidence_directory / "native-ios-devices.json").write_text(result.stdout, encoding="utf-8")
        boot_and_export(select_device(json.loads(result.stdout)), environment_file)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Simulator preparation failed: {error}", file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            print(error.stderr, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
