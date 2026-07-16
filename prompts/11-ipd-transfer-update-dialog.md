# Standardize `TransferUpdateDialog` - Transfer Update (ipd).

## Objective

Refactor **`TransferUpdateDialog`** (Patient/encounter flow: Transfer Update (ipd).) so it fully complies with [`prompt.md`](../prompt.md) - the patient-encounter dialog standardization contract. After this prompt, the dialog must feel like the same product surface as the rest of the inventory in [`dialog-inventory/02-patient-encounter-flow.md`](../dialog-inventory/02-patient-encounter-flow.md), with UI state and backend persistence staying in sync per [`frontend/.cursor/instant_ui_sync.mdc`](../frontend/.cursor/instant_ui_sync.mdc).

## Compliance checklist (from `prompt.md` - this dialog only)

- [x] Opens only through `AppDialog` / `showAppDialog` / approved helpers (`showAppWorkspaceMutationDialog`, `AppConfirmActionDialog` / text / select / text-input variants). **No** raw `AlertDialog` / `showDialog` in feature presentation code.
- [x] Footer actions use `AppButton` (`primary` / `secondary` / `tertiary`) + `AppActionIcons` where icons apply; labels via `context.l10n` (e.g. `commonCancelActionLabel`).
- [x] Footer order matches §1: dialog-specific secondary actions (left) -> mutating Create/Edit/Delete when present (Edit labeled **Edit**, not Update) -> **Cancel** dismiss/abort. Committing primary sits immediately left of Cancel when Cancel is present; destructive confirms use existing error/delete patterns.
- [x] Confirm dialogs: one Confirm (or domain verb) + Cancel - no duplicate save-then-confirm pairs in the same footer.
- [x] Title is **role-based / general** (not the patient's personal name); passed through `AppDialog` so `toDialogTitleUppercase` keeps casing consistent; meaningful `icon` when siblings in this flow already use one.
- [x] Loading / mutation in flight: shared loading primitives; `closeEnabled: false` when needed; `barrierDismissible: false` on mutating openers; competing footer actions disabled until work finishes.
- [x] After success or failure: refresh dialog state; on success only, patch/invalidate Riverpod so parent workspaces stay current; Cancel/failure must not patch.
- [x] Body reuses shared components where equivalents exist (patient chrome, encounter hubs, triage/vitals, status/forms). Extract under `frontend/lib/shared/` if two inventory dialogs need the same section - do not fork per feature.
- [x] Opens with contextual IDs already resolved (patient, encounter, queue item, bed, appointment); permission-aware actions stay behind existing wrappers.
- [x] Every load/mutation HTTP call succeeds on the happy path against the real backend contract; failures surface via shared failure banner/helper; no silent ignore / fake local success.
- [x] Still reachable from every *Used from* / opener site listed below.
- [x] `frontend/test/shared/layout/workspace_ui_pattern_test.dart` stays green for this module's presentation code.

## Context for the executing agent

You are a coding AI agent with full read/write access to this Flutter HMS repo. Execute every step below. Do not ask for clarification. Treat `prompt.md` as normative for dialog UX and `frontend/.cursor/instant_ui_sync.mdc` as normative for sync. **Scope:** only `TransferUpdateDialog` and the minimum call-site / shared-helper edits required for compilation and compliance. Do **not** expand to the full 304-dialog catalog. Do **not** invent a new dialog shell.

**Module / surface:** `ipd`  
**Inventory kind:** `custom`  
**Extends / uses (inventory):** AppDialog / showAppDialog (typical)

## Current inventory row

| Field | Value |
| --- | --- |
| Symbol | `TransferUpdateDialog` |
| Purpose | Patient/encounter flow: Transfer Update (ipd). |
| Defined in | `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart:2297` |
| Kind | `custom` |
| Paired opener(s) | `_openTransferUpdateDialog` |
| Used from | see list below |

### Used from

- `frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart`

### Source peek (heuristic - verify in code)

| Signal | Observation |
| --- | --- |
| `AppDialog` in region | yes |
| `showAppDialog` / workspace helpers | no / unclear |
| Raw `showDialog` / `AlertDialog` | not seen in peek |
| Title snippets | `l10n.ipdManageTransferAction` |
| `AppButton` variants (order seen) | tertiary -> primary |
| `barrierDismissible: false` | not seen |
| `closeEnabled: false` | not seen |
| Loading primitives | seen |

### Likely gaps vs `prompt.md`

- Confirm mutating openers set `barrierDismissible: false` while submit is in flight / for mutating dialogs.
- Loading path exists - ensure `closeEnabled: false` and disabled Cancel while mutation/load is in flight.

## Shared building blocks (mandatory reuse)

Prefer these over new one-offs:

- **Patient chrome:** `AppPatientDetails` / `AppPatientDetailDialog`
- **Encounter / flow hubs:** `OpdEncounterDialog`, `FlowActionsDialog`, OPD appointment/stage dialogs under `shared/opd_actions/`
- **Triage / vitals:** `AppTriageActionDialog`, `RecordVitalsDialog` / `app_record_vitals_dialog`, `AppVitalsForm`
- **Status / forms / layout:** `AppStatusBadge`, shared form fields, `showAppWorkspaceMutationDialog`, confirm helpers

Shell / chrome references:

- `AppDialog` - `frontend/lib/shared/components/app_dialog.dart`
- `AppButton` - `frontend/lib/shared/components/app_button.dart`
- `AppActionIcons` - `frontend/lib/shared/icons/app_action_icons.dart`
- Loading - `frontend/lib/shared/components/app_loading_indicator.dart` (+ `AppLoadingSurface` if used by siblings)
- Title casing - `frontend/lib/core/utils/app_dialog_title.dart`

Prefer existing openers in `shared/opd_actions`, `shared/patient_actions`, and `shared/components` over copying chrome into a feature folder.

## Implementation steps

1. **Read contract + source**
   - Read `prompt.md` end-to-end (especially §1 Footer, §2 Titles, §3 Loading, §4 Reuse, §5 Behavior, §6 Backend sync, Acceptance checklist).
   - Read `TransferUpdateDialog` at `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart:2297` and every paired opener / *Used from* call site above.
   - Trace the mutation path: widget -> controller/repository -> REST route -> response DTO -> Riverpod patch.

2. **Normalize shell**
   - Ensure the dialog is composed with `AppDialog` (or an approved higher helper) and opened with `showAppDialog` / `showAppWorkspaceMutationDialog` / confirm helpers as appropriate.
   - Remove any raw `AlertDialog` / `showDialog` introduced by this dialog's presentation path.
   - Keep maximize/resize/close behavior consistent with sibling encounter dialogs unless the helper already owns it.

3. **Normalize title + icon**
   - Use a general, role-based title for **Transfer Update (ipd).** (e.g. flow/action name - never the patient display name as `AppDialog` title).
   - Wire title through the shell so uppercase normalization applies.
   - Add/keep a meaningful `icon` if peer dialogs in `ipd` already use icons.

4. **Normalize footer actions**
   - Rebuild `actions` with `AppButton` + `AppActionIcons` + `context.l10n`.
   - Enforce §1 order; Cancel label must be **Cancel** (never Close); Cancel aborts without committing.
   - Primary/confirm: `AppButton.primary` with `isLoading` while submitting; destructive paths match `AppConfirmActionDialog` patterns.
   - Match established helpers: **Cancel left of primary**.

5. **Loading + dismissibility**
   - For initial load and submit: show shared loading UX; disable Cancel/close and competing actions; set `barrierDismissible: false` on mutating openers; set `closeEnabled: false` while in flight.

6. **Component reuse**
   - Replace bespoke patient/encounter/triage/vitals/status blocks with shared components listed above when equivalents exist.
   - If this dialog duplicates UI also needed by another inventory row, extract once under `frontend/lib/shared/` and reuse.

7. **Behavior + permissions**
   - Ensure openers pass resolved contextual IDs; do not re-derive identity with blocking logic inside the dialog body.
   - Preserve permission wrappers already used by the parent workspace.

8. **Backend / frontend sync (hard requirement)**
   - Mutations go through repositories over existing REST APIs only.
   - Happy path: every load/mutation API used by this dialog must succeed against the real contract; fix DTO/route/call site if broken.
   - On `AppFailure` / non-success: show shared failure UI, leave data unpatched, keep dialog usable for retry or Cancel.
   - On success only (`saved == true` or equivalent): patch every affected Riverpod slice (encounter, queue, bed, appointment, patient, badges) from response or typed delta.
   - After close, parent workspaces / pinned encounter surfaces must reflect backend truth without a full-app reload.
   - No dual sources of truth: widgets read from Riverpod after a successful round-trip.

9. **Preserve reachability**
   - Do not break ``_openTransferUpdateDialog`` or the *Used from* sites. Update signatures only when required; fix all call sites in the same change.

10. **Verify**
   - Run analyzer on touched files.
   - Run `frontend/test/shared/layout/workspace_ui_pattern_test.dart` (and any feature tests covering this dialog if present).
   - Manually walk the acceptance checklist below and fix any miss before finishing.

## Acceptance criteria (must all pass)

1. `TransferUpdateDialog` opens through `AppDialog` / approved helpers only.
2. Footer order and Cancel/primary semantics match `prompt.md` §1.
3. Title is general + uppercase-normalized; no patient name as title.
4. Loading blocks dismiss; UI + providers update after successful mutations only.
5. Body sections reuse shared components where equivalents exist.
6. Still reachable from inventory openers / *Used from* sites.
7. Every load and mutation API succeeds on the happy path; failures are shown, not ignored.
8. After success, Riverpod state matches backend persistence for dialog + parent workspaces (no stale encounter/queue/bed/patient data).
9. `frontend/test/shared/layout/workspace_ui_pattern_test.dart` remains green.

## Out of scope

- Other inventory rows (unless a shared extract is required for reuse - then keep the extract minimal and shared).
- New dialog frameworks, redesigns unrelated to compliance, or drive-by refactors outside `TransferUpdateDialog`'s path.
- Inventing client-only "saved" state that is not backed by HTTP success.

## Deliverable

Implement the compliance fixes in the repo. Summarize: files changed, footer/title/loading/sync fixes, any shared extracts, and how verification was run.

<!-- generator: encounter-dialog prompt 11 slug=ipd-transfer-update-dialog symbol=TransferUpdateDialog -->
