#!/usr/bin/env python3
"""Post-fix summary notification migration."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FEATURES = ROOT / "lib" / "features"

PATHS = sorted(
    set(FEATURES.glob("**/*_workspace_page.dart"))
    | {
        FEATURES / "patients" / "presentation" / "pages" / "patient_registry_page.dart",
        FEATURES / "tenant_facility" / "presentation" / "pages" / "tenant_facility_setup_page.dart",
    }
)


def fix_file(text: str) -> str:
    text = re.sub(r"\n\s*compact:\s*true,?", "", text)
    text = re.sub(
        r"\bvalue:\s*AppFormatters\.compactNumber\(\s*([^,\)]+)\s*,\s*[^)]+\)",
        r"count: \1",
        text,
    )
    text = re.sub(
        r"\bvalue:\s*_countLabel\(\s*[^,]+,\s*([^)]+)\)",
        r"count: \1",
        text,
    )
    text = re.sub(
        r"\bvalue:\s*'\$\{([^}]+)\}'",
        r"count: \1",
        text,
    )
    text = re.sub(
        r"\bcount:\s*([a-zA-Z_]\w*)\.toString\(\)",
        r"count: \1",
        text,
    )
    text = re.sub(
        r"summaryNotifications:\s*<AppWorkspaceSummaryNotification>\[\s*\.\.\.([^,]+),\s*\],",
        r"summaryNotifications: \1,",
        text,
    )
    text = re.sub(
        r"Widget _summaryNotification\(",
        "AppWorkspaceSummaryNotification _summaryNotification(",
        text,
    )
    text = re.sub(
        r"(AppWorkspaceSummaryNotification _summaryNotification\([\s\S]*?\)\s*\{\s*)"
        r"return AppWorkspaceSummaryNotification\(\s*label:\s*label,\s*"
        r"(?:value:\s*AppFormatters\.compactNumber\(\s*value\s*,\s*[^)]+\)|count:\s*value),",
        r"\1return AppWorkspaceSummaryNotification(\n      label: label,\n      count: value,",
        text,
    )
    text = re.sub(
        r"(\s+)onPressed:\s*onPressed,",
        r"\1onSelected: onPressed,",
        text,
    )
    # Fix helper parameter name at call sites for summary notification helper
    text = re.sub(
        r"(_summaryNotification\(\s*context,\s*\{[\s\S]*?)onPressed:",
        r"\1onSelected:",
        text,
    )
    # Cards missing onSelected
    text = re.sub(
        r"(AppWorkspaceSummaryNotification\(\s*\n\s*label:[^\)]+\n\s*count:[^\)]+\n\s*icon:[^\)]+\n\s*)\)",
        r"\1  onSelected: () {},\n      )",
        text,
    )
    text = re.sub(r"onSelected: \(\) \{,", "onSelected: () {", text)
    return text


def main() -> None:
    for path in PATHS:
        if not path.exists():
            continue
        original = path.read_text(encoding="utf-8")
        updated = fix_file(original)
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
