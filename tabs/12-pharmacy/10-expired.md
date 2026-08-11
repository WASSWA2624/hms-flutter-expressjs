# Pharmacy tab — Expired

## 1. Tab strip

- Label: `pharmacyDeskExpiredLabel`
- Icon: `Icons.event_busy_outlined`
- Count source: `stock.expiredRows`
- Count tone: `AppTabCountTone.danger`
- Deep-link `section`: `expired`
- Stock query: `PharmacyInventoryStockQuery(expiredOnly: true)`
- Tab gate: catalog browse ∩ `pharmacy:read`
- **Omitted when unauthorized**
- Body: `PharmacyCatalogPanel` → Inventory with expired preset

## 2–9. Chrome / table / dialogs / print

Same Inventory catalog pattern as [09-near-expiry.md](09-near-expiry.md) / [07-catalog.md](07-catalog.md) Inventory; filter preset differs (`expiredOnly`).

## 10. Loading / empty / error / success

Catalog inventory panels.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab | catalog browse ∩ |
| Mutations | catalog write ∪ |
| Operations-only entry | omitted |
