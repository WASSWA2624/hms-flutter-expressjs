# Create Drug Scan Pack Capture Polish

## Objective

Refine the Create Drug **Scan pack or use AI capture** dialog so barcode, photo, and raw-text paths are clearly separated; photos collect then process via OCR and/or AI; suggested drug fields render as an editable structured list—without changing create/save, similarity, or form suggestion chrome after Prefill.

## Context

**Current (screenshots + `pharmacy_drug_pack_scan_dialog.dart`)**

- Package barcode field with mic + **Use barcode**; helper says type/paste barcode.
- Toolbar: **Take photo**, **Upload photos** (multi-select), **Process photos**, **Clear photos** in one row; strip shows thumbnails with per-photo remove/edit; status like “5 photos processed.”
- **Paste label wording** multiline with mic + **Parse text** suffix; helper implies paste-only.
- Suggested result is a single green **Confirm suggested values** banner joining garbled OCR fragments (e.g. nonsense · Tablet · 500 mg)—not an editable field list.
- Parse path today: local/heuristic `DrugPackFieldParser` + free OCR (`AppOcrService` / Tesseract WASM). No dedicated AI mapper. No camera barcode-scan control separate from typed barcode. Prefill / Skip / ephemeral images / create-form mapping remain.

**Intended**

- Keep typed barcode; clarify that entering a code then **Use barcode** reads/maps pack identity from that code. Add a **Scan barcode** action with Take/Upload (camera/decode into the barcode field).
- Photo toolbar: Take + Upload (+ Scan barcode). Move **Clear** into the photo preview card (top-right, icon control like per-thumb actions). Move **Process photos** below the strip; enable when photos exist / need processing.
- Raw-text area is freeform input (typed, pasted, or dictated)—not “label wording only”—mapped into the same drug candidate DTO. Place mic + **Parse text** neatly at the top-right of that section; Parse runs mapping.
- Dual extract engines for photos (and text where applicable): **OCR** (on-device / free path) and **AI** (network when available)—both output `DrugPackFieldCandidates`.
- Replace the flat banner with a structured, editable suggested-values list: field icon + parameter label + editable value for each known create field (generic, brand, form, strength, code, batch, dates, etc.).

## Requirements

1. **Preserve create pipeline.** Keep Create Drug form, Prefill → suggestion accept/edit, similarity gate, and save APIs unless a mapping bug is found. Skip/close still pops only the scan dialog.
2. **Clarify barcode path.** Keep Package barcode + **Use barcode**. Copy must state: type/paste the barcode number, then Use barcode to map fields. Do not imply the barcode field accepts photos.
3. **Add Scan barcode control.** Beside Take/Upload, add **Scan barcode** that captures/decodes a barcode into the Package barcode field (reuse `AppBarcodeDecoder` / ephemeral capture). User can then **Use barcode** or auto-apply decode when a code is found. Keep speech mic on the barcode field.
4. **Photo toolbar layout.** Row actions: Take photo, Upload photos, Scan barcode. Remove Clear and Process from this row.
5. **Photo preview card + Clear.** Wrap the strip in a card/section. Put **Clear photos** as a top-right icon action on that card (same visual language as per-thumb remove). Status text stays inside the card (ready vs processed counts).
6. **Process photos below strip.** Place **Process photos** under the gallery. Enable when ≥1 photo is present and processing is needed (or always when photos exist if re-run is useful). On press, run extraction across **all** session photos and merge into one `DrugPackFieldCandidates`.
7. **OCR vs AI process actions.** Under the strip (with Process), expose distinct **OCR** and **AI** actions (or Process menu / paired buttons). **OCR:** existing free `AppOcrService` + `DrugPackFieldParser` (works offline/on-device when the WASM engine is available). **AI:** new pluggable mapper that turns OCR/raw text (and optional image context) into structured `DrugPackFieldCandidates` when network/config allows; degrade gracefully to OCR/heuristics with visible feedback when AI is unavailable. Both must never persist pack images to media APIs.
8. **Raw text → DTO.** Relabel the multiline as raw pack text (typed/pasted/dictated). Mic + **Parse text** sit at the section top-right. Parse maps into `DrugPackFieldCandidates` (heuristic and/or AI path consistent with Req 7).
9. **Editable suggested-values list.** Replace the joined-string banner with a list/table of known parameters: icon, localized field label, editable value control. Seed from candidates; edits update the in-dialog candidate state used by Prefill. Empty fields may show placeholders. Keep Prefill disabled until at least one identity field is usable.
10. **States.** Loading while OCR/AI/barcode decode runs; empty (no candidates); error (parse failed / AI offline); success list; disabled Process/Parse when inputs missing. Responsive; theme tokens; light/dark.
11. **Localization.** Update `app_en.arb` for new labels/helpers (Scan barcode, OCR, AI, raw text, clear-on-card, editable suggestions).

### Optional enhancements

- After Scan barcode decode, auto-run Use barcode when a code is found.
- Show per-engine badge on each suggested field (OCR vs AI).
- Collapse raw-text section behind progressive disclosure once photos/barcode succeed.

## Constraints

- Reuse `showPharmacyDrugPackScanDialog`, `DrugPackFieldCandidates` / `DrugPackFieldParser`, `AppOcrService`, `AppBarcodeDecoder`, ephemeral take/upload/multi-upload, `showAppImageCropDialog`, and design-system controls. Extend with a small shared AI mapping interface rather than a second create flow.
- No paid commercial drug-database subscription required for v1; AI may use an existing app AI/config endpoint if one exists, otherwise a clear stub/config gate with OCR fallback.
- Do not persist pack images; do not change backend create/similarity contracts unless required for AI config.
- No unrelated pharmacy catalog refactors.

## Acceptance Criteria

- [ ] AC1 (Req 1): Prefill still fills Create Drug with suggestion chrome; Skip leaves create open; similarity/save unchanged.
- [ ] AC2 (Req 2–3): Barcode copy is type/paste-only; Scan barcode fills the barcode field; Use barcode maps candidates.
- [ ] AC3 (Req 4–6): Toolbar is Take / Upload / Scan barcode; Clear is on the photo card; Process sits below photos and runs on all images.
- [ ] AC4 (Req 7): OCR and AI paths are distinct; AI unavailable falls back with feedback; no media upload of pack images.
- [ ] AC5 (Req 8): Raw text section has top-right mic + Parse text; Parse updates candidates/DTO.
- [ ] AC6 (Req 9): Suggested values show as editable icon+label+value rows; Prefill uses edited values.
- [ ] AC7 (Req 10–11): Loading/empty/error/success work; strings localized; OK on narrow/wide, light/dark.

## Relevant Files

- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_pack_scan_dialog.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_edit_dialog.dart`
- `frontend/lib/shared/scan/drug_pack_field_parser.dart`
- `frontend/lib/shared/scan/app_ocr_service.dart`
- `frontend/lib/shared/scan/app_barcode_decoder.dart`
- `frontend/lib/shared/scan/app_ephemeral_image_capture.dart`
- `frontend/lib/shared/components/app_image_crop_dialog.dart`
- `frontend/lib/l10n/app_en.arb`
- `frontend/test/features/pharmacy/presentation/pharmacy_drug_pack_scan_dialog_test.dart`
- `frontend/test/shared/scan/drug_pack_field_parser_test.dart`

## Verification

- Widget tests: toolbar layout; Clear on card; Process below strip; editable suggestion rows update Prefill payload; Skip vs Prefill navigation.
- Unit: OCR merge across multi-photo; AI mapper (or stub) → `DrugPackFieldCandidates`; barcode scan fills field.
- Manual: type barcode → Use barcode; Scan barcode; take/upload many → Process OCR + AI; edit suggested rows → Prefill; raw text Parse; AI-offline fallback; light/dark; narrow/wide.
- Confirm no pack-image media API calls; create permissions unchanged.
