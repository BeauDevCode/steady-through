"""Best-effort evidence from the selected simulator on an ephemeral CI host.

A diagnostic device identity is separate from the readiness export. Capturing
evidence must neither launch the app nor grant a permission or set lifecycle.
"""

import json
import os
from pathlib import Path
import re
import subprocess


def main():
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise ValueError("simulator screen diagnostics are restricted to GitHub Actions")
    evidence = Path("build")
    evidence.mkdir(parents=True, exist_ok=True)
    udid = os.environ.get("STEADY_IOS_SIMULATOR_ID")
    selection = evidence / "native-ios-selection.json"
    if not udid and selection.is_file():
        udid = json.loads(selection.read_text(encoding="utf-8")).get("udid")
    if not udid:
        print("::warning::No selected simulator identity was retained; screen diagnostics unavailable.")
        return
    if not isinstance(udid, str) or not re.fullmatch(r"[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}", udid):
        raise ValueError("diagnostic simulator identity is not a UUID")
    commands = (
        (["xcrun", "simctl", "io", udid, "screenshot", str(evidence / "native-ios-screen.png")], "screen", 30),
        (["xcrun", "simctl", "spawn", udid, "log", "show", "--style", "compact", "--last", "10m",
          "--predicate", 'process == "Runner" OR process == "SpringBoard"'], "system", 60),
    )
    for command, label, timeout in commands:
        try:
            result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    text=True, check=True, timeout=timeout)
            output = result.stdout or ""
        except (OSError, subprocess.SubprocessError) as error:
            output = getattr(error, "output", None) or ""
            print(f"::warning::Simulator {label} diagnostic failed: {type(error).__name__}")
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        (evidence / f"native-ios-{label}.log").write_text(output, encoding="utf-8")


if __name__ == "__main__":
    main()
