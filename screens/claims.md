# Action inventory — `/claims`

Primary surface: `ClaimsWorkspacePage` (`frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart`).

Write gate: `claimsWorkspaceWriteRequirement` (request auth, prepare/submit/record/sync claim, insurance catalog creates). Close/settle gate: `claimsFinancialApproveRequirement`.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** (primary on Settled, secondary elsewhere) | Reload queue | **Removed** — queue refreshes after mutations / realtime / scaffold retry |
| Summary chips **Claims to submit** / **Ready to settle** | Same filters as Submitted / Approved | **Removed** — keep Submitted / Approved chips only |
| Summary chip **Eligibility pending** | Filtered to `all` (no distinct status) | **Removed** |
| Advanced **Filters** status group on Authorizations / Active Claims | Same status filter as summary chips | **Removed** on those tabs — summary chips are the sole status filter; Settled keeps Filters |
| Insurance Setup toolbar create actions + description-only panel | Create company / scheme / offer / enrollment / price / API | **Merged** — labeled actions live only on the setup panel; strip toolbar empty for this tab |
| Detail QuickActions showing Submit + Record + Sync + Close always | Same mutations as next-action, status-agnostic | **Merged** — detail shows one status-primary action (+ Sync); next-action remains the row primary |

---

## Claims workspace screen

### Tab strip

- **Authorizations / Active Claims / Settled / Insurance Setup**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, applies default section filter.
  - Condition: Always when workspace loads.

- **Request authorization** (primary, Authorizations)
  - Location: Tab-strip primary (`claimsRequestAuthorizationAction`).
  - Opens modal: Yes — coverage-plan request dialog.
  - Immediate result: Creates pre-authorization; snackbar; queue refresh.
  - Condition: `claimsWorkspaceWriteRequirement`.

- **Prepare claim** (primary, Active Claims)
  - Location: Tab-strip primary (`claimsPrepareClaimAction`).
  - Opens modal: Yes — coverage + invoice prepare dialog.
  - Immediate result: Creates claim draft; snackbar; queue refresh.
  - Condition: `claimsWorkspaceWriteRequirement`.

Settled and Insurance Setup have no tab-strip toolbar actions.

- **Try again** (page load failure)
  - Location: `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Retries workspace load.
  - Condition: Load failure.

### Summary status chips (Authorizations / Active Claims only)

- **Auth pending / Auth approved / Denied / Expired** (Authorizations)
- **Submitted / Approved / Partial / Rejected** (Active Claims)
  - Location: Summary chip row under tab strip.
  - Opens modal: No.
  - Immediate result: Applies matching `ClaimsQueueFilter`.
  - Condition: Chip renders only when count &gt; 0.

### Search / filters / table chrome

- **Search**, **Clear**, **Settings** (columns)
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Table Settings dialog.
  - Immediate result: Search / column visibility for the active section.
  - Condition: Queue sections only (not Insurance Setup).

- **Filters** (advanced) — Settled only
  - Location: Search chrome.
  - Opens modal: Advanced filters panel (Paid / Cancelled).
  - Immediate result: Applies settled status filter.
  - Condition: Settled section.

### Row activation

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Claims detail dialog (billing impact, documents, timeline, print).
  - Immediate result: Loads detail; shows status-primary mutation + Sync when permitted.
  - Condition: Always when rows exist.

- **Next action** (Authorizations / Active Claims)
  - Location: Next-action column.
  - Opens modal: Status-appropriate mutation dialog (update auth / submit / record response / close).
  - Immediate result: Same mutation dialogs as detail primary; snackbar on success.
  - Condition: Write (or financial-approve for Close); absent when no next step (Settled / paid / cancelled).

### Detail dialog

- **Update status** (authorization) / status-primary claim action / **Sync status**
  - Location: Detail `AppQuickActions` (`permissionActions`).
  - Opens modal: Matching mutation dialog (Sync is immediate).
  - Immediate result: Mutates selected record; snackbar; queue refresh.
  - Condition: Write or financial-approve; unauthorized actions absent.

- **Print statement**
  - Location: Detail dialog actions.
  - Opens modal: Print flow.
  - Immediate result: Prints authorization or claim statement.
  - Condition: Always when detail is open.

### Insurance Setup panel

- **Add company / Add scheme / Add offer / Enroll patient / Add price / Insurer API**
  - Location: Setup panel `AppQuickActions` (sole entry points).
  - Opens modal: Matching catalog create dialog.
  - Immediate result: Creates catalog row; snackbar; reference refresh.
  - Condition: `claimsWorkspaceWriteRequirement`; unauthorized actions absent.
