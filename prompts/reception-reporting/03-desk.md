# Reception Reporting: Front Desk Operations — Accurate Dialog Mapping

Wire `desk` dialogs to visit-queue, payment-gate, and high-priority sources already used by Reception—new datasets only when joins are real; never invent pharmacy-style stock metrics.

## Context

**Catalog (`desk` category)** — all `datasetKey` null today

| Report id | Intended desk meaning | Likely authoritative source |
| --- | --- | --- |
| `desk_queue_pressure` | Appointments/visits waiting at desk | Align with home `appointmentDeskQueue`: appointments in `SCHEDULED|CONFIRMED|IN_PROGRESS` **and/or** `visit_queue` non-terminal entries—pick one, match worklist filters |
| `payment_gate_pending` | Patients with unpaid guidance at desk | Same ledger as Reception payment gate: open/unpaid invoices surfaced by billing list used by `ReceptionPaymentGateController` (not a parallel AR formula) |
| `high_priority_intake` | Prioritized desk / emergency intake | Prefer `visit_queue.is_prioritized=true` and/or `emergency_case` “today” count used by home `emergencyCasesToday`—subtitle names which |

**No dataset yet** in `REPORT_DATASETS` for these three—register new keys in `constants.js` + runners when wiring; do not overload `appointment_throughput_no_shows` with desk-queue semantics without documenting the fork.

**Schema**

- `visit_queue`: `status` (`AppointmentStatus`), `queued_at`, `is_prioritized`, facility/patient/appointment links.
- Payment gate: invoice open statuses / pending balance via billing APIs already used by reception UI.
- Emergency: `emergency_case` (home metric)—do not invent a separate prioritization table.

## Data contract

| Report id | Authoritative source | Required columns (keys) | Notes |
| --- | --- | --- | --- |
| `desk_queue_pressure` | chosen queue definition over range (daily series or snapshot + trend) | Prefer `date`, `queue_count` (and optional status breakdown keys) | Must match Reception desk-queue filter language |
| `payment_gate_pending` | payment-gate invoice entries / open balances | Prefer `date` or patient/invoice keys, `amount` and/or `pending_count` | Currency for amount; same open rules as gate UI |
| `high_priority_intake` | prioritized visit_queue and/or emergency_case in range | Prefer `date`, `priority_count` (optional source mix) | Subtitle: visit_queue vs emergency_case |

## Requirements

1. Implement each report with a registered dataset runner or leave unavailable with gap note—no fabricated client counts.
2. Prefer extending existing dashboard metric queries into report datasets over divergent SQL.
3. Soft-refresh Overview signals after runs that change desk metrics when applicable.
4. Seed: when wired, applicable facts ≥1,000 rows (`visit_queue` and/or `appointment` / `invoice` / `emergency_case` as used). Diversify statuses/dates/prioritized flags. Assert floors.
5. Shared kit UX states; reception pack ∩ `reports:read` (and `billing:read` only if payment-gate report needs it—hide if unauthorized).
6. Tests: ≥1 dialog path with live dataset when first report wires; totals match runner for same from/to; unauthorized atoms absent; pharmacy unchanged.

## Constraints

- Do not clone pharmacy sales/stock. Keep chrome ids stable. Parent: `prompts/reporting-analytics.md`, desk language: `prompts/reception-dashboard.md`.
- Rules: `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Each desk report uses documented source or stays unavailable. | R1–R3 |
| A2 | Queue/priority are counts; payment amounts use currency keys. | contract |
| A3 | Wired facts meet ≥1,000-row seed floor; default presets usable. | R4 |
| A4 | Dialog totals match dataset for same range/scope; unauthorized export absent. | R5–R6 |

## Relevant Files

- `datasets.js`, `constants.js` (new keys)
- Reception payment gate + visit-queue services; dashboard receptionist metrics
- `domain_reporting_catalogs.dart`, `domain_reporting_data_provider.dart`

## Verification

- Compare desk-queue count to Reception worklist filter for one day.
- Manual: reception@ → Desk → each button (unavailable until wired; then dense).
