# Refine Create Lab Panel wizard UX

## Context

Clinical Services > Lab > **Create panel** (`LabCatalogItemMutationDialog`)
already has details > tests, save-time similarity
(`showLabCatalogSimilarityDialog` / `lab-panel-similarity`), and post-success
details. Gaps: nested fixed-height `ListView` (`LabPanelTestSelectionTable`);
similarity is only a Save modal, not an explicit next review with clear
per-parameter scores.

## Requirements

1. Keep **Panel details**: name required; code, category, description optional.
   Validate name before Next.
2. On **Panel tests**, use `AppListTable` + built-in search (tenant/standard
   tests). Selected rows sort to top; require at least one member. One
   dialog-body scroll; no nested scroll.
3. After tests, open **Similarity** review (third step or Next) scoring name,
   code/id, category, and member composition (incl. tests already on other
   panels). Show per-parameter scores and calibrated overall % catching slight
   near-duplicates.
4. Each match offers **Use this panel**; Cancel aborts; Create/Continue sends
   `confirm_similar` when needed (reuse contracts, incl. 0% Continue).
5. After Use this or successful create, open
   `showLabCatalogItemDetailsDialog` for that panel.
6. Preserve edit parity, button loading on scan/save, validation/empty/error
   feedback, and `canMutateLabCatalog`. Follow `.cursor/mandatories.mdc`.

## Constraints

- Reuse existing dialog, similarity UI/lib, and `AppListTable`; no parallel
  path or Radiology/Diagnoses scope. Tune existing similarity calibration;
  avoid schema changes unless required.

## Acceptance Criteria

- AC1 (R1-R3): details > searchable `AppListTable` (single scroll) >
  similarity with per-field + overall %.
- AC2 (R4-R5): Use this / successful create opens panel details; Cancel leaves
  catalog unchanged.
- AC3 (R6): Unauthorized mutate UI hidden; button loading; usable xs-xxl /
  light+dark.
- AC4 (R2-R4): Mutation-dialog and `lab-panel-similarity` / service tests cover
  scroll fix, composition overlap, and `confirm_similar`.

## Relevant Files

- `clinical_catalog_admin_dialogs.dart`, `lab_catalog_dialogs.dart`,
  `lab_catalog_similarity_dialog.dart`, `lab-panel-similarity.js`,
  `screens/admin-setup/clinical-services.md`
