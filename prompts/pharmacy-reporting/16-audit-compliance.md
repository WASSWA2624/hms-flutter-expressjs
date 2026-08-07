# Pharmacy Reporting: Audit & Compliance Dialogs and Demo Seed

Implement Audit & Compliance report dialogs from audit trails with before/after values, actor attribution, and permission-safe demo audit rows.

## Context

**Current behavior**

- Category `audit_compliance` has 10 reports; all unavailable.
- Backend audit/PHI logs and report-related audit events are seeded in volume/governance packs but not projected into pharmacy Reporting dialogs.

**Intended behavior**

- Dialogs answer who created/edited/voided, previous vs new values, timestamps, stock/price change audits, permission snapshots, unauthorized attempts, and prescription/controlled audit trails for the period.

**Definitions**

- *Audit row:* Immutable event with actor, entity, action, timestamp, optional old/new payloads.
- *Report ids:* `who_created`, `who_edited`, `who_deleted_voided`, `previous_vs_new_values`, `change_date_time`, `audit_stock_adjustments`, `audit_price_changes`, `user_permissions`, `unauthorized_attempts`, `prescription_controlled_audit`.

## Requirements

1. Map all audit report ids to audit-log datasets; filter by pharmacy-relevant entity types; never fabricate actors.
2. Units: timestamps formatted; counts of attempts → count; price old/new → currency; stock old/new qty → quantity; permission names plain.
3. Soft-refresh; empty when no events; error on denial; subtitle notes permission trimming when fields redacted.
4. Seed audit events for create/edit/void, stock adjustment, price change, unauthorized attempt, and controlled-dispense audit samples in demo window.
5. Reuse audit modules + shared reporting; hide reports/columns without audit entitlement—absent, not disabled.
6. Responsive (payload progressive disclosure on narrow); light/dark.
7. Tests: unauthorized UI absent; seeded event types; export gated.

## Constraints

- Backend RBAC/ABAC authoritative; follow `.cursor/access/permissions.mdc`.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All 10 audit reports map to ready/empty/error when entitled + seeded. | R1 |
| A2 | Price/qty/time fields correctly typed; redaction safe. | R2 |
| A3 | Demo includes create/edit/void, price, stock, unauthorized, controlled audit. | R4 |
| A4 | Unauthorized audit UI absent; shared kit + responsive OK. | R5–R7 |

## Relevant Files

- `.cursor/reporting-analytics.md/pharmacy-reporting.md` §16
- Audit/PHI log modules + seed governance/volume packs
- `pharmacy_reporting_catalog.dart`, data provider
- `frontend/lib/features/reports/presentation/reports_access.dart`
- `frontend/lib/shared/reporting/**`

## Verification

- Widget/provider tests proving audit absent without permission and present with it.
- Manual: Audit → previous vs new, unauthorized attempts; entitled vs unentitled user.
