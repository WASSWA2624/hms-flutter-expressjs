# Simplify Add Diagnosis Transfer UX

Polish `ClinicalDiagnosisActionDialog` for simpler transfer UX: matched toolbar heights, searchable selected pane, clearer action labels, row-click toggle, no name-column sort chrome, and a more compact diagnosis-type row. Inventory: `screens/clinical.md`. Follow `prompts/.cursor/prompt.mdc`.

## Context

Opened from `/clinical` encounter **Add diagnosis**. Density improved, but: transfer action height does not match the search field; selected pane shows **N selected** without search and places **Deselect** outside search chrome; Name column still shows sort affordance; checking a diagnosis requires the checkbox only; action labels (**Add selections** / **Deselect**) are unclear; diagnosis-type radios still consume excess vertical space. Keep the two-pane transfer model and submit flow.

**Row-click toggle:** clicking the diagnosis name/row (not only the checkbox) toggles that row’s checked state on the same pane.

## Requirements

1. Match available-pane transfer action height to the dense search field so search and action share one compact toolbar row.
2. Relabel available transfer action to **Add selected diagnosis** (keep `+` / add icon).
3. On the selected pane, replace the **N selected** count chrome with a dense search field that filters the selected list client-side; place **Remove selected diagnosis** as the search-row trailing action (same pattern as available).
4. Relabel the selected transfer action from **Deselect** to **Remove selected diagnosis** (keep remove icon).
5. Remove Name-column sort affordance/chrome on both panes (no sort arrow or sort underline); keep name + subtitle display.
6. Enable row-click toggle on both panes: clicking the diagnosis content toggles the row checkbox; checkbox clicks keep working; multi-check then transfer unchanged.
7. Compact the diagnosis-type block (Primary / Secondary / Differential): reduce vertical gap/padding so it is a single tight control row while staying borderless and readable.
8. Keep overall chrome simple: no new panels, titles, or match-count banners; preserve Cancel / **Add diagnosis**, default Primary, catalog search/load/retry, transfer rules, caller write gate, loading/empty/error/success, theme tokens, and responsive stacking.

## Constraints

- Reuse `ClinicalDiagnosisActionDialog`, `AppListTable`, `AppTextField`, and theme tokens; extend shared pieces only if required for equal toolbar height, disabling name sort, or row-click toggle.
- No diagnosis-type semantics, catalog source, or submit-contract changes; no unrelated clinical refactors.
- Unauthorized UI remains absent via the existing caller write gate.

## Acceptance Criteria

- Available search and **Add selected diagnosis** share equal toolbar height (1–2).
- Selected pane has dense search + **Remove selected diagnosis**; **N selected** is gone (3–4).
- Name columns show no sort affordance (5).
- Clicking diagnosis text/row toggles check on both panes; transfer still multi-select (6).
- Diagnosis-type row uses less vertical space and stays borderless (7).
- Dialog remains simple; submit/empty/error/retry/success still work (8).
- Update dialog tests for new labels, selected search, row-click toggle, and absent sort chrome; manually verify light/dark on mobile, tablet, and desktop.

## Relevant Files

- `frontend/lib/shared/clinical_actions/dialogs/clinical_diagnosis_action_dialog.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_text_field.dart`
- `frontend/lib/l10n/app_en.arb`
- `screens/clinical.md`
- `frontend/test/shared/clinical_actions/clinical_diagnosis_action_dialog_test.dart`
