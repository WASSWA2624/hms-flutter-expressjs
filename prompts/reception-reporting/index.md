# Reception Reporting Index

First-dense Reporting chrome for the **reception** owned pack (demo: `reception@hosspi.com`). Parent scope: `prompts/reporting-analytics.md`.

## Context

- Catalog sections: registrations, appointments, desk.
- Runnable: `patient_registrations`, `appointment_throughput_no_shows`.
- Desk-specific buttons remain unavailable until schema-backed datasets exist.

## Requirements

1. Keep reception report ids stable; do not clone pharmacy sales/stock metrics.
2. Align labels with front-desk language (registrations, no-shows, desk queue).
3. Child prompts own deep subcategory mapping + seed floors.

## Relevant Files

- `frontend/lib/features/reports/presentation/domain_reporting_catalogs.dart`
- `prompts/reporting-analytics.md`, `prompts/reception-dashboard.md`
