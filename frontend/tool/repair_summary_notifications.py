#!/usr/bin/env python3
"""Repair broken summary notification migration."""

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


def repair_orphan_spread(text: str) -> str:
    pattern = re.compile(
        r"summaryNotifications:\s*<AppWorkspaceSummaryNotification>\[,?\n"
        r"(?P<toolbar>.*?)\n\s*\),\n"
        r"(?:\s*\.\.\.(?P<spread>[^,\n]+),\n)?"
        r"\s*\],",
        re.DOTALL,
    )

    def repl(match: re.Match[str]) -> str:
        spread = match.group("spread")
        toolbar = match.group("toolbar")
        if spread:
            toolbar = re.sub(
                r"summaryNotifications:\s*<AppWorkspaceSummaryNotification>\[,?\n",
                f"summaryNotifications: {spread.strip()},\n",
                toolbar,
                count=1,
            )
        else:
            toolbar = re.sub(
                r"summaryNotifications:\s*<AppWorkspaceSummaryNotification>\[,?\n",
                "",
                toolbar,
                count=1,
            )
        return f"{toolbar}\n      ),"

    return pattern.sub(repl, text)


def repair_icu_ternary(text: str) -> str:
    if "icu_workspace_page.dart" not in str(text):
        return text
    # Remove broken orphan ternary block before body:
    text = re.sub(
        r"\),\n\s*\? const <Widget>\[\]\n\s*: <Widget>\[\[\s\S]*?\],\n(\s*body:)",
        r"),\n\1",
        text,
        count=1,
    )
    # Inject ICU notifications into toolbar if missing proper list
    if "summaryNotifications: isBedView" in text:
        icu_list = """isBedView
            ? const <AppWorkspaceSummaryNotification>[]
            : _icuSummaryNotifications(context, state, controller)"""
        text = text.replace(
            "summaryNotifications: isBedView,",
            f"summaryNotifications: {icu_list},",
        )
        # Rename inline list to method - extract cards block... too complex
    return text


def fix_notification_fields(text: str) -> str:
    def fix_block(block: str) -> str:
        if "AppWorkspaceSummaryNotification(" not in block:
            return block
        block = re.sub(r"\n\s*compact:\s*true,?", "", block)
        block = re.sub(
            r"value:\s*AppFormatters\.compactNumber\(\s*([^,\)]+)\s*,\s*[^)]+\)",
            r"count: \1",
            block,
        )
        block = re.sub(
            r"value:\s*_countLabel\(\s*[^,]+,\s*([^)]+)\)",
            r"count: \1",
            block,
        )
        return block

    parts: list[str] = []
    token = "AppWorkspaceSummaryNotification("
    i = 0
    while i < len(text):
        idx = text.find(token, i)
        if idx == -1:
            parts.append(text[i:])
            break
        parts.append(text[i:idx])
        depth = 0
        end = idx + len(token) - 1
        while end < len(text):
            if text[end] == "(":
                depth += 1
            elif text[end] == ")":
                depth -= 1
                if depth == 0:
                    break
            end += 1
        block = text[idx : end + 1]
        parts.append(fix_block(block))
        i = end + 1
    return "".join(parts)


def fix_return_types(text: str) -> str:
    text = text.replace(
        "return <Widget>[",
        "return <AppWorkspaceSummaryNotification>[",
    )
    text = text.replace(
        "List<Widget> _summaryNotifications",
        "List<AppWorkspaceSummaryNotification> _summaryNotifications",
    )
    return text


def repair_file(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    text = original
    text = repair_orphan_spread(text)
    text = fix_notification_fields(text)
    text = fix_return_types(text)
    if path.name == "icu_workspace_page.dart":
        text = repair_icu_ternary(text)
    if text != original:
        path.write_text(text, encoding="utf-8")
        return True
    return False


def main() -> None:
    changed = [str(p.relative_to(ROOT)) for p in PATHS if p.exists() and repair_file(p)]
    print(f"Repaired {len(changed)} files")


if __name__ == "__main__":
    main()
