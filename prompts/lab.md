# Improve Lab Result Entry Dialog

## Goal

Redesign the lab result entry dialog so it is clean, full-width, and focused on entering/saving results. Remove cluttered chrome, unused columns, and workflow UI that does not belong in this screen.

## Dialog chrome

- **Restore** and **Close** must not show visible labels on both small and large screens.
- Keep Preview report / Save (and Create when relevant) in the footer actions with clear labels.

## Remove from this dialog

1. **Workflow progress section** (`LabWorkflowProgressSection`) — remove entirely from result entry.
2. **Bulk selection bar** — remove Select all, Clear selection, and Reject all. Bulk reject is not part of this flow.
3. **Flag column** — remove. Reference ranges already convey abnormality; no separate Flag / Manual interpretation column is needed in the entry table.
4. **Action column** — remove per-row action column (Reject test, etc.). Actions allowed in this dialog are only: enter/edit results, save, and delete panel (where allowed).

## Layout: one collapsible block per order unit

Every lab order unit must live in its **own collapsible panel** that spans the **full dialog width** (no inset “nested card” feel):

| Order unit | Collapsible block |
|---|---|
| Panel (e.g. CBC) | One collapsible for the whole panel |
| Single test | One collapsible for that test |

Inside each collapsible:

- Title for the panel/test.
- **Delete panel** control on the panel header when the unit is a panel (allowed). Place it clearly in the header actions.
- Result entry content that uses the full width of the panel.

### Delete rules

- **Panels:** user may delete the **entire panel**.
- **Panel child tests:** user must **not** delete individual tests from a panel.
- **Results:** do not offer “delete result” as a primary destructive path for panel members; editing/clearing values before save is fine.

## Result entry fields

Improve the Result area (value, unit, notes) so it is readable and not cramped/overlapping:

- Value, unit, and optional notes laid out cleanly (stack on narrow widths).
- No overflow, no overlapping Clear/unit controls.
- Keep dense but usable inputs suitable for table or stacked rows inside the full-width collapsible.

## Reference ranges and patient gender

When showing reference ranges for a test:

- Use the **patient’s known gender** (and age if already available in context) to choose/filter the correct range.
- Do not show an irrelevant gender’s range as the primary range when gender is known.
- If no gender-matched range exists, fall back clearly (e.g. general/unspecified range) rather than inventing data.

## Save behavior (partial saves allowed)

- Primary action: **Save results**.
- On save, saved values become **immediately visible** to the ordering clinician / patient record.
- Saving must **not** require every test in a panel (or every item on the order) to be filled.
- Partial panel saves are allowed: one or more results can be saved while others remain empty; empty items must not block publishing the ones that were entered.

## Acceptance criteria

- Restore and Close always show text labels.
- No workflow stepper, Select all / Clear selection / Reject all, Flag column, or per-row Action column in result entry.
- Each panel and each standalone test is its own full-width collapsible; panel header has Delete panel when allowed.
- Individual tests inside a panel cannot be deleted from this dialog.
- Reference ranges respect patient gender when available.
- Save publishes entered results immediately, including partial panel results.
