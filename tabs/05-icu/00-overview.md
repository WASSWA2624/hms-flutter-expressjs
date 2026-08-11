# ICU workspace UI inventory

Source: `tabs-lister/05-icu.md` · Code base date: 2026-08-11

## Context

Catalog of every visible / reachable UI atom on `IcuWorkspacePage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/icu` (`AppRoutes.icu`)  
**Page:** `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart`  
**Access:** `frontend/lib/features/icu/presentation/icu_access.dart`  
**Sections enum:** `IcuWorkspaceSection`  
**Detail panels:** `IcuDetailPanel`

## Desk tabs (order)

| Enum | Query `section` | Aliases | File |
| --- | --- | --- | --- |
| `active` | `active` (default omitted) | `''` | [01-active.md](01-active.md) |
| `critical` | `critical` | | [02-critical.md](02-critical.md) |
| `transfers` | `transfers` | | [03-transfers.md](03-transfers.md) |
| `discharge` | `discharge` | | [04-discharge.md](04-discharge.md) |
| `ended` | `ended` | | [05-ended.md](05-ended.md) |
| `all` | `all` | | [06-all.md](06-all.md) |
| `beds` | `beds` | | [07-beds.md](07-beds.md) |
| `followUps` | `follow-ups` | `follow_ups`, `followups` | [08-follow-ups.md](08-follow-ups.md) |

Helpers: `IcuWorkspaceSectionX.queryValue` / `IcuWorkspaceSectionX.fromQueryParam` in `icu_entities.dart`.

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart`
- `frontend/lib/features/icu/presentation/icu_access.dart`
- `frontend/lib/features/icu/domain/entities/icu_entities.dart`
- `frontend/lib/features/icu/presentation/controllers/icu_workspace_controller.dart`
- `frontend/lib/features/icu/presentation/widgets/icu_board_panel.dart`
- `frontend/lib/features/icu/presentation/widgets/icu_board_columns.dart`
- `frontend/lib/features/icu/presentation/widgets/icu_board_filters.dart`
- `frontend/lib/features/icu/presentation/widgets/icu_bed_board_panel.dart`
- `frontend/lib/features/icu/presentation/widgets/icu_detail_panel.dart`
- `frontend/lib/features/icu/presentation/widgets/icu_action_dialogs.dart`
- `frontend/lib/features/icu/presentation/widgets/icu_next_action_button.dart`
- `frontend/test/features/icu/`
