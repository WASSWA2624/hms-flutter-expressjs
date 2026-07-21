"""Strip org Branch from Flutter frontend Dart + ARB (keep bank branch labels)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(r"D:/coding/apps/flutter/hms/frontend")

KEEP = re.compile(r"subscriptionBankBranch|bankBranch|Bank branch|PLATFORM_BANK", re.I)

DROP = re.compile(
    r"""(?xi)
    \bBranchProfile\b
    | \bBranchProfileDto\b
    | \bbranchId\b
    | \bbranch_id\b
    | HmsApiResource\.branches
    | /branches
    | saveBranch
    | deleteBranch
    | restoreBranch
    | hasBranchesConfigured
    | _BranchSetupSection
    | _BranchFormDialog
    | tenantFacility.*[Bb]ranch
    | settingsWorkspaceModuleBranch
    | /settings/branches
    | wizardStepBranches
    | ChecklistBranches
    | ManageBranches
    | CreateBranch
    | AddBranch
    | EditBranch
    | NoBranches
    | BranchesOptional
    | BranchesSection
    | BranchesList
    | BranchName
    | BranchSearch
    | InvalidBranch
    | MissingBranches
    | DepartmentBranch
    | \bbranches\b
    | DeskTab\.branches
    | SetupDeskTab\.branches
    | ['\"]branches['\"]
    """
)


def process_dart(text: str) -> str:
    out = []
    for line in text.splitlines(keepends=True):
        if KEEP.search(line):
            out.append(line)
            continue
        if DROP.search(line):
            continue
        out.append(line)
    result = "".join(out)
    result = re.sub(r",\s*,", ",", result)
    result = re.sub(r"\(\s*,", "(", result)
    result = re.sub(r",\s*\)", ")", result)
    result = re.sub(r"\[\s*,", "[", result)
    result = re.sub(r",\s*\]", "]", result)
    result = re.sub(r"\{\s*,", "{", result)
    result = re.sub(r",\s*\}", "}", result)
    return result


def process_arb(text: str) -> str:
    # Remove JSON entries whose keys contain Branch/branch but not Bank
    # Simple line-based: drop key lines and following value for org branch keys
    lines = text.splitlines(keepends=True)
    out = []
    skip_meta = False
    i = 0
    while i < len(lines):
        line = lines[i]
        if KEEP.search(line):
            out.append(line)
            i += 1
            continue
        m = re.match(r'\s*"(@@)?([^"]+)"\s*:', line)
        if m:
            key = m.group(2)
            base = key[1:] if key.startswith("@") else key
            if re.search(r"branch", base, re.I) and not re.search(r"bank", base, re.I):
                # skip this key and optional @metadata object
                if key.startswith("@"):
                    # skip until closing },
                    depth = 0
                    while i < len(lines):
                        if "{" in lines[i]:
                            depth += lines[i].count("{")
                        if "}" in lines[i]:
                            depth -= lines[i].count("}")
                        i += 1
                        if depth <= 0:
                            break
                    continue
                else:
                    i += 1
                    # also skip following @key metadata block if present
                    if i < len(lines) and re.match(rf'\s*"@{re.escape(base)}"\s*:', lines[i]):
                        depth = 0
                        while i < len(lines):
                            if "{" in lines[i]:
                                depth += lines[i].count("{")
                            if "}" in lines[i]:
                                depth -= lines[i].count("}")
                            i += 1
                            if depth <= 0:
                                break
                    continue
        out.append(line)
        i += 1
    result = "".join(out)
    result = re.sub(r",\s*,", ",", result)
    result = re.sub(r",\s*}", "\n}", result)
    return result


def main() -> None:
    changed = 0
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if "build" in path.parts or ".dart_tool" in path.parts:
            continue
        if path.suffix == ".arb" and path.name == "app_en.arb":
            original = path.read_text(encoding="utf-8")
            updated = process_arb(original)
            if updated != original:
                path.write_text(updated, encoding="utf-8")
                changed += 1
                print("arb", path)
            continue
        if path.suffix != ".dart":
            continue
        # Skip generated l10n briefly; regenerate later or patch
        original = path.read_text(encoding="utf-8")
        updated = process_dart(original)
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            changed += 1
            print("dart", path.relative_to(ROOT))
    print("changed", changed)


if __name__ == "__main__":
    main()
