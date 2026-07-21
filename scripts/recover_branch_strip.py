"""Continue recovery: restore formatting-only damage; carefully re-strip branch refs."""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

REPO = Path(r"D:/coding/apps/flutter/hms")

KEEP = re.compile(
    r"bank[_ ]?branch|PLATFORM_BANK_BRANCH|subscriptionBankBranch|coverageThreshold|branches:\s*\{",
    re.I,
)

BRANCH_HINT = re.compile(
    r"\bbranch_id\b|\bbranchId\b|\breq\.branch\b|prisma\.branch|tx\.branch|"
    r"model:\s*['\"]branch['\"]|/branches|modules/branch|softDeleteBranch|"
    r"restoreBranch\b|getFacilityBranches|listPublicBranches|hasBranchesConfigured|"
    r"branch_allowance|included_branches|restore_requires_active_branch|"
    r"branch_scope_mismatch|errors\.branch|messages\.branch|"
    r"messages\.facility\.branches|messages\.public\.branches|"
    r"\bBRN\b|id:\s*['\"]branch['\"]|['\"]/settings/branches|"
    r"facilityRecords\.branches|\.branches\b|label_key: 'tenant_facility\.checklist\.branches'",
    re.I,
)

DROP_REL = re.compile(r"^\s*(branch|branches)\s*:\s*(true|\{|\[)", re.I)

MANUAL = {
    "backend/src/lib/facility-structure/cascade-soft-delete.js",
    "backend/src/middlewares/tenant-scope.middleware.js",
    "backend/src/middlewares/auth.middleware.js",
    "backend/src/middlewares/request-context.middleware.js",
    "backend/src/middlewares/abac.middleware.js",
    "backend/src/lib/last-office/shared.js",
    "backend/src/app/router.js",
    "backend/prisma/schema.prisma",
}


def git_show(rel: str) -> str | None:
    try:
        out = subprocess.check_output(
            ["git", "show", f"HEAD:{rel}"],
            cwd=REPO,
            stderr=subprocess.DEVNULL,
        )
        return out.decode("utf-8")
    except Exception:
        return None


def should_drop(line: str) -> bool:
    if KEEP.search(line):
        return False
    if DROP_REL.search(line):
        return True
    return bool(BRANCH_HINT.search(line))


def strip_branch_only(text: str) -> str:
    out = []
    for line in text.splitlines(keepends=True):
        if should_drop(line):
            continue
        line = (
            line.replace("facility/branch", "facility")
            .replace("tenant/facility/branch", "tenant/facility")
            .replace("cross-tenant/facility/branch", "cross-tenant/facility")
        )
        out.append(line)
    return "".join(out)


def head_has_branch(text: str) -> bool:
    for line in text.splitlines():
        if KEEP.search(line):
            continue
        if BRANCH_HINT.search(line) or DROP_REL.search(line):
            return True
    return False


def main() -> None:
    status = subprocess.check_output(
        ["git", "status", "--porcelain", "-u", "backend"],
        cwd=REPO,
        text=True,
    )
    restored = restripped = skipped = deleted = 0
    for line in status.splitlines():
        if not line.strip():
            continue
        code = line[:2]
        path = line[3:].strip().replace("\\", "/")
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        if not (path.endswith(".js") or path.endswith(".json")):
            continue
        if path in MANUAL:
            skipped += 1
            continue
        if code.strip().startswith("D") or "D" in code:
            # keep deletions (branch module)
            deleted += 1
            continue
        if path.startswith("backend/src/modules/branch/"):
            deleted += 1
            continue

        head = git_show(path)
        if head is None:
            continue

        # Restore pristine HEAD content
        (REPO / path).write_text(head, encoding="utf-8", newline="\n")
        restored += 1

        if head_has_branch(head):
            cleaned = strip_branch_only(head)
            (REPO / path).write_text(cleaned, encoding="utf-8", newline="\n")
            restripped += 1
            print("restripped", path)

    print(
        f"restored={restored} restripped={restripped} "
        f"manual_skipped={skipped} deleted_kept={deleted}"
    )


if __name__ == "__main__":
    main()
