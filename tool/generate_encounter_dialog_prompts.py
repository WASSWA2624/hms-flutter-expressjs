"""Generate per-dialog standardization prompts for patient-encounter inventory.

Normative contract: prompt.md (patient-encounter dialog standardization).
Regenerate after inventory or contract changes:

    python tool/generate_encounter_dialog_prompts.py
"""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INVENTORY = ROOT / "dialog-inventory" / "02-patient-encounter-flow.md"
PROMPTS = ROOT / "prompts"
CONTRACT = "prompt.md"
API_CONTRACT = ".cursor/api-contract.mdc"
SYNC_RULE = "frontend/.cursor/instant_ui_sync.mdc"
COMPONENTS_RULE = "frontend/.cursor/components.mdc"
LOCALIZATION_RULE = "frontend/.cursor/localization_i18n.mdc"
PERMISSIONS_RULE = "frontend/.cursor/permissions.mdc"
DESIGN_RULE = "frontend/.cursor/design-system.mdc"
ACCESSIBILITY_RULE = "frontend/.cursor/accessibility.mdc"
FEEDBACK_RULE = "frontend/.cursor/ui-feedback.mdc"
FRONTEND_TESTING_RULE = "frontend/.cursor/testing.mdc"
BACKEND_API_RULE = "backend/.cursor/api.mdc"
BACKEND_TESTING_RULE = "backend/.cursor/testing.mdc"
PATTERN_TEST = "frontend/test/shared/layout/workspace_ui_pattern_test.dart"
MODULE_FLOW_RULES = {
    "emergency": ".cursor/flows/emergency-flow.mdc",
    "icu": ".cursor/flows/icu-flow.mdc",
    "ipd": ".cursor/flows/ipd-flow.mdc",
    "opd": ".cursor/flows/opd-flow.mdc",
    "patients": ".cursor/flows/opd-flow.mdc",
    "reception": ".cursor/flows/opd-flow.mdc",
    "shared/components": ".cursor/flows/opd-flow.mdc",
    "shared/opd_actions": ".cursor/flows/opd-flow.mdc",
}
PURPOSE_OVERRIDES = {
    "_PatientFlowQuickDialog": "Patient/encounter flow: Patient Billing Quick (patients).",
}

EMPTY_MARKERS = {"-", "—", "–", "", "n/a", "none"}
_SOURCE_CACHE: dict[tuple[str, tuple[str, ...]], list[tuple[Path, str]]] = {}


def _cached_sources(base: Path, suffixes: set[str]) -> list[tuple[Path, str]]:
    """Read a source tree once so 41 prompt audits remain fast and deterministic."""
    key = (base.as_posix(), tuple(sorted(suffixes)))
    if key not in _SOURCE_CACHE:
        sources: list[tuple[Path, str]] = []
        if base.exists():
            for candidate in base.rglob("*"):
                if not candidate.is_file() or candidate.suffix not in suffixes:
                    continue
                try:
                    sources.append(
                        (candidate, candidate.read_text(encoding="utf-8"))
                    )
                except (OSError, UnicodeDecodeError):
                    continue
        _SOURCE_CACHE[key] = sources
    return _SOURCE_CACHE[key]


def _matching_source_paths(
    base: Path,
    pattern: str,
    suffixes: set[str],
) -> list[Path]:
    """Use ripgrep when available, with a deterministic pure-Python fallback."""
    ripgrep = shutil.which("rg")
    if ripgrep:
        command = [ripgrep, "--files-with-matches", "--no-messages"]
        for suffix in sorted(suffixes):
            command.extend(["--glob", f"*{suffix}"])
        command.extend([pattern, str(base)])
        result = subprocess.run(
            command,
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        if result.returncode in {0, 1}:
            return [
                Path(line.strip())
                for line in result.stdout.splitlines()
                if line.strip()
            ]
    matches = []
    compiled = re.compile(pattern, re.I)
    for candidate, text in _cached_sources(base, suffixes):
        if compiled.search(text):
            matches.append(candidate)
    return matches

SHELL_REFS = {
    "AppDialog": "frontend/lib/shared/components/app_dialog.dart",
    "AppButton": "frontend/lib/shared/components/app_button.dart",
    "AppActionIcons": "frontend/lib/shared/icons/app_action_icons.dart",
    "AppLoadingIndicator": "frontend/lib/shared/components/app_loading_indicator.dart",
    "toDialogTitleUppercase": "frontend/lib/core/utils/app_dialog_title.dart",
    "clinicalActionDialogActions": (
        "frontend/lib/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart"
    ),
    "buildAppDialogFormActions": "frontend/lib/shared/forms/app_form_shell.dart",
    "AppConfirmActionDialog": "frontend/lib/shared/actions/app_action_dialogs.dart",
    "showAppWorkspaceMutationDialog": (
        "frontend/lib/shared/layout/app_workspace_mutation_dialog.dart"
    ),
    "showAppWorkspaceActionDialog": "frontend/lib/shared/layout/app_workspace.dart",
}

# Mirrors prompt.md §2 "Reuse before creating" — keep lists in sync with the contract.
SHARED_REUSE = [
    (
        "Details / layout",
        "`AppPatientDetails`, `AppPatientDetailDialog`, `AppSectionPanel`, "
        "`AppContentPanel`, `AppInfoSheetGrid` / `AppInfoSheetRow`, "
        "`AppInfoTileGrid`, `AppExpandableRecordSection`",
    ),
    (
        "Action groups",
        "`AppActionPanel` / `AppActionSection`, permission action components, "
        "`clinicalActionDialogActions`, `buildAppDialogFormActions`, "
        "`buildAppDialogWizardActions`",
    ),
    (
        "Clinical UI",
        "`OpdEncounterDialog`, `FlowActionsDialog`, shared OPD openers, triage "
        "components, `AppRecordVitalsDialog`, `AppVitalsForm`, `AppStatusBadge`, "
        "shared fields, `AppFormInformationBanner`",
    ),
    (
        "Approved shells / openers",
        "`showAppDialog`, `showAppWorkspaceMutationDialog`, "
        "`showAppWorkspaceActionDialog`, `AppConfirmActionDialog` / "
        "`AppSelectActionDialog` / `AppTextActionDialog` / "
        "`AppTriageActionDialog`, and existing `show*` / `open*` encounter helpers",
    ),
]

# Stable filenames when auto-slugify would drift from established prompt names.
SLUG_OVERRIDES = {
    "QueueActionsDialog": "opd-queue-actions-dialog",
    "FlowActionsDialog": "flow-actions-dialog",
    "_openReleaseBedDialog": "ipd-release-bed-dialog",
    "PatientPinnedOpdEncounterDialog": "patient-pinned-opd-encounter-dialog",
    "ConsultationPaymentDialog": "consultation-payment-dialog",
    "CorrectStageDialog": "correct-stage-dialog",
    "AssignDoctorDialog": "assign-doctor-dialog",
    "RoutingDecisionDialog": "routing-decision-dialog",
    "ReferralDialog": "referral-dialog",
    "FollowUpDialog": "follow-up-dialog",
    "PrintOpdSummaryDialog": "print-opd-summary-dialog",
    "RecordVitalsDialog": "record-vitals-dialog",
}

# Dialog-specific mission, siblings, and hard requirements.
# Keys must match inventory symbols exactly.
DIALOG_BRIEFS: dict[str, dict] = {
    "QuickArrivalDialog": {
        "mission": (
            "Capture an emergency quick arrival and create the encounter path "
            "from the emergency workspace without a full registration detour."
        ),
        "primary_commit": "Save / create arrival",
        "affected": "emergency queue, encounter, patient context, badges",
        "siblings": ["DispatchDialog", "HandoffDialog", "AppTriageActionDialog"],
        "focus": [
            "Trace `createQuickArrival` end-to-end; patch emergency workspace slices on persisted success only.",
            "Keep arrival identity fields on shared form primitives; do not invent a second arrival shell.",
        ],
    },
    "DispatchDialog": {
        "mission": (
            "Dispatch or update ambulance/response status for an emergency case "
            "while preserving queue and detail identity."
        ),
        "primary_commit": "Dispatch / update status",
        "affected": "emergency dispatch state, case detail, queue row",
        "siblings": ["QuickArrivalDialog", "HandoffDialog"],
        "focus": [
            "Preserve paired openers `_openDispatchDialog`, `_openDispatchStatusDialog`, and `showEmergencyDispatchDialog`.",
            "Ensure status updates use HTTP mutation + Riverpod patch; never websocket-as-write.",
        ],
    },
    "HandoffDialog": {
        "mission": (
            "Complete emergency handoff into the next care surface with required "
            "clinical notes and destination context."
        ),
        "primary_commit": "Handoff",
        "affected": "emergency case, destination queue/workspace, encounter",
        "siblings": ["DispatchDialog", "QuickArrivalDialog", "FlowActionsDialog"],
        "focus": [
            "Keep `EmergencyHandoffActionCell._openHandoff` and `_openHandoffDialog` reachable with the same IDs.",
            "Reuse shared patient/encounter summary blocks instead of local handoff-only chrome.",
        ],
    },
    "_openPriorityDialog": {
        "mission": (
            "Set emergency priority/severity through the approved select-action "
            "shell without embedding patient names in the title."
        ),
        "primary_commit": "Edit priority",
        "affected": "emergency summary priority, queue ordering cues",
        "siblings": ["_openResponseDialog", "AppTriageActionDialog"],
        "shape": "inline_select",
        "focus": [
            "Keep `AppSelectActionDialog` + `showAppDialog` (or migrate to an equivalent approved helper).",
            "Confirm `updatePriority` patches only on `saved == true`; cancel leaves state untouched.",
            "Replace any one-off Material icons with `AppActionIcons` / sibling conventions when a shared mapping exists.",
        ],
    },
    "_openResponseDialog": {
        "mission": (
            "Record the emergency clinical response note via the approved "
            "text-action shell."
        ),
        "primary_commit": "Mark response",
        "affected": "emergency response notes, case detail",
        "siblings": ["_openPriorityDialog", "HandoffDialog"],
        "shape": "inline_text",
        "focus": [
            "Keep `AppTextActionDialog` path compliant: Cancel + primary, loading lock, barrierDismissible false.",
            "Trace `markResponse` through controller → repository → backend; fix contract mismatches either side.",
        ],
    },
    "_showTriageDialog": {
        "mission": (
            "Triage a housekeeping maintenance request through the approved "
            "workspace-mutation surface; this is operational maintenance triage, "
            "not clinical patient triage."
        ),
        "primary_commit": "Triage maintenance request",
        "affected": "housekeeping maintenance worklist and selected request detail",
        "siblings": ["showAppWorkspaceMutationDialog"],
        "shape": "inline_opener",
        "focus": [
            "Keep `showAppWorkspaceMutationDialog` + `_TriageForm`; do not migrate this operational workflow to clinical `AppTriageActionDialog`.",
            "Trace `triageMaintenanceRequest` to `POST /maintenance-requests/:human_friendly_id/triage` and patch the housekeeping selection/worklist only after success.",
            "Preserve maintenance-request and non-terminal-state gates at both call sites.",
        ],
    },
    "_TransferRequestDialog": {
        "mission": (
            "Request an ICU transfer with destination and clinical rationale, "
            "aligned with the IPD transfer-request pattern where possible."
        ),
        "primary_commit": "Request transfer",
        "affected": "ICU transfer request, bed/ward queues, encounter",
        "siblings": ["TransferRequestDialog", "_AssignBedDialog"],
        "focus": [
            "Compare with IPD `TransferRequestDialog` and consolidate duplicated transfer chrome into one shared primitive if both still diverge.",
            "Keep `openIcuTransferDialog` and all ICU detail/next-action call sites compiling.",
            "The current ICU form selects target ward/bed and has no clinical-rationale field; do not invent one without a backend requirement.",
            "Trace `requestTransfer` to the IPD flow request-transfer action with public ward/bed identifiers.",
        ],
    },
    "_AssignBedDialog": {
        "mission": (
            "Assign an ICU bed to the selected patient/admission with validated "
            "ward/bed selection."
        ),
        "primary_commit": "Assign bed",
        "affected": "ICU bed occupancy, admission detail, ward lists",
        "siblings": ["_TransferRequestDialog", "IpdStartAdmissionDialog"],
        "shape": "widget_dialog",
        "focus": [
            "Reuse bed/ward selectors already used by IPD/ICU siblings; do not copy a third local picker.",
            "On success, patch bed + admission slices immediately; on failure keep dialog open with `AppFailure`.",
            "Trace `loadBedBoard` and `assignBed`; the mutation posts `bed_id` to the IPD assign-bed action.",
        ],
    },
    "_openReleaseBedDialog": {
        "mission": (
            "Confirm IPD bed release through `AppConfirmActionDialog` with a "
            "single domain verb plus Cancel."
        ),
        "primary_commit": "Release bed",
        "affected": "IPD admission, bed occupancy, rooms/beds workspace",
        "siblings": ["TransferUpdateDialog", "_showTransferUpdateDialog"],
        "shape": "inline_confirm",
        "focus": [
            "Confirmation dialogs: one domain verb + Cancel — no secondary mutation buttons.",
            "Ensure `releaseBed` only patches when confirm returns persisted success.",
            "Prefer `AppActionIcons` for submit leading icon when a shared cleaning/release mapping exists.",
        ],
    },
    "TransferRequestDialog": {
        "mission": (
            "Create an IPD transfer request with destination ward/unit and "
            "reason, reusing the canonical transfer-request surface."
        ),
        "primary_commit": "Request transfer",
        "affected": "IPD transfer queue, admission detail, destination unit",
        "siblings": ["_TransferRequestDialog", "TransferUpdateDialog"],
        "focus": [
            "Consolidate with ICU `_TransferRequestDialog` if fields/chrome still diverge without domain cause.",
            "Keep IPD `_openTransferRequestDialog` working; ICU uses a separate private `_TransferRequestDialog`, not this class.",
            "Trace `requestTransfer` to `POST /api/v1/ipd-flows/:human_friendly_id/request-transfer`; do not invent a reason field absent from the contract.",
        ],
    },
    "TransferUpdateDialog": {
        "mission": (
            "Update an in-flight IPD transfer status/destination with audit-safe "
            "mutation semantics."
        ),
        "primary_commit": "Edit / manage transfer",
        "affected": "IPD transfer row, rooms/beds transfer views",
        "siblings": ["_showTransferUpdateDialog", "TransferRequestDialog"],
        "focus": [
            "Consolidate IPD `TransferUpdateDialog` with rooms/beds private `_TransferUpdateDialog`; rooms/beds does not call this IPD page-local class.",
            "Trace `updateTransfer` to `POST /api/v1/ipd-flows/:human_friendly_id/update-transfer`.",
            "Never label Edit as Update in the footer.",
        ],
    },
    "IpdStartAdmissionDialog": {
        "mission": (
            "Start an IPD admission from the prepared handoff/context with bed "
            "and clinical intake fields."
        ),
        "primary_commit": "Start admission",
        "affected": "IPD admissions list, bed assignment, encounter stage",
        "siblings": ["_PatientAdmissionQuickDialog", "ClinicalAdmissionActionDialog"],
        "focus": [
            "Reuse admission field/section primitives shared with patient admission quick and `ClinicalAdmissionActionDialog`.",
            "Trace start-admission API; patch admission + bed slices on success only.",
            "Move patient search through a controller; the widget currently reads `patientRepositoryProvider.listPatients` directly.",
        ],
    },
    "QueueActionsDialog": {
        "mission": (
            "Present OPD queue-row actions (stage moves and related ops) through "
            "the shared queue-actions hub."
        ),
        "primary_commit": "Execute selected queue action / Cancel",
        "affected": "OPD/reception queue rows, encounter stage badges",
        "siblings": ["ReceptionQueueActionsDialog", "FlowActionsDialog"],
        "shape": "action_hub",
        "focus": [
            "Do not fork a reception-only duplicate of queue actions — extend this shared dialog or extract a neutral primitive.",
            "Each nested mutation must follow loading lock + success-only patch rules.",
            "Replace `LinearProgressIndicator`; route provider loading through a controller instead of reading `opdRepositoryProvider` in the widget.",
            "Preserve prioritize, start OPD, cancel, and move actions plus `showQueueActionsDialog` barrier behavior.",
        ],
    },
    "PatientAppointmentQuickDialog": {
        "mission": (
            "Schedule or adjust a patient appointment from registry/reception "
            "quick actions with resolved patient IDs."
        ),
        "primary_commit": "Save appointment",
        "affected": "appointments list, patient detail, reception schedule cues",
        "siblings": [
            "OpdAppointmentActionsDialog",
            "OpdRescheduleAppointmentDialog",
            "OpdCancelAppointmentDialog",
        ],
        "focus": [
            "Reuse appointment fields/actions from shared OPD appointment dialogs where the UX matches.",
            "Openers must pass resolved patient/appointment IDs — no blocking re-lookup in the body.",
            "Replace the widget's direct `opdRepositoryProvider.createAppointment` write with controller delegation and an immediate provider patch; retain parent refresh only as targeted reconciliation.",
        ],
    },
    "_PatientTriageQuickDialog": {
        "mission": (
            "Record patient triage from registry quick actions via the shared "
            "triage action dialog."
        ),
        "primary_commit": "Save triage",
        "affected": "patient triage, encounter triage badges",
        "siblings": ["AppTriageActionDialog", "_showTriageDialog"],
        "focus": [
            "Must compose `AppTriageActionDialog` / `showAppTriageActionDialog` — delete any local triage form fork.",
            "Preserve `_openPatientTriageQuickDialog` and patient detail quick-action entry points.",
            "Preserve the submit chain: submit OPD encounter → record vitals → optional assign doctor; do not collapse partial-failure handling into false success.",
            "Move provider loading out of the widget repository read and retain `opdEncounterPermissionRequirement`.",
        ],
    },
    "_PatientAdmissionQuickDialog": {
        "mission": (
            "Start or request admission from patient registry quick actions with "
            "the same admission primitives as IPD/OPD handoff."
        ),
        "primary_commit": "Start / request admission",
        "affected": "admission request, patient detail, IPD intake cues",
        "siblings": ["IpdStartAdmissionDialog", "ClinicalAdmissionActionDialog"],
        "focus": [
            "Reuse `ClinicalAdmissionActionDialog`; do not replace its delegated loading/footer with a local shell.",
            "Move `ipdRepositoryProvider.requestAdmission` behind the appropriate controller and patch on success.",
            "Permission wrappers on patient quick actions must remain intact.",
        ],
    },
    "_PatientFlowQuickDialog": {
        "mission": (
            "Create the patient registry's quick OPD billing/walk-in flow, "
            "including consultation fee, invoice creation, and optional payment."
        ),
        "primary_commit": "Create billing / start OPD flow",
        "affected": "OPD encounter, consultation invoice/payment, patient registry detail",
        "siblings": ["ConsultationPaymentDialog"],
        "shape": "widget_dialog",
        "focus": [
            "Do not refactor this as a stage-action hub; it is a billing mutation form despite its historical symbol name.",
            "Trace `submitOpdEncounter` with `consultation_fee`, `create_consultation_invoice`, and optional `pay_now` through the OPD controller/repository/backend.",
            "Preserve currency defaults, payment authorization, and parent patient-registry refresh-on-success behavior.",
        ],
    },
    "_ReceptionPatientPickerDialog": {
        "mission": (
            "Pick an existing patient for a reception workflow with searchable "
            "shared list/detail primitives."
        ),
        "primary_commit": "Select patient / Cancel",
        "affected": "reception selection context only (no fake patient create)",
        "siblings": ["RegisterNewPatientDialog", "OpdEncounterDialog"],
        "shape": "read_only_picker",
        "focus": [
            "Reuse shared patient search/list primitives; do not build a reception-only picker table.",
            "This dialog is non-mutating: search through the patient-registry controller and return the selected `Patient`; the caller resolves appointment IDs.",
            "Search failure stays visible and selection/cancel must not patch server-backed state.",
        ],
    },
    "ReceptionQueueActionsDialog": {
        "mission": (
            "Expose reception queue actions by composing the shared OPD queue "
            "actions surface rather than a divergent fork."
        ),
        "primary_commit": "Execute queue action / Cancel",
        "affected": "reception queue rows, linked OPD encounter stage",
        "siblings": ["QueueActionsDialog", "FlowActionsDialog"],
        "shape": "action_hub",
        "focus": [
            "Migrate duplicated action rows into `QueueActionsDialog` or a shared primitive; keep a thin reception opener if needed.",
            "Preserve `showReceptionQueueActionsDialog` call sites.",
            "Replace `LinearProgressIndicator` and retain `receptionFrontDeskWriteRequirement` / `AppAccessActionGate`.",
        ],
    },
    "_showTransferUpdateDialog": {
        "mission": (
            "Update transfer state from rooms/beds using the same transfer-update "
            "surface as IPD."
        ),
        "primary_commit": "Edit transfer / confirm",
        "affected": "rooms/beds occupancy, transfer row, IPD transfer views",
        "siblings": ["TransferUpdateDialog", "TransferRequestDialog"],
        "shape": "inline_opener",
        "focus": [
            "The opener hosts rooms/beds private `_TransferUpdateDialog`; consolidate that form with IPD `TransferUpdateDialog` through one domain-neutral shared successor.",
            "Trace `RoomsBedsWorkspaceController.updateTransfer` to the IPD update-transfer endpoint and retain rooms/beds call sites.",
            "Keep barrierDismissible false for mutating open and success-only patches.",
        ],
    },
    "AppTriageActionDialog": {
        "mission": (
            "Provide the canonical shared triage action dialog used by emergency, "
            "patients, and other triage entry points."
        ),
        "primary_commit": "Save triage",
        "affected": "triage records for the calling module's encounter/patient",
        "siblings": ["_PatientTriageQuickDialog", "EmergencyActionPanel._openTriageDialog"],
        "focus": [
            "This is a shared primitive — improve it in place; migrate callers off local triage dialogs.",
            "API must stay domain-neutral; callers supply labels, options, and `onSubmit`.",
            "Audit each callback path separately: emergency uses `recordTriage`; patient quick triage uses OPD encounter/vitals/doctor mutations. Housekeeping maintenance triage is out of domain.",
        ],
    },
    "OpdEncounterDialog": {
        "mission": (
            "Host the OPD encounter workspace (clinical documentation and "
            "encounter lifecycle actions) as the canonical encounter dialog."
        ),
        "primary_commit": "Save encounter changes / lifecycle actions",
        "affected": "OPD encounter, queue stage, pinned encounter, clinical sections",
        "siblings": [
            "showOpdEncounterDialog",
            "PatientPinnedOpdEncounterDialog",
            "FlowActionsDialog",
            "_CloseEncounterDialog",
            "_CancelEncounterDialog",
        ],
        "shape": "workspace_dialog",
        "focus": [
            "Do not create a second encounter shell. Extend this dialog and `showOpdEncounterDialog`.",
            "Footer may expose multiple essential mutations — still order secondary → Cancel → primary; prefer approved action helpers.",
            "Every nested save must patch Riverpod on persisted success only and keep the dialog open on failure.",
        ],
    },
    "_CloseEncounterDialog": {
        "mission": (
            "Confirm closing an OPD encounter with a single domain verb plus Cancel."
        ),
        "primary_commit": "Close encounter (domain verb — not the chrome Close label)",
        "affected": "encounter status, OPD queue, pinned encounter",
        "siblings": ["_CancelEncounterDialog", "OpdEncounterDialog"],
        "shape": "confirm",
        "focus": [
            "Chrome dismiss stays Cancel; the primary commit is the domain close verb.",
            "Preserve `_promptCloseEncounter` from encounter dialog and encounter flow.",
            "Trace injected `onConfirm` through the parent callback to `POST /api/v1/opd-flows/:human_friendly_id/close` with `reason_notes`.",
        ],
    },
    "_CancelEncounterDialog": {
        "mission": (
            "Confirm cancelling an OPD encounter with destructive primary + Cancel."
        ),
        "primary_commit": "Cancel encounter",
        "affected": "encounter status, OPD queue, pinned encounter",
        "siblings": ["_CloseEncounterDialog", "OpdCancelAppointmentDialog"],
        "shape": "confirm",
        "focus": [
            "Use error-styled primary with `AppActionIcons` delete/error mapping as siblings do.",
            "Cancel (abort) must not invoke the cancel-encounter mutation.",
            "Trace injected `onConfirm` through the parent callback to `POST /api/v1/opd-flows/:human_friendly_id/cancel`.",
        ],
    },
    "showOpdEncounterDialog": {
        "mission": (
            "Open `OpdEncounterDialog` through the approved workspace/dialog "
            "helper with resolved encounter/patient IDs."
        ),
        "primary_commit": "n/a (opener) — host dialog owns commits",
        "affected": "opens encounter workspace; no independent mutation",
        "siblings": ["OpdEncounterDialog", "PatientPinnedOpdEncounterDialog"],
        "shape": "shared_opener",
        "focus": [
            "Opener-only scope: `showAppDialog` / workspace helpers, barrier rules, argument plumbing.",
            "Do not re-implement encounter body UI here; fix `OpdEncounterDialog` for body compliance.",
            "Preserve all listed call sites and named parameters for contextual IDs.",
        ],
    },
    "OpdAppointmentActionsDialog": {
        "mission": (
            "Present appointment-level actions (open encounter, reschedule, "
            "cancel) from a shared actions hub."
        ),
        "primary_commit": "Execute selected action / Cancel",
        "affected": "appointment row, linked encounter entry points",
        "siblings": [
            "OpdRescheduleAppointmentDialog",
            "OpdCancelAppointmentDialog",
            "PatientAppointmentQuickDialog",
        ],
        "shape": "action_hub",
        "focus": [
            "Child dialogs must remain the single implementations for reschedule/cancel.",
            "Keep `showOpdAppointmentActionsDialog` reception entry points working.",
        ],
    },
    "OpdRescheduleAppointmentDialog": {
        "mission": (
            "Reschedule an OPD appointment with validated date/time and success-only sync."
        ),
        "primary_commit": "Edit / save schedule",
        "affected": "appointment schedule, reception/OPD calendars",
        "siblings": ["OpdCancelAppointmentDialog", "PatientAppointmentQuickDialog"],
        "focus": [
            "Label editing actions Edit (not Update).",
            "Reuse shared date/time fields; keep cancel/failure from patching schedule state.",
        ],
    },
    "OpdCancelAppointmentDialog": {
        "mission": (
            "Cancel an OPD appointment with confirmation semantics and reason capture if required."
        ),
        "primary_commit": "Cancel appointment",
        "affected": "appointment status, queue links",
        "siblings": ["OpdRescheduleAppointmentDialog", "_CancelEncounterDialog"],
        "shape": "confirm",
        "focus": [
            "Prefer `clinicalActionDialogActions` or confirm helper; primary is domain cancel, chrome abort is Cancel.",
            "Trace cancel API; patch appointment slices only after persisted success.",
        ],
    },
    "PatientPinnedOpdEncounterDialog": {
        "mission": (
            "Show the pinned OPD encounter surface by composing the canonical "
            "encounter dialog/opener, not a parallel body."
        ),
        "primary_commit": "Delegates to encounter actions",
        "affected": "pinned encounter view, underlying encounter slices",
        "siblings": ["OpdEncounterDialog", "showOpdEncounterDialog"],
        "focus": [
            "Must wrap/reuse `OpdEncounterDialog` / `showOpdEncounterDialog` rather than duplicate clinical sections.",
            "Preserve `showPatientPinnedOpdEncounterDialog` signature and pin identity.",
        ],
    },
    "FlowActionsDialog": {
        "mission": (
            "Central OPD/reception/patient flow-stage actions hub that opens "
            "canonical child dialogs for each mutation."
        ),
        "primary_commit": "Stage action / nested dialog commits",
        "affected": "encounter stage, queue, payments, disposition, referrals, vitals",
        "siblings": [
            "ConsultationPaymentDialog",
            "CorrectStageDialog",
            "AssignDoctorDialog",
            "RoutingDecisionDialog",
            "OpdDispositionDialog",
            "_OpdAdmissionHandoffDialog",
            "ReferralDialog",
            "FollowUpDialog",
            "PrintOpdSummaryDialog",
            "RecordVitalsDialog",
            "QueueActionsDialog",
        ],
        "shape": "action_hub",
        "focus": [
            "Hub compliance: shell/title/loading/cancel rules here; child dialogs own their mutation UIs — do not inline forks.",
            "Preserve `showFlowActionsDialog` across OPD, reception, patients, and encounter flow.",
            "Each nested opener must pass resolved encounter/patient/queue IDs.",
        ],
    },
    "ConsultationPaymentDialog": {
        "mission": (
            "Capture consultation payment for the active OPD flow item with "
            "ledger-correct HTTP mutation."
        ),
        "primary_commit": "Record payment",
        "affected": "payment status, OPD stage gates, billing cues",
        "siblings": ["FlowActionsDialog"],
        "focus": [
            "Trace pay/record payment path against real billing/OPD routes; fix DTO/schema mismatches either side.",
            "Use `opdWorkspaceControllerProvider.payConsultation` and `POST /api/v1/opd-flows/:human_friendly_id/pay-consultation`; preserve insurance coverage verification and update-existing-billing mode.",
            "Never mark paid in UI without persisted success.",
        ],
    },
    "CorrectStageDialog": {
        "mission": (
            "Correct an OPD flow stage with an explicit audited stage change."
        ),
        "primary_commit": "Correct stage",
        "affected": "encounter stage, queue position, stage badges",
        "siblings": ["FlowActionsDialog", "AssignDoctorDialog"],
        "focus": [
            "Stage correction is a mutation — barrierDismissible false, success-only patch, shared failure UI.",
            "Reuse select/stage field primitives already used by flow siblings.",
            "Trace `correctStage` to `POST /api/v1/opd-flows/:human_friendly_id/correct-stage` with `stage_to` and `reason`; preserve admin authorization.",
        ],
    },
    "AssignDoctorDialog": {
        "mission": (
            "Assign or reassign the attending doctor for the OPD encounter/queue item."
        ),
        "primary_commit": "Assign doctor",
        "affected": "doctor assignment, queue row, encounter header",
        "siblings": ["FlowActionsDialog", "CorrectStageDialog"],
        "focus": [
            "Keep `_openAssignDoctorDialog` and workflow opener call sites in sync.",
            "Keep public `showAssignDoctorDialog` and workflow opener call sites in sync.",
            "Trace assign-doctor to `POST /api/v1/opd-flows/:human_friendly_id/assign-doctor`; preserve the documented `provider_user_id` contract instead of blindly rewriting it.",
        ],
    },
    "RoutingDecisionDialog": {
        "mission": (
            "Record the OPD routing decision that sends the patient to the next care path."
        ),
        "primary_commit": "Save routing decision",
        "affected": "routing/disposition cues, next-queue eligibility",
        "siblings": ["OpdDispositionDialog", "FlowActionsDialog"],
        "focus": [
            "Align field chrome with disposition/referral siblings; extract shared decision sections if duplicated.",
            "The submit method is `disposeFlow`, which calls triage routing at `POST /api/v1/triage/:human_friendly_id/route`; preserve route fields and optional provider/triage data.",
            "Patch routing-related slices only after HTTP success.",
        ],
    },
    "OpdDispositionDialog": {
        "mission": (
            "Capture OPD disposition outcome as part of encounter completion routing."
        ),
        "primary_commit": "Save disposition",
        "affected": "disposition, encounter completion cues, follow-up eligibility",
        "siblings": ["RoutingDecisionDialog", "FollowUpDialog", "ReferralDialog"],
        "focus": [
            "Reuse shared disposition/outcome fields with routing and referral dialogs where possible.",
            "Trace `completeDisposition`, including optional doctor review, to the OPD disposition endpoint; preserve ADMIT handoff and physiotherapy side paths.",
            "Confirm dialogs opened from FlowActionsDialog still return success flags correctly.",
        ],
    },
    "_OpdAdmissionHandoffDialog": {
        "mission": (
            "Offer navigation to IPD after an ADMIT disposition has already "
            "persisted; this dialog performs no admission mutation."
        ),
        "primary_commit": "Open admission",
        "affected": "navigation only; disposition state was patched before this dialog opens",
        "siblings": ["FlowActionsDialog"],
        "shape": "navigation_confirm",
        "focus": [
            "Keep `showOpdAdmissionHandoffDialog` and `FlowActionsDialog._promptIpdHandoff` reachable after persisted ADMIT disposition.",
            "Do not add admission fields or HTTP writes; Cancel aborts routing and Open admission only navigates.",
        ],
    },
    "ReferralDialog": {
        "mission": (
            "Create an OPD referral by adapting the canonical "
            "`ClinicalReferralActionDialog` for the active OPD flow."
        ),
        "primary_commit": "Save referral",
        "affected": "referral record, encounter routing cues",
        "siblings": ["FollowUpDialog", "OpdDispositionDialog"],
        "focus": [
            "Preserve `FlowActionsDialog` → `showReferralDialog`; clinical and physiotherapy pages use `ClinicalReferralActionDialog` directly and are not callers of this wrapper.",
            "Trace `createReferral` to `POST /api/v1/referrals` with `encounter_id`, `external_facility_name`, `reason`, and `notes`.",
        ],
    },
    "FollowUpDialog": {
        "mission": (
            "Schedule an OPD follow-up by adapting the canonical "
            "`ClinicalFollowUpActionDialog` for the active OPD flow."
        ),
        "primary_commit": "Save follow-up",
        "affected": "follow-up appointment/task, encounter disposition cues",
        "siblings": ["ReferralDialog", "PatientAppointmentQuickDialog"],
        "focus": [
            "Reuse appointment/date primitives where the follow-up is appointment-like.",
            "Preserve the `FlowActionsDialog` OPD entry; clinical and physiotherapy pages use the shared clinical dialog directly.",
            "Trace `createFollowUp` to `POST /api/v1/follow-ups` and preserve UTC/date formatting rules.",
        ],
    },
    "PrintOpdSummaryDialog": {
        "mission": (
            "Preview/print the OPD summary using shared print/report primitives."
        ),
        "primary_commit": "Print (with Copy as the secondary action)",
        "affected": "no server mutation unless print audit exists — verify before patching",
        "siblings": ["OpdEncounterDialog", "FlowActionsDialog"],
        "shape": "read_only_action",
        "focus": [
            "If print is local-only, do not fake Riverpod patches; if an audit/print API exists, sync it correctly.",
            "Reuse shared print/report section components and `AppActionIcons.print`.",
        ],
    },
    "RecordVitalsDialog": {
        "mission": (
            "Record encounter vitals through the canonical vitals form/dialog used across modules."
        ),
        "primary_commit": "Save vitals",
        "affected": "vitals history, nursing/OPD vitals panels, encounter summary",
        "siblings": ["AppRecordVitalsDialog", "AppVitalsForm", "FlowActionsDialog"],
        "focus": [
            "Must compose `AppRecordVitalsDialog` / `AppVitalsForm` — remove local vitals form forks.",
            "Nursing already uses `AppRecordVitalsDialog`; consolidate OPD's larger bespoke vitals form without losing its triage/routing sections.",
            "Trace create/edit vitals plus the optional `disposeFlow` → triage-route mutation; each persisted leg must patch independently and safely.",
        ],
    },
    "RegisterNewPatientDialog": {
        "mission": (
            "Register a new patient from reception/registry with validated demographics "
            "and success-only registry sync."
        ),
        "primary_commit": "Register patient",
        "affected": "patient registry lists/details, reception picker results",
        "siblings": ["_ReceptionPatientPickerDialog", "OpdEncounterDialog"],
        "focus": [
            "Mutating openers must set `barrierDismissible: false`; lock Cancel/close while submitting.",
            "Prefer `buildAppDialogFormActions` / wizard actions for multi-step registration footers.",
            "Trace callback injection: dialog `onSubmit` → `patientRegistryControllerProvider.createPatient` at reception/patient-registry call sites → patients repository → `POST /api/v1/patients`.",
            "Return `human_friendly_id`, patch registry slices on success only, and preserve duplicate-override submit labeling.",
        ],
    },
}


def slugify(symbol: str, module: str | None = None) -> str:
    if symbol in SLUG_OVERRIDES:
        return SLUG_OVERRIDES[symbol]
    s = symbol.lstrip("_")
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1-\2", s)
    s = s.replace("_", "-").lower()
    s = re.sub(r"[^a-z0-9-]+", "-", s)
    s = re.sub(r"-+", "-", s).strip("-")
    if module and module not in {
        "shared",
        "shared/opd_actions",
        "shared/components",
        "shared/patient_actions",
    }:
        mod = module.replace("/", "-").replace("_", "-")
        if not s.startswith(mod):
            s = f"{mod}-{s}"
    return s


def _is_empty_cell(value: str) -> bool:
    return value.strip().lower() in EMPTY_MARKERS


def parse_inventory() -> list[dict]:
    rows: list[dict] = []
    for line in INVENTORY.read_text(encoding="utf-8").splitlines():
        if not line.startswith("| `"):
            continue
        parts = [p.strip() for p in line.strip().strip("|").split("|")]
        if len(parts) < 7:
            continue
        symbol = parts[0].strip("`")
        purpose = parts[1]
        defined = parts[2]
        kind = parts[3]
        extends = parts[4]
        openers = parts[5]
        used = parts[6]
        defined_clean = defined.replace("`", "").replace("<br>", "\n").strip()
        m = re.search(r"([^\s:]+\.dart)(?::(\d+))?", defined_clean)
        path = m.group(1) if m else None
        line_no = int(m.group(2)) if m and m.group(2) else None
        used_sites = [
            u.strip().replace("`", "")
            for u in re.split(r"<br\s*/?>|\n", used)
            if not _is_empty_cell(u.strip().replace("`", ""))
        ]
        opener_list = [
            o.strip().replace("`", "")
            for o in re.split(r",\s*", openers)
            if not _is_empty_cell(o.strip().replace("`", ""))
        ]
        rows.append(
            {
                "symbol": symbol,
                "purpose": purpose,
                "path": path,
                "line": line_no,
                "kind": kind,
                "extends": extends,
                "openers": opener_list,
                "used": used_sites,
            }
        )
    return rows


def _declaration_match(text: str, symbol: str) -> re.Match | None:
    """Find the actual declaration, independent of stale inventory line numbers."""
    patterns = [
        rf"(?m)^(?:class|mixin)\s+{re.escape(symbol)}\b",
        rf"(?m)^\s*(?:static\s+)?(?:Future\s*<[^>]*>|void|Widget|bool|String|int|double)\s+{re.escape(symbol)}\s*\(",
        rf"(?m)^\s*(?:final|const|var)\s+.*=\s*{re.escape(symbol)}\s*[;(]",
    ]
    for pattern in patterns:
        match = re.search(pattern, text)
        if match:
            return match
    return None


def enrich_inventory_row(row: dict) -> dict:
    """Verify source location and discover real call-site files across the frontend."""
    enriched = dict(row)
    source_line = row["line"]
    source_exists = False
    detected_openers: list[str] = []
    if row["path"]:
        source_path = ROOT / row["path"].replace("\\", "/")
        if source_path.exists():
            source_exists = True
            text = source_path.read_text(encoding="utf-8")
            declaration = _declaration_match(text, row["symbol"])
            if declaration:
                source_line = text.count("\n", 0, declaration.start()) + 1
            for match in re.finditer(
                r"(?m)^\s*(?:Future\s*<[^>]*>|void|Widget)\s+"
                r"((?:_?(?:show|open))\w+)\s*\(",
                text,
            ):
                name = match.group(1)
                if (
                    name != row["symbol"]
                    and row["symbol"] in _function_region(text, match.start())
                ):
                    detected_openers.append(name)

    needles = [row["symbol"], *row["openers"], *detected_openers]
    invocation_pattern = (
        rf"(?:\b{re.escape(row['symbol'])}\s*\(|"
        rf"\b(?:{'|'.join(re.escape(needle) for needle in needles[1:])})\b)"
        if len(needles) > 1
        else rf"\b{re.escape(row['symbol'])}\s*\("
    )
    discovered: list[str] = []
    frontend_lib = ROOT / "frontend" / "lib"
    if frontend_lib.exists():
        for candidate in _matching_source_paths(
            frontend_lib, invocation_pattern, {".dart"}
        ):
            if not candidate.is_absolute():
                candidate = ROOT / candidate
            relative = candidate.relative_to(ROOT).as_posix()
            if relative != (row["path"] or "").replace("\\", "/"):
                discovered.append(relative)

    validated_inventory_used: list[str] = []
    for listed in row["used"]:
        path_match = re.search(r"([^\s`]+\.dart)", listed)
        if not path_match:
            continue
        listed_path = path_match.group(1).replace("\\", "/")
        candidate = ROOT / listed_path
        if not candidate.exists():
            continue
        try:
            listed_text = candidate.read_text(encoding="utf-8")
        except OSError:
            continue
        if re.search(invocation_pattern, listed_text):
            validated_inventory_used.append(listed_path)

    enriched["source_exists"] = source_exists
    enriched["source_line"] = source_line
    enriched["line_drift"] = (
        source_line is not None
        and row["line"] is not None
        and source_line != row["line"]
    )
    enriched["detected_openers"] = sorted(set(detected_openers))
    enriched["validated_used"] = sorted(set(validated_inventory_used))
    enriched["discovered_used"] = sorted(set(discovered))
    return enriched


def refresh_inventory(rows: list[dict]) -> None:
    """Keep inventory locations/reachability aligned with verified source evidence."""
    by_symbol = {row["symbol"]: row for row in rows}
    output = []
    for line in INVENTORY.read_text(encoding="utf-8").splitlines():
        if not line.startswith("| `"):
            output.append(line)
            continue
        parts = [part.strip() for part in line.strip().strip("|").split("|")]
        symbol = parts[0].strip("`") if parts else ""
        row = by_symbol.get(symbol)
        if row is None or len(parts) < 7:
            output.append(line)
            continue
        if symbol in PURPOSE_OVERRIDES:
            parts[1] = PURPOSE_OVERRIDES[symbol]
        if row["path"] and row.get("source_line"):
            parts[2] = f"`{row['path']}:{row['source_line']}`"
        openers = sorted(
            set(row["openers"] + row.get("detected_openers", []))
        )
        used = sorted(
            set(row.get("validated_used", []) + row.get("discovered_used", []))
        )
        parts[5] = ", ".join(f"`{item}`" for item in openers) or "—"
        parts[6] = "<br>".join(f"`{item}`" for item in used) or "—"
        output.append("| " + " | ".join(parts) + " |")
    INVENTORY.write_text("\n".join(output) + "\n", encoding="utf-8", newline="\n")


def _brace_region(text: str, start: int, brace_start: int | None = None) -> str:
    """Return text from start through the matching closing brace of the first `{`."""
    brace = text.find("{", start if brace_start is None else brace_start)
    if brace < 0:
        return text[start : start + 8000]
    depth = 0
    i = brace
    in_str = False
    str_ch = ""
    escape = False
    while i < len(text):
        ch = text[i]
        if in_str:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == str_ch:
                in_str = False
        else:
            if ch in ("'", '"'):
                in_str = True
                str_ch = ch
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return text[start : i + 1]
        i += 1
    return text[start : min(len(text), start + 40000)]


def _function_region(text: str, start: int) -> str:
    """Return a function body without mistaking named-parameter braces for it."""
    open_paren = text.find("(", start)
    if open_paren < 0:
        return _brace_region(text, start)
    depth = 0
    in_str = False
    str_ch = ""
    escape = False
    i = open_paren
    while i < len(text):
        ch = text[i]
        if in_str:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == str_ch:
                in_str = False
        else:
            if ch in ("'", '"'):
                in_str = True
                str_ch = ch
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    return _brace_region(text, start, i + 1)
        i += 1
    return _brace_region(text, start)


def _symbol_region(text: str, symbol: str, line_no: int | None) -> str:
    """Return the source region for a class/function declaration."""
    start = None
    patterns = [
        rf"(?:class|mixin)\s+{re.escape(symbol)}\b",
        rf"(?m)^\s*(?:static\s+)?(?:Future\s*<[^>]*>|void|Widget|bool|String|int|double)\s+{re.escape(symbol)}\s*\(",
        rf"(?m)^\s*(?:final|const|var)\s+.*=\s*{re.escape(symbol)}\s*[;(]",
    ]
    for pat in patterns:
        m = re.search(pat, text)
        if m:
            start = m.start()
            break
    if start is None and line_no:
        lines = text.splitlines(keepends=True)
        idx = max(0, line_no - 1)
        start = sum(len(l) for l in lines[:idx])
    if start is None:
        m = re.search(rf"\b{re.escape(symbol)}\s*\(", text)
        if m:
            start = m.start()
    if start is None:
        return text

    # Method / top-level function: brace-match a tight body (avoids sibling leakage).
    method_m = re.match(
        rf"(?s)\s*(?:static\s+)?(?:Future\s*<[^>]*>|void|Widget|bool|String|int|double)\s+{re.escape(symbol)}\s*\(",
        text[start:],
    )
    if method_m or (
        re.match(rf"\s*{re.escape(symbol)}\s*\(", text[start:])
        and "class " not in text[max(0, start - 40) : start]
    ):
        # Walk back to include leading annotations/docs on the same declaration block.
        return _function_region(text, start)

    # Class: brace-match the widget and its exact State implementation. This
    # avoids leaking later top-level helpers/classes when the target is last.
    widget_region = _brace_region(text, start)
    tail_start = start + len(widget_region)
    state_match = re.search(
        rf"(?m)^class\s+(_?{re.escape(symbol.lstrip('_'))}State)\b",
        text[tail_start:],
    )
    if state_match:
        state_start = tail_start + state_match.start()
        return widget_region + "\n" + _brace_region(text, state_start)
    return widget_region


def peek_dialog_context(
    path: str | None,
    symbol: str,
    line_no: int | None,
    openers: list[str] | None = None,
    used_from: list[str] | None = None,
) -> dict:
    """Tight source peek for shell, titles, buttons, and mutations."""
    info = {
        "uses_app_dialog": False,
        "uses_show_app_dialog": False,
        "uses_workspace_mutation": False,
        "uses_workspace_action": False,
        "uses_raw_show_dialog": False,
        "uses_alert_dialog": False,
        "uses_circular_progress": False,
        "uses_clinical_actions": False,
        "uses_form_actions": False,
        "uses_wizard_actions": False,
        "uses_confirm": False,
        "uses_select_action": False,
        "uses_text_action": False,
        "uses_triage_action": False,
        "uses_app_button": False,
        "uses_action_icons": False,
        "title_snippets": [],
        "button_snippets": [],
        "close_enabled_false": False,
        "barrier_false": False,
        "is_loading": False,
        "controller_hints": [],
        "mutation_hints": [],
        "label_antipatterns": [],
        "uses_material_icons": False,
        "widget_reads_repository": False,
        "delegated_components": [],
        "trace_files": [],
        "nearby_excerpt": "",
        "region_chars": 0,
    }
    if not path:
        return info
    file_path = ROOT / path.replace("\\", "/")
    if not file_path.exists():
        return info
    text = file_path.read_text(encoding="utf-8")
    region = _symbol_region(text, symbol, line_no)
    info["nearby_excerpt"] = region[:3000]
    info["region_chars"] = len(region)

    # Thin wrappers often delegate all shell/loading/action behavior to a
    # canonical shared dialog. Include those implementations in the evidence
    # scan so prompts do not report false gaps against the wrapper alone.
    delegated_regions: list[str] = []
    delegated_names = []
    for match in re.finditer(
        r"\b([A-Z]\w*(?:Dialog|Form|Panel|Section|Picker))\s*\(",
        region,
    ):
        name = match.group(1)
        prefix = region[max(0, match.start() - 32) : match.start()]
        if re.search(r"(?:class|mixin)\s+$", prefix):
            continue
        if name == symbol or name in delegated_names:
            continue
        delegated_names.append(name)
        if len(delegated_names) >= 8:
            break
    frontend_lib = ROOT / "frontend" / "lib"
    for name in delegated_names:
        found = False
        definition_pattern = rf"(?:class|mixin)\s+{re.escape(name)}\b"
        for candidate in _matching_source_paths(
            frontend_lib, definition_pattern, {".dart"}
        ):
            if not candidate.is_absolute():
                candidate = ROOT / candidate
            candidate_text = candidate.read_text(encoding="utf-8")
            declaration = _declaration_match(candidate_text, name)
            if declaration:
                delegated_regions.append(
                    _symbol_region(candidate_text, name, None)
                )
                info["delegated_components"].append(
                    f"{name} — {candidate.relative_to(ROOT).as_posix()}"
                )
                found = True
                break
        if found and len(delegated_regions) >= 4:
            break

    # Opener regions from the definition file and Used-from files (for shell detection only).
    search_blobs: list[str] = [text]
    for used in used_from or []:
        used_path = ROOT / used.replace("\\", "/").replace("`", "")
        if used_path.exists() and used_path != file_path:
            search_blobs.append(used_path.read_text(encoding="utf-8"))
    opener_regions: list[str] = []
    for opener in openers or []:
        if opener == symbol:
            continue
        for blob in search_blobs:
            if re.search(
                rf"(?m)^\s*(?:static\s+)?(?:Future\s*<[^>]*>|void|Widget)\s+{re.escape(opener)}\s*\(",
                blob,
            ) or re.search(rf"(?:class|mixin)\s+{re.escape(opener)}\b", blob):
                opener_regions.append(_symbol_region(blob, opener, None))
                break

    # Shell/chrome: symbol region + paired openers only (not whole Used-from files).
    scan = region + "\n".join(opener_regions + delegated_regions)
    # Mutations/controllers: symbol region + paired openers (callback-style dialogs
    # often mutate from the opener). Never scan whole Used-from files (sibling leakage).
    mut_scan = region + "\n".join(opener_regions)

    info["uses_app_dialog"] = "AppDialog(" in scan
    info["uses_show_app_dialog"] = bool(
        re.search(
            r"showApp(?:Dialog|WorkspaceMutationDialog|WorkspaceActionDialog|"
            r"Confirm|TriageActionDialog|SelectActionDialog|TextActionDialog)\s*(?:<[^>]*>)?\s*\(",
            scan,
        )
        or "AppConfirmActionDialog" in scan
        or "AppSelectActionDialog" in scan
        or "AppTextActionDialog" in scan
        or "AppTriageActionDialog" in scan
    )
    info["uses_workspace_mutation"] = "showAppWorkspaceMutationDialog" in scan
    info["uses_workspace_action"] = "showAppWorkspaceActionDialog" in scan
    info["uses_raw_show_dialog"] = bool(re.search(r"(?<![A-Za-z])showDialog\s*\(", scan))
    info["uses_alert_dialog"] = "AlertDialog(" in scan
    info["uses_circular_progress"] = (
        "CircularProgressIndicator" in scan or "LinearProgressIndicator" in scan
    )
    info["uses_clinical_actions"] = "clinicalActionDialogActions" in scan
    info["uses_form_actions"] = "buildAppDialogFormActions" in scan
    info["uses_wizard_actions"] = "buildAppDialogWizardActions" in scan
    info["uses_confirm"] = "AppConfirmActionDialog" in scan
    info["uses_select_action"] = "AppSelectActionDialog" in scan
    info["uses_text_action"] = "AppTextActionDialog" in scan
    info["uses_triage_action"] = (
        "AppTriageActionDialog" in scan or "showAppTriageActionDialog" in scan
    )
    info["uses_app_button"] = "AppButton." in scan or "AppButton(" in scan
    info["uses_action_icons"] = "AppActionIcons." in scan
    info["uses_material_icons"] = bool(re.search(r"\bIcons\.\w+", scan))
    info["widget_reads_repository"] = bool(
        re.search(
            r"ref\.(?:read|watch)\(\s*\w*RepositoryProvider\b",
            region,
            re.I | re.S,
        )
    )
    info["close_enabled_false"] = (
        "closeEnabled: false" in scan or "closeEnabled: !" in scan
    )
    info["barrier_false"] = "barrierDismissible: false" in scan
    info["is_loading"] = (
        "argsLoading" in scan
        or "isLoading:" in scan
        or "AppLoadingIndicator" in scan
        or "AppLoadingSurface" in scan
        or "isSaving" in scan
        or "_isSubmitting" in scan
        or "isSubmitting" in scan
    )

    for m in re.finditer(
        r"title:\s*(?:const\s+)?(?:Text\(\s*)?([^,\n)]+)",
        scan,
    ):
        snippet = m.group(1).strip()[:80]
        if snippet not in info["title_snippets"]:
            info["title_snippets"].append(snippet)
        if len(info["title_snippets"]) >= 6:
            break
    for m in re.finditer(r"AppButton\.(primary|secondary|tertiary)\s*\(", scan):
        info["button_snippets"].append(m.group(1))
        if len(info["button_snippets"]) >= 12:
            break
    if info["uses_clinical_actions"] and not info["button_snippets"]:
        info["button_snippets"] = ["secondary", "primary"]
    if info["uses_confirm"] and not info["button_snippets"]:
        info["button_snippets"] = ["secondary", "primary"]

    # Controller / provider reads in symbol region.
    for m in re.finditer(
        r"\b(?:ref\.read|ref\.watch)\(([^)]+(?:Controller|Repository|Provider)[^)]*)\)",
        mut_scan,
        re.S,
    ):
        hint = m.group(1).strip()[:100]
        if hint not in info["controller_hints"]:
            info["controller_hints"].append(hint)
        if len(info["controller_hints"]) >= 6:
            break
    for m in re.finditer(
        r"\.(create|update|delete|save|submit|assign|release|transfer|dispatch|"
        r"handoff|cancel|close|record|register|reschedule|admit|pay|mark|"
        r"correct|request|complete|dispose|route|prioritize|start|move)\w*\s*\(",
        mut_scan,
        re.I,
    ):
        call = m.group(0).rstrip("(").strip(".")
        if call.lower() in {"cancel", "dispose"}:
            continue
        key = f"mutation: {call}"
        if key not in info["mutation_hints"] and len(info["mutation_hints"]) < 8:
            info["mutation_hints"].append(key)

    # Also catch tear-offs / named callbacks: onSubmit: controller.createQuickArrival
    for m in re.finditer(
        r"(?:onSubmit|onConfirm|onSave|onPressed)\s*:\s*(?:\(\)\s*=>\s*)?"
        r"((?:[\w]+\.)+(?:create|update|delete|save|submit|assign|release|transfer|"
        r"dispatch|handoff|cancel|close|record|register|reschedule|admit|pay|"
        r"mark|correct|request|complete|dispose|route|prioritize|start|move)\w*|"
        r"(?:create|update|delete|save|submit|assign|release|transfer|"
        r"dispatch|handoff|cancel|close|record|register|reschedule|admit|pay|"
        r"mark|correct|request|complete|dispose|route|prioritize|start|move)\w*)",
        mut_scan,
        re.I,
    ):
        call = m.group(1).split(".")[-1]
        if call.lower() in {
            "cancel",
            "dispose",
            "onsubmit",
            "onconfirm",
            "onsave",
            "onpressed",
        }:
            continue
        key = f"mutation: {call}"
        if key not in info["mutation_hints"] and len(info["mutation_hints"]) < 8:
            info["mutation_hints"].append(key)

    # Surface concrete cross-stack files that mention the detected mutation
    # methods. These are candidates, not asserted ownership boundaries.
    mutation_names = [
        hint.removeprefix("mutation: ").strip()
        for hint in info["mutation_hints"]
    ]
    if mutation_names:
        for base, suffixes in (
            (ROOT / "frontend" / "lib", {".dart"}),
            (ROOT / "backend" / "src", {".js", ".ts"}),
        ):
            if not base.exists():
                continue
            trace_pattern = (
                rf"\b(?:{'|'.join(re.escape(name) for name in mutation_names)})\b"
            )
            for candidate in _matching_source_paths(base, trace_pattern, suffixes):
                if not candidate.is_absolute():
                    candidate = ROOT / candidate
                info["trace_files"].append(
                    candidate.relative_to(ROOT).as_posix()
                )
                if len(info["trace_files"]) >= 16:
                    break
            if len(info["trace_files"]) >= 16:
                break

    # Label antipatterns in region.
    if re.search(r"""['"]Close['"]|commonClose|closeActionLabel\b""", mut_scan):
        if "Close" not in " ".join(info["label_antipatterns"]):
            info["label_antipatterns"].append(
                "Possible Close label — chrome abort must be Cancel"
            )
    if re.search(r"""['"]Update['"]|commonUpdate|updateActionLabel\b""", mut_scan):
        info["label_antipatterns"].append(
            "Possible Update label — editing actions must be Edit"
        )
    if re.search(
        r"AppDialog\s*\([\s\S]{0,500}?title:\s*[^\n]*"
        r"(patient\.|displayName|fullName|patientName)",
        mut_scan,
        re.I,
    ):
        info["label_antipatterns"].append(
            "Title may include patient name — must be role/flow based"
        )

    return info


def clean_purpose(purpose: str) -> str:
    """Turn inventory purpose into a short professional phrase."""
    text = purpose.strip().rstrip(".")
    text = re.sub(r"^Patient/encounter flow:\s*", "", text, flags=re.I)
    text = re.sub(r"\s*\((emergency|icu|ipd|opd|patients|reception|rooms_beds|housekeeping|shared[^)]*)\)\s*$", "", text, flags=re.I)
    text = re.sub(r"\s+", " ", text).strip()
    return text or purpose.strip()


def human_title(symbol: str, purpose: str) -> str:
    short = clean_purpose(purpose)
    if short and not short.lower().startswith("patient/encounter"):
        # Title-case lightly without wrecking acronyms.
        return short
    name = symbol.lstrip("_")
    name = re.sub(r"^(open|show)", "", name, flags=re.I)
    name = re.sub(r"(Dialog|show)$", "", name, flags=re.I)
    name = re.sub(r"([a-z])([A-Z])", r"\1 \2", name)
    return name.strip() or symbol


def module_hint(path: str | None) -> str:
    if not path:
        return "shared"
    m = re.search(r"features/([^/]+)/", path.replace("\\", "/"))
    if m:
        return m.group(1)
    if "shared/opd_actions" in path:
        return "shared/opd_actions"
    if "shared/patient_actions" in path:
        return "shared/patient_actions"
    if "shared/components" in path:
        return "shared/components"
    return "shared"


def detect_shape(symbol: str, peek: dict, brief: dict, extends: str) -> str:
    if brief.get("shape"):
        return brief["shape"]
    if symbol.startswith("show") or (
        symbol.startswith("_open") or symbol.startswith("_show") or symbol.startswith("open")
    ):
        if peek["uses_confirm"] or "AppConfirmActionDialog" in extends:
            return "inline_confirm"
        if peek["uses_select_action"]:
            return "inline_select"
        if peek["uses_text_action"]:
            return "inline_text"
        if peek["uses_triage_action"]:
            return "inline_triage"
        if symbol.startswith("show") and "Dialog" not in symbol.replace("show", "", 1):
            return "shared_opener"
        return "inline_opener"
    if peek["uses_confirm"] or "AppConfirmActionDialog" in extends:
        return "confirm"
    if "hub" in (brief.get("mission") or "").lower() or symbol in {
        "FlowActionsDialog",
        "QueueActionsDialog",
        "ReceptionQueueActionsDialog",
        "OpdAppointmentActionsDialog",
    }:
        return "action_hub"
    if symbol == "OpdEncounterDialog":
        return "workspace_dialog"
    return "widget_dialog"


def shape_guidance(shape: str) -> list[str]:
    common = [
        "Compose through approved shells only — never raw `AlertDialog` / `showDialog`.",
        "Titles are general/role-based, passed through `AppDialog` for uppercase normalization — never patient names.",
        "Loading uses only `AppLoadingIndicator` / `AppLoadingSurface` / `AppButton.isLoading`.",
        "While loading/saving: disable Cancel, close, and competing actions; `closeEnabled: false`; mutating openers use `barrierDismissible: false`.",
        "Footer L→R: secondary actions → **Cancel** → primary commit. Prefer one commit.",
        "Every `AppButton` needs a leading icon (`AppActionIcons` when mapped) and localized label.",
        "Widgets never call APIs; mutate over HTTP; WebSockets only reconcile; patch Riverpod only after persisted success.",
    ]
    by_shape = {
        "inline_confirm": [
            "Inline confirm opener: host `AppConfirmActionDialog` (or approved confirm helper) via `showAppDialog`.",
            "Exactly one domain verb/Confirm + Cancel. No Create/Edit/Delete strip.",
        ],
        "confirm": [
            "Confirmation body: one domain verb/Confirm + Cancel. Keep destructive styling consistent with siblings.",
        ],
        "inline_select": [
            "Keep `AppSelectActionDialog` (or extract a shared successor) — do not hand-roll a select form.",
            "Submit label for edits is Edit (not Update).",
        ],
        "inline_text": [
            "Keep `AppTextActionDialog` (or shared successor) with Cancel + primary commit and loading lock.",
        ],
        "inline_triage": [
            "Must use `showAppTriageActionDialog` / `AppTriageActionDialog` — no local triage fork.",
        ],
        "inline_opener": [
            "Opener should host a canonical dialog widget; move substantial UI into a shared/feature dialog class if the body is large.",
        ],
        "shared_opener": [
            "Opener-only: focus on `showAppDialog` / workspace helpers, barriers, and argument plumbing.",
            "Do not duplicate dialog body compliance work that belongs to the hosted widget.",
        ],
        "action_hub": [
            "Hub: standardize shell/title/loading/cancel here; open canonical child dialogs for mutations — do not inline child forms.",
            "Each child entry must pass already-resolved contextual IDs and preserve permission gating.",
        ],
        "workspace_dialog": [
            "Workspace dialog: maximize/resize/close behavior must match sibling encounter dialogs.",
            "Multiple essential mutations are allowed only when necessary; still honor Cancel placement and loading locks.",
        ],
        "widget_dialog": [
            "Standard widget dialog: prefer `clinicalActionDialogActions` / form/wizard action builders over a hand-rolled footer.",
        ],
        "read_only_picker": [
            "Picker: loading/error rules apply to search; selection returns data to the caller and does not perform a mutation or patch server state.",
            "Footer/action acceptance is Select + Cancel (or direct row selection + Cancel), not a generic mutation commit.",
        ],
        "read_only_action": [
            "Read-only/local action: do not invent HTTP writes or Riverpod patches. Verify whether an audit API actually exists.",
            "Order local secondary actions before Cancel and the primary local action.",
        ],
        "navigation_confirm": [
            "Navigation confirmation: no HTTP write or provider patch belongs in this dialog; preserve the already-persisted parent result.",
            "Use Cancel + one navigation verb and preserve focus/dismiss behavior.",
        ],
    }
    return common + by_shape.get(shape, by_shape["widget_dialog"])


def gap_notes(peek: dict, shape: str) -> list[str]:
    gaps = []
    if peek["uses_alert_dialog"] or peek["uses_raw_show_dialog"]:
        gaps.append(
            "Raw Material dialog API detected — migrate to `AppDialog` / `showAppDialog` "
            "(or approved workspace / action helpers)."
        )
    if not peek["uses_app_dialog"] and not peek["uses_show_app_dialog"]:
        gaps.append(
            "No clear approved shell usage near the symbol — verify and migrate to "
            "`AppDialog` / `showAppDialog` / workspace helpers / confirm-select-text-triage helpers."
        )
    if peek["uses_circular_progress"]:
        gaps.append(
            "Raw Material progress indicator detected — replace with "
            "`AppLoadingIndicator` / `AppLoadingSurface` / `AppButton.isLoading` only."
        )
    if peek["button_snippets"]:
        order = peek["button_snippets"]
        if "primary" in order:
            pi = order.index("primary")
            later = order[pi + 1 :]
            if any(v in later for v in ("secondary", "tertiary")):
                gaps.append(
                    "Footer button order may place Cancel/secondary after primary — "
                    f"`{CONTRACT}` requires L→R: secondary actions, **Cancel**, primary commit."
                )
    if shape not in {
        "shared_opener",
        "read_only_picker",
        "read_only_action",
        "navigation_confirm",
    } and not peek["barrier_false"]:
        gaps.append(
            "Confirm mutating openers set `barrierDismissible: false` while the dialog can mutate."
        )
    if not peek["close_enabled_false"] and peek["is_loading"]:
        gaps.append(
            "Loading path exists — ensure `closeEnabled: false` and disabled Cancel/"
            "competing actions while mutation/load is in flight."
        )
    if shape not in {
        "shared_opener",
        "inline_confirm",
        "confirm",
        "read_only_action",
        "navigation_confirm",
    } and not peek["is_loading"]:
        gaps.append(
            "No obvious loading primitive near the symbol — add shared loading UX for async open/submit."
        )
    if (
        shape in {"widget_dialog", "workspace_dialog", "action_hub"}
        and not peek["uses_clinical_actions"]
        and not peek["uses_form_actions"]
        and not peek["uses_wizard_actions"]
        and peek["button_snippets"]
        and not peek["uses_confirm"]
    ):
        gaps.append(
            "Footer may be hand-rolled — prefer `clinicalActionDialogActions`, "
            "`buildAppDialogFormActions`, or `buildAppDialogWizardActions` when they fit."
        )
    if peek["uses_app_button"] and not peek["uses_action_icons"]:
        gaps.append(
            "`AppButton` seen without `AppActionIcons` — every action needs a leading icon; "
            "use `AppActionIcons` for shared verbs."
        )
    if (
        not peek["uses_action_icons"]
        and peek.get("uses_material_icons")
        and shape not in {"shared_opener"}
    ):
        gaps.append(
            "One-off `Icons.*` detected — prefer `AppActionIcons` (or sibling domain icon "
            "conventions) when a shared mapping exists."
        )
    if peek.get("widget_reads_repository"):
        gaps.append(
            "Widget reads a repository provider directly — move load/mutation ownership "
            "to a controller and keep server-backed UI state in Riverpod."
        )
    for anti in peek["label_antipatterns"]:
        gaps.append(anti)
    return gaps


def build_prompt(idx: int, row: dict, peek: dict) -> str:
    symbol = row["symbol"]
    purpose = row["purpose"]
    path = row["path"] or "(locate in inventory / codebase — path missing from inventory cell)"
    inventory_line = row["line"] if row["line"] is not None else "?"
    line = row.get("source_line")
    line = line if line is not None else inventory_line
    kind = row["kind"]
    extends = row["extends"]
    openers = sorted(set(row["openers"] + row.get("detected_openers", [])))
    used = sorted(
        set(row.get("validated_used", []) + row.get("discovered_used", []))
    )
    title = human_title(symbol, purpose)
    purpose_clean = clean_purpose(purpose)
    module = module_hint(row["path"])
    flow_rule = MODULE_FLOW_RULES.get(module)
    flow_rule_row = (
        f"| Module flow | [`{flow_rule}`](../{flow_rule}) | "
        "Domain workflow states, transitions, and handoffs |"
        if flow_rule
        else ""
    )
    slug = slugify(symbol, module)
    brief = DIALOG_BRIEFS.get(symbol, {})
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
    controller_md = (
        ", ".join(f"`{h}`" for h in peek["controller_hints"][:6])
        if peek["controller_hints"]
        else "_not detected in peek — trace widget → workspace controller → repository → backend route_"
    )
    mutation_md = (
        ", ".join(f"`{h}`" for h in peek["mutation_hints"][:6])
        if peek["mutation_hints"]
        else "_not detected in symbol region — trace submit/onConfirm handlers_"
    )
    delegated_md = (
        "\n".join(f"- `{item}`" for item in peek["delegated_components"])
        if peek["delegated_components"]
        else "- _No delegated dialog/form/panel implementation detected; inspect the target body directly._"
    )
    trace_md = (
        "\n".join(f"- `{item}`" for item in peek["trace_files"])
        if peek["trace_files"]
        else "- _No mutation-name matches were found automatically. Trace interfaces and route registrations manually; do not assume no backend path exists._"
    )
    location_note = (
        f"Inventory says line {inventory_line}; verified declaration is line {line}. "
        "Treat the verified declaration as authoritative and update the inventory if this task moves it."
        if row.get("line_drift")
        else "Inventory and verified declaration agree at generation time."
    )
    action_helper_md = ", ".join(
        label
        for label, flag in (
            ("`clinicalActionDialogActions`", peek["uses_clinical_actions"]),
            ("`buildAppDialogFormActions`", peek["uses_form_actions"]),
            ("`buildAppDialogWizardActions`", peek["uses_wizard_actions"]),
            ("`AppConfirmActionDialog`", peek["uses_confirm"]),
            ("`AppSelectActionDialog`", peek["uses_select_action"]),
            ("`AppTextActionDialog`", peek["uses_text_action"]),
            ("`AppTriageActionDialog`", peek["uses_triage_action"]),
        )
        if flag
    ) or "_none detected — adopt an approved action helper when the footer fits_"

    mission = brief.get(
        "mission",
        f"Standardize **{title}** so this patient/encounter dialog matches the shared product surface.",
    )
    primary_commit = brief.get("primary_commit", "primary domain commit")
    affected = brief.get("affected", "all Riverpod slices this dialog mutates (lists, details, badges)")
    siblings = brief.get("siblings") or []
    siblings_md = (
        ", ".join(f"`{s}`" for s in siblings)
        if siblings
        else "_scan inventory peers in the same module and shared OPD/clinical surfaces_"
    )
    focus_items = brief.get("focus") or [
        f"Make `{symbol}` fully compliant with `{CONTRACT}` without expanding scope to unrelated inventory rows.",
    ]
    focus_md = "\n".join(f"- {item}" for item in focus_items)
    guidance_md = "\n".join(f"- {g}" for g in guidance)

    shell_bits = []
    if peek["uses_app_dialog"]:
        shell_bits.append("`AppDialog`")
    if peek["uses_show_app_dialog"]:
        shell_bits.append("approved `show*` helper")
    if peek["uses_workspace_mutation"]:
        shell_bits.append("`showAppWorkspaceMutationDialog`")
    if peek["uses_workspace_action"]:
        shell_bits.append("`showAppWorkspaceActionDialog`")
    if peek["uses_confirm"]:
        shell_bits.append("`AppConfirmActionDialog`")
    if peek["uses_select_action"]:
        shell_bits.append("`AppSelectActionDialog`")
    if peek["uses_text_action"]:
        shell_bits.append("`AppTextActionDialog`")
    if peek["uses_triage_action"]:
        shell_bits.append("`AppTriageActionDialog`")
    shell_obs = ", ".join(shell_bits) if shell_bits else "unclear — verify in source"

    action_acceptance = {
        "shared_opener": (
            "Opener preserves its argument/result API, uses the approved helper, "
            "and enforces the correct barrier; hosted-dialog footer work stays in its owner."
        ),
        "action_hub": (
            "Hub may be Cancel-only and delegates each domain mutation to one canonical "
            "child; it does not invent a generic primary commit."
        ),
        "confirm": (
            "Confirmation has exactly Cancel + one domain verb/Confirm, with destructive styling when applicable."
        ),
        "inline_confirm": (
            "Confirmation has exactly Cancel + one domain verb/Confirm, with destructive styling when applicable."
        ),
        "read_only_picker": (
            "Picker supports Cancel plus selection/return semantics; it performs no server mutation."
        ),
        "read_only_action": (
            "Local secondary actions precede Cancel and the primary local action; no server mutation is invented."
        ),
        "navigation_confirm": (
            "Navigation prompt has Cancel + one navigation verb and performs no persistence."
        ),
    }.get(
        shape,
        "Footer order is secondary → Cancel → primary; labels are Cancel/Edit "
        "(not Close/Update); confirmations are one domain verb + Cancel.",
    )
    backend_acceptance = (
        "Search/load paths use the real API contract; selection/cancel/local actions do not patch server state."
        if shape in {"read_only_picker", "read_only_action", "navigation_confirm", "shared_opener"}
        else "Every load and mutation API succeeds on the happy path against the real backend contract; "
        "failures surface via `AppFailure` UI and patch nothing."
    )
    sync_acceptance = (
        "No provider patch is introduced for a non-mutating/local-only action."
        if shape in {"read_only_picker", "read_only_action", "navigation_confirm", "shared_opener"}
        else f"After persisted success only, Riverpod + targeted reconciliation keep dialog and parent surfaces aligned with backend truth for: {affected}."
    )

    return f"""# Standardize `{symbol}` — {title}

## Mission

{mission}

Bring **`{symbol}`** to **100% compliance** with [`{CONTRACT}`](../{CONTRACT}) (patient-encounter dialog standardization). This is **structural**, not cosmetic: consolidate onto the established product surface used across [`dialog-inventory/02-patient-encounter-flow.md`](../dialog-inventory/02-patient-encounter-flow.md). Do not invent another dialog shell, use raw `AlertDialog` / `showDialog`, or keep duplication merely to shrink the diff.

## Normative contracts (read before editing)

| Contract | Path | Authority |
| --- | --- | --- |
| Dialog standardization | [`{CONTRACT}`](../{CONTRACT}) | Shells, reuse, loading/actions, titles, verification |
| API envelopes / IDs | [`{API_CONTRACT}`](../{API_CONTRACT}) | `snake_case`, `human_friendly_id`, success/error envelopes |
| Instant UI sync | [`{SYNC_RULE}`](../{SYNC_RULE}) | HTTP mutate, Riverpod patch on success, WS reconcile only |
| Shared components | [`{COMPONENTS_RULE}`](../{COMPONENTS_RULE}) | Reuse under `frontend/lib/shared/`; no feature forks of shared UI |
| Localization | [`{LOCALIZATION_RULE}`](../{LOCALIZATION_RULE}) | All user-facing strings via l10n |
| Permissions | [`{PERMISSIONS_RULE}`](../{PERMISSIONS_RULE}) | Preserve RBAC/ABAC wrappers; never expose unauthorized actions |
| Design system | [`{DESIGN_RULE}`](../{DESIGN_RULE}) | Tokens only; responsive light/dark UI |
| Accessibility | [`{ACCESSIBILITY_RULE}`](../{ACCESSIBILITY_RULE}) | Focus, semantics, keyboard, scaling, contrast |
| Feedback / failures | [`{FEEDBACK_RULE}`](../{FEEDBACK_RULE}) | Shared async/failure states; preserve input; safe errors |
| Frontend tests | [`{FRONTEND_TESTING_RULE}`](../{FRONTEND_TESTING_RULE}) | Widget/controller/sync/responsive coverage |
| Backend API | [`{BACKEND_API_RULE}`](../{BACKEND_API_RULE}) | Routes, middleware, authz, public IDs |
| Backend tests | [`{BACKEND_TESTING_RULE}`](../{BACKEND_TESTING_RULE}) | Schema/service/controller/route/event coverage |
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
| Action helper peek | {action_helper_md} |
| Controllers (region) | {controller_md} |
| Mutations (region) | {mutation_md} |

### Used from

{used_md}

### Delegated/shared implementation evidence

{delegated_md}

### Cross-stack trace candidates

These files mention a detected mutation method and are starting points, not proof of ownership. Follow interfaces/imports and route registration until the persisted path is proven.

{trace_md}

## Compliance checklist (`{CONTRACT}` — this dialog only)

### 1. Established shells
- [ ] Composed through `AppDialog` via `showAppDialog`, or an approved helper: `showAppWorkspaceMutationDialog`, `showAppWorkspaceActionDialog`, `AppConfirmActionDialog` / `AppSelectActionDialog` / `AppTextActionDialog` / `AppTriageActionDialog`, or an existing `show*` / `open*` encounter helper.
- [ ] **No** raw `AlertDialog` / `showDialog` on this presentation path.
- [ ] Purpose, listed call sites, resolved contextual IDs, and permission wrappers are preserved.

### 2. Reuse before creating
- [ ] Repeated shells, sections, rows, forms, states, and action groups use one canonical implementation; superseded local copies are removed.
- [ ] Shared barrels and encounter flows were searched before adding widgets; canonical APIs are extended, not copied or trivially wrapped.
- [ ] Body uses shared details/layout, action-group, and clinical UI primitives listed under **Shared building blocks** when equivalents exist.
- [ ] If no shared primitive exists and another inventory dialog needs the same UI, create one configurable, domain-neutral primitive under `frontend/lib/shared/`; keep domain behavior in controllers.

### 3. Loading and actions
- [ ] Loading uses only `AppLoadingIndicator` or `AppLoadingSurface`; submission uses `AppButton.isLoading`. **No** `CircularProgressIndicator` or other loaders.
- [ ] While loading or saving: Cancel, close, and competing actions are disabled; `closeEnabled: false`; mutating openers use `barrierDismissible: false`.
- [ ] Footer order left→right: dialog-specific **secondary** actions, then **Cancel**, then the **primary** commit. Prefer one commit; use Create → Edit → Delete only when multiple mutations are essential.
- [ ] Every `AppButton` has a leading icon and localized label. Use `AppActionIcons` for shared verbs; match sibling encounter flows for domain actions.
- [ ] Labels: **Cancel** (not Close), **Edit** (not Update). Confirmation dialogs: one domain verb/Confirm + Cancel.
- [ ] Prefer `clinicalActionDialogActions` / `buildAppDialogFormActions` / `buildAppDialogWizardActions` when they fit instead of a hand-rolled footer.

### 4. Titles
- [ ] Title is general / role-based — **never** the patient's personal name.
- [ ] Title is passed through `AppDialog` for uppercase normalization; icon matches sibling conventions in this flow when peers already use icons.

### 5. Design, responsiveness, localization, and accessibility
- [ ] No hard-coded user-facing copy or private feature string holder; labels, hints, validation, errors, tooltips, and semantics use generated l10n.
- [ ] No hard-coded color, spacing, radius, elevation, typography, date, number, or currency formatting; use theme/design tokens and shared formatters.
- [ ] Content and actions remain usable on mobile, tablet, desktop, dark mode, text scaling, and constrained-height/keyboard layouts without overflow.
- [ ] Keyboard order is logical, focus is trapped/restored by the dialog shell, visible focus remains, icon-only controls have localized semantics, and status is not conveyed by color alone.

### 6. Backend correctness and sync
- [ ] Every load/mutation is traced end-to-end: dialog → workspace controller → repository/DTO → real backend route/schema/service.
- [ ] IDs, `snake_case` payloads, auth, envelopes, and response decoding match [`{API_CONTRACT}`](../{API_CONTRACT}); either side is fixed when mismatched.
- [ ] Widgets never call APIs or own competing server data. Mutations go over HTTP; WebSockets only reconcile ([`{SYNC_RULE}`](../{SYNC_RULE})).
- [ ] On failure: dialog stays open, `AppFailure` is shown through shared failure UI, and **nothing** is patched. No fake or silently ignored success.
- [ ] On persisted success only: immediately patch every affected Riverpod slice, then apply the smallest targeted refresh/realtime reconciliation. Dialog, parent workspaces, pinned views, lists, details, and badges agree with backend truth without a full reload.
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
| `barrierDismissible: false` | {"yes" if peek["barrier_false"] else "not seen"} |
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

Prefer these over new one-offs (`{CONTRACT}` Requirement 2):

{reuse_md}

Shell / chrome references:

- `AppDialog` / `showAppDialog` — `{SHELL_REFS["AppDialog"]}`
- `showAppWorkspaceMutationDialog` — `{SHELL_REFS["showAppWorkspaceMutationDialog"]}`
- `showAppWorkspaceActionDialog` — `{SHELL_REFS["showAppWorkspaceActionDialog"]}`
- `AppConfirmActionDialog` (+ select/text helpers) — `{SHELL_REFS["AppConfirmActionDialog"]}`
- `AppButton` — `{SHELL_REFS["AppButton"]}`
- `AppActionIcons` — `{SHELL_REFS["AppActionIcons"]}`
- Loading — `{SHELL_REFS["AppLoadingIndicator"]}` (+ `AppLoadingSurface` if used by siblings)
- Title casing — `{SHELL_REFS["toDialogTitleUppercase"]}`
- Clinical footer helper — `{SHELL_REFS["clinicalActionDialogActions"]}`
- Form footer helper — `{SHELL_REFS["buildAppDialogFormActions"]}`

Prefer existing openers in `shared/opd_actions`, `shared/patient_actions`, `shared/clinical_actions`, and `shared/components` over copying chrome into a feature folder.

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
   - Trace each load/mutation: dialog → controller → repository/DTO → backend route/schema/service → decode → Riverpod patch.

2. **Normalize shell (Req 1)**
   - Compose with `AppDialog` or an approved higher helper; open with `showAppDialog` / workspace helpers / confirm-select-text-triage helpers as appropriate.
   - Remove raw `AlertDialog` / `showDialog` on this path.
   - Preserve purpose, contextual IDs, and permission wrappers.

3. **Normalize title + icon (Req 4)**
   - General role/flow title for **{title}** — never patient display name.
   - Pass title through the shell for uppercase normalization.
   - Match sibling icon conventions in `{module}`.

4. **Normalize loading + footer (Req 3)**
   - Shared loading primitives only; rebuild actions with `AppButton` + `AppActionIcons` + l10n (or approved action helper).
   - Order: secondary → **Cancel** → primary (`{primary_commit}`).
   - In flight: disable Cancel/close/competitors; `closeEnabled: false`; `barrierDismissible: false` on mutating openers.

5. **Reuse (Req 2)**
   - Replace bespoke blocks with shared primitives; migrate duplicates; delete superseded locals.
   - Cross-check sibling reuse targets: {siblings_md}.
   - Extract under `frontend/lib/shared/` only when multiple inventory flows need the same UI.

6. **Behavior + permissions**
   - Openers pass already-resolved contextual IDs (`human_friendly_id` / domain IDs).
   - Preserve parent permission wrappers; do not expose unauthorized actions.

7. **Design + accessibility**
   - Use generated l10n, theme/design tokens, shared formatters, and responsive layout primitives only.
   - Verify keyboard/focus/semantics, text scaling, dark mode, constrained height, and mobile/tablet/desktop layouts.
   - Preserve entered form data on recoverable failures and never expose raw exception text.

8. **Backend + sync (Req 5 — hard)**
   - Widgets read Riverpod and delegate to controllers; no widget API calls.
   - Happy-path APIs must succeed against the real contract; fix either side on mismatch.
   - Failure → shared `AppFailure` UI, no patch, dialog stays open.
   - Persisted success only → patch {affected}, then apply the smallest targeted reconciliation.
   - Cancel/failure never present false success.

9. **Preserve reachability**
   - Do not break {reachability_md}. Update all call sites in the same change when signatures move.

10. **Verify**
   - Analyzer clean on touched files.
   - `{PATTERN_TEST}` green.
   - Run focused Flutter widget/controller/DTO tests plus backend schema/service/controller/route/event tests for every touched stack layer. Add missing tests; never rely on production services or secrets.
   - Happy-path succeeds; cancel/failure neither patches nor dismisses as saved.
   - Verify responsive, keyboard, focus, semantics, text-scale, and dark-mode behavior for changed dialog UI.
   - Run localization/code generation when ARB or generated DTO/model inputs change, and verify generated output is clean.
   - Equivalent flows share primitives, spacing, sections, action icons/labels, loading/error behavior, and responsive layout.
   - Tick every checklist item above before finishing.

## Acceptance criteria (all must pass)

1. `{symbol}` opens only through `AppDialog` / approved helpers — no raw Material dialog APIs.
2. {action_acceptance}
3. Loading uses only shared spinner primitives; dismiss and competing actions are blocked while in flight.
4. Title is general, uppercase-normalized, and never a patient name.
5. All copy is localized; all styling/formatting uses shared tokens/formatters; responsive and accessible behavior is verified.
6. Body sections and action groups reuse canonical shared primitives; no unjustified local forks (siblings considered: {siblings_md}).
7. Still reachable from inventory openers / *Used from* sites with contextual IDs and permissions intact.
8. {backend_acceptance}
9. {sync_acceptance}
10. `{PATTERN_TEST}` remains green; focused frontend/backend tests cover this dialog's critical path.

## Out of scope

- Other inventory rows (unless a minimal shared extract is required for reuse).
- New dialog frameworks, unrelated redesigns, or drive-by refactors outside `{symbol}`'s path.
- Client-only "saved" state not backed by HTTP success.
- Retaining duplicate local UI solely to shrink the diff.

## Deliverable

Implement the compliance fixes in the repo. Summarize: files changed; shell/title/footer/loading/reuse/sync fixes; design/localization/accessibility fixes; shared extracts; API/DTO/route fixes; tests added and run; exact commands and results; remaining risks (or explicitly state none). Append the project rule files applied and the model used.

<!-- generator: encounter-dialog prompt {idx:02d} slug={slug} symbol={symbol} shape={shape} -->
"""


def main() -> None:
    PROMPTS.mkdir(exist_ok=True)
    for old in list(PROMPTS.glob("*.md")):
        try:
            text = old.read_text(encoding="utf-8")
        except OSError:
            continue
        if (
            "generator: encounter-dialog prompt" in text
            or old.name.startswith("02-")
            and "standardize-" in old.name
        ):
            old.unlink()
    sample = PROMPTS / "_sample_structure_extract.md"
    if sample.exists():
        sample.unlink()

    rows = [enrich_inventory_row(row) for row in parse_inventory()]
    if len(rows) != 41:
        raise SystemExit(f"Expected 41 inventory rows, found {len(rows)}")
    refresh_inventory(rows)
    for row in rows:
        row["line"] = row["source_line"]
        row["line_drift"] = False
        if row["symbol"] in PURPOSE_OVERRIDES:
            row["purpose"] = PURPOSE_OVERRIDES[row["symbol"]]

    missing_briefs = [r["symbol"] for r in rows if r["symbol"] not in DIALOG_BRIEFS]
    if missing_briefs:
        raise SystemExit(f"Missing DIALOG_BRIEFS for: {', '.join(missing_briefs)}")

    index_lines = [
        "# Patient encounter flow — dialog prompts",
        "",
        "One actionable agent prompt per inventory row in "
        "[`02-patient-encounter-flow.md`](02-patient-encounter-flow.md).",
        f"Normative contract: [`../{CONTRACT}`](../{CONTRACT}) "
        f"(also [`../{API_CONTRACT}`](../{API_CONTRACT}), "
        f"[`../{SYNC_RULE}`](../{SYNC_RULE}), "
        f"[`../{COMPONENTS_RULE}`](../{COMPONENTS_RULE})).",
        "",
        "Prompt files live in [`../prompts/`](../prompts/) "
        "(named `NN-<dialog-slug>.md`). "
        "`run_prompts.py` executes every `prompts/*.md` — keep this index here "
        "so it is not mistaken for an implementation brief.",
        "",
        "Each prompt is generated to be actionable, professional, contextual, "
        "specific, and complete against `prompt.md` (shells, reuse, loading/"
        "actions, titles, backend sync, verification).",
        "",
        "Regenerate with:",
        "",
        "```bash",
        "python tool/generate_encounter_dialog_prompts.py",
        "```",
        "",
        "| # | Prompt | Symbol | Purpose |",
        "| --- | --- | --- | --- |",
    ]

    used_names: set[str] = set()
    for i, row in enumerate(rows, start=1):
        peek = peek_dialog_context(
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
        body = build_prompt(i, row, peek)
        module = module_hint(row["path"])
        slug = slugify(row["symbol"], module)
        name = f"{i:02d}-{slug}.md"
        if name in used_names:
            raise SystemExit(f"Duplicate prompt filename: {name}")
        used_names.add(name)
        (PROMPTS / name).write_text(body, encoding="utf-8", newline="\n")
        index_lines.append(
            f"| {i:02d} | [`../prompts/{name}`](../prompts/{name}) | "
            f"`{row['symbol']}` | {clean_purpose(row['purpose'])} |"
        )
        print(f"wrote {name}")

    index_path = ROOT / "dialog-inventory" / "02-patient-encounter-flow-prompts.md"
    index_path.write_text("\n".join(index_lines) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote index {index_path.name} ({len(rows)} prompts)")


if __name__ == "__main__":
    main()
