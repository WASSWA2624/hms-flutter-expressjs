# Scope: Pharmacy drug pack scan automation — refine capture UX, barcode processing, and extraction accuracy

## Goal

Refine the existing **Scan pack or use AI capture** dialog (`showPharmacyDrugPackScanDialog`) so barcode processing, camera capture, live barcode scanning, and OCR/AI retries behave as staff expect—without redesigning the dialog or removing current assistive flows.

Outcome: staff can process a typed/scanned barcode into suggested drug fields, take real camera photos, scan barcodes with an in-app scanner (with product lookup where available), re-run OCR/AI as many times as needed, and get more accurate generic name / brand / form / strength / batch / dates before **Prefill form**.

## Non-goals

- Do not redesign the dialog layout, create-drug form, or catalog screens.
- Do not persist pack photos, OCR blobs, or scan frames to media storage (session/ephemeral only—keep current contract).
- Do not require a paid drug-data subscription; free/public lookup sources only, with graceful offline / unavailable fallbacks.
- Do not remove: raw pack text + Parse text / Process with AI, suggested-value editors, Skip scan, Prefill form, multi-photo thumbnails with crop/remove, or the create-form prefill handoff from `pharmacy_drug_edit_dialog.dart`.
- Do not block create when scan/lookup fails—assistive only; staff always confirm before save.

## Current implementation (baseline)

Primary UI: `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_pack_scan_dialog.dart`

Supporting stack:

| Area | Location | Current behavior |
| --- | --- | --- |
| Dialog entry | `pharmacy_drug_edit_dialog.dart` → `showPharmacyDrugPackScanDialog` | Returns `DrugPackFieldCandidates?` for create prefill |
| Barcode field | `AppTextField` + speech mic + suffix **Use barcode** | `_applyBarcode` runs `DrugPackFieldParser` on typed code |
| Take photo | `takeEphemeralImage` | Camera-preferring input; on unsupported platforms falls back to file picker (feels like “upload”) |
| Upload photos | `uploadEphemeralImages` | Gallery/file multi-select — keep |
| Scan barcode | Same as take-photo path + `AppHeuristicBarcodeDecoder` / OCR text heuristics | Still image, not a live scanner; no product catalog lookup |
| Process OCR / AI | `_processPhotos` + `_canProcessPhotos` | Buttons **disable** after a successful run (`_photosNeedProcessing = false`) until photos change |
| OCR | `AppTesseractJsOcrService` (web) | On-device Tesseract; accuracy often poor on pack art |
| Field map | `DrugPackFieldParser`, `DrugPackLocalAiMapper` | Heuristic / local clean+parse; screenshots show garbage generic/brand strings |
| AI mapper API | `DrugPackAiMapper` | Abstraction already allows a better remote/local impl without UI rewrite |

Observed gaps (from current UI + staff feedback):

1. Mic and **Use barcode** feel disconnected; label **Use barcode** understates that the action maps/prefills fields.
2. **Take photo** often opens file upload instead of a real camera experience.
3. **Scan barcode** is photo-based, not a built-in live scanner; no barcode→product metadata enrichment.
4. **Process with OCR** / **Process with AI** become inactive after the first successful process—retries require re-adding/editing photos.
5. Extracted suggested values (especially generic/brand) are frequently wrong or OCR garbage.

## Required changes

### 1) Package barcode field: mic proximity + **Process barcode**

- Rename action label from **Use barcode** → **Process barcode** (update `app_en.arb` + generated l10n; keep semantic meaning: map barcode into suggested drug fields).
- Update helper copy to match (e.g. process barcode to map fields; scan barcode fills the field from the scanner).
- Keep speech-to-text on the barcode field, but place the mic control **adjacent** to the Process barcode control (tight trailing cluster: mic → Process barcode), so the two actions read as one control group—not mic left floating and process far right.
- Prefer fixing via the dialog’s suffix composition / `AppTextField` trailing layout for this field without breaking speech/suffix patterns elsewhere.
- **Process barcode** must remain: take current barcode text → parse/map → seed Suggested values (and set drug code from barcode when identity fields are empty)—same success path as today, clearer naming only unless lookup (below) adds enrichment.

### 2) Take photo → open camera

- **Take photo** must open a **camera capture** path (device camera / getUserMedia / platform camera UI), not the gallery/file picker, whenever the platform can support it.
- Keep crop/editor behavior consistent with today’s take-photo flow if already used.
- **Upload photos** stays gallery/file multi-select.
- On true camera-unavailable platforms only, fall back clearly (message or disabled state)—do not silently pretend Take photo is Upload.

### 3) Built-in barcode scanner + lookup infrastructure

- **Scan barcode** must open an **in-app barcode scanner** (live camera viewfinder + decode), especially on phone/web-with-camera. Create shared scan infrastructure under `frontend/lib/shared/scan/` if missing (do not bolt a one-off only inside the pharmacy dialog if a reusable scanner is feasible).
- Scanner requirements:
  - Decode common retail/pharma barcodes (EAN/UPC/Code128/QR as already targeted by heuristics, expanded if the decoder stack allows).
  - On successful decode: fill Package barcode, then run the same process/map path as Process barcode.
  - Support cancel/close without losing existing dialog state.
  - Ephemeral frames only; no media upload.
- **Product / pack metadata lookup** (assistive):
  - After a successful decode (and optionally after Process barcode), attempt lookup against configurable free/public barcode or open-drug resources (pluggable provider interface; fail soft).
  - Merge any returned name/form/strength/etc. into `DrugPackFieldCandidates` the same way OCR/AI merge works today.
  - If lookup is unavailable, offline, or empty: keep current parser-only behavior; show a non-blocking status, never block Prefill/Skip.
- Desktop without camera: offer a clear fallback (manual entry + Process barcode, or still-image decode)—do not leave Scan barcode as a silent no-op.

### 4) Allow repeated Process with OCR / Process with AI

- After photos are processed, **Process with OCR** and **Process with AI** must stay **enabled** whenever `_photos.isNotEmpty` and not busy—staff must be able to re-run for multiple trials without editing/re-uploading photos.
- Fix the gate that currently ties enablement to `_photosNeedProcessing` only (e.g. allow process when photos exist; keep “needs processing” as status copy if useful, not as a hard disable).
- Re-runs should re-OCR / re-map and refresh Suggested values + raw text merge behavior consistent with current merge rules (prefer non-empty; staff can still edit).
- Preserve busy/loading guards so double-taps don’t spawn parallel runs; after completion, buttons re-enable for another try.
- Mirror the same “retry anytime” expectation for raw-text **Parse text** / **Process with AI** (already mostly enabled when not busy—keep that).

### 5) Improve extraction accuracy (OCR + mapping)

- Improve pack-photo → field accuracy so generic name, brand name, form, strength, batch, manufacturing/expiry are recovered more reliably than today’s garbage strings.
- Work within existing seams:
  - `AppOcrService` / platform OCR (preprocessing, language/psm hints, multi-pass, or better engine if free and ephemeral-safe).
  - `DrugPackFieldParser` heuristics (pack-label patterns: “Tablets B.P.”, brand lines, strength units, EXP/MFG).
  - `DrugPackLocalAiMapper` cleanup + structured mapping; optionally wire a better `DrugPackAiMapper` when configured, with local fallback unchanged.
- Prefer fixing mapping of *good* OCR lines over only UI polish; still surface Raw pack text so staff can correct and re-parse.
- Add/extend unit tests with realistic pack OCR fixtures (e.g. Paracetamol / brand / 500 mg / Tablet) proving generic + brand + strength + form populate correctly; keep regression tests for barcode-only and empty OCR.

## Preserve

- Dialog title, Skip scan, Prefill form (`hasAnyIdentityField` gate).
- Suggested values section and editable fields.
- Multi-photo strip, clear-all, per-photo crop/remove.
- Raw pack text section and parse/AI actions.
- Ephemeral image contract (no HMS media persistence).
- Existing `DrugPackFieldCandidates` shape and create-dialog prefill integration.
- l10n via ARB (no hard-coded user-facing English in widgets).
- Existing component patterns: `AppDialog`, `AppButton`, `AppTextField`, shared `scan` exports.

## Acceptance criteria

1. Barcode trailing controls: mic sits next to **Process barcode**; label/helper no longer say **Use barcode**.
2. **Process barcode** with a valid/typed code maps into Suggested values (and code/barcode fields) as before, with clearer copy.
3. **Take photo** opens camera capture on supported platforms; **Upload photos** remains file/gallery.
4. **Scan barcode** opens an in-app live scanner when camera is available; decoded value fills the barcode field and triggers process/map; cancel leaves prior dialog state intact.
5. Barcode decode can optionally enrich candidates via pluggable free lookup; failure degrades to parser-only without blocking the flow.
6. With N photos already processed, **Process with OCR** and **Process with AI** remain clickable; each re-run refreshes suggestions; buttons only disable while a run is in progress.
7. For representative pack photos/OCR text (e.g. Paracetamol 500 mg tablets + brand), Suggested values show correct-or-near-correct generic, brand, form, and strength—not OCR gibberish as the primary result.
8. Existing tests updated; new tests cover: process-barcode labeling/behavior, process-buttons remain enabled after first run, scanner/lookup soft-fail, improved parser/AI fixtures.
9. No pack image bytes uploaded to media APIs; create/save path unchanged aside from better prefill candidates.

## Implementation notes

- Start from `pharmacy_drug_pack_scan_dialog.dart`; extract reusable scanner/lookup into `frontend/lib/shared/scan/` when the dialog would otherwise grow a second capture stack.
- Prefer extending `AppBarcodeDecoder` / new `DrugPackBarcodeLookup` (name as fits repo style) over scattering HTTP in the widget.
- `_canProcessPhotos` today: `!_busy && _photos.isNotEmpty && _photosNeedProcessing` — this is the retry bug; change enablement, not the whole photo pipeline.
- Web camera: improve beyond `capture=environment` file input where a real MediaStream viewfinder is needed for live scan; keep stub/unsupported paths for non-web.
- Keep status messages (`pharmacyDrugScanProcessingAiBody`, empty/no-data, AI unavailable) coherent with retries and lookup misses.

## Out of scope / later

- Paid commercial drug databases or guaranteed global GTIN coverage.
- Auto-saving catalog drugs without staff review.
- Replacing the entire create-drug wizard with scan-only entry.
