# Standardize `PatientPinnedOpdEncounterDialog` — Patient Pinned Opd Encounter

## Mission

Show the pinned OPD encounter surface by composing the canonical encounter dialog/opener, not a parallel body.

Bring **`PatientPinnedOpdEncounterDialog`** to **100% compliance** with [`prompt.md`](../prompt.md) (patient-encounter dialog standardization). This is **structural**, not cosmetic: consolidate onto the established product surface used across [`dialog-inventory/02-patient-encounter-flow.md`](../dialog-inventory/02-patient-encounter-flow.md). Do not invent another dialog shell, use raw `AlertDialog` / `showDialog`, or keep duplication merely to shrink the diff.

## Normative contracts (read before editing)

| Contract | Path | Authority |
| --- | --- | --- |
| Dialog standardization | [`prompt.md`](../prompt.md) | Shells, reuse, loading/actions, titles, verification |
| API envelopes / IDs | [`.cursor/api-contract.mdc`](../.cursor/api-contract.mdc) | `snake_case`, `human_friendly_id`, success/error envelopes |
| Instant UI sync | [`frontend/.cursor/instant_ui_sync.mdc`](../frontend/.cursor/instant_ui_sync.mdc) | HTTP mutate, Riverpod patch on success, WS reconcile only |
| Shared components | [`frontend/.cursor/components.mdc`](../frontend/.cursor/components.mdc) | Reuse under `frontend/lib/shared/`; no feature forks of shared UI |
| Localization | [`frontend/.cursor/localization_i18n.mdc`](../frontend/.cursor/localization_i18n.mdc) | All user-facing strings via l10n |
| Permissions | [`frontend/.cursor/permissions.mdc`](../frontend/.cursor/permissions.mdc) | Preserve RBAC/ABAC wrappers; never expose unauthorized actions |

## Target

| Field | Value |
| --- | --- |
| Symbol | `PatientPinnedOpdEncounterDialog` |
| Purpose | Patient Pinned Opd Encounter |
| Module / surface | `shared/opd_actions` |
| Inventory kind | `shared` |
| Presentation shape | `widget_dialog` |
| Defined in | `frontend/lib/shared/opd_actions/opd_encounter_flow.dart:75` |
| Extends / uses | AppDialog / showAppDialog (typical) |
| Paired opener(s) | `showPatientPinnedOpdEncounterDialog` |
| Primary commit | Delegates to encounter actions |
| Slices to keep in sync | pinned encounter view, underlying encounter slices |
| Sibling reuse targets | `OpdEncounterDialog`, `showOpdEncounterDialog` |
| Action helper peek | _none detected — adopt an approved action helper when the footer fits_ |
| Controllers (region) | `opdRepositoryProvider` |
| Mutations (region) | `mutation: cancelEncounter`, `mutation: closeEncounter`, `mutation: submitOpdEncounter`, `mutation: cancelOpdEncounter`, `mutation: closeOpdEncounter` |

### Used from

- _Inventory lists no *Used from* sites — keep existing private openers reachable._

## Compliance checklist (`prompt.md` — this dialog only)

### 1. Established shells
- [ ] Composed through `AppDialog` via `showAppDialog`, or an approved helper: `showAppWorkspaceMutationDialog`, `showAppWorkspaceActionDialog`, `AppConfirmActionDialog` / `AppSelectActionDialog` / `AppTextActionDialog` / `AppTriageActionDialog`, or an existing `show*` / `open*` encounter helper.
- [ ] **No** raw `AlertDialog` / `showDialog` on this presentation path.
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
- [ ] Every `AppButton` has a leading icon and localized label. Use `AppActionIcons` for shared verbs; match sibling encounter flows for domain actions.
- [ ] Labels: **Cancel** (not Close), **Edit** (not Update). Confirmation dialogs: one domain verb/Confirm + Cancel.
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
- [ ] Still reachable from every paired opener and *Used from* site listed above.
- [ ] `frontend/test/shared/layout/workspace_ui_pattern_test.dart` stays green. Add focused widget, controller, DTO, and (when the stack is touched) backend route/schema/service tests for this dialog's path.

## Compliance snapshot (heuristic — verify in code)

| Signal | Observation |
| --- | --- |
| Approved shell signals | `AppDialog`, approved `show*` helper |
| Raw `showDialog` / `AlertDialog` | not seen in peek |
| `CircularProgressIndicator` | not seen |
| Title snippets | `l10n.opdWalkInDialogTitle`, `l10n.opdLoadingTitle` |
| `AppButton` variants (order seen) | secondary -> primary |
| `AppActionIcons` | seen |
| `barrierDismissible: false` | yes |
| `closeEnabled: false` | yes |
| Loading primitives | seen |
| Peek region size | 9335 chars |

### Priority gaps to close

1. Footer may be hand-rolled — prefer `clinicalActionDialogActions`, `buildAppDialogFormActions`, or `buildAppDialogWizardActions` when they fit.

### Dialog-specific focus

- Must wrap/reuse `OpdEncounterDialog` / `showOpdEncounterDialog` rather than duplicate clinical sections.
- Preserve `showPatientPinnedOpdEncounterDialog` signature and pin identity.

## Shared building blocks (mandatory reuse)

Prefer these over new one-offs (`prompt.md` Requirement 2):

- **Details / layout:** `AppPatientDetails`, `AppPatientDetailDialog`, `AppSectionPanel`, `AppContentPanel`, `AppInfoSheetGrid` / `AppInfoSheetRow`, `AppInfoTileGrid`, `AppExpandableRecordSection`
- **Action groups:** `AppActionPanel` / `AppActionSection`, permission action components, `clinicalActionDialogActions`, `buildAppDialogFormActions`, `buildAppDialogWizardActions`
- **Clinical UI:** `OpdEncounterDialog`, `FlowActionsDialog`, shared OPD openers, triage components, `AppRecordVitalsDialog`, `AppVitalsForm`, `AppStatusBadge`, shared fields, `AppFormInformationBanner`
- **Approved shells / openers:** `showAppDialog`, `showAppWorkspaceMutationDialog`, `showAppWorkspaceActionDialog`, `AppConfirmActionDialog` / `AppSelectActionDialog` / `AppTextActionDialog` / `AppTriageActionDialog`, and existing `show*` / `open*` encounter helpers

Shell / chrome references:

- `AppDialog` / `showAppDialog` — `frontend/lib/shared/components/app_dialog.dart`
- `showAppWorkspaceMutationDialog` — `frontend/lib/shared/layout/app_workspace_mutation_dialog.dart`
- `showAppWorkspaceActionDialog` — `frontend/lib/shared/layout/app_workspace.dart`
- `AppConfirmActionDialog` (+ select/text helpers) — `frontend/lib/shared/actions/app_action_dialogs.dart`
- `AppButton` — `frontend/lib/shared/components/app_button.dart`
- `AppActionIcons` — `frontend/lib/shared/icons/app_action_icons.dart`
- Loading — `frontend/lib/shared/components/app_loading_indicator.dart` (+ `AppLoadingSurface` if used by siblings)
- Title casing — `frontend/lib/core/utils/app_dialog_title.dart`
- Clinical footer helper — `frontend/lib/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart`
- Form footer helper — `frontend/lib/shared/forms/app_form_shell.dart`

Prefer existing openers in `shared/opd_actions`, `shared/patient_actions`, `shared/clinical_actions`, and `shared/components` over copying chrome into a feature folder.

## Execution plan

You are a coding agent with full read/write access to this repo. Execute every step. Do not ask for clarification. Treat the normative contracts table as binding.

**Scope lock:** only `PatientPinnedOpdEncounterDialog` and the minimum call-site / shared-helper edits required for compilation and compliance. Do **not** expand to unrelated inventory rows. Shared extracts are allowed only when required for reuse and must stay domain-neutral under `frontend/lib/shared/`.

### Shape rules for `widget_dialog`

- Compose through approved shells only — never raw `AlertDialog` / `showDialog`.
- Titles are general/role-based, passed through `AppDialog` for uppercase normalization — never patient names.
- Loading uses only `AppLoadingIndicator` / `AppLoadingSurface` / `AppButton.isLoading`.
- While loading/saving: disable Cancel, close, and competing actions; `closeEnabled: false`; mutating openers use `barrierDismissible: false`.
- Footer L→R: secondary actions → **Cancel** → primary commit. Prefer one commit.
- Every `AppButton` needs a leading icon (`AppActionIcons` when mapped) and localized label.
- Widgets never call APIs; mutate over HTTP; WebSockets only reconcile; patch Riverpod only after persisted success.
- Standard widget dialog: prefer `clinicalActionDialogActions` / form/wizard action builders over a hand-rolled footer.

### Steps

1. **Read contracts + source**
   - Read [`prompt.md`](../prompt.md) (Scope + Requirements 1–5 + Verification).
   - Skim [`.cursor/api-contract.mdc`](../.cursor/api-contract.mdc) and [`frontend/.cursor/instant_ui_sync.mdc`](../frontend/.cursor/instant_ui_sync.mdc).
   - Read `PatientPinnedOpdEncounterDialog` at `frontend/lib/shared/opd_actions/opd_encounter_flow.dart:75` and every paired opener / *Used from* site.
   - Trace each load/mutation: dialog → controller → repository/DTO → backend route/schema/service → decode → Riverpod patch.

2. **Normalize shell (Req 1)**
   - Compose with `AppDialog` or an approved higher helper; open with `showAppDialog` / workspace helpers / confirm-select-text-triage helpers as appropriate.
   - Remove raw `AlertDialog` / `showDialog` on this path.
   - Preserve purpose, contextual IDs, and permission wrappers.

3. **Normalize title + icon (Req 4)**
   - General role/flow title for **Patient Pinned Opd Encounter** — never patient display name.
   - Pass title through the shell for uppercase normalization.
   - Match sibling icon conventions in `shared/opd_actions`.

4. **Normalize loading + footer (Req 3)**
   - Shared loading primitives only; rebuild actions with `AppButton` + `AppActionIcons` + l10n (or approved action helper).
   - Order: secondary → **Cancel** → primary (`Delegates to encounter actions`).
   - In flight: disable Cancel/close/competitors; `closeEnabled: false`; `barrierDismissible: false` on mutating openers.

5. **Reuse (Req 2)**
   - Replace bespoke blocks with shared primitives; migrate duplicates; delete superseded locals.
   - Cross-check sibling reuse targets: `OpdEncounterDialog`, `showOpdEncounterDialog`.
   - Extract under `frontend/lib/shared/` only when multiple inventory flows need the same UI.

6. **Behavior + permissions**
   - Openers pass already-resolved contextual IDs (`human_friendly_id` / domain IDs).
   - Preserve parent permission wrappers; do not expose unauthorized actions.

7. **Backend + sync (Req 5 — hard)**
   - Widgets read Riverpod and delegate to controllers; no widget API calls.
   - Happy-path APIs must succeed against the real contract; fix either side on mismatch.
   - Failure → shared `AppFailure` UI, no patch, dialog stays open.
   - Persisted success only → patch pinned encounter view, underlying encounter slices, then apply the smallest targeted reconciliation.
   - Cancel/failure never present false success.

8. **Preserve reachability**
   - Do not break `showPatientPinnedOpdEncounterDialog`. Update all call sites in the same change when signatures move.

9. **Verify**
   - Analyzer clean on touched files.
   - `frontend/test/shared/layout/workspace_ui_pattern_test.dart` green.
   - Focused widget/controller/DTO/(backend) tests for this path.
   - Happy-path succeeds; cancel/failure neither patches nor dismisses as saved.
   - Equivalent flows share primitives, spacing, sections, action icons/labels, loading/error behavior, and responsive layout.
   - Tick every checklist item above before finishing.

## Acceptance criteria (all must pass)

1. `PatientPinnedOpdEncounterDialog` opens only through `AppDialog` / approved helpers — no raw Material dialog APIs.
2. Footer order is secondary → Cancel → primary; labels are Cancel/Edit (not Close/Update); confirmations are one domain verb + Cancel.
3. Loading uses only shared spinner primitives; dismiss and competing actions are blocked while in flight.
4. Title is general, uppercase-normalized, and never a patient name.
5. Body sections and action groups reuse canonical shared primitives; no unjustified local forks (siblings considered: `OpdEncounterDialog`, `showOpdEncounterDialog`).
6. Still reachable from inventory openers / *Used from* sites with contextual IDs and permissions intact.
7. Every load and mutation API succeeds on the happy path against the real backend contract; failures surface via `AppFailure` UI and patch nothing.
8. After persisted success only, Riverpod + targeted reconciliation keep dialog and parent surfaces aligned with backend truth for: pinned encounter view, underlying encounter slices.
9. `frontend/test/shared/layout/workspace_ui_pattern_test.dart` remains green; focused tests cover this dialog's critical path.

## Out of scope

- Other inventory rows (unless a minimal shared extract is required for reuse).
- New dialog frameworks, unrelated redesigns, or drive-by refactors outside `PatientPinnedOpdEncounterDialog`'s path.
- Client-only "saved" state not backed by HTTP success.
- Retaining duplicate local UI solely to shrink the diff.

## Deliverable

Implement the compliance fixes in the repo. Summarize: files changed; shell/title/footer/loading/reuse/sync fixes; shared extracts; API/DTO/route fixes; tests added or run; how verification was performed.

<!-- generator: encounter-dialog prompt 29 slug=patient-pinned-opd-encounter-dialog symbol=PatientPinnedOpdEncounterDialog shape=widget_dialog -->
