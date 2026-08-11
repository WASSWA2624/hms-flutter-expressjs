# Pharmacy tab — Near expiry

## 1. Tab strip

- Label: `pharmacyDeskNearExpiryLabel`
- Icon: `Icons.hourglass_bottom_outlined`
- Count source: `stock.expiringSoonRows`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `near-expiry`
- Stock query: `PharmacyInventoryStockQuery(expiringWithinDays: 30)`
- Tab gate: catalog browse ∩ `pharmacy:read`
- **Omitted when unauthorized**
- Body: `PharmacyCatalogPanel` focused on Inventory with stock filter (`opensCatalogPanel` + `isStockSection`)

## 2. Search / Filters / Settings / Export / Print / context

Inventory catalog chrome (see [07-catalog.md](07-catalog.md) § Inventory): Filters / Settings / Add when write ∪; Export typically off.

## 3. Table

- Inventory stock rows filtered to near-expiry window (not order columns)
- Row → drug/stock detail/edit surfaces

## 4. Advanced filters / search fields

Inventory stock filters (status / item / SKU / facility / pending) with near-expiry preset applied via section `stockQuery`.

## 5–9. Actions / dialogs / forms / print

Same catalog Inventory dialogs as Catalog (drug details/edit, similarity, pack scan as reachable). No order dispense chrome.

## 10. Loading / empty / error / success

Catalog inventory empty/loading panels.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab | catalog browse ∩ |
| Mutations | catalog write ∪ |
| Operations-only entry | stock tabs omitted |
