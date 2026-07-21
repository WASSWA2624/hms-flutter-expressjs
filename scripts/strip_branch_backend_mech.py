"""Mechanically strip org-branch fields from backend JS/JSON source files."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(r"D:/coding/apps/flutter/hms/backend/src")
SCRIPTS = Path(r"D:/coding/apps/flutter/hms/backend/scripts")

SKIP_NAME_PARTS = {"node_modules"}

# Lines that are bank/jest related — leave alone when matching only those.
KEEP_LINE = re.compile(
    r"bank[_ ]?branch|PLATFORM_BANK_BRANCH|subscriptionBankBranch|coverageThreshold",
    re.I,
)


def process_text(text: str, path: Path) -> str:
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if KEEP_LINE.search(line):
            out.append(line)
            i += 1
            continue

        # Drop simple assignment / property lines that are solely branch-related
        if re.search(
            r"^\s*(?:const|let|var)?\s*branch(?:Id|_id)?\s*=",
            line,
        ) and "bank" not in line.lower():
            i += 1
            continue

        if re.search(
            r"^\s*branch(?:Id|_id)?\s*[:=]",
            line,
        ) and "bank" not in line.lower():
            # Keep if part of a larger object that might need trailing comma fix later
            if stripped.endswith(",") or stripped.endswith("{") is False:
                i += 1
                continue

        if re.search(r"^\s*req\.branch\s*=", line):
            i += 1
            continue

        if "softDeleteBranchCascade" in line and (
            "const softDeleteBranchCascade" in line or "softDeleteBranchCascade," in line
        ):
            # Skip entire function if starting
            if "const softDeleteBranchCascade" in line or "async function softDeleteBranchCascade" in line:
                # consume until matching closing at column 0 `};` after function
                depth = 0
                started = False
                while i < len(lines):
                    l = lines[i]
                    if "{" in l:
                        depth += l.count("{")
                        started = True
                    if "}" in l:
                        depth -= l.count("}")
                    i += 1
                    if started and depth <= 0:
                        break
                continue
            i += 1
            continue

        # Comment / docstring mentions
        if re.search(r"facility/branch|/branch\b|cross-tenant/facility/branch", line):
            line = (
                line.replace("facility/branch", "facility")
                .replace("/branch", "")
                .replace("cross-tenant/facility/branch", "cross-tenant/facility")
                .replace("tenant/facility/branch", "tenant/facility")
            )

        # Common string/field replacements in remaining lines
        newline = line
        newline = re.sub(r",?\s*['\"]branch_id['\"]\s*,?", "", newline)
        newline = re.sub(r",?\s*['\"]branchId['\"]\s*,?", "", newline)
        newline = re.sub(r"\bbranch_id\b", "/*removed_branch_id*/", newline)

        # If line became only removed marker or empty props, drop it
        if "/*removed_branch_id*/" in newline:
            # Better: rewrite known patterns specifically below; revert crude replace
            newline = line

        # Targeted replacements
        newline = re.sub(
            r"const SCOPE_FIELDS = \['tenant_id', 'facility_id', 'branch_id'\];",
            "const SCOPE_FIELDS = ['tenant_id', 'facility_id'];",
            newline,
        )
        newline = re.sub(
            r"const branchId = decoded\.branch_id \|\| decoded\.branchId \|\| null;\n?",
            "",
            newline,
        )
        newline = re.sub(r"\s*branch_id: branchId,\n?", "", newline)
        newline = re.sub(r"\s*branchId,\n?", "", newline)
        newline = re.sub(r"\s*branchId: branchId,\n?", "", newline)

        # Remove object properties branch_id: <expr>,
        newline = re.sub(
            r"^[ \t]*branch_id\s*:\s*[^,\n]+,?\s*\n",
            "",
            newline,
        )
        newline = re.sub(
            r"^[ \t]*branchId\s*:\s*[^,\n]+,?\s*\n",
            "",
            newline,
        )
        newline = re.sub(
            r"^[ \t]*branches\s*:\s*[^,\n]+,?\s*\n",
            "",
            newline,
        )

        # Fix double commas / trailing commas left after removals later in cleanup pass
        out.append(newline if newline != line else line)
        i += 1

    result = "".join(out)
    # Clean double commas in object/array literals
    result = re.sub(r",\s*,", ",", result)
    result = re.sub(r"\{\s*,", "{", result)
    result = re.sub(r",\s*\}", "}", result)
    result = re.sub(r"\[\s*,", "[", result)
    result = re.sub(r",\s*\]", "]", result)
    return result


def strip_en_locale(path: Path) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))

    def walk(obj):
        if isinstance(obj, dict):
            keys = list(obj.keys())
            for k in keys:
                if k in {"branch", "branches"} and isinstance(obj[k], dict):
                    # Keep if looks like bank? usually errors.branch
                    del obj[k]
                else:
                    walk(obj[k])
        elif isinstance(obj, list):
            for item in obj:
                walk(item)

    walk(data)
    # Also remove restore_requires_active_branch under department if present
    errors = data.get("errors", {})
    dept = errors.get("department", {})
    if isinstance(dept, dict):
        dept.pop("restore_requires_active_branch", None)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> None:
    changed = 0
    for path in list(ROOT.rglob("*.js")) + list(ROOT.rglob("*.json")):
        if any(p in SKIP_NAME_PARTS for p in path.parts):
            continue
        if path.name == "en.json" and "locales" in path.parts:
            strip_en_locale(path)
            changed += 1
            print("locale", path)
            continue
        original = path.read_text(encoding="utf-8")
        updated = process_text(original, path)
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            changed += 1
            print("updated", path.relative_to(ROOT.parent))
    print("files changed", changed)


if __name__ == "__main__":
    main()
