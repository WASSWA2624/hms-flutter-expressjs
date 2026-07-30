# Polish Lab Result Entry Dialog UI

## Goal

Tighten the lab result entry dialog by removing actions the lab technician cannot use, making result status visually obvious, and standardizing the patient header on `AppWorkspaceDetailPanel` as a collapsible section.

## Remove from this dialog

1. **Lab order section** — Remove the "Lab order LAB..." block with ordered-at, **Edit order**, and **Delete order** actions. Lab technicians do not edit or delete orders from the result entry screen. Keep the test entry and panel content; no order meta panel should appear above the results panels.
2. **Create Lab Order** footer button — Remove this button from the dialog footer. Result entry is not an order creation surface.

## Footer actions

Retain only:

| Action               | Behavior |
|----------------------|----------|
| **Preview report**   | Unchanged |
| **Save results**     | Always visible. **Enabled** once at least one result is entered. The button should remain visible but inactive (disabled) when nothing is entered yet. Payment status (unpaid, partial, etc.) must NOT block entry or saving. |

## Color-code entered results

Color-code results (both before and after save) for quick recognition based on their interpretation against the reference range:

| Interpretation        | Visual treatment                   |
|-----------------------|------------------------------------|
| Normal / in range     | Neutral or success tone            |
| Low / below range     | Distinct "low" tone (e.g., warning/info) |
| High / above range    | Distinct "high" / abnormal tone    |
| Critical              | Strong error / critical tone       |

Apply the color to the result value presentation (and row accent if already used), not just after saving. Reuse the existing flag/interpreter logic where possible (`NORMAL`, `ABNORMAL`, `CRITICAL`, low/high flags).

## Patient header → `AppWorkspaceDetailPanel` (standardized)

Replace the existing patient context header (with "Show less"/"Show more") with a standardized `AppWorkspaceDetailPanel`, implemented as a collapsible section component:

- **Header:** Show patient display name and a copyable patient ID (e.g., `Wilson Wasswa · PAT0000001`). The patient ID should be clearly presented and copy-enabled within the header.
- **Body:** Display additional patient context details (encounter info, status, order summary) in the panel body as needed, rather than crowding the header.
- **Collapsibility:** This section uses the collapsible section component. It may be expanded or collapsed if that matches UI policy, but the header format (name + ID, with ID copyable) and detail placement must follow this guidance.

Other collapsible `AppWorkspaceDetailPanel` usage (such as for panels and single-test blocks) remains unchanged.

## Acceptance criteria

- No Edit order / Delete order or Lab order meta section in result entry.
- No Create Lab Order button in the dialog footer.
- Save results is always visible, inactive until there are results to save, and never blocked by payment status.
- Entered values are color-coded according to normal, low, high, and critical reference ranges.
- Patient block uses `AppWorkspaceDetailPanel` implemented as a standardized collapsible section with name and copyable ID in the header, and other details in the body.
