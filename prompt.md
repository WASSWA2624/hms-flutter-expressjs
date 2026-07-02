# OPD Encounter Dialog — Gap Closure & UX Improvements

## Goal

Review and improve the shared **Start OPD encounter** dialog (`OpdEncounterDialog` in `frontend/lib/shared/components/opd_encounter_dialog.dart`) so staff can reliably start, follow up on, and close OPD encounters from every entry point, with clear workflow guidance and consistent billing defaults.

## Entry points (must behave consistently)

| Entry point | Current behavior | Expected behavior |
|---|---|---|
| **Patient profile → Quick action: Start OPD encounter** | Opens dialog for a known patient. Detects active encounter and shows summary banner; primary action becomes **Update encounter**. | Same, plus full follow-up affordances below. |
| **OPD workspace → Start OPD encounter** | Three tabs: **Existing patient**, **Appointment patient**, **New patient**. | Same tabs; **New patient** flow must create the patient first, then continue as an existing-patient encounter (see §5). |
| **Patient profile → Active work → Continue** | Opens the relevant downstream dialog (e.g. `FlowActionsDialog`). | Unchanged; ensure encounter dialog improvements align with this path. |

## 1. Active encounter summary — show what to do next

When an active OPD encounter is detected (`OpdFlowSummary` resolved via `_activeEncounterNotice`):

### Add
- **Next step** — display `flow.displayNextStep ?? flow.nextStep` using existing helpers (`opdNextStepDisplayLabel`). This is already shown in `OpdFlowActionsDialog` / OPD workspace table but **missing** from the encounter dialog banner.
- **Primary workflow action** — a clear CTA to proceed (e.g. **Continue encounter** / **Open workflow**) that opens `OpdFlowActionsDialog` for the active flow, matching the OPD queue “Next step” semantics.
- **Copyable identifiers** — use `AppCopyableIdentifier` for:
  - Encounter ID (`flow.apiId`)
  - Patient identifier (MRN / patient no. from the selected or initial patient)

### Fix
- **Stage duplication** — stage currently appears in both the status badge and the details grid. Keep one prominent stage display; use the freed slot for **Next step** (or remove redundant badge).
- **Visit type vs arrival mode** — when updating an active encounter, arrival mode in the form may disagree with the encounter’s visit type (e.g. encounter = Online Appointment, form = Walk In). Prefill arrival mode from the active encounter and disable or clearly label overrides.

## 2. Close / cancel active encounters

For any **non-terminal** active encounter shown in this dialog, provide:

- **Close encounter** — mark the encounter complete/closed through the appropriate OPD API (reuse existing repository/controller patterns).
- **Cancel encounter** — with a **reason**:
  - Prefer a **selectable list of predefined reasons** (e.g. *Patient left before consultation*, *Duplicate encounter*, *Entered in error*, *Patient already seen*, *Other*).
  - When *Other* is selected, show a free-text field.
  - Reuse existing l10n keys where possible (`opdCancelAction`, `opdCancellationReasonLabel`).

Place these as secondary/destructive actions in the dialog footer or active-encounter panel — visible when `_activeEncounter != null`, hidden for new starts.

> If backend endpoints for close/cancel do not exist yet, add them (or document the required API contract) before wiring the UI.

## 3. Form layout & clarity

Polish the encounter form so follow-up is scannable:

- **Routing** section — keep current layout (arrival mode, doctor search); ensure labels/helper text remain visible when an active encounter is present.
- **Billing** section — improve visual hierarchy:
  - Group consultation fee + currency, notes, **Payment required**, and **Payment received** clearly.
  - When updating an active encounter, reflect current billing state (paid / required / amount) from the flow; avoid implying a new payment is needed when already paid.
- Use existing form primitives (`AppFormSection`, `AppResponsiveFieldRow`, `AppFormInformationBanner`) — no new design system.

## 4. Consultation fee defaults (doctor → global fallback)

When a doctor is selected in **Search doctor (optional)**:

1. **Pre-fill consultation fee** from the provider’s HR profile (`OpdProviderOption.consultationFee`) — partially implemented in `_applyProviderDefaultsToState`.
2. **Fallback** — if the selected doctor has no fee, use the **facility/tenant standard consultation fee** configured by admin/HR.
3. **Currency** — follow the same precedence: doctor currency → global default → `appDefaultCurrencyCode`.
4. Only auto-fill when the fee field is empty or the user changes doctor (preserve manual edits).

### Admin configuration (if missing)
- Allow admin/HR to set a **standard consultation fee** (and currency) at facility or tenant level.
- Wire this into provider loading so `OpdEncounterDialog` receives the default without extra round-trips where possible.

## 5. New patient tab — two-step flow

**Current:** New patient tab embeds `RegisterNewPatientForm` and submits patient + encounter in one payload (`patient_registration`).

**Expected:**
1. User completes new patient registration and submits **Create patient** (or equivalent).
2. On success, dialog **switches to Existing patient** tab with the newly created patient pre-selected.
3. User completes routing/billing and clicks **Start encounter** as for any existing patient.

Do **not** require the user to manually search for the patient they just created.

## 6. Reuse existing implementations

Before adding new code, audit and reuse:

| Concern | Existing reference |
|---|---|
| Next step labels | `opdNextStepDisplayLabel`, `opd_status_display.dart` |
| Workflow actions | `OpdFlowActionsDialog` (`frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`) |
| Copy to clipboard | `AppCopyableIdentifier` |
| Active encounter update | `opdRepository.updateActiveEncounter` (patient registry path) |
| Post-update workflow open | `_openPatientOpdEncounterDialog` → `FlowActionsDialog` pattern in `patient_registry_page.dart` |
| Provider fee on staff | HR staff onboarding (`consultation_fee` field) |

## Acceptance criteria

- [ ] Active encounter banner shows **Next step** and copyable encounter + patient IDs.
- [ ] User can **continue** the workflow (open `OpdFlowActionsDialog`) directly from the encounter dialog when an active encounter exists.
- [ ] User can **close** or **cancel** an active encounter with a predefined reason (and optional free text).
- [ ] Stage is not duplicated; visit type and arrival mode stay consistent when updating.
- [ ] Selecting a doctor pre-fills fee from doctor profile, else from global standard fee.
- [ ] New patient tab: create patient → auto-switch to existing patient → start encounter.
- [ ] All three entry points behave consistently.
- [ ] Widget tests updated in `start_walk_in_dialog_test.dart` and `patient_registry_page_test.dart`.

## Testing

- Extend existing dialog tests for: active encounter with `nextStep`, copy actions, cancel/close flows, doctor fee prefill (with and without provider fee), new-patient two-step flow.
- Manually verify scenarios from screenshots: Amina Demo-Alpha (active encounter), Wilson Wampamba (no encounter), OPD workspace (all three tabs).

## Out of scope (unless required by API gaps)

- Changes to OPD workspace table columns or queue prioritization.
- Broader patient profile / active-work list redesign.
