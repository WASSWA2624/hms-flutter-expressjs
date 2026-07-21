# Compact Reception Mobile List Rows

Replace bulky Reception mobile cards—including Follow-ups—with a dense list layout; keep the wide-viewport table. Follow `prompts/.cursor/prompt.mdc`.

## Context

`AppListTable` shows a table on wide screens and `mobileItemBuilder` on phones. `_ReceptionDeskMobileRow` stacks fields with large padding, so few rows fit. Desktop columns are fine.

**Compact mobile row:** one dense selectable row; patient identity plus section-critical fields; minimal vertical chrome.

## Requirements

1. Keep the adaptive table on wide screens; change only the narrow list.
2. Redesign Reception mobile rows (all desk sections, including Follow-ups) into compact items: identity first; key fields on one secondary line—not tall labeled stacks.
3. Follow-ups: name/ID, phone when present, scheduled date·time, and notes snippet when present.
4. Preserve single tap/keyboard activation to the existing detail dialog; no nested duplicate targets.
5. Reuse `AppListItemText` / design-system list primitives and theme tokens; avoid height-only card chrome.
6. Preserve loading, empty, error, success, search/filter parity, permissions; omit unauthorized UI.

## Constraints

- Reuse `AppListTable`, row mapping, localization, auth; no new contracts.
- Do not change desktop columns, sorting, or follow-up rules.
- Support themes and phone/tablet/desktop widths.

## Acceptance Criteria

- R1–R2: Wide = table; narrow = denser list than today.
- R3: Follow-ups mobile rows show listed fields when available.
- R4: Activation opens the correct dialog once.
- R5–R6: Tokens/states intact; unauthorized UI absent.
- Update reception mobile-list tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/shared/components/{app_list_table,app_list_item_text}.dart`
- `frontend/test/features/reception/`
- `frontend/test/shared/components/app_list_table_test.dart`
