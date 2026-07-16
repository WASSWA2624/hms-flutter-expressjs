"""Generate table-standardization prompt generator files."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "prompt-generators"
OUT.mkdir(exist_ok=True)

SCREENS = [
    {
        "num": "01",
        "slug": "patients",
        "name": "Patients",
        "route": "/patients",
        "page": "PatientRegistryPage",
        "file": "frontend/lib/features/patients/presentation/pages/patient_registry_page.dart",
        "module": "patients",
        "tabs": "All patients, Active, Admitted, Balance due",
        "purpose": "Patient registry worklist filtered by status and billing balance.",
        "query": "?section=<value>",
        "tables": [("_PatientList", "patient_registry_page.dart", "Patient", 7)],
        "workflow": True,
        "detail": "showPatientDetailDialog",
        "ref": "emergency (WorkflowActionButton) + mortuary (search chrome)",
    },
    {
        "num": "02",
        "slug": "reception",
        "name": "Reception",
        "route": "/reception",
        "page": "ReceptionWorkspacePage",
        "file": "frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart",
        "module": "reception",
        "tabs": "Appointments, Queue, Active visits, Payment gate",
        "purpose": "Front-desk appointments, queue, active visits, and payment gate.",
        "query": "?section=<value>",
        "tables": [
            (
                "_ReceptionDeskTable (inline in _ReceptionWorkspaceContentState)",
                "reception_workspace_page.dart",
                "_ReceptionDeskRow",
                4,
            )
        ],
        "workflow": True,
        "detail": "openReceptionPatientEditor",
        "ref": "mortuary (_MortuaryWorklist Filters/Settings chrome)",
    },
    {
        "num": "03",
        "slug": "opd",
        "name": "OPD",
        "route": "/opd",
        "page": "OpdWorkspacePage",
        "file": "frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart",
        "module": "opd",
        "tabs": "All, Arrivals, Queue, Triage, Active",
        "purpose": "Outpatient department encounter worklist and triage queue.",
        "query": "?scope=<value>",
        "tables": [("_OpdMainTable", "opd_workspace_page.dart", "_OpdTableItem", 5)],
        "workflow": True,
        "detail": "_openTableItemActions",
        "ref": "emergency (next-action column)",
    },
    {
        "num": "04",
        "slug": "emergency",
        "name": "Emergency",
        "route": "/emergency",
        "page": "EmergencyWorkspacePage",
        "file": "frontend/lib/features/emergency/presentation/pages/emergency_workspace_page.dart",
        "module": "emergency",
        "tabs": "Active cases, Critical, Ambulance, Handoff ready, Closed, All",
        "purpose": "Emergency case board and ambulance workflow.",
        "query": "?scope=<value>",
        "tables": [
            (
                "Emergency worklist table in _EmergencyWorkspaceContentState",
                "emergency_workspace_page.dart",
                "EmergencyCaseSummary",
                6,
            )
        ],
        "workflow": True,
        "detail": "openEmergencyDetailDialog",
        "ref": "emergency_workspace_widgets.dart (emergencyNextActionColumn)",
    },
    {
        "num": "05",
        "slug": "ipd",
        "name": "IPD",
        "route": "/ipd",
        "page": "IpdWorkspacePage",
        "file": "frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart",
        "module": "ipd",
        "tabs": "Admission queue, Active patients, Transfers, Discharge, Bed board",
        "purpose": "Inpatient admissions, transfers, discharge, and bed board.",
        "query": "?panel=<value>",
        "tables": [
            ("_IpdBoardPanel", "ipd_workspace_page.dart", "IpdAdmissionSummary", 7),
            ("_IpdBedBoardPanel", "ipd_bed_board_panel.dart", "IpdBedBoardEntry", 5),
        ],
        "workflow": True,
        "detail": "_openIpdDetailDialog",
        "ref": "_IpdBedBoardPanel (5 columns)",
    },
    {
        "num": "06",
        "slug": "rooms-beds",
        "name": "Rooms & Beds",
        "route": "/rooms-beds",
        "page": "RoomsBedsWorkspacePage",
        "file": "frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart",
        "module": "rooms_beds",
        "tabs": "Bed board, Wards, Rooms",
        "purpose": "Bed inventory, ward structure, and room management.",
        "query": "?view=<value>",
        "tables": [
            (
                "Bed board table in _RoomsBedsWorkspaceContentState",
                "rooms_beds_workspace_page.dart",
                "BedBoardItem",
                5,
            )
        ],
        "workflow": True,
        "detail": "_openBedDetailDialog",
        "ref": "rooms_beds_workspace_page.dart",
    },
    {
        "num": "07",
        "slug": "icu",
        "name": "ICU",
        "route": "/icu",
        "page": "IcuWorkspacePage",
        "file": "frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart",
        "module": "icu",
        "tabs": "Active, Critical, Transfer, Discharge, Ended, All",
        "purpose": "ICU patient board and critical-care workflow.",
        "query": "?scope=<value>",
        "tables": [("_IcuBoardPanel", "icu_workspace_page.dart", "IcuPatientSummary", 7)],
        "workflow": True,
        "detail": "_openIcuDetailDialog",
        "ref": "nursing_worklist_panel.dart",
    },
    {
        "num": "08",
        "slug": "nursing",
        "name": "Nursing",
        "route": "/nursing",
        "page": "NursingWorkspacePage",
        "file": "frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart",
        "module": "nursing",
        "tabs": "All, Assigned ward, Urgent, Medication due, Handover pending, Transfer pending, Discharge pending",
        "purpose": "Nursing worklist across wards and care tasks.",
        "query": "?filter=<value>",
        "tables": [
            ("NursingWorklistPanel", "nursing_worklist_panel.dart", "NursingWorkItem", 5)
        ],
        "workflow": True,
        "detail": "openNursingPatientDetailDialog",
        "ref": "nursing_worklist_panel.dart",
    },
    {
        "num": "09",
        "slug": "clinical",
        "name": "Clinical",
        "route": "/clinical",
        "page": "ClinicalWorkspacePage",
        "file": "frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart",
        "module": "clinical",
        "tabs": "All, Waiting review, Urgent, Results ready, My patients",
        "purpose": "Clinical review worklist and results triage.",
        "query": "?filter=<value>",
        "tables": [
            ("_ClinicalWorklistPanel", "clinical_workspace_page.dart", "ClinicalWorklistEntry", 5)
        ],
        "workflow": True,
        "detail": "_openClinicalEntryDialog",
        "ref": "radiology _RadiologyWorklistPanel",
    },
    {
        "num": "10",
        "slug": "physiotherapy",
        "name": "Physiotherapy",
        "route": "/physiotherapy",
        "page": "PhysiotherapyWorkspacePage",
        "file": "frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart",
        "module": "physiotherapy",
        "tabs": "All, Scheduled, In progress, Completed",
        "purpose": "Therapy session scheduling and progress tracking.",
        "query": "?status=<value>",
        "tables": [
            ("_PhysiotherapyWorkspace table", "physiotherapy_workspace_page.dart", "TherapyWorkItem", 5)
        ],
        "workflow": True,
        "detail": "_openTherapyDetailDialog",
        "ref": "physiotherapy_workspace_page.dart",
    },
    {
        "num": "11",
        "slug": "lab",
        "name": "Laboratory",
        "route": "/lab",
        "page": "LabWorkspacePage",
        "file": "frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart",
        "module": "lab",
        "tabs": "Worklist, Collection, Processing, Verification, Critical, Completed",
        "purpose": "Lab order worklist across collection through verification.",
        "query": "?stage=<value>",
        "tables": [("_LabWorklistPanel", "lab_workspace_page.dart", "LabOrderSummary", 9)],
        "workflow": True,
        "detail": "_openLabDetailDialog",
        "ref": "mortuary (_MortuaryWorklist)",
    },
    {
        "num": "12",
        "slug": "radiology",
        "name": "Radiology",
        "route": "/radiology",
        "page": "RadiologyWorkspacePage",
        "file": "frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart",
        "module": "radiology",
        "tabs": "Worklist, Reporting, Released, All orders",
        "purpose": "Radiology order worklist and reporting queue.",
        "query": "?panel=<value>",
        "tables": [
            ("_RadiologyWorklistPanel", "radiology_workspace_page.dart", "RadiologyOrder", 5)
        ],
        "workflow": True,
        "detail": "_openRadiologyDetailDialog",
        "ref": "radiology_workspace_page.dart",
    },
    {
        "num": "13",
        "slug": "pharmacy",
        "name": "Pharmacy",
        "route": "/pharmacy",
        "page": "PharmacyWorkspacePage",
        "file": "frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart",
        "module": "pharmacy",
        "tabs": "Ready queue, In progress, Pending payment, Completed, All orders",
        "purpose": "Pharmacy dispensing queue, stock, and returns.",
        "query": "?queue=<value>",
        "tables": [
            ("_PharmacyQueuePanel", "pharmacy_workspace_page.dart", "PharmacyOrder", 7),
            ("_MedicationItemsPanel", "pharmacy_workspace_page.dart", "PharmacyOrderItem", 4),
            ("_DrugStockPanel", "pharmacy_workspace_page.dart", "PharmacyDrug", 5),
            ("_ReturnMedicationsTable", "pharmacy_workspace_page.dart", "_LineEditState", 4),
        ],
        "workflow": True,
        "detail": "_openPharmacyDetailDialog",
        "ref": "mortuary (_MortuaryWorklist)",
    },
    {
        "num": "14",
        "slug": "billing",
        "name": "Billing",
        "route": "/billing",
        "page": "BillingWorkspacePage",
        "file": "frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart",
        "module": "billing",
        "tabs": "All, Needs issue, Pending payment, Claims pending, Approval required, Overdue",
        "purpose": "Billing queue, invoices, and payment follow-up.",
        "query": "?filter=<value>",
        "tables": [("_BillingQueuePanel", "billing_workspace_page.dart", "BillingWorkItem", 7)],
        "workflow": True,
        "detail": "_showBillingDetailDialog",
        "ref": "mortuary (_MortuaryWorklist)",
    },
    {
        "num": "15",
        "slug": "claims",
        "name": "Claims",
        "route": "/claims",
        "page": "ClaimsWorkspacePage",
        "file": "frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart",
        "module": "claims",
        "tabs": "Authorizations, Active claims, Settled, Insurance setup",
        "purpose": "Insurance authorizations, claims, and payer setup.",
        "query": "?panel=<value>",
        "tables": [("_ClaimsQueuePanel", "claims_workspace_page.dart", "ClaimsQueueItem", 6)],
        "workflow": True,
        "detail": "_openClaimsDetailDialog",
        "ref": "mortuary (_MortuaryWorklist)",
    },
    {
        "num": "16",
        "slug": "discharge",
        "name": "Discharge",
        "route": "/discharge",
        "page": "DischargeWorkspacePage",
        "file": "frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart",
        "module": "discharge",
        "tabs": "All, Planned, Pending clearance, Completed",
        "purpose": "Discharge planning and clearance workflow.",
        "query": "?status=<value>",
        "tables": [
            (
                "Discharge worklist in _DischargeWorkspaceContentState",
                "discharge_workspace_page.dart",
                "IpdAdmissionSummary",
                5,
            )
        ],
        "workflow": True,
        "detail": "_openDischargeDetailDialog",
        "ref": "discharge_workspace_page.dart",
    },
    {
        "num": "17",
        "slug": "theater",
        "name": "Theater",
        "route": "/theater",
        "page": "TheaterWorkspacePage",
        "file": "frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart",
        "module": "theater",
        "tabs": "Scheduled, In theater, Recovery, All",
        "purpose": "Operating theater case scheduling and progression.",
        "query": "?scope=<value>",
        "tables": [("_TheaterCaseBoard", "theater_workspace_page.dart", "TheaterCase", 9)],
        "workflow": True,
        "detail": "_openTheaterCaseDialog",
        "ref": "emergency (WorkflowActionButton)",
    },
    {
        "num": "18",
        "slug": "operations",
        "name": "Operations",
        "route": "/operations",
        "page": "OperationsWorkspacePage",
        "file": "frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart",
        "module": "operations",
        "tabs": "All requests, Open, In progress, Completed, Assets",
        "purpose": "Facilities operations requests and asset registry.",
        "query": "?panel=<value>",
        "tables": [
            ("_OperationsQueuePanel", "operations_workspace_page.dart", "OperationsWorkItem", 5),
            ("_OperationsAssetsPanel", "operations_workspace_page.dart", "OperationsAsset", 4),
        ],
        "workflow": True,
        "detail": "_openRequestDetailDialog",
        "ref": "operations_workspace_page.dart",
    },
    {
        "num": "19",
        "slug": "housekeeping",
        "name": "Housekeeping",
        "route": "/housekeeping",
        "page": "HousekeepingWorkspacePage",
        "file": "frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart",
        "module": "housekeeping",
        "tabs": "Tasks, Schedules, Maintenance",
        "purpose": "Housekeeping tasks, schedules, and maintenance.",
        "query": "?panel=<value>",
        "tables": [
            (
                "_HousekeepingWorklistPanel",
                "housekeeping_workspace_page.dart",
                "HousekeepingWorkItem",
                5,
            )
        ],
        "workflow": True,
        "detail": "_openTaskDetailDialog",
        "ref": "housekeeping_workspace_page.dart",
    },
    {
        "num": "20",
        "slug": "hr",
        "name": "HR",
        "route": "/hr",
        "page": "HrWorkspacePage",
        "file": "frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart",
        "module": "hr",
        "tabs": "Staff directory, Work queue, Rosters, Leave, Compensation, Activity",
        "purpose": "HR staff directory, work queue, and workforce admin.",
        "query": "?section=<value>",
        "tables": [
            ("_HrStaffDirectory", "hr_workspace_page.dart", "HrStaffProfile", 5),
            ("_HrWorkQueueTable", "hr_workspace_page.dart", "HrWorkItem", 5),
        ],
        "workflow": True,
        "detail": "showHrStaffDetailDialog",
        "ref": "_HrStaffDirectory",
    },
    {
        "num": "21",
        "slug": "biomedical",
        "name": "Biomedical",
        "route": "/biomedical",
        "page": "BiomedicalWorkspacePage",
        "file": "frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart",
        "module": "biomedical",
        "tabs": "Overview, Registry, Preventive, Work orders, Compliance, Support, Analytics",
        "purpose": "Biomedical asset registry and maintenance work orders.",
        "query": "?panel=<value>",
        "tables": [
            (
                "Asset worklist in _BiomedicalWorkspaceContentState",
                "biomedical_workspace_page.dart",
                "BiomedicalAsset",
                6,
            )
        ],
        "workflow": True,
        "detail": "_openAssetDetailDialog",
        "ref": "biomedical_workspace_page.dart",
    },
    {
        "num": "22",
        "slug": "communications",
        "name": "Communications",
        "route": "/communications",
        "page": "CommunicationsWorkspacePage",
        "file": "frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart",
        "module": "communications",
        "tabs": "Notifications, Deliveries, Templates",
        "purpose": "Notification inbox, delivery log, and templates.",
        "query": "?panel=<value>",
        "tables": [
            ("_NotificationsTable", "communications_workspace_page.dart", "NotificationItem", 5),
            ("_DeliveriesTable", "communications_workspace_page.dart", "NotificationDelivery", 5),
            ("_TemplatesTable", "communications_workspace_page.dart", "CommunicationTemplate", 4),
        ],
        "workflow": True,
        "detail": "audit inline selection vs modal detail on row tap",
        "ref": "mortuary (_MortuaryWorklist)",
    },
    {
        "num": "23",
        "slug": "integrations",
        "name": "Integrations",
        "route": "/integrations",
        "page": "IntegrationsWorkspacePage",
        "file": "frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart",
        "module": "integrations",
        "tabs": "Integrations, API keys, Webhooks, Logs, Interop",
        "purpose": "Integration connectors, keys, webhooks, and logs.",
        "query": "?panel=<value>",
        "tables": [
            (
                "_IntegrationWorklistPanel",
                "integrations_workspace_page.dart",
                "IntegrationWorkItem",
                5,
            )
        ],
        "workflow": True,
        "detail": "_openIntegrationDetailDialog",
        "ref": "mortuary (_MortuaryWorklist)",
    },
    {
        "num": "24",
        "slug": "subscriptions",
        "name": "Subscriptions",
        "route": "/subscriptions",
        "page": "SubscriptionsWorkspacePage",
        "file": "frontend/lib/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart",
        "module": "subscriptions",
        "tabs": "Overview, Tenants, Plans, Subscriptions, Modules, Notifications",
        "purpose": "SaaS tenant subscriptions and plan administration.",
        "query": "?panel=<value>",
        "tables": [
            (
                "_SubscriptionsWorklistPanel",
                "subscriptions_workspace_page.dart",
                "SubscriptionItem",
                4,
            )
        ],
        "workflow": False,
        "detail": "_openSubscriptionDetailDialog",
        "ref": "mortuary (_MortuaryWorklist)",
    },
    {
        "num": "25",
        "slug": "access-admin",
        "name": "Access Admin",
        "route": "/admin/access",
        "page": "AccessAdminWorkspacePage",
        "file": "frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart",
        "module": "access_admin",
        "tabs": "Users, Roles, Permissions, Registrations",
        "purpose": "User access, roles, permissions, and registrations.",
        "query": "?panel=<value>",
        "tables": [("_WorklistPanel", "access_admin_workspace_page.dart", "AccessAdminItem", 5)],
        "workflow": False,
        "detail": "audit per-tab management dialogs on row select",
        "ref": "mortuary (_MortuaryWorklist)",
    },
    {
        "num": "26",
        "slug": "reports",
        "name": "Reports",
        "route": "/reports",
        "page": "ReportsWorkspacePage",
        "file": "frontend/lib/features/reports/presentation/pages/reports_workspace_page.dart",
        "module": "reports",
        "tabs": "Overview, Catalog, Delivery, Dashboards, Monitor, Activity, Audit, PHI, Processing",
        "purpose": "Report catalog, schedules, compliance logs, and monitoring.",
        "query": "?panel=<value>",
        "tables": [
            ("_ReportItemsPanel", "reports_workspace_page.dart", "ReportsWorkspaceItem", 5),
            ("_ComplianceLogPanel", "reports_workspace_page.dart", "ComplianceLogItem", 5),
            ("_ReportSchedulesPanel", "reports_workspace_page.dart", "ReportsWorkspaceItem", 4),
        ],
        "workflow": True,
        "detail": "audit per tab for detail dialog on row tap",
        "ref": "mortuary (_MortuaryWorklist)",
    },
    {
        "num": "27",
        "slug": "mortuary",
        "name": "Mortuary",
        "route": "/mortuary",
        "page": "MortuaryWorkspacePage",
        "file": "frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart",
        "module": "mortuary",
        "tabs": "Cases, Storage, Releases, Audit",
        "purpose": "Mortuary case registry, storage, and release workflow.",
        "query": "?panel=<value>",
        "tables": [("_MortuaryWorklist", "mortuary_workspace_page.dart", "MortuaryWorkspaceItem", 7)],
        "workflow": True,
        "detail": "onItemSelected → mortuary detail dialog",
        "ref": "_MortuaryWorklist (chrome reference; reduce columns to ≤5)",
    },
]


def resolve_table_path(screen: dict, fname: str) -> str:
    if fname.endswith("_panel.dart") or "worklist" in fname:
        return f"frontend/lib/features/{screen['module']}/presentation/widgets/{fname}"
    return f"frontend/lib/features/{screen['module']}/presentation/pages/{fname}"


def table_rows(screen: dict) -> str:
    rows: list[str] = []
    for index, (widget, fname, entity, count) in enumerate(screen["tables"], 1):
        path = resolve_table_path(screen, fname)
        rows.append(
            f"| {index} | {widget} | `{path}` | `{entity}` | {count} (audit exact) | [discover during audit] |"
        )
    header = (
        "| # | Table widget | File | Entity | Columns today | Detail on row select |\n"
        "|---|--------------|------|--------|---------------|----------------------|"
    )
    return header + "\n" + "\n".join(rows)


def workflow_section(screen: dict) -> str:
    if screen["workflow"]:
        return (
            "- **Status column (second from right):** `AppWorkspaceStatusBadge` with formatted label.\n"
            "- **Next-action column (rightmost):** explicit verb label per workflow stage; prefer "
            "`WorkflowActionButton` when applicable.\n"
            "- Press opens contextual dialog or deep-links to the precise tab/screen — never a generic module home."
        )
    return (
        "- This screen's entities may not use workflow status. Apply up to five priority data columns only.\n"
        "- Do **not** add generic status/action columns unless the audit confirms workflow state on the entity."
    )


def render(screen: dict) -> str:
    route_path = screen["route"].lstrip("/")
    workflow_label = "Yes" if screen["workflow"] else "No (data-only tables)"
    return f"""/{route_path}

---

# Table Standardization Prompt Generator — {screen["name"]}

You are a coding AI agent acting as a **prompt generator**. Your job is to audit the codebase for the **{screen["name"]}** screen, then produce a comprehensive, context-aware refactoring prompt that another coding AI agent can execute autonomously — and save that prompt to `prompts/{screen["num"]}-{screen["slug"]}-prompt.md` (same name as this generator file, without `-generator`).

The generated prompt **MUST** be fully compliant with the table rules in `prompt.md` (Table Standardization). Every acceptance criterion in the generated prompt must map back to those rules.

## Pre-filled screen context (do not invent alternatives)

| Field | Value |
|-------|-------|
| Route | `{screen["route"]}` |
| Screen name | {screen["name"]} |
| Page widget | `{screen["page"]}` |
| Primary page file | `{screen["file"]}` |
| Feature module | `{screen["module"]}` |
| Known tabs | {screen["tabs"]} |
| Purpose | {screen["purpose"]} |
| Has workflow status columns | {workflow_label} |
| Row detail handler (starting point) | `{screen["detail"]}` |

- Deep-link query parameter pattern: `{screen["query"]}`

### Known table inventory (validate and complete during audit)

{table_rows(screen)}

The executing agent that runs your generated prompt must:
- Have full read/write access to the codebase.
- Be able to create, modify, and delete files.
- Be able to run shell commands (tests, linting, formatting).
- Operate without human clarification — all instructions must be unambiguous and self-contained.
- Receive explicit file paths, exact class/widget names, column definitions, and concrete code patterns.

---

## Mandatory compliance source: `prompt.md`

Before generating anything, read `prompt.md` at the repository root. The generated prompt **must enforce all of the following** for **{screen["name"]}** (`{screen["route"]}`) — **for every `AppListTable` on this screen**:

### §1 Search chrome
- Global search bar matching all declared columns (visible and hidden).
- Search bar trailing controls limited to **Filters** (opens **Advanced filters** modal) and **Settings** (opens **Table Settings** modal).
- `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` (`Settings`); set `columnVisibilityTitle` to **Table Settings**.
- Session-persisted column visibility via `AppListTableColumnVisibilityController` + stable `columnVisibilityStorageKey` per table.

### §2 Column content
- One semantic field per column; allowed two-line primary/subtitle for a single field via `AppListItemText` / `bodySmall`.
- No duplicate or merged unrelated fields in one column.

### §3 Column layout
- Do **not** declare a row-number column (`AppListTable` adds it automatically).
- Maximum **five** entries in each table's `columns` array.
- When workflow applies: three priority data columns + status + explicit next-action column.
- When no workflow: up to five priority data columns; extras belong in `columnChoices` (hidden by default).

### §4 Status and next-action
{workflow_section(screen)}

### §5 Row selection
- `onRowSelected` / row tap opens a modal detail dialog reusing existing feature/shared dialogs.
- Detail dialog exposes follow-up actions aligned with the next-action column.

### §6 Responsiveness
- `displayMode: AppListTableDisplayMode.adaptive` and a `mobileItemBuilder` mirroring desktop priority fields, status, and actions.

### §7 Shared components
- Build on `AppListTable`, `AppListTableSearch`, `AppListTableColumn` from `frontend/lib/shared/components/app_list_table.dart`.
- Distinct `columnVisibilityStorageKey` and `columnWidthStorageKey` when multiple tables exist on one screen.

### §8 Real-time freshness
- Table data flows from Riverpod providers with WebSocket/sync reconciliation (`frontend/.cursor/realtime_sync.mdc`, `frontend/.cursor/instant_ui_sync.mdc`).

**Objective:** Every worklist table on {screen["name"]} must match the same chrome, column budget, interaction model, and freshness behavior defined in `prompt.md`.

---

## Step 1: Codebase Discovery (mandatory — do this first)

Perform a full audit focused on `{screen["route"]}` / `{screen["page"]}`.

### 1.1 Locate the target screen

- Start at `{screen["file"]}` and walk all imports: widgets, controllers, providers, repositories, models, routes, dialogs, and tests under `frontend/lib/features/{screen["module"]}/`.
- Map every `AppListTable` instance (widget class, file, entity type, tab/panel binding).
- Document current columns per table: `id`, label, field mapped, sort comparator, cell builder pattern.

### 1.2 Audit reference implementations (read only)

Read these files before generating the prompt:

- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` (`_MortuaryWorklist` — Filters/Settings chrome)
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` (`emergencyNextActionColumn`, `WorkflowActionButton`)
- Closest on-screen reference: **{screen["ref"]}**
- `prompt.md`

Extract:
- How `AppListTableSearch` wires Filters (`showAdvancedFilterButton`, `filterGroups`, `advancedFilterTitle`).
- How Settings opens column visibility (`columnVisibilityController`, `columnVisibilityTitle`).
- How next-action buttons and status badges are rendered.
- How `onRowSelected` opens `{screen["detail"]}`.
- Current column count vs the five-column budget.

### 1.3 Inventory shared components to reuse

Locate and list exact import paths for:

- `AppListTable` / `AppListTableColumn` / `AppListTableSearch`
- `AppListTableColumnVisibilityController` + `AppListTableColumnVisibilityMemory`
- `AppWorkspaceStatusBadge` / `WorkflowActionButton` (if workflow entity)
- `AppListItemText` for two-line cells
- Existing detail dialogs in `frontend/lib/features/{screen["module"]}/presentation/`

### 1.4 Gap analysis vs `prompt.md`

For **each table** on this screen, produce a concrete gap list, for example:

- Column count exceeds five defaults
- Combined unrelated fields in one column (name + ID, status + date, etc.)
- Search bar missing or not matching hidden columns
- Extra trailing actions in search chrome (export, refresh, overflow)
- Filters/Settings labels or modal titles non-standard
- Missing `columnVisibilityStorageKey` / session persistence
- Generic next-action label (`Next step`, `Action`) instead of explicit verb
- `onRowSelected` missing or navigates away instead of opening detail dialog
- No `mobileItemBuilder` or missing status/action on mobile
- Table not wired to realtime provider refresh

### 1.5 Per-tab / per-panel table matrix

Document how each tab switches table content and which columns differ per tab.

### 1.6 Domain-specific requirements

- Entities, providers, and API surfaces this screen uses.
- Validate known tabs against enums / section models in code; correct labels if l10n differs.
- Workflow stages and the explicit next-action label per stage (if applicable).
- Behaviors that must be preserved (permissions, counts, pagination, deep links, dialogs).

### 1.7 Migrations

- Check whether schema/API changes are required. Prefer "No database migrations required" unless the audit proves otherwise.

---

## Step 2: Generate the Prompt

Produce a self-contained refactoring prompt for a coding AI agent. It must not require re-discovery of basics already known from this generator, but it **must** include the concrete audit findings (exact symbols, files, per-table columns, and per-tab differences).

### Generated prompt structure (exact)

```markdown
# Standardize {screen["name"]} Tables

## Objective

Refactor every `AppListTable` on the {screen["name"]} workspace (`{screen["route"]}`, `{screen["page"]}`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

## Compliance Checklist (from prompt.md — per table)

- [ ] Global search matches all columns (including hidden)
- [ ] Search chrome has only Filters (Advanced filters modal) and Settings (Table Settings modal)
- [ ] Session-persisted column visibility via `AppListTableColumnVisibilityController`
- [ ] ≤ 5 declared columns; automatic row number only
- [ ] One semantic field per column; two-line display only for primary/secondary of one field
- [ ] Status + explicit next-action columns when entity has workflow
- [ ] Row tap opens reused detail dialog with follow-up actions
- [ ] Adaptive layout + `mobileItemBuilder` parity
- [ ] Real-time refresh via Riverpod providers

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every
step below precisely. Do not skip steps. Do not ask for clarification. Run tests and formatting
after implementation. Treat `prompt.md` as the normative table contract.

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, or unrelated screen chrome unless required for compilation.

## Current State (from audit)

[Per-table: widget, file, entity, current columns, search chrome, gaps vs prompt.md]

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` (`_MortuaryWorklist`)
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart`
- `prompt.md`

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey |
|--------------|-------------|--------|-----------------------------------|----------------------------|
| ...          | ...         | ...    | ...                               | ...                        |

### Column plan (per table)

| Position | Column id | Label | Source field | Notes |
|----------|-----------|-------|--------------|-------|
| 1–3      | ...       | ...   | ...          | priority data |
| 4        | status    | ...   | ...          | if workflow |
| 5        | next_action | ... | ...          | explicit `WorkflowActionButton` or module equivalent |

### Search chrome (per table)

- `AppListTableSearch` matcher covering all column fields + hidden `columnChoices`
- Filters: label `Filters`, modal title `Advanced filters`
- Settings: `commonTableSettingsActionLabel`, modal title `Table Settings`

### Row interaction

- `onRowSelected` → `{screen["detail"]}` (or audited replacement)
- Next-action column uses same handler destination as detail dialog actions

## Implementation Steps

1. **[Table 1]** — File: `[exact path]`
   - Reduce/reorder columns to ≤5 defaults; move extras to `columnChoices`
   - ...

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| ...       | ...         | ...   |

## Files to Create / Modify / Delete

[Tables]

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only (per locale rule)
- Prefer shared keys: `commonTableSettingsActionLabel`, shared Filters/Advanced filters keys

## Database Migrations

[Required migrations OR explicit "No database migrations required — schema unchanged."]

## Verification Steps

    cd frontend
    dart format .
    dart analyze --fatal-infos
    flutter test test/features/{screen["module"]}/

## Testing Requirements

- [ ] Each table: search, Filters, Settings only in chrome
- [ ] Column visibility persists for session per table key
- [ ] ≤5 default columns; row number automatic
- [ ] Workflow tables: explicit status + next-action labels
- [ ] Row tap opens detail dialog
- [ ] Mobile list shows same priority fields
- [ ] Realtime refresh still updates rows after mutations/events
- [ ] Permissions still gate write actions

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for every table on this screen
- [ ] Domain logic preserved
- [ ] Analyze clean; tests pass
```

---

## Step 3: Save the Output

- **Output path (fixed):** `prompts/{screen["num"]}-{screen["slug"]}-prompt.md`
- This mirrors this generator file (`prompt-generators/{screen["num"]}-{screen["slug"]}-prompt-generator.md`) with `-generator` removed from the filename.
- **Replace/update** that file if it already exists; do not invent a different name or numeric prefix.
- Do not save under alternate names such as `standardize-*-tables.md` unless you are explicitly retiring a legacy file — in that case, note the legacy path at the top of the new prompt and delete or redirect the old file.

---

## Rules

1. **Never generate a generic prompt.** Every section must cite real paths, classes, providers, column ids, and per-tab table bindings discovered in the audit of `{screen["page"]}`.
2. **Do not guess.** If something is missing, instruct the executing agent to follow Mortuary + Emergency references + `prompt.md`, with the exact pattern to copy.
3. **Preserve domain logic.** Restructure table chrome/columns/row interactions only; keep {screen["name"]} business behavior.
4. **Reuse over reinvention.** Forbid new table/search/filter implementations when `AppListTable` and shared widgets exist.
5. **Be specific.** Exact imports, constructors, parameters, l10n keys, storage keys, and column ids.
6. **prompt.md is non-negotiable.** The generated prompt's acceptance criteria must include the full per-table compliance checklist above.
7. **Agent-executable.** No follow-up questions required.
8. **Include verification.** Concrete shell commands and tests under `test/features/{screen["module"]}/`.
9. **Multi-table screens.** Generate steps and checklists for **each** table widget separately.

---

## Usage

This file is already bound to **{screen["name"]}** (`{screen["route"]}`). Run it as a prompt. The generator agent will:

1. Audit `{screen["file"]}` and related `{screen["module"]}` files against Mortuary/Emergency references + `prompt.md`.
2. Produce a self-contained, agent-executable table-standardization prompt.
3. Save it to `prompts/{screen["num"]}-{screen["slug"]}-prompt.md`.
"""


def main() -> None:
    for screen in SCREENS:
        out = OUT / f"{screen['num']}-{screen['slug']}-prompt-generator.md"
        out.write_text(render(screen), encoding="utf-8")
        print(out.name)
    print(f"Wrote {len(SCREENS)} files to {OUT}")


if __name__ == "__main__":
    main()
