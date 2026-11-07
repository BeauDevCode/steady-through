"""Reject incomplete native runs using Dart test's JSON reporter protocol.

Protocol: https://github.com/dart-lang/test/blob/master/pkgs/test/doc/json_reporter.md
The report is JSON objects separated by newlines, not a JSON array. Loading
and teardown tests can be hidden, so only the named application tests count.
"""

import argparse
import json
from pathlib import Path
import sys


REQUIRED_TESTS = frozenset({
    "native bridge remains paused without source consent",
    "native vault keeps an event through lock and authenticated unlock",
    "native encrypted backup restores only after its own passphrase",
    "native support flow preserves focused step and people after reopening",
})


def verify_report(path):
    starts = {}
    completed = set()
    required = set()
    done = False
    with Path(path).open(encoding="utf-8") as report:
        for line_number, line in enumerate(report, 1):
            if not line.strip():
                continue
            event = json.loads(line)
            if not isinstance(event, dict):
                raise ValueError(f"line {line_number} is not an event object")
            if done:
                raise ValueError("events appeared after final completion")
            event_type = event.get("type")
            if event_type == "testStart":
                test = event.get("test")
                if not isinstance(test, dict):
                    raise ValueError("testStart has no test metadata")
                test_id, name = test.get("id"), test.get("name")
                if type(test_id) is not int or not isinstance(name, str):
                    raise ValueError("testStart has an invalid ID or name")
                if test_id in starts:
                    raise ValueError(f"test ID {test_id} started more than once")
                if name in REQUIRED_TESTS:
                    if name in required:
                        raise ValueError(f"required test started more than once: {name}")
                    required.add(name)
                starts[test_id] = name
            elif event_type == "testDone":
                test_id = event.get("testID")
                if type(test_id) is not int or test_id not in starts:
                    raise ValueError("testDone has no corresponding testStart")
                if test_id in completed:
                    raise ValueError(f"test ID {test_id} completed more than once")
                if event.get("result") != "success" or event.get("skipped") is not False:
                    raise ValueError(f"test did not pass without skipping: {starts[test_id]}")
                if starts[test_id] in REQUIRED_TESTS and event.get("hidden") is not False:
                    raise ValueError(f"required test result did not count as execution: {starts[test_id]}")
                completed.add(test_id)
            elif event_type == "error":
                # The protocol permits errors after a successful testDone.
                raise ValueError(f"test runner emitted an error: {event.get('error', 'unknown')}")
            elif event_type == "done":
                if event.get("success") is not True:
                    raise ValueError("test runner did not finish successfully")
                done = True
            elif not isinstance(event_type, str):
                raise ValueError(f"line {line_number} has no event type")
    if not done:
        raise ValueError("missing final successful done event")
    missing = REQUIRED_TESTS - required
    if missing:
        raise ValueError("missing required tests: " + "; ".join(sorted(missing)))
    if starts.keys() != completed:
        raise ValueError("one or more tests started without completing")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    arguments = parser.parse_args()
    try:
        verify_report(arguments.report)
    except (OSError, ValueError) as error:
        print(f"Native report rejected: {error}", file=sys.stderr)
        return 1
    print(f"{len(REQUIRED_TESTS)} required native tests passed; run completed successfully without failures or skips.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
