# Patient encounter flow — dialog standardization

Standardize every dialog listed in [`dialog-inventory/02-patient-encounter-flow.md`](dialog-inventory/02-patient-encounter-flow.md) so encounter UX feels like one product surface, not a patchwork of feature-local modals.

**Scope:** only those inventory rows (41 definitions across emergency, housekeeping, ICU, IPD, OPD, patients, reception, rooms/beds, and shared OPD/patient/triage helpers). Do not expand to the full 304-dialog catalog unless the inventory file is updated first.

**Non-goals:** inventing a new dialog shell, introducing raw `AlertDialog` / `showDialog` in feature code, or duplicating shared clinical/OPD/patient UI inside feature folders.

---

## Platform rules (do not fight the stack)

1. **Shell** — Compose [`AppDialog`](frontend/lib/shared/components/app_dialog.dart) via `showAppDialog`, or the higher helpers when they fit:
   - `showAppWorkspaceMutationDialog` — form + submit/cancel + failure banner
   - `AppConfirmActionDialog` / text / select / text-input variants — confirmations and simple actions
   - Prefer existing openers in `shared/opd_actions`, `shared/patient_actions`, and `shared/components` over copying chrome into a feature.

2. **Buttons** — There are no separate Create/Edit/Delete button widgets. Reuse:
   - [`AppButton`](frontend/lib/shared/components/app_button.dart) (`primary` / `secondary` / `tertiary`)
   - [`AppActionIcons`](frontend/lib/shared/icons/app_action_icons.dart) for leading icons
   - Shared action builders when applicable (`clinicalActionDialogActions`, mutation/confirm helpers)
   - Localized labels via `context.l10n` (e.g. `commonCancelActionLabel`)

3. **Pattern tests** — Keep `frontend/test/shared/layout/workspace_ui_pattern_test.dart` green: no raw Material dialog APIs in feature presentation code.

---

## 1. Footer actions

Footer actions are the `AppDialog.actions` list (right-aligned by the shell). Order left → right as users read:

| Position | Role | Notes |
| --- | --- | --- |
| Leftmost | Dialog-specific secondary actions | Extra steps unique to that dialog (print, correct stage, etc.) |
| Middle | Standard mutating actions (when present) | Prefer one clear primary. If several apply: Create → Edit → Delete. Label Edit **Edit**, not Update. Omit unused actions. |
| Rightmost | Dismiss / abort | Always labeled **Cancel** (never Close). Use `AppButton` secondary or tertiary + `AppActionIcons.cancel`. Cancel aborts without committing. |

**Primary / confirm:** the committing action sits immediately left of Cancel only when Cancel is present; otherwise it is rightmost. Use `AppButton.primary`, with loading via `isLoading`. Destructive confirms use error coloring + delete icon patterns already used by `AppConfirmActionDialog` / `_actionDialogButtons`.

**Confirm dialogs:** one Confirm (or domain verb) + Cancel — no duplicate “save then confirm” pairs in the same footer.

Match the established helpers: **Cancel left of primary**, not Cancel on the far right of the whole footer row ahead of primary.

---

## 2. Titles

- Prefer **role-based, general titles** over entity-specific strings (e.g. “OPD Flow”, “Patient Details” — not the patient’s personal name as the dialog title).
- Pass titles through `AppDialog` so [`toDialogTitleUppercase`](frontend/lib/core/utils/app_dialog_title.dart) keeps header casing consistent.
- Use a meaningful `icon` on the shell when siblings in the same flow already do.

---

## 3. Loading and dismissibility

- While a mutation or initial load is in flight, show loading with shared primitives (`AppButton.isLoading`, [`AppLoadingIndicator`](frontend/lib/shared/components/app_loading_indicator.dart) / `AppLoadingSurface`) and short contextual copy where helpful.
- Block dismiss until the in-flight work finishes: disable Cancel / close (`closeEnabled: false` when needed), set `barrierDismissible: false` on the opener for mutating dialogs, and disable competing footer actions.
- After success or failure, refresh the dialog’s own state and invalidate/refetch Riverpod providers so parent workspaces stay current — do not leave stale encounter/queue/bed data on screen.

---

## 4. Component reuse (mandatory)

Prefer existing shared building blocks over new one-offs:

- Patient chrome: `AppPatientDetails` / `AppPatientDetailDialog`
- Encounter / flow hubs: `OpdEncounterDialog`, `FlowActionsDialog`, OPD appointment/stage dialogs under `shared/opd_actions/`
- Triage / vitals: `AppTriageActionDialog`, `RecordVitalsDialog` / `app_record_vitals_dialog`, `AppVitalsForm`
- Status / forms / layout: `AppStatusBadge`, shared form fields, workspace mutation/confirm helpers

If two inventory dialogs need the same section, extract or reuse once under `frontend/lib/shared/` — do not fork the UI per feature.

---

## 5. Behavior and data

- Open with the correct contextual IDs (patient, encounter, queue item, bed, appointment) already resolved; any wait should be network/IO, not re-deriving context in the dialog body.
- Dialog purpose must match inventory intent (arrival, handoff, transfer, disposition, registration, etc.).
- Keep permission-aware actions behind existing permission wrappers where the surrounding workspace already uses them.

---

## 6. Backend / frontend sync (hard requirement)

Every patient-encounter dialog action must keep UI state and persisted backend state aligned. Follow [`frontend/.cursor/instant_ui_sync.mdc`](frontend/.cursor/instant_ui_sync.mdc):

1. **HTTP is the mutation path** — dialogs/controllers write through repositories over the existing REST APIs. Do not invent client-only state that pretends a save succeeded.
2. **All API calls must succeed for the happy path** — request payloads, routes, auth, and response parsing must match the owning backend module. A dialog is not done if Create/Edit/Delete/Confirm (or load-on-open) fails against a healthy API. Fix the contract, DTO, or call site — do not paper over with silent ignore or fake local success.
3. **Surface failures** — on `AppFailure` / non-success, show the shared failure pattern (banner / confirm helper), leave data unpatched, and keep the dialog usable for retry or Cancel.
4. **Patch on success only** — when `saved == true` (or equivalent success), update every affected Riverpod slice immediately from the response or a typed local delta (encounter, queue, bed, appointment, patient, badges). Cancel and failure must not patch.
5. **Stay in sync after close** — parent workspaces, pinned encounter dialogs, and related lists must reflect the new backend truth without a manual full-app reload; use targeted provider patches / refresh plans, with realtime reconciliation where the module already publishes events.
6. **No dual sources of truth** — widgets read authoritative data from Riverpod; do not keep a competing “dialog-local” copy of server entities that drifts from providers after a successful API round-trip.

---

## Acceptance checklist (per inventory row)

For each symbol in `02-patient-encounter-flow.md`:

1. Opens through `AppDialog` / approved helpers only.
2. Footer order and Cancel/primary semantics match §1.
3. Title is general + uppercase-normalized; no patient name as title.
4. Loading blocks dismiss; UI and providers update after mutations.
5. Body sections reuse shared components where equivalents exist.
6. Still reachable from the *Used from* call sites listed in the inventory.
7. Every load and mutation API used by the dialog succeeds on the happy path against the real backend contract; failures are shown, not ignored.
8. After a successful mutation, frontend Riverpod state matches backend persistence (dialog + parent workspaces); no stale encounter/queue/bed/patient data remains.

When all rows pass, patient-encounter dialogs should read as one consistent clinical flow across modules, with UI and API state staying in sync.
