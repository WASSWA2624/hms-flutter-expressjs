# Claims workspace UI inventory

Source: `tabs-lister/15-claims.md` · Code base date: 2026-08-11

## Context

Catalog of every visible / reachable UI atom on `ClaimsWorkspacePage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/claims` (`AppRoutes.claims`)  
**Page:** `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart`  
**Access:** `frontend/lib/features/claims/presentation/claims_access.dart`  
**Sections enum:** `ClaimsDeskSection`

## Desk tabs (order)

| Enum | Query `section` | Aliases / notes | File |
| --- | --- | --- | --- |
| `authorizations` | `authorizations` | default | [01-authorizations.md](01-authorizations.md) |
| `activeClaims` | `active-claims` | | [02-active-claims.md](02-active-claims.md) |
| `settled` | `settled` | | [03-settled.md](03-settled.md) |
| `insuranceSetup` | `insurance-setup` | non-queue panel | [04-insurance-setup.md](04-insurance-setup.md) |

Helpers: `claimsDeskSectionFromQuery` / `claimsDeskSectionToQuery` in `claims_entities.dart`.

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart`
- `frontend/lib/features/claims/presentation/claims_access.dart`
- `frontend/lib/features/claims/domain/entities/claims_entities.dart`
- `frontend/lib/features/claims/presentation/controllers/claims_workspace_controller.dart`
- `frontend/lib/features/claims/presentation/widgets/claims_insurance_config_dialogs.dart`
- `frontend/lib/features/claims/presentation/widgets/insurance_authorization_panel.dart`
- `frontend/test/features/claims/`
