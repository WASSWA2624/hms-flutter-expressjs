# Lab: Walk-In Orders, Lab Encounters, and Patient Create

Enable Lab to create orders for existing and new patients from the create-lab-request flow, auto-generating a Lab encounter when none is selected, and allowing authorized patient registration nested in that flow.

## Context

**Current behavior**

- Create Lab Order (`LabOrderContextDialog`) searches existing patients and requires selecting an encounter; backend `POST /lab-orders` rejects missing `encounter_id`.
- `EncounterType` has no `LAB`; lab-flow forbids Lab creating encounters.
- Default `LAB_TECH` has `patient:read` / `patients:read` but not `patient:write`, so techs cannot register patients from Lab.

**Intended behavior**

- Authorized users create lab orders for **existing** or **new** patients from `/lab` create-request.
- When no encounter is selected (or the patient has none), the system **creates or reuses an open Lab encounter** (`encounter_type` `LAB`) and links the order.
- When entitled with `patient:write`, users register a patient **inside** the create-lab-request flow (reuse `RegisterNewPatientForm` / dialog), then continue to tests/panels and order create.
- Clinical encounter-linked orders remain; walk-in Lab orders must still be encounter-tied (Lab encounter, not encounter-less like pharmacy).

**Definitions**

- *Lab encounter*: `encounter` with `encounter_type` `LAB`, facility/tenant scoped, status `OPEN` until closed elsewhere.
- *Walk-in lab order*: order for a registered patient whose encounter is Lab-generated (or an existing clinical encounter if the user selects one).
- *Create-lab-request flow*: Create Lab Order context → catalog/billing dialog → `POST /lab-orders`.

## Requirements

1. Add `LAB` to `EncounterType` (schema + migration) and allow it in encounter create/update/list validation.
2. Make `encounter_id` optional on lab-order create. When omitted/null, resolve an open Lab encounter for the patient (facility-scoped) or create one; attach that id to the order. Keep clinical create-with-explicit-encounter unchanged.
3. Lab create UI: encounter optional; if omitted, show clear copy that a Lab encounter will be created. Keep existing-encounter pick when available.
4. Add Existing / New patient mode on create (New only when `patient:write`). New mode reuses shared registration; on success select the patient and continue. Unauthorized New mode absent.
5. Grant default `LAB_TECH` (and frontend role pack) `patient:write` for embedded create. Keep registry `/patients` for lab-focused shell as today unless otherwise entitled.
6. Update `lab-flow.mdc`: Lab may create Lab encounters and patients via create-order; must not advance OPD/IPD stages or invent non-Lab clinical encounters.
7. Cover permission, loading, empty, error, success, validation, and feedback on the create path. Responsive; theme tokens; light/dark.
8. Tests: schema optional encounter; service auto-creates/reuses Lab encounter; permissions; dialog new/existing + optional encounter; unauthorized New mode absent.

## Constraints

- Reuse lab-order create, `LabOrderContextDialog`, patient registration components, encounter service/repository—no parallel order or patient stacks.
- Do not omit encounter (pharmacy-style); every lab order stays encounter-linked.
- Do not auto-create OPD/IPD/EMERGENCY encounters from Lab.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `.cursor/flows/lab-flow.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | `lab:write` creates order for existing patient with selected clinical encounter. | R2–R3 |
| A2 | Existing patient, no encounter selected → open Lab encounter created/reused; order linked. | R1–R3 |
| A3 | `patient:write` registers new patient in create flow, then creates order (+ Lab encounter). | R4–R5 |
| A4 | Without `patient:write`, New patient mode absent; create still works for existing patients. | R4 |
| A5 | OPD/IPD stages unchanged by Lab walk-in create; clinical order path unchanged. | R2, R6 |
| A6 | Loading/validation/error/success feedback present; unauthorized chrome absent. | R7–R8 |

## Relevant Files

- `backend/prisma/schema.prisma`; encounter + lab-order schemas/services
- `backend/src/config/permissions.js` (`LAB_TECH`); `frontend/lib/core/permissions/access_policy.dart`
- `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart`; lab workspace create path
- `frontend/lib/shared/patient_actions/register_new_patient_dialog.dart`
- `.cursor/flows/lab-flow.mdc`, `.cursor/access/default_user_roles.mdc`
- Tests: lab-order schema/service; lab access/dialog; access_policy LAB_TECH

## Verification

- Backend: create without `encounter_id` yields Lab encounter; with explicit encounter reuses it; LAB_TECH has `patient:write`.
- Flutter: New patient mode gated; existing + empty encounter succeeds; narrow/light/dark.
- Manual `LAB_TECH`: register patient → create order; existing patient without encounter → Lab encounter + order on worklist.
