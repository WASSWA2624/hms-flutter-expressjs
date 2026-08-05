# Pharmacy: Walk-In Orders and Comprehensive Pharmacy Reporting

Enable pharmacy walk-in order creation (no clinical encounter) and period-based pharmacy reporting—consumption, stock risk/suggestions, throughput, source mix—via Pharmacy analytics and Reports create/run, delivered with built-in print plus PDF, Excel, and CSV. Deny pharmacist-focused `/patients` access while allowing required patient detail reads inside Pharmacy and the pharmacy dashboard.

## Context

**Current behavior**

- `/pharmacy` is operational: Ready / Partial / Pending payment / Completed / Cancelled / All orders, Catalog, and threshold stock alerts.
- Orders come from clinical modules via `createPharmacyOrder`. Pharmacy Flutter has **no** create-order API or walk-in CTA.
- Backend create accepts `patient_id` required and `encounter_id` optional; `order_source` is `PHARMACY` without encounter (UI: “Walk-in pharmacy”).
- Home `record_pharmacy_sale` → `?section=sales` is a stub (not a desk section).
- Reports has only `inventory_stock_risk`. No pharmacy datasets for consumption, suggestions, throughput, returns, expiry, or source mix. No Pharmacy analytics panel / Reports deep link; focused shell may hide `/reports` despite `reports:read`. Print and PDF/CSV/XLSX exist—pharmacy datasets are not wired through them.
- Default `PHARMACIST` includes `patient:read` and `patients:read`; focused shell and home shortcuts include `/patients`.

**Intended behavior**

- Authorized users **create walk-in orders** from `/pharmacy`; orders join worklists with walk-in labeling; dispense/payment unchanged.
- Pharmacist-focused users **cannot** open `/patients` (shell, shortcuts, deep links absent). They **can** read required patient fields for walk-in select, order rows/details, and pharmacy home KPIs inside `/pharmacy` and the pharmacy dashboard—not via the registry.
- Authorized users **see** and **create/run** pharmacy reports (day/month/year/custom) with charts and tables, and **present** them via built-in **print** plus **PDF**, **Excel (XLSX)**, and **CSV**.
- Coverage: consumption (most/least), stock suggestions, stock/expiry risk, throughput, clinical vs walk-in mix. Reuse Reports—no parallel stack. Desk and clinical prescribing stay unchanged unless required.

**Definitions**

- *Pharmacist-focused user*: `isPharmacistFocusedShellUser`.
- *Patients registry*: `/patients` (incl. deep links)—not pharmacy-embedded patient chrome.
- *Required patient details (pharmacy)*: identity/search and fields already needed to dispense safely—not registry CRUD or unrelated charting.
- *Walk-in pharmacy order*: registered `patient_id`, no `encounter_id`, `order_source` `PHARMACY`.
- *Consumption*: sum of completed `quantity_dispensed` per drug, facility-scoped, in period.
- *Highly / least consumed*: ranked lists; least-consumed uses a clear filter (e.g. stocked or previously dispensed).
- *Stock suggestion*: advisory restock from consumption rate − on-hand (≥0), optionally vs `reorder_level`—not an auto PO.
- *Operational throughput*: created, dispensed, partial, cancelled, pending, returns in period.
- *Source mix*: counts/qty by `CLINICAL` vs `PHARMACY`.
- *Stock/expiry risk*: extend `inventory_stock_risk` with near-expiry/expired pressure where data exists.
- *Period*: day, month, year, or custom `from`–`to`. *Granularity*: daily short; monthly for year/multi-month.
- *Present / deliver report*: built-in print and/or PDF, Excel (XLSX), CSV (`REPORT_FORMATS`). Keep JSON if supported; do not omit PDF/XLSX/CSV/print for pharmacy datasets.

## Requirements

1. Remove `AppRoutes.patients` from `pharmacistFocusedShellRoutes`; deny `/patients` for pharmacist-focused users. Drop default-pack `patients:read` from `PHARMACIST`; keep `patient:read` for embedded pharmacy/dashboard reads. Hide shell/home actions that open `/patients` (absence, not stubs). Dual-role users with registry rights keep `/patients`.
2. Add create-order gated by `pharmacy:write` ∩ `pharmacy-dispensing`: embedded patient search/select (no registry navigation), ≥1 drug line, omit encounter, optional billing. Wire to `POST /pharmacy-workspace/orders`; refresh; success feedback. Map `record_pharmacy_sale` / `section=sales` and an in-workspace CTA here. No auto-encounters; preserve clinical create elsewhere.
3. Extend Reports datasets: keep/extend `inventory_stock_risk`; add pharmacy siblings (or one composite) for consumption ranks, suggestions, throughput, source mix, expiry risk. Facility/tenant scoped; period series/tables at chosen granularity.
4. Support **day**, **month**, **year**, and **custom** `from`/`to` end-to-end; align enums so year/custom are not dropped.
5. Expose analytics for `pharmacy:read` (and `reports:read` where charts/create require it): period selector, KPI strip, ≥2 chart types, suggestion/risk tables. Prefer Pharmacy analytics panel **and** Pharmacy → Reports deep link—not Home-only.
6. Enable create/run from Reports (and Pharmacy when entitled): dataset, period, visualization, **PDF** / **Excel (XLSX)** / **CSV**; completed runs support **built-in print** plus download (reuse Reports print/export gates). Entitled staff open `/reports`; unauthorized print/export/create/registry chrome absent.
7. Progressive disclosure; cover loading, empty, error/retry, validation (create, invalid range/format), print/export feedback. Responsive; theme tokens; light/dark.
8. Preserve dispense/attest/return/cancel, pending-payment, catalog, threshold stock tabs, Home today KPIs (no `/patients` shortcuts for focused pharmacists). Update tests for patients denial, embedded patient read, walk-in create, aggregation, permissions, charts/create-run, print + PDF/XLSX/CSV, deep links.

## Constraints

- Reuse pharmacy-workspace create, embedded patient pickers/`patient:read` APIs, `pharmacy_access`, focused-shell helpers, `datasets.js` / Reports print/export—no second order, analytics, print, or registry stack.
- No purchasing/PO or general ledger; suggestions/risk stay advisory.
- Clinical users own encounter-linked prescribing; pharmacy create is **walk-in only**.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `.cursor/access/default_user_roles.mdc`, `.cursor/flows/pharmacy-flow.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Focused pharmacist: no `/patients`; `/pharmacy` allowed; embedded patient details/search work on desk + dashboard. | R1–R2 |
| A2 | `pharmacy:write` creates walk-in order; CTA/`section=sales` opens create; unauthorized absent. | R2, R7 |
| A3 | Day/month/year/custom shows consumption, suggestions, throughput, source mix, stock/expiry risk. | R3–R5 |
| A4 | ≥2 charts; create/run with visual + tabular; **print** and **PDF**/**Excel**/**CSV**; unauthorized export/print absent. | R5–R6 |
| A5 | Entitled pharmacist opens Reports; desk/clinical prescribing unchanged; dual-role keeps `/patients`. | R1, R6, R8 |
| A6 | Invalid create or empty/invalid periods/formats show validation/empty; loads show loading. | R7 |
| A7 | Tests cover patients denial, embedded patient read, walk-in create, aggregation, permissions, print/PDF/XLSX/CSV. | R8 |

## Relevant Files

- `frontend/lib/app/router/app_routes.dart` (`pharmacistFocusedShellRoutes`); shell/home profiles + actions
- `frontend/lib/features/pharmacy/presentation/`; patient picker reuse; reports print/export + charts
- `backend/src/config/permissions.js` (`PHARMACIST`); pharmacy-workspace / pharmacy-order; `lib/reports/datasets.js`, `constants.js`
- Tests: shell_route_access; pharmacy access/create; patients absence; reports datasets; print/export UI

## Verification

- Backend: walk-in create; period aggregation; PDF/XLSX/CSV; pharmacist pack lacks `patients:read`.
- Flutter: no `/patients` for focused pharmacist; embedded patient read in pharmacy/dashboard; create + analytics + print/PDF/Excel/CSV when entitled.
- Manual `PHARMACIST`: cannot open Patients; walk-in → dispense via in-pharmacy patient select; reports print/export; queues/catalog work. Light/dark and narrow viewports.
