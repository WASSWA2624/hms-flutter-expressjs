# Pharmacy tab — Near expiry

## 1. Tab strip

- Label: `pharmacyDeskNearExpiryLabel` (`Near expiry`)
- Icon: `Icons.hourglass_bottom_outlined`
- Count source:
  - Sibling: `stockAlertSummary.expiringSoonRows`
  - Active: filtered `inventoryWorkbench.stocks.totalItemCount` via `pharmacySectionTabCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `near-expiry`
- Stock query: `PharmacyInventoryStockQuery(expiringWithinDays: 30)` via `applyDeskStockFilter`
- Tab gate: `PharmacyNearExpiryAtomPermissions.tab` = catalog browse ∩ `pharmacy:read` + `pharmacy-dispensing`
- **Omitted when unauthorized**
- Body: `PharmacyCatalogPanel` focused on Inventory (`opensCatalogPanel` + `isStockSection`) — intentional reuse of Catalog Inventory table (not a forked alert table)

## 2. Search / Filters / Settings / Export / Print / context

Same Inventory catalog chrome as [07-catalog.md](07-catalog.md) § Inventory:

Order: **Filters → Settings → Export → Print → bulk Clear?**

- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Close `commonCloseActionLabel`
- Settings: `commonTableSettings*`; storage `pharmacy_catalog_inventory`
- Export / Print: omit without ∩ `evidence:export`; Print label `commonPrintActionLabel` (preview-first)
- Near-expiry preset applied via section `stockQuery`; further filters edit the same inventory query model

## 3. Table

- Inventory stock rows filtered to near-expiry window
- Default columns (**5**): Selection / Item / Quantity / Stock status / Actions
- Optional columns via Settings (`columnChoices`)
- Row → Adjust / Clear when write ∪

## 4. Advanced filters / search fields

Inventory stock filters (status / item / SKU / facility / storage / pending) with near-expiry preset.  
Footer: Clear filters → Apply filters → Close.

## 5–9. Actions / dialogs / forms / print

Same catalog Inventory dialogs as Catalog (adjust/clear stock). No order dispense chrome.

## 10. Loading / empty / error / success

Catalog inventory empty/loading panels; mutation feedback under write ∪.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab | `PharmacyNearExpiryAtomPermissions` browse ∩ |
| Export / Print | ∩ `evidence:export` |
| Mutations | catalog write ∪ |
| Operations-only entry | stock tabs omitted |
