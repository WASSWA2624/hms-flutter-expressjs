# Pharmacy Create Order: Reuse Clinical Prescribe Medicines Flow

Replace the pharmacy walk-in medicine line form with the shared clinical Prescribe medicines workflow, keep a pharmacy-owned patient shell, and default new orders to Anonymous.

## Context

**Current behavior (Create order)**

- Entry points: pharmacy workspace walk-in / Create order, and home quick action `record_pharmacy_sale` → `showPharmacyWalkInOrderDialog` (`pharmacy_walk_in_order_dialog.dart`).
- Patient modes: Existing, New (when `patient:write`), Anonymous. Default today is **Existing**.
- Medicines: stacked inline lines (searchable drug dropdown, quantity, free-text dose, instructions). No medicines table, catalog multi-add, filters, column settings, structured dosing, or Review billing.
- Submit: `POST /api/v1/pharmacy/orders` via `createPharmacyOrder` with optional `patient_id` (omitted when Anonymous), no `encounter_id`. Backend already allows nullable `patient_id` (`20260806140000_pharmacy_order_optional_patient`).

**Current behavior (clinical Prescribe)**

- Shared `ClinicalPrescriptionActionDialog` (+ catalog / dosing / Review billing) used from clinical, OPD, nursing, IPD, ICU.
- Medicines table, empty state (“No medicines added yet”), Add medicine → catalog, search/filters/settings, structured Rx, Review billing.
- Submit goes through clinical/pharmacy-order callers with encounter + patient; pharmacy walk-in does not use this UI today.

**Intended behavior**

- Create order keeps a **pharmacy patient shell** (Existing / New / Anonymous) with default **Anonymous**.
- Medicines UX matches clinical Prescribe (reuse the shared dialog/widgets—do not rebuild a parallel table).
- On success, continue today’s pharmacy outcomes: create order, snackbar/feedback, open order detail / refresh worklist as today.
- Anonymous stays **encounter-less** and **patient-less** (`patient_id` null). Do not invent a sentinel “anonymous patient” record.

**Definitions**

- *Pharmacy Create order*: facility walk-in / OTC order from pharmacy or home Create order; not a clinical encounter prescription.
- *Prescribe medicines flow*: `ClinicalPrescriptionActionDialog` + catalog + dosing helpers (+ Review billing when a patient exists).
- *Anonymous order*: `patient_id` omitted/null; no encounter; no auto-billing attachment.

## Requirements

1. Open Create order from pharmacy and home with patient mode defaulting to **Anonymous**. Preserve Existing and New (New only when patient registry write is allowed; unauthorized New absent).
2. Replace the walk-in inline medicine line UI with the shared Prescribe medicines flow (table, empty state, Add medicine → catalog, search/filters/settings, structured dosing, remove selected). Reuse `ClinicalPrescriptionActionDialog` (or extract a shared medicines host it already owns)—do not duplicate catalog/dosing/billing widgets.
3. Wire submit to the existing pharmacy create path (`createPharmacyOrder` / `POST /api/v1/pharmacy/orders`): map Prescribe item payloads into that create contract; omit `encounter_id`; include `patient_id` only for Existing/New.
4. Review billing: available for Existing/New when payer context exists; for Anonymous hide or omit billing submit (backend already skips billing without a patient). Do not block Anonymous create solely because billing is absent.
5. Load drug reference data for the Prescribe catalog from existing pharmacy/clinical drug catalog sources already used by workspace or clinical reference data—no second catalog stack.
6. Remove obsolete walk-in-only medicine form code once callers use the shared flow; keep patient shell, create API, and post-create UX (detail dialog / snackbar / list refresh).
7. Cover permission, loading, empty, error, success, validation, and visible feedback. Responsive; theme tokens; light/dark.
8. Tests: default Anonymous; Existing/New still create with `patient_id`; Anonymous omits `patient_id`; medicines added via catalog/Prescribe path; unauthorized New absent; billing gated for Anonymous; clinical Prescribe callers unchanged.

## Constraints

- Reuse shared clinical prescription UI and pharmacy create order service/schema. No parallel medicine editor.
- Do not require `encounter_id` for pharmacy Create order.
- Do not create or hard-code a sentinel anonymous patient id; keep nullable `patient_id`.
- Do not change clinical/OPD/nursing/IPD/ICU Prescribe entry contracts beyond shared-widget extraction if needed.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `.cursor/flows/pharmacy-flow.mdc` (if present), `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Create order opens with Anonymous selected by default. | R1 |
| A2 | Medicines UI matches Prescribe: empty state, Add medicine → catalog, table edit/remove, structured dosing. | R2, R5 |
| A3 | Anonymous create succeeds without `patient_id` / encounter; order appears on pharmacy worklist. | R3, R4 |
| A4 | Existing (and New when allowed) create includes `patient_id`; New mode absent without write access. | R1, R3, R8 |
| A5 | Review billing usable with patient; Anonymous create does not require billing. | R4 |
| A6 | Clinical Prescribe paths still work; pharmacy no longer shows the old inline Line 1 form. | R2, R6, R8 |
| A7 | Loading/validation/error/success feedback present; unauthorized chrome absent; usable on narrow + light/dark. | R7 |

## Relevant Files

- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_walk_in_order_dialog.dart`
- `frontend/lib/shared/clinical_actions/dialogs/clinical_prescription_action_dialog.dart`
- `frontend/lib/shared/clinical_actions/dialogs/clinical_prescription_catalog_dialog.dart`
- `frontend/lib/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart`
- `frontend/lib/features/home/presentation/widgets/home_dashboard_actions.dart` (`record_pharmacy_sale`)
- `backend/src/modules/pharmacy-order/schemas/pharmacy-order.schema.js`; pharmacy-workspace create route/service
- Tests: `pharmacy_walk_in_order_payload_test.dart`, `clinical_prescription_action_dialog_test.dart`, pharmacy/home create-order tests; backend pharmacy-order schema anonymous `patient_id`

## Verification

- Flutter: Anonymous default; add medicines via catalog; create without patient; Existing/New with patient; New gated; clinical Prescribe regression.
- Backend: create with null/omitted `patient_id` still valid; with `patient_id` unchanged.
- Manual: pharmacy Create order and home Create order → Prescribe-style medicines → create → order detail/worklist; light/dark and narrow viewport.
