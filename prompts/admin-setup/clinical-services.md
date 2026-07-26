# Implement "Create lab panel" with similarity checks

## Status: done

Lab **panel** create/edit now mirrors lab **test** create/edit: member-test
picker, `panel_items` payload, similarity review (including 0%),
`confirm_similar`, and backend uniqueness/409s.

## What shipped

### Frontend (`LabCatalogItemMutationDialog`, panel branch)

- Two-step wizard (`AppWizardStepper`): step 1 **Panel details**
  (name/code/category/description, Next validates), step 2 **Panel tests** —
  `LabPanelTestSelectionTable`, a fixed-height virtualized multi-select list
  (`ListView.builder` + search); ≥1 member test required before Save.
- Similarity review opens **only when** near/exact matches exist (empty
  0% scans save directly). Match dialog uses a single status banner and a
  bullet list for panel member tests.
- Payload includes `panel_items` (`lab_test_id`, optional `test_code`,
  `sort_order`) and `confirm_similar: true` after proceed.
- `_guardAgainstDuplicates` runs for panels: name/code/category + **composition
  overlap** (member-test identity match by id or code); always opens
  `showLabCatalogSimilarityDialog` (including 0%).
- Mobile-friendly picker layout (`AppBreakpoints.isMobile`).
- Catalog mutate remains gated by `canMutateLabCatalog`.

### Backend (`lab-panel.service.js` + `@lib/lab/lab-panel-similarity.js`)

- Composite similarity (name/code/category + membership units).
- `enrichPanelItemsForSimilarity` resolves friendly/uuid ids to internal id +
  code before uniqueness so id-only clients still match code-keyed rows.
- Composition scores **per member unit** (not flat dual-key Jaccard) so extra
  CODE/ID tokens on the same test do not dilute below the 80% threshold.
- `createLabPanel` / `updateLabPanel` reject exact/near matches with 409 unless
  `confirm_similar === true`; strip `confirm_similar` from writes.
- Schema: required `panel_items` on create; optional `confirm_similar`.

### Docs / tests

- `screens/admin-setup/clinical-services.md` documents panel picker + similarity.
- Backend: `lab-panel-similarity.test.js`, `lab-panel.service.test.js`,
  `lab-panel.schema.test.js`.
- Frontend: panel cases in `lab_catalog_item_mutation_dialog_test.dart` and
  domain panel similarity coverage.

## Original goal (kept for context)

A panel is a named, coded catalog entry composed of existing lab tests. Create
must pick member tests and guard against duplicates / near-duplicates the same
way lab tests already do.
