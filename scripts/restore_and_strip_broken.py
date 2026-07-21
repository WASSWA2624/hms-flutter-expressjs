"""Restore syntax-broken JS files from origin/main, then carefully remove Branch."""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

REPO = Path(r"D:/coding/apps/flutter/hms")

BROKEN = [
    "backend/src/tests/modules/tenant-facility-workspace/services/tenant-facility-workspace.service.test.js",
    "backend/src/tests/modules/reports-workspace/services/reports-workspace.service.test.js",
    "backend/src/tests/modules/department/schemas/department.schema.test.js",
    "backend/src/tests/modules/department/services/department.service.test.js",
    "backend/src/tests/modules/dashboard-workspace/services/dashboard-workspace.service.test.js",
    "backend/src/modules/shift-close/services/shift-close.service.js",
    "backend/src/modules/reports-workspace/repositories/reports-workspace.repository.js",
    "backend/src/modules/reports-workspace/services/reports-workspace.service.js",
    "backend/src/modules/office-context/services/office-context.service.js",
    "backend/src/modules/kpi-snapshot/repositories/kpi-snapshot.repository.js",
    "backend/src/modules/kpi-snapshot/services/kpi-snapshot.service.js",
    "backend/src/modules/handover/services/handover.service.js",
    "backend/src/modules/department/services/department.service.js",
    "backend/src/modules/day-close/services/day-close.service.js",
    "backend/src/modules/dashboard-workspace/repositories/dashboard-workspace.repository.js",
    "backend/src/modules/dashboard-workspace/services/dashboard-workspace.service.js",
    "backend/src/modules/dashboard-widget/repositories/dashboard-widget.repository.js",
    "backend/src/modules/dashboard-widget/services/dashboard-widget.service.js",
    "backend/src/modules/custody-snapshot/services/custody-snapshot.service.js",
    "backend/src/modules/contact/services/contact.service.js",
    "backend/src/modules/closeout-pack/services/closeout-pack.service.js",
    "backend/src/modules/break-glass-access/services/break-glass-access.service.js",
    "backend/src/modules/analytics-event/repositories/analytics-event.repository.js",
    "backend/src/modules/analytics-event/services/analytics-event.service.js",
    "backend/src/modules/address/services/address.service.js",
    "backend/src/modules/abac-policy/services/abac-policy.service.js",
    "backend/src/lib/reports/api.js",
]

KEEP = re.compile(r"bank[_ ]?branch|PLATFORM_BANK_BRANCH|subscriptionBankBranch", re.I)

# Drop whole statements/lines that are solely branch-scoped.
LINE_DROP = re.compile(
    r"""(?x)
    \bbranch_id\b
    | \bbranchId\b
    | prisma\.branch\b
    | tx\.branch\b
    | model:\s*['\"]branch['\"]
    | /branches
    | getFacilityBranches
    | listPublicBranches
    | findBranches\b
    | countBranches\b
    | resolveBranchFacilityScope
    | serializeBranch\b
    | softDeleteBranch
    | restoreBranch\b
    | hasBranchesConfigured
    | branch_allowance
    | included_branches
    | branch_scope_mismatch
    | facilityRecords\.branches
    | snapshot\.branches
    | \.branches\b
    """,
    re.I,
)


def git_show(rel: str) -> str:
    return subprocess.check_output(
        ["git", "show", f"origin/main:{rel}"], cwd=REPO
    ).decode("utf-8")


def remove_named_functions(text: str, names: list[str]) -> str:
    for name in names:
        # const name = async (...) => { ... };
        pattern = re.compile(
            rf"\n(?:async\s+)?(?:function\s+{name}\b|const\s+{name}\s*=\s*async\s*\([^)]*\)\s*=>\s*\{{).*?\n\}};\n",
            re.S,
        )
        text = pattern.sub("\n", text)
        pattern2 = re.compile(
            rf"\nconst\s+{name}\s*=\s*\([^)]*\)\s*=>\s*\{{.*?\n\}};\n",
            re.S,
        )
        text = pattern2.sub("\n", text)
    return text


def remove_prisma_branch_findmany(text: str) -> str:
    return re.sub(r"\s*prisma\.branch\.findMany\(\{.*?\}\),?", "", text, flags=re.S)


def strip_branch(text: str) -> str:
    text = remove_named_functions(
        text,
        [
            "getFacilityBranches",
            "listPublicBranches",
            "findBranches",
            "countBranches",
            "resolveBranchFacilityScope",
            "serializeBranch",
            "softDeleteBranchCascade",
            "restoreBranch",
        ],
    )
    text = remove_prisma_branch_findmany(text)

    out = []
    for line in text.splitlines(keepends=True):
        if KEEP.search(line):
            out.append(line)
            continue
        if LINE_DROP.search(line):
            continue
        out.append(line)
    result = "".join(out)
    # Only fix double-commas left by dropped properties; do not squash formatting.
    result = re.sub(r",\s*,+", ",", result)
    return result


def main() -> None:
    for rel in BROKEN:
        try:
            original = git_show(rel)
        except subprocess.CalledProcessError:
            print("missing on origin", rel)
            continue
        cleaned = strip_branch(original)
        path = REPO / rel
        path.write_text(cleaned, encoding="utf-8", newline="\n")
        # verify syntax
        check = subprocess.run(
            ["node", "--check", str(path)], capture_output=True, text=True
        )
        status = "ok" if check.returncode == 0 else "STILL BROKEN"
        print(status, rel)
        if check.returncode != 0:
            err = (check.stderr or "").strip().splitlines()[:3]
            for e in err:
                print(" ", e)


if __name__ == "__main__":
    main()
