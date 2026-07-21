"""Restore broken files from last-good commit f38e2ab4, then safely drop Branch bits."""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

REPO = Path(r"D:/coding/apps/flutter/hms")
GOOD = "f38e2ab4"

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
    # facility also had orphans - restore and strip named fns
    "backend/src/modules/facility/services/facility.service.js",
    "backend/src/modules/facility/repositories/facility.repository.js",
    "backend/src/modules/facility/routes/facility.routes.js",
    "backend/src/modules/facility/controllers/facility.controller.js",
    "backend/src/modules/public/services/public.service.js",
    "backend/src/modules/public/repositories/public.repository.js",
    "backend/src/modules/public/controllers/public.controller.js",
    "backend/src/modules/public/routes/public.routes.js",
]


def show(rel: str) -> str:
    return subprocess.check_output(["git", "show", f"{GOOD}:{rel}"], cwd=REPO).decode("utf-8")


def strip_safe(text: str) -> str:
    # Remove complete if (x.branch_id) { ... } blocks (single assignment style)
    text = re.sub(
        r"\n\s*if \([^\n]*branch_id[^\n]*\) \{\n(?:[^\n]*\n)*?\s*\}\n",
        "\n",
        text,
    )
    # Remove single-line object props
    text = re.sub(r"\n\s*branch_id\s*:[^\n]+,\n", "\n", text)
    text = re.sub(r"\n\s*branchId\s*:[^\n]+,\n", "\n", text)
    # Remove zod-like .optional() chains that are only branch_id fields on one line
    text = re.sub(r"\n\s*branch_id:\s*[^\n]+,\n", "\n", text)

    # Remove named functions entirely (balanced braces from const name =)
    names = [
        "getFacilityBranches",
        "listPublicBranches",
        "findBranches",
        "countBranches",
        "resolveBranchFacilityScope",
        "serializeBranch",
    ]
    for name in names:
        text = remove_function(text, name)

    # Remove export entries
    for name in names:
        text = re.sub(rf"\n\s*{name},?\n", "\n", text)

    # Remove routes that only serve /branches
    text = re.sub(
        r"\n/\*\*[\s\S]*?Get facility branches[\s\S]*?router\.get\([\s\S]*?\);\n",
        "\n",
        text,
        count=1,
    )
    text = re.sub(
        r"\nrouter\.get\(\s*['\"]/?branches['\"][\s\S]*?\);\n",
        "\n",
        text,
    )

    # Remove prisma.branch Promise.all entries
    text = re.sub(r"\s*prisma\.branch\.findMany\(\{[\s\S]*?\}\),?", "", text)
    text = re.sub(r"\s*prisma\.branch\.count\(\{[\s\S]*?\}\),?", "", text)

    return text


def remove_function(text: str, name: str) -> str:
    """Remove `const name = ... { ... };` or `async function name...` with brace matching."""
    patterns = [
        rf"const\s+{name}\s*=",
        rf"async\s+function\s+{name}\b",
        rf"function\s+{name}\b",
    ]
    for pat in patterns:
        while True:
            m = re.search(pat, text)
            if not m:
                break
            start = m.start()
            # include leading docblock
            doc = text.rfind("\n/**", 0, start)
            if doc != -1 and text[doc:start].strip().startswith("/**"):
                # only if between doc and const there's mostly whitespace/comments
                between = text[doc:start]
                if between.count("\nconst ") == 0 and between.count("\nasync ") == 0:
                    start = doc + 1  # keep prior newline via slice
                    if text[start - 1] != "\n":
                        start = doc
            # find first { after match
            brace = text.find("{", m.end())
            if brace < 0:
                break
            depth = 0
            i = brace
            while i < len(text):
                ch = text[i]
                if ch == "{":
                    depth += 1
                elif ch == "}":
                    depth -= 1
                    if depth == 0:
                        end = i + 1
                        if end < len(text) and text[end] == ";":
                            end += 1
                        if end < len(text) and text[end] == "\n":
                            end += 1
                        text = text[:start] + text[end:]
                        break
                i += 1
            else:
                break
    return text


def main() -> None:
    still = []
    for rel in BROKEN:
        try:
            raw = show(rel)
        except subprocess.CalledProcessError:
            print("missing", rel)
            continue
        cleaned = strip_safe(raw)
        path = REPO / rel
        path.write_text(cleaned, encoding="utf-8", newline="\n")
        check = subprocess.run(["node", "--check", str(path)], capture_output=True, text=True)
        if check.returncode != 0:
            still.append(rel)
            print("STILL", rel)
            for line in (check.stderr or "").strip().splitlines()[:3]:
                print(" ", line)
        else:
            print("ok", rel)
    print("remaining", len(still))


if __name__ == "__main__":
    main()
