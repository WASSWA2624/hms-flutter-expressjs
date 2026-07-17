# Standardize `_AccessAdminUserDetailDialog` — Access Admin User Detail

## Mission

Show access-admin user detail with shared user-access and info primitives.

Bring **`_AccessAdminUserDetailDialog`** to **100% compliance** with [`prompt.md`](prompt.md) (detail-viewer standardization). This is **structural**, not cosmetic: consolidate onto the established product surface used across [`dialog-inventory/03-detail-viewers.md`](../../dialog-inventory/03-detail-viewers.md). Do not invent another dialog shell, use raw `AlertDialog` / `showDialog`, or keep duplication merely to shrink the diff. Prefer predefined components under [`frontend/lib/shared/`](../../frontend/lib/shared/) for every repeated detail pattern.

## Normative contracts (read before editing)

| Contract | Path | Authority |
| --- | --- | --- |
| Detail-viewer standardization | [`prompt.md`](prompt.md) | Shells, shared detail reuse, loading/actions, titles, verification |
| API envelopes / IDs | [`.cursor/api-contract.mdc`](../../.cursor/api-contract.mdc) | `snake_case`, `human_friendly_id`, success/error envelopes |
| Instant UI sync | [`frontend/.cursor/instant_ui_sync.mdc`](../../frontend/.cursor/instant_ui_sync.mdc) | HTTP mutate, Riverpod patch on success, WS reconcile only |
| Shared components | [`frontend/.cursor/components.mdc`](../../frontend/.cursor/components.mdc) | Reuse under `frontend/lib/shared/`; no feature forks of shared UI |
| Localization | [`frontend/.cursor/localization_i18n.mdc`](../../frontend/.cursor/localization_i18n.mdc) | All user-facing strings via l10n |
| Permissions | [`frontend/.cursor/permissions.mdc`](../../frontend/.cursor/permissions.mdc) | Preserve RBAC/ABAC wrappers; never expose unauthorized actions |
| Design system | [`frontend/.cursor/design-system.mdc`](../../frontend/.cursor/design-system.mdc) | Tokens only; responsive light/dark UI |
| Accessibility | [`frontend/.cursor/accessibility.mdc`](../../frontend/.cursor/accessibility.mdc) | Focus, semantics, keyboard, scaling, contrast |
| Feedback / failures | [`frontend/.cursor/ui-feedback.mdc`](../../frontend/.cursor/ui-feedback.mdc) | Shared async/failure states; preserve input; safe errors |
| Frontend tests | [`frontend/.cursor/testing.mdc`](../../frontend/.cursor/testing.mdc) | Widget/controller/sync/responsive coverage |
| Backend API | [`backend/.cursor/api.mdc`](../../backend/.cursor/api.mdc) | Routes, middleware, authz, public IDs |
| Backend tests | [`backend/.cursor/testing.mdc`](../../backend/.cursor/testing.mdc) | Schema/service/controller/route/event coverage |


## Target

| Field | Value |
| --- | --- |
| Symbol | `_AccessAdminUserDetailDialog` |
| Purpose | Access Admin User Detail |
| Module / surface | `access_admin` |
| Inventory kind | `custom` |
| Presentation shape | `detail_viewer` |
| Verified definition | `frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart:1514` |
| Inventory location note | Inventory and verified declaration agree at generation time. |
| Extends / uses | AppDialog / showAppDialog (typical) |
| Paired opener(s) | `_openUserDetail` |
| Primary commit | Cancel (dismiss) |
| Slices to keep in sync | access_admin user detail |
| Sibling reuse targets | `_AccessAdminRoleDetailDialog`, `_HrAccessUserDetailDialog` |
| Controllers (region) | _not detected in peek — trace widget → workspace controller → repository → backend route_ |
| Mutations (region) | `mutation: assignUserRole` |

### Used from

- _Inventory lists no *Used from* sites — keep existing private openers reachable._

### Delegated/shared implementation evidence

- `AppDialog — frontend/lib/shared/components/app_dialog.dart`
- `AppRoleAssignmentPicker — frontend/lib/shared/components/app_role_assignment_picker.dart`
- `AppConfirmActionDialog — frontend/lib/shared/actions/app_action_dialogs.dart`
- `AppPermissionAssignmentPicker — frontend/lib/shared/components/app_permission_assignment_picker.dart`

### Cross-stack trace candidates

These files mention a detected mutation/load method and are starting points, not proof of ownership. Follow interfaces/imports and route registration until the persisted path is proven.

- `frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart`
- `frontend/lib/features/access_admin/presentation/controllers/access_admin_workspace_controller.dart`
- `frontend/lib/features/access_admin/domain/repositories/access_admin_repository.dart`
- `frontend/lib/features/access_admin/data/repositories/access_admin_repository_impl.dart`
- `frontend/lib/features/hr/presentation/controllers/hr_workspace_controller.dart`
- `frontend/lib/features/hr/presentation/widgets/hr_enhanced_dialogs.dart`
- `frontend/lib/features/hr/data/repositories/hr_repository_impl.dart`
- `frontend/lib/features/hr/domain/repositories/hr_repository.dart`

## Compliance checklist (`prompt.md` — this dialog only)

### 1. Established shells
- [ ] Composed through `AppDialog` via `showAppDialog`, or `AppPatientDetailDialog` for patient-bearing surfaces, or an approved workspace helper when already the pattern.
- [ ] **No** raw `AlertDialog` / `showDialog` on this presentation path.
- [ ] Purpose, listed call sites, resolved contextual IDs, and permission wrappers are preserved.

### 2. Reuse before creating (detail uniformity)
- [ ] Repeated shells, sections, rows, states, and action groups use one canonical shared implementation; superseded local copies are removed.
- [ ] Shared barrels under `frontend/lib/shared/` were searched before adding widgets; canonical APIs are extended, not copied or trivially wrapped.
- [ ] Body uses the **Shared building blocks** below when equivalents exist (info sheets, section panels, patient details, status, timeline, report preview, etc.).
- [ ] If no shared primitive exists and another inventory detail viewer needs the same UI, create one configurable, domain-neutral primitive under `frontend/lib/shared/`; keep domain behavior in controllers.
- [ ] If this viewer surfaces a person/patient, keep the chrome title role-based and put identity in shared detail components.

### 3. Loading and actions
- [ ] Loading uses only `AppLoadingIndicator` or `AppLoadingSurface`; async actions use `AppButton.isLoading`. **No** `CircularProgressIndicator` / `LinearProgressIndicator`.
- [ ] While loading: Cancel, close, and competing actions are disabled; `closeEnabled: false`.
- [ ] Footer order left→right: optional **secondary** actions, then **Cancel**. No invented primary mutation commit.
- [ ] Every `AppButton` has a leading icon and localized label. Use `AppActionIcons` for shared verbs; match sibling detail viewers in `access_admin`.
- [ ] Labels: **Cancel** (not Close), **Edit** (not Update).

### 4. Titles
- [ ] Title is general / role-based — **never** a patient or staff personal name.
- [ ] Title is passed through `AppDialog` for uppercase normalization; icon matches sibling conventions in this module when peers already use icons.
- [ ] Person identity lives in `AppPatientDetails` / info sheets inside the body, not in the chrome title.

### 5. Design, responsiveness, localization, and accessibility
- [ ] No hard-coded user-facing copy or private feature string holder; labels, hints, errors, tooltips, and semantics use generated l10n.
- [ ] No hard-coded color, spacing, radius, elevation, typography, date, number, or currency formatting; use theme/design tokens and shared formatters.
- [ ] Content and actions remain usable on mobile, tablet, desktop, dark mode, text scaling, and constrained-height layouts without overflow.
- [ ] Keyboard order is logical, focus is trapped/restored by the dialog shell, visible focus remains, icon-only controls have localized semantics, and status is not conveyed by color alone.

### 6. Backend correctness and sync
- [ ] Every load path is traced end-to-end: dialog → workspace controller → repository/DTO → real backend route/schema/service.
- [ ] IDs, `snake_case` payloads, auth, envelopes, and response decoding match [`.cursor/api-contract.mdc`](../../.cursor/api-contract.mdc); either side is fixed when mismatched.
- [ ] Widgets never call APIs or own competing server data. Reads via controllers/Riverpod; WebSockets only reconcile ([`instant_ui_sync.mdc`](../../frontend/.cursor/instant_ui_sync.mdc)).
- [ ] On failure: dialog stays open, `AppFailure` is shown through shared failure UI, and **nothing** is patched.
- [ ] Detail viewers usually do not mutate. If a secondary action persists: patch access_admin user detail only after HTTP success, then apply the smallest targeted reconciliation.
- [ ] Cancel / failure neither patches nor dismisses as if saved.

### 7. Reachability and verification
- [ ] Still reachable from every paired opener and *Used from* site listed above.
- [ ] `frontend/test/shared/layout/workspace_ui_pattern_test.dart` stays green. Add focused widget, controller, DTO, and (when the stack is touched) backend route/schema/service tests for this dialog's path.

## Compliance snapshot (heuristic — verify in code)

| Signal | Observation |
| --- | --- |
| Approved shell signals | `AppDialog`, approved `show*` helper |
| Raw `showDialog` / `AlertDialog` | not seen in peek |
| Raw Material progress indicator | yes — replace |
| Title snippets | `l10n.accessAdminUserAccessAddRoleDialogTitle`, `l10n.accessAdminUserAccessRemoveRoleConfirmTitle`, `l10n.accessAdminUserAccessAddDirectPermissionDialogTitle`, `l10n.accessAdminCreateUserDetailsSectionTitle` |
| `AppButton` variants (order seen) | primary -> secondary -> primary -> secondary -> primary -> secondary -> secondary -> secondary |
| `AppActionIcons` | seen |
| `closeEnabled: false` | yes |
| Loading primitives | seen |
| Direct widget repository read | not seen |
| Delegated components scanned | 4 |
| Cross-stack trace files found | 8 |
| Peek region size | 32546 chars |

### Priority gaps to close

1. Raw Material progress indicator detected — replace with `AppLoadingIndicator` / `AppLoadingSurface` / `AppButton.isLoading` only.
2. Possible Close label — chrome abort must be Cancel
3. No `AppInfoSheet*` / `AppSectionPanel` delegation detected — replace bespoke key/value and section chrome with shared detail primitives.

### Dialog-specific focus

- Compose `AppUserAccessPanel` / permission grouped views; no local access chrome.

## Shared building blocks (mandatory reuse)

Prefer these over new one-offs (`prompt.md` Requirement 2):

- **Detail layout:** `AppPatientDetails`, `AppPatientDetailDialog`, `AppSectionPanel`, `AppContentPanel`, `AppMessagePanel`, `AppInfoSheetGrid` / `AppInfoSheetRow`, `AppInfoTileGrid` / `AppInfoTile`, `AppExpandableRecordSection`, `AppCopyableIdentifier`
- **Status / history / clinical preview:** `AppStatusBadge` / `AppStatusText`, `AppTimeline`, `AppClinicalResultsPreview`
- **Reports / print previews:** `AppReportPreviewPanel`, `AppReportSummaryGrid`, `AppReportActionButton`, `AppReportSectionTile` / picker helpers
- **Action groups:** `AppActionPanel` / `AppActionSection`, permission action components, `buildAppDialogFormActions` when an edit handoff fits
- **Async / empty / error:** `AppLoadingIndicator` / `AppLoadingSurface`, shared state panels (`AppStateView` / workspace state panels) — never raw Material progress
- **Approved shells / openers:** `showAppDialog`, `AppPatientDetailDialog`, `showAppWorkspaceActionDialog` / `showAppWorkspaceMutationDialog` when already the workspace pattern, and existing `show*` / `open*` detail helpers

Shell / detail chrome references:

- `AppDialog` / `showAppDialog` — `frontend/lib/shared/components/app_dialog.dart`
- `AppPatientDetailDialog` — `frontend/lib/shared/components/app_patient_detail_dialog.dart`
- `AppPatientDetails` — `frontend/lib/shared/components/app_patient_details.dart`
- `AppSectionPanel` / `AppContentPanel` — `frontend/lib/shared/components/app_content_panel.dart`
- `AppInfoSheetGrid` / `AppInfoSheetRow` — `frontend/lib/shared/components/app_info_sheet.dart`
- `AppInfoTileGrid` — `frontend/lib/shared/components/app_info_tile.dart`
- `AppExpandableRecordSection` — `frontend/lib/shared/components/app_record_section.dart`
- `AppCopyableIdentifier` — `frontend/lib/shared/components/app_copyable_identifier.dart`
- `AppStatusBadge` — `frontend/lib/shared/components/app_status_badge.dart`
- `AppTimeline` — `frontend/lib/shared/components/app_timeline.dart`
- `AppClinicalResultsPreview` — `frontend/lib/shared/components/app_clinical_results_preview.dart`
- `AppReportPreviewPanel` — `frontend/lib/shared/components/app_report_actions.dart`
- `AppButton` — `frontend/lib/shared/components/app_button.dart`
- `AppActionIcons` — `frontend/lib/shared/icons/app_action_icons.dart`
- Loading — `frontend/lib/shared/components/app_loading_indicator.dart` (+ `AppLoadingSurface`)
- Title casing — `frontend/lib/core/utils/app_dialog_title.dart`

Prefer existing openers and shared detail helpers over copying chrome into a feature folder.

## Execution plan

You are a coding agent with full read/write access to this repo. Execute every step. Do not ask for clarification. Treat the normative contracts table as binding.

**Scope lock:** only `_AccessAdminUserDetailDialog` and the minimum call-site / shared-helper edits required for compilation and compliance. Do **not** expand to unrelated inventory rows. Shared extracts are allowed only when required for reuse and must stay domain-neutral under `frontend/lib/shared/`.

### Shape rules for `detail_viewer`

- Compose through approved shells only — never raw `AlertDialog` / `showDialog`.
- Titles are general/role-based, passed through `AppDialog` for uppercase normalization — never patient or staff personal names.
- Loading uses only `AppLoadingIndicator` / `AppLoadingSurface` / `AppButton.isLoading` — never `CircularProgressIndicator` / `LinearProgressIndicator`.
- While loading: disable Cancel, close, and competing actions; `closeEnabled: false`.
- Footer L→R: optional secondary actions → **Cancel**. Do not invent a primary mutation commit.
- Every `AppButton` needs a leading icon (`AppActionIcons` when mapped) and localized label.
- Widgets never call APIs; reads go through controllers/Riverpod; WebSockets only reconcile.
- Replace bespoke label/value lists with `AppInfoSheetGrid` / `AppInfoSheetRow` / `AppInfoTileGrid`.
- Section chrome must use `AppSectionPanel` / `AppContentPanel`; long records use `AppExpandableRecordSection`.
- Read-only detail: prefer Cancel-only footer unless Edit/Print/Navigate already exist.
- Patient-bearing bodies must compose `AppPatientDetails` and/or `AppPatientDetailDialog`.
- Status via `AppStatusBadge` / `AppStatusText`; IDs via `AppCopyableIdentifier`.

### Steps

1. **Read contracts + source**
   - Read every contract in the **Normative contracts** table. Apply each rule to files matching its scope; do not treat this prompt as a substitute for project rules.
   - Read `_AccessAdminUserDetailDialog` at `frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart:1514` and every paired opener / *Used from* site.
   - Inspect every delegated/shared implementation and trace candidate above, then follow imports/interfaces/routes beyond those candidates as needed.
   - Trace each load (and any real mutation): dialog → controller → repository/DTO → backend route/schema/service → decode → Riverpod.

2. **Normalize shell (Req 1)**
   - Compose with `AppDialog` / `AppPatientDetailDialog` / approved helpers; open with `showAppDialog` as appropriate.
   - Remove raw `AlertDialog` / `showDialog` on this path.
   - Preserve purpose, contextual IDs, and permission wrappers.

3. **Normalize title + icon (Req 4)**
   - General role/flow title for **Access Admin User Detail** — never personal display name.
   - Pass title through the shell for uppercase normalization.
   - Match sibling icon conventions in `access_admin`.

4. **Normalize loading + footer (Req 3)**
   - Shared loading primitives only; rebuild actions with `AppButton` + `AppActionIcons` + l10n.
   - Order: secondary → **Cancel** (`Cancel (dismiss)`).
   - In flight: disable Cancel/close/competitors; `closeEnabled: false`.

5. **Reuse shared detail primitives (Req 2 — hard)**
   - Replace bespoke key/value blocks, section chrome, status chips, timelines, and preview bodies with the Shared building blocks above.
   - Cross-check sibling reuse targets: `_AccessAdminRoleDetailDialog`, `_HrAccessUserDetailDialog`.
   - Extract under `frontend/lib/shared/` only when multiple inventory detail viewers need the same UI.
   - Delete superseded local widgets after migration.

6. **Behavior + permissions**
   - Openers pass already-resolved contextual IDs (`human_friendly_id` / domain IDs).
   - Preserve parent permission wrappers; do not expose unauthorized actions.

7. **Design + accessibility**
   - Use generated l10n, theme/design tokens, shared formatters, and responsive layout primitives only.
   - Verify keyboard/focus/semantics, text scaling, dark mode, constrained height, and mobile/tablet/desktop layouts.

8. **Backend + sync (Req 5)**
   - Widgets read Riverpod and delegate to controllers; no widget API calls.
   - Happy-path loads must succeed against the real contract; fix either side on mismatch.
   - Failure → shared `AppFailure` UI, no patch, dialog stays open.
   - Do not invent mutations. If a secondary action already persists → patch access_admin user detail only after success.
   - Cancel/failure never present false success.

9. **Preserve reachability**
   - Do not break `_openUserDetail`. Update all call sites in the same change when signatures move.

10. **Verify**
   - Analyzer clean on touched files.
   - `frontend/test/shared/layout/workspace_ui_pattern_test.dart` green.
   - Run focused Flutter widget/controller/DTO tests plus backend tests for every touched stack layer. Add missing tests; never rely on production services or secrets.
   - Load happy-path succeeds; cancel/failure neither patches nor dismisses as saved.
   - Verify responsive, keyboard, focus, semantics, text-scale, and dark-mode behavior for changed dialog UI.
   - Equivalent detail viewers share primitives, spacing, sections, action icons/labels, loading/error behavior, and responsive layout.
   - Tick every checklist item above before finishing.

## Acceptance criteria (all must pass)

1. `_AccessAdminUserDetailDialog` opens only through `AppDialog` / `AppPatientDetailDialog` / approved helpers — no raw Material dialog APIs.
2. Footer is optional secondary actions → **Cancel**; labels are Cancel/Edit (not Close/Update); no invented primary mutation.
3. Loading uses only shared spinner primitives; dismiss and competing actions are blocked while in flight.
4. Title is general, uppercase-normalized, and never a personal name.
5. All copy is localized; all styling/formatting uses shared tokens/formatters; responsive and accessible behavior is verified.
6. Body sections reuse canonical shared detail primitives; no unjustified local forks (siblings considered: `_AccessAdminRoleDetailDialog`, `_HrAccessUserDetailDialog`).
7. Still reachable from inventory openers / *Used from* sites with contextual IDs and permissions intact.
8. Load paths use the real API contract; dismiss/local actions do not patch server state.
9. No provider patch is introduced for a non-mutating/local-only detail view; realtime reconcile only when already required.
10. `frontend/test/shared/layout/workspace_ui_pattern_test.dart` remains green; focused frontend/backend tests cover this dialog's critical path.

## Out of scope

- Other inventory rows (unless a minimal shared extract is required for reuse).
- New dialog frameworks, unrelated redesigns, or drive-by refactors outside `_AccessAdminUserDetailDialog`'s path.
- Client-only "saved" state not backed by HTTP success.
- Retaining duplicate local UI solely to shrink the diff.
- Inventing mutations on a read-only detail viewer.

## Deliverable

Implement the compliance fixes in the repo. Summarize: files changed; shell/title/footer/loading/reuse/sync fixes; design/localization/accessibility fixes; shared extracts; API/DTO/route fixes; tests added and run; exact commands and results; remaining risks (or explicitly state none). Append the project rule files applied and the model used.

<!-- generator: detail-viewer prompt 03 slug=access-admin-user-detail-dialog symbol=_AccessAdminUserDetailDialog shape=detail_viewer -->
