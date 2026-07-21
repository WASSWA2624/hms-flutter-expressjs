# Gate Correct Stage by Recorded Milestones

Limit **Correct stage** targets so staff cannot reverse past recorded work. Same dialog everywhere the action appears. Follow `prompts/.cursor/prompt.mdc`.

## Context

**Correct stage** opens `CorrectStageDialog` (current stage, target select, reason, Cancel / Correct stage). Today every stage except current is selectable, so a paid visit can still target Payment due.

**Recorded milestone:** durable completed work (payment, vitals, doctor assignment, clinical review/orders, disposition/admission)—not the stage pointer alone.

**Eligible target:** a workflow stage that does not undo a recorded milestone. Edit recorded data via existing edit flows.

## Requirements

1. Open shared `CorrectStageDialog` from every Correct stage entry (Reception, OPD/clinic, other Flow Actions hosts).
2. List only eligible targets from existing workflow stages; omit ineligible options.
3. Backend rejects ineligible `stage_to` even if submitted directly.
4. Require reason per existing rules; block submit when target equals current or is ineligible.
5. Preserve loading, validation, busy, success, error, permission states; sync after save; omit unauthorized UI.

## Constraints

- Reuse CorrectStageDialog, Flow Actions, `correctStage` API, labels, auth, localization, design-system; no parallel dialogs.
- Do not invent stages, delete milestones, or replace edit/payment/vitals flows.
- Support themes and viewports.

## Acceptance Criteria

- R1: Same dialog everywhere Correct stage exists.
- R2–R3: Eligible targets only; backend rejects ineligible corrections.
- R4: Invalid target/reason submits blocked.
- R5: States/sync intact; unauthorized UI absent.
- Update correct-stage and opd-flow service tests; run Flutter analysis and backend opd-flow tests.

## Relevant Files

- `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`
- `frontend/test/shared/opd_actions/opd_correct_stage_dialog_test.dart`
- `backend/src/modules/opd-flow/services/opd-flow.service.js`
- `backend/src/tests/modules/opd-flow/services/opd-flow.service.test.js`
