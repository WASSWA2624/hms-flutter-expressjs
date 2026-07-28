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
| Detail QuickActions showing Submit + Record + Sync + Close always | Same mutations as next-action, status-agnostic | **Removed** parallel always-on shortcuts — detail kept status-primary + Sync |
| Detail status-primary (**Update status** / **Submit** / **Record** / **Close**) matching row **Next action** | Same stage write | **Removed** from detail — next-action is the sole primary; detail keeps **Sync** only (claims) |
| Next-action **detail fetch** before mutation dialogs | Intermediate shell | **Removed** — `focusItem` selects locally; form opens immediately; `selectItem` remains for detail |
| Mobile list without next-action trailing (detail omitted matching write) | Primary write unreachable on phone | **Fixed** — same next-action control as desktop column, trailing on mobile rows (icon-only + tooltip under 600px) |
| Close-as-paid dialog **Payer response** status select (default PAID) | Restate next-action choice | **Removed** — close locks status to `PAID`; notes only. Record response still selects status |

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
  - Condition: `claimsWorkspaceWriteRequirement`; omitted when unauthorized.

- **Prepare claim** (primary, Active Claims)
  - Location: Tab-strip primary (`claimsPrepareClaimAction`).
  - Opens modal: Yes — coverage + invoice prepare dialog.
  - Immediate result: Creates claim draft; snackbar; queue refresh.
  - Condition: `claimsWorkspaceWriteRequirement`; omitted when unauthorized.

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
  - Immediate result: Loads detail; shows Sync when permitted (active claims only).
  - Condition: Always when rows exist.

- **Next action** (Authorizations / Active Claims)
  - Location: Next-action column (desktop) / mobile row trailing.
  - Opens modal: Status-appropriate mutation dialog (update auth / submit / record response / close as paid).
  - Immediate result: `focusItem` then mutation dialog; snackbar on success.
  - Condition: Write (or financial-approve for Close as paid); absent when no next step (Settled / paid / cancelled); unauthorized controls omitted.

### Detail dialog

- **Sync status** (active claims only)
  - Location: Detail `AppQuickActions` (`permissionActions`).
  - Opens modal: No — mutates immediately.
  - Immediate result: Syncs claim status with insurer; snackbar; queue refresh.
  - Condition: Write; omitted for authorizations and paid/cancelled claims; unauthorized actions absent.

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

### Nested mutation dialogs

- **Request authorization** — company (optional filter) + coverage scheme (required).
- **Prepare claim** — company (optional filter) + scheme + invoice (required).
- **Update authorization** — status (required) + approved amount when APPROVED/PARTIAL.
- **Submit / resubmit claim** — optional notes.
- **Record payer response** — payer response status (required) + optional notes.
- **Close as paid** — optional notes only; status locked to `PAID`.

---

## Manual checks (Req 7)

- [x] Refresh absent; no Claims to submit / Ready to settle / Eligibility pending chips; advanced Filters absent on Authorizations / Active Claims; Insurance Setup creates absent from tab strip.
- [x] Detail has Sync only for active claims; no Update status / Submit / Record / Close as paid when next-action owns that write; authorization detail has Print only (no Sync / Update status).
- [x] Row next-action is the sole status-primary write on desktop and mobile; Sync remains detail-only; setup creates only on Insurance Setup panel.
- [x] Next-action opens the mutation dialog without a prior detail fetch; deep-link / row select still load full detail via `selectItem`.
- [x] Close as paid does not show Payer response status select; Record response still does.
- [x] Without write capability, Request authorization / next-action / Insurance Setup creates are absent.
- [x] Mobile list exposes next-action trailing; tap opens mutation without detail first.
- [ ] After mutations, snackbar + refreshed queue; loading / empty / error-retry / validation still render on simplified surfaces.
