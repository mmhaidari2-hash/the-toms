#!/usr/bin/env python3
"""Fail closed for public deployment; local/branch preview builds remain possible.

This verifies the presence of accountable release evidence, not its legal
correctness. A passed check is not a legal opinion or trademark clearance.
"""
import datetime
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTROLS = (
    "brand_clearance", "art_and_content_rights", "speech_output_rights",
    "children_and_privacy", "hosting_and_transfers", "regulated_content_review",
    "consumer_and_store_terms", "accessibility_and_release_qa",
)
FIELDS = (
    "businessName", "postalAddressUk", "privacyEmail", "supportEmail",
    "playContactEmail", "companyNumber", "icoRegistration", "publicPrivacyUrl",
    "publicTermsUrl", "dataDeletionUrl", "securityContactEmail",
)


def findings(root=ROOT):
    issues = []
    source = (root / "app/lib/core/legal/publisher_config.dart").read_text()
    values = dict(re.findall(r"static const String (\w+)\s*=\s*'([^']*)';", source))
    for field in FIELDS:
        value = values.get(field, "").strip()
        if not value or re.search(r"PLACEHOLDER|YOUR-DOMAIN|applying", value, re.I):
            issues.append(f"publisher.{field}: incomplete")
        elif field.endswith("Email") and not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", value):
            issues.append(f"publisher.{field}: invalid email")
        elif field.endswith("Url") and not re.fullmatch(r"https://[^/\s]+(?:/[^\s]*)?", value):
            issues.append(f"publisher.{field}: public HTTPS URL required")
    try:
        record = json.loads((root / "docs/compliance/release_evidence.json").read_text())
        controls = record["controls"]
        if not isinstance(controls, dict):
            raise ValueError("controls must be an object")
    except (OSError, ValueError, KeyError, TypeError):
        return issues + ["release evidence: missing or invalid"]
    for name in CONTROLS:
        row = controls.get(name)
        if not isinstance(row, dict) or row.get("status") != "approved":
            issues.append(f"{name}: not approved")
            continue
        if not isinstance(row.get("reviewer"), str) or not row["reviewer"].strip():
            issues.append(f"{name}: accountable reviewer required")
        try:
            day = datetime.date.fromisoformat(row.get("reviewed_on", ""))
            if day > datetime.date.today():
                raise ValueError("future date")
        except (ValueError, TypeError):
            issues.append(f"{name}: valid review date required")
        evidence = row.get("evidence")
        if not isinstance(evidence, list) or not evidence or any(
            not isinstance(item, str) or not item.strip() or "PLACEHOLDER" in item
            for item in evidence
        ):
            issues.append(f"{name}: evidence reference required")
    return issues


if __name__ == "__main__":
    blocked = findings()
    if blocked:
        print("PUBLIC RELEASE BLOCKED (evidence/readiness check, not a legal ruling)")
        print("\n".join(f"- {issue}" for issue in blocked))
        raise SystemExit(1)
    print("Release evidence present. This is not legal certification; review it before publishing.")
