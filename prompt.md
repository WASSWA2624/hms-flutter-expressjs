# Feature: Refine Radiology workflow detail dialog header & view mode

## Goal

Improve the **Radiology workflow** detail dialog (opened from a worklist row) so key patient/order context is scannable at a glance and workflow actions are self-explanatory. Scope is the dialog header and view-mode switch only; workflow steps, order metadata grid, and section content stay as-is.

## Current state (keep)

Do not regress:

- Dialog title: **Radiology workflow** (`radiologyDetailTitle`).
- Patient name as the primary headline.
- **Order metadata** grid below the header (Order, Modality, Priority, Ordered, Encounter, Payment).
- **Workflow progress** stepper and scroll-to-section behavior.
- Imaging-floor vs reporting section ordering and conditional actions.
- Existing l10n keys for actions (`radiologyAssignAction`, `radiologyStartImagingAction`, `radiologyPerformStudyAction`, `radiologyCancelOrderAction`, etc.).

## Problem (see screenshot)

| Area | Current behavior | Issue |
|------|------------------|-------|
| **Header actions** | Assign, Start imaging, Perform study, Cancel render as icon-only chips | `_WorkspaceHeaderActions` forces `AppActionLabelScope(showLabels: false, forceIconOnly: true)`; users cannot tell what each button does |
| **Patient context row** | Patient ID + status on one line; study on a separate row; billing as a warning alert below | Context is fragmented across three visual bands |
| **View mode** | `SegmentedButton` for *Imaging floor* / *Reporting* | Filled segments with border/background feel heavy; user wants plain radio-style selection |

## Reference implementation

**Primary file:** `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`

- Header: `_RadiologyDetailBody` → `AppWorkspacePatientContextHeader` (lines ~681–713).
- Actions: `_buildHeaderActions` (Assign, Start imaging, Perform study, Cancel, etc.).
- View mode: `_RadiologyViewModeSection` (`SegmentedButton<RadiologyDetailViewMode>`).

**Shared components:**

- `frontend/lib/shared/layout/app_workspace.dart` — `AppWorkspacePatientContextHeader`, `_WorkspaceHeaderActions`, `_PatientContextMetaLine`, `_PatientContextInlineFacts`.
- `frontend/lib/shared/components/app_radio_group.dart` — `AppRadioGroup` / `RadioGroup` for borderless radio toggles.
- Billing label helper: `_billingGateLabel` in `radiology_workspace_page.detail_cells.dart`.

## Required changes

### 1. Label header workflow actions

Show **visible text labels** on all workflow action buttons in the dialog header (icon + label, or label-only on very narrow widths—never icon-only without a label).

- Prefer a radiology-specific opt-in on `AppWorkspacePatientContextHeader` (e.g. `showActionLabels: true`) rather than changing `_WorkspaceHeaderActions` globally for every workspace.
- Preserve existing button variants (secondary / primary / tertiary), loading state, and permission gating (`canWork`, `nextActions` flags).
- Keep tooltips/semantics aligned with the visible label.

### 2. Consolidate patient context into one metadata row

Below the patient name, render **one horizontal facts row** (wrap when space is tight):

| Item | Source | Notes |
|------|--------|-------|
| **Patient ID** | `order.patientId` | Label from `radiologyPatientIdLabel`; keep copy affordance |
| **Status** | `_orderStatus(context, order)` | `AppWorkspaceStatusBadge` |
| **Study** | `order.testDisplayName` | Label from `radiologyStudyLabel` |
| **Billing** | `_billingGateLabel(context, order)` | Use warning tone when gate unavailable; success/neutral when confirmed |

- Use `Wrap` or equivalent so items stay on one row on desktop and reflow gracefully on narrow dialog widths.
- Remove redundant duplication: billing should appear in this row **instead of** a separate alert chip when the same information is shown (avoid “Billing gate unavailable” twice).
- Patient name remains on its own line above this row.

### 3. Replace view-mode segmented control with radio buttons

In `_RadiologyViewModeSection`, replace `SegmentedButton` with a **borderless radio group**:

- Options: **Imaging floor** (`radiologyViewModeImagingFloorLabel`) and **Reporting** (`radiologyViewModeReportingLabel`).
- No segment background, outline, or pill container—selected state via radio indicator + typography/color only.
- Reuse `AppRadioGroup` or `RadioGroup` if it fits; otherwise match existing clinical radio patterns (e.g. `clinical_request_billing_panel.dart`).
- Keep helper text below (*Perform studies, acquire images…* / reporting equivalent) unchanged.

## Implementation rules

- **Minimal scope:** dialog header layout + view-mode control only; do not refactor worklist table, filters, or backend.
- **Reuse shared primitives** from `frontend/lib/shared/`; extend `AppWorkspacePatientContextHeader` only if radiology cannot achieve the layout with existing `fields`, `alerts`, and `secondaryFields` props.
- **No new visual language**—match existing typography, spacing tokens, and badge tones.
- **Localization:** reuse existing l10n keys; add new keys only if a label is genuinely missing.
- **Responsive:** verify at dialog `maxWidth: 980` and compact/mobile widths.

## Acceptance criteria

- [ ] Header workflow buttons show readable labels (Assign, Start imaging, Perform study, Cancel, etc.)—not icon-only.
- [ ] Below patient name, Patient ID, order status, study, and billing appear on a **single metadata row**, wrapping only when width requires it.
- [ ] Billing gate status is shown once in that row (no duplicate alert for the same state).
- [ ] Imaging floor / Reporting uses borderless radio buttons, not a segmented control.
- [ ] Order metadata grid, workflow progress, and section bodies are unchanged.
- [ ] Existing permissions, loading states, and action enablement logic still work.
