# Standardize `OpdEncounterDialog` — Opd Encounter

## Mission

Host the OPD encounter workspace (clinical documentation and encounter lifecycle actions) as the canonical encounter dialog.

Bring **`OpdEncounterDialog`** to **100% compliance** with [`prompt.md`](../prompt.md) (patient-encounter dialog standardization). This is **structural**, not cosmetic: consolidate onto the established product surface used across [`dialog-inventory/02-patient-encounter-flow.md`](../dialog-inventory/02-patient-encounter-flow.md). Do not invent another dialog shell, use raw `AlertDialog` / `showDialog`, or keep duplication merely to shrink the diff.

## Normative contracts (read before editing)

| Contract | Path | Authority |
| --- | --- | --- |
| Dialog standardization | [`prompt.md`](../prompt.md) | Shells, reuse, loading/actions, titles, verification |
| API envelopes / IDs | [`.cursor/api-contract.mdc`](../.cursor/api-contract.mdc) | `snake_case`, `human_friendly_id`, success/error envelopes |
| Instant UI sync | [`frontend/.cursor/instant_ui_sync.mdc`](../frontend/.cursor/instant_ui_sync.mdc) | HTTP mutate, Riverpod patch on success, WS reconcile only |
| Shared components | [`frontend/.cursor/components.mdc`](../frontend/.cursor/components.mdc) | Reuse under `frontend/lib/shared/`; no feature forks of shared UI |
| Localization | [`frontend/.cursor/localization_i18n.mdc`](../frontend/.cursor/localization_i18n.mdc) | All user-facing strings via l10n |
| Permissions | [`frontend/.cursor/permissions.mdc`](../frontend/.cursor/permissions.mdc) | Preserve RBAC/ABAC wrappers; never expose unauthorized actions |
| Design system | [`frontend/.cursor/design-system.mdc`](../frontend/.cursor/design-system.mdc) | Tokens only; responsive light/dark UI |
| Accessibility | [`frontend/.cursor/accessibility.mdc`](../frontend/.cursor/accessibility.mdc) | Focus, semantics, keyboard, scaling, contrast |
| Feedback / failures | [`frontend/.cursor/ui-feedback.mdc`](../frontend/.cursor/ui-feedback.mdc) | Shared async/failure states; preserve input; safe errors |
| Frontend tests | [`frontend/.cursor/testing.mdc`](../frontend/.cursor/testing.mdc) | Widget/controller/sync/responsive coverage |
| Backend API | [`backend/.cursor/api.mdc`](../backend/.cursor/api.mdc) | Routes, middleware, authz, public IDs |
| Backend tests | [`backend/.cursor/testing.mdc`](../backend/.cursor/testing.mdc) | Schema/service/controller/route/event coverage |
| Module flow | [`.cursor/flows/opd-flow.mdc`](../.cursor/flows/opd-flow.mdc) | Domain workflow states, transitions, and handoffs |

## Target

| Field | Value |
| --- | --- |
| Symbol | `OpdEncounterDialog` |
| Purpose | Opd Encounter |
| Module / surface | `shared/components` |
| Inventory kind | `shared` |
| Presentation shape | `workspace_dialog` |
| Verified definition | `frontend/lib/shared/components/opd_encounter_dialog.dart:166` |
| Inventory location note | Inventory and verified declaration agree at generation time. |
| Extends / uses | AppDialog / showAppDialog (typical) |
| Paired opener(s) | `showOpdEncounterDialog` |
| Primary commit | Save encounter changes / lifecycle actions |
| Slices to keep in sync | OPD encounter, queue stage, pinned encounter, clinical sections |
| Sibling reuse targets | `showOpdEncounterDialog`, `PatientPinnedOpdEncounterDialog`, `FlowActionsDialog`, `_CloseEncounterDialog`, `_CancelEncounterDialog` |
| Action helper peek | `AppConfirmActionDialog` |
| Controllers (region) | `appAccessPolicyProvider` |
| Mutations (region) | `mutation: createPatient` |

### Used from

- `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`
- `frontend/lib/shared/opd_actions/opd_appointment_actions_dialog.dart`
- `frontend/lib/shared/opd_actions/opd_encounter_flow.dart`

### Delegated/shared implementation evidence

- `AppDialog — frontend/lib/shared/components/app_dialog.dart`
- `AppSectionPanel — frontend/lib/shared/components/app_content_panel.dart`
- `AppConfirmActionDialog — frontend/lib/shared/actions/app_action_dialogs.dart`
- `RegisterNewPatientForm — frontend/lib/shared/patient_actions/register_new_patient_dialog.dart`

### Cross-stack trace candidates

These files mention a detected mutation method and are starting points, not proof of ownership. Follow interfaces/imports and route registration until the persisted path is proven.

- `frontend/lib/shared/components/opd_encounter_dialog.dart`
- `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`
- `frontend/lib/features/patients/presentation/controllers/patient_registry_controller.dart`
- `frontend/lib/features/patients/domain/repositories/patient_repository.dart`
- `frontend/lib/features/patients/data/repositories/patient_repository_impl.dart`
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `backend/src/modules/patient/services/patient.service.js`
- `backend/src/modules/patient/routes/patient.routes.js`
- `backend/src/modules/patient/controllers/patient.controller.js`
- `backend/src/tests/modules/patient/services/patient.service.test.js`
- `backend/src/tests/modules/patient/controllers/patient.controller.test.js`

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

### 5. Design, responsiveness, localization, and accessibility
- [ ] No hard-coded user-facing copy or private feature string holder; labels, hints, validation, errors, tooltips, and semantics use generated l10n.
- [ ] No hard-coded color, spacing, radius, elevation, typography, date, number, or currency formatting; use theme/design tokens and shared formatters.
- [ ] Content and actions remain usable on mobile, tablet, desktop, dark mode, text scaling, and constrained-height/keyboard layouts without overflow.
- [ ] Keyboard order is logical, focus is trapped/restored by the dialog shell, visible focus remains, icon-only controls have localized semantics, and status is not conveyed by color alone.

### 6. Backend correctness and sync
- [ ] Every load/mutation is traced end-to-end: dialog → workspace controller → repository/DTO → real backend route/schema/service.
- [ ] IDs, `snake_case` payloads, auth, envelopes, and response decoding match [`.cursor/api-contract.mdc`](../.cursor/api-contract.mdc); either side is fixed when mismatched.
- [ ] Widgets never call APIs or own competing server data. Mutations go over HTTP; WebSockets only reconcile ([`frontend/.cursor/instant_ui_sync.mdc`](../frontend/.cursor/instant_ui_sync.mdc)).
- [ ] On failure: dialog stays open, `AppFailure` is shown through shared failure UI, and **nothing** is patched. No fake or silently ignored success.
- [ ] On persisted success only: immediately patch every affected Riverpod slice, then apply the smallest targeted refresh/realtime reconciliation. Dialog, parent workspaces, pinned views, lists, details, and badges agree with backend truth without a full reload.
- [ ] Cancel / failure neither patches nor dismisses as if saved.

### 7. Reachability and verification
- [ ] Still reachable from every paired opener and *Used from* site listed above.
- [ ] `frontend/test/shared/layout/workspace_ui_pattern_test.dart` stays green. Add focused widget, controller, DTO, and (when the stack is touched) backend route/schema/service tests for this dialog's path.

## Compliance snapshot (heuristic — verify in code)

| Signal | Observation |
| --- | --- |
| Approved shell signals | `AppDialog`, approved `show*` helper, `AppConfirmActionDialog` |
| Raw `showDialog` / `AlertDialog` | not seen in peek |
| Raw Material progress indicator | yes — replace |
| Title snippets | `l10n.opdWalkInDialogTitle`, `l10n.opdPatientSectionTitle`, `l10n.opdRoutingSectionTitle`, `l10n.opdBillingSectionTitle` |
| `AppButton` variants (order seen) | secondary -> secondary -> secondary -> secondary -> secondary -> primary |
| `AppActionIcons` | seen |
| `barrierDismissible: false` | yes |
| `closeEnabled: false` | yes |
| Loading primitives | seen |
| Direct widget repository read | not seen |
| Delegated components scanned | 4 |
| Cross-stack trace files found | 11 |
| Peek region size | 56784 chars |

### Priority gaps to close

1. Raw Material progress indicator detected — replace with `AppLoadingIndicator` / `AppLoadingSurface` / `AppButton.isLoading` only.

### Dialog-specific focus

- Do not create a second encounter shell. Extend this dialog and `showOpdEncounterDialog`.
- Footer may expose multiple essential mutations — still order secondary → Cancel → primary; prefer approved action helpers.
- Every nested save must patch Riverpod on persisted success only and keep the dialog open on failure.

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

**Scope lock:** only `OpdEncounterDialog` and the minimum call-site / shared-helper edits required for compilation and compliance. Do **not** expand to unrelated inventory rows. Shared extracts are allowed only when required for reuse and must stay domain-neutral under `frontend/lib/shared/`.

### Shape rules for `workspace_dialog`

- Compose through approved shells only — never raw `AlertDialog` / `showDialog`.
- Titles are general/role-based, passed through `AppDialog` for uppercase normalization — never patient names.
- Loading uses only `AppLoadingIndicator` / `AppLoadingSurface` / `AppButton.isLoading`.
- While loading/saving: disable Cancel, close, and competing actions; `closeEnabled: false`; mutating openers use `barrierDismissible: false`.
- Footer L→R: secondary actions → **Cancel** → primary commit. Prefer one commit.
- Every `AppButton` needs a leading icon (`AppActionIcons` when mapped) and localized label.
- Widgets never call APIs; mutate over HTTP; WebSockets only reconcile; patch Riverpod only after persisted success.
- Workspace dialog: maximize/resize/close behavior must match sibling encounter dialogs.
- Multiple essential mutations are allowed only when necessary; still honor Cancel placement and loading locks.

### Steps

1. **Read contracts + source**
   - Read every contract in the **Normative contracts** table. Apply each rule to files matching its scope; do not treat this prompt as a substitute for project rules.
   - Read `OpdEncounterDialog` at `frontend/lib/shared/components/opd_encounter_dialog.dart:166` and every paired opener / *Used from* site.
   - Inspect every delegated/shared implementation and trace candidate above, then follow imports/interfaces/routes beyond those candidates as needed.
   - Trace each load/mutation: dialog → controller → repository/DTO → backend route/schema/service → decode → Riverpod patch.

2. **Normalize shell (Req 1)**
   - Compose with `AppDialog` or an approved higher helper; open with `showAppDialog` / workspace helpers / confirm-select-text-triage helpers as appropriate.
   - Remove raw `AlertDialog` / `showDialog` on this path.
   - Preserve purpose, contextual IDs, and permission wrappers.

3. **Normalize title + icon (Req 4)**
   - General role/flow title for **Opd Encounter** — never patient display name.
   - Pass title through the shell for uppercase normalization.
   - Match sibling icon conventions in `shared/components`.

4. **Normalize loading + footer (Req 3)**
   - Shared loading primitives only; rebuild actions with `AppButton` + `AppActionIcons` + l10n (or approved action helper).
   - Order: secondary → **Cancel** → primary (`Save encounter changes / lifecycle actions`).
   - In flight: disable Cancel/close/competitors; `closeEnabled: false`; `barrierDismissible: false` on mutating openers.

5. **Reuse (Req 2)**
   - Replace bespoke blocks with shared primitives; migrate duplicates; delete superseded locals.
   - Cross-check sibling reuse targets: `showOpdEncounterDialog`, `PatientPinnedOpdEncounterDialog`, `FlowActionsDialog`, `_CloseEncounterDialog`, `_CancelEncounterDialog`.
   - Extract under `frontend/lib/shared/` only when multiple inventory flows need the same UI.

6. **Behavior + permissions**
   - Openers pass already-resolved contextual IDs (`human_friendly_id` / domain IDs).
   - Preserve parent permission wrappers; do not expose unauthorized actions.

7. **Design + accessibility**
   - Use generated l10n, theme/design tokens, shared formatters, and responsive layout primitives only.
   - Verify keyboard/focus/semantics, text scaling, dark mode, constrained height, and mobile/tablet/desktop layouts.
   - Preserve entered form data on recoverable failures and never expose raw exception text.

8. **Backend + sync (Req 5 — hard)**
   - Widgets read Riverpod and delegate to controllers; no widget API calls.
   - Happy-path APIs must succeed against the real contract; fix either side on mismatch.
   - Failure → shared `AppFailure` UI, no patch, dialog stays open.
   - Persisted success only → patch OPD encounter, queue stage, pinned encounter, clinical sections, then apply the smallest targeted reconciliation.
   - Cancel/failure never present false success.

9. **Preserve reachability**
   - Do not break `showOpdEncounterDialog`. Update all call sites in the same change when signatures move.

10. **Verify**
   - Analyzer clean on touched files.
   - `frontend/test/shared/layout/workspace_ui_pattern_test.dart` green.
   - Run focused Flutter widget/controller/DTO tests plus backend schema/service/controller/route/event tests for every touched stack layer. Add missing tests; never rely on production services or secrets.
   - Happy-path succeeds; cancel/failure neither patches nor dismisses as saved.
   - Verify responsive, keyboard, focus, semantics, text-scale, and dark-mode behavior for changed dialog UI.
   - Run localization/code generation when ARB or generated DTO/model inputs change, and verify generated output is clean.
   - Equivalent flows share primitives, spacing, sections, action icons/labels, loading/error behavior, and responsive layout.
   - Tick every checklist item above before finishing.

## Acceptance criteria (all must pass)

1. `OpdEncounterDialog` opens only through `AppDialog` / approved helpers — no raw Material dialog APIs.
2. Footer order is secondary → Cancel → primary; labels are Cancel/Edit (not Close/Update); confirmations are one domain verb + Cancel.
3. Loading uses only shared spinner primitives; dismiss and competing actions are blocked while in flight.
4. Title is general, uppercase-normalized, and never a patient name.
5. All copy is localized; all styling/formatting uses shared tokens/formatters; responsive and accessible behavior is verified.
6. Body sections and action groups reuse canonical shared primitives; no unjustified local forks (siblings considered: `showOpdEncounterDialog`, `PatientPinnedOpdEncounterDialog`, `FlowActionsDialog`, `_CloseEncounterDialog`, `_CancelEncounterDialog`).
7. Still reachable from inventory openers / *Used from* sites with contextual IDs and permissions intact.
8. Every load and mutation API succeeds on the happy path against the real backend contract; failures surface via `AppFailure` UI and patch nothing.
9. After persisted success only, Riverpod + targeted reconciliation keep dialog and parent surfaces aligned with backend truth for: OPD encounter, queue stage, pinned encounter, clinical sections.
10. `frontend/test/shared/layout/workspace_ui_pattern_test.dart` remains green; focused frontend/backend tests cover this dialog's critical path.

## Out of scope

- Other inventory rows (unless a minimal shared extract is required for reuse).
- New dialog frameworks, unrelated redesigns, or drive-by refactors outside `OpdEncounterDialog`'s path.
- Client-only "saved" state not backed by HTTP success.
- Retaining duplicate local UI solely to shrink the diff.

## Deliverable

Implement the compliance fixes in the repo. Summarize: files changed; shell/title/footer/loading/reuse/sync fixes; design/localization/accessibility fixes; shared extracts; API/DTO/route fixes; tests added and run; exact commands and results; remaining risks (or explicitly state none). Append the project rule files applied and the model used.

<!-- generator: encounter-dialog prompt 22 slug=opd-encounter-dialog symbol=OpdEncounterDialog shape=workspace_dialog -->
