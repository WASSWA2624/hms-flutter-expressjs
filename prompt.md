# Patient encounter dialogs — standardization

Refactor the 41 definitions in [`dialog-inventory/02-patient-encounter-flow.md`](dialog-inventory/02-patient-encounter-flow.md) into one reusable product surface. This is structural, not cosmetic.

## Scope

Change inventoried definitions, listed call sites, and shared primitives for consolidation. Do not touch unrelated dialogs, create another shell, use raw `AlertDialog`/`showDialog`, or keep duplication to shrink the diff.

## Requirements

1. **Use established shells**
   - Compose [`AppDialog`](frontend/lib/shared/components/app_dialog.dart) through `showAppDialog`.
   - Prefer `showAppWorkspaceMutationDialog`, `showAppWorkspaceActionDialog`, `AppConfirmActionDialog` variants, and existing `show*`/`open*` encounter helpers.
   - Preserve each row’s purpose, call sites, resolved contextual IDs, and permission wrappers.

2. **Reuse before creating**
   - Inventory repeated shells, sections, rows, forms, states, and action groups. Choose one canonical implementation per pattern, migrate every applicable flow, and remove superseded local versions.
   - Search shared barrels and encounter flows before adding widgets. Extend canonical APIs; never copy, trivially wrap, or locally redefine them.
   - Details: `AppPatientDetails`, `AppPatientDetailDialog`, `AppSectionPanel`, `AppContentPanel`, `AppInfoSheetGrid`/`Row`, `AppInfoTileGrid`, and `AppExpandableRecordSection`.
   - Action groups: `AppActionPanel`/`Section`, permission action components, `clinicalActionDialogActions`, `buildAppDialogFormActions`, and `buildAppDialogWizardActions`.
   - Clinical UI: `OpdEncounterDialog`, `FlowActionsDialog`, shared OPD openers, triage components, `AppRecordVitalsDialog`, `AppVitalsForm`, `AppStatusBadge`, shared fields, and `AppFormInformationBanner`.
   - If none exists, create one configurable, domain-neutral primitive under `frontend/lib/shared/` for every matching flow. Keep domain behavior in controllers.

3. **Loading and actions**
   - Use the app’s existing spinner only: `AppLoadingIndicator` or `AppLoadingSurface`; use `AppButton.isLoading` for submission. Do not introduce `CircularProgressIndicator` or another loader.
   - While loading or saving, disable Cancel, close, and competing actions; apply `closeEnabled: false` and `barrierDismissible: false`.
   - Order actions left to right: secondary actions, **Cancel**, primary commit. Prefer one commit; use Create → Edit → Delete only when multiple mutations are essential.
   - Every `AppButton` needs a leading icon and localized label. Use `AppActionIcons` for shared verbs; match sibling encounter flows for domain actions. No iconless buttons or one-off Material icons when a shared mapping exists. Say **Cancel**, not Close, and **Edit**, not Update. Confirmation dialogs have one domain verb/Confirm plus Cancel.

4. **Titles**
   - Use general role-based titles, never patient names. Pass titles through `AppDialog` for uppercase normalization and reuse sibling icon conventions.

5. **Backend correctness and sync**
   - Follow [the API contract](.cursor/api-contract.mdc) and [`instant_ui_sync.mdc`](frontend/.cursor/instant_ui_sync.mdc).
   - Trace every load/mutate path end to end: dialog → workspace controller → repository/DTO → real backend route/schema/service. Match IDs, `snake_case` payloads, auth, envelopes, and response decoding; fix either side on mismatch.
   - Widgets never call APIs or own competing server data. Mutate over HTTP; WebSockets only reconcile.
   - On failure, keep the dialog open, show `AppFailure` through shared failure UI, and patch nothing. Never fake or silently ignore success.
   - On persisted success only, immediately patch every affected Riverpod slice, then apply the smallest targeted refresh/realtime reconciliation. Dialogs, parent workspaces, pinned views, lists, details, and badges must match backend truth without a full reload.

## Verification

Keep the workspace pattern test green. Add focused widget, controller, DTO, backend route/schema, and service tests. Verify happy-path API calls succeed and cancel/failure neither patches nor dismisses. Confirm equivalent flows share primitives, spacing, sections, action icons/labels, loading/error behavior, and responsive layout without duplicates.
