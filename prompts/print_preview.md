# Print preview toolbar: page chrome + maximize document area

Refine the shared App print-preview chrome so zoom/page controls sit under the pane-mode tabs (not inside the document pane), and so multi-page documents expose current/total page navigation. Goal: give the HTML preview the maximum vertical space while making page position obvious.

## Current status (screenshot baseline)

Radiology (and other sectioned dialogs) show `AppPrintPreviewWorkspace` in split view:

- Pane tabs: **Split view** | **Sections** | **Preview**
- Left: section checklist tiles
- Right: `AppPrintPreviewPanel` with its own toolbar **inside** the bordered preview pane (zoom out, decrease, percent, increase, zoom in, fit, maximize), then the HTML document below
- Footer: Close / Print

Problems visible today:

1. **Toolbar steals preview height** — zoom controls live inside the preview pane above the document, shrinking the readable area (especially at ~149% zoom where content already clips horizontally).
2. **No page chrome** — toolbar has zoom/fit/maximize only. There is no current page / total pages indicator and no previous/next page controls when the document has more than one page.

Do **not** restyle printed HTML templates, section tiles, or dialog titles in this pass.

## Context

Shared preview stack:

- `frontend/lib/shared/printing/app_print_preview.dart`
  - `AppPrintPreviewToolbar` — zoom out / decrease / percent / increase / zoom in / fit / maximize
  - `AppPrintPreviewPanel` — currently hosts the toolbar **above** the HTML document inside the preview chrome
  - `AppPrintPreviewPaneModeBar` — Split / Sections / Preview tabs
  - `AppPrintPreviewWorkspace` — today puts the mode strip on the **sections** column only (or compact strip when sections are hidden); preview column embeds the full panel including toolbar
  - `showAppPrintPreviewDialog` — simple preview dialog using `AppPrintPreviewPanel`
- HTML / paging: `PrintFormTemplate` / `buildPrintFormTemplateHtml` (`print_form_template.dart`) already emits multi-page articles (`print-template-page`, `Page N of M` in print footer when explicit pages are used)
- Preview render: `AppPrintHtmlPreview` / web impl scales the whole HTML; page navigation must scroll/focus the corresponding page in the preview, not invent a second print engine

Reference UX from the attached radiology print dialog; apply the chrome change **once** in shared widgets so radiology, lab, OPD, patient chart, nursing, and `showAppPrintPreviewDialog` all pick it up.

Follow `.cursor/locale-development.mdc`, `.cursor/mandatories.mdc`, `frontend/.cursor/ui-feedback.mdc`, and existing `AppDialog` / print-preview patterns. Routing work in `prompts/print_preview_refactor.md` is separate — do not redo print-entry migration here.

## Requirements

1. **Relocate chrome under the tabs**
   - Move zoom / fit / maximize (and the new page controls) out of the interior of the preview document pane.
   - Place them in a shared strip **directly under** the pane-mode tabs (`AppPrintPreviewPaneModeBar`), so they remain visible in split, sections+return, and preview-only modes as appropriate.
   - Preferred layout for workspace:
     - Row/column 1: pane-mode tabs
     - Row/column 2: print toolbar (zoom + page + maximize)
     - Below: sections and/or document preview **without** a second nested toolbar
   - For `showAppPrintPreviewDialog` (no pane tabs): keep a single toolbar above the document, still outside any scroll that would hide it under content; maximize document height the same way.
   - After the move, `AppPrintPreviewPanel` should render primarily as the document surface (optional: `toolbarEnabled: false` when the parent owns the strip).

2. **Add page numbers and page navigation**
   - Extend the shared toolbar with:
     - Previous page / Next page actions
     - A clear current/total label (e.g. `Page {current} of {total}` via l10n)
   - Wire page state into workspace / simple dialog callers that already know page count from template HTML or an explicit `pageCount` / page-anchor API.
   - Behavior:
     - Single-page docs: show `Page 1 of 1` (or hide prev/next as disabled); do not invent fake pages
     - Multi-page docs: prev/next updates current page and scrolls/focuses that page in the HTML preview
     - Clamp current page to `1…total`; disable prev on first / next on last
   - Prefer detecting pages from existing `.print-template-page` structure in the preview HTML rather than duplicating paging logic in each feature dialog.
   - Do not confuse the small **section tile badges** (item counts in the checklist) with print page numbers.

3. **Maximize preview document area**
   - Removing the in-pane toolbar must reclaim vertical space for the HTML preview.
   - Preview pane border/chrome may remain; avoid stacking duplicate bordered toolbars.
   - Default zoom / fit behavior may stay as-is unless the relocated chrome makes fit-to-width obviously wrong — do not chase unrelated zoom defaults in this pass.

4. **Shared API, all call sites**
   - Update `AppPrintPreviewToolbar`, `AppPrintPreviewPanel`, `AppPrintPreviewWorkspace`, and `showAppPrintPreviewDialog` so feature dialogs that only pass `preview:` / scale callbacks keep working.
   - Propagate optional page callbacks (`onPagePrevious`, `onPageNext`, `currentPage`, `pageCount`) with sensible defaults when page metadata is unavailable (`pageCount <= 1`).
   - Do not fork a radiology-only toolbar.

5. **l10n + a11y + tests**
   - Add ARB keys for page label and prev/next actions (and tooltips/semantics). Run l10n generation per locale-development rules.
   - Update/extend `frontend/test/shared/printing/app_print_preview_test.dart` (and any workspace/dialog tests) to assert:
     - Toolbar is not nested inside the scrolling document body in workspace mode (or `toolbarEnabled` is false on the panel when parent owns chrome)
     - Page label / prev/next appear when `pageCount > 1`
     - Prev/next invoke callbacks and respect first/last bounds
   - Keep existing zoom/fit/maximize coverage green.

## Constraints

- Scope is **shared print-preview chrome** only (`app_print_preview.dart` + tests + l10n). Do not redesign section pickers, printed HTML CSS, sample PDFs, or print routing.
- Do not change Print / Close footer behavior, permissions, or `showPreview: false` contracts.
- Stay on existing theme spacing, `AppButton` icon-only patterns, and responsive workspace breakpoints.
- Avoid unrelated refactors; no new markdown docs beyond this prompt file.

## Acceptance Criteria

- [ ] AC1 (Req 1): In split view (radiology-style), zoom/fit/maximize live under the pane tabs, not as a second bar inside the preview document pane; preview document height is larger than the pre-change layout for the same dialog size.
- [ ] AC2 (Req 1): Preview-only mode and simple `showAppPrintPreviewDialog` still expose the same zoom/fit/maximize controls without losing maximize.
- [ ] AC3 (Req 2): Multi-page preview shows current/total page and working prev/next that move the preview to that page; single-page shows honest `1 of 1` (or disabled nav) without errors.
- [ ] AC4 (Req 4): Radiology, lab, OPD, patient-chart, nursing, and simple template preview dialogs all inherit the chrome change without per-feature toolbar forks.
- [ ] AC5 (Req 5): New strings are localized; widget tests cover toolbar placement and page navigation; existing print-preview tests pass.
- [ ] AC6: Manual check on radiology print dialog — tabs → toolbar → maximized preview; page controls visible when document has multiple pages.

## Relevant Files

- `frontend/lib/shared/printing/app_print_preview.dart`
- `frontend/lib/shared/printing/app_print_html_preview.dart` (+ web/stub if page scroll needs a hook)
- `frontend/lib/shared/printing/print_form_template.dart` (page structure reference only)
- Feature dialogs that embed `AppPrintPreviewWorkspace` / `AppPrintPreviewPanel` (radiology, lab, OPD, nursing, patient registry) — only if constructor/callback wiring must be updated
- `frontend/lib/l10n/app_en.arb` (+ generated l10n)
- `frontend/test/shared/printing/app_print_preview_test.dart`
- Related feature print dialog tests if they assert toolbar ancestry

## Optional (out of scope unless trivial)

- Changing default zoom so the first paint fits width
- Horizontal clipping of wide tables inside printed HTML
- Restyling section checklist density / “No data available” tiles
