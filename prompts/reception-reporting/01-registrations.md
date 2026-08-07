# Reception Reporting: Patient Registrations — Accurate Dialog Mapping

Wire `registrations` dialogs to `patient` create volume—facility mix from real `facility_id`, not invented returning flags.

## Context

**Catalog (`registrations` category)**

| Report id | datasetKey today | Projection |
| --- | --- | --- |
| `registrations_volume` | `patient_registrations` | pass-through daily rows |
| `registrations_by_facility` | `patient_registrations` | same dataset (today stamps `scope.facility_label` on every row) |
| `new_vs_returning` | `null` | unavailable |

**Registrations truth (`runPatientRegistrationsDataset`)**

- Source: `patient` where tenant/(optional facility) scope and `created_at` in range.
- Columns: `date`, `registrations`, `facility`.
- Today `facility` is **scope label**, not a group-by on `patient.facility_id`. Multi-facility honesty requires grouping by patient facility (join `facility` label) or keep single-facility demo (one facility seed).

**Schema gaps**

- No `is_returning` / `first_registered_at` alternate on `patient`. “Returning” must be defined via prior activity (e.g. earlier `encounter`/`appointment` before range, or patient created before range with visit in range)—document the chosen definition; never fake client-side.

## Data contract

| Report id | Authoritative source | Required columns (keys) | Notes |
| --- | --- | --- | --- |
| `registrations_volume` | patient creates by day | `date`, `registrations` (+ `facility` when scoped) | Count of patients created |
| `registrations_by_facility` | patient creates grouped by `facility_id` | `facility`, `registrations` | Fix runner; demo may be one row |
| `new_vs_returning` | documented join definition **or gap** | `segment` (`new`/`returning`), `registrations` or `patients` | Subtitle states definition |

## Requirements

1. Implement contract rows: extend `runPatientRegistrationsDataset` (group_by facility / segment params) rather than a second registration formula.
2. Keep `registrations` as create-count; do not mix appointment volume into this category.
3. Wire `datasetKey`s; provider returns ready when rows exist.
4. Seed: ≥1,000 `patient` after `db:seed:demo`; diversify `created_at` across default presets. Assert floor in verify/seed tests.
5. Front-desk labels only (registrations—not pharmacy sales). Permissions: reception pack ∩ `reports:read`.
6. Tests: volume sum equals patient count in range; facility totals partition that count; unauthorized export absent.

## Constraints

- Single-facility demo OK if labeled. Rules: `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`, parent epic / `prompts/reception-dashboard.md` language.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Volume/facility(/new-returning) use contract sources; gaps unavailable. | R1–R3 |
| A2 | `registrations` is a count. | contract |
| A3 | ≥1,000 patients; volume dense for default presets. | R4 |
| A4 | Dialog totals match dataset for same from/to/scope. | R6 |

## Relevant Files

- `datasets.js` (`runPatientRegistrationsDataset`), `constants.js`
- `domain_reporting_catalogs.dart`; Prisma `patient`, `facility`
- Seed/verify packs

## Verification

- SQL count patients in range vs dialog summary.
- Manual: reception@ → Registrations → volume / by facility.
