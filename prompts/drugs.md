# Create Drug Flow: Scan Assist → Confirm Prefill → Similarity → Save

**Objective:** Make Catalog → Drugs **Create drug** (`PharmacyDrugEditDialog` in create mode) as fast and accurate as possible by adding an assistive **barcode-first, OCR-fallback** capture path that **prefills** identity / formulation / batch fields, requires staff to **confirm** suggested values (highlighted; accept / edit / accept all), then runs a **drug similarity check** via the existing `AppSimilarity` pattern **before** `createDrug`. Do not persist pack photos. Keep pricing, stock, storage, and the existing save/API contract unless a change is required for similarity or prefill.

## Context

Codebase status (no screenshots attached — current `PharmacyDrugEditDialog` + pharmacy catalog create path):

| Surface | Current behavior |
| --- | --- |
| Entry | Catalog → Drugs → Create (`_DrugCatalogTab._openDrugDialog` → `PharmacyDrugEditDialog` with `drug == null`) |
| Dialog | Manual form only: Identity (generic, code, brand), Formulation (form, strength), Pricing, Initial stock + unit + reorder, Batch (batch #, MFG, EXP, alert lead), Storage room/shelf |
| Scan / OCR / barcode | **None.** No scanner packages in `frontend/pubspec.yaml`; no pack-scan CTA on the dialog |
| Prefill confirmation | **None.** Fields are typed; no “suggested / accept” chrome |
| Images | Shared `AppImageUploadField` / `pickAppImageFile` exist for **persisted** uploads elsewhere — **not** used by drug create; pack images must stay ephemeral |
| Similarity before save | Storage **room** / **shelf** create already: API check → `showAppSimilarityReviewDialog` adapter → proceed / use existing / retry / cancel. **Drugs have no equivalent** (no `checkDrugSimilarity` API, lib, or dialog) |
| Save | `_submit` → `controller.createDrug(PharmacyDrugInput…)` (+ optional facility offering); edit path is separate and stays available |

Raw intent: barcode scan when possible; if that fails, capture pack photo(s) → OCR → prefill → discard images → highlight prefilled fields and confirm (per-field accept/edit or accept all) → then similarity review using shared infrastructure → then existing create. Prefer **free / no paid OCR or drug-data subscriptions**. Assistive entry only — staff remains source of truth.

## Requirements

### A. Reusable capture / parse infrastructure (required foundation)

1. **Build shared, reusable scan + OCR plumbing** (not a one-off buried only inside the drug dialog). Prefer `frontend/lib/shared/…` services/widgets that pharmacy (and later peers) can call:
   - **Barcode capture** (camera or upload/decode) returning a normalized code string when found.
   - **Ephemeral image capture** (camera and/or gallery / file picker — web-capable first given current web usage) returning in-memory bytes only.
   - **OCR** over those bytes → raw text (+ optional structured line candidates). Use a **free** stack (e.g. on-device / WASM / backend-local OCR). **No** paid Cloud Vision / Lexicomp / First Databank subscription for v1.
   - **Drug-field parser** mapping barcode + OCR text (+ optional free public enrichment such as OpenFDA / RxNorm / DailyMed / local formulary when a code or name is known) into candidate values for: `brandName`, `genericName`, `form`, `strength`, `code`, `batchNumber`, `expiryDate`, `manufacturedAt` when present on pack.
2. **Do not persist pack photos or OCR images** to media storage, DB, or the drug record. After parse/prefill (or cancel), drop in-memory buffers. No attachment field on `PharmacyDrug`.
3. **Graceful degradation:** if barcode is missing/unreadable, offer photo OCR; if OCR yields nothing useful, fall back to the existing empty manual form without blocking create.

### B. Create-drug UX: Scan → Prefill → Confirm

4. **Create mode only for the automated path** (primary scope). Keep **Edit drug** behavior as today unless wiring a read-only “Scan to fill empty fields” later is trivial; do not regress edit/save/reorder/storage.
5. Add a clear **Scan pack** (or equivalent) entry on create: barcode-first. On barcode success, resolve candidates (local catalog + optional free lookup). On barcode failure / skip, allow **one or more pack photos** → OCR → parse.
6. **Prefill** the existing form fields that can be inferred. **Do not** invent selling prices, stock qty, reorder, room/shelf from OCR — those stay manual (or empty) as today.
7. **Confirmation step before treating values as accepted:**
   - Every field filled by scan/OCR must be **visually highlighted** as suggested (distinct from manually typed values).
   - Per suggested field: **Accept** or **Edit** (edit clears “suggested” once the user owns the value).
   - Global **Accept all** for remaining suggestions.
   - User may discard suggestions and type manually.
   - Until accepted (individually or via accept all), do not treat suggested values as confirmed for the similarity/save step — or equivalently: require an explicit confirm pass so staff cannot accidentally save unreviewed OCR text. Prefer staying on the same dialog with highlighted chrome rather than inventing a disconnected wizard unless clarity demands a short review panel.
8. After confirmation, continue with the **same** form sections (pricing, stock, batch leftovers, storage) and validation rules already on `PharmacyDrugEditDialog`.

### C. Similarity check before create (mirror storage pattern)

9. **Before** calling `createDrug`, run a **drug similarity check** modeled on storage room/shelf:
   - Backend: similarity helper (e.g. under `backend/src/lib/pharmacy/`) using shared tenant similarity primitives; compare at least generic/brand/name, code, form, strength (weights/thresholds aligned with existing `SIMILARITY_THRESHOLD` style). Exact code or exact identity conflicts should surface as hard/exact matches.
   - API + schema + service/controller/route following pharmacy-workspace storage similarity.
   - Frontend: repository/controller method + `showPharmacyDrugSimilarityDialog` adapter over `showAppSimilarityReviewDialog` (cancel / proceed / use existing / retry), same decision loop as `_StorageRoom` / shelf create.
10. **Use existing:** if staff chooses an existing drug, close create (or open that drug’s details/edit) without creating a duplicate — mirror shelf/room “use existing” UX.
11. **Retry:** return edited proposed identity fields into the form and re-check when the user retries from the similarity dialog.
12. If the check returns no material matches, allow proceed to create as storage does today.

### D. Preserve existing functionality

13. Keep create payload shape (`PharmacyDrugInput`, facility offering, inventory unit / initial stock / batch / storage) unless similarity needs extra read-only display fields.
14. Keep write gating, catalog table Create entry, l10n patterns, light/dark, and dialog width/scroll behavior.
15. Do not redesign Catalog Drugs worklist, drug details dialog, or formulary/inventory tabs except for wiring Create → new flow.

## Constraints

- **Free stack only for v1:** no paid OCR SaaS or commercial drug DB subscription required to ship. Optional free public APIs are fine; document rate-limit/offline behavior.
- **Web must work** for capture/OCR path (app is often run on web); native mobile enhancements are welcome if they reuse the same shared API.
- Prefer extending `PharmacyDrugEditDialog` + small shared modules over a parallel create screen.
- Reuse `AppSimilarity` / storage similarity adapters as the template for drug similarity UI and control flow.
- Images are ephemeral; never upload pack scans as drug media.
- OCR/barcode is **assistive** — never auto-save without confirm + similarity gate.
- Scope creep: no full formulary sync product, no mandatory internet for offline-capable barcode→manual, no change to pharmacy pricing rules.

## Acceptance Criteria

- (R1) Create drug offers **Scan pack** with **barcode-first**; OCR photo path available when barcode fails or is skipped.
- (R2) Successful scan/OCR **prefills** brand / generic / form / strength / code / batch / dates when parsed; price/stock/storage remain manual.
- (R3) Pack images are **discarded** after prefill/cancel and are **not** stored on the drug or media API.
- (R4) Prefilled fields are **highlighted**; user can **Accept**, **Edit**, or **Accept all** before continuing.
- (R5) On Create submit (after confirm), a **drug similarity** review runs via shared `AppSimilarity` pattern; cancel / proceed / use existing / retry behave like storage shelf/room.
- (R6) Proceed still calls existing `createDrug` with validated form data; duplicates can be avoided via use-existing.
- (R7) Manual-only create still works if the user never scans.
- (R8) Edit drug path and non-drug catalog surfaces remain behaviorally unchanged unless explicitly touched for shared infra.
- (R9) No paid OCR/drug-data subscription is required for the happy path.

## Verification

- Unit/widget tests: parser maps sample OCR/barcode fixtures → field candidates; suggested-field accept/accept-all clears highlight state; create submit invokes similarity before `createDrug`; use-existing / retry / cancel branches.
- Backend tests: drug similarity scoring (exact code, near generic/brand, threshold filtering) mirrors shelf/room test style.
- Manual: Catalog → Drugs → Create → scan barcode → confirm highlights → similarity → save; barcode fail → photo OCR → same; skip scan → manual create; ensure no pack image left in network tab/media; light + dark; web width.

## Relevant Files

- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_edit_dialog.dart` — create/edit form; primary UX integration point
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart` — `_openDrugDialog` entry
- `frontend/lib/shared/components/app_similarity.dart` — shared similarity review dialog
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_storage_shelf_similarity_dialog.dart` (+ room peer) — adapter pattern to copy for drugs
- `frontend/lib/shared/components/app_image_upload_field.dart` / `app_image_crop_dialog.dart` — reference for picking bytes only (do **not** persist)
- `frontend/lib/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart` — `createDrug`; add similarity check API
- `backend/src/lib/pharmacy/pharmacy-storage-shelf-similarity.js` (+ room) — pattern for new `pharmacy-drug-similarity`
- `backend/src/modules/pharmacy-workspace/` — routes, schemas, service, controller for similarity endpoint
- `frontend/lib/l10n/app_en.arb` — Scan pack, suggested field, accept all, similarity copy
- Tests under `frontend/test/features/pharmacy/` and backend pharmacy similarity tests as needed

## Out of scope

- Paying for commercial drug databases or cloud OCR
- Persisting packaging photos on the drug record
- Auto-filling pharmacy/facility price or stock levels from the internet
- Redesigning edit-drug, drug details, or unrelated catalog tabs
