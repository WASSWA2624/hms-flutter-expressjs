# Pharmacy tab — Low stock

## 1. Tab strip

- Label: `pharmacyDeskLowStockLabel` (`Low stock`)
- Icon: `Icons.trending_down_outlined`
- Count source:
  - Sibling: `stockAlertSummary.lowStockRows`
  - Active: filtered `inventoryWorkbench.stocks.totalItemCount` via `pharmacySectionTabCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `low-stock`
- Stock query: `PharmacyInventoryStockQuery(stockStatus: 'LOW_STOCK')` via `applyDeskStockFilter`
- Tab gate: `PharmacyLowStockAtomPermissions.tab` = catalog browse ∩ `pharmacy:read` + `pharmacy-dispensing`
- **Omitted when unauthorized**
- Body: `PharmacyCatalogPanel` focused on Inventory (`opensCatalogPanel` + `isStockSection`) — intentional reuse of Catalog Inventory table (not a forked alert table)

## 2. Search / Filters / Settings / Export / Print / context

Same Inventory catalog chrome as [09-near-expiry.md](09-near-expiry.md) / [07-catalog.md](07-catalog.md) § Inventory:

Order: **Filters → Settings → Export → Print → bulk Clear?**

- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Close `commonCloseActionLabel`
- Settings: `commonTableSettings*`; storage `pharmacy_catalog_inventory`
- Export / Print: omit without ∩ `evidence:export`; Print label `commonPrintActionLabel` (preview-first)
- Low-stock preset applied via section `stockQuery`; further filters edit the same inventory query model

## 3. Table

- Inventory stock rows filtered to `LOW_STOCK`
- Default columns (**5**): Selection / Item / Quantity / Stock status / Actions
- Optional columns via Settings (`columnChoices`)
- Row → Adjust / Clear when write ∪

## 4. Advanced filters / search fields

Inventory stock filters (status / item / SKU / facility / storage / pending) with low-stock preset.  
Footer: Clear filters → Apply filters → Close.

## 5–9. Actions / dialogs / forms / print

Same catalog Inventory dialogs as Catalog (adjust/clear stock). No order dispense chrome.

## 10. Loading / empty / error / success

Catalog inventory empty/loading panels; mutation feedback under write ∪.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab | `PharmacyLowStockAtomPermissions` browse ∩ |
| Export / Print | ∩ `evidence:export` |
| Mutations | catalog write ∪ |
| Operations-only entry | stock tabs omitted |
