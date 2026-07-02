# Patient detail modal — Active work & Quick actions UX

## Context

On the **patient detail dialog** (`PatientDetailDialog` in `patient_registry_page.dart`), two sections need clearer affordances:

1. **Active work** — lists in-flight items (encounters, queue entries, admissions, orders, etc.) with a **Continue** action.
2. **Quick actions** — permission-gated shortcuts (schedule appointment, start OPD, request admission, lab, radiology, theater, physiotherapy, report).

Reference screenshot: patient **Wilson Wasswa** shows two active-work rows both titled **Jordan Demo**, one badge **Open** and one **In Progress**, with no indication of *what* is open or in progress.

## Problem 1 — Active work labels are ambiguous

**Current behavior** (`patient_detail_active_work.dart`, `patient_active_work_helpers.dart`):

- Status badges use raw API values via `AppDisplay.apiLabel(item.status)` → e.g. "Open", "In Progress".
- Row title is `item.title` (often a facility/clinic name like "Jordan Demo"), not the work type.
- Subtitle and timestamp repeat context without clarifying whether the row is an **encounter**, **queue entry**, **admission request**, **lab order**, etc.

**Expected behavior:**

Each active-work row must answer three questions at a glance:

| Question | Example |
|---|---|
| **What** is this? | "OPD encounter", "Visit queue", "Admission request", "Lab order" |
| **Where / which**? | Facility, department, or public ID (e.g. Jordan Demo, ENC0000123) |
| **Status** | Contextual badge, not a bare API token |

### Implementation guidance

- Add a localized **work-type label** derived from `PatientActiveWorkKind` (and admission-specific handling for `REQUESTED` via `isPendingPatientAdmissionRequest`).
- Restructure the row layout:
  - **Primary line:** work type (semibold) + status badge.
  - **Secondary line:** facility / location / public ID (`subtitle` or `title` as appropriate).
  - **Tertiary line:** timestamp (unchanged).
- Replace generic `AppDisplay.apiLabel(item.status)` with **kind-aware status labels** where raw values are misleading (e.g. encounter `OPEN` → "Encounter open", queue `IN_PROGRESS` → "In queue").
- Add l10n keys in `app_en.arb` / `app_fr.arb`; run codegen.
- Update `patient_active_work_helpers_test.dart` and add widget/unit coverage for label mapping.

**Key files:** `patient_active_work_helpers.dart`, `patient_detail_active_work.dart`, `app_en.arb`, `app_fr.arb`.

## Problem 2 — Quick actions lack hover feedback and tooltips

**Current behavior** (`patient_detail_quick_actions.dart`, `AppPermissionActionList`, `AppButton`):

- Buttons render but **hover state is barely visible** on the light dialog surface.
- `AppPermissionActionItem` supports `tooltip`, but patient quick actions **never set it**.
- When an action is disabled (missing permission, inactive module, or contextual guard like `hasActiveAdmission`), the user gets a greyed-out button with **no explanation**.

**Expected behavior:**

- Every quick-action button shows a **Material tooltip on hover** (with the standard arrow) describing what the action does.
- When disabled, the tooltip explains **why** (e.g. "Requires clinical write permission", "Inpatient module not enabled", "Patient already has an active admission", "A lab order is already in progress").
- Hover/focus states are visually distinct (foreground emphasis and/or subtle background) even for `AppButtonVariant.secondary` on white surfaces.

### Implementation guidance

- Pass `tooltip` on each `AppPermissionActionItem` in `patient_detail_quick_actions.dart`.
- Extend `AppPermissionActionButton` (or a small helper) to resolve a **denial reason** from `AccessRequirement` + contextual `enabled` flags, and surface it as the tooltip when `enabled && isAllowed` is false.
- Verify hover styling in `AppButton._buttonStyle` for secondary variant on `surfaceContainerLowest` / white backgrounds; adjust `backgroundColor` or `overlayColor` on `WidgetState.hovered` if needed.
- Add l10n keys for tooltip messages (action description + denial reasons).
- Manually verify on web (Chrome): hover shows tooltip with arrow; disabled actions explain the blocker.

**Key files:** `patient_detail_quick_actions.dart`, `app_permission_action.dart`, `app_button.dart`, `access_requirement.dart`.

## Acceptance criteria

- [ ] Active-work rows display a clear **work type**; status badges are contextual, not bare API labels.
- [ ] Two rows for the same facility (e.g. encounter + queue) are distinguishable without opening **Continue**.
- [ ] All quick-action buttons have tooltips; disabled buttons explain why they are unavailable.
- [ ] Hover/focus on quick actions is visibly distinct on the patient detail dialog.
- [ ] EN + FR strings added; existing tests updated; new label-mapping tests pass.
- [ ] No unrelated refactors; follow existing patterns (`AppPermissionActionList`, `AppStatusText`, l10n conventions).

## Out of scope

- Changing backend status enums or active-work collection logic (unless required for correct labels).
- Redesigning the full patient detail dialog layout.
