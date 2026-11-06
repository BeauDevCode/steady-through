"""Behavioral fixtures for the native test report gate (no native SDK needed)."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("verify_native_results.py")
NAMES = (
    "native bridge remains paused without source consent",
    "native vault keeps an event through lock and authenticated unlock",
    "native encrypted backup restores only after its own passphrase",
)


def passing_events():
    events = [{"type": "start", "protocolVersion": "0.1.0"}]
    # Loading and tearDownAll are real reporter events, but do not count as
    # evidence that the three required tests executed.
    for test_id, name in enumerate(("loading integration_test/native_smoke_test.dart", *NAMES, "(tearDownAll)")):
        events.append({"type": "testStart", "test": {"id": test_id, "name": name}})
        events.append({"type": "testDone", "testID": test_id, "result": "success", "skipped": False, "hidden": test_id in (0, 4)})
    events.append({"type": "done", "success": True})
    return events


class NativeResultsCliTest(unittest.TestCase):
    def run_report(self, events=None, raw=None, exists=True):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "native-results.json"
            if exists:
                report.write_text(raw if raw is not None else "\n".join(json.dumps(event) for event in events) + "\n", encoding="utf-8")
            return subprocess.run([sys.executable, str(SCRIPT), str(report)], capture_output=True, text=True, check=False)

    def assert_rejected(self, events=None, raw=None, exists=True):
        result = self.run_report(events, raw, exists)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("Native report rejected:", result.stderr)

    def test_accepts_all_three_named_successes_and_final_success(self):
        result = self.run_report(passing_events())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("3 required native tests passed", result.stdout)

    def test_accepts_interleaved_test_completion(self):
        events = passing_events()
        events[2], events[3] = events[3], events[2]
        self.assertEqual(self.run_report(events).returncode, 0)

    def test_rejects_missing_file(self):
        self.assert_rejected(exists=False)

    def test_rejects_empty_report(self):
        self.assert_rejected(raw="")

    def test_rejects_zero_tests_with_successful_run(self):
        self.assert_rejected([{"type": "done", "success": True}])

    def test_rejects_only_loading_and_teardown(self):
        self.assert_rejected([event for event in passing_events() if event.get("test", {}).get("id", event.get("testID")) not in (1, 2, 3)])

    def test_rejects_missing_or_renamed_required_test(self):
        for name in NAMES:
            with self.subTest(name=name):
                events = passing_events()
                next(event["test"] for event in events if event.get("test", {}).get("name") == name)["name"] = name + " changed"
                self.assert_rejected(events)

    def test_rejects_skipped_required_test(self):
        events = passing_events()
        next(event for event in events if event.get("testID") == 2)["skipped"] = True
        self.assert_rejected(events)

    def test_rejects_failed_or_error_result(self):
        for result in ("failure", "error"):
            with self.subTest(result=result):
                events = passing_events()
                next(event for event in events if event.get("testID") == 2)["result"] = result
                self.assert_rejected(events)

    def test_rejects_error_emitted_after_test_succeeds(self):
        events = passing_events()
        events.insert(-1, {"type": "error", "testID": 2, "isFailure": False, "error": "late asynchronous error"})
        self.assert_rejected(events)

    def test_rejects_other_failed_test_even_if_required_tests_pass(self):
        events = passing_events()
        next(event for event in events if event.get("testID") == 0)["result"] = "failure"
        self.assert_rejected(events)

    def test_rejects_missing_completion_for_test(self):
        self.assert_rejected([event for event in passing_events() if event.get("testID") != 2])

    def test_rejects_missing_false_or_null_final_success(self):
        self.assert_rejected(passing_events()[:-1])
        for success in (False, None, "true", 1):
            with self.subTest(success=success):
                self.assert_rejected(passing_events()[:-1] + [{"type": "done", "success": success}])

    def test_rejects_malformed_json_or_non_object(self):
        for raw in ("broken json\n", "[]\n", "null\n"):
            with self.subTest(raw=raw):
                self.assert_rejected(raw=raw)

    def test_rejects_duplicate_id_name_or_completion(self):
        for duplicate in (passing_events()[3], passing_events()[4], {"type": "testStart", "test": {"id": 8, "name": NAMES[0]}}):
            with self.subTest(duplicate=duplicate):
                events = passing_events()
                events.insert(-1, duplicate)
                self.assert_rejected(events)

    def test_rejects_completion_without_start(self):
        events = passing_events()
        events.insert(-1, {"type": "testDone", "testID": 99, "result": "success", "skipped": False})
        self.assert_rejected(events)

    def test_rejects_missing_skipped_field(self):
        events = passing_events()
        del next(event for event in events if event.get("testID") == 2)["skipped"]
        self.assert_rejected(events)

    def test_rejects_hidden_required_test_that_does_not_count_as_execution(self):
        events = passing_events()
        next(event for event in events if event.get("testID") == 2)["hidden"] = True
        self.assert_rejected(events)

    def test_rejects_trailing_events_and_duplicate_done(self):
        for extra in ({"type": "print", "message": "after done"}, {"type": "done", "success": True}):
            with self.subTest(extra=extra):
                self.assert_rejected(passing_events() + [extra])


if __name__ == "__main__":
    unittest.main()
