# Action inventory — `/pharmacy`

Primary surface: `PharmacyWorkspacePage` (`frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`).

Write gate: `AccessRequirement` with `AppPermissions.pharmacyWrite`. Billing payment actions also need `billingWrite`. Catalog browse / print / detail browse remain without write. Unauthorized write controls do not render.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** / stock shortcut actions (**Low stock** / **Almost out** / **Expiring soon**) | Reload queue / open catalog filters | **Removed** — queue syncs after mutations / realtime / scaffold **Try again**; catalog is the sole stock entry |
| Rotating tab primary (**Billing** on pending-payment) | Same catalog / payment goals | **Merged** — stable **Catalog and stock** primary on every tab; payment is row **Next action** / detail |
| Advanced filters **Queue status** + **Pending payment** vs tab strip | Same queue scope | **Removed** from advanced filters — tabs own queue status / pending payment |
| Inline **Drug stock** panel (dead) vs **Catalog and stock** dialog | Browse / map stock | **Removed** dead panel — catalog dialog is the sole stock surface |
| Detail **Workflow readiness** checklist | Restates dispense / stock / attest / print availability | **Removed** — eligible actions and patient context fields carry the state |
| Detail actions shown disabled when ineligible (attest / return / cancel / dispense / pay) | No-op chrome | **Removed** — only eligible, authorized writes render; print always available |
| Mobile `_MedicationLineActions` vs desktop `_MedicationPrimaryLineAction` | Same map-stock / price-source write | **Merged** — one primary line action widget |
| Row **Next action** vs detail eligible writes | Start primary / secondary + print | **Kept** — next-action is the labeled minimal path (no empty detail shell); detail holds remaining eligible writes + print |

---

## Pharmacy workspace screen

### Tab strip

- **Ready / Partial / Pending payment / Completed / All orders**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, applies queue filter.
  - Condition: Always when workspace loads.
  - Counts: From workbench summary; Ready / Partial / Pending payment use warning tone.

- **Catalog and stock** (primary)
  - Location: Tab-strip primary on every tab.
  - Opens modal: Yes — `openPharmacyCatalogDialog` (drugs / formulary / inventory / storage).
  - Immediate result: Manage catalog, stock, formulary, storage layout.
  - Condition: Always when workspace loads (browse); mutations inside catalog respect write gate.

Tab-strip **Refresh** and stock shortcut secondaries were removed.

- **Try again** (page load failure)
  - Location: `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Retries workspace load.
  - Condition: Load failure.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (advanced), **Settings** (columns), pagination
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters; Table Settings.
  - Immediate result: Search / filters / column visibility for the active section (`pharmacy_{section}`).
  - Condition: Always on the worklist.

#### Advanced filters (from **Filters**)

Fields: location, priority, partial stock, urgent, order date from/to.

- **Apply filters** / **Clear filters** / **Close**
  - Location: Panel footer / chrome.
  - Immediate result: Applies or clears advanced filters **without changing the active queue tab**.

### Empty / no-results

- **Empty worklist**
  - Location: `AppWorkspaceStatePanel.empty`.
  - Opens modal: No.
  - Immediate result: Empty copy; catalog primary remains.
  - Condition: No rows after tab / search / filters.

### Row activation / next-action

- **Row select** (desktop / mobile)
  - Location: Table row / mobile list item.
  - Opens modal: Prescription detail dialog.
  - Immediate result: Loads workflow; shows patient context, eligible actions, medications, timeline, print.
  - Condition: When rows exist.

- **Next action** (labeled primary row control)
  - Location: Next-action column; mobile list.
  - Opens modal: Record payment / attest / dispense / return / cancel dialog directly (or detail when only view).
  - Immediate result: Completes that mutation path without an empty detail shell first.
  - Condition: Write (and billing write for payment); unauthorized next-action absent. View remains when write denied.

### Detail dialog (from row select / deep link `orderId`)

- Eligible writes only: **Record payment**, **Dispense**, **Attest**, **Return**, **Cancel order**
  - Location: Detail quick actions.
  - Opens modal: Matching mutation dialog (required inputs / confirmations).
  - Immediate result: Mutates via controller; snackbar; worklist refresh.
  - Condition: Capability + write / billing gates; omitted when ineligible or unauthorized.

- **Print instructions**
  - Location: Detail extra action (not write-gated).
  - Opens modal: Print flow.
  - Immediate result: Prints medication instructions.
  - Condition: Always when detail is open.

- Line **Map stock** / **Use pharmacy/facility price**
  - Location: Medication line action column (desktop + mobile).
  - Opens modal: Catalog (map stock) or applies price source mutation.
  - Condition: Write; unauthorized control absent.

### Catalog dialog (from tab primary / inventory deep link / map stock)

- Drugs / Formulary / Inventory / Storage tabs with add/edit/delete and stock filters.
- Condition: Mutations require write; browse available when catalog opens.

### Deep links

- `?section=` — selects tab (aliases supported).
- `?section=inventory` / `stock` — opens catalog dialog on inventory tab.
- `?orderId=` / encounter deep link — opens prescription detail for that order.

---

## Verification (Req 7)

- Widget tests in `frontend/test/features/pharmacy/presentation/pharmacy_workspace_page_test.dart` prove:
  - **Refresh** / stock shortcuts / rotating **Billing** primary are absent; **Catalog and stock** is the sole strip primary.
  - Advanced filters omit Queue status and Pending payment.
  - Row next-action opens cancel (representative write) without the detail shell.
  - Detail omits workflow readiness chrome; shows only eligible writes + print.
  - Read-only users keep catalog; write next-action absent; print still reachable from detail.
  - Inventory deep link opens catalog; `orderId` opens detail.
