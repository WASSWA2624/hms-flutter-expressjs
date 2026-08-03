# Pharmacy Catalog & Stock — Drug CRUD Navigation and Similarity

## Objective

Align Catalog & Stock drug create, edit, and delete post-success navigation with the storage-room pattern, and make similarity review advisory rather than a hard block—including at 100% match—while scoring candidates with explicit per-field weights.

## Context

- Surface: Pharmacy workspace → Catalog & stock → Drugs (and the same similarity rules for Storage rooms / Shelves in that hub).
- Current create path already opens drug details after save or “Use existing” (`pharmacy_catalog_panel.dart` `_openDrugDialog`). Edit from the table closes the form and returns to the drugs table. Edit from details keeps the details dialog open but does not re-open it as a deliberate post-edit step. Delete from details already pops back to the table.
- Similarity today: weighted fields exist in `pharmacy-drug-similarity.js` (generic 35, brand 15, code 30, form 10, strength 10), but exact identity/code matches force overall score to 100, UI sets `blockProceed: hasExactConflict`, and create/update throws 409 on exact conflicts even when the user confirmed similar. Near matches can proceed via `confirm_similar`. Storage room/shelf adapters mirror the hard block.
- Permissions stay `pharmacy:write` (or operations write where already allowed for storage). Unauthorized create/edit/delete controls must not render.
- Reuse: `PharmacyDrugEditDialog`, `openPharmacyDrugDetailsDialog`, `showPharmacyDrugSimilarityDialog` / `showAppSimilarityReviewDialog`, storage room/shelf dialog-for-details helpers, existing `confirm_similar` contract, catalog refresh after mutations.

## Requirements

1. **Create → details:** After a successful drug create (including “Create anyway” and “Replace existing” that yields a saved drug), close the create form and open the drug details dialog for that drug. Do not leave the user on an empty create form or only the drugs table.
2. **Edit → details:** After a successful drug edit started from the drugs table, close the edit form and open the drug details dialog for the updated drug. After a successful edit started from an open details dialog, close the edit form and keep (or refresh) details so the updated fields are visible from workspace state.
3. **Delete → table:** After a successful drug delete from details, close details and return to the drugs table. Bulk delete from the table stays on the table. Preserve confirm dialogs and failure snackbars.
4. **Create anyway at any score:** Similarity review must offer “Create anyway” for near and exact (100%) matches. Do not hard-block proceed solely because identity or code is exact. Prefer “Use existing” / “Replace existing” when those actions remain available; “Create anyway” must still be reachable.
5. **Backend confirm override:** When `confirm_similar` is true, drug create/update must not reject exact identity or exact code conflicts. Without confirmation, keep rejecting similar/exact candidates as today (or via the similarity-check review path before persist). Strip `confirm_similar` before persistence.
6. **Weighted composite score:** Overall similarity must be the weighted composite of compared fields (existing drug weights; room/shelf keep their name/code or label/code weights). Do not coerce overall score to 100 merely because one field or clinical identity is exact. Exactness remains a per-field / match flag (badge, field status MATCH) without erasing lower field scores from the composite.
7. **All relevant parameters:** Score only fields present on input or candidate; include every configured weighted field that has values. Differing fields must pull the composite below 100 when not all weighted fields match. Apply the same advisory + weighted rules to pharmacy storage room and shelf similarity in Catalog & stock.
8. **States:** Preserve loading on save, validation errors on the form, similarity dialog cancel/retry, mutation failure snackbars, catalog list refresh after create/edit/delete, and write-gated actions (no disabled unauthorized chrome).

### Optional enhancements

- Align non-pharmacy modules (lab, radiology, tenant, facility, etc.) to the same advisory exact-match + weighted composite pattern in a follow-up; out of scope for this change unless touched incidentally by shared similarity UI.

## Constraints

- Preserve dispense queues, billing, prepare/attest, print, formulary/inventory tabs, and pack-scan flows unless required for the navigation/similarity changes above.
- Reuse existing dialogs, entities, routes (`/drugs/similarity-check`, drug setup/update/delete, storage similarity routes), and design-system similarity review—no parallel duplicate-review UI.
- Follow prompt implementation standards in `prompts/.cursor/prompt.mdc` (RBAC/ABAC, sync after mutations, theme tokens, responsive layout).

## Acceptance Criteria

- AC1 (Req 1): Successful create closes the form and shows drug details for the created (or replaced) drug.
- AC2 (Req 2): Successful table edit opens details with updated values; successful details edit leaves details showing updated values.
- AC3 (Req 3): Successful delete from details returns to the drugs table; list no longer includes the deleted drug after refresh.
- AC4 (Req 4–5): Exact 100% match still shows “Create anyway”; confirming create persists a new drug when `confirm_similar` is sent; backend no longer returns exact-conflict 409 when confirmed.
- AC5 (Req 6–7): Partial field matches produce a composite score below 100 when weighted non-matching fields are present; exact field flags remain visible; room/shelf similarity allows create/update anyway when confirmed.
- AC6 (Req 8): Unauthorized users never see create/edit/delete; authorized flows keep loading, validation, error, and success feedback.

## Relevant Files

- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_edit_dialog.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_details_dialog.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_similarity_dialog.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_storage_panel.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_storage_room_similarity_dialog.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_storage_shelf_similarity_dialog.dart`
- `backend/src/lib/pharmacy/pharmacy-drug-similarity.js`
- `backend/src/lib/pharmacy/pharmacy-storage-room-similarity.js`
- `backend/src/lib/pharmacy/pharmacy-storage-shelf-similarity.js`
- `backend/src/modules/pharmacy-workspace/services/pharmacy-workspace.service.js`
- `backend/src/modules/pharmacy-workspace/services/pharmacy-storage.service.js`
- Tests: `pharmacy_drug_similarity_dialog_test.dart`, `pharmacy_drug_details_dialog_test.dart`, `pharmacy_catalog_dialog_test.dart`, `pharmacy-drug-similarity.test.js`, `pharmacy-storage.service.test.js`, storage room/shelf similarity dialog tests

## Verification

- Update frontend tests that currently expect “Create anyway” absent on exact match; assert it is present and usable for drugs, rooms, and shelves.
- Extend backend drug similarity / setup tests for weighted composites and `confirm_similar` overriding exact identity/code.
- Manual: create → details; edit from table → details; edit from details → refreshed details; delete → table; exact duplicate → Create anyway succeeds; partial match shows non-100 composite.
- Confirm unauthorized write UI absent; authorized actions still available; catalog refreshes; light/dark and mobile/desktop layouts unchanged aside from navigation.
