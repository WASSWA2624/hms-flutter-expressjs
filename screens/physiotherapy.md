# Action inventory — `/physiotherapy`

Primary surface: `PhysiotherapyWorkspacePage` (`frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart`).

Write gate: `_therapyWriteRequirement` (`clinicalWrite` | `patientWrite`). Print instructions uses `_therapyReadRequirement` (`clinicalRead` | `patientRead` | `billingRead`). Unauthorized write controls do not render.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** | Reload worklist | **Removed** — list syncs after mutations / realtime / adaptive poll / scaffold **Try again** |
| Tab-strip primary (Schedule session / Record session / Mark attendance / …) depends on prior selection | Same stage write as row | **Removed** — row **Next action** is the labeled minimal path |
| Detail Quick Action matching row next-action (accept / assessment / schedule / session / attendance / follow-up / print) | Same write | **Omitted** from detail via `omitNextActionKind` — next-action is the sole primary for that goal |
| Detail actions shown disabled when ineligible (schedule without patient id / attendance without appointment) | No-op chrome | **Removed** — ineligible writes omitted |
| Advanced filter **Queue / scope** mirroring tab strip | Same scope switch as tabs | **Removed** — tabs own `PhysiotherapyQueueScope`; filters keep source / status / attendance / therapist / dates |
| Mobile list without next-action trailing | Same stage write as desktop column | **Fixed** — compact `TherapyNextActionButton` on `AppListTableMobileItem.trailing` |

---

## Physiotherapy workspace screen

### Tab strip

- **Referrals / Today / Active plans / Follow-up due / Missed / Completed**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, reloads worklist.
  - Condition: Always when workspace loads.
  - Counts: From workspace state; Missed danger; Referrals / Active plans / Follow-up due warning; Today / Completed info.

- **Follow-ups** (shared worklist tab)
  - Location: Tab strip.
  - Opens modal: No.
  - Immediate result: Shows `FollowUpWorklistPanel`; URL `?section=follow-ups`.
  - Condition: Always when workspace loads.

Tab-strip primary write and **Refresh** were removed.

- **Try again** (page load failure)
  - Location: `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Reloads physiotherapy workspace.
  - Condition: Load failure.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (advanced), **Settings** (columns)
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters; Table Settings dialog.
  - Immediate result: Search / filters / column visibility for the active section.
  - Condition: Always when worklist loads. Advanced filters omit queue scope (tabs own scope).

### Empty / no-results

- **Empty worklist**
  - Location: `AppWorkspaceStatePanel.empty`.
  - Opens modal: No.
  - Immediate result: Empty copy.
  - Condition: No rows after tab / search / filters.

### Row activation / next-action

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Therapy detail dialog (context, complementary writes, records).
  - Immediate result: Loads detail; omits the stage next-action from Quick Actions.
  - Condition: Always when rows exist.

- **Next action** (stage label)
  - Location: `next_action` column; mobile `AppListTableMobileItem.trailing`.
  - Opens modal: Matching mutation dialog (accept referral / assessment / schedule session / record session / follow-up / attendance / print).
  - Immediate result: Selects work item then opens mutation dialog directly (no empty detail shell). Persists via controller; snackbar; worklist refresh.
  - Condition: Write gate (print uses read); unauthorized next-action absent. Ineligible schedule / attendance next-actions omitted (not disabled chrome).

### Detail dialog

- **Close**
  - Location: Dialog actions.
  - Opens modal: No (closes detail).
  - Immediate result: Dismisses detail.

- **Complementary writes** (update plan, progress note, close episode, and stage actions when not the row next-action)
  - Location: Detail `AppQuickActions` (`permissionActions`).
  - Opens modal: Matching action dialog.
  - Immediate result: Mutates selected therapy item; snackbar; refresh where needed.
  - Condition: Write / read gate; action omitted when it equals `omitNextActionKind`; schedule only with patient id; attendance only with appointment; unauthorized / ineligible writes absent.

- **Overview / session / plan / notes / follow-up / backend-gap panels**
  - Location: Detail body.
  - Opens modal: No.
  - Immediate result: Progressive disclosure of therapy history and unavailable workflows.
  - Condition: Always when detail is open.

### Deep links

- **`?section=`** — selects tab (`referrals` / `today` / `active-plans` / `follow-up` / `missed` / `completed` / `follow-ups`).
- **`?search=` / `?encounterId=` / `?sessionId=`** — pre-fills search.

### Manual checks (Req 7)

- [x] Unauthorized user: next-action writes and detail write actions absent; print still available with read. *(widget)*
- [x] Referral row: only **Accept referral** next-action; detail has no Accept referral duplicate. *(widget)*
- [x] Today row: only **Record session** next-action; detail omits Record session. *(widget)*
- [x] No Refresh or primary write control on the tab strip. *(widget)*
- [x] Advanced filters omit queue scope group. *(widget)*
- [x] Mobile list shows next-action trailing. *(widget)*
- [x] Next-action opens mutation dialog without an empty detail first. *(widget)*
- [ ] Loading / empty / validation / error snackbars still surface on simplified paths. *(manual — dialog validation / snackbars reuse shared helpers)*
