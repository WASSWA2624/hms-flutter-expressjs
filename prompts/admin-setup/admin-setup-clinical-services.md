# Strengthen Radiology Imaging-Test Similarity Engine

Make radiology create/edit run percentage similarity on name and code before save, with match and no-match feedback.

## Context

- Surface: `RadiologyCatalogMutationDialog` (create and edit) on Clinical Services → Radiology.
- Current guard is too weak: exact matching misses misspellings; edit skips the check.
- Similarity = percentage fuzzy match on normalized name and code in active catalog scope.

## Requirements

1. Score name and code by percentage similarity, not exact-string-only matching.
2. Detect near-duplicates from misspellings, spacing/punctuation variants, and token overlap.
3. Run the check on Save for create and edit; exclude the edited row.
4. Threshold matches open Cancel / Use existing / Proceed with percentage scores.
5. When none match, show visible pre-save “no similar test” feedback, then continue save.
6. Exact conflicts stay field-blocked; Proceed sends `confirm_similar` for backend enforcement.
7. Keep permission, loading, validation, error, success states; hide unauthorized create/edit.

## Constraints

- Extend existing radiology similarity helpers/dialog and create/update API only.
- Align backend/frontend scoring. No silent duplicates.

## Acceptance Criteria

- Near-matching name/code opens the similarity dialog with scores on create/edit.
- Exact duplicates stay blocked with visible field feedback.
- No-match Save shows “no similar test” feedback, then saves.
- Use existing does not mutate; Proceed confirms once and syncs the list.
- Unauthorized users never see create/edit.
- Works on mobile/tablet/desktop in light and dark themes.

## Relevant Files

- `clinical_catalog_admin_dialogs.dart`, `radiology_catalog_similarity.dart`, similarity dialog
- `facility_catalog_config_panel.dart`, `radiology-test-similarity.js`, radiology-test module
- Radiology similarity unit/service tests
