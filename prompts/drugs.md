# Create Drug Pack Scan UX

## Objective

Simplify the Create Drug **Scan pack** assistive flow so barcode, multi-photo OCR, and optional AI text parse feed a clear preview, then prefill the existing Create Drug form—without changing create/save, similarity checks, or suggested-field confirmation.

## Context

**Current (Create Drug + Scan pack)**

- Create Drug (`PharmacyDrugEditDialog`) exposes **Scan pack**, which opens `_PharmacyDrugPackScanDialog`.
- Scan pack is barcode-first with a separate **Use barcode** button beside the field, **Capture pack photo** (single shot), **Paste pack text**, a large **Pack text** area, instructional body copy, then **Skip scan** / **Prefill form**.
- Parse path: ephemeral image → barcode decode + free OCR (`AppOcrService`) → `DrugPackFieldParser` → `DrugPackFieldCandidates` → prefill + `AppSuggestedFieldSet` chrome on the create form.
- Images are never persisted; staff must confirm before save. Similarity check on create remains unchanged.

**Intended**

- Declutter Scan pack: less instructional text; scan-focused layout.
- Put **Use barcode** inside the barcode field suffix (right of mic): icon+label on large viewports, icon-only on small (tooltip/semantics retain full label).
- Support **multiple pack photos** from either **camera take** or **gallery/file upload** (add repeatedly in one session); after each batch, extract and map into candidates, then show a preview before Prefill.
- Replace free-form “paste pack text” as a primary paste dump with an **AI/parser text** input: user pastes or types pack text → parser maps to the same candidate DTO used by OCR/barcode.
- **Skip scan** / dialog close returns to Create Drug only (nested dialog); do not dismiss the whole create flow.
- Entry action on Create Drug should read as scan/AI capture (e.g. “Scan pack or use AI capture”), not a vague “Scan pack” alone.

## Requirements

1. **Preserve create pipeline.** Keep Create Drug sections, validation, create/update APIs, similarity dialog, suggested accept/edit chrome, and `DrugPackFieldCandidates` → form mapping unless a field mapping bug is found.
2. **Declutter Scan pack UI.** Remove or drastically shorten the long instructional body. Keep hierarchy: barcode → photo capture → optional parser text → status/error → preview → footer actions. No duplicate competing CTAs.
3. **Inline barcode apply.** Move **Use barcode** into the barcode `AppTextField` suffix trail (after speech mic via existing `suffixIcon` composition). Responsive: show label+icon when space allows; icon-only below the compact breakpoint used by `AppButton`/label scope. Keep speech-to-text on the barcode field.
4. **Multi-photo OCR (take or upload).** In one scan session, let the user add **two or more** pack images via **camera** and/or **gallery/file upload** (reuse ephemeral pick/capture from `captureEphemeralImage` / `pickAppImageFile`—both sources must be available where the platform supports them). Allow repeating “Add photo” / “Upload photo” until the user is done; do not cap at a single shot. Run barcode+OCR per image (or batched), merge into one `DrugPackFieldCandidates` (existing `merge` semantics). Discard all image bytes after parse. Show lightweight progress/count (e.g. “2 photos processed”) without persisting thumbnails or uploading to media APIs.
5. **Parser text input (not paste dump).** Replace **Paste pack text** + large always-on dump UX with a single optional **Parse pack text** (AI/heuristic parser) control: multiline or compact expand-on-demand field + explicit parse action that calls the same `DrugPackFieldParser` (and any existing assistive mapping) to produce/update candidates. Do not introduce a paid drug-data subscription; stay on free heuristics/OCR already in `shared/scan`.
6. **Preview then Prefill.** After barcode apply, photo parse, or text parse succeeds with identity fields, show a clear preview of mapped candidates (brand, generic, form, strength, code, batch, dates as available). **Prefill form** stays disabled until preview has usable identity fields; on press, pop candidates and apply existing create-form prefill + suggestion marks.
7. **Nested navigation.** **Skip scan**, dialog X, and Cancel-equivalent must `pop` only the scan dialog and leave Create Drug open and unchanged. Do not clear create-form state on skip.
8. **Entry labeling.** Update Create Drug scan entry copy/iconography so intent is “scan pack or use AI/OCR capture.” Localize via `app_en.arb` (+ generated l10n). Keep icon consistent with scan/AI capture.
9. **States.** Cover loading (busy while OCR/decode/parse), empty (no candidates yet), error (no parseable data—reuse/adapt `pharmacyDrugScanNoDataBody`), success preview, and disabled Prefill when preview is empty. Unauthorized pharmacy create remains governed by existing catalog permissions (no new “no access” chrome).
10. **Responsive + theme.** Layout must work mobile/tablet/desktop without clipping overflow of suffix actions; use theme tokens; support light/dark.

### Optional enhancements

- Compact photo strip (ephemeral count chips only) with separate **Take photo** and **Upload photo** actions, plus clear/reset session photos.
- Collapse parser text behind progressive disclosure (“Have pack text?”) to keep the default scan path barcode + photos only.

## Constraints

- Reuse `showPharmacyDrugPackScanDialog`, `DrugPackFieldParser`, `AppOcrService`, `AppBarcodeDecoder`, `captureEphemeralImage`, `AppTextField`/`AppButton`/`AppDialog`, and create-form suggestion flow; do not reinvent parallel parsers or media upload.
- Do not persist pack images to media APIs or disk beyond the in-memory parse session.
- Do not change backend drug create contracts or similarity RBAC unless required for a bug in existing assistive mapping.
- No unrelated pharmacy catalog refactors.
- Follow project prompt/UI rules: theme tokens, responsive actions, no unauthorized control stubs.

## Acceptance Criteria

- [ ] AC1 (Req 1): Create Drug still saves, runs similarity, and applies suggestion accept/edit after prefill as today.
- [ ] AC2 (Req 2–3): Scan pack has no long instruction paragraph; barcode field contains Use barcode in the suffix after mic; large viewport shows icon+label, small shows icon-only with accessible label.
- [ ] AC3 (Req 4): User can add ≥2 pack photos in one session via camera and/or upload; candidates merge across photos; images discarded after parse; busy/error feedback visible; no media-API upload.
- [ ] AC4 (Req 5): Primary paste-dump CTA is gone; optional parser text produces the same candidate shape via `DrugPackFieldParser`.
- [ ] AC5 (Req 6): Preview appears when candidates exist; Prefill enabled only then; Prefill returns to Create Drug with fields filled and suggestion chrome.
- [ ] AC6 (Req 7): Skip scan / close scan returns to Create Drug without closing create or wiping form values.
- [ ] AC7 (Req 8): Create Drug entry label communicates scan or AI/OCR capture; strings localized.
- [ ] AC8 (Req 9–10): Loading/empty/error/success states work; UI OK on narrow and wide viewports in light and dark.

## Relevant Files

- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_pack_scan_dialog.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_edit_dialog.dart`
- `frontend/lib/shared/scan/drug_pack_field_parser.dart`
- `frontend/lib/shared/scan/app_ephemeral_image_capture.dart`
- `frontend/lib/shared/scan/app_ocr_service.dart`
- `frontend/lib/shared/scan/app_barcode_decoder.dart`
- `frontend/lib/shared/components/app_text_field.dart`
- `frontend/lib/l10n/app_en.arb`
- `frontend/test/shared/scan/drug_pack_field_parser_test.dart`

## Verification

- Widget/unit: barcode suffix action layout (or golden/responsive smoke); multi-photo merge → candidates (camera and upload entry points); parser text → candidates; Prefill disabled/enabled; skip leaves create route/dialog open.
- Extend/adjust `drug_pack_field_parser_test.dart` if merge/parse behavior changes; add pack-scan dialog tests for skip vs prefill navigation where practical.
- Manual: Create Drug → Scan → barcode apply; take multiple photos for OCR; upload multiple photos for OCR; mix take+upload in one session; parser text; preview → Prefill; Skip/X back to create; narrow + wide; light + dark.
- Confirm no media upload network calls for pack images; pharmacy create permission behavior unchanged.
