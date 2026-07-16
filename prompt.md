# Patient encounter dialogs — standardization

Standardize every definition in [`dialog-inventory/02-patient-encounter-flow.md`](dialog-inventory/02-patient-encounter-flow.md) so each patient encounter flow behaves like one product surface.

## Scope

Change only the 41 inventoried definitions and their listed call sites. Do not expand to the full dialog catalog unless the inventory is updated. Do not create a new shell, use raw `AlertDialog`/`showDialog` in feature presentation code, or duplicate shared clinical UI.

## Implementation rules

1. **Shells and helpers**
   - Compose [`AppDialog`](frontend/lib/shared/components/app_dialog.dart) through `showAppDialog`.
   - Prefer `showAppWorkspaceMutationDialog`, `AppConfirmActionDialog` variants, and existing openers in `shared/opd_actions`, `shared/patient_actions`, or `shared/components`.
   - Keep `frontend/test/shared/layout/workspace_ui_pattern_test.dart` green.

2. **Actions**
   - Use [`AppButton`](frontend/lib/shared/components/app_button.dart), [`AppActionIcons`](frontend/lib/shared/icons/app_action_icons.dart), shared action builders, and `context.l10n`.
   - Prefer one clear committing action. Order actions left to right: dialog-specific secondary actions, **Cancel**, then the primary/confirm action. If multiple mutations are unavoidable, order them Create → Edit → Delete and keep the primary last.
   - Label dismissal **Cancel**, never Close; it must not commit. Label editing **Edit**, never Update.
   - Use `AppButton.primary` for commit, `isLoading` while submitting, and established error-colored delete patterns for destructive confirmation.
   - A confirmation footer contains one domain verb/Confirm plus Cancel—never both Save and Confirm.

3. **Titles**
   - Use general role-based titles such as “OPD Flow” or “Patient Details,” never a patient name.
   - Pass titles through `AppDialog` for `toDialogTitleUppercase`; add a meaningful shell icon where sibling dialogs use one.

4. **Loading**
   - Use `AppButton.isLoading`, `AppLoadingIndicator`, or `AppLoadingSurface`.
   - During initial load or mutation, disable Cancel, close, and competing actions; use `closeEnabled: false` and `barrierDismissible: false` where applicable.

5. **Reuse**
   - Reuse `AppPatientDetails`, `AppPatientDetailDialog`, `OpdEncounterDialog`, `FlowActionsDialog`, shared OPD action dialogs, `AppTriageActionDialog`, record-vitals components, `AppVitalsForm`, `AppStatusBadge`, and shared form/layout helpers.
   - If two dialogs need the same section, extract it once under `frontend/lib/shared/`.

6. **Behavior and data**
   - Open with resolved patient, encounter, queue, bed, or appointment IDs.
   - Preserve each inventory row’s purpose, listed call sites, and existing permission wrappers.
   - Follow [`frontend/.cursor/instant_ui_sync.mdc`](frontend/.cursor/instant_ui_sync.mdc): mutate through repository REST APIs; match backend routes, DTOs, auth, and response parsing.
   - Never fake success or silently ignore failure. Show the shared failure UI, patch nothing, and allow retry or Cancel.
   - On confirmed success only, update all affected Riverpod state immediately and invalidate/refetch as needed. Dialogs, parent workspaces, pinned views, badges, and related lists must match persisted backend state without a full reload. Avoid competing local copies of server entities.

## Done when

Every inventoried dialog uses an approved shell, consistent title/actions/loading, shared components, working real API calls, visible failures, and synchronized Riverpod/backend state while remaining reachable from every listed call site.
