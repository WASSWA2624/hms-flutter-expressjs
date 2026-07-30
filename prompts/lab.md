# Polish Lab Result Entry Dialog UI

## Goal

Tighten the lab result entry dialog: remove actions the lab technician cannot use, make result status visually obvious, and standardize the patient header on `AppWorkspaceDetailPanel`.

## Remove from this dialog

1. **Lab order section** — Remove the “Lab order LAB…” block that shows ordered-at plus **Edit order** / **Delete order**. Lab technicians do not edit or delete orders from result entry. Keep panel/test entry content; do not require an order meta panel above the panels.
2. **Create Lab Order** footer button — Remove it from this dialog. Result entry is not an order-creation surface.

## Footer actions

Keep only:

| Action | Behavior |
|---|---|
| **Preview report** | Unchanged |
| **Save results** | Always visible. **Enabled** only when at least one result has been entered (and payment gate allows). **Disabled/inactive** when nothing is entered yet — do not hide the button. |

## Color-code entered results

When a result value is entered (before and after save), style it for quick recognition against the applicable reference range:

| Interpretation | Visual treatment |
|---|---|
| Normal / in range | Neutral / success tone |
| Low / below range | Distinct “low” tone (e.g. warning/info) |
| High / above range | Distinct “high” / abnormal tone |
| Critical | Strong error / critical tone |

Apply color to the result value display (and row accent if already used), not only after save. Reuse existing interpretation/flag logic where possible (`NORMAL` / `ABNORMAL` / `CRITICAL`, low/high flags).

## Patient header → `AppWorkspaceDetailPanel`

Replace the current patient context header (with **Show less** / **Show more**) with `AppWorkspaceDetailPanel`:

- **Title:** patient display name + patient ID (e.g. `Wilson Wasswa · PAT0000001`).
- **Body:** remaining context (encounter, status/order summary, etc.) — not crammed into the title.
- **Not collapsible:** no Show less / Show more / expand chevron on this patient section (`collapsible: false`).

Keep panel and single-test blocks as collapsible `AppWorkspaceDetailPanel`s (unchanged from prior redesign).

## Acceptance criteria

- No Edit order / Delete order / Lab order meta section in result entry.
- No Create Lab Order button in the dialog footer.
- Save results is always shown; inactive until there is something to save.
- Entered values are color-coded by normal / low / high / critical against the reference range.
- Patient block uses `AppWorkspaceDetailPanel` with name + ID in the title, details in the body, and no collapse control.
