# Compact Reception Mobile List Rows

Deliver 10 sample mobile-list photos, then replace bulky Reception mobile cards—including Follow-ups—with the chosen dense layout; keep the wide-viewport table. Follow `prompts/.cursor/prompt.mdc`.

## Context

`AppListTable` shows a table on wide screens and `mobileItemBuilder` on phones. `_ReceptionDeskMobileRow` stacks fields with large padding, so few rows fit. Desktop columns are fine.

**Compact mobile row:** one dense selectable row; patient identity plus section-critical fields; minimal vertical chrome.

**Sample photos:** ten distinct phone-frame mockups of Follow-ups list items so a layout can be chosen before coding.

## Requirements

1. Create **10 unique sample photos** of compact Follow-ups mobile rows showing patient name/ID, phone, date, and time; vary density, alignment, meta layout, and chrome—not ten near-duplicates.
2. Keep the adaptive table on wide screens; change only the narrow list after a sample is chosen.
3. Redesign Reception mobile rows (all desk sections, including Follow-ups) into compact items: identity first; key fields on one secondary line—not tall labeled stacks.
4. Follow-ups: name/ID, phone when present, scheduled date·time, and notes snippet when present.
5. Preserve single tap/keyboard activation to the existing detail dialog; no nested duplicate targets.
6. Reuse `AppListItemText` / design-system list primitives and theme tokens; avoid height-only card chrome.
7. Preserve loading, empty, error, success, search/filter parity, permissions; omit unauthorized UI.

## Constraints

- Reuse `AppListTable`, row mapping, localization, auth; no new contracts.
- Do not change desktop columns, sorting, or follow-up rules.
- Support themes and phone/tablet/desktop widths.

## Acceptance Criteria

- R1: Ten distinct sample photos of compact Follow-ups mobile rows are delivered for selection.
- R2–R3: Wide = table; narrow = denser list than today after implementation.
- R4: Follow-ups mobile rows show listed fields when available.
- R5: Activation opens the correct dialog once.
- R6–R7: Tokens/states intact; unauthorized UI absent.
- Update reception mobile-list tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/shared/components/{app_list_table,app_list_item_text}.dart`
- `frontend/test/features/reception/`
- `frontend/test/shared/components/app_list_table_test.dart`
