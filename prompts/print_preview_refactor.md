# Route every print flow through App print preview

Perform a **complete** frontend scan (not a surface pass) of every print button, print action, inventory print entry, and print helper. Refactor any flow that prints HTML without first showing the shared App print-preview surface so the user always previews before the browser/OS print dialog.

## Context

Shared printing stack:

- Preview UI: `frontend/lib/shared/printing/app_print_preview.dart`
  - `AppPrintPreviewPanel` — zoom toolbar + HTML document
  - `AppPrintPreviewWorkspace` — sections + preview panes + pane-mode tabs
  - `showAppPrintPreviewDialog` — standard simple preview dialog (panel + Close/Print)
- HTML build + branded chrome: `PrintFormTemplate` / `buildPrintFormTemplateHtml` via `print_form_template_context.dart`
- Typed product entry points: `PrintDocumentTemplates` in `frontend/lib/shared/printing/templates/print_document_templates.dart`
  - Default: `showPreview: true` → opens `showAppPrintPreviewDialog`, then prints
  - `showPreview: false` is allowed **only** when the caller already embeds `AppPrintPreviewPanel` / `AppPrintPreviewWorkspace`
- Actual print: `printFormTemplateDocument` → `printHtmlDocument` (`frontend/lib/core/platform/app_print*.dart`). That path must never be the first user-visible step for a print action.

**Valid patterns (keep both):**

1. **Simple:** `PrintDocumentTemplates.*(…)` with default `showPreview: true` (or call `showAppPrintPreviewDialog` then print).
2. **Sectioned / custom dialog:** Own `AppDialog` that embeds `AppPrintPreviewWorkspace` or `AppPrintPreviewPanel`, then `PrintDocumentTemplates.*(…, showPreview: false)` on confirm.

**Invalid:** Any UI path that reaches `printFormTemplateDocument` / `printHtmlDocument` without an App preview dialog/panel already shown for that action.

Known call sites to include in the audit (verify each end-to-end):

| Surface | Entry | Preview today |
| --- | --- | --- |
| Radiology | `radiology_workspace_page.print.dart` | Custom `AppPrintPreviewWorkspace` (`showPreview: false`) |
| Lab | `lab_result_entry_dialog.dart` | Custom `AppPrintPreviewWorkspace` (`showPreview: false`) |
| OPD | `opd_print_summary_dialog.dart` | Custom `AppPrintPreviewWorkspace` (`showPreview: false`) |
| Patients chart | `patient_registry_page.dart` | Custom `AppPrintPreviewWorkspace` (`showPreview: false`) |
| Nursing | `nursing_print_summary_dialog.dart` | Custom `AppPrintPreviewPanel` only (`showPreview: false`) |
| Clinical | `clinical_workspace_page.dart` | `PrintDocumentTemplates.clinicalSummary` (default preview) |
| Billing | `billing_invoice_print_helpers.dart` | `PrintDocumentTemplates.invoice` (default preview) |
| Pharmacy | `pharmacy_workspace_page.dart` | `PrintDocumentTemplates.medicationInstructions` (default preview) |
| Physiotherapy | `physiotherapy_workspace_page.dart` | `PrintDocumentTemplates.carePlan` (default preview) |
| Claims | `claims_workspace_page.dart` | `PrintDocumentTemplates.claimStatement` (default preview) |
| Reports | `reports_workspace_page.dart` | `PrintDocumentTemplates.registry` (default preview) |
| Biomedical | `biomedical_workspace_page.dart` | `PrintDocumentTemplates.registry` (default preview) |
| Mortuary | `mortuary_workspace_page.dart` | `PrintDocumentTemplates.mortuaryCase` (default preview) |
| Emergency | `emergency_workspace_widgets.dart` | `PrintDocumentTemplates.clinicalSummary` (default preview) |
| ICU | `icu_detail_panel.dart` | `PrintDocumentTemplates.clinicalSummary` (default preview) |
| Discharge | `discharge_workspace_page.dart` | `PrintDocumentTemplates.clinicalSummary` (default preview) |

Also scan for stragglers via: `AppReportActionButton.print`, `AppActionIcons.print` / `Icons.print_outlined`, `PrintDocumentTemplates.`, `showAppPrintPreviewDialog`, `printFormTemplateDocument`, `printHtmlDocument`, `showPreview: false`, and l10n `*Print*` action handlers. Do not treat billing-inventory label strings alone as print flows—follow the wired `onPressed` / helper.

Follow `.cursor/locale-development.mdc`, `.cursor/mandatories.mdc`, `frontend/.cursor/ui-feedback.mdc`, and existing `AppDialog` / print-preview patterns. Related layout polish lives in `prompts/print_preview.md` (do not redo that work here unless a migrated dialog regresses).

## Requirements

1. **Complete inventory:** Produce (in the PR/commit description or a short comment in the change summary—not a new markdown inventory folder) a checklist of every user-facing print entry found. Mark each as already-compliant, migrated, or intentionally non-HTML (if any). No feature module may be skipped because it “probably already uses templates.”

2. **No preview bypass:** Ensure every HTML print action shows App preview before `printHtmlDocument`. Forbid new or remaining direct calls to `printFormTemplateDocument` / `printHtmlDocument` from feature UI. Keep `printFormTemplateDocument` as the shared print executor used only after preview confirm (via `PrintDocumentTemplates` or equivalent).

3. **Prefer shared entry points:** New or fixed simple prints must go through `PrintDocumentTemplates.*` (default preview) or `showAppPrintPreviewDialog`. Do not invent parallel preview dialogs. Custom section pickers must reuse `AppPrintPreviewWorkspace` + `AppPrintPreviewPanel`.

4. **Normalize `showPreview: false`:** Keep `showPreview: false` only where a custom dialog already embeds preview. If a caller sets `showPreview: false` without embedding preview, switch to default preview or embed the shared panel/workspace.

5. **Nursing alignment:** Bring nursing print summary onto the same preview contract as other dialogs (at minimum keep `AppPrintPreviewPanel`; prefer sharing `showAppPrintPreviewDialog` if sections are not needed). Do not leave a one-off zoom/print dialog that drifts from shared chrome.

6. **Preserve sectioned flows:** Do not flatten radiology, lab, OPD, or patient-chart section pickers into the simple dialog. They must keep `AppPrintPreviewWorkspace` and continue using `showPreview: false` only for the final print step.

7. **Honest gating + feedback:** Keep existing print permission / eligibility gates. Omit unauthorized print controls (do not show disabled “no access” print buttons). Keep print busy/loading on the Print action; Close/Cancel disabled while printing; errors surfaced via existing UI feedback.

8. **l10n + tests:** Reuse existing print-preview and feature print strings. Add keys only for new user-visible copy. Update/add widget tests so: (a) representative simple flows open `showAppPrintPreviewDialog` / `AppPrintPreviewPanel` before print; (b) `showPreview: false` call sites still mount preview UI; (c) no feature test asserts direct print-without-preview. Extend `frontend/test/shared/printing/` and affected feature tests as needed.

Optional enhancements: none (do not restyle printed HTML templates, redesign section checkbox grids, or change dialog titles beyond what migration requires).

## Constraints

- Scope is frontend print **routing** and preview consistency, not print HTML/PDF visual redesign (`print_form_template`, sample PDFs, `print_templates/`).
- Do not add print to modules that have no print product action today (IPD, theater, reception, etc.).
- Do not change backend print APIs or permissions models; reuse existing authorization checks.
- Do not bypass `PrintDocumentTemplates` by calling `printFormTemplateDocument` from features.
- Avoid unrelated refactors outside print entry wiring and shared preview reuse.
- Stay under existing responsive/theme/`AppDialog` contracts; migrated dialogs must not clip or overflow on mobile/tablet/desktop.

## Acceptance Criteria

- [ ] AC1 (Req 1): Audit covers every print entry found by the search patterns above; each is classified compliant / migrated / non-applicable.
- [ ] AC2 (Req 2–4): No feature UI path invokes `printHtmlDocument` / `printFormTemplateDocument` without an App print-preview surface already shown for that action.
- [ ] AC3 (Req 3, 5–6): Simple prints use `PrintDocumentTemplates` default preview or `showAppPrintPreviewDialog`; sectioned prints still use `AppPrintPreviewWorkspace`; nursing uses shared preview chrome.
- [ ] AC4 (Req 7): Unauthorized print controls remain omitted; print loading/error/success behavior is preserved.
- [ ] AC5 (Req 8): Tests fail if a covered flow prints without mounting preview UI; existing preview layout tests still pass.
- [ ] AC6: Manual spot-check of at least one simple flow (e.g. billing/clinical) and one sectioned flow (e.g. radiology/lab) shows preview dialog/panel before the browser print dialog.

## Relevant Files

- `frontend/lib/shared/printing/app_print_preview.dart`
- `frontend/lib/shared/printing/templates/print_document_templates.dart`
- `frontend/lib/shared/printing/printing.dart`
- `frontend/lib/app/printing/print_form_template_context.dart`
- `frontend/lib/core/platform/app_print.dart` (+ web/stub)
- `frontend/lib/shared/components/app_report_actions.dart` (`AppReportActionButton.print`)
- Feature call sites in the Context table
- `frontend/test/shared/printing/app_print_preview_test.dart`
- `frontend/test/shared/printing/print_document_templates_test.dart`
- Related feature print dialog tests (OPD, lab, radiology, nursing, billing helpers)
