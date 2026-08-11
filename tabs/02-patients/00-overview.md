# Patients registry UI inventory

Source: `tabs-lister/02-patients.md` · Code base date: 2026-08-11

## Context

Catalog of every visible / reachable UI atom on `PatientRegistryPage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/patients` (`AppRoutes.patients`)  
**Page:** `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`  
**Access:** `frontend/lib/features/patients/presentation/patient_registry_access.dart`  
**Sections enum:** `PatientRegistrySection`

## Desk tabs (order)

| Enum | Query `section` | Aliases | File |
| --- | --- | --- | --- |
| `all` | _(omit / empty)_ | `all` (default) | [01-all.md](01-all.md) |
| `active` | `active` | — | [02-active.md](02-active.md) |
| `admitted` | `admitted` | — | [03-admitted.md](03-admitted.md) |
| `balanceDue` | `balance-due` | `balance_due`, `balancedue` | [04-balance-due.md](04-balance-due.md) |

Helpers: `PatientRegistrySectionFilter.queryValue` / `PatientListQuery.fromUri` in `patient_entities.dart`.

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`
- `frontend/lib/features/patients/presentation/patient_registry_access.dart`
- `frontend/lib/features/patients/domain/entities/patient_entities.dart`
- `frontend/lib/features/patients/presentation/controllers/patient_registry_controller.dart`
- `frontend/lib/features/patients/presentation/widgets/patient_detail_dialog.dart`
- `frontend/lib/features/patients/presentation/widgets/patient_detail_dialog_body.dart`
- `frontend/lib/features/patients/presentation/widgets/patient_detail_quick_actions.dart`
- `frontend/lib/features/patients/presentation/widgets/patient_admission_quick_dialog.dart`
- `frontend/lib/features/patients/presentation/widgets/patient_discharge_planning_dialog.dart`
- `frontend/lib/features/patients/presentation/widgets/patient_billing_context_panel.dart`
- `frontend/lib/features/patients/presentation/widgets/patient_pharmacy_context_panel.dart`
- `frontend/lib/shared/opd_actions/` (appointment / encounter reuse)
- `frontend/lib/shared/clinical_actions/` (lab / radiology / theater / physio)
- `frontend/test/features/patients/`
