# HR Multi-Compensation Pay Structure — UI, Payroll Engine & Schedule Sync

## Objective

Evolve staff compensation from a **single active pay structure** into a **multi-rate pay profile** so clinical and operational staff (e.g. doctors, surgeons, nurses) can hold **concurrent compensation lines** — monthly base, hourly shift pay, daily rate, consultation fee, and procedure fee — each with its own rate, currency, and effective dates.

Payroll must **aggregate all applicable lines** for a pay period using **real activity and schedule data** (shifts, availability, leave, consultations, procedures), not a single dropdown selection. Implement end-to-end on **backend and frontend**.

**Entry points (from screenshots):**

- HR workspace (`/hr`) → select staff → **Staff detail** → **Compensation** action or Compensation section
- Staff detail → **Run payroll** (gated on at least one compensation line)
- Staff onboarding compensation step (optional initial multi-line setup)

**Parent context:** [prompts/24-hr-module-prompt.md](./prompts/24-hr-module-prompt.md) §6 Payroll and compensation

**Primary touchpoints:**

| Area | File |
|------|------|
| Update compensation dialog (Pay structure / History tabs) | `frontend/lib/features/hr/presentation/widgets/hr_compensation_dialog.dart` |
| Staff detail compensation section & actions | `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`, `hr_staff_detail_actions.dart`, `hr_staff_detail_helpers.dart` |
| Onboarding compensation (single-line today) | `frontend/lib/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart` |
| Payroll preview / process wizard | `frontend/lib/features/hr/presentation/widgets/hr_payroll_wizard_dialog.dart`, `hr_enhanced_dialogs.dart` |
| HR entities & DTOs | `frontend/lib/features/hr/domain/entities/hr_entities.dart`, `data/dtos/hr_dtos.dart` |
| HR repository / controller | `frontend/lib/features/hr/data/repositories/hr_repository_impl.dart`, `presentation/controllers/hr_workspace_controller.dart` |
| Pay type catalog | `backend/src/lib/hr/reference-data.js` (`COMPENSATION_PAY_TYPE_CATALOG`) |
| Staff profile compensation sync | `backend/src/modules/staff-profile/services/staff-profile.service.js` (`syncStaffCompensations`) |
| Compensation validation | `backend/src/modules/staff-profile/schemas/staff-profile.schema.js` |
| Payroll calculation engine | `backend/src/modules/hr-workspace/services/hr-workspace.service.js` (`buildPayrollProposedItems`, `calculateCompensationAmount`) |
| DB model | `backend/prisma/schema.prisma` (`staff_compensation`) |
| Strings | `frontend/lib/l10n/app_en.arb` |

---

## Problem Statement (from current UI)

The **Update compensation** dialog exposes one form for a single pay structure at a time:

1. **Single-line editing** — Pay type, pay frequency, base rate, and effective dates are bound to one row. Changing pay type replaces the active structure instead of adding another concurrent line. A doctor who earns a monthly retainer **and** per-consultation **and** per-procedure fees cannot configure all three in one save.
2. **History vs active structure conflated** — The **History** tab lists past rows but the **Pay structure** tab only hydrates from `history.first`, so secondary active pay types are invisible in the editor.
3. **Payroll preview lacks activity breakdown** — Run payroll is enabled when any compensation exists, but preview does not clearly show per–pay-type line items, quantities (hours, days, consultations, procedures), or how schedule/leave affected eligibility.
4. **Engine gaps** — Backend `calculateCompensationAmount` handles `PER_HOUR`, `PER_MONTH`, and `PER_PROCEDURE` only; `PER_DAY` and `PER_CONSULTATION` return zero. Procedure counts come from `metadata_json.procedure_count`, not clinical activity. Daily/monthly proration does not yet use availability slots or approved leave.
5. **Schedule not in sync** — Compensation, availability, shifts, leave, and payroll operate as separate flows. Daily-rate staff should be paid for **worked/eligible days** derived from availability and shifts minus approved leave, not arbitrary period proration alone.

---

## Global Standards

Follow the same rules as the HR module prompt:

- Hospital workflow language — pay type labels from `hrReferenceCompensationPayTypeLabel`; show staff name, staff number, and rate summaries; avoid raw UUIDs in primary UI.
- Modal-first: compensation and payroll flows use `AppDialog` / `showAppWorkspaceMutationDialog`.
- Reuse `frontend/lib/shared/*` form components (`AppSelectField`, `AppCurrencyAmountField`, `AppDateField`, `AppFormSection`).
- All new/changed strings in `frontend/lib/l10n/app_en.arb`.
- Permission-gate writes with `hrWrite` (+ `financialApprove` for payroll process).
- Refresh staff detail compensation list after every mutation without full-page reload.
- Pay types must stay aligned with `COMPENSATION_PAY_TYPES`: `PER_CONSULTATION`, `PER_MONTH`, `PER_DAY`, `PER_HOUR`, `PER_PROCEDURE`.
- Do **not** add new pay types without product approval; extend calculation and UI for the existing catalog first.

---

## 1. Multi-Line Compensation UI

### 1.1 Pay structure tab — concurrent lines

Replace the single-form **Pay structure** tab with a **multi-row editor**:

| Column / field | Behavior |
|----------------|----------|
| Pay type | Required; one row per pay type; prevent duplicate pay types in the active set |
| Pay frequency | Optional; store in `metadata_json.pay_frequency` (`MONTHLY`, `BIWEEKLY`, `WEEKLY`) for salaried lines |
| Base rate + currency | Required per row |
| Effective from | Required |
| Effective to | Optional |

**Actions:**

- **Add pay line** — append a new row (default pay type = next unused catalog entry).
- **Remove pay line** — remove unsaved row or mark existing row ended (set `effective_to` to today or next period start; do not hard-delete history).
- **Edit row** — inline or expand-in-place; opening detail from staff Compensation section should focus the matching row.

Persist via existing `PUT /staff-profiles/:id` payload shape:

```json
{ "compensations": [ { "pay_type", "rate", "currency", "effective_from", "effective_to", "metadata_json" } ] }
```

`syncStaffCompensations` already soft-deletes and recreates rows — preserve that pattern but ensure the UI sends the **full intended active set**, not one line plus silent history merge.

### 1.2 History tab

Group history by pay type. Show ended rows with effective date range and rate. Distinguish **active** (no `effective_to` or future-dated end) vs **ended** rows. Tapping a history row opens read-only detail (`showHrCompensationDetailDialog`) with **Add new rate** pre-selecting that pay type.

### 1.3 Staff detail Compensation section

When multiple active lines exist, list **all** active compensations (not only the first). Each row: localized pay type, rate + currency, effective range. Empty state CTA opens multi-line editor.

### 1.4 Onboarding (stretch)

Allow optional multi-line compensation during onboarding using the same row component extracted from the compensation dialog. Minimum for this task: shared row widget reused by update dialog; onboarding may follow in a follow-up if time-boxed.

---

## 2. Backend Compensation API

### 2.1 Validation

- Accept `compensations` array on staff profile create/update (already in schema).
- Reject duplicate `pay_type` values in a single payload.
- Validate `effective_to >= effective_from` per row (already in `compensationInputSchema`).
- Return hydrated `compensations` on staff profile GET/detail responses ordered by `effective_from` desc, active lines first.

### 2.2 Sync semantics

Keep transactional soft-delete + recreate in `syncStaffCompensations`. Document that clients must send the complete desired compensation set. Optionally support row-level `id` for audit without changing delete-and-recreate if straightforward.

---

## 3. Payroll Engine — Multi-Type Calculation

### 3.1 Extend `calculateCompensationAmount`

Implement missing pay types and tighten formulas:

| Pay type | Quantity source | Formula |
|----------|-----------------|---------|
| `PER_HOUR` | Sum of shift assignment durations in period (existing) | `rate × hours` |
| `PER_DAY` | Eligible workdays in period from availability + assigned shifts, minus approved leave days | `rate × eligible_days` |
| `PER_MONTH` | Calendar proration over pay period intersecting effective dates (existing); optionally cap by eligible workdays when `metadata_json.pay_frequency` is not monthly | `rate × eligible_days / period_days` |
| `PER_CONSULTATION` | Count of completed consultations attributed to staff in period (OPD/clinical module linkage or HR workspace aggregate endpoint) | `rate × consultation_count` |
| `PER_PROCEDURE` | Count of completed procedures attributed to staff in period | `rate × procedure_count` |

Each component returns a `calculation` object: `{ pay_type, rate, currency, quantity, unit, formula, source_refs }`.

### 3.2 `buildPayrollProposedItems`

- For each staff member in scope, load **all** effective compensations for the run period (already queried).
- Compute each line independently; **sum amounts** per staff (same currency; if mixed currencies, return separate subtotals or primary currency + warning — match existing `normalizeMoney` behavior).
- Include in `calculation_json.components` every pay type with quantity and amount (not only hourly).
- Staff-scoped preview (`staff_profile_id` filter) must return the same component breakdown.

### 3.3 Activity & schedule inputs

Introduce or reuse queries for period-scoped:

- **Shifts** — `shift_assignment` (existing).
- **Availability** — `staff_availability` slots overlapping period (for eligible day/hour denominators).
- **Leave** — approved `staff_leave` rows excluding days from eligible counts.
- **Consultations / procedures** — prefer existing clinical billing or encounter tables; if not wired yet, add a thin HR aggregate service with clear TODO hooks and seed/demo counts for demo tenants.

Document data sources in code comments; do not invent parallel clinical APIs inside HR widgets.

---

## 4. Payroll & Compensation UI Sync

### 4.1 Run payroll wizard

- Before process, **Preview payroll** must show a **per-staff expandable breakdown**: each compensation line, quantity, rate, subtotal, gross total.
- When staff has multiple pay types, show all components; do not collapse to a single hourly rate field.
- Surface warnings when a configured pay type has **zero quantity** in the period (e.g. procedure rate set but no procedures recorded).
- Keep **Replace existing payroll items** and period/facility filters.

### 4.2 Cross-feature consistency

| Feature | Sync expectation |
|---------|------------------|
| **Record availability** | Availability changes affect `PER_DAY` / `PER_HOUR` denominators on next payroll preview |
| **Assign shift** | Shift hours feed `PER_HOUR`; shift days feed `PER_DAY` |
| **Request / approve leave** | Approved leave subtracts from eligible days |
| **Compensation update** | Staff detail and payroll preview refresh; run payroll stays disabled until at least one active line exists |

After compensation save, invalidate staff detail and any open payroll preview for that staff member.

---

## 5. Testing & Acceptance Criteria

### Backend

- Unit tests for `calculateCompensationAmount` covering all five pay types, leave exclusion, and multi-line summation.
- Tests for duplicate `pay_type` rejection and multi-row `syncStaffCompensations`.
- Payroll preview fixture: staff with monthly + consultation + procedure lines returns three `components` and correct gross total.

### Frontend

- Widget test: compensation dialog renders multiple rows, add/remove, submits full array.
- Staff detail shows two+ active compensation rows.
- Payroll preview displays component breakdown labels from l10n.

### Manual (demo staff e.g. Avery Demo)

1. Open **Staff detail** → **Compensation**.
2. Add **Monthly rate** + **Consultation fee rate** + **Procedure rate** with distinct rates and shared or staggered effective dates; save.
3. Staff detail Compensation section lists all three active lines.
4. **Run payroll** for a period with shifts and (seeded) consultations/procedures → preview shows line items per pay type with quantities and subtotals.
5. Approve leave spanning part of the period → daily/monthly eligible days decrease in preview calculation metadata.
6. Change availability → re-preview reflects updated eligible days/hours.

---

## 6. Out of Scope (unless trivial)

- New pay types beyond the existing catalog.
- Full general-ledger export or tax withholding rules.
- Replacing facility-wide payroll run creation UX (only enhance calculation + preview fidelity).
- OPD encounter UI changes — consume data via backend aggregates only.

---

## 7. Delivery Notes

- Extract a reusable `HrCompensationLineEditor` (or equivalent) shared by update dialog and optionally onboarding.
- Prefer extending `calculateCompensationAmount` and preview DTOs over one-off frontend math.
- Keep `metadata_json` for pay frequency and future extensibility; avoid schema migration unless `pay_frequency` must be first-class.
- Update [prompts/24-hr-module-prompt.md](./prompts/24-hr-module-prompt.md) §6 status line when complete.
