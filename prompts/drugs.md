# Implementation prompt: Similarity match card — Replace existing

## Goal

Extend the shared similarity review UI so each match card can **replace an existing record with the proposed values**, instead of only selecting the existing record or creating a duplicate.

Primary surface: `frontend/lib/shared/components/app_similarity.dart`.

## Current behavior (as implemented)

`showAppSimilarityReviewDialog` / `AppSimilarityMatchCard` support these outcomes today:

| Action | Meaning | Result |
| --- | --- | --- |
| **Cancel** | Dismiss review | `AppSimilarityReviewAction.cancel` |
| **Check again** | Re-run similarity with edited proposed fields | `retry` + `proposedValues` |
| **Use this** (per match card) | Keep the selected existing item; abandon create | `useExisting` + `selected` (+ optional `proposedValues`) |
| **Save / create anyway** (dialog footer) | Continue creating a new item with proposed values | `proceed` + `proposedValues` (hidden when `blockProceed` / exact conflict) |

Match cards expose a **single** CTA (`onUseThis` → `useExisting`). There is **no** action that means: *apply the proposed (suggested) values onto this existing match*.

Callers (e.g. pharmacy drug create via `pharmacy_drug_similarity_dialog.dart` → `pharmacy_drug_edit_dialog.dart`) already handle `useExisting` by selecting the existing entity and aborting create. That path must remain unchanged.

## Intended behavior

When the user is **adding** (create flow) and similarity review shows one or more existing matches:

1. Keep **Use this** as today: select the existing match and do **not** create a new record; do **not** overwrite the existing record with proposed values.
2. Add **Replace existing** (per match card): choose that existing match as the target, and treat the **proposed/suggested values** as the values that should **overwrite** that existing record — **no new duplicate** is created.
3. Preserve **Cancel**, **Check again**, and **Save/create anyway** semantics unless a caller explicitly opts into different footer behavior.

Direction of data for replace:

- **Source of truth for field values:** current proposed values in the dialog (including any in-dialog edits), not the existing column.
- **Target of the write:** the selected match’s existing item (`AppSimilarityMatch.item`).
- **Outcome:** replace/update existing with proposed; do not create a second entity.

## Gap to close

| Area | Gap |
| --- | --- |
| Result model | No `replaceExisting` (or equivalent) on `AppSimilarityReviewAction` / `AppSimilarityReviewResult` |
| Match card UI | Only one action; no second CTA for replace |
| Dialog API | No opt-in flags/labels/icons for replace; no way for callers to enable/disable it |
| Tests | `app_similarity_test.dart` covers use-this / proceed / retry only |

## Requirements

### Shared component (`app_similarity.dart`)

1. **Add a review action** for replace, e.g. `AppSimilarityReviewAction.replaceExisting`, with a result factory that carries:
   - `selected` — the existing match item `T`
   - `proposedValues` — map of current proposed field values (same shape as `proceed` / `retry`)
2. **Extend `AppSimilarityMatchCard`** so each card can show a second action when enabled:
   - Primary existing action remains **Use this** (`useExisting`).
   - New action **Replace existing** pops `replaceExisting` with that card’s item + current proposed values.
   - Layout: keep the existing card structure; place both actions in the card footer without clutter (e.g. secondary + primary/destructive-adjacent secondary). Match existing `AppButton` patterns.
3. **Extend `showAppSimilarityReviewDialog` / dialog state** with opt-in replace support, for example:
   - `enableReplaceExisting` (default `false`) — callers must opt in so existing adapters stay behavior-identical.
   - Optional `replaceExistingLabel` / `replaceExistingIcon` (fallback to new shared l10n keys).
4. **Default off:** when `enableReplaceExisting` is false, UI and result surface must match today’s behavior (no new buttons, no new enum values returned from the dialog).
5. **Exact vs near matches:** replace should be available on both exact and near match cards when enabled (exact conflicts already block *create anyway*; replace is an alternative to create, not a bypass of identity review).
6. **Do not** change field comparison rendering, scoring display, proposed-field editing, retry, cancel, or proceed unless required to wire the new action.

### Localization

- Add shared strings in `app_en.arb` (and regenerate l10n as this repo requires), e.g.:
  - `appSimilarityReplaceExistingAction` — default label such as “Replace existing”
  - Optional short helper/tooltip only if the design system already uses one for similar CTAs; otherwise label-only is enough.
- Domain adapters may override via `replaceExistingLabel` (e.g. pharmacy: “Replace this drug”) without hard-coding English in widgets.

### Call-site wiring (out of shared widget, but in scope for a complete feature)

Shared component work alone is insufficient for end-to-end behavior. After the API exists, the **first consumer** should be the pharmacy drug create similarity path (prompt context: drugs), unless this task is explicitly limited to the shared widget + tests only:

1. `pharmacy_drug_similarity_dialog.dart` — enable replace; map `replaceExisting` → a new `PharmacyDrugSimilarityAction.replaceExisting` carrying `selectedDrug` + proposed values.
2. `pharmacy_drug_edit_dialog.dart` (create branch) — on replace: call existing `updateDrug` / offering upsert with proposed field values for the selected drug id; pop a saved/replaced result; **do not** call `createDrug`.
3. `pharmacy_catalog_panel.dart` — treat a successful replace like a successful save/use-existing for refresh / details open, consistent with current post-create UX.
4. Other similarity adapters (tenant, facility, storage, lab, etc.) **must remain unchanged** until they opt in.

If this ticket is **shared-component only**, document the new API and leave domain wiring to a follow-up; still ship component tests.

### Tests

Update / add widget tests in `frontend/test/shared/components/app_similarity_test.dart`:

- Replace CTA **absent** when `enableReplaceExisting` is false (default).
- Replace CTA **present** when enabled; tapping returns `replaceExisting` with correct `selected` and edited `proposedValues`.
- **Use this** still returns `useExisting` and does not update semantics.
- Exact-conflict + replace enabled: proceed still blocked; replace and use-this still available.

Add or extend pharmacy dialog/edit tests only if domain wiring is included in the same change.

## Non-goals / preserve

- Do not remove or redefine `useExisting`.
- Do not force replace on all similarity dialogs; default remains off.
- Do not redesign the similarity dialog layout beyond the match-card action area.
- Do not change backend similarity scoring APIs for this UI action (replace is an update of an already-identified existing id).
- Do not invent a merge/partial-field UI; replace applies the **current proposed values** as the update payload the caller already knows how to send.

## Acceptance criteria

- [ ] Match cards can optionally offer **Replace existing** in addition to **Use this**.
- [ ] Choosing replace returns selected existing item + proposed values; choosing use-this still only selects existing.
- [ ] Default callers (replace disabled) behave exactly as before.
- [ ] With pharmacy wiring (if in scope): create-with-similarity → replace updates that drug and does not create a duplicate.
- [ ] Shared component tests cover enable/disable and both card actions.
- [ ] l10n keys exist; no raw user-facing English hard-coded in the shared widget beyond existing patterns.

## Implementation notes

- Prefer extending the existing result enum/factories over a parallel callback API, so adapters keep a single `switch (result.action)`.
- Pass `proposedValues` on replace the same way `useExisting` already can, so callers do not re-read controllers after pop.
- Keep `AppSimilarityMatchCard` reusable: if both actions are shown, prefer optional `onReplaceExisting` / visibility flag over baking domain logic into the card.
- Visual language: reuse secondary/tertiary button styles already used on the card; avoid introducing a new card chrome.
