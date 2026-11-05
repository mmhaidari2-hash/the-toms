import json
import tempfile
import unittest
from pathlib import Path

from tool.check_public_release import CONTROLS, FIELDS, ROOT, findings


class PublicReleaseGateTest(unittest.TestCase):
    def test_real_repository_is_explicitly_not_cleared(self):
        self.assertTrue(any("publisher." in issue for issue in findings(ROOT)))
        self.assertTrue(any("brand_clearance" in issue for issue in findings(ROOT)))

    def test_missing_evidence_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "app/lib/core/legal/publisher_config.dart"
            config.parent.mkdir(parents=True)
            config.write_text("")
            issues = findings(root)
            self.assertEqual(len(issues), len(FIELDS) + 1)

    def test_approved_word_without_reviewer_date_and_evidence_is_not_enough(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "app/lib/core/legal/publisher_config.dart"
            config.parent.mkdir(parents=True)
            config.write_text("")
            record = root / "docs/compliance/release_evidence.json"
            record.parent.mkdir(parents=True)
            record.write_text(json.dumps({"controls": {
                name: {"status": "approved"} for name in CONTROLS
            }}))
            issues = findings(root)
            self.assertEqual(len(issues), len(FIELDS) + 3 * len(CONTROLS))


if __name__ == "__main__":
    unittest.main()
