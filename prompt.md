# Fix: Pharmacy "Catalog and stock" dialog not rendering

## Problem
On the Pharmacy screen, clicking the **Catalog and stock** button does not show its dialog. Instead the screen becomes inactive/unresponsive, as if the modal is mounted but invisible or an overlay is blocking interaction.

## Required changes
1. **Fix the Catalog and stock dialog** so it opens and renders correctly, matching the behavior of the other dialogs in the app that already display properly (use those working dialogs as the reference implementation/pattern).
2. **Remove the "Storage layout" action** from the "more actions" (⋮) menu, along with its now-unused dialog/handler code.
3. **Audit all other dialogs in the Pharmacy module** — including nested/child dialogs — for the same rendering/overlay defect and fix any found.

## Acceptance criteria
- Clicking **Catalog and stock** opens a fully visible, interactive modal; the underlying screen is properly dimmed and dismiss works as expected.
- The **Storage layout** menu item and its dead code are gone.
- Every Pharmacy dialog (top-level and nested) opens and renders correctly.
- No leftover invisible overlays block the screen after a dialog closes.
