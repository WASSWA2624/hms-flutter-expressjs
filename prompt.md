# Bug: OPD queue status not syncing after lab results are verified

## Summary

Lab completion state is not reflected in the OPD flow. A patient whose lab results are **Verified** in the Laboratory worklist still appears as **Lab pending** with next step **Lab handoff** on the OPD flow table.

## Evidence

| Module | Patient | Queue / result state |
|--------|---------|----------------------|
| **OPD flow** (`/opd`) | Samuel Demo-Bravo (`PAT-9456CE18C9`) | Queue status: **Lab pending** · Next step: **Lab handoff** |
| **Laboratory** (`/lab`) | Samuel Demo-Bravo (same patient) | Result status: **Verified** |

See attached screenshots for the mismatch.

## Expected behavior

When all active lab order items for an encounter are verified/completed:

1. **OPD flow** queue status should advance from **Lab pending** to **Results ready** (or the correct downstream state).
2. **Next step** should update from **Lab handoff** to **Review results** (or equivalent).
3. Status should stay consistent across OPD, Lab, and any other modules that surface the same encounter.

## Actual behavior

OPD continues to show **Lab pending** / **Lab handoff** after lab verification, while the Laboratory worklist shows **Verified**.

## Scope

- **Frontend:** OPD flow table (`frontend/lib/features/opd/`), Lab worklist (`frontend/lib/features/lab/`)
- **Backend:** OPD display resolution and lab→OPD sync (`backend/src/modules/opd-flow/services/opd-flow.service.js`, `backend/src/modules/lab-workspace/services/lab-workspace.service.js`)

## Likely investigation areas

1. **`resolveLabState()`** — OPD treats lab work as incomplete unless orders/items are `COMPLETED` and no results are `PENDING`. Confirm whether **Verified** result status is handled correctly.
2. **`syncOpdFlowForOrder()` / `syncDiagnosticsStage()`** — Lab verification should trigger OPD stage sync (`LAB_RESULTS_VERIFIED`). Verify this runs and that the encounter stage advances out of `LAB_REQUESTED`.
3. **Realtime / cache refresh** — Confirm OPD UI refreshes after lab verification (websocket event or refetch), not only on manual reload.
4. **Encounter linkage** — Confirm the lab order and OPD encounter refer to the same encounter ID.

## Acceptance criteria

- [ ] Reproduce with Samuel Demo-Bravo (or equivalent seeded data): verify lab results, then confirm OPD updates without a full page reload.
- [ ] OPD queue status and next step match the resolved lab state for that encounter.
- [ ] Partial completion (some items verified, others pending) still shows an in-progress lab state; full verification shows results ready.
- [ ] Existing tests pass; add or extend coverage in `opd-flow.diagnostics-sync.service.test.js` and lab-workspace sync tests if a gap is found.
- [ ] No regression for encounters with concurrent radiology/pharmacy workflows.

## Test plan

1. Open OPD flow and note a patient in **Lab pending**.
2. Open Laboratory worklist for the same patient/encounter.
3. Verify all lab results (or use already-verified seed data).
4. Return to OPD flow — confirm status is **Results ready** and next step is **Review results**.
5. Repeat on mobile, tablet, and desktop widths to ensure responsive UI is unaffected.
