# Accounts workspace UI inventory

Source: `tabs-lister/14-accounts.md` · Code base date: 2026-08-11

## Context

Catalog of every visible / reachable UI atom on `AccountsWorkspacePage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/accounts` (`AppRoutes.accounts`)  
**Page:** `frontend/lib/features/accounts/presentation/pages/accounts_workspace_page.dart`  
**Access:** `frontend/lib/features/accounts/presentation/accounts_access.dart`  
**Sections enum:** `AccountsDeskSection`

**Note:** `accounts_gl_workspace_page.dart` re-exports `accounts_workspace_page.dart`. The Accounts desk shows GL as the in-desk `gl` tab (`AccountsGlPanel` → `showAccountsGlDialog`), not a separate nested route page.

## Desk tabs (order)

| Enum | Query `section` | Aliases | File |
| --- | --- | --- | --- |
| `work` | `work` | `all`, `inbox` | [01-work.md](01-work.md) |
| `journals` | `journals` | `journal-entries`, `unposted`, `ready-to-post` | [02-journals.md](02-journals.md) |
| `approvals` | `approvals` | `approval-required` | [03-approvals.md](03-approvals.md) |
| `gl` | `gl` | `general-ledger`, `ledger` | [04-gl.md](04-gl.md) |
| `ledgers` | `ledgers` | `patient-ledgers` | [05-ledgers.md](05-ledgers.md) |
| `chart` | `chart` | `chart-of-accounts`, `coa` | [06-chart.md](06-chart.md) |
| `books` | `books` | `periods`, `period-close`, `close` | [07-books.md](07-books.md) |

Helpers: `AccountsDeskSection.resolveDeskSlug` / `sectionQueryValue` in `accounts_entities.dart`.

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/accounts/presentation/pages/accounts_workspace_page.dart`
- `frontend/lib/features/accounts/presentation/pages/accounts_gl_workspace_page.dart` (re-export)
- `frontend/lib/features/accounts/presentation/accounts_access.dart`
- `frontend/lib/features/accounts/domain/entities/accounts_entities.dart`
- `frontend/lib/features/accounts/presentation/controllers/accounts_workspace_controller.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_*_panel.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_journal_dialog.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_gl_dialog.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_chart_dialogs.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_patient_ledger_dialog.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_period_dialogs.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_work_actions.dart`
- `frontend/test/features/accounts/`
