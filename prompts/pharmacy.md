# Pharmacy: Walk-In Orders and Comprehensive Pharmacy Reporting

Enable pharmacy walk-in order creation (no clinical encounter), period-based pharmacy reporting (print + PDF/Excel/CSV), and print of pharmacy order invoices/receipts. On the pharmacy dashboard, show a last-month most-sold-drugs bar chart with qty/amount/profit toggle, and remove the Pending orders collapsible section. Deny pharmacist-focused `/patients` while allowing required patient detail reads inside Pharmacy and the pharmacy dashboard.

## Context

**Current behavior**

- `/pharmacy` is operational (queues, catalog, threshold stock alerts). Orders come from clinical modules; Flutter has **no** walk-in create API/CTA. Backend create allows `patient_id` + optional `encounter_id`; no encounter → `order_source` `PHARMACY`. Home `record_pharmacy_sale` → `?section=sales` is a stub. Pharmacy prints medication instructions / history, but **not** order **invoices/receipts**.
- Pharmacist home: 7-day dispense trend, order-status mix, and a Pending orders collapsible queue—not a last-month most-sold bar with qty/amount/profit toggle.
- `/reports` opens for `reports:read` but catalog/runs stay **empty** despite dispensed orders. Only nearby dataset is `inventory_stock_risk`. No pharmacy dispense datasets or Pharmacy → Reports deep link.
- Default `PHARMACIST` includes `patient:read` and `patients:read`; focused shell/home include `/patients`.

**Intended behavior**

- Authorized users **create walk-in orders** from `/pharmacy`; dispense/payment unchanged. Entitled users **print pharmacy order invoices/receipts** from order detail (built-in print), alongside existing medication-instruction prints.
- Pharmacist-focused users **cannot** open `/patients`; they **can** read required patient fields inside `/pharmacy` and the pharmacy dashboard.
- Pharmacy dashboard: last-month most-sold bar (X = drugs; Y = qty/amount/profit toggle). No Pending orders collapsible section; pending work stays on `/pharmacy` tabs.
- With dispense data, entitled users **create/run** pharmacy reports (day/month/year/custom)—**`/reports` must not stay empty**—via **print**, **PDF**, **Excel (XLSX)**, **CSV**. Also cover consumption ranks, stock suggestions, stock/expiry risk, throughput, source mix. Reuse Reports and shared charts/print—no parallel stack.

**Definitions**

- *Pharmacist-focused user*: `isPharmacistFocusedShellUser`. *Patients registry*: `/patients`—not embedded pharmacy patient chrome.
- *Pending orders collapsible section*: pharmacist home priority/queue panel titled “Pending orders” (`showQueuePanel` / guided pending-dispense chrome)—not `/pharmacy` Ready/New orders tabs.
- *Pharmacy order invoice/receipt*: printable sale document for an order (patient, lines, qty, prices, totals, paid/due when billing exists). Distinct from medication-instructions print and Reports exports.
- *Walk-in pharmacy order*: registered `patient_id`, no `encounter_id`, `order_source` `PHARMACY`.
- *Most sold (last one month)*: top N drugs by active metric over trailing ~30 days / last calendar month; facility-scoped from completed dispenses.
- *Qty* / *Amount* / *Profit*: dispensed qty; sales revenue; amount − unit cost × qty when cost exists (else unavailable)—not invented COGS.

## Requirements

1. Remove `AppRoutes.patients` from `pharmacistFocusedShellRoutes`; deny `/patients` for pharmacist-focused users. Drop default-pack `patients:read`; keep `patient:read` for embedded pharmacy/dashboard reads. Hide shell/home `/patients` actions (absence, not stubs). Dual-role registry users keep `/patients`.
2. Add create-order gated by `pharmacy:write` ∩ `pharmacy-dispensing`: embedded patient search/select, ≥1 drug line, omit encounter, optional billing. Wire to `POST /pharmacy-workspace/orders`; refresh; success feedback. Map `record_pharmacy_sale` / `section=sales` and an in-workspace CTA here. No auto-encounters; preserve clinical create elsewhere.
3. From pharmacy order detail, enable **print invoice/receipt** via built-in print (reuse `PrintDocumentTemplates.invoice` / billing invoice helpers). Include patient, order id, lines (drug, qty, price), totals, payment status when available. Gate with `pharmacy:read` (money may need `billing:read` / pricing read—unauthorized chrome absent). Keep medication-instructions print. Loading, empty-lines validation, preview, success/error.
4. On the pharmacy home dashboard: (a) last-month most-sold bar chart (qty/amount/profit toggle; gate `pharmacy:read`; money metrics may need pricing/billing/`reports:read`; loading/empty/error; reuse `DashboardChartsRow` / BAR_CHART); (b) remove Pending orders collapsible (`showQueuePanel` false for pharmacist)—absence, not disabled. Keep `/pharmacy` Ready/New orders.
5. Extend Reports datasets from **`pharmacy_order` / `dispense_log` / inventory** (keep/extend `inventory_stock_risk`): consumption, suggestions, throughput, source mix, expiry risk, most-sold series. Seed and/or one-click create so `/reports` is not empty when dispense data exists. Support **day**, **month**, **year**, **custom**; Pharmacy analytics + Reports deep link.
6. Enable create/run from Reports (and Pharmacy when entitled): dataset, period, visualization, **PDF** / **Excel (XLSX)** / **CSV**; **built-in print**. Unauthorized print/export/create/registry chrome absent. Progressive disclosure; loading/empty/error/validation; responsive; light/dark.
7. Preserve dispense/attest/return/cancel, pending-payment, catalog, threshold stock tabs, medication-instructions print, non-queue Home KPIs (no `/patients` shortcuts; no Pending orders collapsible). Update tests for patients denial, walk-in create, invoice/receipt print, bar toggle, collapsible absence, dispensed→report data, permissions, report PDF/XLSX/CSV.

## Constraints

- Reuse pharmacy-workspace create, embedded patient pickers/`patient:read`, `pharmacy_access`, focused-shell helpers, home charts, shared printing (`PrintDocumentTemplates`, billing invoice helpers), `datasets.js` / Reports—no second order, analytics, print, or registry stack.
- No purchasing/PO or general ledger; profit is a margin proxy. Clinical prescribing stays encounter-linked; pharmacy create is **walk-in only**.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `.cursor/access/default_user_roles.mdc`, `.cursor/flows/pharmacy-flow.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Focused pharmacist: no `/patients`; `/pharmacy` allowed; embedded patient details/search work. | R1–R2 |
| A2 | `pharmacy:write` creates walk-in order; CTA/`section=sales` opens create; unauthorized absent. | R2 |
| A3 | Authorized user prints pharmacy order invoice/receipt from order detail; unauthorized print chrome absent; instructions print still works. | R3 |
| A4 | Dashboard: last-month most-sold bar with qty/amount/profit toggle; no Pending orders collapsible; empty/loading handled. | R4 |
| A5 | Day/month/year/custom reports from dispense data; `/reports` not empty when orders exist; print + PDF/Excel/CSV. | R5–R6 |
| A6 | Desk/clinical prescribing unchanged; dual-role keeps `/patients`; unauthorized money/export chrome absent. | R1, R6–R7 |
| A7 | Tests cover patients denial, walk-in create, invoice/receipt print, bar toggle, Pending orders collapsible absence, dispensed→report data, permissions, PDF/XLSX/CSV. | R3, R7 |

## Relevant Files

- `frontend/lib/features/home/` (pharmacist profile, guided queue/alerts, charts); `app_routes.dart` focused shell
- `frontend/lib/features/pharmacy/presentation/`; `billing_invoice_print_helpers.dart`; `PrintDocumentTemplates`
- `backend/src/config/permissions.js`; pharmacy-workspace / pharmacy-order; dashboard summary; `lib/reports/datasets.js`, `constants.js`
- Tests: shell_route_access; home pharmacist charts/queue absence; pharmacy create; invoice/receipt print; reports datasets; print/export UI
## Verification

- Backend: last-month top drugs by qty/amount/profit; walk-in create; report aggregation; pharmacist pack lacks `patients:read`.
- Flutter: invoice/receipt print; dashboard bar + metric toggle; no Pending orders collapsible; no `/patients` for focused pharmacist; Reports usable with dispensed data.
- Manual `PHARMACIST`: print invoice/receipt; dashboard bar with no Pending orders collapsible; walk-in → dispense; Reports run/export; `/pharmacy` queues still work. Light/dark + narrow viewports.
