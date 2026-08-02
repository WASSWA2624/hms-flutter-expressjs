# Shared Similarity Card + Dialog: Reusable Review Flow

**Objective:** Extract a shared, elegant similarity **match card** and **review dialog** under `frontend/lib/shared/components` (composed from existing collapsible / panel / banner primitives) so features can reuse one pattern — field-level proposed vs existing comparison, overall %, color-coded Exact/Near, right-aligned **Use this**, editable proposed values with **Retry**, and footer **Save anyway** / **Cancel** — then migrate the pharmacy storage-room Duplicate Room flow to it without regressing create/update, exact-block, soft-delete, or details routing.

## Context

Screenshots show the live pharmacy Catalog **Duplicate Room** dialog (`?section=catalog` → Rooms → Create). That UI already works end-to-end but is feature-private and incomplete relative to the intended shared design:

| Surface | Current behavior |
| --- | --- |
| Pharmacy dialog | `pharmacy_storage_room_similarity_dialog.dart` — `AppFormInformationBanner` + read-only proposed `AppSectionPanel` + match `AppContentPanel` cards with Field / Proposed / Existing / % table + **Use this room** (left-aligned) + Cancel / Create anyway |
| Exact conflict | Banner “Exact match found”; Create anyway hidden; Use this + Cancel only |
| Near / none | Create anyway / Continue available; 0% panel when no matches |
| Proposed values | Display-only; user must Cancel back to the create form to edit — **no in-dialog edit / Retry** |
| Details routing | Not inside the similarity dialog; callers (`openPharmacyStorageRoomDialogForDetails` / catalog Create) open details after save or Use existing |
| Shared folder | **No** similarity widgets under `frontend/lib/shared/components` |
| Duplicated clones | Tenant-facility `*_similarity_dialog.dart`, lab/radiology catalog similarity dialogs, access-admin role/user — same skeleton, copy-pasted |

Existing chrome to compose (do not reinvent):

- `AppCollapsibleSection` / `AppSectionPanel` — proposed block; prefer collapsible for editable proposed + header actions (Retry)
- `AppContentPanel` — toned match cards (error / warning / success)
- `AppFormInformationBanner` — top status message
- `AppDialog` / `AppButton` — shell and footer actions
- Lab/radiology field-comparison layout (`lab_catalog_similarity_dialog.dart` / `radiology_catalog_similarity_dialog.dart`) — richer table + **Use this** right-aligned; good visual seed for the shared card

Raw intent: one reusable **card** + one reusable **dialog** under shared; elegant and simple; dialog owns banner, editable proposed + retry, match list, Save anyway / Cancel, and routes to the entry’s details when appropriate.

## Requirements

1. **Shared similarity match card (`AppSimilarityMatchCard` or equivalent name).** Under `frontend/lib/shared/components`, build a generic, domain-agnostic card (prefer composing `AppContentPanel` + optional collapsible chrome only where it helps density):
   - Shows the **parameters** under review (field labels supplied by the caller).
   - For each parameter: **entered (proposed)** value, **existing** value, and **per-field %** (nullable when not scored).
   - Shows **overall %** and Exact / Near (or equivalent) badge, color-coded via theme tokens / `AppWorkspaceStatusTone` / `AppFormInformationVariant` — no one-off hard-coded brand colors.
   - **Use this** action **right-aligned** on the card (screenshots today left-align pharmacy; intended is right-aligned, matching lab/facility room patterns).
   - Caller supplies title/subtitle (e.g. existing room name/code), field rows, scores, tone, and `onUseThis` — no pharmacy/facility entity imports inside shared.

2. **Shared similarity review dialog (`showAppSimilarityReviewDialog` or equivalent).** Same shared folder; compose card + chrome into one dialog with:
   - **Top:** color-coded status card/banner with an appropriate title + message (exact / similar / none) driven by caller flags or a small result model.
   - **Proposed section:** **editable** collapsible (`AppCollapsibleSection`) listing the entered parameters; include a **Retry** (or “Check again”) action that returns edited proposed values to the caller (or invokes a caller-provided `onRetry`) so similarity can be re-run **without** forcing Cancel → reopen create form.
   - **Matches section:** list of shared match cards (or empty / “no close matches” score panel).
   - **Footer:** **Cancel**; **Save anyway** (or Continue when no matches) — label injectable; hide/disable Save anyway when the caller marks the result as a hard exact block (preserve pharmacy’s exact-duplicate rule).
   - Result type mirrors existing patterns: `cancel` | `useExisting` (payload) | `proceed` | optionally `retry` with updated proposed map — keep the API small.

3. **Details routing after successful create path.** Keep behavior simple and explicit:
   - **Use this** / **Save anyway → create success** should land on the **details** surface for that entity, as today for pharmacy Rooms (create → details; Use existing → details).
   - Prefer a thin **caller callback** (`onResolved` / parent already opens details) over the shared dialog importing feature details dialogs. Document the contract: dialog returns the chosen entity or “proceed”; feature opens details. If a shared helper wrapper is cleaner for pharmacy only, keep it in the pharmacy layer.

4. **Migrate pharmacy storage-room flow first.** Replace `pharmacy_storage_room_similarity_dialog.dart` internals (or delete and call shared) from `_StorageRoomDialog._submit` so Duplicate Room / Similar rooms screenshots use the shared card + dialog. Preserve:
   - Exact name/code → hard stop (no Save anyway)
   - Near matches → Save anyway / Create anyway with `confirm_similar`
   - Use this → no create; open existing room details
   - Auto-code, soft/hard delete, filters/export, RBAC unchanged

5. **Out of scope for this pass (unless trivial).** Mass-migrating every tenant-facility / lab / radiology / access-admin dialog in one PR. After pharmacy proves the API, other modules may adopt later. Do not change Drugs / Formulary / Inventory / Shelves semantics beyond similarity UX. Do not invent new backend scoring fields; consume existing `field_comparisons` / scores already returned.

6. **Elegance and simplicity.** Prefer one small public model for field rows + one card + one dialog function; avoid a parallel design system. Light + dark theme tokens; responsive match list; no cluttered chrome.

## Constraints

- Place reusable widgets under `frontend/lib/shared/components` and export via `components.dart` if that is the repo convention.
- Build from existing collapsible/panel/banner primitives; do not fork a second dialog framework.
- Shared layer stays **domain-agnostic** (strings, field rows, callbacks, tones) — pharmacy maps `PharmacyStorageRoomSimilarity*` → shared models at the call site.
- Preserve pharmacy exact-block semantics and create → details / Use existing → details behavior.
- No unrelated module refactors; no DB migrations.

## Acceptance Criteria

- (R1) Shared match card shows parameters, proposed, existing, per-field %, overall %, color-coded status, and **right-aligned Use this**.
- (R2) Shared dialog shows banner, **editable** proposed collapsible with **Retry**, match cards section, **Save anyway** (when allowed) + **Cancel**.
- (R3) Pharmacy Rooms create/edit similarity uses the shared dialog/card; exact duplicates cannot Save anyway; near matches can; Use this opens existing room details without creating a duplicate.
- (R4) Successful create (Save anyway → persist) still opens room details as today.
- (R5) Retry re-checks similarity with edited proposed values without a full Cancel → reopen create-form cycle (or documented equivalent that meets the same UX).
- (R6) Other catalog tabs and prior Room CRUD (codes, soft/hard delete, filters) remain intact.
- (R7) Light + dark; no Actions/table regressions from unrelated edits.

## Verification

- Widget tests for shared card/dialog: exact blocks Save anyway; near allows Save anyway; Use this / Cancel / Retry callbacks fire; Use this is right-aligned.
- Pharmacy: existing `pharmacy_storage_room_similarity_dialog_test.dart` updated to shared API (or replaced); create → similarity → details / Use this → details still covered.
- Manual: `?section=catalog` → Rooms — exact duplicate (banner + cards + Use this + Cancel only); near match (Save anyway); edit proposed + Retry; Use this → details; light + dark.

## Relevant Files

- New: `frontend/lib/shared/components/app_similarity_*.dart` (card + dialog + small models) + export in `components.dart`
- Reference UI: `frontend/lib/shared/lab_catalog/lab_catalog_similarity_dialog.dart`, `frontend/lib/features/tenant_facility/presentation/widgets/room_similarity_dialog.dart`
- Migrate: `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_storage_room_similarity_dialog.dart`, `pharmacy_storage_panel.dart` (`_StorageRoomDialog._submit`)
- Primitives: `app_collapsible_section.dart` / `app_content_panel.dart` / `app_form_information_banner.dart` / `app_dialog.dart`
- Tests: new shared similarity widget tests; update `frontend/test/features/pharmacy/presentation/pharmacy_storage_room_similarity_dialog_test.dart`
