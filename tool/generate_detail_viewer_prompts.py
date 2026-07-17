"""Generate per-dialog standardization prompts for detail-viewer inventory.

Normative contract: prompts/detail-viewers/prompt.md
Regenerate after inventory or contract changes:

    python tool/generate_detail_viewer_prompts.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tool"))

import generate_encounter_dialog_prompts as base  # noqa: E402

INVENTORY = ROOT / "dialog-inventory" / "03-detail-viewers.md"
PROMPTS = ROOT / "prompts" / "detail-viewers"
CONTRACT = "prompts/detail-viewers/prompt.md"
CONTRACT_REL = "prompt.md"  # relative from each prompt file in the same folder
INDEX = ROOT / "dialog-inventory" / "03-detail-viewers-prompts.md"
PATTERN_TEST = base.PATTERN_TEST

API_CONTRACT = base.API_CONTRACT
SYNC_RULE = base.SYNC_RULE
COMPONENTS_RULE = base.COMPONENTS_RULE
LOCALIZATION_RULE = base.LOCALIZATION_RULE
PERMISSIONS_RULE = base.PERMISSIONS_RULE
DESIGN_RULE = base.DESIGN_RULE
ACCESSIBILITY_RULE = base.ACCESSIBILITY_RULE
FEEDBACK_RULE = base.FEEDBACK_RULE
FRONTEND_TESTING_RULE = base.FRONTEND_TESTING_RULE
BACKEND_API_RULE = base.BACKEND_API_RULE
BACKEND_TESTING_RULE = base.BACKEND_TESTING_RULE

MODULE_FLOW_RULES = {
    "emergency": ".cursor/flows/emergency-flow.mdc",
    "icu": ".cursor/flows/icu-flow.mdc",
    "ipd": ".cursor/flows/ipd-flow.mdc",
    "opd": ".cursor/flows/opd-flow.mdc",
    "patients": ".cursor/flows/opd-flow.mdc",
    "nursing": ".cursor/flows/nursing-flow.mdc",
    "discharge": ".cursor/flows/discharge-flow.mdc",
    "lab": ".cursor/flows/lab-flow.mdc",
    "pharmacy": ".cursor/flows/pharmacy-flow.mdc",
    "radiology": ".cursor/flows/radiology-flow.mdc",
}

SHARED_REUSE = [
    (
        "Detail layout",
        "`AppPatientDetails`, `AppPatientDetailDialog`, `AppSectionPanel`, "
        "`AppContentPanel`, `AppMessagePanel`, `AppInfoSheetGrid` / "
        "`AppInfoSheetRow`, `AppInfoTileGrid` / `AppInfoTile`, "
        "`AppExpandableRecordSection`, `AppCopyableIdentifier`",
    ),
    (
        "Status / history / clinical preview",
        "`AppStatusBadge` / `AppStatusText`, `AppTimeline`, "
        "`AppClinicalResultsPreview`",
    ),
    (
        "Reports / print previews",
        "`AppReportPreviewPanel`, `AppReportSummaryGrid`, "
        "`AppReportActionButton`, `AppReportSectionTile` / picker helpers",
    ),
    (
        "Action groups",
        "`AppActionPanel` / `AppActionSection`, permission action components, "
        "`buildAppDialogFormActions` when an edit handoff fits",
    ),
    (
        "Async / empty / error",
        "`AppLoadingIndicator` / `AppLoadingSurface`, shared state panels "
        "(`AppStateView` / workspace state panels) — never raw Material progress",
    ),
    (
        "Approved shells / openers",
        "`showAppDialog`, `AppPatientDetailDialog`, "
        "`showAppWorkspaceActionDialog` / `showAppWorkspaceMutationDialog` "
        "when already the workspace pattern, and existing `show*` / `open*` "
        "detail helpers",
    ),
]

SHELL_REFS = base.SHELL_REFS
SHELL_REFS = {
    **SHELL_REFS,
    "AppPatientDetailDialog": (
        "frontend/lib/shared/components/app_patient_detail_dialog.dart"
    ),
    "AppPatientDetails": "frontend/lib/shared/components/app_patient_details.dart",
    "AppInfoSheetGrid": "frontend/lib/shared/components/app_info_sheet.dart",
    "AppInfoTileGrid": "frontend/lib/shared/components/app_info_tile.dart",
    "AppSectionPanel": "frontend/lib/shared/components/app_content_panel.dart",
    "AppExpandableRecordSection": (
        "frontend/lib/shared/components/app_record_section.dart"
    ),
    "AppReportPreviewPanel": (
        "frontend/lib/shared/components/app_report_actions.dart"
    ),
    "AppClinicalResultsPreview": (
        "frontend/lib/shared/components/app_clinical_results_preview.dart"
    ),
    "AppTimeline": "frontend/lib/shared/components/app_timeline.dart",
    "AppStatusBadge": "frontend/lib/shared/components/app_status_badge.dart",
    "AppCopyableIdentifier": (
        "frontend/lib/shared/components/app_copyable_identifier.dart"
    ),
}

SLUG_OVERRIDES = {
    "_openDetailDialog": "access-admin-detail-dialog",
    "AppPatientDetailDialog": "app-patient-detail-dialog",
    "PatientDetailDialog": "patient-detail-dialog",
    "NursingPatientDetailDialog": "nursing-patient-detail-dialog",
    "NursingPrintSummaryDialog": "nursing-print-summary-dialog",
    "SubscriptionReportAdminsDialog": "subscription-report-admins-dialog",
    "_RequestDetailsEditDialog": "radiology-request-details-edit-dialog",
    "_LabReportPreviewDialog": "lab-report-preview-dialog",
    "_PatientReportPrintPreviewDialog": "patient-report-print-preview-dialog",
    "_showReportPreviewDialog": "housekeeping-report-preview-dialog",
    "openReportDetailDialog": "reports-report-detail-dialog",
    "openComplianceDetailDialog": "reports-compliance-detail-dialog",
    "showHrWorkQueueDialog": "hr-work-queue-dialog",
    "showHrStaffDirectoryDialog": "hr-staff-directory-dialog",
    "showHrPreviewPayrollDialog": "hr-preview-payroll-dialog",
    "showHrPreviewRosterDialog": "hr-preview-roster-dialog",
}

# Explicit overrides. Missing symbols get auto briefs from default_brief().
DIALOG_BRIEFS: dict[str, dict] = {
    "AppPatientDetailDialog": {
        "mission": (
            "Keep the shared patient detail chrome shell domain-neutral and "
            "reusable so every patient-bearing detail viewer composes it "
            "instead of forking AppDialog chrome."
        ),
        "primary_commit": "Cancel (dismiss) — optional secondary actions injected by callers",
        "affected": "none by itself — callers own Riverpod slices",
        "siblings": [
            "PatientDetailDialog",
            "NursingPatientDetailDialog",
            "openEmergencyDetailDialog",
            "openIcuDetailDialog",
            "_openIpdDetailDialog",
        ],
        "focus": [
            "This is the canonical shared shell — extend its API; do not duplicate it in features.",
            "Callers supply localized title/closeLabel/content; never bake patient names into the shell.",
            "Preserve maximize/scroll/action-slot behavior used by nursing and patient registry.",
        ],
        "shape": "shared_detail_shell",
    },
    "PatientDetailDialog": {
        "mission": (
            "Present the patient registry detail surface by composing "
            "`AppPatientDetailDialog` / `AppPatientDetails` and shared info/"
            "section primitives — not a parallel patient chrome."
        ),
        "primary_commit": "Cancel (dismiss) — secondary Edit/actions only when already present",
        "affected": "patient registry selection/detail slices",
        "siblings": [
            "AppPatientDetailDialog",
            "NursingPatientDetailDialog",
            "_PatientReportPrintPreviewDialog",
        ],
        "focus": [
            "Compose `AppPatientDetailDialog` + `AppPatientDetails`; replace bespoke identity blocks.",
            "Use `AppInfoSheetGrid` / `AppExpandableRecordSection` for demographics and history.",
            "IDs must use `AppCopyableIdentifier` with `human_friendly_id`.",
        ],
        "shape": "detail_viewer",
        "patient_bearing": True,
    },
    "NursingPatientDetailDialog": {
        "mission": (
            "Show nursing patient context through the shared patient detail "
            "shell and shared section/info primitives while preserving nursing "
            "action reachability."
        ),
        "primary_commit": "Cancel (dismiss) — nursing secondary actions remain permission-gated",
        "affected": "nursing selection/detail, related clinical badges",
        "siblings": [
            "AppPatientDetailDialog",
            "PatientDetailDialog",
            "NursingPrintSummaryDialog",
            "openIcuDetailDialog",
        ],
        "focus": [
            "Already hosts `AppPatientDetailDialog` — deepen body reuse (`AppSectionPanel`, info sheets, status badges).",
            "Keep writeRequirement / AccessGate behavior; never expose unauthorized actions.",
            "Replace raw loaders/empty states with shared loading/state panels.",
        ],
        "shape": "detail_viewer",
        "patient_bearing": True,
    },
    "NursingPrintSummaryDialog": {
        "mission": (
            "Preview/print the nursing summary using shared report/preview "
            "primitives rather than a one-off print body."
        ),
        "primary_commit": "Print (with Copy/secondary as applicable) then Cancel",
        "affected": "no server mutation unless print audit exists — verify before patching",
        "siblings": [
            "NursingPatientDetailDialog",
            "_PatientReportPrintPreviewDialog",
            "_LabReportPreviewDialog",
            "_showReportPreviewDialog",
        ],
        "focus": [
            "Reuse `AppReportPreviewPanel` / `AppReportSummaryGrid` / `AppReportActionButton`.",
            "Use `AppActionIcons.print`; do not invent HTTP writes for local-only print.",
        ],
        "shape": "detail_preview",
    },
    "_BillingLedgerDialog": {
        "mission": (
            "Present the patient billing ledger as a uniform read-only detail "
            "surface with shared sections, info grids, and loading/error UX."
        ),
        "primary_commit": "Cancel (dismiss)",
        "affected": "billing ledger/detail slices (realtime reconcile only)",
        "siblings": ["_showBillingDetailDialog", "PatientDetailDialog"],
        "focus": [
            "Replace `LinearProgressIndicator` with `AppLoadingIndicator` / `AppLoadingSurface`.",
            "Ledger totals/rows use `AppInfoSheetGrid` / `AppSectionPanel` / list primitives — not ad-hoc Text columns.",
            "Keep realtime refresh; never treat websocket as a write.",
        ],
        "shape": "detail_viewer",
        "patient_bearing": True,
    },
    "_showBillingDetailDialog": {
        "mission": (
            "Open billing work-item detail through `AppDialog` and shared "
            "detail layout primitives used by other billing viewers."
        ),
        "primary_commit": "Cancel (dismiss) — secondary Edit only if already present",
        "affected": "billing workspace selection/detail",
        "siblings": ["_BillingLedgerDialog"],
        "focus": [
            "Inline opener must host shared section/info primitives, not bespoke label rows.",
            "Currency/amount formatting via shared formatters only.",
        ],
        "shape": "detail_viewer",
    },
    "openEmergencyDetailDialog": {
        "mission": (
            "Show emergency encounter detail with shared patient context, "
            "status, timeline, and section primitives."
        ),
        "primary_commit": "Cancel (dismiss) — secondary actions stay permission-gated",
        "affected": "emergency case detail/queue selection",
        "siblings": [
            "openIcuDetailDialog",
            "_openIpdDetailDialog",
            "PatientDetailDialog",
            "AppPatientDetailDialog",
        ],
        "focus": [
            "Patient-bearing: compose `AppPatientDetails` / `AppPatientDetailDialog` patterns.",
            "Use `AppStatusBadge`, `AppTimeline`, and `AppInfoSheetGrid` for case facts.",
        ],
        "shape": "detail_viewer",
        "patient_bearing": True,
    },
    "openIcuDetailDialog": {
        "mission": (
            "Show ICU patient detail using the same shared detail product "
            "surface as other clinical detail viewers."
        ),
        "primary_commit": "Cancel (dismiss) — secondary actions stay permission-gated",
        "affected": "ICU board selection/detail",
        "siblings": [
            "openEmergencyDetailDialog",
            "_openIpdDetailDialog",
            "NursingPatientDetailDialog",
        ],
        "focus": [
            "Compose shared patient + section + status primitives; delete local key/value chrome.",
            "Preserve ICU board call sites and contextual IDs.",
        ],
        "shape": "detail_viewer",
        "patient_bearing": True,
    },
    "_openIpdDetailDialog": {
        "mission": (
            "Show IPD admission/patient detail through shared patient and "
            "section primitives used across inpatient surfaces."
        ),
        "primary_commit": "Cancel (dismiss)",
        "affected": "IPD workspace selection/detail",
        "siblings": [
            "openIcuDetailDialog",
            "_openBedDetailDialog",
            "NursingPatientDetailDialog",
        ],
        "focus": [
            "Patient-bearing detail must reuse `AppPatientDetails` and info/section panels.",
            "Bed/ward facts use `AppInfoSheetGrid` / `AppStatusBadge`.",
        ],
        "shape": "detail_viewer",
        "patient_bearing": True,
    },
    "_openBedDetailDialog": {
        "mission": (
            "Show bed board detail with shared info/section/status primitives "
            "aligned to rooms/beds and IPD viewers."
        ),
        "primary_commit": "Cancel (dismiss)",
        "affected": "rooms/beds selection/detail",
        "siblings": ["_openIpdDetailDialog", "openIcuDetailDialog"],
        "focus": [
            "Occupancy/status via `AppStatusBadge`; facts via `AppInfoSheetGrid`.",
            "If a patient is assigned, show `AppPatientDetails` rather than free-text name rows.",
        ],
        "shape": "detail_viewer",
    },
    "_LabReportPreviewDialog": {
        "mission": (
            "Preview lab report content through shared clinical-results and "
            "report preview primitives."
        ),
        "primary_commit": "Cancel / Print as already present — no invented mutation",
        "affected": "lab result preview only unless audit API proven",
        "siblings": [
            "NursingPrintSummaryDialog",
            "_PatientReportPrintPreviewDialog",
            "AppClinicalResultsPreview",
        ],
        "focus": [
            "Prefer `AppClinicalResultsPreview` and/or `AppReportPreviewPanel`.",
            "Remove bespoke preview chrome; keep reject/paired flows reachable.",
        ],
        "shape": "detail_preview",
    },
    "_PatientReportPrintPreviewDialog": {
        "mission": (
            "Preview patient report print output using shared report preview "
            "and action primitives."
        ),
        "primary_commit": "Print (secondary Copy if present) then Cancel",
        "affected": "no server mutation unless print audit exists — verify before patching",
        "siblings": [
            "NursingPrintSummaryDialog",
            "_LabReportPreviewDialog",
            "PatientDetailDialog",
        ],
        "focus": [
            "Compose `AppReportPreviewPanel` / `AppReportActionButton` / `AppActionIcons.print`.",
            "Do not invent Riverpod patches for local-only print.",
        ],
        "shape": "detail_preview",
    },
    "_showReportPreviewDialog": {
        "mission": (
            "Preview housekeeping report output with the same shared report "
            "preview surface used elsewhere."
        ),
        "primary_commit": "Print/Cancel as applicable — no invented mutation",
        "affected": "housekeeping report preview only",
        "siblings": [
            "NursingPrintSummaryDialog",
            "_PatientReportPrintPreviewDialog",
            "openReportDetailDialog",
        ],
        "focus": [
            "Reuse `AppReportPreviewPanel` / summary grid / report action buttons.",
        ],
        "shape": "detail_preview",
    },
    "openReportDetailDialog": {
        "mission": (
            "Show a report run/detail viewer using shared report section and "
            "preview primitives."
        ),
        "primary_commit": "Cancel (dismiss)",
        "affected": "reports workspace selection/detail",
        "siblings": [
            "openComplianceDetailDialog",
            "_showReportPreviewDialog",
            "SubscriptionReportAdminsDialog",
        ],
        "focus": [
            "Use report section/preview shared components; avoid ad-hoc report body layouts.",
        ],
        "shape": "detail_preview",
    },
    "openComplianceDetailDialog": {
        "mission": (
            "Show compliance item detail with shared section/info/status "
            "primitives consistent with reports viewers."
        ),
        "primary_commit": "Cancel (dismiss)",
        "affected": "reports/compliance selection/detail",
        "siblings": ["openReportDetailDialog"],
        "focus": [
            "Status via `AppStatusBadge`; facts via `AppInfoSheetGrid` / `AppSectionPanel`.",
        ],
        "shape": "detail_viewer",
    },
    "showHrStaffDirectoryDialog": {
        "mission": (
            "Present the HR staff directory as a uniform detail/directory "
            "surface reusing shared list/search/info primitives."
        ),
        "primary_commit": "Cancel (dismiss) — row open may hand off to staff detail",
        "affected": "HR directory selection",
        "siblings": [
            "showHrStaffDetailDialog",
            "showHrWorkQueueDialog",
            "_HrAssignmentDetailDialog",
        ],
        "focus": [
            "Directory chrome uses shared search/list patterns; opening a row reuses staff detail primitives.",
            "Do not build a second directory shell.",
        ],
        "shape": "detail_directory",
    },
    "showHrWorkQueueDialog": {
        "mission": (
            "Present the HR work queue viewer with shared list/section/status "
            "primitives aligned to other HR detail surfaces."
        ),
        "primary_commit": "Cancel (dismiss)",
        "affected": "HR work-queue selection",
        "siblings": [
            "showHrStaffDirectoryDialog",
            "_showWorkItemDialog",
            "_showActivityDialog",
        ],
        "focus": [
            "Reuse shared list/status/section components; keep work-item openers reachable.",
        ],
        "shape": "detail_directory",
    },
    "showHrStaffDetailDialog": {
        "mission": (
            "Show HR staff detail through shared info/section/status "
            "primitives — never a bespoke staff profile chrome."
        ),
        "primary_commit": "Cancel (dismiss)",
        "affected": "HR staff detail selection",
        "siblings": [
            "showHrStaffDirectoryDialog",
            "_HrAssignmentDetailDialog",
            "_HrAccessUserDetailDialog",
        ],
        "focus": [
            "Title is role-based (Staff Detail), not the person's name.",
            "Identity/IDs use `AppCopyableIdentifier` and info sheets.",
        ],
        "shape": "detail_viewer",
    },
    "showHrPreviewPayrollDialog": {
        "mission": (
            "Preview payroll using shared report/summary grid primitives."
        ),
        "primary_commit": "Cancel / Print as applicable — no invented mutation",
        "affected": "HR payroll preview only",
        "siblings": [
            "showHrPreviewRosterDialog",
            "showHrCompensationDetailDialog",
        ],
        "focus": [
            "Prefer `AppReportPreviewPanel` / `AppReportSummaryGrid` for totals and line items.",
        ],
        "shape": "detail_preview",
    },
    "showHrPreviewRosterDialog": {
        "mission": (
            "Preview roster using shared report/section primitives consistent "
            "with other HR previews."
        ),
        "primary_commit": "Cancel / Print as applicable — no invented mutation",
        "affected": "HR roster preview only",
        "siblings": [
            "showHrPreviewPayrollDialog",
            "showHrScheduleTemplateDetailDialog",
            "showHrShiftDetailDialog",
        ],
        "focus": [
            "Reuse shared preview/section components; avoid roster-specific chrome forks.",
        ],
        "shape": "detail_preview",
    },
    "_AccessAdminRoleDetailDialog": {
        "mission": (
            "Show access-admin role detail using shared permission/role "
            "presentation components under `frontend/lib/shared/`."
        ),
        "primary_commit": "Cancel (dismiss) — Edit only if already present",
        "affected": "access_admin role detail",
        "siblings": [
            "_AccessAdminUserDetailDialog",
            "showHrAccessRoleDetailDialog",
            "_openDetailDialog",
        ],
        "focus": [
            "Reuse `AppPermissionGroupedView` / `AppUserAccessPanel` / role assignment pickers when applicable.",
            "Facts via `AppInfoSheetGrid` / `AppSectionPanel`.",
        ],
        "shape": "detail_viewer",
    },
    "_AccessAdminUserDetailDialog": {
        "mission": (
            "Show access-admin user detail with shared user-access and info "
            "primitives."
        ),
        "primary_commit": "Cancel (dismiss)",
        "affected": "access_admin user detail",
        "siblings": [
            "_AccessAdminRoleDetailDialog",
            "_HrAccessUserDetailDialog",
        ],
        "focus": [
            "Compose `AppUserAccessPanel` / permission grouped views; no local access chrome.",
        ],
        "shape": "detail_viewer",
    },
    "_HrAccessUserDetailDialog": {
        "mission": (
            "Show HR access user detail by reusing the same shared user-access "
            "primitives as access_admin viewers."
        ),
        "primary_commit": "Cancel (dismiss)",
        "affected": "HR access user detail",
        "siblings": [
            "showHrAccessRoleDetailDialog",
            "showHrAccessPermissionDetailDialog",
            "_AccessAdminUserDetailDialog",
        ],
        "focus": [
            "Eliminate HR-only forks of user/permission detail layout.",
        ],
        "shape": "detail_viewer",
    },
    "showHrAccessRoleDetailDialog": {
        "mission": (
            "Show HR access role detail with shared permission/role primitives."
        ),
        "primary_commit": "Cancel (dismiss)",
        "affected": "HR access role detail",
        "siblings": [
            "showHrAccessPermissionDetailDialog",
            "_HrAccessUserDetailDialog",
            "_AccessAdminRoleDetailDialog",
        ],
        "focus": [
            "Align with access_admin role detail shared components.",
        ],
        "shape": "detail_viewer",
    },
    "showHrAccessPermissionDetailDialog": {
        "mission": (
            "Show HR permission detail with shared permission presentation "
            "components."
        ),
        "primary_commit": "Cancel (dismiss)",
        "affected": "HR access permission detail",
        "siblings": [
            "showHrAccessRoleDetailDialog",
            "_HrAccessUserDetailDialog",
        ],
        "focus": [
            "Reuse `AppPermissionGroupedView` / info sheets; no bespoke permission tables.",
        ],
        "shape": "detail_viewer",
    },
    "_TenantDetailsDialog": {
        "mission": (
            "Show tenant details with shared section/info primitives aligned "
            "to facility/setup detail viewers."
        ),
        "primary_commit": "Cancel (dismiss)",
        "affected": "tenant_facility tenant detail",
        "siblings": [
            "_FacilityDetailsDialog",
            "_SetupDetailDialog",
            "_openSubscriptionDetailDialog",
        ],
        "focus": [
            "IDs via `AppCopyableIdentifier`; facts via `AppInfoSheetGrid` / `AppSectionPanel`.",
        ],
        "shape": "detail_viewer",
    },
    "_FacilityDetailsDialog": {
        "mission": (
            "Show facility details with the same shared detail surface as "
            "tenant/setup viewers."
        ),
        "primary_commit": "Cancel (dismiss)",
        "affected": "tenant_facility facility detail",
        "siblings": ["_TenantDetailsDialog", "_SetupDetailDialog"],
        "focus": [
            "Eliminate facility-only chrome forks; reuse shared info/section primitives.",
        ],
        "shape": "detail_viewer",
    },
    "_SetupDetailDialog": {
        "mission": (
            "Show tenant/facility setup detail using shared info/section "
            "primitives."
        ),
        "primary_commit": "Cancel (dismiss)",
        "affected": "tenant_facility setup detail",
        "siblings": ["_TenantDetailsDialog", "_FacilityDetailsDialog"],
        "focus": [
            "Setup facts in `AppSectionPanel` + `AppInfoSheetGrid`; shared loading/error UX.",
        ],
        "shape": "detail_viewer",
    },
    "SubscriptionReportAdminsDialog": {
        "mission": (
            "Show subscription report-admins detail/directory with shared "
            "list/info primitives."
        ),
        "primary_commit": "Cancel (dismiss)",
        "affected": "subscriptions report-admins presentation",
        "siblings": [
            "_openSubscriptionDetailDialog",
            "showHrStaffDirectoryDialog",
        ],
        "focus": [
            "Reuse shared list/info components; keep all listed call sites working.",
        ],
        "shape": "detail_directory",
    },
    "_RequestDetailsEditDialog": {
        "mission": (
            "Present radiology request details (edit handoff) on the shared "
            "detail/form surface — detail chrome first, then shared form "
            "actions if editing remains in-scope for this row."
        ),
        "primary_commit": "Edit (not Update) when persisting; otherwise Cancel",
        "affected": "radiology request detail/edit slices",
        "siblings": ["_openRadiologyDetailDialog"],
        "focus": [
            "Read path uses shared detail primitives; any persist path uses controllers + form action helpers.",
            "Do not keep a one-off request details shell.",
        ],
        "shape": "detail_viewer",
    },
    "showCommunicationsNotificationDetailDialog": {
        "mission": (
            "Show communications notification detail with shared info/section "
            "primitives used by delivery/template viewers."
        ),
        "primary_commit": "Cancel (dismiss)",
        "affected": "communications notification detail",
        "siblings": [
            "showCommunicationsDeliveryDetailDialog",
            "showCommunicationsTemplateDetailDialog",
        ],
        "focus": [
            "Unify the three communications detail openers onto one section/info pattern.",
        ],
        "shape": "detail_viewer",
    },
    "showCommunicationsDeliveryDetailDialog": {
        "mission": (
            "Show communications delivery detail with the shared "
            "communications detail surface."
        ),
        "primary_commit": "Cancel (dismiss)",
        "affected": "communications delivery detail",
        "siblings": [
            "showCommunicationsNotificationDetailDialog",
            "showCommunicationsTemplateDetailDialog",
        ],
        "focus": [
            "Reuse the same info/section/status primitives as notification/template detail.",
        ],
        "shape": "detail_viewer",
    },
    "showCommunicationsTemplateDetailDialog": {
        "mission": (
            "Show communications template detail with the shared "
            "communications detail surface."
        ),
        "primary_commit": "Cancel (dismiss)",
        "affected": "communications template detail",
        "siblings": [
            "showCommunicationsNotificationDetailDialog",
            "showCommunicationsDeliveryDetailDialog",
        ],
        "focus": [
            "Template body preview should reuse shared content/report panels where applicable.",
        ],
        "shape": "detail_viewer",
    },
}


def clean_purpose(purpose: str) -> str:
    text = purpose.strip().rstrip(".")
    text = re.sub(r"^Detail viewer:\s*", "", text, flags=re.I)
    text = re.sub(
        r"\s*\((access_admin|billing|biomedical|claims|communications|"
        r"discharge|emergency|housekeeping|hr|icu|integrations|ipd|lab|"
        r"mortuary|nursing|operations|patients|pharmacy|physiotherapy|"
        r"radiology|reports|rooms_beds|subscriptions|tenant_facility|"
        r"shared[^)]*)\)\s*$",
        "",
        text,
        flags=re.I,
    )
    text = re.sub(r"\s+", " ", text).strip()
    return text or purpose.strip()


def slugify(symbol: str, module: str | None = None) -> str:
    if symbol in SLUG_OVERRIDES:
        return SLUG_OVERRIDES[symbol]
    return base.slugify(symbol, module)


def parse_inventory() -> list[dict]:
    """Parse detail-viewer inventory; temporarily retarget base.INVENTORY."""
    previous = base.INVENTORY
    base.INVENTORY = INVENTORY
    try:
        rows = base.parse_inventory()
    finally:
        base.INVENTORY = previous
    for row in rows:
        row["purpose_clean"] = clean_purpose(row["purpose"])
    return rows


def refresh_inventory(rows: list[dict]) -> None:
    previous = base.INVENTORY
    previous_overrides = base.PURPOSE_OVERRIDES
    base.INVENTORY = INVENTORY
    base.PURPOSE_OVERRIDES = {}
    try:
        base.refresh_inventory(rows)
    finally:
        base.INVENTORY = previous
        base.PURPOSE_OVERRIDES = previous_overrides


def detect_shape(symbol: str, peek: dict, brief: dict, extends: str) -> str:
    if brief.get("shape"):
        return brief["shape"]
    purpose = (brief.get("mission") or "").lower()
    if "preview" in symbol.lower() or "preview" in purpose or "print" in symbol.lower():
        return "detail_preview"
    if "directory" in symbol.lower() or "workqueue" in symbol.lower().replace("_", ""):
        return "detail_directory"
    if symbol == "AppPatientDetailDialog":
        return "shared_detail_shell"
    if symbol.startswith(("show", "open", "_open", "_show")) and "Dialog" not in symbol:
        # opener functions that host bodies
        return "detail_viewer"
    return "detail_viewer"


def shape_guidance(shape: str) -> list[str]:
    common = [
        "Compose through approved shells only — never raw `AlertDialog` / `showDialog`.",
        "Titles are general/role-based, passed through `AppDialog` for uppercase normalization — never patient or staff personal names.",
        "Loading uses only `AppLoadingIndicator` / `AppLoadingSurface` / `AppButton.isLoading` — never `CircularProgressIndicator` / `LinearProgressIndicator`.",
        "While loading: disable Cancel, close, and competing actions; `closeEnabled: false`.",
        "Footer L→R: optional secondary actions → **Cancel**. Do not invent a primary mutation commit.",
        "Every `AppButton` needs a leading icon (`AppActionIcons` when mapped) and localized label.",
        "Widgets never call APIs; reads go through controllers/Riverpod; WebSockets only reconcile.",
        "Replace bespoke label/value lists with `AppInfoSheetGrid` / `AppInfoSheetRow` / `AppInfoTileGrid`.",
        "Section chrome must use `AppSectionPanel` / `AppContentPanel`; long records use `AppExpandableRecordSection`.",
    ]
    by_shape = {
        "detail_viewer": [
            "Read-only detail: prefer Cancel-only footer unless Edit/Print/Navigate already exist.",
            "Patient-bearing bodies must compose `AppPatientDetails` and/or `AppPatientDetailDialog`.",
            "Status via `AppStatusBadge` / `AppStatusText`; IDs via `AppCopyableIdentifier`.",
        ],
        "detail_preview": [
            "Preview/print: reuse `AppReportPreviewPanel` / `AppReportSummaryGrid` / `AppReportActionButton` or `AppClinicalResultsPreview`.",
            "Do not invent HTTP writes or Riverpod patches for local-only print; verify audit APIs before syncing.",
            "Order local secondary actions before Cancel and any primary local action (Print).",
        ],
        "detail_directory": [
            "Directory/queue viewer: shared search/list/status primitives; row open hands off to a canonical detail viewer.",
            "Do not embed a second full detail chrome inside the directory body.",
        ],
        "shared_detail_shell": [
            "Shared shell only: keep API domain-neutral; accept localized title/closeLabel/content/actions from callers.",
            "Do not move feature business logic into the shell; deepen reuse by migrating callers onto it.",
        ],
    }
    return common + by_shape.get(shape, by_shape["detail_viewer"])


def gap_notes(peek: dict, shape: str) -> list[str]:
    gaps = []
    if peek["uses_alert_dialog"] or peek["uses_raw_show_dialog"]:
        gaps.append(
            "Raw Material dialog API detected — migrate to `AppDialog` / "
            "`showAppDialog` (or `AppPatientDetailDialog`)."
        )
    if not peek["uses_app_dialog"] and not peek["uses_show_app_dialog"]:
        gaps.append(
            "No clear approved shell usage near the symbol — verify and migrate "
            "to `AppDialog` / `showAppDialog` / `AppPatientDetailDialog`."
        )
    if peek["uses_circular_progress"]:
        gaps.append(
            "Raw Material progress indicator detected — replace with "
            "`AppLoadingIndicator` / `AppLoadingSurface` / `AppButton.isLoading` only."
        )
    if not peek["is_loading"] and shape != "shared_detail_shell":
        gaps.append(
            "No obvious shared loading primitive near the symbol — add "
            "`AppLoadingIndicator` / `AppLoadingSurface` for async open/load."
        )
    if peek["uses_app_button"] and not peek["uses_action_icons"]:
        gaps.append(
            "`AppButton` seen without `AppActionIcons` — every action needs a "
            "leading icon; use `AppActionIcons` for shared verbs."
        )
    if (
        not peek["uses_action_icons"]
        and peek.get("uses_material_icons")
        and shape != "shared_detail_shell"
    ):
        gaps.append(
            "One-off `Icons.*` detected — prefer `AppActionIcons` (or sibling "
            "domain icon conventions) when a shared mapping exists."
        )
    if peek.get("widget_reads_repository"):
        gaps.append(
            "Widget reads a repository provider directly — move load ownership "
            "to a controller and keep server-backed UI state in Riverpod."
        )
    for anti in peek["label_antipatterns"]:
        gaps.append(anti)
    # Detail-specific reuse nudges when peeks show weak shared adoption.
    scan_hint = " ".join(peek.get("delegated_components") or [])
    if shape == "detail_viewer" and "AppInfoSheet" not in scan_hint and "AppSectionPanel" not in scan_hint:
        gaps.append(
            "No `AppInfoSheet*` / `AppSectionPanel` delegation detected — replace "
            "bespoke key/value and section chrome with shared detail primitives."
        )
    if shape == "detail_preview" and "AppReport" not in scan_hint and "AppClinicalResults" not in scan_hint:
        gaps.append(
            "No shared report/clinical preview delegation detected — migrate onto "
            "`AppReportPreviewPanel` / `AppClinicalResultsPreview` (or extract one)."
        )
    return gaps


def default_brief(row: dict, siblings: list[str]) -> dict:
    title = clean_purpose(row["purpose"])
    module = base.module_hint(row["path"])
    symbol = row["symbol"]
    lower = f"{symbol} {title}".lower()
    patient_bearing = any(
        token in lower
        for token in (
            "patient",
            "emergency",
            "icu",
            "ipd",
            "nursing",
            "mortuary",
            "discharge",
            "therapy",
            "pharmacy",
            "radiology",
            "lab",
        )
    )
    if any(token in lower for token in ("preview", "print", "report preview", "payroll", "roster")):
        shape = "detail_preview"
        primary = "Print/Cancel as applicable — no invented mutation"
        focus = [
            f"Standardize `{symbol}` onto shared report/preview primitives under `frontend/lib/shared/`.",
            "Reuse `AppReportPreviewPanel` / `AppReportSummaryGrid` / `AppClinicalResultsPreview` when applicable.",
            "Replace raw loaders; keep Cancel labeling (not Close).",
        ]
    elif any(token in lower for token in ("directory", "work queue")):
        shape = "detail_directory"
        primary = "Cancel (dismiss) — row open hands off to detail"
        focus = [
            f"Standardize `{symbol}` onto shared list/search/status primitives.",
            "Do not embed a second full detail chrome; open canonical detail viewers from rows.",
        ]
    else:
        shape = "detail_viewer"
        primary = "Cancel (dismiss) — optional secondary Edit/Print only if already present"
        focus = [
            f"Standardize `{symbol}` onto shared detail layout primitives under `frontend/lib/shared/`.",
            "Replace bespoke label/value lists with `AppInfoSheetGrid` / `AppInfoSheetRow` / `AppInfoTileGrid`.",
            "Use `AppSectionPanel` / `AppContentPanel` for sections; `AppExpandableRecordSection` for long records.",
            "Loading/error/empty via shared primitives only.",
        ]
        if patient_bearing:
            focus.insert(
                1,
                "Patient-bearing: compose `AppPatientDetails` and/or `AppPatientDetailDialog`.",
            )
    return {
        "mission": (
            f"Present a uniform read-only detail surface for **{title}** by "
            f"composing predefined shared components from `frontend/lib/shared/` "
            f"so `{module}` matches sibling detail viewers."
        ),
        "primary_commit": primary,
        "affected": f"{module} detail/workspace selection slices (realtime reconcile only unless a mutation is proven)",
        "siblings": siblings,
        "focus": focus,
        "shape": shape,
        "patient_bearing": patient_bearing,
    }


def module_siblings(rows: list[dict], symbol: str, module: str) -> list[str]:
    peers = [
        r["symbol"]
        for r in rows
        if r["symbol"] != symbol and base.module_hint(r["path"]) == module
    ]
    # Prefer a short stable list.
    return peers[:5]


def build_prompt(idx: int, row: dict, peek: dict, brief: dict) -> str:
    symbol = row["symbol"]
    purpose = row["purpose"]
    path = row["path"] or (
        "(locate in inventory / codebase — path missing from inventory cell)"
    )
    inventory_line = row["line"] if row["line"] is not None else "?"
    line = row.get("source_line")
    line = line if line is not None else inventory_line
    kind = row["kind"]
    extends = row["extends"]
    openers = sorted(set(row["openers"] + row.get("detected_openers", [])))
    used = sorted(
        set(row.get("validated_used", []) + row.get("discovered_used", []))
    )
    title = clean_purpose(purpose) or base.human_title(symbol, purpose)
    purpose_clean = clean_purpose(purpose)
    module = base.module_hint(row["path"])
    flow_rule = MODULE_FLOW_RULES.get(module)
    flow_rule_row = (
        f"| Module flow | [`{flow_rule}`](../../{flow_rule}) | "
        "Domain workflow states, transitions, and handoffs |"
        if flow_rule
        else ""
    )
    slug = slugify(symbol, module)
    shape = detect_shape(symbol, peek, brief, extends)
    gaps = gap_notes(peek, shape)
    guidance = shape_guidance(shape)

    defined_loc = f"`{path}:{line}`" if line != "?" else f"`{path}`"
    opener_md = (
        ", ".join(f"`{o}`" for o in openers)
        if openers
        else "_none listed in inventory_"
    )
    reachability_md = (
        ", ".join(f"`{o}`" for o in openers)
        if openers
        else "existing private call sites / *Used from* sites"
    )
    used_md = (
        "\n".join(f"- `{u}`" for u in used)
        if used
        else "- _Inventory lists no *Used from* sites — keep existing private openers reachable._"
    )
    title_snip = (
        ", ".join(f"`{t}`" for t in peek["title_snippets"][:4])
        if peek["title_snippets"]
        else "_not detected in peek — inspect source_"
    )
    buttons = (
        " -> ".join(peek["button_snippets"][:8])
        if peek["button_snippets"]
        else "_not detected — inspect `AppDialog.actions` / helper actions_"
    )
    gap_md = (
        "\n".join(f"{i}. {g}" for i, g in enumerate(gaps, 1))
        if gaps
        else "1. Peek did not flag obvious gaps — still complete every checklist item; peeks are heuristic."
    )
    reuse_md = "\n".join(f"- **{k}:** {v}" for k, v in SHARED_REUSE)
    controller_hints = [
        h.rstrip(",").strip() for h in peek["controller_hints"][:6] if h.strip()
    ]
    controller_md = (
        ", ".join(f"`{h}`" for h in controller_hints)
        if controller_hints
        else "_not detected in peek — trace widget → workspace controller → repository → backend route_"
    )
    mutation_md = (
        ", ".join(f"`{h}`" for h in peek["mutation_hints"][:6])
        if peek["mutation_hints"]
        else "_not detected in symbol region — detail viewers are usually read-only; verify before inventing writes_"
    )
    delegated_md = (
        "\n".join(f"- `{item}`" for item in peek["delegated_components"])
        if peek["delegated_components"]
        else "- _No delegated dialog/form/panel implementation detected; inspect the target body directly._"
    )
    trace_md = (
        "\n".join(f"- `{item}`" for item in peek["trace_files"])
        if peek["trace_files"]
        else "- _No mutation-name matches were found automatically. Trace load paths and route registrations manually._"
    )
    location_note = (
        f"Inventory says line {inventory_line}; verified declaration is line {line}. "
        "Treat the verified declaration as authoritative and update the inventory if this task moves it."
        if row.get("line_drift")
        else "Inventory and verified declaration agree at generation time."
    )

    mission = brief["mission"]
    primary_commit = brief["primary_commit"]
    affected = brief["affected"]
    siblings = brief.get("siblings") or []
    siblings_md = (
        ", ".join(f"`{s}`" for s in siblings)
        if siblings
        else "_scan inventory peers in the same module and shared detail surfaces_"
    )
    focus_md = "\n".join(f"- {item}" for item in brief["focus"])
    guidance_md = "\n".join(f"- {g}" for g in guidance)
    patient_note = (
        "- [ ] This viewer is **patient-bearing**: body must compose `AppPatientDetails` and/or `AppPatientDetailDialog`."
        if brief.get("patient_bearing")
        else "- [ ] If this viewer surfaces a person/patient, keep the chrome title role-based and put identity in shared detail components."
    )

    shell_bits = []
    if peek["uses_app_dialog"]:
        shell_bits.append("`AppDialog`")
    if peek["uses_show_app_dialog"]:
        shell_bits.append("approved `show*` helper")
    if any("AppPatientDetailDialog" in c for c in peek.get("delegated_components", [])):
        shell_bits.append("`AppPatientDetailDialog`")
    shell_obs = ", ".join(shell_bits) if shell_bits else "unclear — verify in source"

    action_acceptance = {
        "detail_preview": (
            "Local secondary actions precede Cancel and any primary local action "
            "(Print); no server mutation is invented."
        ),
        "detail_directory": (
            "Directory supports Cancel plus row-open handoff; it does not invent "
            "a generic primary mutation commit."
        ),
        "shared_detail_shell": (
            "Shell preserves caller-injected actions + Cancel/close slot; remains "
            "domain-neutral and reusable."
        ),
    }.get(
        shape,
        "Footer is optional secondary actions → **Cancel**; labels are Cancel/Edit "
        "(not Close/Update); no invented primary mutation.",
    )
    backend_acceptance = (
        "Load paths use the real API contract; dismiss/local actions do not patch server state."
    )
    sync_acceptance = (
        "No provider patch is introduced for a non-mutating/local-only detail view; "
        "realtime reconcile only when already required."
        if shape in {"detail_preview", "detail_directory", "shared_detail_shell", "detail_viewer"}
        else "On persisted success only, patch affected slices then reconcile."
    )

    # Relative links from prompts/detail-viewers/*.md
    def rel(path_from_root: str) -> str:
        return f"../../{path_from_root}"

    return f"""# Standardize `{symbol}` — {title}

## Mission

{mission}

Bring **`{symbol}`** to **100% compliance** with [`{CONTRACT_REL}`]({CONTRACT_REL}) (detail-viewer standardization). This is **structural**, not cosmetic: consolidate onto the established product surface used across [`dialog-inventory/03-detail-viewers.md`]({rel("dialog-inventory/03-detail-viewers.md")}). Do not invent another dialog shell, use raw `AlertDialog` / `showDialog`, or keep duplication merely to shrink the diff. Prefer predefined components under [`frontend/lib/shared/`]({rel("frontend/lib/shared/")}) for every repeated detail pattern.

## Normative contracts (read before editing)

| Contract | Path | Authority |
| --- | --- | --- |
| Detail-viewer standardization | [`{CONTRACT_REL}`]({CONTRACT_REL}) | Shells, shared detail reuse, loading/actions, titles, verification |
| API envelopes / IDs | [`.cursor/api-contract.mdc`]({rel(API_CONTRACT)}) | `snake_case`, `human_friendly_id`, success/error envelopes |
| Instant UI sync | [`frontend/.cursor/instant_ui_sync.mdc`]({rel(SYNC_RULE)}) | HTTP mutate, Riverpod patch on success, WS reconcile only |
| Shared components | [`frontend/.cursor/components.mdc`]({rel(COMPONENTS_RULE)}) | Reuse under `frontend/lib/shared/`; no feature forks of shared UI |
| Localization | [`frontend/.cursor/localization_i18n.mdc`]({rel(LOCALIZATION_RULE)}) | All user-facing strings via l10n |
| Permissions | [`frontend/.cursor/permissions.mdc`]({rel(PERMISSIONS_RULE)}) | Preserve RBAC/ABAC wrappers; never expose unauthorized actions |
| Design system | [`frontend/.cursor/design-system.mdc`]({rel(DESIGN_RULE)}) | Tokens only; responsive light/dark UI |
| Accessibility | [`frontend/.cursor/accessibility.mdc`]({rel(ACCESSIBILITY_RULE)}) | Focus, semantics, keyboard, scaling, contrast |
| Feedback / failures | [`frontend/.cursor/ui-feedback.mdc`]({rel(FEEDBACK_RULE)}) | Shared async/failure states; preserve input; safe errors |
| Frontend tests | [`frontend/.cursor/testing.mdc`]({rel(FRONTEND_TESTING_RULE)}) | Widget/controller/sync/responsive coverage |
| Backend API | [`backend/.cursor/api.mdc`]({rel(BACKEND_API_RULE)}) | Routes, middleware, authz, public IDs |
| Backend tests | [`backend/.cursor/testing.mdc`]({rel(BACKEND_TESTING_RULE)}) | Schema/service/controller/route/event coverage |
{flow_rule_row}

## Target

| Field | Value |
| --- | --- |
| Symbol | `{symbol}` |
| Purpose | {purpose_clean} |
| Module / surface | `{module}` |
| Inventory kind | `{kind}` |
| Presentation shape | `{shape}` |
| Verified definition | {defined_loc} |
| Inventory location note | {location_note} |
| Extends / uses | {extends} |
| Paired opener(s) | {opener_md} |
| Primary commit | {primary_commit} |
| Slices to keep in sync | {affected} |
| Sibling reuse targets | {siblings_md} |
| Controllers (region) | {controller_md} |
| Mutations (region) | {mutation_md} |

### Used from

{used_md}

### Delegated/shared implementation evidence

{delegated_md}

### Cross-stack trace candidates

These files mention a detected mutation/load method and are starting points, not proof of ownership. Follow interfaces/imports and route registration until the persisted path is proven.

{trace_md}

## Compliance checklist (`{CONTRACT_REL}` — this dialog only)

### 1. Established shells
- [ ] Composed through `AppDialog` via `showAppDialog`, or `AppPatientDetailDialog` for patient-bearing surfaces, or an approved workspace helper when already the pattern.
- [ ] **No** raw `AlertDialog` / `showDialog` on this presentation path.
- [ ] Purpose, listed call sites, resolved contextual IDs, and permission wrappers are preserved.

### 2. Reuse before creating (detail uniformity)
- [ ] Repeated shells, sections, rows, states, and action groups use one canonical shared implementation; superseded local copies are removed.
- [ ] Shared barrels under `frontend/lib/shared/` were searched before adding widgets; canonical APIs are extended, not copied or trivially wrapped.
- [ ] Body uses the **Shared building blocks** below when equivalents exist (info sheets, section panels, patient details, status, timeline, report preview, etc.).
- [ ] If no shared primitive exists and another inventory detail viewer needs the same UI, create one configurable, domain-neutral primitive under `frontend/lib/shared/`; keep domain behavior in controllers.
{patient_note}

### 3. Loading and actions
- [ ] Loading uses only `AppLoadingIndicator` or `AppLoadingSurface`; async actions use `AppButton.isLoading`. **No** `CircularProgressIndicator` / `LinearProgressIndicator`.
- [ ] While loading: Cancel, close, and competing actions are disabled; `closeEnabled: false`.
- [ ] Footer order left→right: optional **secondary** actions, then **Cancel**. No invented primary mutation commit.
- [ ] Every `AppButton` has a leading icon and localized label. Use `AppActionIcons` for shared verbs; match sibling detail viewers in `{module}`.
- [ ] Labels: **Cancel** (not Close), **Edit** (not Update).

### 4. Titles
- [ ] Title is general / role-based — **never** a patient or staff personal name.
- [ ] Title is passed through `AppDialog` for uppercase normalization; icon matches sibling conventions in this module when peers already use icons.
- [ ] Person identity lives in `AppPatientDetails` / info sheets inside the body, not in the chrome title.

### 5. Design, responsiveness, localization, and accessibility
- [ ] No hard-coded user-facing copy or private feature string holder; labels, hints, errors, tooltips, and semantics use generated l10n.
- [ ] No hard-coded color, spacing, radius, elevation, typography, date, number, or currency formatting; use theme/design tokens and shared formatters.
- [ ] Content and actions remain usable on mobile, tablet, desktop, dark mode, text scaling, and constrained-height layouts without overflow.
- [ ] Keyboard order is logical, focus is trapped/restored by the dialog shell, visible focus remains, icon-only controls have localized semantics, and status is not conveyed by color alone.

### 6. Backend correctness and sync
- [ ] Every load path is traced end-to-end: dialog → workspace controller → repository/DTO → real backend route/schema/service.
- [ ] IDs, `snake_case` payloads, auth, envelopes, and response decoding match [`.cursor/api-contract.mdc`]({rel(API_CONTRACT)}); either side is fixed when mismatched.
- [ ] Widgets never call APIs or own competing server data. Reads via controllers/Riverpod; WebSockets only reconcile ([`instant_ui_sync.mdc`]({rel(SYNC_RULE)})).
- [ ] On failure: dialog stays open, `AppFailure` is shown through shared failure UI, and **nothing** is patched.
- [ ] Detail viewers usually do not mutate. If a secondary action persists: patch {affected} only after HTTP success, then apply the smallest targeted reconciliation.
- [ ] Cancel / failure neither patches nor dismisses as if saved.

### 7. Reachability and verification
- [ ] Still reachable from every paired opener and *Used from* site listed above.
- [ ] `{PATTERN_TEST}` stays green. Add focused widget, controller, DTO, and (when the stack is touched) backend route/schema/service tests for this dialog's path.

## Compliance snapshot (heuristic — verify in code)

| Signal | Observation |
| --- | --- |
| Approved shell signals | {shell_obs} |
| Raw `showDialog` / `AlertDialog` | {"yes — migrate" if peek["uses_raw_show_dialog"] or peek["uses_alert_dialog"] else "not seen in peek"} |
| Raw Material progress indicator | {"yes — replace" if peek["uses_circular_progress"] else "not seen"} |
| Title snippets | {title_snip} |
| `AppButton` variants (order seen) | {buttons} |
| `AppActionIcons` | {"seen" if peek["uses_action_icons"] else "not seen"} |
| `closeEnabled: false` | {"yes" if peek["close_enabled_false"] else "not seen"} |
| Loading primitives | {"seen" if peek["is_loading"] else "not seen"} |
| Direct widget repository read | {"yes — move to controller" if peek["widget_reads_repository"] else "not seen"} |
| Delegated components scanned | {len(peek["delegated_components"])} |
| Cross-stack trace files found | {len(peek["trace_files"])} |
| Peek region size | {peek["region_chars"]} chars |

### Priority gaps to close

{gap_md}

### Dialog-specific focus

{focus_md}

## Shared building blocks (mandatory reuse)

Prefer these over new one-offs (`{CONTRACT_REL}` Requirement 2):

{reuse_md}

Shell / detail chrome references:

- `AppDialog` / `showAppDialog` — `{SHELL_REFS["AppDialog"]}`
- `AppPatientDetailDialog` — `{SHELL_REFS["AppPatientDetailDialog"]}`
- `AppPatientDetails` — `{SHELL_REFS["AppPatientDetails"]}`
- `AppSectionPanel` / `AppContentPanel` — `{SHELL_REFS["AppSectionPanel"]}`
- `AppInfoSheetGrid` / `AppInfoSheetRow` — `{SHELL_REFS["AppInfoSheetGrid"]}`
- `AppInfoTileGrid` — `{SHELL_REFS["AppInfoTileGrid"]}`
- `AppExpandableRecordSection` — `{SHELL_REFS["AppExpandableRecordSection"]}`
- `AppCopyableIdentifier` — `{SHELL_REFS["AppCopyableIdentifier"]}`
- `AppStatusBadge` — `{SHELL_REFS["AppStatusBadge"]}`
- `AppTimeline` — `{SHELL_REFS["AppTimeline"]}`
- `AppClinicalResultsPreview` — `{SHELL_REFS["AppClinicalResultsPreview"]}`
- `AppReportPreviewPanel` — `{SHELL_REFS["AppReportPreviewPanel"]}`
- `AppButton` — `{SHELL_REFS["AppButton"]}`
- `AppActionIcons` — `{SHELL_REFS["AppActionIcons"]}`
- Loading — `{SHELL_REFS["AppLoadingIndicator"]}` (+ `AppLoadingSurface`)
- Title casing — `{SHELL_REFS["toDialogTitleUppercase"]}`

Prefer existing openers and shared detail helpers over copying chrome into a feature folder.

## Execution plan

You are a coding agent with full read/write access to this repo. Execute every step. Do not ask for clarification. Treat the normative contracts table as binding.

**Scope lock:** only `{symbol}` and the minimum call-site / shared-helper edits required for compilation and compliance. Do **not** expand to unrelated inventory rows. Shared extracts are allowed only when required for reuse and must stay domain-neutral under `frontend/lib/shared/`.

### Shape rules for `{shape}`

{guidance_md}

### Steps

1. **Read contracts + source**
   - Read every contract in the **Normative contracts** table. Apply each rule to files matching its scope; do not treat this prompt as a substitute for project rules.
   - Read `{symbol}` at {defined_loc} and every paired opener / *Used from* site.
   - Inspect every delegated/shared implementation and trace candidate above, then follow imports/interfaces/routes beyond those candidates as needed.
   - Trace each load (and any real mutation): dialog → controller → repository/DTO → backend route/schema/service → decode → Riverpod.

2. **Normalize shell (Req 1)**
   - Compose with `AppDialog` / `AppPatientDetailDialog` / approved helpers; open with `showAppDialog` as appropriate.
   - Remove raw `AlertDialog` / `showDialog` on this path.
   - Preserve purpose, contextual IDs, and permission wrappers.

3. **Normalize title + icon (Req 4)**
   - General role/flow title for **{title}** — never personal display name.
   - Pass title through the shell for uppercase normalization.
   - Match sibling icon conventions in `{module}`.

4. **Normalize loading + footer (Req 3)**
   - Shared loading primitives only; rebuild actions with `AppButton` + `AppActionIcons` + l10n.
   - Order: secondary → **Cancel** (`{primary_commit}`).
   - In flight: disable Cancel/close/competitors; `closeEnabled: false`.

5. **Reuse shared detail primitives (Req 2 — hard)**
   - Replace bespoke key/value blocks, section chrome, status chips, timelines, and preview bodies with the Shared building blocks above.
   - Cross-check sibling reuse targets: {siblings_md}.
   - Extract under `frontend/lib/shared/` only when multiple inventory detail viewers need the same UI.
   - Delete superseded local widgets after migration.

6. **Behavior + permissions**
   - Openers pass already-resolved contextual IDs (`human_friendly_id` / domain IDs).
   - Preserve parent permission wrappers; do not expose unauthorized actions.

7. **Design + accessibility**
   - Use generated l10n, theme/design tokens, shared formatters, and responsive layout primitives only.
   - Verify keyboard/focus/semantics, text scaling, dark mode, constrained height, and mobile/tablet/desktop layouts.

8. **Backend + sync (Req 5)**
   - Widgets read Riverpod and delegate to controllers; no widget API calls.
   - Happy-path loads must succeed against the real contract; fix either side on mismatch.
   - Failure → shared `AppFailure` UI, no patch, dialog stays open.
   - Do not invent mutations. If a secondary action already persists → patch {affected} only after success.
   - Cancel/failure never present false success.

9. **Preserve reachability**
   - Do not break {reachability_md}. Update all call sites in the same change when signatures move.

10. **Verify**
   - Analyzer clean on touched files.
   - `{PATTERN_TEST}` green.
   - Run focused Flutter widget/controller/DTO tests plus backend tests for every touched stack layer. Add missing tests; never rely on production services or secrets.
   - Load happy-path succeeds; cancel/failure neither patches nor dismisses as saved.
   - Verify responsive, keyboard, focus, semantics, text-scale, and dark-mode behavior for changed dialog UI.
   - Equivalent detail viewers share primitives, spacing, sections, action icons/labels, loading/error behavior, and responsive layout.
   - Tick every checklist item above before finishing.

## Acceptance criteria (all must pass)

1. `{symbol}` opens only through `AppDialog` / `AppPatientDetailDialog` / approved helpers — no raw Material dialog APIs.
2. {action_acceptance}
3. Loading uses only shared spinner primitives; dismiss and competing actions are blocked while in flight.
4. Title is general, uppercase-normalized, and never a personal name.
5. All copy is localized; all styling/formatting uses shared tokens/formatters; responsive and accessible behavior is verified.
6. Body sections reuse canonical shared detail primitives; no unjustified local forks (siblings considered: {siblings_md}).
7. Still reachable from inventory openers / *Used from* sites with contextual IDs and permissions intact.
8. {backend_acceptance}
9. {sync_acceptance}
10. `{PATTERN_TEST}` remains green; focused frontend/backend tests cover this dialog's critical path.

## Out of scope

- Other inventory rows (unless a minimal shared extract is required for reuse).
- New dialog frameworks, unrelated redesigns, or drive-by refactors outside `{symbol}`'s path.
- Client-only "saved" state not backed by HTTP success.
- Retaining duplicate local UI solely to shrink the diff.
- Inventing mutations on a read-only detail viewer.

## Deliverable

Implement the compliance fixes in the repo. Summarize: files changed; shell/title/footer/loading/reuse/sync fixes; design/localization/accessibility fixes; shared extracts; API/DTO/route fixes; tests added and run; exact commands and results; remaining risks (or explicitly state none). Append the project rule files applied and the model used.

<!-- generator: detail-viewer prompt {idx:02d} slug={slug} symbol={symbol} shape={shape} -->
"""


def main() -> None:
    PROMPTS.mkdir(parents=True, exist_ok=True)
    # Remove previously generated detail-viewer prompts only (keep prompt.md).
    for old in list(PROMPTS.glob("*.md")):
        if old.name == "prompt.md":
            continue
        try:
            text = old.read_text(encoding="utf-8")
        except OSError:
            continue
        if "generator: detail-viewer prompt" in text or re.match(
            r"^\d{2}-.+\.md$", old.name
        ):
            old.unlink()

    rows = [base.enrich_inventory_row(row) for row in parse_inventory()]
    if len(rows) != 52:
        raise SystemExit(f"Expected 52 inventory rows, found {len(rows)}")
    refresh_inventory(rows)
    for row in rows:
        row["line"] = row["source_line"]
        row["line_drift"] = False

    briefs: dict[str, dict] = {}
    for row in rows:
        module = base.module_hint(row["path"])
        siblings = module_siblings(rows, row["symbol"], module)
        brief = default_brief(row, siblings)
        override = DIALOG_BRIEFS.get(row["symbol"])
        if override:
            brief = {**brief, **override}
            if "siblings" not in override:
                brief["siblings"] = siblings
            if "focus" in override:
                brief["focus"] = override["focus"]
        briefs[row["symbol"]] = brief

    index_lines = [
        "# Detail viewers — dialog prompts",
        "",
        "One actionable agent prompt per inventory row in "
        "[`03-detail-viewers.md`](03-detail-viewers.md).",
        f"Normative contract: [`../{CONTRACT}`](../{CONTRACT}) "
        f"(also [`../{API_CONTRACT}`](../{API_CONTRACT}), "
        f"[`../{SYNC_RULE}`](../{SYNC_RULE}), "
        f"[`../{COMPONENTS_RULE}`](../{COMPONENTS_RULE})).",
        "",
        "Prompt files live in [`../prompts/detail-viewers/`](../prompts/detail-viewers/) "
        "(named `NN-<dialog-slug>.md`). Keep this index here so it is not mistaken "
        "for an implementation brief.",
        "",
        "Each prompt is generated to be actionable, professional, contextual, "
        "specific, and complete against `prompts/detail-viewers/prompt.md` "
        "(shells, shared detail-component reuse, loading/actions, titles, "
        "backend sync, verification).",
        "",
        "Regenerate with:",
        "",
        "```bash",
        "python tool/generate_detail_viewer_prompts.py",
        "```",
        "",
        "| # | Prompt | Symbol | Purpose |",
        "| --- | --- | --- | --- |",
    ]

    used_names: set[str] = set()
    for i, row in enumerate(rows, start=1):
        peek = base.peek_dialog_context(
            row["path"],
            row["symbol"],
            row["source_line"],
            sorted(set(row["openers"] + row.get("detected_openers", []))),
            sorted(
                set(
                    row.get("validated_used", [])
                    + row.get("discovered_used", [])
                )
            ),
        )
        brief = briefs[row["symbol"]]
        body = build_prompt(i, row, peek, brief)
        module = base.module_hint(row["path"])
        slug = slugify(row["symbol"], module)
        name = f"{i:02d}-{slug}.md"
        if name in used_names:
            raise SystemExit(f"Duplicate prompt filename: {name}")
        used_names.add(name)
        (PROMPTS / name).write_text(body, encoding="utf-8", newline="\n")
        index_lines.append(
            f"| {i:02d} | [`../prompts/detail-viewers/{name}`]"
            f"(../prompts/detail-viewers/{name}) | "
            f"`{row['symbol']}` | {clean_purpose(row['purpose'])} |"
        )
        print(f"wrote {name}")

    INDEX.write_text("\n".join(index_lines) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote index {INDEX.name} ({len(rows)} prompts)")


if __name__ == "__main__":
    main()
