# Reception Reporting: Appointments & No-Shows — Accurate Dialog Mapping

Wire `appointments` dialogs to `appointment` throughput status buckets—align with desk language and existing runner definitions.

## Context

**Catalog (`appointments` category)**

| Report id | datasetKey today | Projection |
| --- | --- | --- |
| `appointment_throughput` | `appointment_throughput_no_shows` | pass-through daily rows |
| `no_shows` | `appointment_throughput_no_shows` | emphasize `no_show` (+ scheduled context) |
| `completed_vs_scheduled` (chart) | `appointment_throughput_no_shows` | series `completed` vs `scheduled` |

**Throughput truth (`runAppointmentDataset`)**

- Source: `appointment` in tenant/(optional facility) scope with `scheduled_start` in range.
- Daily aggregates: `scheduled` = count all; `completed` = status `COMPLETED`; `no_show` = status `NO_SHOW`.
- Other statuses (`SCHEDULED|CONFIRMED|IN_PROGRESS|CANCELLED`) count toward `scheduled` only—not separate columns today.

**Status enum:** `SCHEDULED|CONFIRMED|IN_PROGRESS|COMPLETED|CANCELLED|NO_SHOW`.

## Data contract

| Report id | Authoritative source | Required columns (keys) | Notes |
| --- | --- | --- | --- |
| `appointment_throughput` | appointment daily series | `date`, `scheduled`, `completed`, `no_show` | Full throughput table |
| `no_shows` | same series | `date`, `no_show` (+ optional `scheduled`, `no_show_rate`) | Rate = no_show/scheduled when scheduled&gt;0; document if added |
| `completed_vs_scheduled` | same series | `date`, `completed`, `scheduled` | Chart |

## Requirements

1. Prefer extending `runAppointmentDataset` (extra status columns only if catalog needs them) over parallel appointment math.
2. Keep status string matching uppercase enum equality used by the runner.
3. Do not clone pharmacy dispense throughput into reception.
4. Seed: ≥1,000 `appointment` after `db:seed:demo`; diversify statuses including `NO_SHOW` and `COMPLETED` across dates. Assert floor in verify/seed tests.
5. Shared dialog/chart/export; reception pack ∩ `reports:read`; loading/empty/error/success.
6. Tests: dialog sum of `no_show`/`completed`/`scheduled` equals dataset for same from/to; unauthorized export absent.

## Constraints

- Labels: Appointments / No-shows (not “Meetings”). Align KPI meaning with home/reception desk where possible (`prompts/reception-dashboard.md`).
- Rules: `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All three reports use appointment runner contract. | R1–R3 |
| A2 | Counts use `scheduled`/`completed`/`no_show` keys. | contract |
| A3 | ≥1,000 appointments; throughput/no-shows dense for default presets. | R4 |
| A4 | Dialog totals match dataset summary/rows for same range/scope. | R6 |

## Relevant Files

- `datasets.js` (`runAppointmentDataset`), `constants.js`
- `domain_reporting_catalogs.dart`; Prisma `appointment`

## Verification

- Fixture day: scheduled/completed/no_show vs SQL status counts.
- Manual: reception@ → Appointments → throughput, no-shows, completed vs scheduled chart.
