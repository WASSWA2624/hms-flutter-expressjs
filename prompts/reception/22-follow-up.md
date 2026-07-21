# Add Reception Follow-up Worklist and Callback Outcomes

Add a Reception call worklist; support schedule, complete, and reschedule. Follow `prompts/.cursor/prompt.mdc`.

## Context

Flow Actions **Follow up** and `POST /follow-ups` exist, but Reception lacks a call worklist. Follow-ups are optional at disposition or any applicable stage.

**Follow-up:** encounter-linked `SCHEDULED` callback (`scheduled_at`, optional notes).
**Complete:** mark successful (`COMPLETED`).
**Reschedule:** create another `SCHEDULED` follow-up when the callback continues.

## Requirements

1. Add Reception **Follow-ups** tab of authorized `SCHEDULED` rows: patient id, contact, date, time; sort by `scheduled_at` ascending.
2. Keep authorized **Follow up** on Flow Actions for non-terminal visits; after disposition/discharge success, open dialog when authorized (skippable).
3. On save, reuse patient contact; if missing, require capture before persist.
4. Row open shows call details with **Mark completed** and **Schedule another**; sync after mutations.
5. Preserve loading, empty, error, busy, success, validation, permission states; omit unauthorized UI.
6. Reuse list/dialog on OPD, Emergency, Inpatient, ICU when already exposed; omit Billing and Lab.

## Constraints

- Reuse follow-up API, `ClinicalFollowUpActionDialog`, auth, localization, design-system; extend contracts only for list contact.
- Do not invent clinical stages or force follow-up on every encounter.
- Support themes and viewports.

## Acceptance Criteria

- R1: Sorted scheduled rows show id, contact, date, time.
- R2: Manual schedule remains; post-disposition opens skippable dialog when authorized.
- R3: Missing contact required on save.
- R4: Complete and reschedule refresh the worklist.
- R5–R6: States clear; unauthorized UI absent; clinical reuse excludes Billing/Lab.
- Update follow-up, reception, disposition tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/opd_actions/`
- `frontend/lib/features/reception/`
- `backend/src/modules/follow-up/`
- `frontend/test/features/reception/`
