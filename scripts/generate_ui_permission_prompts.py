#!/usr/bin/env python3
"""Generate per-tab UI permission-enforcement prompts under prompts/ui-permissions/."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "prompts" / "ui-permissions"

# Shared vocabulary helpers used in matrices (AppPermissions keys).
# Semantics:
#   all = intersection (grantsAll / AccessRequirement.allPermissions)
#   any = union (grantsAny / AccessRequirement.anyPermissions)

SCREENS: list[dict] = [
    {
        "slug": "patients",
        "route": "/patients",
        "title": "Patients registry",
        "inventory": "screens/patients.md",
        "feature": "frontend/lib/features/patients/",
        "module": "patient-registry",
        "route_any": ["patient:read"],
        "defaults": {
            "read_all": ["patient:read"],
            "create_all": ["patient:write"],
            "update_all": ["patient:write"],
            "delete_all": ["patient:delete"],
            "notes": (
                "Nested Quick Actions use their module rights: OPD/admit need "
                "clinical + encounter gates; lab/radiology/theater/physio need "
                "matching write/request rights; insurance/billing chips need "
                "billing:read/write; reports need reports:read. "
                "Show a chip only when every listed right is held (intersection)."
            ),
        },
        "tabs": [
            {
                "slug": "all-patients",
                "label": "All patients",
                "section": "all",
                "extra": "Full registry list; Register patient + Duplicate review on strip.",
            },
            {
                "slug": "active",
                "label": "Active",
                "section": "active",
                "extra": "Active outpatients / open visits; same CRUD as registry.",
            },
            {
                "slug": "admitted",
                "label": "Admitted",
                "section": "admitted",
                "extra": (
                    "Inpatient admissions. Row/detail may surface admit/discharge "
                    "actions requiring clinical:write (and billing:read for financial "
                    "status) in addition to patient:read."
                ),
                "read_all": ["patient:read"],
                "nested_any_read": ["clinical:read", "billing:read"],
            },
            {
                "slug": "balance-due",
                "label": "Balance due",
                "section": "balance-due",
                "extra": (
                    "Financial filter. Viewing balances requires patient:read ∩ "
                    "billing:read. Payment/enrollment actions need billing:write "
                    "where applicable."
                ),
                "read_all": ["patient:read", "billing:read"],
                "create_all": ["patient:write"],
                "update_all": ["patient:write"],
                "delete_all": ["patient:delete"],
                "nested_write_all": ["billing:write"],
            },
        ],
    },
    {
        "slug": "reception",
        "route": "/reception",
        "title": "Reception desk",
        "inventory": "screens/reception.md",
        "feature": "frontend/lib/features/reception/",
        "module": "patient-registry + scheduling-queue",
        "route_any": ["patient:read", "last_office:read"],
        "defaults": {
            "read_all": ["patient:read"],
            "create_all": ["patient:write"],
            "update_all": ["patient:write"],
            "delete_all": ["patient:delete"],
            "notes": (
                "Desk tabs themselves may use receptionDeskSectionRequirement "
                "(hide unauthorized tabs). Register/Schedule need patient:write. "
                "Payment gate needs billing:read (view) / billing:write (collect). "
                "Follow-ups may allow last_office:read readers without patient:write."
            ),
        },
        "tabs": [
            {
                "slug": "appointments",
                "label": "Appointments",
                "section": "appointments",
                "extra": "Schedule, check-in, reschedule, cancel appointments.",
            },
            {
                "slug": "desk-queue",
                "label": "Desk queue",
                "section": "desk-queue",
                "extra": "Front-desk waiting queue and call-next actions.",
            },
            {
                "slug": "high-priority",
                "label": "High priority",
                "section": "high-priority",
                "extra": "Escalated desk items; emergency handoff may need emergency:read.",
                "nested_any_read": ["emergency:read"],
            },
            {
                "slug": "active-visits",
                "label": "Active visits",
                "section": "active-visits",
                "extra": "In-facility visits; continue/end may need clinical:write or OPD encounter gate.",
                "nested_any_write": ["clinical:write", "patient:write"],
            },
            {
                "slug": "follow-ups",
                "label": "Follow-ups",
                "section": "follow-ups",
                "extra": "Follow-up worklist; complete/reschedule gated by write rights.",
                "read_any": ["patient:read", "last_office:read"],
            },
            {
                "slug": "payment-gate",
                "label": "Payment gate",
                "section": "payment-gate",
                "extra": "Billing hold / payment clearance before clinical progress.",
                "read_all": ["patient:read", "billing:read"],
                "update_all": ["billing:write"],
                "create_all": ["billing:write"],
            },
        ],
    },
    {
        "slug": "billing",
        "route": "/billing",
        "title": "Billing workspace",
        "inventory": "screens/billing.md",
        "feature": "frontend/lib/features/billing/",
        "module": "billing-payments",
        "route_any": ["billing:read", "billing:write"],
        "defaults": {
            "read_all": ["billing:read"],
            "create_all": ["billing:write"],
            "update_all": ["billing:write"],
            "delete_all": ["billing:write"],
            "notes": (
                "Close shift/day need billing:write. Approval-required mutations need "
                "financial:approve (intersection with billing:write when both apply). "
                "Claims-pending may deep-link to claims; hide if insurance module / "
                "billing rights missing."
            ),
        },
        "tabs": [
            {"slug": "all", "label": "All", "section": "all", "extra": "Full billing queue."},
            {
                "slug": "needs-issue",
                "label": "Needs issue",
                "section": "needs-issue",
                "extra": "Invoices awaiting issue; Issue action needs billing:write.",
            },
            {
                "slug": "awaiting-payment",
                "label": "Awaiting payment",
                "section": "awaiting-payment",
                "extra": "Record payment / receipt actions need billing:write.",
            },
            {
                "slug": "claims-pending",
                "label": "Claims pending",
                "section": "claims-pending",
                "extra": "Insurance claim handoff; may require billing:read ∩ insurance module.",
            },
            {
                "slug": "approval-required",
                "label": "Approval required",
                "section": "approval-required",
                "extra": "Approve/reject financial holds.",
                "update_all": ["financial:approve"],
                "create_all": ["financial:approve"],
                "nested_write_all": ["billing:write"],
            },
            {
                "slug": "overdue",
                "label": "Overdue",
                "section": "overdue",
                "extra": "Collections follow-up; write for dunning / adjust / waive.",
            },
        ],
    },
    {
        "slug": "claims",
        "route": "/claims",
        "title": "Claims workspace",
        "inventory": "screens/claims.md",
        "feature": "frontend/lib/features/claims/",
        "module": "insurance-claims",
        "route_any": ["billing:read", "billing:write", "financial:approve"],
        "defaults": {
            "read_all": ["billing:read"],
            "create_all": ["billing:write"],
            "update_all": ["billing:write"],
            "delete_all": ["billing:write"],
            "notes": (
                "Authorizations and claim prepare use claimsWorkspaceWriteRequirement "
                "(typically billing:write). Settlement/approval steps may need "
                "financial:approve. Insurance Setup catalog edits need write; "
                "read-only users see setup without create controls."
            ),
        },
        "tabs": [
            {
                "slug": "authorizations",
                "label": "Authorizations",
                "section": "authorizations",
                "extra": "Request/update pre-authorizations.",
            },
            {
                "slug": "active-claims",
                "label": "Active Claims",
                "section": "active-claims",
                "extra": "Prepare, submit, amend active claims.",
            },
            {
                "slug": "settled",
                "label": "Settled",
                "section": "settled",
                "extra": "Read-heavy settled claims; exports may need evidence:export or reports:read.",
                "nested_any_read": ["reports:read", "evidence:export"],
            },
            {
                "slug": "insurance-setup",
                "label": "Insurance Setup",
                "section": "insurance-setup",
                "extra": "Payers/plans/catalog; create/edit need billing:write (or facility admin).",
                "read_any": ["billing:read", "facility:admin", "tenant:admin"],
                "create_all": ["billing:write"],
                "update_all": ["billing:write"],
            },
        ],
    },
    {
        "slug": "subscriptions",
        "route": "/subscriptions",
        "title": "Subscriptions workspace",
        "inventory": "screens/subscriptions.md",
        "feature": "frontend/lib/features/subscriptions/",
        "module": "platform subscriptions",
        "route_any": ["system:admin"],
        "defaults": {
            "read_all": ["subscriptions:read"],
            "create_all": ["subscriptions:write"],
            "update_all": ["subscriptions:write"],
            "delete_all": ["subscriptions:delete"],
            "notes": (
                "Route is super-admin gated; still gate each atom with subscriptions:* "
                "so elevated-but-scoped sessions cannot over-grant. Overview KPIs need "
                "subscriptions:read; destructive deletes need subscriptions:delete."
            ),
        },
        "tabs": [
            {"slug": "overview", "label": "Overview", "section": "overview", "extra": "Summary KPIs only; no create primary."},
            {"slug": "plans", "label": "Plans", "section": "plans", "extra": "Create/edit plans and module packs."},
            {"slug": "subscriptions", "label": "Subscriptions", "section": "subscriptions", "extra": "Assign/create tenant subscriptions."},
            {"slug": "invoices", "label": "Invoices", "section": "invoices", "extra": "Subscription invoices; write for issue/adjust."},
            {"slug": "licenses", "label": "Licenses", "section": "licenses", "extra": "Add/revoke licenses; delete needs subscriptions:delete."},
        ],
    },
    {
        "slug": "opd",
        "route": "/opd",
        "title": "OPD workspace",
        "inventory": "screens/opd.md",
        "feature": "frontend/lib/features/opd/",
        "module": "scheduling-queue",
        "route_any": [
            "patient:read",
            "clinical:read",
            "billing:read",
            "operations:read",
            "emergency:read",
        ],
        "defaults": {
            "read_any": ["patient:read", "clinical:read"],
            "create_all": ["clinical:write"],
            "update_all": ["clinical:write"],
            "delete_all": ["clinical:write"],
            "notes": (
                "Start OPD encounter uses encounter permission (clinical write / "
                "patient-flow gate). Triage/queue stage actions need clinical:write. "
                "Payment-related stages need billing:read/write. Follow-ups panel "
                "is read with clinical:read; complete needs write."
            ),
        },
        "tabs": [
            {"slug": "all-worklist", "label": "All worklist", "section": "all", "extra": "Combined OPD worklist."},
            {"slug": "arrivals", "label": "Arrivals", "section": "arrivals", "extra": "Check-in / arrival processing."},
            {"slug": "queue", "label": "Queue", "section": "queue", "extra": "Waiting queue call-next / requeue."},
            {"slug": "triage", "label": "Triage", "section": "triage", "extra": "Triage vitals/acuity; clinical:write."},
            {"slug": "active", "label": "Active", "section": "active", "extra": "In-consultation encounters."},
            {
                "slug": "follow-ups",
                "label": "Follow-ups",
                "section": "follow-ups",
                "extra": "Shared follow-up worklist; no Start OPD primary.",
                "create_all": ["clinical:write"],
            },
        ],
    },
    {
        "slug": "emergency",
        "route": "/emergency",
        "title": "Emergency workspace",
        "inventory": "screens/emergency.md",
        "feature": "frontend/lib/features/emergency/",
        "module": "scheduling-queue (emergency)",
        "route_any": ["emergency:read", "emergency:write", "operations:read"],
        "defaults": {
            "read_all": ["emergency:read"],
            "create_all": ["emergency:write"],
            "update_all": ["emergency:write"],
            "delete_all": ["emergency:delete"],
            "notes": (
                "Quick arrival / triage / disposition need emergency:write. "
                "Hard delete/void needs emergency:delete. Ambulance ops may also "
                "need operations:read for vehicle context; do not expose delete "
                "to write-only staff."
            ),
        },
        "tabs": [
            {"slug": "active-cases", "label": "Active cases", "section": "active", "extra": "Live ED board; Quick arrival primary."},
            {"slug": "critical", "label": "Critical", "section": "critical", "extra": "Critical acuity filter."},
            {
                "slug": "ambulance",
                "label": "Ambulance",
                "section": "ambulance",
                "extra": "Dispatch/trips; operations:read may union for asset context.",
                "read_any": ["emergency:read", "operations:read"],
            },
            {"slug": "handoff-ready", "label": "Handoff ready", "section": "handoff", "extra": "Handoff to ward/OPD; clinical:write may be needed for admit."},
            {"slug": "closed", "label": "Closed", "section": "closed", "extra": "Closed cases; no Quick arrival; delete still gated."},
            {"slug": "all", "label": "All", "section": "all", "extra": "Unfiltered board."},
        ],
    },
    {
        "slug": "ipd",
        "route": "/ipd",
        "title": "IPD workspace",
        "inventory": "screens/ipd.md",
        "feature": "frontend/lib/features/ipd/",
        "module": "inpatient-bed-management",
        "route_any": ["clinical:read", "operations:read", "billing:read"],
        "defaults": {
            "read_any": ["clinical:read", "operations:read"],
            "create_all": ["clinical:write"],
            "update_all": ["clinical:write"],
            "delete_all": ["clinical:write"],
            "notes": (
                "Start admission needs operational/clinical write gate. Manage beds "
                "navigates to /rooms-beds and needs bed-admin (facility/tenant admin "
                "or unit:manage). Billing panels inside detail need billing:read."
            ),
        },
        "tabs": [
            {"slug": "admission-queue", "label": "Admission Queue", "section": "admission-queue", "extra": "Pending admissions; Start admission primary."},
            {"slug": "active-patients", "label": "Active Patients", "section": "active", "extra": "Current inpatients."},
            {"slug": "transfers", "label": "Transfers", "section": "transfers", "extra": "Ward/bed transfers."},
            {"slug": "discharge", "label": "Discharge", "section": "discharge", "extra": "Discharge planning handoff; may need billing:read for clearance."},
            {
                "slug": "bed-board",
                "label": "Bed board",
                "section": "bed-board",
                "extra": "Occupancy board; Manage beds needs bed-admin rights.",
                "nested_any_write": ["unit:manage", "facility:admin", "tenant:admin"],
            },
            {"slug": "follow-ups", "label": "Follow-ups", "section": "follow-ups", "extra": "Shared follow-ups; no Start admission."},
        ],
    },
    {
        "slug": "rooms-beds",
        "route": "/rooms-beds",
        "title": "Rooms & beds",
        "inventory": "screens/rooms-beds.md",
        "feature": "frontend/lib/features/rooms_beds/",
        "module": "inpatient-bed-management",
        "route_any": [
            "clinical:read",
            "operations:read",
            "tenant:admin",
            "facility:admin",
            "system:admin",
        ],
        "defaults": {
            "read_any": ["clinical:read", "operations:read", "facility:admin"],
            "create_all": ["unit:manage"],
            "update_all": ["unit:manage"],
            "delete_all": ["unit:manage"],
            "notes": (
                "Bed admin create room/bed uses unit:manage or facility/tenant admin "
                "(any-of elevated admins). Assign/release/transfer occupancy needs "
                "clinical:write or operations:write per existing bed gates—prefer "
                "existing helpers; never show admin create to clinical-read-only."
            ),
        },
        "tabs": [
            {"slug": "all-beds", "label": "All beds", "section": "all", "extra": "Create room primary when bed-admin."},
            {"slug": "available", "label": "Available", "section": "available", "extra": "Create bed primary when bed-admin."},
            {"slug": "occupied", "label": "Occupied", "section": "occupied", "extra": "Release/transfer actions for writers."},
            {"slug": "turnover", "label": "Turnover", "section": "turnover", "extra": "Housekeeping turnover; operations:write may apply."},
            {"slug": "out-of-service", "label": "Out of service", "section": "out-of-service", "extra": "Mark in/out of service needs manage/write."},
        ],
    },
    {
        "slug": "icu",
        "route": "/icu",
        "title": "ICU workspace",
        "inventory": "screens/icu.md",
        "feature": "frontend/lib/features/icu/",
        "module": "icu-critical-care",
        "route_any": ["clinical:read", "emergency:read", "operations:read"],
        "defaults": {
            "read_any": ["clinical:read", "emergency:read"],
            "create_all": ["clinical:write"],
            "update_all": ["clinical:write"],
            "delete_all": ["clinical:write"],
            "notes": (
                "ICU stays/alerts/transfers need clinical:write. Emergency origin "
                "cases may union emergency:read for visibility. Bed board manage "
                "follows rooms-beds admin gates."
            ),
        },
        "tabs": [
            {"slug": "active-icu", "label": "Active ICU", "section": "active", "extra": "Active ICU stays."},
            {"slug": "critical-alerts", "label": "Critical alerts", "section": "critical", "extra": "Critical alert queue."},
            {"slug": "transfers", "label": "Transfers", "section": "transfers", "extra": "ICU transfers."},
            {"slug": "discharge-ready", "label": "Discharge ready", "section": "discharge-ready", "extra": "Step-down / discharge ready."},
            {"slug": "ended-stays", "label": "Ended stays", "section": "ended", "extra": "Historical stays; prefer read-only."},
            {"slug": "all-icu", "label": "All ICU", "section": "all", "extra": "Unfiltered ICU board."},
            {"slug": "bed-board", "label": "Bed board", "section": "bed-board", "extra": "ICU bed occupancy."},
            {"slug": "follow-ups", "label": "Follow-ups", "section": "follow-ups", "extra": "Shared follow-up worklist."},
        ],
    },
    {
        "slug": "nursing",
        "route": "/nursing",
        "title": "Nursing workspace",
        "inventory": "screens/nursing.md",
        "feature": "frontend/lib/features/nursing/",
        "module": "inpatient-bed-management",
        "route_any": [
            "clinical:read",
            "patient:read",
            "last_office:read",
            "operations:read",
        ],
        "defaults": {
            "read_any": ["clinical:read", "patient:read"],
            "create_all": ["clinical:write"],
            "update_all": ["clinical:write"],
            "delete_all": ["clinical:write"],
            "notes": (
                "Medication-due actions need pharmacy:read to view meds and "
                "clinical:write (or pharmacy:write where dispense is involved)—use "
                "intersection when both apply. Shift context is read via roster:read "
                "when present. Handover/transfer/discharge pending writes need "
                "clinical:write; last_office:read alone must not unlock write controls."
            ),
        },
        "tabs": [
            {"slug": "all", "label": "All", "section": "all", "extra": "Full nursing worklist."},
            {"slug": "assigned-ward", "label": "Assigned ward", "section": "assigned-ward", "extra": "ABAC ward/assignment scope preferred."},
            {"slug": "urgent", "label": "Urgent", "section": "urgent", "extra": "Urgent nursing tasks."},
            {
                "slug": "medication-due",
                "label": "Medication due",
                "section": "medication-due",
                "extra": "Due meds; pharmacy:read ∩ clinical:write for charting/admin.",
                "read_all": ["clinical:read", "pharmacy:read"],
                "update_all": ["clinical:write"],
            },
            {"slug": "handover-pending", "label": "Handover pending", "section": "handover-pending", "extra": "Shift handover complete needs clinical:write."},
            {"slug": "transfer-pending", "label": "Transfer pending", "section": "transfer-pending", "extra": "Transfer execute needs clinical:write."},
            {
                "slug": "discharge-pending",
                "label": "Discharge pending",
                "section": "discharge-pending",
                "extra": "Nursing discharge checks; billing clearance needs billing:read.",
                "nested_any_read": ["billing:read", "last_office:read"],
            },
        ],
    },
    {
        "slug": "clinical",
        "route": "/clinical",
        "title": "Clinical workspace",
        "inventory": "screens/clinical.md",
        "feature": "frontend/lib/features/clinical/",
        "module": "encounters-vitals",
        "route_any": ["clinical:read", "clinical:write"],
        "defaults": {
            "read_all": ["clinical:read"],
            "create_all": ["clinical:write"],
            "update_all": ["clinical:write"],
            "delete_all": ["clinical:write"],
            "notes": (
                "Encounter notes/diagnoses/procedures/referrals/disposition need "
                "clinical:write. Nested lab request needs lab:write OR clinical:write "
                "per existing order gate (prefer existing helper; document any-of). "
                "Radiology/pharmacy orders similarly. Admission request may need "
                "operations/clinical write. Discharge planning may need billing:read "
                "for financial clearance UI."
            ),
        },
        "tabs": [
            {"slug": "follow-ups", "label": "Follow-ups", "section": "follow-ups", "extra": "FollowUpWorklistPanel; complete needs write."},
            {"slug": "all", "label": "All", "section": "all", "extra": "Outpatient clinical worklist."},
            {"slug": "waiting-review", "label": "Waiting review", "section": "waiting-review", "extra": "Awaiting clinician review."},
            {"slug": "urgent", "label": "Urgent", "section": "urgent", "extra": "Urgent encounters."},
            {"slug": "results-ready", "label": "Results ready", "section": "results-ready", "extra": "Lab/imaging results ready; may show lab:read/radiology:read panels."},
            {"slug": "in-consultation", "label": "In consultation", "section": "in-consultation", "extra": "Active consultation; richest nested action bar."},
            {"slug": "completed", "label": "Completed", "section": "completed", "extra": "Same-day completed; prefer read; reopen needs write."},
        ],
    },
    {
        "slug": "physiotherapy",
        "route": "/physiotherapy",
        "title": "Physiotherapy workspace",
        "inventory": "screens/physiotherapy.md",
        "feature": "frontend/lib/features/physiotherapy/",
        "module": "physiotherapy",
        "route_any": ["clinical:read", "clinical:write", "patient:read", "billing:read"],
        "defaults": {
            "read_any": ["clinical:read", "patient:read"],
            "create_all": ["clinical:write"],
            "update_all": ["clinical:write"],
            "delete_all": ["clinical:write"],
            "notes": (
                "Therapy plans/sessions need clinical:write. Billing status chips "
                "need billing:read. Referrals intake may allow patient:read readers "
                "without write."
            ),
        },
        "tabs": [
            {"slug": "referrals", "label": "Referrals", "section": "referrals", "extra": "Incoming therapy referrals."},
            {"slug": "today", "label": "Today", "section": "today", "extra": "Today's sessions."},
            {"slug": "active-plans", "label": "Active plans", "section": "active-plans", "extra": "Active therapy plans."},
            {"slug": "follow-up-due", "label": "Follow-up due", "section": "follow-up", "extra": "Due therapy follow-ups."},
            {"slug": "missed", "label": "Missed", "section": "missed", "extra": "Missed sessions; reschedule needs write."},
            {"slug": "completed", "label": "Completed", "section": "completed", "extra": "Completed plans; read-heavy."},
            {"slug": "follow-ups", "label": "Follow-ups", "section": "follow-ups", "extra": "Shared FollowUpWorklistPanel."},
        ],
    },
    {
        "slug": "lab",
        "route": "/lab",
        "title": "Lab workspace",
        "inventory": "screens/lab.md",
        "feature": "frontend/lib/features/lab/",
        "module": "lab-workflows",
        "route_any": ["lab:read", "clinical:read", "clinical:write"],
        "defaults": {
            "read_all": ["lab:read"],
            "create_all": ["lab:write"],
            "update_all": ["lab:write"],
            "delete_all": ["lab:write"],
            "notes": (
                "Create order / configurations need lab:write (clinical:write may "
                "satisfy request-from-clinical any-of—reuse existing requirement). "
                "Result entry and verification need lab:write. Critical release may "
                "require intersection of lab:write + clinical:read for notify. "
                "Readers with only clinical:read must not see config/create."
            ),
        },
        "tabs": [
            {"slug": "all", "label": "All", "section": "all", "extra": "Full lab worklist; Create Lab Order primary."},
            {"slug": "awaiting-results", "label": "Awaiting results", "section": "awaiting-results", "extra": "Pending result entry."},
            {"slug": "processing", "label": "Processing", "section": "processing", "extra": "In-lab processing."},
            {"slug": "pending-verification", "label": "Pending verification", "section": "pending-verification", "extra": "Verify/release results need lab:write."},
            {"slug": "critical", "label": "Critical", "section": "critical", "extra": "Critical values; notify/acknowledge."},
            {"slug": "verified", "label": "Verified", "section": "verified", "extra": "Released results; prefer read."},
            {"slug": "follow-ups", "label": "Follow-ups", "section": "follow-ups", "extra": "No Create Order primary."},
        ],
    },
    {
        "slug": "radiology",
        "route": "/radiology",
        "title": "Radiology workspace",
        "inventory": "screens/radiology.md",
        "feature": "frontend/lib/features/radiology/",
        "module": "radiology-workflows",
        "route_any": [
            "radiology:read",
            "radiology:write",
            "clinical:read",
            "clinical:write",
            "billing:read",
        ],
        "defaults": {
            "read_all": ["radiology:read"],
            "create_all": ["radiology:write"],
            "update_all": ["radiology:write"],
            "delete_all": ["radiology:write"],
            "notes": (
                "Request imaging / configurations need radiology:write. Reporting "
                "and release need radiology:write. Billing holds need billing:read. "
                "Clinical:read alone may view shared results but not config."
            ),
        },
        "tabs": [
            {"slug": "worklist", "label": "Worklist", "section": "worklist", "extra": "Acquisition worklist."},
            {"slug": "reporting", "label": "Reporting", "section": "reporting", "extra": "Report drafting/signing."},
            {"slug": "released", "label": "Released", "section": "released", "extra": "Released reports; prefer read."},
            {"slug": "all-orders", "label": "All orders", "section": "all", "extra": "Unfiltered orders."},
            {"slug": "follow-ups", "label": "Follow-ups", "section": "follow-ups", "extra": "No Request imaging primary."},
        ],
    },
    {
        "slug": "pharmacy",
        "route": "/pharmacy",
        "title": "Pharmacy workspace",
        "inventory": "screens/pharmacy.md",
        "feature": "frontend/lib/features/pharmacy/",
        "module": "pharmacy-dispensing",
        "route_any": ["pharmacy:read", "operations:read"],
        "defaults": {
            "read_all": ["pharmacy:read"],
            "create_all": ["pharmacy:write"],
            "update_all": ["pharmacy:write"],
            "delete_all": ["pharmacy:write"],
            "notes": (
                "Dispense/partial fill need pharmacy:write. Pending-payment queue "
                "may show billing:read status; collecting payment needs billing:write. "
                "Catalog/stock nested CRUD needs pharmacy:write; readers browse only. "
                "Controlled drugs may require intersection with compliance:read for audit panels."
            ),
        },
        "tabs": [
            {"slug": "ready", "label": "Ready", "section": "ready", "extra": "Ready to dispense."},
            {"slug": "partial", "label": "Partial", "section": "partial", "extra": "Partial fills."},
            {
                "slug": "pending-payment",
                "label": "Pending payment",
                "section": "pending-payment",
                "extra": "Payment gate before dispense.",
                "read_all": ["pharmacy:read", "billing:read"],
                "nested_write_all": ["billing:write"],
            },
            {"slug": "completed", "label": "Completed", "section": "completed", "extra": "Dispensed history; prefer read."},
            {"slug": "all-orders", "label": "All orders", "section": "all", "extra": "Unfiltered pharmacy orders."},
        ],
    },
    {
        "slug": "operations",
        "route": "/operations",
        "title": "Operations workspace",
        "inventory": "screens/operations.md",
        "feature": "frontend/lib/features/operations/",
        "module": "facilities-maintenance",
        "route_any": ["operations:read", "operations:write"],
        "defaults": {
            "read_all": ["operations:read"],
            "create_all": ["operations:write"],
            "update_all": ["operations:write"],
            "delete_all": ["operations:write"],
            "notes": (
                "Create/update requests and asset mutations need operations:write. "
                "Report summary dialog needs operations:read only."
            ),
        },
        "tabs": [
            {"slug": "all-requests", "label": "All requests", "section": "all", "extra": "All facility requests."},
            {"slug": "open", "label": "Open", "section": "open", "extra": "Open requests."},
            {"slug": "in-progress", "label": "In progress", "section": "in-progress", "extra": "In-progress work."},
            {"slug": "completed", "label": "Completed", "section": "completed", "extra": "Completed/cancelled."},
            {"slug": "assets", "label": "Assets", "section": "assets", "extra": "Facility assets CRUD for writers."},
        ],
    },
    {
        "slug": "housekeeping",
        "route": "/housekeeping",
        "title": "Housekeeping workspace",
        "inventory": "screens/housekeeping.md",
        "feature": "frontend/lib/features/housekeeping/",
        "module": "facilities-maintenance",
        "route_any": ["operations:read", "operations:write"],
        "defaults": {
            "read_all": ["operations:read"],
            "create_all": ["operations:write"],
            "update_all": ["operations:write"],
            "delete_all": ["operations:write"],
            "notes": (
                "Create task/schedule/maintenance request need operations:write "
                "(canManage). Housekeeper role ABAC should prefer assigned/own scope."
            ),
        },
        "tabs": [
            {"slug": "tasks", "label": "Tasks", "section": "tasks", "extra": "Create task primary."},
            {"slug": "schedules", "label": "Schedules", "section": "schedules", "extra": "Create schedule primary."},
            {"slug": "maintenance-requests", "label": "Maintenance requests", "section": "maintenance", "extra": "Request maintenance primary."},
        ],
    },
    {
        "slug": "hr",
        "route": "/hr",
        "title": "HR workspace",
        "inventory": "screens/hr.md",
        "feature": "frontend/lib/features/hr/",
        "module": "hr-rosters",
        "route_any": ["hr:read", "hr:write"],
        "defaults": {
            "read_all": ["hr:read"],
            "create_all": ["hr:write"],
            "update_all": ["hr:write"],
            "delete_all": ["hr:write"],
            "notes": (
                "Add staff / leave request need hr:write. Shift templates need "
                "roster:write (and publish/approve use roster:publish / "
                "roster:approve). Access tab embeds admin-access rules "
                "(tenant/facility admin). Payroll drafts may need financial:approve "
                "for approve actions."
            ),
        },
        "tabs": [
            {"slug": "human-resources", "label": "Human resources", "section": "staff", "extra": "Staff directory; Add staff."},
            {"slug": "leave-requests", "label": "Leave requests", "section": "leave", "extra": "Request/approve leave."},
            {
                "slug": "shifts",
                "label": "Shifts",
                "section": "shifts",
                "extra": "Roster templates/shifts.",
                "create_all": ["roster:write"],
                "update_all": ["roster:write"],
                "nested_any_write": ["roster:publish", "roster:approve"],
            },
            {
                "slug": "payroll-drafts",
                "label": "Payroll drafts",
                "section": "payroll",
                "extra": "Payroll drafts; approve may need financial:approve.",
                "nested_any_write": ["financial:approve", "hr:write"],
            },
            {
                "slug": "manage-users-roles",
                "label": "Manage users and roles",
                "section": "access",
                "extra": "Embedded access admin; tenant/facility/system admin any-of.",
                "read_any": ["tenant:admin", "facility:admin", "system:admin"],
                "create_all": ["tenant:admin"],
                "update_all": ["tenant:admin"],
            },
        ],
    },
    {
        "slug": "biomedical",
        "route": "/biomedical",
        "title": "Biomedical workspace",
        "inventory": "screens/biomedical.md",
        "feature": "frontend/lib/features/biomedical/",
        "module": "biomedical-engineering-suite",
        "route_any": ["biomed:read", "biomed:write"],
        "defaults": {
            "read_all": ["biomed:read"],
            "create_all": ["biomed:write"],
            "update_all": ["biomed:write"],
            "delete_all": ["biomed:write"],
            "notes": (
                "Register asset / work orders / PM scheduling need biomed:write. "
                "Analytics/compliance panels need biomed:read; exports may need "
                "reports:read or evidence:export."
            ),
        },
        "tabs": [
            {"slug": "registry", "label": "Registry", "section": "registry", "extra": "Register asset primary."},
            {"slug": "overview", "label": "Overview", "section": "overview", "extra": "KPIs; read-heavy."},
            {"slug": "preventive", "label": "Preventive", "section": "preventive", "extra": "Schedule maintenance primary."},
            {"slug": "work-orders", "label": "Work orders", "section": "work-orders", "extra": "Create work order primary."},
            {"slug": "compliance", "label": "Compliance", "section": "compliance", "extra": "Recalls/downtime; compliance:read may union."},
            {"slug": "support", "label": "Support", "section": "support", "extra": "Vendor/support tickets."},
            {
                "slug": "analytics",
                "label": "Analytics",
                "section": "analytics",
                "extra": "Charts; reports:read may be required in addition to biomed:read.",
                "read_all": ["biomed:read"],
                "nested_any_read": ["reports:read"],
            },
        ],
    },
    {
        "slug": "communications",
        "route": "/communications",
        "title": "Communications workspace",
        "inventory": "screens/communications.md",
        "feature": "frontend/lib/features/communications/",
        "module": "notifications-communications",
        "route_any": ["communications:read", "communications:write"],
        "defaults": {
            "read_all": ["communications:read"],
            "create_all": ["communications:write"],
            "update_all": ["communications:write"],
            "delete_all": ["communications:delete"],
            "notes": (
                "New message/group need communications:write. Delete thread/"
                "template needs communications:delete. Deliveries are typically "
                "read-only operational logs."
            ),
        },
        "tabs": [
            {"slug": "messages", "label": "Messages", "section": "messages", "extra": "Inbox; New message/group primaries."},
            {"slug": "notifications", "label": "Notifications", "section": "notifications", "extra": "Notification center."},
            {"slug": "deliveries", "label": "Deliveries", "section": "deliveries", "extra": "Delivery logs; prefer read."},
            {"slug": "templates", "label": "Templates", "section": "templates", "extra": "Template CRUD for writers; delete gated."},
        ],
    },
    {
        "slug": "integrations",
        "route": "/integrations",
        "title": "Integrations workspace",
        "inventory": "screens/integrations.md",
        "feature": "frontend/lib/features/integrations/",
        "module": "integrations-core",
        "route_any": [
            "integration:read",
            "integration:write",
            "tenant:admin",
            "facility:admin",
            "system:admin",
        ],
        "defaults": {
            "read_all": ["integration:read"],
            "create_all": ["integration:write"],
            "update_all": ["integration:write"],
            "delete_all": ["integration:delete"],
            "notes": (
                "Create integration/API key/webhook need integration:write (or "
                "admin any-of per existing manage requirement). Secrets reveal "
                "is write-only. Logs are read; Interop tests may need write."
            ),
        },
        "tabs": [
            {"slug": "integrations", "label": "Integrations", "section": "integrations", "extra": "Create integration primary."},
            {"slug": "api-keys", "label": "API keys", "section": "api-keys", "extra": "Create API key; secret reveal write-only."},
            {"slug": "webhooks", "label": "Webhooks", "section": "webhooks", "extra": "Create webhook primary."},
            {"slug": "logs", "label": "Logs", "section": "logs", "extra": "Read-only delivery/audit logs."},
            {"slug": "interop", "label": "Interop", "section": "interop", "extra": "Interop probes; write to run tests."},
        ],
    },
    {
        "slug": "discharge",
        "route": "/discharge",
        "title": "Discharge workspace",
        "inventory": "screens/discharge.md",
        "feature": "frontend/lib/features/discharge/",
        "module": "inpatient-bed-management",
        "route_any": [
            "clinical:read",
            "clinical:write",
            "pharmacy:read",
            "billing:read",
            "operations:read",
        ],
        "defaults": {
            "read_any": ["clinical:read", "last_office:read"],
            "create_all": ["clinical:write"],
            "update_all": ["clinical:write"],
            "delete_all": ["clinical:write"],
            "notes": (
                "Planning/clearance writes need clinical:write. Clearance checklist "
                "sections: pharmacy:read for meds, billing:read for bills, "
                "operations:read for room turnover—show section only when that "
                "right is held (union across sections, intersection within section)."
            ),
        },
        "tabs": [
            {"slug": "all-patients", "label": "All patients", "section": "all", "extra": "All discharge candidates."},
            {"slug": "planned", "label": "Planned", "section": "planned", "extra": "Planned discharges."},
            {
                "slug": "pending-clearance",
                "label": "Pending clearance",
                "section": "pending-clearance",
                "extra": "Multi-department clearance; section gates per module rights.",
                "read_any": ["clinical:read", "pharmacy:read", "billing:read", "operations:read", "last_office:read"],
            },
            {"slug": "completed", "label": "Completed", "section": "completed", "extra": "Completed discharges; prefer read."},
            {"slug": "follow-ups", "label": "Follow-ups", "section": "follow-ups", "extra": "Post-discharge follow-ups."},
        ],
    },
    {
        "slug": "theater",
        "route": "/theater",
        "title": "Theater workspace",
        "inventory": "screens/theater.md",
        "feature": "frontend/lib/features/theater/",
        "module": "theatre-anesthesia",
        "route_any": ["patient:read", "clinical:read", "billing:read", "operations:read"],
        "defaults": {
            "read_any": ["clinical:read", "patient:read"],
            "create_all": ["clinical:write"],
            "update_all": ["clinical:write"],
            "delete_all": ["clinical:write"],
            "notes": (
                "Schedule case / stage updates need clinical:write (theater write "
                "gate). Billing holds need billing:read. Room/asset context may "
                "need operations:read."
            ),
        },
        "tabs": [
            {"slug": "scheduled", "label": "Scheduled", "section": "scheduled", "extra": "Schedule case primary."},
            {"slug": "in-theater", "label": "In theater", "section": "in-theater", "extra": "Intra-op stage actions."},
            {"slug": "recovery", "label": "Recovery", "section": "recovery", "extra": "PACU / recovery."},
            {"slug": "all-cases", "label": "All cases", "section": "all", "extra": "Unfiltered cases."},
            {"slug": "follow-ups", "label": "Follow-ups", "section": "follow-ups", "extra": "No Schedule case primary."},
        ],
    },
    {
        "slug": "mortuary",
        "route": "/mortuary",
        "title": "Mortuary workspace",
        "inventory": "screens/mortuary.md",
        "feature": "frontend/lib/features/mortuary/",
        "module": "mortuary",
        "route_any": [
            "mortuary:read",
            "mortuary:write",
            "mortuary:approve",
            "mortuary:release",
            "mortuary:audit",
        ],
        "defaults": {
            "read_all": ["mortuary:read"],
            "create_all": ["mortuary:write"],
            "update_all": ["mortuary:write"],
            "delete_all": ["mortuary:write"],
            "notes": (
                "Fine-grained mortuary rights: manage_storage, post_mortem_request, "
                "approve, release, billing_event, export, audit. Map each control to "
                "the matching AppPermissions.mortuary* key. Release needs "
                "mortuary:release; approvals need mortuary:approve; storage assignment "
                "needs mortuary:manage_storage; billing events need "
                "mortuary:billing_event ∩ billing where shown; exports need "
                "mortuary:export; audit panels need mortuary:audit."
            ),
        },
        "tabs": [
            {"slug": "overview", "label": "Overview", "section": "overview", "extra": "Summary; read."},
            {"slug": "intake", "label": "Intake", "section": "intake", "extra": "Receive case; mortuary:write."},
            {
                "slug": "storage",
                "label": "Storage",
                "section": "storage",
                "extra": "Assign storage; mortuary:manage_storage.",
                "update_all": ["mortuary:manage_storage"],
                "create_all": ["mortuary:manage_storage"],
            },
            {
                "slug": "custody",
                "label": "Custody",
                "section": "custody",
                "extra": "Custody chain; post-mortem request / approve gates.",
                "nested_any_write": ["mortuary:post_mortem_request", "mortuary:approve", "mortuary:write"],
            },
            {
                "slug": "release",
                "label": "Release",
                "section": "release",
                "extra": "Body release; mortuary:release (often ∩ approve).",
                "update_all": ["mortuary:release"],
            },
            {
                "slug": "reports",
                "label": "Reports",
                "section": "reports",
                "extra": "Exports/audit; mortuary:export / mortuary:audit.",
                "read_any": ["mortuary:read", "mortuary:audit", "mortuary:export"],
                "nested_any_write": ["mortuary:export"],
            },
        ],
    },
    {
        "slug": "admin-access",
        "route": "/admin/access",
        "title": "Access admin",
        "inventory": "screens/admin-access.md",
        "feature": "frontend/lib/features/admin_access/",
        "module": "access administration",
        "route_any": ["tenant:admin", "facility:admin", "system:admin"],
        "defaults": {
            "read_any": ["tenant:admin", "facility:admin", "system:admin"],
            "create_all": ["tenant:admin"],
            "update_all": ["tenant:admin"],
            "delete_all": ["tenant:admin"],
            "notes": (
                "Reuse existing canWrite / elevated gates. Registrations tab only "
                "when isElevated. Assignable rights must stay within actor ceiling "
                "and subscription modules. Demo users follow same write gate."
            ),
        },
        "tabs": [
            {"slug": "directory", "label": "Directory", "section": "directory", "extra": "Users directory; Create user."},
            {"slug": "roles", "label": "Roles", "section": "roles", "extra": "Create/edit roles; permission assignment ceiling."},
            {"slug": "permissions", "label": "Permissions", "section": "permissions", "extra": "Permission catalog; edits elevated only."},
            {"slug": "entitlements", "label": "Entitlements", "section": "entitlements", "extra": "Module entitlements; subscription ∩ admin."},
            {
                "slug": "registrations",
                "label": "Registrations",
                "section": "registrations",
                "extra": "Pending registrations; elevated only.",
                "read_all": ["system:admin"],
            },
            {"slug": "demo", "label": "Demo", "section": "demo", "extra": "Demo users; same write gate as directory."},
        ],
    },
    {
        "slug": "settings",
        "route": "/settings",
        "title": "Settings",
        "inventory": "screens/settings.md",
        "feature": "frontend/lib/features/settings/",
        "module": "settings / admin setup",
        "route_any": [],
        "defaults": {
            "read_all": ["profile:read"],
            "create_all": ["facility:admin"],
            "update_all": ["profile:update"],
            "delete_all": ["facility:admin"],
            "notes": (
                "Preferences/Accessibility: authenticated profile prefs. Account "
                "security: profile:update. Administration boundaries / Configuration "
                "/ Administrative setup: facility:admin ∪ tenant:admin ∪ system:admin. "
                "Hide entire sections when no authorized actions remain."
            ),
        },
        "tabs": [
            {"slug": "preferences", "label": "Preferences", "section": "preferences", "extra": "User prefs; authenticated."},
            {"slug": "accessibility", "label": "Accessibility", "section": "accessibility", "extra": "A11y prefs; authenticated."},
            {
                "slug": "account-and-security",
                "label": "Account and security",
                "section": "account",
                "extra": "Profile/password; profile:read / profile:update.",
                "read_all": ["profile:read"],
                "update_all": ["profile:update"],
            },
            {
                "slug": "administration-boundaries",
                "label": "Administration boundaries",
                "section": "administration",
                "extra": "Admin boundaries; admin any-of.",
                "read_any": ["facility:admin", "tenant:admin", "system:admin"],
            },
            {
                "slug": "configuration",
                "label": "Configuration",
                "section": "configuration",
                "extra": "Tenant/facility config; admin any-of.",
                "read_any": ["facility:admin", "tenant:admin", "system:admin"],
                "update_all": ["facility:admin"],
            },
            {
                "slug": "administrative-setup",
                "label": "Administrative setup workspace",
                "section": "workspace",
                "extra": "Wards/units/rooms/beds/users setup; admin or HR workspace gates.",
                "read_any": ["facility:admin", "tenant:admin", "system:admin", "hr:read"],
            },
        ],
    },
]

# Single-surface screens (no tab strip) still need one permission scan prompt.
SINGLE_SCREENS: list[dict] = [
    {
        "slug": "home",
        "route": "/",
        "title": "Home dashboard",
        "inventory": "screens/home.md",
        "feature": "frontend/lib/features/home/",
        "label": "Home (all atoms)",
        "section": "home",
        "extra": "Coordinate with prompts/dashboard.md; every KPI/queue/action/shortcut must declare requiredPermissions.",
        "route_any": [],
        "read_all": ["profile:read"],
        "notes": "Union across grants filters the visible atom set; intersection within each atom.",
    },
    {
        "slug": "reports",
        "route": "/reports",
        "title": "Reports workspace",
        "inventory": "screens/reports.md",
        "feature": "frontend/lib/features/reports/",
        "label": "Reports (all panels)",
        "section": "reports",
        "extra": "Catalog, schedules, compliance, timeline nested surfaces.",
        "route_any": [
            "reports:read",
            "reports:write",
            "compliance:read",
            "evidence:export",
            "tenant:admin",
            "facility:admin",
            "system:admin",
        ],
        "read_any": ["reports:read", "compliance:read"],
        "create_all": ["reports:write"],
        "update_all": ["reports:write"],
        "delete_all": ["reports:delete"],
        "notes": (
            "Compliance panels need compliance:read/review. Exports need "
            "evidence:export or reports:write per control. Hide schedule create "
            "without reports:write."
        ),
    },
    {
        "slug": "profile",
        "route": "/profile",
        "title": "Profile",
        "inventory": "screens/profile.md",
        "feature": "frontend/lib/features/profile/",
        "label": "Profile",
        "section": "profile",
        "extra": "View/edit profile and change password.",
        "route_any": [],
        "read_all": ["profile:read"],
        "update_all": ["profile:update"],
        "notes": "Hide edit/password without profile:update; view needs profile:read.",
    },
]


def fmt_list(keys: list[str] | None, *, empty: str = "_(n/a)_") -> str:
    if not keys:
        return empty
    return ", ".join(f"`{k}`" for k in keys)


def merge(defaults: dict, tab: dict, key: str) -> list[str] | None:
    if key in tab:
        return tab[key]
    return defaults.get(key)


def word_count(text: str) -> int:
    return len(text.split())


def build_tab_prompt(screen: dict, tab: dict) -> str:
    d = screen["defaults"]
    read_all = merge(d, tab, "read_all")
    read_any = merge(d, tab, "read_any")
    create_all = merge(d, tab, "create_all")
    update_all = merge(d, tab, "update_all")
    delete_all = merge(d, tab, "delete_all")
    nested_any_read = merge(d, tab, "nested_any_read") or []
    nested_any_write = merge(d, tab, "nested_any_write") or []
    nested_write_all = merge(d, tab, "nested_write_all") or []
    notes = tab.get("notes") or d.get("notes") or ""

    title = (
        f"UI Permission Scan — {screen['title']} / {tab['label']} "
        f"(`{screen['route']}?…={tab['section']}`)"
    )

    body = f"""# {title}

Deep-scan every UI atom on this tab (page chrome, list, row actions, detail, nested dialogs) and enforce permission-based visibility so users only see and use what their effective permissions allow.

## Context

- Target tab: **{tab['label']}** (`{tab['section']}`). {tab.get('extra', '')}
- Feature code: `{screen['feature']}`
- Module entitlement: `{screen['module']}`
- Route entry any-of: {fmt_list(screen.get('route_any'))}
- Effective access = union(role/module/user grants) ∩ subscription ∩ ABAC (see `.cursor/access/permissions.mdc`, `frontend/.cursor/permissions.mdc`).
- Reuse `AppAccessPolicy`, `AccessRequirement` (`allPermissions` = intersection, `anyPermissions` = union), `AppAccessGate` / action gates. Backend remains authoritative.
- Shared rules: `prompts/ui-permissions/_shared-rules.md`. Follow `prompts/.cursor/prompt.mdc`.
- Inventory atoms from feature presentation code, routes, and tests—do not recreate `screens/`.

## Permission matrix (HMS defaults for this tab)

| Concern | Semantics | Keys |
| --- | --- | --- |
| View / read UI | all-of (∩) | {fmt_list(read_all, empty="_(route/session gate only)_")} |
| View / read UI | any-of (∪) | {fmt_list(read_any)} |
| Create | all-of (∩) | {fmt_list(create_all)} |
| Update | all-of (∩) | {fmt_list(update_all)} |
| Delete | all-of (∩) | {fmt_list(delete_all)} |
| Nested cross-module read | any-of (∪) | {fmt_list(nested_any_read)} |
| Nested cross-module write | any-of (∪) | {fmt_list(nested_any_write)} |
| Nested cross-module write | all-of (∩) | {fmt_list(nested_write_all)} |

{notes}

Prefer existing feature `*Requirement` helpers when present; align them to this matrix rather than inventing a second vocabulary. Adjust only when source already documents a different gate—then keep source and note the mapping in tests.

## Requirements

1. Inventory every visible atom on this tab from presentation source: tab strip actions for this section, search/filters/columns, summary chips, rows, next-actions, empty/error/retry, detail sheets, and every nested dialog/workflow reachable from this tab only.
2. Classify each atom as read, create, update, delete, approve, export, navigate, or progressive-disclosure chrome; map it to `AppPermissions` using the matrix (intersection vs union as specified).
3. Gate rendering with `grantsAll` / `grantsAny` / `AccessRequirement.isAllowed` before build; unauthorized controls, columns that solely expose forbidden data, and unauthorized nested actions must not mount. Do not use disabled/grey unauthorized controls or routine “no access” banners.
4. Apply plan module entitlements and ABAC scope (tenant/facility/ward/assignment/own) after RBAC; strip UI the plan or scope forbids even if a role pack includes the permission string.
5. Keep authorized UX intact: loading, empty, error/retry, success/snackbar, and validation states must still work for permitted users; after mutations, synchronize lists/detail.
6. Collapse empty sections when all children are filtered; hide the tab itself from the strip when the user cannot meet the tab’s read requirement (if the screen already supports per-tab requirements; otherwise keep strip but empty-authorized content only).
7. Add/update widget tests proving: (a) missing any required ∩ permission ⇒ atom absent; (b) holding the full ∩ set ⇒ atom present; (c) ∪ grants show the union of allowed atoms; (d) nested cross-module chips absent without those rights; (e) authorized flows still succeed.

## Constraints

- Scope: this tab’s UI tree and nested dialogs opened from it; do not redesign unrelated screens.
- Do not create, edit, delete, or regenerate any file under `screens/` (read-only inventory).
- Reuse design-system components and existing gates; no second permission vocabulary.
- Theme tokens; responsive mobile/tablet/desktop; light and dark.
- No exploit/PoC code; no secrets in tests—use policy fixtures.

## Acceptance Criteria

- Every actionable atom on this tab has an explicit permission mapping and is absent when denied.
- Create/update/delete/approve/export controls match the matrix verbs; read-only users cannot mutate.
- Intersection and union behave as specified; cross-module nested UI respects nested rows.
- Unauthorized data-only columns/panels do not render; no disabled unauthorized affordances.
- Tests in `frontend/test/` cover denial and allowance fixtures for this tab’s critical atoms.
- Loading/empty/error/success remain observable for authorized users.

## Relevant Files

- `{screen['inventory']}`
- `{screen['feature']}`
- `frontend/lib/core/permissions/access_policy.dart`
- `frontend/lib/core/permissions/access_requirement.dart`
- `frontend/lib/core/permissions/access_gate.dart`
- `frontend/lib/app/router/app_routes.dart`
- `prompts/ui-permissions/_shared-rules.md`
- Matching `frontend/test/features/...` for this workspace
"""
    return body.strip() + "\n"


def build_single_prompt(screen: dict) -> str:
    tab = {
        "slug": screen["slug"],
        "label": screen["label"],
        "section": screen["section"],
        "extra": screen["extra"],
        "read_all": screen.get("read_all"),
        "read_any": screen.get("read_any"),
        "create_all": screen.get("create_all"),
        "update_all": screen.get("update_all"),
        "delete_all": screen.get("delete_all"),
        "notes": screen.get("notes"),
    }
    wrapper = {
        "title": screen["title"],
        "route": screen["route"],
        "inventory": screen["inventory"],
        "feature": screen["feature"],
        "module": screen.get("module", screen["slug"]),
        "route_any": screen.get("route_any", []),
        "defaults": {
            "read_all": screen.get("read_all"),
            "read_any": screen.get("read_any"),
            "create_all": screen.get("create_all"),
            "update_all": screen.get("update_all"),
            "delete_all": screen.get("delete_all"),
            "notes": screen.get("notes"),
        },
    }
    return build_tab_prompt(wrapper, tab)


def build_shared_rules() -> str:
    return """# UI Permission Enforcement — Shared Rules

Canonical rules for every prompt under `prompts/ui-permissions/`. Tab prompts refine matrices; they must not contradict this file or `prompts/.cursor/prompt.mdc`.

## Objective

Users must only see and use UI that their **effective** permissions allow. Backend authorization remains authoritative; frontend hiding prevents leakage and dead ends.

## Effective access

```
effective = union(role grants, module grants, user grants)
          ∩ subscription package modules
          ∩ plan permission caps
          ∩ ABAC scope (tenant, facility, ward/unit, assignment, own)
```

- **Intersection (∩ / `allPermissions` / `grantsAll`)**: every listed key required (e.g. payment gate needs `patient:read` and `billing:read`).
- **Union (∪ / `anyPermissions` / `grantsAny`)**: any one key sufficient (e.g. route entry via `clinical:read` or `operations:read`).
- Multi-role users receive the **union** of grants, then ∩ subscription/ABAC. Never unlock excluded modules via role packs alone.

## CRUD mapping (HMS)

| UI intent | Typical permission verb |
| --- | --- |
| View lists, detail, KPIs, reports | `*:read` |
| Register, schedule, create order/request | `*:write` or module `request` |
| Edit demographics, update stage, amend | `*:write` / `*:update` |
| Soft/hard delete, void, revoke | `*:delete` (or write only if product has no delete key) |
| Approve claims, roster, mortuary, financial | `*:approve` / `financial:approve` / `roster:approve` |
| Export evidence/reports | `*:export` / `evidence:export` / `reports:read` |

Use exact `AppPermissions` keys from `access_policy.dart` / `backend/src/config/permissions.js`.

## Enforcement UX

- Unauthorized UI **must not render** (no disabled stubs, no routine “no access” copy).
- Forbidden feedback only for direct restricted deep links, stale permissions, or backend `403`.
- Hide tabs/sections when the user fails that surface’s read requirement and the screen supports per-section gates.
- Nested dialogs inherit parent gates and add their own; never open a write dialog for a read-only user via a leftover icon.

## Implementation reuse

- Prefer existing `*Requirement` / `AppAccessGate` / `AppAccessActionGate` helpers.
- Filter lists of actions/chips/columns with shared helpers (see home dashboard atom permissions pattern).
- Keep loading, empty, error/retry, success, validation states for authorized paths.
- Synchronize frontend data after successful mutations.

## Verification (every tab prompt)

Widget/unit tests must prove unauthorized absence and authorized presence for representative atoms, including at least one ∩ denial and one ∪ allowance case where the matrix uses both.

## Related

- `.cursor/access/permissions.mdc`, `modules.mdc`, `subscriptions.mdc`, `default_user_roles.mdc`
- `frontend/.cursor/permissions.mdc`
- `prompts/.cursor/prompt.mdc`
"""


def build_readme(entries: list[tuple[str, str, str]]) -> str:
    lines = [
        "# UI Permission Prompts",
        "",
        "Per-tab (and single-surface) prompts that deep-scan nested UI and enforce",
        "permission-based access. Shared rules: [`_shared-rules.md`](_shared-rules.md).",
        "",
        "Run one prompt at a time with the target tab’s file as the agent instruction.",
        "",
        "## Index",
        "",
        "| Screen | Tab / surface | Prompt |",
        "| --- | --- | --- |",
    ]
    for screen_title, tab_label, rel in entries:
        lines.append(f"| {screen_title} | {tab_label} | `{rel}` |")
    lines.append("")
    lines.append(f"Total prompts: **{len(entries)}**")
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    if OUT.exists():
        for p in OUT.rglob("*.md"):
            p.unlink()
    OUT.mkdir(parents=True, exist_ok=True)

    (OUT / "_shared-rules.md").write_text(build_shared_rules() + "\n", encoding="utf-8")

    index: list[tuple[str, str, str]] = []
    oversize: list[tuple[str, int]] = []

    for screen in SCREENS:
        folder = OUT / screen["slug"]
        folder.mkdir(parents=True, exist_ok=True)
        for tab in screen["tabs"]:
            text = build_tab_prompt(screen, tab)
            path = folder / f"{tab['slug']}.md"
            path.write_text(text, encoding="utf-8")
            wc = word_count(text)
            if wc > 1000:
                oversize.append((str(path.relative_to(ROOT)), wc))
            index.append(
                (
                    screen["title"],
                    tab["label"],
                    str(path.relative_to(OUT)).replace("\\", "/"),
                )
            )

    singles = OUT / "_screens"
    singles.mkdir(parents=True, exist_ok=True)
    for screen in SINGLE_SCREENS:
        text = build_single_prompt(screen)
        path = singles / f"{screen['slug']}.md"
        path.write_text(text, encoding="utf-8")
        wc = word_count(text)
        if wc > 1000:
            oversize.append((str(path.relative_to(ROOT)), wc))
        index.append(
            (
                screen["title"],
                screen["label"],
                str(path.relative_to(OUT)).replace("\\", "/"),
            )
        )

    (OUT / "README.md").write_text(build_readme(index), encoding="utf-8")

    print(f"Wrote {len(index)} prompts under {OUT}")
    if oversize:
        print("OVERSIZE (>1000 words):")
        for rel, wc in oversize:
            print(f"  {wc:4d}  {rel}")
    else:
        print("All prompts <= 1000 words")


if __name__ == "__main__":
    main()
