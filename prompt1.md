# Modal Dialog — Global Unification & UX Consistency

## Objective

Audit and unify **every modal dialog** in the HMS frontend so they share one shell (`AppDialog` / `showAppDialog`), consistent footer actions, predictable sizing on all viewports, and no duplicated dialog scaffolding. Call sites should supply **content and domain logic only**; chrome, layout, drag/resize, focus, and action placement live in shared components.

**Manual smoke URL:** `127.0.0.1:5201` — test dialogs from Lab, Patients, Tenant Facility setup, ICU, and one clinical action flow.

---

## Problem summary (current behavior)

The app already has a shared dialog shell, but usage is inconsistent and sizing behavior does not match product intent.

### 1. Fragmented action/footer patterns

| Pattern | Location | Issue |
|---------|----------|-------|
| `_DialogActions` footer | `app_dialog.dart` | Correct target — fixed footer, end-aligned `OverflowBar`. |
| `_actionDialogButtons` | `app_action_dialogs.dart` | Cancel + primary; duplicated logic. |
| `clinicalActionDialogActions` | `clinical_action_dialog_actions.dart` | Cancel + primary; duplicated logic. |
| `_dialogActions` (local) | `lab_workspace_page.dart`, `nursing_workspace_page.dart`, `icu_workspace_page.dart`, `pharmacy_workspace_page.dart`, `physiotherapy_workspace_page.dart`, `reports_workspace_page.dart`, `lab_catalog_dialogs.dart`, … | Same Cancel + primary helper copy-pasted per module. |
| `showAppWorkspaceMutationDialog` | `app_workspace_mutation_dialog.dart` | Cancel + submit + optional extras — still renders Cancel in footer. |
| Inline delete confirm | `tenant_facility_setup_page.dart` `_deleteEntity` | Ad-hoc `AppDialog` with Cancel + Delete instead of `AppConfirmActionDialog`. |

**Cancel buttons are redundant.** `AppDialog` already provides header close (×), Escape (`CallbackShortcuts`), and optional barrier dismiss. Footer Cancel duplicates dismiss without adding value.

### 2. Inconsistent destructive / submit placement

- Footer uses `MainAxisAlignment.end` — **rightmost action is the last widget** in the `actions` list.
- Some dialogs use `AppButton.primary` for Delete; others use tertiary; order varies (Cancel left, Delete right vs. mixed).
- No single helper encodes: *secondary/extra actions → primary submit → destructive last-on-right* (or the project's chosen canonical order).

### 3. Sizing, drag, and resize do not match intent

In `app_dialog.dart`:

- Initial desktop height is intrinsic (`_desktopSize == null`) but capped by `maxHeight = viewport - insetPadding`; large forms can clip when `scrollable: false`.
- Resize (`_handleResize`) enforces `_desktopMinWidth` / `_desktopMinHeight` but **does not clamp to available viewport** on the max side during drag-resize.
- Maximize sets size to full viewport — good — but restore/drag paths feel capped below usable screen space (user-reported max vertical height while dragging).
- `_snackBarClearance` (88px bottom inset) permanently reduces usable height even when no snackbar is visible.
- Content that exceeds available space should **grow the shell up to viewport bounds**, then scroll inside the body — not clip silently.

### 4. Duplicated domain dialogs

Examples of the same UX rebuilt in multiple places:

- Delete confirmation: inline in `tenant_facility_setup_page.dart` vs. `AppConfirmActionDialog` elsewhere.
- Lab delete flows: `LabDeleteReasonDialog` (good shared widget) vs. one-off confirms in other modules.
- Form mutation: some pages use `showAppWorkspaceMutationDialog`; others inline `AppDialog` + `Form` + local `_dialogActions`.
- Patient create/edit: verify `patient_registry_page.dart` does not duplicate a form dialog that should be extracted once.

### 5. Stray modal chrome at call sites

Call sites sometimes reimplement header controls, embed action rows inside `content`, or pass empty/redundant wrappers instead of using `actions`, `scrollable`, and `icon` on `AppDialog`.

---

## Target UX (all breakpoints)

### Single dialog shell

Every modal must be opened with **`showAppDialog`** and rendered with **`AppDialog`** (or a thin shared wrapper listed below). No raw `showDialog`, `AlertDialog`, or bespoke `Dialog` widgets.

**Approved wrappers** (extend `AppDialog`; do not fork layout):

| Wrapper | Use when |
|---------|----------|
| `AppDialog` | Generic content + footer actions |
| `showAppWorkspaceMutationDialog` | Validated form create/edit with submit lifecycle |
| `AppConfirmActionDialog` | Yes/no or async confirm (delete, irreversible actions) |
| `AppTextActionDialog` | Free-text note/summary capture |
| Domain-specific widgets (e.g. `LabDeleteReasonDialog`, `ClinicalDiagnosisActionDialog`) | One widget per distinct domain flow; must compose `AppDialog` internally |

### Layout regions

```
┌─ Header (draggable on desktop): [icon] Title ··· [maximize] [close ×] ─┐
├─ Body (padded, scrolls when needed) ────────────────────────────────────┤
└─ Footer (fixed): ··· [secondary] [primary submit] [destructive?] ────────┘
```

| Region | Rule |
|--------|------|
| Header | Title + optional icon; close (×) always dismisses (respect `closeEnabled` while saving). **No action buttons in header** except maximize/close. |
| Body | Form fields, read-only detail, confirmation copy. **No Save/Delete/Cancel buttons in body.** |
| Footer | **All** action buttons live here via `AppDialog.actions`. |

### Footer action conventions

**Remove Cancel from all dialog footers.** Dismiss via close (×), Escape, or barrier tap (when `barrierDismissible`).

| Action type | Component | Position |
|-------------|-----------|----------|
| Secondary / optional | `AppButton.secondary` or `AppButton.tertiary` | Left of primary (earlier in `actions` list) |
| Primary submit (Save, Add, Confirm) | `AppButton.primary` | Right side; rightmost when no destructive action |
| Destructive (Delete, Remove, Cancel order*) | `AppButton.primary` with error/destructive styling **or** documented destructive variant | **Rightmost** in footer |
| Loading | `isLoading` on the submitting button; disable other footer actions |

\* “Cancel order” etc. are domain destructive actions, not dialog dismiss.

**Canonical order** (left → right in `OverflowBar`, end-aligned):

```
[secondary…] [primary submit] [destructive]
```

When only one action exists (e.g. “Close” or “OK”), it is a single `AppButton.primary` aligned end.

Use **`AppButton`** only — no raw `TextButton`, `ElevatedButton`, or `FilledButton` in dialog footers.

### Sizing & interaction (desktop ≥ 600px width)

| Behavior | Rule |
|----------|------|
| Initial size | **Shrink-wrap** to content width/height, clamped to available viewport (after insets). |
| Auto-grow | If content height (or width) exceeds current shell size, expand shell **up to** `viewport − insetPadding` so content is fully visible before scrolling kicks in. |
| Max bounds | Manual drag-resize and maximize may use **full available viewport** width and height — not an artificial cap below screen space. |
| Min bounds | Keep reasonable minimums (`_desktopMinWidth`, `_desktopMinHeight`) so the shell stays usable. |
| Overflow | When content exceeds max expanded shell, set `scrollable: true` on body (`SingleChildScrollView` — already in `_DialogBody`). |
| Drag | Header drag moves dialog; clamp translation so dialog remains reachable, not clamped to a fraction of viewport unnecessarily. |
| Resize | Edge/corner handles respect min **and max** = available viewport. |
| Maximize | Fills viewport; restore returns to pre-maximize size/position. |
| Mobile (< 600px) | Full-width inset dialog; no drag/resize/maximize; body scrolls when needed. |

### Accessibility & focus

Preserve existing behavior from `showAppDialog`:

- Focus restoration to opener after close.
- `FocusTraversalGroup`, Escape to dismiss.
- `semanticLabel` on dialogs that need screen-reader context.
- `closeEnabled: false` while async submit in flight.

---

## Scope

### In scope

| Area | Location |
|------|----------|
| Core dialog shell | `frontend/lib/shared/components/app_dialog.dart` |
| Dialog entrypoint | `showAppDialog` (same file) |
| Shared action helpers | New or consolidated helper in `app_dialog.dart` or `app_dialog_actions.dart` |
| Mutation wrapper | `frontend/lib/shared/layout/app_workspace_mutation_dialog.dart` |
| Action dialog wrappers | `frontend/lib/shared/actions/app_action_dialogs.dart` |
| Clinical actions helper | `frontend/lib/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart` |
| All `showAppDialog` / `AppDialog` call sites | Feature pages under `frontend/lib/features/`, shared dialogs under `frontend/lib/shared/` |
| Tests | `frontend/test/shared/components/app_dialog_test.dart` + affected dialog tests |

### Out of scope

- Bottom sheets, drawers, full-page routes, or `showModalBottomSheet` — not modal dialogs.
- Snackbar/toast styling (but re-evaluate whether `_snackBarClearance` should remain fixed or become conditional).
- Changing business logic inside domain forms (field validation, API calls) — only dialog chrome and action placement.
- New third-party dialog packages.

---

## Implementation strategy

Work in this order. **Fix shared components first** so all call sites inherit behavior.

### Phase 1 — Fix `AppDialog` sizing, drag, and resize

1. **Auto-size to content** up to viewport max on first layout (measure intrinsic content; set initial `_desktopSize` when needed).
2. **Clamp resize** in `_handleResize` to `availableWidth` / `availableHeight` (viewport minus insets).
3. **Review drag clamp** in `_handleDrag` — ensure users can position the dialog anywhere within the viewport without an overly restrictive vertical cap.
4. **Revisit `_snackBarClearance`** — use full height when safe, or reduce inset if it causes persistent clipping.
5. **Default `scrollable: true`** for dialogs with unbounded/large content, or auto-enable when measured content exceeds max shell height.
6. Ensure `Flexible` + `fillHeight` interaction does not clip: when content is taller than viewport, body scrolls; shell height = viewport max.

### Phase 2 — Centralize footer actions

1. Add **`AppDialogActions`** (or `buildAppDialogActions`) — single helper returning `List<Widget>`:

   ```dart
   // API sketch — adjust to match AppButton variants available
   List<Widget> buildAppDialogActions(
     BuildContext context, {
     String? primaryLabel,
     VoidCallback? onPrimary,
     bool isPrimaryLoading = false,
     List<AppDialogSecondaryAction> secondaryActions = const [],
     AppDialogDestructiveAction? destructiveAction,
   });
   ```

2. **Remove Cancel** from the helper; document dismiss via close/Escape.
3. Replace duplicates:
   - `_actionDialogButtons` → shared helper
   - `clinicalActionDialogActions` → shared helper
   - All page-local `_dialogActions` → import shared helper
4. Update `showAppWorkspaceMutationDialog` — drop `cancelLabel` parameter; remove Cancel button from `_buildActions`.
5. Update `AppConfirmActionDialog` — single destructive/confirm primary button; no Cancel.

### Phase 3 — Migrate call sites

1. Grep for `commonCancelActionLabel` inside dialog `actions` — remove each Cancel footer button.
2. Grep for `AppDialog(` and verify:
   - `actions` populated for any button that submits/deletes/confirms
   - No action `Row` inside `content`
   - Uses `showAppDialog`, not raw `showDialog`
3. Replace inline delete confirms (e.g. `tenant_facility_setup_page.dart` `_deleteEntity`) with `AppConfirmActionDialog` or a shared `showAppDeleteConfirmDialog` if delete copy differs by entity.
4. Prefer `showAppWorkspaceMutationDialog` for standard create/edit forms instead of inlined `AppDialog` + `Form`.
5. **Deduplicate domain dialogs** — if two modules implement the same “create patient” (or similar) modal, extract one shared widget under `frontend/lib/shared/` or the owning feature package.

### Phase 4 — Cleanup & performance

1. Delete dead private helpers (`_dialogActions` per page) after migration.
2. Avoid rebuilding entire dialog trees on unrelated setState — keep submit loading localized (existing pattern in mutation dialog).
3. Do not wrap large lists in non-scrollable body — always `scrollable: true` for forms with > ~6 fields or dynamic lists.
4. Remove redundant `barrierDismissible: false` where close + unsaved-state guard is sufficient (keep `false` when form data loss is a concern).

### Phase 5 — Regression pass

Manually exercise dialogs at **258px, 426px, 626px, 759px, and desktop** widths:

| Flow | Module |
|------|--------|
| Create/edit form | Patients or HR (`showAppWorkspaceMutationDialog`) |
| Delete confirm | Tenant Facility or Lab delete |
| Clinical action | OPD/IPD clinical action dialog |
| Large form | Lab result entry or Subscriptions |
| Drag + resize + maximize | Any desktop form dialog |

---

## Acceptance criteria

- [ ] **100% of modals** use `showAppDialog` + `AppDialog` (or an approved wrapper that composes it).
- [ ] **No footer Cancel buttons** anywhere; dismiss works via ×, Escape, and barrier (when enabled).
- [ ] **All action buttons** (Save, Edit, Delete, Confirm, …) render in the **footer region** only, with consistent labels (`AppButton`, l10n keys).
- [ ] **Destructive actions** are consistently styled and **rightmost** in the footer.
- [ ] **Primary submit** sits immediately left of destructive (when both present).
- [ ] Dialog **auto-expands** to show content up to viewport max; **no clipped fields** on small or large screens.
- [ ] Manual **resize and drag** respect min size and **full available viewport** as max.
- [ ] **One shared footer-action helper** — no per-page `_dialogActions` copies remain.
- [ ] **No duplicate domain dialog** implementations for the same entity/action (extract shared widget where found).
- [ ] `dart analyze` passes on touched files; `app_dialog_test.dart` updated for sizing/action changes; existing dialog widget tests pass.

---

## Verification

1. **Automated:** `flutter test frontend/test/shared/components/app_dialog_test.dart` and other dialog tests under `frontend/test/`.
2. **Static:** search confirms zero `commonCancelActionLabel` in dialog footer actions; zero raw `showDialog(` outside `app_dialog.dart`.
3. **Manual:** open dialogs listed in Phase 5; verify footer-only actions, dismiss without Cancel, resize to full viewport, scroll when content exceeds max height.

---

## Constraints

- **Minimize diff scope** — shared-component fixes first; migrate call sites in batches by module if needed.
- **Preserve behavior** — submit validation, async error display (`AppFailureStateView`), `closeEnabled` while saving, and focus restoration must remain intact.
- **Follow existing conventions** — `AppButton`, `theme.spacing.*`, `AppFormShell`, `AppFieldRequirementScope`, l10n via `context.l10n`.
- **No new dependencies.**
- **No unrelated refactors** — touch dialog chrome and action placement only unless deduplication requires extracting a shared domain widget.
