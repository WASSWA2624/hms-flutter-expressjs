# Reception Dashboard: Front-Desk Home Parity with Pharmacy Patterns

Bring the receptionist Home dashboard to pharmacist-home operational quality—KPIs, deep-links, charts, and labels that match what receptionists do most—without rewriting the Reception workspace or cloning pharmacy stock/sales metrics.

## Context

**Current behavior (codebase; no screenshots attached)**

- **Pharmacy reference:** Pharmacist home uses a desk-focused KPI strip (orders, pending, dispensed, stock risk, sales, billing pending), `homePharmacyMetricQuery` → `/pharmacy?section=…` with facility-local today bounds, `PharmacyMostSoldCharts` (period / top-N + tappable status mix), domain labels, and omits the home pending-orders panel because Pharmacy owns that worklist.
- **Reception home today:** Profile `receptionist` (`homeTitle: Front desk`) ships KPIs `appointments_today` (UI label **Meetings**), `desk_queue`, `turnaround_pressure`, `no_show_pressure`, plus overflow templates `registrations_today`, `emergency_cases_today`, `opd_notifications_attention`, `pending_balance_amount`. `maxStatusCards: 4` (effective cap 4; expand may surface cross-domain cards up to 6). Quick actions: register patient, book appointment, route patient. Shortcuts: reception, patients, communications, reports, settings.
- **Deep-link drift:** Metric routes use `section=queue` | `in-progress` | `follow-up` | `desk-queue`. Canonical Reception values are `appointments`, `desk-queue`, `high-priority`, `active`, `follow-ups`, `payment-gate` (`receptionDeskSectionToQueryValue`). Aliases partly compensate, but `receptionDeskSectionFromQuery` maps `follow-up` and `no_show_pressure` to **paymentGate**—so the Follow-ups KPI can open Payment gate. Pending payments routes to Billing (`queue=pendingPayment`), not Reception Payment gate.
- **Charts:** Reception uses generic `DashboardChartsRow` (arrivals trend + appointment status mix). Only pharmacist mounts a role-specific interactive chart strip.
- **Backend metrics (`ROLE_PACKS.RECEPTIONIST`):** `appointmentsToday` (scheduled_start ≥ today), `appointmentDeskQueue` (SCHEDULED|CONFIRMED|IN_PROGRESS), `turnaroundPressure` (IN_PROGRESS), `noShowPressure` (NO_SHOW), `registrationsToday`, `emergencyCasesToday`, `pendingBalanceAmount`. Trend series = patient creates; distribution = appointment status counts. Workspace queue split: queue_preview = appointments; follow_up_preview = IN_PROGRESS appointments + emergency cases (not callback/no-show follow-ups).
- **Reception workspace (preserve):** Sections Appointments, Desk queue, High priority, Active visits, Follow-ups, Payment gate with existing permissions, dialogs, and worklists.

**Intended behavior**

- Mirror pharmacy’s *desk home* pattern for reception: primary KPIs and charts reflect daily front-desk work; every tappable KPI opens the matching Reception section (or Patients for registrations) with correct query params; labels use reception language (Appointments, Desk queue—not Meetings).
- Primary strip emphasizes: today’s appointments, desk queue, active/in-progress visits, no-show / follow-up callbacks; secondary (permissioned): registrations today, high-priority / emergency intake, payment-gate pending balances. Do not invent pharmacy-style stock/sales KPIs for reception.
- Fix section alias bugs and prefer Reception Payment gate for pending-payment guidance when the user can open Reception with `billing:read`.

**Definitions**

- *Reception dashboard:* Role home for `AppRole.receptionist` / profile id `receptionist` (not the `/reception` workspace itself).
- *Desk work:* Register, book, check-in/route, high-priority intake, active visits, follow-up callbacks, payment-gate guidance.
- *Canonical section:* Value from `receptionDeskSectionToQueryValue`.

## Requirements

1. Audit and reorder receptionist status cards so the visible primary strip (≤6 after expand, Dashboard.md guidance) matches desk work: appointments today → desk queue → active/in-progress → follow-ups/no-shows, then permissioned registrations, high-priority/emergency, pending payments. Remove or demote cards that lack a live receptionist metric or are not front-desk primary (e.g. `opd_notifications_attention` unless wired to a real receptionist count).
2. Relabel KPIs, queue titles, and chart titles to reception domain language (Appointments today, Desk queue, Active visits / In progress, Follow-ups, etc.); eliminate “Meetings” / “Desk / meetings” copy.
3. Add `homeReceptionMetricQuery` (pharmacy counterpart): map each reception KPI to `/reception` (or `/patients` for registrations) with **canonical** `section` values and facility-local today `from`/`to` when the metric is today-scoped. Route `pending_balance_amount` to Reception `payment-gate` when shell access allows; otherwise keep Billing fallback.
4. Fix `receptionDeskSectionFromQuery`: `follow-up` / `follow_ups` / `no_show_pressure` → `followUps`; payment aliases only → `paymentGate`; keep `in-progress` / `turnaround_pressure` → `activeVisits`.
5. Mount a receptionist-specific chart strip (pharmacy parity of interaction, not data): period-aware arrivals/registrations trend + tappable appointment/queue status mix that deep-links into matching Reception sections. Reuse shared chart primitives; do not show most-sold drugs.
6. Align home queue / follow-up previews with desk meaning: queue = desk appointments awaiting action; follow-ups = no-show/callback pressure (not IN_PROGRESS duplicates). Either fix the backend split or omit a redundant home queue panel when Reception owns the worklist (document the chosen pharmacy-like approach).
7. Keep metric definitions consistent with worklist filters and facility-local today; soft-refresh Home after reception mutations that change these KPIs (`homeInvalidateDashboard` / existing sync). Loading, empty, and error states for strip and charts; unauthorized KPI/chart/route absent (not disabled stubs).
8. Tests: deep-link matrix per KPI; alias fix regression; primary card order/labels; chart segment → section navigation; unauthorized atoms absent; Reception workspace behavior unchanged except corrected inbound query handling; pharmacist home unchanged.

## Constraints

- Reuse Home scaffold, metric strip, access gates, and pharmacy chart *patterns* only—do not copy pharmacy stock/sales KPIs or rebuild `/reception` tabs/CRUD.
- Backend RBAC/ABAC remains authoritative. Theme tokens; light/dark; responsive; no clipped primary actions.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Primary KPIs and labels match front-desk daily work; no Meetings wording; non-desk cards demoted/removed. | R1, R2 |
| A2 | Each authorized KPI deep-links to the correct Reception/Patients target with canonical section (+ today bounds where applicable). | R3, R4 |
| A3 | `follow-up` / `no_show_pressure` open Follow-ups; payment aliases open Payment gate. | R4 |
| A4 | Reception home charts are interactive and section-aware like pharmacy’s desk charts, without pharmacy product charts. | R5 |
| A5 | Queue/follow-up home previews match desk semantics (or panel omitted with documented pharmacy-like rationale). | R6 |
| A6 | Unauthorized atoms absent; themes/viewports usable; pharmacy home and Reception worklists otherwise unchanged. | R7, R8 |

## Relevant Files

- `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart` (receptionist + pharmacist profiles)
- `frontend/lib/features/home/presentation/widgets/home_metric_routes.dart`
- `frontend/lib/features/home/presentation/pages/home_page.dart`, `pharmacy_most_sold_charts.dart`, `home_dashboard_actions.dart`
- `frontend/lib/features/reception/domain/entities/reception_entities.dart` (`receptionDeskSectionFromQuery`)
- `frontend/lib/features/home/domain/entities/home_dashboard_layout.dart`, `home_dashboard_atom_permissions.dart`
- `backend/src/lib/dashboard/summary.js`, `backend/src/modules/dashboard-widget/repositories/dashboard-widget.repository.js`
- `backend/src/modules/dashboard-workspace/services/dashboard-workspace.service.js` (`splitReceptionistWorkspaceQueues`)
- `frontend/test/features/home/domain/entities/home_dashboard_layout_test.dart` (+ metric-route / section-alias tests)

## Verification

- Widget/unit: KPI order/labels; every receptionist metric route; section alias matrix; chart tap → `/reception?section=…`.
- Backend: receptionist metric pack and queue/follow-up split match documented definitions.
- Manual: sign in as receptionist → Home KPIs open correct desk tabs; Follow-ups KPI ≠ Payment gate; Payment pending opens payment-gate when allowed; light/dark + narrow width; pharmacist home still shows pharmacy charts/KPIs only.
