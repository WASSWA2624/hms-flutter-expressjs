# Pharmacy inventory — convention gaps

Optional findings vs `prompts/.cursor/*.mdc` after shared-chrome remediation (2026-08-12).

## Residual / notes

- none (required Export/Print gating, Filters label key, and preview-first list Print are closed on order / catalog / suppliers desks).
- Nested formulary/selection / shelf-picker tables intentionally keep `enableExport: false` (picker chrome, not printable desks).
- Stock-alert desks still reuse Catalog → Inventory filtered views (tracked for per-tab prompts `09`–`12` if a dedicated alert table is required).
- Controlled-drug audit requirement remains documented in atom maps with **no dedicated chrome** on Ready / All orders (product exception until audit panels mount).
- Pending payment requires both pharmacy + billing read; route-only operations readers never see catalog/stock/suppliers.

Per-tab inventory lives under this folder; source prompt: `tabs-lister/12-pharmacy.md`.
