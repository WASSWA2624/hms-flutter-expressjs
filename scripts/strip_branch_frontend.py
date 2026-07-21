"""Remove org Branch from Flutter frontend using origin/main where needed.

Keeps subscriptionBankBranchLabel.
"""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

REPO = Path(r"D:/coding/apps/flutter/hms")
FRONT = REPO / "frontend"

KEEP = re.compile(r"subscriptionBankBranch|bankBranch|Bank branch", re.I)

# High-signal org-branch markers
DROP = re.compile(
    r"""(?x)
    \bBranchProfile\b
    | \bBranchProfileDto\b
    | \bbranchId\b
    | \bbranch_id\b
    | HmsApiResource\.branches
    | saveBranch
    | deleteBranch
    | restoreBranch
    | hasBranchesConfigured
    | _BranchSetupSection
    | _BranchFormDialog
    | tenantFacilityChecklistBranches
    | tenantFacilityWizardStepBranches
    | tenantFacilityCreateBranch
    | tenantFacilityManageBranches
    | tenantFacilityBranches
    | tenantFacilityBranch
    | tenantFacilityAddBranch
    | tenantFacilityEditBranch
    | tenantFacilityNoBranches
    | tenantFacilityInvalidBranch
    | tenantFacilityWizardMissingBranches
    | tenantFacilityDepartmentBranch
    | settingsWorkspaceModuleBranch
    | /settings/branches
    | SetupDeskTab\.branches
    | ['\"]branches['\"]
    """,
    re.I,
)


def should_drop(line: str) -> bool:
    if KEEP.search(line):
        return False
    return bool(DROP.search(line))


def process_text(text: str) -> str:
    return "".join(line for line in text.splitlines(keepends=True) if not should_drop(line))


def process_arb(text: str) -> str:
    lines = text.splitlines(keepends=True)
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if KEEP.search(line):
            out.append(line)
            i += 1
            continue
        m = re.match(r'\s*"(@?)([^"]+)"\s*:', line)
        if m:
            is_meta = bool(m.group(1))
            key = m.group(2)
            base = key
            if re.search(r"branch", base, re.I) and not re.search(r"bank", base, re.I):
                if is_meta:
                    depth = 0
                    while i < len(lines):
                        depth += lines[i].count("{") - lines[i].count("}")
                        i += 1
                        if depth <= 0:
                            break
                    continue
                i += 1
                if i < len(lines) and re.match(rf'\s*"@{re.escape(base)}"\s*:', lines[i]):
                    depth = 0
                    while i < len(lines):
                        depth += lines[i].count("{") - lines[i].count("}")
                        i += 1
                        if depth <= 0:
                            break
                continue
        out.append(line)
        i += 1
    result = "".join(out)
    result = re.sub(r",(\s*)}", r"\1}", result)
    result = re.sub(r",\s*,", ",", result)
    return result


def main() -> None:
    changed = 0
    targets = [
        "lib/core/network/api_endpoints.dart",
        "lib/core/security/auth_session.dart",
        "lib/core/permissions/access_policy.dart",
        "lib/core/realtime/realtime_scope.dart",
        "lib/features/auth/data/dtos/auth_session_dto.dart",
        "lib/features/tenant_facility/domain/entities/tenant_facility_setup.dart",
        "lib/features/tenant_facility/domain/repositories/tenant_facility_repository.dart",
        "lib/features/tenant_facility/data/dtos/tenant_facility_dtos.dart",
        "lib/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart",
        "lib/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart",
        "lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart",
        "lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_wizard.dart",
        "lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart",
        "lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart",
        "lib/features/home/presentation/widgets/home_context_panel.dart",
        "lib/features/home/presentation/controllers/home_controller.dart",
        "lib/features/home/domain/entities/home_dashboard.dart",
        "lib/features/home/domain/entities/home_dashboard_lookups.dart",
        "lib/features/home/data/dtos/home_dashboard_dtos.dart",
        "lib/features/home/data/dtos/home_dashboard_lookups_dtos.dart",
        "lib/features/home/data/repositories/home_repository_impl.dart",
        "lib/features/settings/presentation/widgets/settings_workspace_section.dart",
        "lib/features/reports/data/dtos/reports_dtos.dart",
        "lib/features/reports/domain/entities/reports_entities.dart",
        "lib/l10n/app_en.arb",
    ]

    for rel in targets:
        path = FRONT / rel
        if not path.exists():
            print("missing", rel)
            continue
        original = path.read_text(encoding="utf-8")
        updated = process_arb(original) if path.suffix == ".arb" else process_text(original)
        if updated != original:
            path.write_text(updated, encoding="utf-8", newline="\n")
            changed += 1
            print("updated", rel)

    # tests
    for path in (FRONT / "test").rglob("*.dart"):
        original = path.read_text(encoding="utf-8")
        updated = process_text(original)
        if updated != original:
            path.write_text(updated, encoding="utf-8", newline="\n")
            changed += 1
            print("updated", path.relative_to(FRONT))

    print("changed", changed)


if __name__ == "__main__":
    main()
