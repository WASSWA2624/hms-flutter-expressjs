# Action inventory — `/subscriptions`

Primary surface: `SubscriptionsWorkspacePage` (`frontend/lib/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart`).

Write gate: `AppPermissions.subscriptionsWrite` (toolbar primaries, detail quick actions, plan footer **Edit plan**, cohort account actions). Read: `subscriptionsRead` via route access.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Dead **Notifications** tab (badge only, tap no-op) | None | **Removed** — queue chips under the panel strip own queue jumps |
| Unwired summary notification menu vs Overview **Past due** card | Apply past-due queue | **Merged** — queue chips only when count &gt; 0; Overview past-due card removed |
| Overview always stacked above every panel’s worklist | Same metrics + list chrome | **Split** — Overview panel is metrics/cohorts only; other panels own the worklist |
| Advanced filters **Resource** group vs panel / nested resource tabs | Switch resource | **Removed** from advanced filters — tabs own resource navigation |
| Toolbar **Activate subscription** vs detail **Activate** | Create new vs activate existing | **Renamed** create entry to **New subscription**; detail keeps **Activate** |
| Cohort **Assign subscription** / **Modify** vs create / edit labels | Same create/edit forms | **Unified** — **New subscription** / **Edit subscription** |
| Edit subscription plan dropdown vs **Change plan** | Change plan | **Removed** plan field from edit form — **Change plan** is the sole plan-migration path |
| Create/edit plan module checkboxes + **Add modules** dialog | Update included modules | **Split** — modules on **Create plan** only; existing plans use **Manage modules** |
| Cancel **Reason** form (reason never sent to API) | Cancel subscription | **Replaced** with destructive confirm (`AppConfirmActionDialog`) |
| **Print invoice** snackbar stub | No report | **Removed** until a real report endpoint exists |
| Detail quick-actions title from patients l10n | Wrong module copy | **Fixed** — subscriptions **Quick actions** label |

---

## Subscriptions workspace screen

### Panel strip

- **Overview / Plans / Subscriptions / Invoices / Licenses**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches panel (+ default resource), updates URL `?panel=…&resource=…`.
  - Condition: Always shown.

- **New subscription** / **Create plan** / **Assign module** / **Add license** (primary by resource)
  - Location: Tab-strip primary (`AppTabToolbarPrimary`).
  - Opens modal: Matching create form.
  - Immediate result: Creates record; snackbar; workspace refresh.
  - Condition: `subscriptionsWrite` and a non-Overview panel with a creatable resource; omitted when unauthorized.

Panel-strip **Notifications** tab was removed. Queue chips (below the strip) apply pending / past-due / denied / expiring / approaching-limit queues when counts are positive.

- **Try again** (page load / inline failure)
  - Location: `AsyncStateScaffold` or `AppFailureStateView`.
  - Opens modal: No.
  - Immediate result: Retries workspace load / refresh.
  - Condition: Load or mutation failure surface.

### Nested resource tabs (non-Overview)

- **Plans / Modules** (Plans panel), **Subscriptions / Module subscriptions** (Subscriptions panel)
  - Location: Nested `AppTabStrip`.
  - Immediate result: Switches resource within the active panel.
  - Condition: Panel has more than one resource.

### Overview panel

- **Active plans / Not subscribed / Closed subscriptions** metric cards
  - Opens modal: Tenant cohort dialog (browse + optional **New subscription** / **Edit subscription** when write-authorized).
- Usage limits and recommendations: read-only progressive disclosure.

### Search / filters / table chrome (worklist panels)

- **Search**, **Clear**, **Filters** (advanced), **Settings** (columns)
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters panel; Table Settings dialog.
  - Immediate result: Filters/search/column visibility for the active resource.
  - Condition: Non-Overview panels with a worklist.

#### Advanced filters (from **Filters**)

Fields vary by resource: status, tier, billing cycle, plan, module, fit, invoice status, license type, eligibility, date preset.

- **Apply filters** / **Clear filters** / **Close**
  - Immediate result: Applies or clears advanced filters **without changing panel/resource**.

Resource selection was removed from advanced filters.

### Row activation

- **Row select** (desktop / mobile)
  - Location: Table row / mobile list item.
  - Opens modal: Subscription detail dialog.
  - Immediate result: Selects item and opens the single detail surface (actions + fields + timeline; plans get plan hero / modules / accounts).
  - Condition: When rows exist.

### Detail dialog (from row select)

Write actions appear only when `subscriptionsWrite`.

Subscriptions: **Edit subscription**, **Renew**, **Change plan**, **Activate**, **Cancel subscription** (confirm).  
Module subscriptions: **Enable/Disable module** (reason required by API).  
Licenses: **Update license**.  
Invoices: **Collect invoice**, **Retry invoice**.  
Plans: **Manage modules**; footer **Edit plan**.

### Empty / no-results / validation

- Empty worklist: `emptyTitle` / `emptyBody`.
- Form validation stays inside each mutation dialog; success/error via snackbar (`savedMessage` / failure message).
- Cancel uses confirm-only (no discarded reason field).

---

## Verification (Req 7)

- Widget tests in `frontend/test/features/subscriptions/presentation/subscriptions_workspace_page_test.dart` prove:
  - **Notifications** tab is absent; queue chips appear for positive counts.
  - **New subscription** is the sole create primary on the Subscriptions panel when write-authorized.
  - Unauthorized users see no create primaries / detail mutation controls.
  - Advanced filters omit a Resource group.
  - Cancel uses confirm (no reason shell); Print invoice is absent.
  - Overview panel has no worklist; Plans/Subscriptions panels show nested resource tabs where applicable.
