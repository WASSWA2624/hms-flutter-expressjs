# Clinical Reporting Index

First-dense Reporting chrome for the **clinical** owned pack (demo: `doctor@hosspi.com`, `nurse@hosspi.com`). Parent scope: `prompts/reporting-analytics.md`.

## Context

- Doctors/nurses must **not** mount pharmacy Reporting via embed `pharmacy:read`.
- Runnable: `patient_registrations`, `appointment_throughput_no_shows`.
- Outcomes / LOS / prescriptions stay unavailable until clinical datasets exist.

## Requirements

1. Preserve owned-pack selection in `reports_role_tailoring.dart`.
2. Prefer clinical datasets over pharmacy consumption for this pack.
3. Child prompts for specialty sections as schemas land.

## Relevant Files

- `frontend/lib/features/reports/presentation/reports_role_tailoring.dart`
- `frontend/lib/features/reports/presentation/domain_reporting_catalogs.dart`
- `prompts/reporting-analytics.md`
