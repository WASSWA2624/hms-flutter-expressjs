# Pharmacy: Walk-In Orders and Comprehensive Pharmacy Reporting

Enable pharmacy walk-in order creation (no clinical encounter) and period-based pharmacy reporting—consumption, stock risk/suggestions, throughput, source mix—via Pharmacy analytics and Reports create/run, delivered with built-in print plus PDF, Excel, and CSV. Deny pharmacist-focused `/patients` access while allowing required patient detail reads inside Pharmacy and the pharmacy dashboard.

## Context

**Current behavior**

- `/pharmacy` is operational (queues, catalog, threshold stock alerts). Orders come from clinical modules; Flutter has **no** walk-in create API/CTA. Backend create allows `patient_id` + optional `encounter_id`; no encounter → `order_source` `PHARMACY` (“Walk-in pharmacy”). Home `record_pharmacy_sale` → `?section=sales` is a stub.
- Pharmacists with `reports:read` can open `/reports`, but catalog/runs stay **empty** even when Pharmacy already lists **dispensed** orders. Only dataset near pharmacy is `inventory_stock_risk` (thresholds)—no consumption, suggestions, throughput, returns, expiry, or source-mix datasets from `pharmacy_order` / `dispense_log`. No Pharmacy analytics panel or Pharmacy → Reports deep link. Print/PDF/CSV/XLSX exist for completed runs, but pharmacy has nothing to run.
- Default `PHARMACIST` includes `patient:read` and `patients:read`; focused shell and home shortcuts include `/patients`.

**Intended behavior**

- Authorized users **create walk-in orders** from `/pharmacy`; dispense/payment unchanged.
- Pharmacist-focused users **cannot** open `/patients`; they **can** read required patient fields for walk-in select, order rows/details, and pharmacy home KPIs inside `/pharmacy` and the pharmacy dashboard.
- When Pharmacy has dispensed/order/stock data, entitled users **see** and **create/run** pharmacy reports (day/month/year/custom) with charts/tables—**`/reports` must not stay empty**—via seeded defaults and/or one-click create from pharmacy datasets. Present via **print**, **PDF**, **Excel (XLSX)**, **CSV**. Coverage: consumption (most/least), stock suggestions, stock/expiry risk, throughput, clinical vs walk-in mix. Reuse Reports—no parallel stack.

**Definitions**

- *Pharmacist-focused user*: `isPharmacistFocusedShellUser`. *Patients registry*: `/patients`—not embedded pharmacy patient chrome.
- *Required patient details (pharmacy)*: identity/search and fields needed to dispense safely—not registry CRUD.
- *Walk-in pharmacy order*: registered `patient_id`, no `encounter_id`, `order_source` `PHARMACY`.
- *Consumption*: sum of completed `quantity_dispensed` per drug, facility-scoped, in period.
- *Highly / least consumed*: ranked lists; least-consumed uses a clear filter (e.g. stocked or previously dispensed).
- *Stock suggestion*: advisory restock from consumption rate − on-hand (≥0), optionally vs `reorder_level`—not an auto PO.
- *Operational throughput*: created, dispensed, partial, cancelled, pending, returns in period.
- *Source mix*: counts/qty by `CLINICAL` vs `PHARMACY`.
- *Stock/expiry risk*: extend `inventory_stock_risk` with near-expiry/expired pressure where data exists.
- *Period*: day, month, year, or custom `from`–`to`. *Granularity*: daily short; monthly for year/multi-month.
- *Present / deliver report*: built-in print and/or PDF, Excel (XLSX), CSV (`REPORT_FORMATS`). Do not omit PDF/XLSX/CSV/print for pharmacy datasets.

## Requirements

1. Remove `AppRoutes.patients` from `pharmacistFocusedShellRoutes`; deny `/patients` for pharmacist-focused users. Drop default-pack `patients:read` from `PHARMACIST`; keep `patient:read` for embedded pharmacy/dashboard reads. Hide shell/home `/patients` actions (absence, not stubs). Dual-role registry users keep `/patients`.
2. Add create-order gated by `pharmacy:write` ∩ `pharmacy-dispensing`: embedded patient search/select (no registry navigation), ≥1 drug line, omit encounter, optional billing. Wire to `POST /pharmacy-workspace/orders`; refresh; success feedback. Map `record_pharmacy_sale` / `section=sales` and an in-workspace CTA here. No auto-encounters; preserve clinical create elsewhere.
3. Extend Reports datasets from **`pharmacy_order` / `dispense_log` / inventory** (keep/extend `inventory_stock_risk`): consumption ranks, suggestions, throughput, source mix, expiry risk. Facility/tenant scoped; period series/tables. Seed and/or expose one-click create so entitled pharmacists see catalog/run content when dispense data exists—not an empty `/reports` dead end.
4. Support **day**, **month**, **year**, and **custom** `from`/`to` end-to-end; align enums so year/custom are not dropped.
5. Expose analytics for `pharmacy:read` (and `reports:read` where charts/create require it): period selector, KPI strip, ≥2 chart types, suggestion/risk tables. Prefer Pharmacy analytics panel **and** Pharmacy → Reports deep link to pharmacy datasets.
6. Enable create/run from Reports (and Pharmacy when entitled): dataset, period, visualization, **PDF** / **Excel (XLSX)** / **CSV**; completed runs support **built-in print** plus download (reuse Reports print/export gates). Unauthorized print/export/create/registry chrome absent.
7. Progressive disclosure; cover loading, empty-only-when-no-data, error/retry, validation (create, invalid range/format), print/export feedback. Responsive; theme tokens; light/dark.
8. Preserve dispense/attest/return/cancel, pending-payment, catalog, threshold stock tabs, Home today KPIs (no `/patients` shortcuts for focused pharmacists). Update tests for patients denial, embedded patient read, walk-in create, datasets reflecting dispensed orders, permissions, charts/create-run, print + PDF/XLSX/CSV.

## Constraints

- Reuse pharmacy-workspace create, embedded patient pickers/`patient:read`, `pharmacy_access`, focused-shell helpers, `datasets.js` / Reports print/export—no second order, analytics, print, or registry stack.
- No purchasing/PO or general ledger; suggestions/risk stay advisory. Clinical prescribing stays encounter-linked; pharmacy create is **walk-in only**.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `.cursor/access/default_user_roles.mdc`, `.cursor/flows/pharmacy-flow.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Focused pharmacist: no `/patients`; `/pharmacy` allowed; embedded patient details/search work on desk + dashboard. | R1–R2 |
| A2 | `pharmacy:write` creates walk-in order; CTA/`section=sales` opens create; unauthorized absent. | R2, R7 |
| A3 | Day/month/year/custom shows consumption, suggestions, throughput, source mix, stock/expiry risk from existing dispense/order data. | R3–R5 |
| A4 | With dispensed Pharmacy orders, `/reports` is not empty for entitled pharmacists; ≥2 charts; create/run with visual + tabular; **print** and **PDF**/**Excel**/**CSV**. | R3, R5–R6 |
| A5 | Desk/clinical prescribing unchanged; dual-role keeps `/patients`; unauthorized export/print absent. | R1, R6, R8 |
| A6 | Invalid create or empty/invalid periods/formats show validation/empty; loads show loading. | R7 |
| A7 | Tests cover patients denial, embedded patient read, walk-in create, dispensed→report data, permissions, print/PDF/XLSX/CSV. | R8 |

## Relevant Files

- `frontend/lib/app/router/app_routes.dart` (`pharmacistFocusedShellRoutes`); shell/home profiles + actions
- `frontend/lib/features/pharmacy/presentation/`; patient picker reuse; reports print/export + charts
- `backend/src/config/permissions.js` (`PHARMACIST`); pharmacy-workspace / pharmacy-order; `lib/reports/datasets.js`, `constants.js`; report-definition seeds/runs
- Tests: shell_route_access; pharmacy access/create; patients absence; reports datasets with dispense fixtures; print/export UI

## Verification

- Backend: walk-in create; aggregation from dispensed orders; PDF/XLSX/CSV; pharmacist pack lacks `patients:read`.
- Flutter: no `/patients` for focused pharmacist; embedded patient read; Reports shows pharmacy definitions/runs when Pharmacy has dispensed data; print/PDF/Excel/CSV when entitled.
- Manual `PHARMACIST`: no Patients registry; walk-in → dispense; open Reports and run reports reflecting dispensed orders; queues/catalog work. Light/dark and narrow viewports.
