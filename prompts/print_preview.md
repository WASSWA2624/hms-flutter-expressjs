# Print preview dialog: denser layout and flexible preview pane

Refine the shared print-preview workspace so the dialog feels tight, the preview uses the full dialog height, and pane-mode switching uses `AppTabStrip`. Fix the Flutter layout overflow (`BOTTOM OVERFLOWED BY … PIXELS`) visible in the radiology print dialog. Preview chrome (zoom toolbar + document) must scroll together as one pane.

## Context

- Shared surface: `frontend/lib/shared/printing/app_print_preview.dart`
  - `AppPrintPreviewWorkspace` — two-column layout + pane mode bar
  - `AppPrintPreviewPaneModeBar` — icon button row for Split / Sections / Preview
  - `AppPrintPreviewPanel` — wraps `AppReportPreviewPanel` + zoom toolbar + HTML preview
  - `AppPrintPreviewToolbar` — zoom / fit controls
- Preview chrome wrapper: `AppReportPreviewPanel` in `frontend/lib/shared/components/app_report_actions.dart` (title row + maximize header actions)
- Tab strip to reuse: `AppTabStrip` in `frontend/lib/shared/components/app_tab_strip.dart`
- Call sites (apply shared changes once; verify at least radiology + lab):
  - `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.print.dart`
  - `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart`
  - other `AppPrintPreviewWorkspace` / `AppPrintPreviewPanel` consumers
- Current pain (see screenshot of **PRINT RADIOLOGY REPORT**):
  - Pane mode is three icon buttons (`AppPrintPreviewPaneModeBar`), not the app tab strip.
  - Dialog body has excess outer padding / margin — large empty frame around the workspace.
  - Preview column is short: “Print preview” title + Maximize sit above a separate zoom toolbar, then a clipped document area that shows **BOTTOM OVERFLOWED BY 45 PIXELS**.
  - Preview does not fill dialog height (header → actions footer).
  - Pane-mode controls sit on a full-width row above both columns; they should live with the **sections** column only.
  - Maximize-preview control in the preview header is redundant with dialog fullscreen / toolbar maximize — remove that header strip.
- Follow `.cursor/locale-development.mdc`, `.cursor/mandatories.mdc`, `frontend/.cursor/ui-feedback.mdc`, and existing `AppDialog` / `AppTabStrip` patterns.

## Requirements

1. **Pane mode → `AppTabStrip`:** Replace `AppPrintPreviewPaneModeBar` (or reimplement it) so Split / Sections only / Preview only use `AppTabStrip` (labels + selection semantics matching existing l10n: split / sections / preview). Prefer `AppTabStripVariant.nested` if that matches other subordinate strips in dialogs. Keep the same `AppPrintPreviewPaneMode` enum and `onPaneModeChanged` contract.

2. **Tab strip width = sections column only:** Place the tab strip inside / above the **sections** pane, not as a full-width row spanning sections + preview. When sections are hidden (preview-only mode), hide the strip or show a minimal equivalent only if needed for switching back — prefer a compact control that still lets the user return to split/sections without reclaiming a full header band across the preview.

3. **Remove excess dialog padding:** Tighten `AppDialog` / workspace padding so the content hugs the dialog chrome (title bar and Close/Print actions). Prefer `contentPadding: EdgeInsets.zero` (or the smallest spacing token already used by dense dialogs) on print dialogs; remove double padding between dialog content and `_ScrollPane` borders. Do not leave a large empty gutter around the workspace.

4. **Preview fills dialog height:** In split and preview-only modes, the preview column must stretch from just under the dialog title to just above the dialog actions. Drive height from available constraints (`Expanded` / `LayoutBuilder`), not a short fixed `height: 420`-style body that leaves unused vertical space. Sections column should match that full height.

5. **Remove the “Print preview” header strip:** Drop the `AppReportPreviewPanel` title row (“Print preview”) and its maximize header action from this surface. Do not show “Maximize preview” as a labeled header control above the zoom toolbar. If maximize/restore remains useful, keep it only as an icon on the zoom toolbar (`AppPrintPreviewToolbar.showMaximize`) or rely on the dialog’s own fullscreen control — not both stacked headers.

6. **One scrollable preview section (toolbar + document):** The zoom toolbar and the HTML document must live in **one** scrollable preview pane. Scrolling the preview scrolls the toolbar away with the content (whole section scrolls together). Do not pin the toolbar while only the iframe/document scrolls inside a fixed clipped box that overflows. Fix the **BOTTOM OVERFLOWED** layout error — preview children must respect parent constraints (no unbounded `Column`/`Expanded` mismatch).

7. **Flexible, user-friendly preview:** Preview pane should grow with available space (`flex` / `Expanded`), remain readable at default zoom, and stay usable when the user switches pane modes or resizes/fullscreen the dialog. Avoid nested scroll views that fight each other (dialog scroll + pane scroll + iframe scroll). Keep `AppDialog(scrollable: false)` and let the panes own scrolling.

8. **Preserve behavior:** Zoom in/out/step/fit, section checkboxes, print/close actions, HTML fallback, and pane-mode visibility rules stay intact. Do not redesign section picker content or print HTML templates in this prompt.

9. **l10n + tests:** Reuse existing print-preview l10n keys for tab labels where possible; add keys only if tab strip needs text labels the icon bar lacked. Update `frontend/test/shared/printing/app_print_preview_test.dart` (and call-site tests if they assert on `AppPrintPreviewPaneModeBar` / “Print preview” title / maximize header). Assert: no overflow in workspace layout tests; tab strip drives pane mode; preview has no title header; toolbar scrolls with preview content.

Optional enhancements: none (do not restyle printed HTML, section checkbox grid, or dialog action buttons beyond padding/height needed for this layout).

## Out of scope

- Print template / HTML document design (`print_form_template`, sample PDFs).
- New print section types or radiology/lab clinical fields.
- Changing dialog title strings (“PRINT RADIOLOGY REPORT”, etc.) except if a shared print-dialog shell is touched for padding only.
