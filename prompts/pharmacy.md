# Pharmacy: Walk-In Orders and Comprehensive Pharmacy Reporting

Enable pharmacy walk-in order creation (no clinical encounter) and period-based pharmacy reporting—consumption, stock risk/suggestions, throughput, source mix—via Pharmacy analytics and Reports create/run, delivered with built-in print plus PDF, Excel, and CSV.

## Context

**Current behavior**

- `/pharmacy` is operational: Ready / Partial / Pending payment / Completed / Cancelled / All orders, Catalog, and threshold stock alerts (near expiry, expired, low stock, out of stock).
- Orders come from clinical modules via `createPharmacyOrder`. Pharmacy Flutter has **no** create-order API or walk-in CTA.
- Backend `POST /pharmacy-workspace/orders` accepts `patient_id` required and `encounter_id` optional. Serializer sets `order_source` `PHARMACY` when no encounter, else `CLINICAL`. UI labels `PHARMACY` as “Walk-in pharmacy.”
- Home `record_pharmacy_sale` → `?section=sales` is not a `PharmacyDeskSection`—a stub.
- Reports has only `inventory_stock_risk` (on-hand vs `reorder_level`). No pharmacy datasets for consumption ranks, restock suggestions, dispense throughput, returns, expiry pressure, or walk-in vs clinical mix. Home pharmacist KPIs are mostly today-only. Pharmacy has no analytics panel or Reports deep link; focused shell may hide `/reports` despite `reports:read`. Existing Reports already supports print and `REPORT_FORMATS` including PDF/CSV/XLSX—pharmacy datasets are not wired through that delivery path.

**Intended behavior**

- Authorized users **create walk-in orders** from `/pharmacy` (patient, drug lines, optional billing, no encounter); orders join worklists with walk-in labeling; dispense/payment unchanged.
- Authorized users **see** and **create/run** pharmacy reports for day, month, year, or custom range—with charts and tabular detail—and **present** them via built-in **print** plus **PDF**, **Excel (XLSX)**, and **CSV**.
- Coverage: consumption (most/least), stock suggestions, stock/expiry risk, order/dispense/return throughput, clinical vs walk-in source mix.
- Operational desk and clinical prescribing stay unchanged unless required to expose analytics. Reuse Reports datasets/runs, shared charts, and print/export chrome—no parallel stack.

**Definitions**

- *Walk-in pharmacy order*: registered `patient_id`, no `encounter_id`, `order_source` `PHARMACY`.
- *Clinical order*: has `encounter_id`; clinical modules; unchanged.
- *Consumption*: sum of `quantity_dispensed` (prefer completed logs) per drug, facility-scoped, in period.
- *Highly / least consumed*: ranked lists; least-consumed uses a clear filter (e.g. stocked or previously dispensed).
- *Stock suggestion*: advisory restock from consumption rate − on-hand (≥0), optionally vs `reorder_level`—not an auto PO.
- *Operational throughput*: orders created, dispensed, partially dispensed, cancelled, pending, and returns in period.
- *Source mix*: counts/qty by `CLINICAL` vs `PHARMACY`.
- *Stock/expiry risk*: extend `inventory_stock_risk` with near-expiry/expired pressure where data exists.
- *Period*: day, month, year, or custom `from`–`to`. *Granularity*: daily for short ranges; monthly for year/multi-month.
- *Present / deliver report*: print a completed run with built-in print, and/or download as PDF, Excel (XLSX), or CSV via Reports print/export (`REPORT_FORMATS`). Keep JSON if supported; do not omit PDF/XLSX/CSV/print for pharmacy datasets.

## Requirements

1. Add create-order gated by `pharmacy:write` ∩ `pharmacy-dispensing`: patient select, ≥1 drug line, omit encounter, optional billing. Wire to `POST /pharmacy-workspace/orders`; refresh workbench; success feedback. Map `record_pharmacy_sale` / `section=sales` and an in-workspace CTA to this flow. No auto-encounters; preserve clinical create elsewhere.
2. Extend Reports datasets: keep/extend `inventory_stock_risk`; add pharmacy-category siblings (or one composite) for consumption ranks, stock suggestions, throughput, source mix, and expiry risk. Period queries return series/tables at chosen granularity; facility/tenant scoped.
3. Support **day**, **month**, **year**, and **custom** `from`/`to` end-to-end (resolver, run params, Reports/Pharmacy filters). Align enums so year/custom are not dropped.
4. Expose analytics for `pharmacy:read` (and `reports:read` where charts/create require it): period selector, KPI strip, ≥2 chart types, suggestion/risk tables. Prefer a Pharmacy analytics panel **and** Pharmacy → Reports deep link—not Home-only visuals.
5. Enable create/run from Reports (and Pharmacy when entitled): dataset, period, visualization, format among **PDF**, **Excel (XLSX)**, **CSV**. Completed runs show visual + tabular detail and support **built-in print** plus download in those formats (reuse Reports print/export gates, e.g. `evidence:export`).
6. Staff with `reports:read` (including default `PHARMACIST`) can open `/reports` when granted; unauthorized print/export/create chrome absent.
7. Progressive disclosure: KPIs + charts first; rankings/suggestions secondary without cluttering Ready. Cover loading, empty range, error/retry, validation (create, invalid range/format), print/export feedback. Responsive; theme tokens; light/dark.
8. Preserve dispense/attest/return/cancel, pending-payment, catalog, threshold stock tabs, Home today KPIs. Update tests for walk-in create, aggregation, period math, permissions, charts/create-run, print + PDF/XLSX/CSV, deep links.

## Constraints

- Reuse `createPharmacyOrderSchema`, pharmacy-workspace create, clinical line helpers where fit, patient search, `pharmacy_access`, `datasets.js` / Reports modules, `DashboardChartsRow`, and Reports print/export (`AppReportActionButton`, printing helpers)—no second order, analytics, or print engine.
- No purchasing/PO or general ledger; suggestions/risk stay advisory / inventory-derived.
- Clinical users own encounter-linked prescribing; pharmacy create is **walk-in only**.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `.cursor/flows/pharmacy-flow.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | `pharmacy:write` creates walk-in order (≥1 line, no encounter); CTA/`section=sales` opens create; unauthorized absent. | R1, R7 |
| A2 | Select day/month/year/custom; see consumption (most/least) and stock suggestions. | R2–R4 |
| A3 | Same surface shows throughput, source mix, and stock/expiry risk. | R2, R4 |
| A4 | ≥2 charts; create/run pharmacy report with visual + tabular results. | R4–R5 |
| A5 | Completed run can be **printed** and downloaded as **PDF**, **Excel**, and **CSV**; unauthorized export/print absent. | R5–R6 |
| A6 | Entitled pharmacist opens Reports; desk/clinical prescribing unchanged. | R6, R8 |
| A7 | Invalid create or empty/invalid periods/formats show validation/empty; loads show loading. | R7 |
| A8 | Tests cover walk-in create, aggregation, permissions, print/PDF/XLSX/CSV, and authorized report flows. | R8 |

## Relevant Files

- `frontend/lib/features/pharmacy/presentation/` (workspace, access, controllers, repository/DTOs)
- `frontend/lib/shared/clinical_actions/dialogs/clinical_prescription_action_dialog.dart`
- `frontend/lib/features/home/.../home_dashboard_actions.dart`; shell/home profiles for Reports entitlement
- `frontend/lib/features/reports/presentation/` (print/export); shared dashboard charts + printing helpers
- `backend/src/modules/pharmacy-workspace/`; `pharmacy-order` create; `lib/reports/datasets.js`, `constants.js`; report-run
- `dispense_log` / `pharmacy_order` / `inventory_stock` / drug–inventory links
- Tests: pharmacy access/create; reports datasets/runtime; print/export + analytics permissions/UI

## Verification

- Backend: walk-in create without encounter; period aggregation for consumption, suggestions, throughput, source mix, stock/expiry risk; PDF/XLSX/CSV run formats succeed for pharmacy datasets.
- Flutter: create + analytics with grants, absent without; print and PDF/Excel/CSV when entitled.
- Manual `PHARMACIST` (+ `reports:read` / export grant): walk-in → dispense; switch periods; print and export PDF/Excel/CSV; queues/catalog still work. Light/dark and narrow viewports.