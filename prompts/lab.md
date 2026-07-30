# Simplify the Lab Module Workflow

## Goal

The lab module is currently too complex. Simplify the entire lab workflow (backend + frontend) to exactly this flow, and remove everything that doesn't fit it:

1. **Request arrives** — A lab request created anywhere in the app (Clinical, Nursing, OPD, ICU, etc.) immediately appears on the lab screen as pending work.
2. **Technician performs the test** — The lab technician opens the pending request and enters the results.
3. **Technician saves** — On save, the results are final. No verification, no release, no approval steps.
4. **Results are immediately visible globally** — As soon as results are saved, the ordering doctor (and anyone viewing that patient's record anywhere in the app) can see them.

## Key principle

The lab technician is authorized to enter results. Saving results **is** the final step. There is no separate "verify", "release", "approve", or "review" stage performed by anyone.

## What to remove

Remove all intermediate result-workflow steps across the whole app, including (but not limited to):

- The verify-results flow: `verify-results` endpoint, `verifyLabOrderResults` controller/service/schema, `VERIFY_RESULT` / `VERIFY_RESULTS` actions, and the `LAB_RESULTS_VERIFIED` trigger.
- Any separate "release results" step distinct from saving results.
- "Pending verification" tabs, filters, statuses, and screens in the lab workspace (e.g. the pending-verification views and their billing inventories).
- Frontend capability flags like `can_verify_result` / `can_verify_all` and the buttons/dialogs that use them.
- Any other status, permission, notification, audit action, or UI element that only exists to support the removed verification/release steps.

Update tests to match the simplified flow, and remove tests that only cover the deleted steps.

## What to keep

- Lab request creation from other modules and its visibility on the lab screen (pending queue).
- Sample handling if it's part of performing the test — but keep it lightweight; it must not block the enter-results → save → visible flow.
- Critical-result notifications to the ordering doctor should fire when results are **saved** (not on a verify/release event).
- Billing checks that gate performing the test can stay, but they should gate at most one point in the flow, not multiple steps.
- Audit logging of who entered/saved the results.

## Acceptance criteria

- A lab request made from OPD appears in the lab pending list without any extra action.
- A lab technician can open it, enter results, and save in one continuous flow.
- Immediately after saving, the results are visible in the patient's record from the doctor's side with no further action by anyone.
- No verify/release/approve buttons, statuses, endpoints, or screens remain anywhere in the app.
