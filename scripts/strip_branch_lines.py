"""Remove org-branch lines/expressions from backend JS + locale JSON.

Keeps bank-branch / jest coverage references.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOTS = [
    Path(r"D:/coding/apps/flutter/hms/backend/src"),
    Path(r"D:/coding/apps/flutter/hms/backend/scripts"),
]

KEEP = re.compile(
    r"bank[_ ]?branch|PLATFORM_BANK_BRANCH|subscriptionBankBranch|coverageThreshold|branches:\s*\{",
    re.I,
)

# Drop whole line if it matches these (and is not KEEP)
DROP_LINE = re.compile(
    r"""(?xi)
    \bbranch_id\b
    | \bbranchId\b
    | \breq\.branch\b
    | \bprisma\.branch\b
    | \btx\.branch\b
    | model:\s*['\"]branch['\"]
    | ['\"]branch['\"]\s*:
    | /branches
    | modules/branch
    | softDeleteBranch
    | restoreBranch\b
    | getFacilityBranches
    | listPublicBranches
    | hasBranchesConfigured
    | branch_allowance
    | included_branches
    | restore_requires_active_branch
    | branch_scope_mismatch
    | errors\.branch
    | messages\.branch
    | messages\.facility\.branches
    | messages\.public\.branches
    | \bBRN\b
    | human.?friendly.*branch
    | id:\s*['\"]branch['\"]
    | ['\"]/settings/branches
    | findMany\(\{\s*where:.*branch
    """
)

# Also drop lines that are only branch include/select relations
DROP_REL = re.compile(
    r"^\s*(branch|branches)\s*:\s*(true|\{|\[|include|select)",
    re.I,
)


def should_drop(line: str) -> bool:
    if KEEP.search(line):
        return False
    if DROP_REL.search(line):
        return True
    if DROP_LINE.search(line):
        return True
    return False


def clean_js(text: str) -> str:
    out_lines = []
    for line in text.splitlines(keepends=True):
        if should_drop(line):
            continue
        # Comment cleanups
        line2 = (
            line.replace("facility/branch", "facility")
            .replace("tenant/facility/branch", "tenant/facility")
            .replace("cross-tenant/facility/branch", "cross-tenant/facility")
        )
        out_lines.append(line2)
    result = "".join(out_lines)
    # Fix common syntax leftovers
    result = re.sub(r",\s*,", ",", result)
    result = re.sub(r"\{\s*,", "{", result)
    result = re.sub(r",\s*\}", "}", result)
    result = re.sub(r"\[\s*,", "[", result)
    result = re.sub(r",\s*\]", "]", result)
    # Remove empty include/select objects that only had branch
    result = re.sub(r"include:\s*\{\s*\}", "include: undefined", result)
    return result


def clean_locale(path: Path) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))

    def scrub(obj):
        if isinstance(obj, dict):
            for k in list(obj.keys()):
                if k in {"branch", "branches"}:
                    del obj[k]
                    continue
                if "branch" in k.lower() and "bank" not in k.lower():
                    del obj[k]
                    continue
                scrub(obj[k])
        elif isinstance(obj, list):
            for item in obj:
                scrub(item)

    scrub(data)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> None:
    changed = 0
    for root in ROOTS:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            if path.suffix not in {".js", ".json"}:
                continue
            if "node_modules" in path.parts:
                continue
            if path.name == "en.json" and "locales" in path.parts:
                clean_locale(path)
                changed += 1
                print("locale", path)
                continue
            if path.suffix == ".json" and "fr-translation" in path.name:
                continue  # skip large cache
            original = path.read_text(encoding="utf-8")
            updated = clean_js(original) if path.suffix == ".js" else original
            if updated != original:
                path.write_text(updated, encoding="utf-8")
                changed += 1
                print("updated", path)
    print("changed", changed)


if __name__ == "__main__":
    main()
