# Create Imaging Test with Similarity Guard

Add a scoped pre-create similarity check to Radiology Create imaging test (Admin Setup → Clinical Services) so duplicates cannot save silently; sync backend/frontend.

## Context

- `RadiologyCatalogMutationDialog` (create): required name, optional code, required modality (`kRadiologyCatalogModalities`).
- Similarity = fuzzy match on name (and code when set) in active catalog scope. Mirror tenant/facility similarity UX.

## Requirements

1. On Save (create only), validate then run similarity before create.
2. Scope candidates: platform/global; tenant (and its facilities); facility-visible catalog.
3. Exact name/code conflicts block with validation or banner feedback.
4. Near matches open Cancel / Use existing / Proceed create.
5. Cancel keeps form; Use existing dismisses without insert; Proceed create persists once, reloads Radiology, shows success.
6. Enforce same rules on backend create (no UI bypass).
7. Keep permission, loading, validation, error, success states; unauthorized create must not render.

## Constraints

- Reuse modality options, create API, RBAC/ABAC, design system, post-mutation reload, similarity dialog patterns.
- Touch other Clinical Services flows only for shared helpers. No silent duplicates.

## Acceptance Criteria

- No match → create, reload, success feedback.
- Near match → Cancel keeps form; Use existing creates nothing; Proceed inserts once.
- Exact duplicate → rejected on UI and API with visible feedback.
- Platform creates global; tenant creates stay tenant-scoped.
- Unauthorized users never see Create imaging test.
- Works on mobile/tablet/desktop in light and dark themes.

## Relevant Files

- `screens/admin-setup-clinical-services.md`
- `clinical_catalog_admin_dialogs.dart`, `facility_catalog_config_panel.dart`, `facility_similarity_dialog.dart`
- `backend/src/modules/radiology-test/**` and create/similarity tests
