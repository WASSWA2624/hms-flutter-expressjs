# Action inventory — `/pharmacy`

Primary surface: `PharmacyWorkspacePage` (`frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`).

Write gate: `AppPermissions.pharmacyWrite` (`_writeRequirement`). Billing record-payment also needs `billingWrite`. Unauthorized write / next-action controls do not render. Backend auth remains authoritative.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** | Reload queue | **Removed** — mutations / realtime / adaptive poll / scaffold **Try again** |
| Rotating primary (**Catalog** vs **Billing** by tab) + Catalog secondary on payment tab | Open catalog / leave for billing | **Merged** — stable **Catalog and stock** primary on every tab; billing desk stays in main nav; **Record payment** remains the in-queue payment path |
| Toolbar **Low stock** / **Almost out** / **Expiring soon** | Open catalog inventory | **Removed** — sole catalog entry is the primary; inventory filters live inside the catalog dialog |
| Advanced filters **Queue status** + **Pending payment** vs tab strip | Select queue | **Removed** from advanced filters — tabs own queue; clear filters preserves tab status / pending-payment |
| Deep link `orderId` / `encounterId` only `selectOrder` | Intermediate shell; hunt for row | **Removed** — deep link opens prescription detail dialog |
| Detail **Dispense** (and other writes) as disabled no-ops | Restate blocked capability | **Removed** — detail actions render only when authorized and eligible |
| Detail **Workflow readiness** panel | Restate dispense / stock / attest / print availability | **Removed** — actions and line items already surface readiness; progressive disclosure via timeline remains |
| Dead inline **Drug stock** panel vs catalog dialog | Browse / map stock | **Removed** — catalog dialog is the sole stock surface |
| Mobile `_MedicationLineActions` vs desktop line action | Same map-stock / price-source write | **Merged** — one `_MedicationPrimaryLineAction` |
| Mobile list without next-action trailing | Same stage write as desktop column | **Fixed** — next-action on `AppListTableMobileItem.trailing` |
| Row **Next action** vs row select → detail actions | Start primary / all item actions | **Kept** — next-action is the labeled minimal path; detail holds secondary actions + print |

---

## Pharmacy workspace screen

### Tab strip

- **Ready / Partial / Pending payment / Completed / All orders**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, applies queue filter.
  - Condition: Always when workspace loads.
  - Counts: Summary counts per section.

- **Catalog and stock** (primary)
  - Location: Tab-strip primary on every worklist tab.
  - Opens modal: Yes — catalog / formulary / inventory / storage dialog.
  - Immediate result: Browse and manage drugs, formulary, stock, storage.
  - Condition: Always shown when workspace loads (catalog writes gated inside dialog).

Tab-strip **Refresh**, rotating **Billing** primary, and inventory-alert shortcuts were removed.

- **Try again** (page load failure)
  - Location: `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Reloads pharmacy workspace.
  - Condition: Load failure.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (advanced), **Settings** (columns), pagination
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters; Table Settings.
  - Immediate result: Client/server filters / search / column visibility for the active tab.
  - Condition: Always on the worklist.

#### Advanced filters (from **Filters**)

Fields: care location; priority; partial stock; urgent; order date from/to.

- **Apply filters** / **Clear filters** / **Close**
  - Location: Panel footer / chrome.
  - Immediate result: Applies or clears advanced filters **without changing** tab-owned status / pending-payment.

### Empty / no-results

- **Empty worklist**
  - Location: `AppWorkspaceStatePanel.empty`.
  - Opens modal: No.
  - Immediate result: Empty copy; **Catalog and stock** remains available.
  - Condition: No rows after tab / search / filters.

### Row activation / next-action

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Prescription detail (`_PharmacyDetailPanel`).
  - Immediate result: Loads workflow; eligible actions, items, timeline.
  - Condition: Always when rows exist.

- **Next action** (status-aware label)
  - Location: `next_action` column (always visible); mobile `AppListTableMobileItem.trailing`.
  - Opens modal: Mutation dialog for the top allowed action (record/confirm billing, dispense, attest, return, cancel) or detail when view-only.
  - Immediate result: Completes that path without opening full detail first (except view-details).
  - Condition: Write (+ billing write for payment); unauthorized control absent.

### Detail dialog (from row select)

- **Close**
  - Location: Dialog chrome.
  - Opens modal: No.
  - Immediate result: Dismisses detail.

- **Record payment** / **Dispense** / **Attest** / **Return** / **Cancel order**
  - Location: Detail action panel (only when authorized and eligible).
  - Opens modal: Billing dialog or dispense/attest/return/cancel forms.
  - Immediate result: Mutates order; snackbar; workspace sync.
  - Condition: Capability + write / billing write; Dispense omitted when payment blocks; unauthorized / ineligible actions absent.

- **Print instructions**
  - Location: Detail action panel extra (not write-gated).
  - Opens modal: Print flow.
  - Immediate result: Prints patient medication instructions.
  - Condition: When detail is open.

- Line **Map stock** / price source actions
  - Location: Medication items table.
  - Opens modal: Mapping / price confirm as required.
  - Immediate result: Updates line stock mapping or price source.
  - Condition: Write.

### Catalog dialog

Opened from tab primary or `?section=inventory` (inventory tab preselected). Nested drug / formulary / inventory / storage panels keep their add/edit/delete/adjust flows and destructive confirms.

### Deep links

- **`?orderId=` / `?encounterId=`** — opens prescription detail for the matching row (no select-only shell).
- **`?section=` / `?search=`** — selects tab / pre-fills search; `section=inventory` opens catalog.

### Manual checks (Req 7)

- [ ] Unauthorized user: next-action write controls absent; Catalog primary remains; detail print remains.
- [ ] Every worklist tab: one **Catalog and stock** primary; no Refresh / Low stock / Billing toolbar.
- [ ] Advanced filters omit Queue status / Pending payment; clearing filters does not leave the active tab queue.
- [ ] Deep link `/pharmacy?orderId=…` opens detail without hunting the row.
- [ ] Payment-blocked order: detail shows Record payment, not a disabled Dispense.
- [ ] Detail omits Workflow readiness panel; ineligible write actions are absent.
- [ ] Loading / empty / validation / error snackbars still surface on simplified paths.

Widget tests in `frontend/test/features/pharmacy/presentation/pharmacy_workspace_page_test.dart` cover toolbar merges, deep-link detail, next-action cancel path, read-only next-action / detail write absence, advanced-filter omissions, and readiness removal.
