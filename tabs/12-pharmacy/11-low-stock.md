# Pharmacy tab — Low stock

## 1. Tab strip

- Label: `pharmacyDeskLowStockLabel`
- Icon: `Icons.trending_down_outlined`
- Count source: `stock.lowStockRows`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `low-stock`
- Stock query: `PharmacyInventoryStockQuery(stockStatus: 'LOW_STOCK')`
- Tab gate: catalog browse ∩ `pharmacy:read`
- **Omitted when unauthorized**
- Body: `PharmacyCatalogPanel` → Inventory with low-stock preset

## 2–9. Chrome / table / dialogs / print

Same Inventory catalog pattern as [09-near-expiry.md](09-near-expiry.md); status filter preset `LOW_STOCK`.

## 10. Loading / empty / error / success

Catalog inventory panels.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab | catalog browse ∩ |
| Mutations | catalog write ∪ |
| Operations-only entry | omitted |
