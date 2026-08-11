# Pharmacy tab — Out of stock

## 1. Tab strip

- Label: `pharmacyDeskOutOfStockLabel`
- Icon: `Icons.remove_shopping_cart_outlined`
- Count source: `stock.outOfStockRows`
- Count tone: `AppTabCountTone.danger`
- Deep-link `section`: `out-of-stock`
- Stock query: `PharmacyInventoryStockQuery(stockStatus: 'OUT_OF_STOCK')`
- Tab gate: catalog browse ∩ `pharmacy:read`
- **Omitted when unauthorized**
- Body: `PharmacyCatalogPanel` → Inventory with out-of-stock preset

## 2–9. Chrome / table / dialogs / print

Same Inventory catalog pattern as [09-near-expiry.md](09-near-expiry.md); status filter preset `OUT_OF_STOCK`. Order-column helper returns empty list for this desk section (panel owns table).

## 10. Loading / empty / error / success

Catalog inventory panels.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab | catalog browse ∩ |
| Mutations | catalog write ∪ |
| Operations-only entry | omitted |
