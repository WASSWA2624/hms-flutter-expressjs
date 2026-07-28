# Action inventory — `/subscriptions`

Primary surface: `SubscriptionsWorkspacePage` (`frontend/lib/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart`).

Write gate: `AppPermissions.subscriptionsWrite` (creates / edits / renew / change plan / cancel / collect / retry). Read: `subscriptions:read` via route access (super-admin gated at router).

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Fake **Notifications** tab (count only; tap no-op) + unused summary payload | Jump to attention queues | **Removed** tab — actionable **queue chips** under the strip (claims pattern) |
| Overview **Past due** metric vs Past due invoices chip | Apply past-due queue | **Removed** metric — chip is the sole entry |
| Overview metrics + worklist on every panel | Same subscriptions list as Operations | **Scoped** — cohort / usage / recommendations only on **Overview**; worklists on other panels |
| Overview + Operations both defaulting to subscriptions worklist | Browse / create subscriptions | **Overview** monitors only; **Operations** owns the worklist + **New subscription** |
| Advanced filters **Resource** group vs panel / nested resource tabs | Switch resource | **Removed** from filters — panels + nested **Plans / Modules** and **Subscriptions / Module subscriptions** tabs own navigation |
| Dead **Active subscriptions** notification (`onSelected` empty) | None | **Removed** |
| Plan detail **Add modules** + **Edit plan** module checkboxes | Edit included modules | **Merged** — **Manage modules** on detail (write-only); create form still collects modules; edit plan form omits module list |
| **Edit subscription** plan field + **Change plan** | Change plan | **Merged** — edit keeps status / dates; **Change plan** is the sole plan-change path |
| Invoice **Print invoice** snackbar-only shell | No backend report | **Removed** — client-only shell never called the API |
| Cancel dialog **Reason** field (discarded before API cancel) | Restate cancel intent | **Removed** — confirm-only destructive dialog; payload unchanged |
| Toolbar **Activate subscription** label vs create goal | Create subscription | **Renamed** sole create entry to **New subscription** (detail **Activate** remains for pending rows) |
| Unauthorized **Manage modules** / create toolbar | Mutations | **Unauthorized UI absent** — omitted without `subscriptionsWrite` |
| Edit status **Cancelled** + **Cancel subscription** | Terminate subscription | **Merged** — Cancel confirm is sole cancel path; edit omits Cancelled (cancelled rows show date-only hint; use **Activate** to restore) |
| Always-visible disabled **Activate** / **Cancel** / **Collect** | Same mutations when inapplicable | **Removed** — actions render only when capability flags allow |
| Detail info tiles shared across resources (empty module / fit / dates) | Repeat N/A fields | **Scoped** — each resource shows only relevant tiles |

---

## Subscriptions workspace screen

### Tab strip

- **Overview / Plans / Subscriptions / Invoices / Licenses**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches panel (+ default resource), updates URL `?panel=…`.
  - Condition: Always when workspace loads.

- **Create plan** (primary, Plans resource)
  - Location: Tab-strip primary.
  - Opens modal: Yes — plan create form (includes modules).
  - Immediate result: Creates plan; snackbar; refresh.
  - Condition: `subscriptionsWrite`; omitted on Overview and when unauthorized.

- **New subscription** (primary, Subscriptions resource)
  - Location: Tab-strip primary on Operations.
  - Opens modal: Yes — create / assign form.
  - Immediate result: Creates subscription; snackbar; refresh.
  - Condition: `subscriptionsWrite` and tenants available.

- **Assign module** / **Add license** (primary on Module subscriptions / Licenses)
  - Location: Tab-strip primary.
  - Opens modal: Yes — assign / license form.
  - Condition: `subscriptionsWrite`; lookups non-empty.

### Queue chips (attention)

- **Pending changes / Past due invoices / Denied modules / Expiring licenses / Approaching limits**
  - Location: Chip row under tab strip (`FilterChip`).
  - Opens modal: No.
  - Immediate result: `applyQueue` → switches panel / resource / queue; URL updated.
  - Condition: Chip renders only when count &gt; 0 and matching queue summary exists.

### Nested resource tabs

- **Plans / Modules** (Catalog)
- **Subscriptions / Module subscriptions** (Operations)
  - Location: Nested `AppTabStrip` above the worklist.
  - Immediate result: `applyResource`; updates URL `?resource=…`.
  - Condition: Multi-resource panels only.

### Overview panel (Overview tab only)

- **Active plans / Not subscribed / Closed subscriptions**
  - Location: Cohort metric cards.
  - Opens modal: Yes — tenant cohort dialog (assign / modify when write-authorized).
  - Immediate result: Lists cohort tenants; optional mutation dialogs.
  - Condition: Overview panel only.

- **Usage limits** / **Recommendations**
  - Location: Progressive disclosure under cohort cards.
  - Condition: When overview payload includes them.

### Search / filters / table chrome (non-Overview panels)

- **Search**, **Clear**, **Filters** (advanced), **Settings** (columns)
  - Location: `AppListTable` chrome.
  - Opens modal: Advanced filters (no Resource group); Table Settings.
  - Immediate result: Filters / search / columns for the active resource.
  - Condition: Worklist panels only.

### Row activation

- **Row select**
  - Location: Table row / mobile list item.
  - Opens modal: Detail dialog (`_SubscriptionDetailPanel` / plan detail).
  - Immediate result: Selects item; plan detail loads plan stats / accounts.
  - Condition: When rows exist.

### Detail dialog actions (write-authorized)

- Subscriptions: **Edit subscription** (status / dates; no Cancelled), **Renew**, **Change plan**, **Activate** (only when `canActivateSubscription`), **Cancel subscription** (confirm-only; only when `canCancelSubscription`).
- Module subscriptions: **Enable / Disable module** (only when `canToggleModule`).
- Licenses: **Update license**.
- Invoices: **Collect invoice** (only when `canCollectInvoice`), **Retry invoice** (no print shell).
- Plans: footer **Edit plan** (metadata); section **Manage modules**.

### Empty / error / validation

- Empty worklist: `emptyTitle` / `emptyBody`.
- Load / mutation failure: scaffold **Try again** / inline `AppFailureStateView` retry.
- Form validation stays inside each mutation dialog; success / error via snackbar.

---

## Verification (Req 7)

- Widget tests in `frontend/test/features/subscriptions/presentation/subscriptions_workspace_page_test.dart` prove:
  - **Notifications** tab is absent; queue chips are the sole attention entry.
  - Overview shows cohort metrics without worklist / past-due card / create primary.
  - Catalog nested **Plans / Modules** tabs exist; advanced filters omit **Resource**.
  - Operations owns **New subscription**; nested module-subscriptions tab present.
  - Read-only users see no create / edit / manage-modules controls.
  - Invoice detail omits **Print invoice**.
  - Edit subscription form omits **Plan** and **Cancelled**; **Change plan** / **Cancel** remain on detail.
  - Active detail omits **Activate**; pending shows **Activate**; cancelled omits **Cancel** and edit shows cancelled hint.
  - Cancel uses confirm-only dialog without a discarded reason field.
