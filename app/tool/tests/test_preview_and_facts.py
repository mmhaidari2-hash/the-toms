"""Release-facing checks that do not need Flutter.

These confirm review-only build flags stay out of release entrypoints, and that
two factual corrections still match the sources they were checked against.
A pass is not a legal opinion.
"""
import hashlib
import json
import re
import unittest
from pathlib import Path

APP = Path(__file__).resolve().parents[2]
REPO = APP.parent


class PreviewFlagTest(unittest.TestCase):
    def test_release_entrypoints_do_not_set_preview_defines(self):
        files = [
            APP / "tool/build_android.sh",
            APP / "tool/infra/deploy_cloudflare.sh",
            REPO / ".github/workflows/ci.yml",
        ]
        for path in files:
            text = path.read_text()
            self.assertNotIn("PREVIEW_UNLOCK", text, path.name)
            self.assertNotIn("PREVIEW_AUDIO_BASE", text, path.name)

    def test_preview_flags_default_off_in_source(self):
        flags = (APP / "lib/core/platform/preview_flags.dart").read_text()
        self.assertIn("bool.fromEnvironment('PREVIEW_UNLOCK')", flags)
        self.assertIn("String.fromEnvironment('PREVIEW_AUDIO_BASE')", flags)
        self.assertNotIn("defaultValue: true", flags)
        self.assertNotIn("defaultValue: 'http", flags)
        progress = (APP / "lib/core/models/user_progress.dart").read_text()
        self.assertNotIn("fromEnvironment('PREVIEW_UNLOCK'", progress)


class LifeUkFactTest(unittest.TestCase):
    def test_citizenship_question_keeps_the_settlement_date(self):
        data = json.loads((APP / "assets/data/lifeuk.json").read_text())
        values = next(ch for ch in data["chapters"] if ch["id"] == "values")
        expl = values["expl"][3]
        self.assertIn("26 March 2027", expl["en"])
        self.assertIn("B2", expl["en"])
        self.assertIn("۲۶ مارس ۲۰۲۷", expl["fa"])
        self.assertNotIn("Most people applying to settle or become citizens also need to show English at B1", expl["en"])
        q = next(item for item in values["qs"] if item["id"] == "values_13")
        self.assertEqual(q["options"][0], "B1 or above")
        self.assertIn("26 March 2027", q["why"])
        self.assertIn("B2", q["why"])
        self.assertIn("Dr Okafor", q["q"])
        src = (APP / "tool/lifeuk/lifeuk.txt").read_text()
        self.assertIn("26 March 2027", src)
        self.assertNotIn("Most people applying to settle or become citizens also need to show English at B1", src)


class AdviserNameTest(unittest.TestCase):
    def test_visa_and_settlement_name_the_current_regulator(self):
        visa = json.loads((APP / "assets/data/visa_desk.json").read_text())
        blob = json.dumps(visa, ensure_ascii=False)
        self.assertIn("Immigration Advice Authority", blob)
        self.assertIn("formerly OISC", blob)
        self.assertIn("https://www.gov.uk/government/organisations/immigration-advice-authority", blob)
        self.assertNotIn("office-of-the-immigration-services-commissioner", blob)
        settlement = json.loads((APP / "assets/data/settlement.json").read_text())
        self.assertIn("Immigration Advice Authority", settlement["disclaimer_en"])
        self.assertIn("IAA", settlement["disclaimer_fa"])
        spots = (APP / "lib/features/map/map_spots.dart").read_text()
        self.assertIn("IAA", spots)
        self.assertIn("نام پیشین OISC", spots)
        self.assertNotIn("OISC signposts", spots)


class FontProvenanceTest(unittest.TestCase):
    def test_documented_font_prefixes_match_the_files(self):
        text = (REPO / "docs/compliance/font_provenance.md").read_text()
        rows = re.findall(r"\| ([A-Za-z0-9.-]+\.ttf) \| (\d+) \| `([0-9a-f]+)", text)
        self.assertEqual(len(rows), 15)
        for name, nbytes, prefix in rows:
            data = (APP / "assets/google_fonts" / name).read_bytes()
            self.assertEqual(len(data), int(nbytes), name)
            self.assertTrue(hashlib.sha256(data).hexdigest().startswith(prefix), name)


if __name__ == "__main__":
    unittest.main()
