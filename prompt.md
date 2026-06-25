# Theater — Schedule Case Dialog UX Refinement

## Objective

Replace the **Schedule theater case** modal (`_ScheduleCaseForm` in `theater_workspace_page.dart`) so coordinators schedule cases using **searchable selects and proper date/time inputs** — never raw UUIDs or ISO strings.

Billing must support **multiple catalog procedures with prices**, **pay-now vs bill-later**, and visibility in the **Billing** module.

**Entry point:** Theater workspace → **Schedule case** action (full create flow; not reschedule-only mode).

**Parent context:** This is a focused slice of the Theater module. Read [prompts/21-theater-module-prompt.md](prompts/21-theater-module-prompt.md) and [flows/theater-flow.mdc](.cursor/flows/theater-flow.mdc) before implementing.

**Central encounter rule:** Theater cases attach to an existing encounter (IPD admission hub, OPD visit, or emergency-linked encounter). Theater does not create parallel admission records.

---

## Global Implementation Standards

| Area | Requirement |
| ---- | ----------- |
| UI/UX | Hospital workflow language — not enum names or UUIDs. Follow `frontend/.cursor/design-system.mdc`, `components.mdc`, `ui-patterns.mdc`, `ui-workspace.mdc`. Reuse `frontend/lib/shared/*` before new widgets. |
| Theming and i18n | All user-visible strings in `app_en.arb` — no hardcoded labels. |
| Modal-first | Stay in-dialog; do not navigate to new routes for this workflow. |
| Architecture | Widgets → Riverpod controller → repository → API. **No API calls from widgets.** |
| Permissions | `AccessGate` / `AppAccessActionGate`; price override requires `billingWrite`. |
| Quality gate | From `frontend/`: `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`. |

---

## Mandatory Reading

1. [app-write-up.mdc](.cursor/app-write-up.mdc) — Theater vs IPD, ICU, Billing boundaries.
2. [flows/theater-flow.mdc](.cursor/flows/theater-flow.mdc) — case lifecycle and handoff.
3. [flows/ipd-flow.mdc](.cursor/flows/ipd-flow.mdc) — §7 surgery route, §9 OT transfer, §11 `In Procedure / OT`.
4. [flows/opd-flow.mdc](.cursor/flows/opd-flow.mdc) — elective surgery from outpatient planning.

---

## Current State (do not regress)

| Field | Today | Problem |
| ----- | ----- | ------- |
| Encounter | `AppTextField` → `encounter_id` | Users must know/paste IDs |
| Scheduled at | `AppTextField` (ISO string) | No date/time picker |
| Room | `AppTextField` → `room_id` | No OT room list |
| Surgeon / Anesthetist | `AppTextField` → `*_user_id` | No name search |
| Billing | Single hardcoded `THEATRE_CASE_FEE` line | No procedure catalog, no multi-line items |
| Stage notes | Multiline `AppTextField` | **Keep as-is** |

**API contract** (`POST /theatre-flows/start`, `startTheatreFlowSchema` in `backend/src/modules/theatre-flow/schemas/theatre-flow.schema.js`): UI shows human labels; payload still submits internal IDs — `encounter_id`, `scheduled_at`, `room_id`, `surgeon_user_id`, `anesthetist_user_id`, `source_kind`, `billing`, etc.

---

## Reference Patterns (reuse, do not reinvent)

| Need | Existing pattern |
| ---- | ------------------ |
| Patient → encounter dual select | `LabOrderContextDialog` — `AppSelectField.searchable` + `AppResponsiveFieldRow.two` (`shared/lab_catalog/lab_catalog_dialogs.dart`) |
| Patient/encounter APIs | `LabRepository.searchOrderContextPatients` + `getOrderContextPatient` — mirror or share for theater |
| Date + time | `AppDateField` + `AppTimeField` in `AppResponsiveFieldRow.two` (`clinical_follow_up_action_dialog.dart`) |
| Staff search by name | Nursing handover — `searchUsers` + `AppSelectField.searchable` with `onSearchTextChanged` (`nursing_workspace_page.dart`) |
| Procedure picker (multi) | `ClinicalProcedureCatalogDialog` + `ClinicalProcedureActionDialog` |
| Billing panel | `ClinicalRequestBillingPanel` (already wired in `_ScheduleCaseForm`; extend line items dynamically) |
| Searchable select | `AppSelectField.searchable` (`app_select_field.dart`) — supports `leadingIcon`, `searchText` |

> **“Double select”** in this codebase means the **Lab patient + encounter pattern** — two linked `AppSelectField.searchable` fields, not a separate widget.

---

## Form Layout & Field Requirements

### 1. Patient context (dual select)

Replace the single **Encounter ID** field with a two-step select:

**Patient** — `AppSelectField.searchable`

- Debounced remote search (name, MRN/patient number, phone when available).
- Option label: patient display name + identifier subtitle.
- Required.

**Encounter** — `AppSelectField.searchable` (enabled after patient is selected)

- Load encounters for the selected patient (active IPD admissions, OPD visits, emergency-linked encounters).
- Option label: encounter type/source + date + ward/location (e.g. `IPD · Ward 3 · ENC-0042`).
- Required.
- On selection: auto-derive `source_kind` (`IPD` | `OPD` | `EMERGENCY`) and show a read-only **Source** chip.
- **ICU patients** arrive via IPD admission — show as IPD with ICU location in the encounter subtitle (backend `source_kind` has no separate ICU value).

Layout: `AppResponsiveFieldRow.two` on wide screens; stack on narrow.

**Pre-selection:** If opened from IPD/ICU/Emergency deep link with patient/encounter context, pre-fill both selects.

### 2. Scheduled at

Replace the text field with **`AppDateField` + `AppTimeField`**.

- Required.
- Combine into ISO datetime for `scheduled_at` on submit.
- Optional default: next sensible slot (e.g. today + 1 hour).

### 3. Operating room

Replace **Room ID** with `AppSelectField.searchable`.

- Options: OT/theatre rooms for the facility (`room` records resolved by theatre-flow).
- Label: room name; subtitle: ward/building when available.
- Optional but recommended.
- If source context affects room choice, filter or sort accordingly and add brief helper text.

### 4. Surgeon

`AppSelectField.searchable` with remote staff search.

- Search: name, staff ID, phone (tenant/facility scoped).
- Prefer surgeon-role filter when API supports it; otherwise show role in subtitle.
- Submit `surgeon_user_id` internally — never show UUID in the field.
- Optional.

### 5. Anesthetist

Same pattern as surgeon; prefer anesthetist-capable users when API supports it.

- Submit `anesthetist_user_id`.
- Optional.

### 6. Stage notes

**No change** — multiline `AppTextField` → `stage_notes`.

---

## Billing Section

Replace the single `THEATRE_CASE_FEE` line with a **procedure billing block**.

### Procedure lines

- Add procedures via nested `ClinicalProcedureCatalogDialog` (or a thin theatre wrapper).
- Support **multiple procedures** per scheduled case.
- Each line: procedure name/code, quantity, **unit price from catalog**, line total, currency.
- Allow **manual price override** when user has `billingWrite` (same rules as `ClinicalRequestBillingPanel`).
- Show **grand total + currency** prominently (reuse existing total row).

### Pay now vs bill later

Keep `ClinicalRequestBillingPanel` segmented control:

| Mode | Behavior |
| ---- | -------- |
| **Bill later** | Create case + billing intent; Billing workspace sees pending charges. No payment captured in Theater. |
| **Pay now** | Show `AppCurrencyAmountField`, payment method, reference. Amount auto-syncs to total until user edits. Payload uses existing `billing` schema. |

### Payment methods

Add `leadingIcon` per method on `AppSelectField` options:

| Method | Icon |
| ------ | ---- |
| `CASH` | `Icons.payments_outlined` |
| `CARD` | `Icons.credit_card_outlined` |
| `MOBILE_MONEY` | `Icons.phone_android_outlined` |
| `BANK_TRANSFER` | `Icons.account_balance_outlined` |
| `INSURANCE` | `Icons.health_and_safety_outlined` |
| `OTHER` | `Icons.more_horiz_outlined` |

Extract a shared `clinicalRequestPaymentMethodOptions(l10n)` helper if OPD and theater both need icons.

### Billing module visibility

Bill-later and partial-pay charges must appear in the Billing workspace via existing clinical-request billing integration (same path as Lab/OPD). Do not duplicate cashier UI in Theater beyond capture-at-schedule.

---

## Data Layer (new controller/repository methods)

Theater has no search helpers today. Add to `theater_workspace_controller.dart` + `theater_repository` (or reuse shared endpoints):

| Method | Purpose | Likely source |
| ------ | ------- | ------------- |
| `searchSchedulePatients(query)` | Patient dual-select step 1 | Mirror `LabRepository.searchOrderContextPatients` |
| `loadSchedulePatientEncounters(patientId)` | Encounter options step 2 | Mirror `LabRepository.getOrderContextPatient` |
| `searchTheatreRooms(query)` | OT room select | Facility `room` list filtered for theatre use |
| `searchTheatreStaff(query, {role})` | Surgeon/anesthetist select | Mirror `NursingRepository.searchUsers` with role filter |

Debounce search in the widget; call controller methods only.

---

## Submit Payload

On success, pop the same map shape `_ScheduleCaseForm` uses today:

```dart
{
  'encounter_id': selectedEncounterId,
  'scheduled_at': combinedDateTime.toUtc().toIso8601String(),
  if (selectedRoomId != null) 'room_id': selectedRoomId,
  if (selectedSurgeonId != null) 'surgeon_user_id': selectedSurgeonId,
  if (selectedAnesthetistId != null) 'anesthetist_user_id': selectedAnesthetistId,
  if (derivedSourceKind != null) 'source_kind': derivedSourceKind, // IPD | OPD | EMERGENCY
  'workflow_stage': 'PRE_OP',
  'stage_notes': notes,
  if (charge) 'billing': billing.toPayloadMap(),
}
```

---

## Reschedule Mode

When `rescheduleOnly: true`:

- Hide patient, encounter, and billing sections (unchanged scope).
- Apply datetime, room, surgeon, anesthetist, and notes improvements from this prompt.

---

## Architecture & UX Rules

- Extract `_ScheduleCaseForm` to `presentation/widgets/theater_schedule_case_form.dart` if `theater_workspace_page.dart` grows further.
- Replace user-facing `*IdLabel` strings with workflow language: Patient, Encounter, Operating room, Surgeon, Anesthetist.
- Partial refresh after modal success per `frontend/.cursor/realtime_sync.mdc`.

---

## Out of Scope

- Backend schema changes unless required for patient/encounter/room search (prefer reusing existing lab/patient/nursing endpoints).
- Full theater module completion (case board, anesthesia, post-op) — see [prompts/21-theater-module-prompt.md](prompts/21-theater-module-prompt.md).
- Owning IPD admission creation or ICU stay lifecycle.

---

## Acceptance Criteria

- [ ] Schedule dialog has no raw ID or ISO datetime text inputs for primary fields.
- [ ] Patient → encounter dual select works with search and cascading enablement.
- [ ] Scheduled at uses date/time pickers.
- [ ] Room, surgeon, and anesthetist are searchable selects; payload uses internal IDs.
- [ ] Multiple procedures can be added with catalog prices and editable totals.
- [ ] Total + currency displayed; pay now / bill later matches other clinical request flows.
- [ ] Payment methods show icons in the dropdown.
- [ ] Bill-later charges visible in Billing module (or gap documented in PR).
- [ ] Reschedule dialog keeps encounter/billing hidden; inherits datetime/room/staff improvements.
- [ ] `flutter analyze` and theater controller tests pass.

---

## Quality Gate

```sh
cd frontend
dart format --set-exit-if-changed .
flutter analyze
flutter test test/features/theater/
```

---

## Key Files

```
frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart
frontend/lib/features/theater/presentation/widgets/theater_schedule_case_form.dart   # new — extract form
frontend/lib/features/theater/presentation/controllers/theater_workspace_controller.dart
frontend/lib/features/theater/data/repositories/theater_repository_impl.dart
frontend/lib/shared/clinical_actions/clinical_request_billing_panel.dart             # payment icons (optional shared)
frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart                             # reference pattern
frontend/lib/l10n/app_en.arb
frontend/test/features/theater/presentation/theater_workspace_controller_test.dart
backend/src/modules/theatre-flow/schemas/theatre-flow.schema.js
```

---

## Notes for Implementer

1. Billing panel and procedure catalog already exist — this is mostly **wiring and UX**, not new billing infrastructure.
2. Backend `source_kind` is `IPD | OPD | EMERGENCY` only.
3. Payment method icons in `ClinicalRequestBillingPanel` benefit Lab, Radiology, and other modules using the same panel.
4. `procedure_name` on `startTheatreFlowSchema` is optional; derive a summary from the first selected procedure or join multiple names if the API accepts it.
