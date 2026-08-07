# Reception Reporting Index

First-dense Reporting chrome for the **reception** owned pack (demo: `reception@hosspi.com`). Parent scope: `prompts/reporting-analytics.md`.

## Context

- Catalog sections: registrations, appointments, desk.
- Runnable: `patient_registrations`, `appointment_throughput_no_shows`.
- Desk buttons and `new_vs_returning` remain unavailable until schema-backed datasets exist (see `03-desk.md`, `01-registrations.md`).

## Data accuracy rules

1. Registration volume = `patient.created_at` counts via `runPatientRegistrationsDataset` (extend for facility group-by / returning definition).
2. Appointment throughput/no-shows = `runAppointmentDataset` status buckets only—do not reuse pharmacy dispense throughput.
3. Desk metrics must match Reception worklist / payment-gate / home desk definitions—or stay unavailable.
4. Seed: ≥1,000 `patient` / `appointment` (and `visit_queue` / gate invoices / emergency when desk reports wire). Assert floors.
5. Labels use front-desk language (registrations, no-shows, desk queue)—not Meetings or pharmacy sales/stock.

## Requirements

1. Keep reception report ids stable; do not clone pharmacy sales/stock metrics.
2. Execute category prompts `01`–`03` below before claiming deep completeness.
3. Align with `prompts/reception-dashboard.md` section language where reports deep-link or share filters.
4. Follow parent epic + `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`.

## Constraints

- Pharmacy and admin Reporting chrome unchanged.
- Unauthorized atoms absent; pack matrix stays green.

## Relevant Files

| # | Prompt |
| --- | --- |
| 1 | `01-registrations.md` |
| 2 | `02-appointments.md` |
| 3 | `03-desk.md` |
| Spec | `prompts/reporting-analytics.md`, `prompts/reception-dashboard.md` |
| Catalog/provider | `domain_reporting_catalogs.dart`, `domain_reporting_data_provider.dart` |
| Datasets | `backend/src/lib/reports/datasets.js`, `constants.js` |

## Verification

- Implement 01→03. Dialog totals = dataset for same from/to/scope.
- Manual: `reception@hosspi.com` Reporting matches desk job; pharmacist sales catalog unchanged.
