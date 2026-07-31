# Radiology workflow detail

Simplify the Radiology workflow detail dialog so technologists and reporters work from a clear procedure list: mark each ordered study Done, then complete a **comprehensive per-procedure report** for any imaging procedure and modality. Keep the patient header; remove the cluttered metadata / request-details / standalone report / timeline stack that makes the current dialog hard to use.

## Context

- Detail dialog: `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart` (`_openRadiologyDetailDialog`, `_RadiologyOrderDetail`, `_RadiologyDetailBody`).
- Detail cells / “Not available” lines: `radiology_workspace_page.detail_cells.dart` (`_DetailLine`, `_valueOrUnknown`).
- Print field picker (exists, poorly placed): `radiology_workspace_page.print.dart`.
- Controller: `radiology_workspace_controller.dart` (`selectOrder`, `getWorkflow`, study/result mutations, assign/start/complete, asset upload, PACS sync).
- Entities / DTOs: `radiology_entities.dart`, `radiology_dtos.dart` — `RadiologyWorkflow`, `RadiologyOrder`, `RadiologyRequestedTest` (`requestedTests` already on the order but **not shown as a procedure workbench** in detail), `ImagingStudy` / `ImagingAsset` / `PacsLink`.
- Access: `radiology_access.dart` (write / report / print gates).
- Image intake today: local file/upload study assets, PACS link sync on studies; capture-photo currently shares the file picker. Reporting is plain text and not modality-complete.
- Current layout (painful): patient header → order metadata grid (many “Not available”) → Imaging floor / Reporting radios (chrome only) → Imaging studies empty state → Request details (edit icon) → independent Report section → Workflow timeline.
- Target UX inspiration: lab result entry (`lab_result_entry_dialog.dart`) — patient header + flat procedure/test rows + focused report/result dialog with print/preview in the footer.
- Clinical request-time details (modality, laterality, priority, clinical note) already live in the **request** / catalog dialog; do not re-surface them as a long read-only form here.
- Follow `.cursor/locale-development.mdc`, `.cursor/mandatories.mdc`, `frontend/.cursor/ui-feedback.mdc`, and existing `AppCollapsibleSection` / `AppDialog` / `AppListTable` patterns.

## Requirements

1. **Keep patient header:** Retain `AppPatientDetails` (name, patient id, order status, essential billing/study summary). Keep honest header next-actions (Assign / Start imaging / Cancel) gated by write access. Do not bury the primary work under stage radios.
2. **Procedure workbench table (primary body):** Replace the order-metadata label/value grid with a scannable table (or flat list matching clinical/lab density) of **ordered radiology procedures** for this workflow. Prefer `order.requestedTests` when present; if the API still returns one procedure per order row, show that as a one-row table—do not invent fake multi-rows. Show modality on the row when known (X-ray, Ultrasound, CT, MRI, Fluoroscopy, Mammography, Nuclear medicine, Interventional, etc.—humanized labels).
3. **Procedure columns:** At minimum show:
   - Radiology order / procedure id (friendly id, e.g. `RAD0000006`)
   - Procedure / study name
   - Modality (when available)
   - Laterality (and body region when useful)
   - Status (e.g. Pending / In process / Done—humanized, not raw enums; prefer localized Pending over “Not available” / `—`)
   - Actions column
4. **Mark Done:** Each pending/in-process procedure has a clear **Done** (or equivalent) action that records the procedure as performed. Done must be permission-gated and must call the real complete/study path—not a cosmetic checkbox. Done must work for **every** supported modality/procedure type on the catalog—not only X-ray or ultrasound.
5. **Write report after Done:** Only when a procedure is Done (or already reportable) show a **Write report** / open-report action. Tapping it opens a focused **report dialog** (not another long section on the same scroll). One report per procedure when multiple procedures exist. The same report path must complete reporting for **any** ordered imaging procedure/modality (no modality-specific dead ends or “unsupported study” stubs).
6. **Comprehensive report editor:** The report dialog is the full reporting workplace for that procedure. Authors must be able to:
   - Use a rich-text surface (not a single plain `AppTextField`) with structured narrative (technique / findings / impression / recommendation, or equivalent sections that fit all modalities)
   - Complete a clinically usable report regardless of modality (X-ray, US, CT, MRI, fluoro, mammo, NM, interventional, Doppler, etc.)—shared sections plus optional modality-aware hints/templates if they already exist; do not hard-block modalities without a template
   - Insert imaging assets **inline** in the report body with captions
   - Add simple annotations / on-image text where the asset/study model allows
   - Attach and browse images from **multiple sources** in one place (see Req 7)
   - Save draft, finalize, and (where product already supports it) attest / addendum without leaving the dialog for a second “Report” page section
7. **Multi-source imaging for reports:** From the procedure / report dialog, support gathering images from:
   - **Local device** — camera capture (real camera path when available) and file/gallery picker for common image formats
   - **Remote sources** — URL / remote fetch or facility remote intake already supported by the product; clear failure copy when unreachable
   - **PACS** — link / sync / pull existing PACS studies and assets via existing `PacsLink` / study sync APIs; show sync state honestly
   - **Already-attached study assets** — reuse uploads already on the imaging study for this procedure
   Present sources as explicit intake actions (not one ambiguous “Upload” that pretends to be camera + PACS). Each attached image must retain source metadata where available (local / remote / PACS) so reporters know provenance. Prefer tying all assets to the procedure being reported.
8. **Assign report typist:** For a completed procedure awaiting a report, allow assigning a user (typist/reporter) to type the report—reuse existing assignee/assign APIs where possible; do not invent a parallel staff module.
9. **Remove clutter from the detail body:**
   - Remove the standalone **Request details** read-only section (those fields belong at request time / edit-order flows, not as empty “Not available” chrome here).
   - Remove the independent **Report** section that duplicates the report dialog.
   - Remove the **Workflow timeline** from this dialog.
   - Remove or replace the **Imaging floor / Reporting** radio switch if it only reorders chrome; do not keep a fake two-mode shell once the procedure table + report dialog own the work.
10. **Lean procedure-scoped studies chrome:** Do not keep a large empty “No imaging studies” block competing with the report. Image intake lives as compact row actions and/or inside the report dialog (Req 7). Empty states must say what to do next (attach from device, remote, or PACS)—not generic “Not available.”
11. **Print in report dialog footer:** Move **Print report** into the report dialog footer (and/or dialog actions). Opening print must show a preview / field-selection dialog (existing print picker can be reused) so the user chooses which sections/fields (and selected images) go on the printed report. Gate print with the real radiology print/access requirement—do not leave an always-enabled dead control.
12. **Empty & unknown copy:** Stop flooding the detail with “Not available” lines for unset optional fields. Show only fields that have values, or use short localized Pending / em dash sparingly inside the procedure table—not a metadata encyclopedia.
13. **l10n + tests:** English strings for procedure columns (including modality), Done, Write report, multi-source image intake labels (local / remote / PACS), typist assign, report dialog sections, print footer, and empty states; widget/controller tests for procedure table presence, modality-agnostic Done → report, multi-source attach entry points, removed Request details / Report / Timeline sections, and print living on the report dialog.

Optional enhancements: modality-aware report templates/snippets if catalog already carries them—do not block shipping the shared comprehensive editor; do not expand desk tabs in this prompt.

## Constraints

- Reuse `AppDialog`, `AppPatientDetails`, `AppListTable` / dense table patterns, existing radiology assign/complete/result APIs, study asset upload, and PACS link/sync paths. Do not invent a second radiology desk or a parallel reporting module.
- Prefer surfacing `requestedTests` / existing order+result+study+asset+PacsLink models over new Prisma tables unless a true multi-procedure report or multi-source asset link is missing—then add the smallest backend glue needed.
- Rich text + inline images should build on existing imaging assets / upload / PACS paths; extend intake UX rather than requiring a greenfield PACS rewrite. Remote URL/fetch may use the smallest safe existing storage/upload pipeline.
- Reporting must remain **modality-complete**: one report dialog contract for all catalog modalities; optional templates are additive, not exclusive.
- Request-time metadata editing stays in order create/edit / request dialogs; this detail is for **performing**, **gathering images**, and **reporting**.
- No unrelated desk-tab redesign (Worklist / Reports today / etc.) in this prompt—detail dialog only.
- Preserve permission gating for write, report finalize, assign, print, upload, and PACS actions.
- Responsive: procedure table and report dialog usable on desktop dense layout and mobile overflow; image intake actions remain reachable in overflow menus on narrow layouts.

## Acceptance Criteria

- AC1 (Req 1–3, 12): Detail keeps patient header; primary body is a procedure table with id, name, modality, laterality/region, status; no “Not available” metadata wall.
- AC2 (Req 4–5, 9): Done marks any modality’s procedure performed; Write report opens only when appropriate; Request details, standalone Report, Timeline, and useless stage radios are gone from this dialog.
- AC3 (Req 6–8, 10): Report dialog completes comprehensive rich reporting for any procedure/modality; images can be attached from local device, remote sources, PACS, and existing study assets with clear source actions; typist can be assigned; no competing empty studies wall.
- AC4 (Req 11): Print lives on the report dialog footer with field/image selection / preview and real access gating.
- AC5 (Req 13): English l10n and tests cover the table, modality-agnostic Done → report, multi-source intake, removed sections, and print placement.

## Relevant Files

- `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`
- `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.detail_cells.dart`
- `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.print.dart`
- `frontend/lib/features/radiology/presentation/controllers/radiology_workspace_controller.dart`
- `frontend/lib/features/radiology/presentation/radiology_access.dart`
- `frontend/lib/features/radiology/domain/entities/radiology_entities.dart`
- `frontend/lib/features/radiology/data/dtos/radiology_dtos.dart`
- `frontend/lib/features/radiology/domain/repositories/radiology_repository.dart`
- `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart` (pattern reference)
- `frontend/lib/shared/components/app_patient_details.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_collapsible_section.dart`
- `frontend/lib/shared/components/app_clinical_results_preview.dart`
- `backend/src/modules/radiology-workspace/`
- `backend/src/modules/radiology-order/`
- `frontend/lib/l10n/app_en.arb`
- `.cursor/locale-development.mdc`
- `.cursor/mandatories.mdc`
- `frontend/.cursor/ui-feedback.mdc`
