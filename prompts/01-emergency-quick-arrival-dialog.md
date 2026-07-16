# Standardize `QuickArrivalDialog` — Quick Arrival (emergency).

## Objective

Deeply refactor **`QuickArrivalDialog`** (Patient/encounter flow: Quick Arrival (emergency).) so it **100% complies** with [`prompt.md`](../prompt.md) — the patient-encounter dialog standardization contract. This is structural, not cosmetic: consolidate onto the established product surface used by the rest of [`dialog-inventory/02-patient-encounter-flow.md`](../dialog-inventory/02-patient-encounter-flow.md). UI state and backend persistence must stay aligned per [`frontend/.cursor/instant_ui_sync.mdc`](../frontend/.cursor/instant_ui_sync.mdc) and [`.cursor/api-contract.mdc`](../.cursor/api-contract.mdc).

## Compliance checklist (from `prompt.md` — this dialog only)

### 1. Established shells
- [ ] Composed through `AppDialog` and opened with `showAppDialog`, or an approved helper: `showAppWorkspaceMutationDialog`, `showAppWorkspaceActionDialog`, `AppConfirmActionDialog` variants, or an existing `show*` / `open*` encounter helper.
- [ ] **No** raw `AlertDialog` / `showDialog` on this dialog's presentation path.
- [ ] Purpose, listed call sites, resolved contextual IDs, and permission wrappers are preserved.

### 2. Reuse before creating
- [ ] Repeated shells, sections, rows, forms, states, and action groups use one canonical implementation; superseded local copies are removed.
- [ ] Shared barrels and encounter flows were searched before adding widgets; canonical APIs are extended, not copied or trivially wrapped.
- [ ] Body uses shared details/layout, action-group, and clinical UI primitives listed under **Shared building blocks** when equivalents exist.
- [ ] If no shared primitive exists and another inventory dialog needs the same UI, create one configurable, domain-neutral primitive under `frontend/lib/shared/`; keep domain behavior in controllers.

### 3. Loading and actions
- [ ] Loading uses only `AppLoadingIndicator` or `AppLoadingSurface`; submission uses `AppButton.isLoading`. **No** `CircularProgressIndicator` or other loaders.
- [ ] While loading or saving: Cancel, close, and competing actions are disabled; `closeEnabled: false`; mutating openers use `barrierDismissible: false`.
- [ ] Footer order left→right: dialog-specific **secondary** actions, then **Cancel**, then the **primary** commit. Prefer one commit; use Create → Edit → Delete only when multiple mutations are essential.
- [ ] Actions use `AppButton` + `AppActionIcons` + localized labels. Label is **Cancel** (not Close) and **Edit** (not Update). Confirmation dialogs: one domain verb/Confirm + Cancel.
- [ ] Prefer `clinicalActionDialogActions` / `buildAppDialogFormActions` / `buildAppDialogWizardActions` when they fit instead of a hand-rolled footer.

### 4. Titles
- [ ] Title is general / role-based — **never** the patient's personal name.
- [ ] Title is passed through `AppDialog` for uppercase normalization; icon matches sibling conventions in this flow when peers already use icons.

### 5. Backend correctness and sync
- [ ] Every load/mutation is traced end-to-end: dialog → workspace controller → repository/DTO → real backend route/schema/service.
- [ ] IDs, `snake_case` payloads, auth, envelopes, and response decoding match [`.cursor/api-contract.mdc`](../.cursor/api-contract.mdc); either side is fixed when mismatched.
- [ ] Widgets never call APIs or own competing server data. Mutations go over HTTP; WebSockets only reconcile ([`frontend/.cursor/instant_ui_sync.mdc`](../frontend/.cursor/instant_ui_sync.mdc)).
- [ ] On failure: dialog stays open, `AppFailure` is shown through shared failure UI, and **nothing** is patched. No fake or silently ignored success.
- [ ] On persisted success only: immediately patch every affected Riverpod slice, then apply the smallest targeted refresh/realtime reconciliation. Dialog, parent workspaces, pinned views, lists, details, and badges agree with backend truth without a full reload.
- [ ] Cancel / failure neither patches nor dismisses as if saved.

### 6. Reachability and verification
- [ ] Still reachable from every paired opener and *Used from* site listed below.
- [ ] `frontend/test/shared/layout/workspace_ui_pattern_test.dart` stays green. Add focused widget, controller, DTO, and (when the stack is touched) backend route/schema/service tests for this dialog's path.

## Context for the executing agent

You are a coding AI agent with full read/write access to this Flutter HMS repo. Execute every step below. Do not ask for clarification. Treat [`prompt.md`](../prompt.md) as normative for dialog structure/UX, [`.cursor/api-contract.mdc`](../.cursor/api-contract.mdc) as normative for HTTP contracts, and [`frontend/.cursor/instant_ui_sync.mdc`](../frontend/.cursor/instant_ui_sync.mdc) as normative for Riverpod/realtime sync.

**Scope:** only `QuickArrivalDialog` and the minimum call-site / shared-helper edits required for compilation and compliance. Do **not** expand to unrelated inventory rows or invent a new dialog shell. Do not retain duplication merely to minimize the diff.

**Module / surface:** `emergency`  
**Inventory kind:** `custom`  
**Extends / uses (inventory):** AppDialog / showAppDialog (typical)  
**Action helper peek:** `clinicalActionDialogActions`  
**Controller / mutation peek:** `mutation-ish call: createQuickArrival`

## Current inventory row

| Field | Value |
| --- | --- |
| Symbol | `QuickArrivalDialog` |
| Purpose | Patient/encounter flow: Quick Arrival (emergency). |
| Defined in | `frontend/lib/features/emergency/presentation/widgets/emergency_dialogs.dart:36` |
| Kind | `custom` |
| Paired opener(s) | `_openQuickArrivalDialog` |
| Used from | see list below |

### Used from

- `frontend/lib/features/emergency/presentation/pages/emergency_workspace_page.dart`

### Source peek (heuristic — verify in code)

| Signal | Observation |
| --- | --- |
| `AppDialog` in region | yes |
| `showAppDialog` / workspace helpers | yes |
| Raw `showDialog` / `AlertDialog` | not seen in peek |
| `CircularProgressIndicator` | not seen |
| Title snippets | `EmergencyText.quickEmergencyArrival` |
| `AppButton` variants (order seen) | secondary -> primary |
| `barrierDismissible: false` | yes |
| `closeEnabled: false` | yes |
| Loading primitives | seen |

### Likely gaps vs `prompt.md`

- Peek did not flag obvious gaps; still run the full acceptance checklist — peeks are heuristic.

## Shared building blocks (mandatory reuse)

Prefer these over new one-offs (from `prompt.md` Requirement 2):

- **Details / layout:** `AppPatientDetails`, `AppPatientDetailDialog`, `AppSectionPanel`, `AppContentPanel`, `AppInfoSheetGrid` / `AppInfoSheetRow`, `AppInfoTileGrid`, `AppExpandableRecordSection`
- **Action groups:** `AppActionPanel` / `AppActionSection`, permission action components, `clinicalActionDialogActions`, `buildAppDialogFormActions`, `buildAppDialogWizardActions`
- **Clinical UI:** `OpdEncounterDialog`, `FlowActionsDialog`, shared OPD openers, triage components, `AppRecordVitalsDialog`, `AppVitalsForm`, `AppStatusBadge`, shared fields, `AppFormInformationBanner`
- **Approved shells / openers:** `showAppDialog`, `showAppWorkspaceMutationDialog`, `showAppWorkspaceActionDialog`, `AppConfirmActionDialog` variants, and existing `show*` / `open*` encounter helpers

Shell / chrome references:

- `AppDialog` — `frontend/lib/shared/components/app_dialog.dart`
- `AppButton` — `frontend/lib/shared/components/app_button.dart`
- `AppActionIcons` — `frontend/lib/shared/icons/app_action_icons.dart`
- Loading — `frontend/lib/shared/components/app_loading_indicator.dart` (+ `AppLoadingSurface` if used by siblings)
- Title casing — `frontend/lib/core/utils/app_dialog_title.dart`
- Clinical footer helper — `frontend/lib/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart`
- Form footer helper — `frontend/lib/shared/forms/app_form_shell.dart`

Prefer existing openers in `shared/opd_actions`, `shared/patient_actions`, `shared/clinical_actions`, and `shared/components` over copying chrome into a feature folder.

## Implementation steps

1. **Read contract + source**
   - Read [`prompt.md`](../prompt.md) end-to-end (Scope + Requirements 1–5 + Verification).
   - Skim [`.cursor/api-contract.mdc`](../.cursor/api-contract.mdc) and [`frontend/.cursor/instant_ui_sync.mdc`](../frontend/.cursor/instant_ui_sync.mdc) for payload/envelope and patch/reconcile rules.
   - Read `QuickArrivalDialog` at `frontend/lib/features/emergency/presentation/widgets/emergency_dialogs.dart:36` and every paired opener / *Used from* call site above.
   - Trace each load and mutation: dialog → workspace controller → repository/DTO → backend route/schema/service → response decode → Riverpod patch.

2. **Normalize shell (Requirement 1)**
   - Compose with `AppDialog` (or an approved higher helper) and open with `showAppDialog` / `showAppWorkspaceMutationDialog` / `showAppWorkspaceActionDialog` / confirm helpers as appropriate.
   - Remove any raw `AlertDialog` / `showDialog` on this presentation path.
   - Keep maximize/resize/close behavior consistent with sibling encounter dialogs unless the helper already owns it.
   - Preserve purpose, contextual IDs, and permission wrappers.

3. **Normalize title + icon (Requirement 4)**
   - Use a general, role-based title for **Quick Arrival (emergency).** (flow/action name — never the patient display name as `AppDialog` title).
   - Pass the title through the shell so uppercase normalization applies.
   - Add/keep a meaningful `icon` if peer dialogs in `emergency` already use icons.

4. **Normalize loading + footer actions (Requirement 3)**
   - Use only `AppLoadingIndicator` / `AppLoadingSurface` / `AppButton.isLoading`.
   - Rebuild `actions` with `AppButton` + `AppActionIcons` + `context.l10n`, or an approved action helper.
   - Enforce left→right order: secondary actions → **Cancel** → primary commit. Cancel aborts without committing and is never labeled Close. Edit is never labeled Update.
   - While in flight: disable Cancel/close/competing actions; `closeEnabled: false`; `barrierDismissible: false` on mutating openers.
   - Confirm dialogs: one domain verb/Confirm + Cancel.

5. **Component reuse (Requirement 2)**
   - Replace bespoke patient/encounter/triage/vitals/status/section/action blocks with the shared primitives listed above when equivalents exist.
   - Inventory duplicates across encounter dialogs; migrate every applicable flow to the canonical implementation and delete superseded locals.
   - If this dialog duplicates UI also needed by another inventory row and no shared primitive exists, extract once under `frontend/lib/shared/` (domain-neutral, configurable) and reuse. Keep domain logic in controllers.

6. **Behavior + permissions**
   - Openers must pass already-resolved contextual IDs (patient, encounter, queue item, bed, appointment, etc.); do not re-derive identity with blocking logic inside the dialog body.
   - Preserve permission wrappers already used by the parent workspace.

7. **Backend / frontend sync (Requirement 5 — hard requirement)**
   - Widgets read from Riverpod and delegate to controllers; widgets never call APIs.
   - Mutations go through repositories over existing REST APIs only; WebSockets reconcile only.
   - Happy path: every load/mutation API used by this dialog must succeed against the real contract; fix DTO/route/schema/call site if broken.
   - On `AppFailure` / non-success: show shared failure UI, leave data unpatched, keep the dialog open for retry or Cancel.
   - On persisted success only (`saved == true` or equivalent): patch every affected Riverpod slice (encounter, queue, bed, appointment, patient, badges, lists, details) from the response or a typed delta, then apply the smallest targeted refresh/realtime reconciliation.
   - After close, parent workspaces / pinned encounter surfaces must reflect backend truth without a full-app reload.
   - Cancel and failure must neither patch nor present a false success.

8. **Preserve reachability**
   - Do not break `_openQuickArrivalDialog` or the *Used from* sites. Update signatures only when required; fix all call sites in the same change.

9. **Verify (Verification section of `prompt.md`)**
   - Run analyzer on touched files.
   - Keep `frontend/test/shared/layout/workspace_ui_pattern_test.dart` green.
   - Add or update focused widget, controller, DTO, and (if touched) backend route/schema/service tests.
   - Confirm happy-path APIs succeed; cancel/failure neither patches nor dismisses as saved.
   - Confirm equivalent flows share primitives, spacing, sections, actions, loading/error behavior, and responsive layout without duplicate UI.
   - Walk the acceptance checklist below and fix any miss before finishing.

## Acceptance criteria (must all pass)

1. `QuickArrivalDialog` opens only through `AppDialog` / approved helpers — no raw Material dialog APIs.
2. Footer order is secondary → Cancel → primary; labels are Cancel/Edit (not Close/Update); confirmations are one domain verb + Cancel.
3. Loading uses only shared spinner primitives; dismiss and competing actions are blocked while in flight.
4. Title is general, uppercase-normalized, and never a patient name.
5. Body sections and action groups reuse canonical shared primitives; no unjustified local forks.
6. Still reachable from inventory openers / *Used from* sites with contextual IDs and permissions intact.
7. Every load and mutation API succeeds on the happy path against the real backend contract; failures surface via `AppFailure` UI and patch nothing.
8. After persisted success only, Riverpod + targeted reconciliation make dialog and parent surfaces match backend truth (no stale encounter/queue/bed/patient/badge data; no full reload required).
9. `frontend/test/shared/layout/workspace_ui_pattern_test.dart` remains green; focused tests cover this dialog's critical path.

## Out of scope

- Other inventory rows (unless a shared extract is required for reuse — then keep the extract minimal, shared, and domain-neutral).
- New dialog frameworks, redesigns unrelated to compliance, or drive-by refactors outside `QuickArrivalDialog`'s path.
- Inventing client-only "saved" state that is not backed by HTTP success.
- Retaining duplicate local UI solely to shrink the diff.

## Deliverable

Implement the compliance fixes in the repo. Summarize: files changed; shell/title/footer/loading/reuse/sync fixes; any shared extracts; API/DTO/route fixes; tests added or run; and how verification was performed.

<!-- generator: encounter-dialog prompt 01 slug=emergency-quick-arrival-dialog symbol=QuickArrivalDialog -->
