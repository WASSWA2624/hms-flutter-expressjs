# Claims inventory — convention gaps

Residual findings vs `prompts/.cursor/*.mdc` after shared-chrome / convention-gap remediation.

## Gaps

- none

## Justified product exceptions (tested)

- Date filter remains disabled on Claims queue tabs: `ClaimsQueueQuery` and the claims-workspace work-items API do not accept a date range (`enableDateFilter: false`; covered in `claims_workspace_page_test.dart`).
- Insurance Setup omits tab count chrome (`count: null`) — catalog hub, not a countable worklist.
