# Modal Dialog Footer & Layout Unification

## Objective

Unify every modal dialog in the app around a single layout contract: **header (fixed) → scrollable body (fields only) → footer (fixed actions)**. Action buttons such as Cancel, Save, Submit, and Register must always live in the **non-scrollable, non-resizable footer**, never buried inside the form body. When a dialog is resized or maximized, only the body grows or shrinks; header and footer keep stable height. Maximum dialog dimensions must respect the **available viewport**, not artificial caps that clip content or hide actions.

**Smoke URL:** `127.0.0.1:5201` — verify on **Patients** (Emergency registration + Report equipment fault), then OPD, Billing, and one module with long mutation forms (e.g. Subscriptions, Radiology).

---

## Problems observed (screenshots)

### 1. Primary actions scroll out of view

**Report equipment fault** (`app_global_fault_report_dialog.dart`) opens via the global toolbar on Patients. The form has many fields, but **Cancel / Submit are rendered inside the scrollable body** via `AppFormActions` at the bottom of `AppFormShell.children`. At default dialog height the footer actions are **not visible** — users must scroll past all fields or resize blindly. Only the header close (×) is reachable.

| Symptom | Likely cause |
|---------|----------------|
| No Cancel / Submit visible at open | `AppFormActions` inside `content`, not `AppDialog.actions` |
| Actions appear only after scrolling | `scrollable: true` wraps entire `content`, including action row |
| Same pattern on global housekeeping request | `app_global_housekeeping_request_dialog.dart` duplicates the anti-pattern |

### 2. Inconsistent dialog action placement across the codebase

Two competing patterns exist today:

| Pattern | Example | Footer fixed? |
|---------|---------|---------------|
| **Correct** — `AppDialog.actions` | `EmergencyPatientFormDialog` in `patient_registry_page.dart`, `showAppWorkspaceMutationDialog` | Yes |
| **Incorrect** — `AppFormActions` in form body | Global fault/housekeeping dialogs; inline forms in `billing_workspace_page.dart`, `subscriptions_workspace_page.dart`, `radiology_workspace_page.dart`, and ~12 other workspace pages passed to `showAppWorkspaceActionDialog` | No |

`AppFormActions` (`app_form_shell.dart`) is appropriate for **inline page forms**, not modal footers.

### 3. Resize behavior does not always prioritize body growth

`AppDialog` (`app_dialog.dart`) structures header / `Flexible` body / `_DialogActions` footer correctly when `actions` is populated. Gaps remain:

- Desktop resize (`_handleResize`) does not **clamp** width/height to viewport minus insets — dialogs can grow past the screen.
- Initial `maxWidth` default (`600`) is fine, but resized/maximized dialogs should use **full available width and height** (viewport minus `_dialogInsetPadding` and snack-bar clearance).
- Resize handles sit on the shell edge; ensure dragging never visually compresses the footer — only the `Flexible` content area should change height.

### 4. Emergency registration is the reference, not the exception

**Emergency registration** already uses `AppDialog.actions` with Cancel + primary submit in the footer. It demonstrates the target UX. Other dialogs must match it.

---

## Target UX

### A. Fixed three-zone dialog shell

Every modal (`AppDialog`, `showAppDialog`, `showAppWorkspaceActionDialog`, `showAppWorkspaceMutationDialog`, clinical action dialogs, catalog pickers) must follow:

```
┌─────────────────────────────────────┐
│ HEADER (fixed, draggable)           │  ← title, icon, maximize, close
├─────────────────────────────────────┤
│ BODY (scrollable when overflow)     │  ← fields, helper text, nested pickers
│   • inputs only                     │
│   • no Cancel / Save / Submit       │
│   • optional: buttons that open     │
│     sub-pickers / secondary modals  │
├─────────────────────────────────────┤
│ FOOTER (fixed, never scrolls)       │  ← Cancel (tertiary) + primary action(s)
└─────────────────────────────────────┘
```

**Rules:**

- Pass all dismiss/submit actions through `AppDialog.actions` (or `showAppWorkspaceActionDialog.actions`).
- **Remove `AppFormActions` from any widget tree rendered inside `AppDialog.content`** or `showAppWorkspaceActionDialog.content`.
- Footer uses existing `_DialogActions` styling (`surfaceContainerLowest`, top border, `OverflowBar` end-aligned).
- Button order: **Cancel left of primary** (tertiary → secondary extras → primary), matching `EmergencyPatientFormDialog` and `AppWorkspaceMutationDialog`.
- While submitting: disable Cancel and close; show loading on primary (`closeEnabled: !isSubmitting`).

### B. Migration paths for offending dialogs

| Current | Target |
|---------|--------|
| `AppFormActions` at end of `AppFormShell.children` inside dialog content | Lift state to dialog `StatefulWidget`; wire `AppDialog.actions` |
| `showAppWorkspaceActionDialog` + body-only form with inline actions | Prefer `showAppWorkspaceMutationDialog` when submit closes dialog on success; otherwise pass `actions` to `showAppWorkspaceActionDialog` and keep submit logic in parent state |
| Global fault / housekeeping dialogs | Refactor to match `showAppWorkspaceMutationDialog` pattern (fixed footer, `AppFailureStateView` in body) |

**Primary files:**

- `frontend/lib/shared/components/app_dialog.dart` — shell, resize, `_DialogActions`
- `frontend/lib/shared/layout/app_workspace_mutation_dialog.dart` — reference implementation
- `frontend/lib/shared/layout/app_workspace.dart` — `showAppWorkspaceActionDialog`
- `frontend/lib/shared/actions/app_global_fault_report_dialog.dart` — **priority fix** (screenshot)
- `frontend/lib/shared/actions/app_global_housekeeping_request_dialog.dart` — same pattern
- `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart` — `EmergencyPatientFormDialog` (golden example)

**Workspace pages with `AppFormActions` inside dialog forms** (audit and migrate):

`billing_workspace_page.dart`, `subscriptions_workspace_page.dart`, `radiology_workspace_page.dart`, `theater_workspace_page.dart`, `operations_workspace_page.dart`, `discharge_workspace_page.dart`, `claims_workspace_page.dart`, `housekeeping_workspace_page.dart`, `integrations_workspace_page.dart`, `rooms_beds_workspace_page.dart`

### C. Resize and maximize behavior

| Behavior | Spec |
|----------|------|
| Vertical resize | Increase/decrease **body** height only; header and footer heights unchanged |
| Horizontal resize | Widen/narrow entire dialog; body reflows |
| Maximize | Fill viewport minus insets; body scrolls if fields overflow |
| Min size | Keep existing `_desktopMinWidth` / `_desktopMinHeight` |
| Max size | `viewport − _dialogInsetPadding` (width and height); clamp `_handleResize` and maximize to these bounds |
| Resize handles | Bottom-right corner + edge handles; must not overlap footer action bar |

Implement clamping in `_handleResize` and `_toggleMaximize` if not already present.

### D. Body content rules

| Allowed in body | Not allowed in body |
|-----------------|---------------------|
| `AppTextField`, `AppSelectField`, `AppCheckboxField`, sections, `AppFormShell` children (fields) | `AppFormActions`, raw `OverflowBar` of Cancel/Submit |
| `AppStateView` loading/error (with Retry in body is OK for load failures) | Duplicate close button when footer Cancel exists |
| Buttons that open **nested** pickers/catalog modals | Primary mutation buttons (Save, Register, Submit, Report) |
| `AppFailureStateView` for submit errors | |

### E. Optional: deprecate dialog misuse of `AppFormActions`

Add a short doc comment on `AppFormActions` in `app_form_shell.dart`:

> For modal dialogs, use `AppDialog.actions` or `showAppWorkspaceMutationDialog` — not `AppFormActions`.

Do **not** remove `AppFormActions`; it remains valid for non-modal forms.

---

## Scope & constraints

- **Shared shell first** — fix `AppDialog` resize clamping, then global dialogs, then workspace inline forms.
- **No behavior regression** — submit payloads, validation, and navigation results unchanged.
- **Follow project rules:** `frontend/.cursor/components.mdc`, `design-system.mdc`, `ui-patterns.mdc`, `ui-feedback.mdc`, `localization_i18n.mdc`.
- **Reuse existing helpers** — `showAppWorkspaceMutationDialog`, `clinical_action_dialog_actions.dart`, `AppButton.tertiary` / `.primary`; do not introduce a third dialog abstraction.
- **Uniform** — every module dialog matches Emergency registration footer behavior.

---

## Acceptance criteria

1. **Report equipment fault** (Patients → toolbar): Cancel and Submit are **always visible** in a fixed footer without scrolling.
2. **Emergency registration** footer unchanged — still shows Cancel + Register at bottom.
3. **Global housekeeping request** dialog has fixed footer actions.
4. Grep audit: **zero** `AppFormActions` inside files that only render as `AppDialog` / `showAppWorkspaceActionDialog` content (workspace inline forms migrated).
5. Resizing a tall dialog vertically grows/shrinks **only** the body; footer height stable.
6. Maximized dialog uses full available viewport; resize cannot exceed viewport bounds.
7. Existing tests in `frontend/test/shared/components/app_dialog_test.dart` pass; add tests for footer visibility with long content and resize clamping.
8. Manual smoke on `127.0.0.1:5201`: Patients (both dialogs), Billing (payment dialog), OPD (clinical action dialog) — footer actions visible at open on desktop and mobile widths.

---

## Out of scope (this pass)

- Changing field requirements or business validation on fault report / emergency forms.
- Redesigning dialog header chrome (drag, maximize, close) beyond resize clamp fixes.
- `AppWorkspaceDetailDrawer` — separate surface; only align if it already duplicates modal patterns.
- Shell-level drawers and bottom sheets.
- Migrating non-dialog inline page forms that correctly use `AppFormActions` outside modals.
