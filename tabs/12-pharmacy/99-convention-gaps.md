# Pharmacy inventory — convention gaps

Optional findings vs `prompts/.cursor/*.mdc` after code trace (2026-08-11). No UI changes in this inventory pass.

## Residual / notes

- Order desk `AppListTable` does **not** mount Export or table Print; print is detail/instructions/batch/invoice helper-driven.
- Catalog formulary/selection tables explicitly set `enableExport: false`.
- Filters button label on orders uses `pharmacyQueueFilterLabel` (not always `commonFiltersActionLabel`).
- Suppliers is a **desk** tab (not a nested Catalog icon tab), while entity comments historically mentioned suppliers under catalog nesting.
- Stock-alert desks reuse Catalog → Inventory rather than a separate alert-only table.
- Controlled-drug audit requirement is documented in atom maps but has **no dedicated chrome** on Ready / All orders.
- Pending payment requires both pharmacy + billing read; route-only operations readers never see catalog/stock/suppliers.

Per-tab inventory lives under this folder; source prompt: `tabs-lister/12-pharmacy.md`.
