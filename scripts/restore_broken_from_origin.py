"""Restore all syntax-broken files from origin/main with no stripping."""
from __future__ import annotations

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
    # also ensure public/facility stay fixed - already fixed separately
]


def main() -> None:
    for rel in BROKEN:
        data = subprocess.check_output(["git", "show", f"origin/main:{rel}"], cwd=REPO)
        path = REPO / rel
        path.write_bytes(data)
        check = subprocess.run(["node", "--check", str(path)], capture_output=True, text=True)
        print(("ok" if check.returncode == 0 else "BAD"), rel)


if __name__ == "__main__":
    main()
