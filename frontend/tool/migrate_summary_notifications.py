#!/usr/bin/env python3
"""Migrate workspace summary cards to toolbar summary notifications."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FEATURES = ROOT / "lib" / "features"

PAGE_PATHS = sorted(
    set(FEATURES.glob("**/*_workspace_page.dart"))
    | {
        FEATURES / "patients" / "presentation" / "pages" / "patient_registry_page.dart",
        FEATURES / "tenant_facility" / "presentation" / "pages" / "tenant_facility_setup_page.dart",
    }
)


def find_matching_paren(text: str, open_index: int) -> int:
    depth = 0
    for i in range(open_index, len(text)):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return i
    raise ValueError("Unbalanced parentheses")


def find_matching_bracket(text: str, open_index: int) -> int:
    depth = 0
    for i in range(open_index, len(text)):
        if text[i] == "[":
            depth += 1
        elif text[i] == "]":
            depth -= 1
            if depth == 0:
                return i
    raise ValueError("Unbalanced brackets")


def extract_summary_cards_expr(text: str) -> tuple[str | None, str]:
    match = re.search(r"\bsummaryCards\s*:", text)
    if not match:
        return None, text

    value_start = match.end()
    while value_start < len(text) and text[value_start].isspace():
        value_start += 1

    ch = text[value_start]
    if ch == "<":
        bracket_start = text.find("[", value_start)
        if bracket_start == -1:
            return None, text
        bracket_end = find_matching_bracket(text, bracket_start)
        expr = text[bracket_start + 1 : bracket_end].strip()
        if expr.startswith("...") and expr.count(",") == 0:
            expr = expr[3:].strip()
        else:
            expr = text[value_start : bracket_end + 1]
            expr = expr.replace("<Widget>", "<AppWorkspaceSummaryNotification>")
        value_end = bracket_end + 1
    elif ch.isalpha() or ch == "_":
        if text.startswith("isBedView", value_start):
            q = text.find("?", value_start)
            colon = text.find(":", q)
            false_start = colon + 1
            while false_start < len(text) and text[false_start].isspace():
                false_start += 1
            if text[false_start] == "<":
                bstart = text.find("[", false_start)
                bend = find_matching_bracket(text, bstart)
                false_part = text[bstart : bend + 1].replace(
                    "<Widget>", "<AppWorkspaceSummaryNotification>"
                )
                expr = f"isBedView ? const <AppWorkspaceSummaryNotification>[] : {false_part}"
                value_end = bend + 1
            else:
                return None, text
        else:
            paren = text.find("(", value_start)
            value_end = find_matching_paren(text, paren) + 1
            expr = text[value_start:value_end]
    else:
        return None, text

    while value_end < len(text) and text[value_end].isspace():
        value_end += 1
    if value_end < len(text) and text[value_end] == ",":
        value_end += 1

    new_text = text[: match.start()] + text[value_end:]
    return expr.strip(), new_text


def transform_summary_card_constructor(block: str) -> str:
    if not block.startswith("AppWorkspaceSummaryCard("):
        return block

    inner_start = len("AppWorkspaceSummaryCard(")
    inner_end = block.rfind(")")
    inner = block[inner_start:inner_end]

    props: dict[str, str] = {}
    cursor = 0
    while cursor < len(inner):
        while cursor < len(inner) and inner[cursor].isspace():
            cursor += 1
        if cursor >= len(inner):
            break
        prop_match = re.match(r"([A-Za-z_]\w*)\s*:", inner[cursor:])
        if not prop_match:
            break
        prop = prop_match.group(1)
        absolute = cursor
        cursor += prop_match.end()
        local = cursor
        ch = inner[local] if local < len(inner) else ""
        if ch in "'\"":
            quote = ch
            i = local + 1
            while i < len(inner):
                if inner[i] == quote and inner[i - 1] != "\\":
                    props[prop] = inner[local : i + 1]
                    cursor = i + 1
                    break
                i += 1
        elif ch == "(":
            end = find_matching_paren(inner, local)
            props[prop] = inner[local : end + 1]
            cursor = end + 1
        elif ch == "[":
            end = find_matching_bracket(inner, local)
            props[prop] = inner[local : end + 1]
            cursor = end + 1
        else:
            end = local
            paren = brace = 0
            while end < len(inner):
                ch = inner[end]
                if ch == "(":
                    paren += 1
                elif ch == ")":
                    paren -= 1
                elif ch == "{":
                    brace += 1
                elif ch == "}":
                    brace -= 1
                elif ch == "," and paren == 0 and brace == 0:
                    break
                end += 1
            props[prop] = inner[local:end].strip()
            cursor = end

        while cursor < len(inner) and inner[cursor].isspace():
            cursor += 1
        if cursor < len(inner) and inner[cursor] == ",":
            cursor += 1

    if "label" not in props:
        return block.replace("AppWorkspaceSummaryCard", "AppWorkspaceSummaryNotification").replace(
            "onPressed:", "onSelected:"
        )

    count = props.get("value", "0")
    count_match = re.match(
        r"AppFormatters\.compactNumber\(\s*([^,]+)\s*,\s*[^)]+\)",
        count,
    )
    if count_match:
        count = count_match.group(1).strip()
    else:
        count_match = re.match(r"_countLabel\(\s*[^,]+,\s*([^)]+)\)", count)
        if count_match:
            count = count_match.group(1).strip()
        else:
            str_match = re.match(r"'\$\{([^}]+)\}'", count)
            if str_match:
                count = str_match.group(1).strip()

    on_selected = props.get("onPressed", "() {}")

    lines = [
        "AppWorkspaceSummaryNotification(",
        f"  label: {props['label']},",
        f"  count: {count},",
        f"  icon: {props.get('icon', 'Icons.insights_outlined')},",
    ]
    if "tone" in props:
        lines.append(f"  tone: {props['tone']},")
    lines.append(f"  onSelected: {on_selected},")
    lines.append(")")
    return "\n".join(lines)


def replace_all_summary_cards(text: str) -> str:
    result: list[str] = []
    i = 0
    token = "AppWorkspaceSummaryCard("
    while i < len(text):
        idx = text.find(token, i)
        if idx == -1:
            result.append(text[i:])
            break
        result.append(text[i:idx])
        end = find_matching_paren(text, idx + len("AppWorkspaceSummaryCard"))
        block = text[idx : end + 1]
        result.append(transform_summary_card_constructor(block))
        i = end + 1
    return "".join(result)


def transform_summary_card_helper(text: str) -> str:
    pattern = re.compile(
        r"Widget _summaryCard\(\s*BuildContext context,\s*\{([\s\S]*?)\}\)\s*\{[\s\S]*?"
        r"return AppWorkspaceSummaryCard\(([\s\S]*?)\);\s*\}",
    )

    def repl(match: re.Match[str]) -> str:
        params = match.group(1)
        body_props = match.group(2)
        props: dict[str, str] = {}
        for line in body_props.splitlines():
            line = line.strip().rstrip(",")
            if ":" not in line:
                continue
            key, val = line.split(":", 1)
            props[key.strip()] = val.strip()
        count = props.get("value", "0")
        if "AppFormatters.compactNumber" not in count:
            count = "value"
        else:
            count = re.sub(
                r"AppFormatters\.compactNumber\(\s*value\s*,\s*[^)]+\)",
                "value",
                count,
            )
        return (
            "AppWorkspaceSummaryNotification _summaryNotification(\n"
            "    BuildContext context, {\n"
            f"{params}"
            "  }) {\n"
            "    return AppWorkspaceSummaryNotification(\n"
            f"      label: {props.get('label', 'label')},\n"
            f"      count: {count},\n"
            f"      icon: {props.get('icon', 'Icons.insights_outlined')},\n"
            + (f"      tone: {props['tone']},\n" if "tone" in props else "")
            + f"      onSelected: {props.get('onPressed', 'onPressed')},\n"
            "    );\n"
            "  }"
        )

    return pattern.sub(repl, text)


def rename_helpers(text: str) -> str:
    replacements = [
        ("List<Widget> _summaryCards", "List<AppWorkspaceSummaryNotification> _summaryNotifications"),
        ("List<Widget> _opdBackendSummaryCards", "List<AppWorkspaceSummaryNotification> _opdBackendSummaryNotifications"),
        ("List<Widget> _setupSummaryCards", "List<AppWorkspaceSummaryNotification> _setupSummaryNotifications"),
        ("_summaryCards(", "_summaryNotifications("),
        ("_opdBackendSummaryCards(", "_opdBackendSummaryNotifications("),
        ("_setupSummaryCards(", "_setupSummaryNotifications("),
        ("_summaryCard(", "_summaryNotification("),
        ("return <Widget>[", "return <AppWorkspaceSummaryNotification>["),
        (
            "final List<Widget> cards = <Widget>[]",
            "final List<AppWorkspaceSummaryNotification> notifications = <AppWorkspaceSummaryNotification>[]",
        ),
        ("cards.add(", "notifications.add("),
        ("return cards;", "return notifications;"),
    ]
    for old, new in replacements:
        text = text.replace(old, new)
    return text


def inject_summary_notifications(text: str, summary_expr: str | None) -> str:
    if not summary_expr or "summaryNotifications:" in text:
        return text

    summary_expr = summary_expr.replace("_summaryCards(", "_summaryNotifications(")
    summary_expr = summary_expr.replace("_opdBackendSummaryCards(", "_opdBackendSummaryNotifications(")
    summary_expr = summary_expr.replace("_setupSummaryCards(", "_setupSummaryNotifications(")

    for pattern in (
        r"(appWorkspaceToolbarWithLabels\(\s*\n?\s*l10n,)",
        r"(appWorkspaceToolbarWithLabels\(\s*\n?\s*context\.l10n,)",
    ):
        if re.search(pattern, text):
            return re.sub(
                pattern,
                rf"\1\n        summaryNotifications: {summary_expr},",
                text,
                count=1,
            )
    return text


def migrate_file(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    if "AppWorkspaceSummaryCard" not in original and "summaryCards:" not in original:
        return False

    text = replace_all_summary_cards(original)
    text = transform_summary_card_helper(text)
    text = rename_helpers(text)
    summary_expr, text = extract_summary_cards_expr(text)
    text = re.sub(r"\n\s*compactSummaryCards:\s*true,?", "", text)
    text = re.sub(r"\n\s*inlineSummaryCards:\s*\w+,?", "", text)
    text = inject_summary_notifications(text, summary_expr)

    if text != original:
        path.write_text(text, encoding="utf-8")
        return True
    return False


def main() -> None:
    changed = [str(p.relative_to(ROOT)) for p in PAGE_PATHS if p.exists() and migrate_file(p)]
    print(f"Migrated {len(changed)} files")
    for item in changed:
        print(f"  {item}")


if __name__ == "__main__":
    main()
