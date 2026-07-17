# Detail viewers — standardization

Refactor the 52 definitions in [`dialog-inventory/03-detail-viewers.md`](../../dialog-inventory/03-detail-viewers.md) into one reusable product surface. This is structural, not cosmetic.

## Scope

Change inventoried definitions, listed call sites, and shared primitives for consolidation. Do not touch unrelated dialogs, create another shell, use raw `AlertDialog`/`showDialog`, or keep duplication to shrink the diff.

## Requirements

1. **Use established shells**
   - Compose [`AppDialog`](../../frontend/lib/shared/components/app_dialog.dart) through `showAppDialog`.
   - Prefer `AppPatientDetailDialog` for patient-bearing detail surfaces, and `showAppWorkspaceActionDialog` / `showAppWorkspaceMutationDialog` only when the opener already belongs to that workspace pattern.
   - Preserve each row’s purpose, call sites, resolved contextual IDs, and permission wrappers.

2. **Reuse before creating (detail uniformity)**
   - Inventory repeated shells, sections, rows, states, and action groups. Choose one canonical implementation per pattern, migrate every applicable viewer, and remove superseded local versions.
   - Search shared barrels under `frontend/lib/shared/` before adding widgets. Extend canonical APIs; never copy, trivially wrap, or locally redefine them.
   - **Detail layout (mandatory when applicable):**
     - Patient context: `AppPatientDetails`, `AppPatientDetailDialog`
     - Sections: `AppSectionPanel`, `AppContentPanel`, `AppMessagePanel`
     - Key/value facts: `AppInfoSheetGrid` / `AppInfoSheetRow`, `AppInfoTileGrid` / `AppInfoTile`
     - Long records: `AppExpandableRecordSection`
     - Identity: `AppCopyableIdentifier` / `AppCopyableIdentifierCell` for `human_friendly_id` and other copyable IDs
     - Status: `AppStatusBadge` / `AppStatusText` (never color-only status)
     - Timeline / history: `AppTimeline`
     - Clinical results: `AppClinicalResultsPreview`
     - Reports / previews: `AppReportPreviewPanel`, `AppReportSummaryGrid`, `AppReportActionButton`, `AppReportSectionTile` / picker helpers
   - **Action groups:** `AppActionPanel` / `AppActionSection`, permission action components, `buildAppDialogFormActions` when an edit handoff fits.
   - **Async / empty / error:** `AppLoadingIndicator` / `AppLoadingSurface`, shared state panels (`AppStateView` / workspace state panels) — never raw Material progress bars or ad-hoc empty copy.
   - If none exists, create one configurable, domain-neutral primitive under `frontend/lib/shared/` for every matching viewer. Keep domain behavior in controllers.

3. **Loading and actions**
   - Use the app’s existing spinner only: `AppLoadingIndicator` or `AppLoadingSurface`; use `AppButton.isLoading` for any in-dialog async action. Do not introduce `CircularProgressIndicator`, `LinearProgressIndicator`, or another loader.
   - While loading: disable Cancel/close and competing actions; apply `closeEnabled: false` and, for any mutating child handoff, `barrierDismissible: false`.
   - Detail viewers are primarily **read-only**. Footer order left to right: optional secondary actions (Edit, Print, Copy, Navigate…), then **Cancel**. Do not invent a primary commit mutation unless the inventory row already owns one and the backend path is proven.
   - Every `AppButton` needs a leading icon and localized label. Use `AppActionIcons` for shared verbs; match sibling detail viewers in the same module for domain actions. No iconless buttons or one-off Material icons when a shared mapping exists. Say **Cancel**, not Close, and **Edit**, not Update.

4. **Titles**
   - Use general role-based titles (e.g. Patient Detail, Billing Ledger, Bed Detail), never patient or staff personal names as the dialog title.
   - Pass titles through `AppDialog` for uppercase normalization and reuse sibling icon conventions.
   - Put person identity in `AppPatientDetails` / info sheets inside the body, not in the chrome title.

5. **Backend correctness and sync**
   - Follow [the API contract](../../.cursor/api-contract.mdc) and [`instant_ui_sync.mdc`](../../frontend/.cursor/instant_ui_sync.mdc).
   - Trace every load path end to end: dialog → workspace controller → repository/DTO → real backend route/schema/service. Match IDs, `snake_case` payloads, auth, envelopes, and response decoding; fix either side on mismatch.
   - Widgets never call APIs or own competing server data. Reads go through controllers/Riverpod; WebSockets only reconcile.
   - On failure, keep the dialog open, show `AppFailure` through shared failure UI, and patch nothing. Never fake or silently ignore success.
   - Detail viewers usually do not mutate. If a secondary action persists, patch every affected Riverpod slice only after HTTP success, then apply the smallest targeted refresh/realtime reconciliation. Workspaces, pinned views, lists, details, and badges must match backend truth without a full reload.

## Verification

Keep the workspace pattern test green. Add focused widget, controller, DTO, backend route/schema, and service tests when the stack is touched. Verify load happy-path succeeds and cancel/failure neither patches nor dismisses as saved. Confirm equivalent detail viewers share primitives, spacing, sections, action icons/labels, loading/error behavior, and responsive layout without duplicates.
