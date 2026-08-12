# Pharmacy inventory — convention gaps

Cross-cutting checklist vs `prompts/.cursor/*.mdc` after full Pharmacy remediation (2026-08-12).  
**Open required gaps: none.**

## Closed inventory residuals (prompt `99-convention-gaps`)

| Former gap | Resolution |
| --- | --- |
| Order desk tables lacked Export / table Print | Mounted on `_PharmacyQueuePanel` with `enableExport`/`enablePrint`, gated by ∩ `evidence:export`, preview-first via `printPharmacyListTable` |
| Filters used `pharmacyQueueFilterLabel` | Normalized to `commonFiltersActionLabel` (incl. nested dispense-line table) |
| Stock-alert desks reused Catalog → Inventory | **Justified product exception** — `applyDeskStockFilter` + Inventory chrome; filtered active badges via `stocks.totalItemCount` (`09`–`12`) |
| Formulary/selection pickers `enableExport: false` | **Justified product exception** — picker chrome, not printable desks |

## Count / tone model (tabs.mdc)

- Sibling badges: dedicated unfiltered workspace summary / `stockAlertSummary` / suppliers `totalItemCount`
- Active order tab: filtered `workbench.orders.totalItemCount`
- Active stock-alert tab: filtered `inventoryWorkbench.stocks.totalItemCount`
- Catalog hub: count `null`
- Tones: `warning` / `danger` only for attention queues; others `info`

## Tables / printing

- Printable desks: Filters → Settings → Export → Print → context
- Print trigger label: `commonPrintActionLabel` (`Print`)
- Default visible columns prefer **5** (per-tab inventories + tests)
- Filter/Settings footers: Clear/Apply/Close + Apply/Reset columns/Close

## Documented non-gaps / exceptions

- Nested formulary / shelf / inventory-selection pickers: `enableExport: false`
- Controlled-drug audit ∩ documented in atom maps with **no dedicated chrome** yet
- Pending payment tab requires pharmacy + billing read; operations-only route entry omits catalog/stock/suppliers

## Regression coverage

- Per-tab `*_permissions_test.dart` (01–12) + `pharmacy_scope_navigation_test.dart` + `pharmacy_access_test.dart` + `pharmacy_workspace_page_test.dart` + `pharmacy_convention_gaps_test.dart`

Per-tab inventories: `tabs/12-pharmacy/01`–`12`. Source prompt: `tabs-lister/12-pharmacy.md`.
