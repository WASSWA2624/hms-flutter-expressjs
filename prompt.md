# Workspace Toolbar & Action Button Consistency — Implementation Prompt

## Objective

Eliminate inconsistent toolbar and action-button behavior across HOSSPI HMS module workspaces. Every module screen must use the same responsive action pattern: **icon + label on desktop/tablet**, **icon-only with overflow menu on small screens**, with correct hover, tooltip, permission, and accessibility behavior.

This is a **cross-cutting UI consistency** task. Fix shared primitives first, then migrate every affected screen, clean up legacy code, and pass the quality gate.

---

## Source of truth

| Area | Reference |
| ---- | --------- |
| Workspace layout | [`frontend/.cursor/ui-workspace.mdc`](frontend/.cursor/ui-workspace.mdc) |
| Shared components | [`frontend/.cursor/components.mdc`](frontend/.cursor/components.mdc) |
| Design tokens | [`frontend/.cursor/design-system.mdc`](frontend/.cursor/design-system.mdc) |
| Breakpoints | [`frontend/lib/core/responsive/app_breakpoints.dart`](frontend/lib/core/responsive/app_breakpoints.dart) |
| Toolbar shell | [`frontend/lib/shared/layout/app_workspace_toolbar.dart`](frontend/lib/shared/layout/app_workspace_toolbar.dart) |
| Button primitive | [`frontend/lib/shared/components/app_button.dart`](frontend/lib/shared/components/app_button.dart) |
| Label scope | [`frontend/lib/shared/components/app_action_label_scope.dart`](frontend/lib/shared/components/app_action_label_scope.dart) |
| Overflow resolver | [`frontend/lib/shared/layout/app_toolbar_overflow_resolver.dart`](frontend/lib/shared/layout/app_toolbar_overflow_resolver.dart) |
| Toolbar tests | [`frontend/test/shared/layout/app_workspace_toolbar_test.dart`](frontend/test/shared/layout/app_workspace_toolbar_test.dart) |

---

## Target behavior (non-negotiable)

### Desktop and tablet (`md` breakpoint and above — not `xs` or `sm`)

- Every toolbar action shows **leading icon + visible text label**.
- Applies to **primary**, **secondary**, **refresh**, **global actions** (fault report, housekeeping request), and module-specific actions.
- Labels come from **`app_en.arb`** via `AppLocalizations` — no hardcoded English in feature pages.
- Disabled actions remain visible with reduced opacity; add a **tooltip** explaining why when permission or module entitlement blocks the action.
- Hover and focus states must match other `AppButton` controls (pointer cursor on web/desktop, visible focus ring).

### Small screens (`xs` and `sm`)

- Toolbar actions render **icon-only** (labels hidden via `AppActionLabelScope`).
- When actions do not fit, collapse extras into the **More actions** overflow menu (`Icons.more_vert`).
- On the narrowest layouts, **only the page icon, page title, and More actions button** stay on one header row — no wrapping to a second line.
- More actions trigger must use `AppButton.popupMenuTrigger`, show a tooltip, and use a **clickable pointer cursor** on hover.
- Overflow menu items always show **icon + label** (`AppMenuItemLabel`).

### Actions outside the main toolbar

- Row-level icon actions (`AppListTable`, `AppRecordSection`) may stay icon-only on all breakpoints **only if** they always provide `semanticLabel` and `tooltip`.
- Full-width form submit buttons use labeled `AppButton.primary` — never unexplained icon-only controls.

---

## Root causes to fix first (shared layer)

These bugs explain most reported inconsistencies. Fix them before auditing individual modules.

### 1. `AppButton` hides secondary labels on desktop

In `app_button.dart`, `showLabel` currently suppresses labels for `AppButtonVariant.secondary` when `AppActionLabelScope.showLabels == true`. That inverts the intended behavior and is why refresh, configure, shift context, and most secondary toolbar actions appear icon-only on large screens.

**Fix:** When `forceIconOnly` is false and `iconOnly` is false, show the label for **all** variants on desktop. Reserve icon-only rendering for `xs`/`sm` (`forceIconOnly == true`) or explicit `iconOnly: true` in compact contexts (table row actions, popup triggers).

### 2. Global toolbar actions hard-code `iconOnly: true`

These widgets always force icon-only mode and bypass responsive label scope:

- [`app_workspace_refresh_action.dart`](frontend/lib/shared/actions/app_workspace_refresh_action.dart)
- [`app_global_fault_report_action.dart`](frontend/lib/shared/actions/app_global_fault_report_action.dart)
- [`app_global_housekeeping_request_action.dart`](frontend/lib/shared/actions/app_global_housekeeping_request_action.dart)

**Fix:** Remove `iconOnly: true`. Pass `leadingIcon`, `label`, `semanticLabel`, and `tooltip`. Let `AppActionLabelScope` from `AppWorkspaceToolbar` control compact vs labeled rendering.

### 3. Feature pages bypass `AppWorkspaceToolbar`

Any screen that hand-rolls `Row`/`Wrap` of `AppButton(iconOnly: true, …)` in the header must migrate to:

```dart
toolbar: appWorkspaceToolbarWithLabels(
  l10n,
  primary: AppButton.primary(...),
  secondary: <Widget>[...],
  onRefresh: controller.refresh,
  isRefreshing: state.isRefreshing,
),
```

Use `AppWorkspaceToolbarConfig` — not legacy `primaryAction` / `secondaryActions` on `AppWorkspace` unless the screen is intentionally toolbar-free.

### 4. `AppWorkspaceBoardToggle` styling

IPD/ICU **Patient board / Bed board** toggles use `SegmentedButton` with default Material rounding that looks overly pill-shaped.

**Fix:** Apply design-system border radius (`8–12px` per `components.mdc`) via `SegmentedButton.styleFrom` / theme override in [`app_workspace_board_toggle.dart`](frontend/lib/shared/layout/app_workspace_board_toggle.dart). Keep icon + label segments on desktop; icon-only segments only when `AppActionLabelScope` forces compact mode.

### 5. Overflow resolver dead code

[`app_toolbar_overflow_resolver.dart`](frontend/lib/shared/layout/app_toolbar_overflow_resolver.dart) has unreachable duplicate `AppButton` handling after an early return. Clean up while touching the file.

---

## Module audit checklist

Work through **every** workspace below. For each screen, verify desktop labels, mobile overflow, tooltips, permissions, and that create/edit flows use existing dialogs — not new routes.

| Module | Route / page | Known issues to resolve |
| ------ | ------------ | ----------------------- |
| **Home / Dashboard** | `home_page.dart` | Refresh icon-only on desktop |
| **Patients** | `patient_registry_page.dart` | Emergency registration, Add patient — icon-only |
| **OPD** | `opd_workspace_page.dart` | Start encounter labeled; request action icon-only |
| **Emergency** | `emergency_workspace_page.dart` | Quick arrival labeled; refresh icon-only |
| **IPD** | IPD workspace | Board toggle over-rounded; verify toolbar actions |
| **ICU** | `icu_workspace_page.dart`, `icu_bed_board_panel.dart` | Bed/board layout polish; toolbar consistency |
| **Rooms & Beds** | `rooms_beds_workspace_page.dart` | Admin/setup navigation button lacks label; add **Create room** and **Create bed** actions wired to **existing** mutation dialogs/models |
| **Nursing** | `nursing_workspace_page.dart` | Shift context, record vitals — icon-only |
| **Clinical** | `clinical_workspace_page.dart` | Two inactive toolbar buttons for platform admin — fix `AccessRequirement` / module entitlement so super-admin can use them; ensure labeled design |
| **Physiotherapy** | `physiotherapy_workspace_page.dart` | All toolbar actions icon-only except overflow |
| **Theater** | `theater_workspace_page.dart` | Schedule view refresh icon-only; left-side actions lack labels and hover/tooltips |
| **Lab** | `lab_workspace_page.dart` | Toolbar actions icon-only |
| **Radiology** | `radiology_workspace_page.dart` | Toolbar actions icon-only |
| **Pharmacy** | `pharmacy_workspace_page.dart` | Toolbar actions icon-only |
| **Billing** | `billing_workspace_page.dart` | Toolbar actions icon-only |
| **Claims** | claims workspace | One action icon-only; request authorization is labeled — align both |
| **Subscriptions** | `subscriptions_workspace_page.dart` | Activate labeled; refresh icon-only |
| **Operations** | `operations_workspace_page.dart` | Unlabeled action (likely operations report) — add clear label |
| **Housekeeping** | `housekeeping_workspace_page.dart` | Create cleaning schedule unavailable (module/permission); request maintenance icon-only |
| **Biomedical** | biomedical workspace | Register asset labeled; refresh icon-only; unexplained inactive action — label and gate correctly |
| **HR** | `hr_workspace_page.dart` | Work queues and HR actions icon-only |
| **Communications** | `communications_workspace_page.dart` | Refresh icon-only |
| **Integrations** | `integrations_workspace_page.dart` | Create API key, create webhook — icon-only |
| **Reports** | `reports_workspace_page.dart` | Refresh icon-only |
| **Settings** | settings workspace | Refresh icon-only |
| **Setup / Tenant** | `tenant_facility_setup_page.dart` | Verify consistency (reported as OK for refresh) |
| **Discharge, Mortuary, Triage, Dental, Access Admin** | respective workspace pages | Audit and align with standard toolbar pattern |

### Permission and inactive-action rules

- Platform / super-admin roles must not see **enabled-looking but dead** toolbar buttons. Either enable the action for that role or hide/disable with an explanatory tooltip.
- Housekeeping and biomedical actions must respect module entitlements (`activeModules`) — surface **why** an action is disabled instead of silent no-ops.
- Reuse `AppAccessActionGate` and existing `AccessRequirement` constants; do not invent per-page permission checks.

### Rooms & beds — functional gap

- Add toolbar **Create room** and **Create bed** primary/secondary actions.
- Wire them to the **existing** room/bed mutation dialogs and repository methods already defined in the feature — do not duplicate forms or models.

---

## Implementation steps (in order)

1. **Fix shared primitives** — `AppButton` label logic, global action widgets, board toggle styling, overflow resolver cleanup.
2. **Extend toolbar tests** — update [`app_workspace_toolbar_test.dart`](frontend/test/shared/layout/app_workspace_toolbar_test.dart) so secondary and refresh actions assert visible labels at `1200×800` and icon-only at `360×600`.
3. **Migrate module toolbars** — replace hand-rolled action rows with `appWorkspaceToolbarWithLabels`; add missing `leadingIcon` + localized `label` on every `AppButton`.
4. **Fix permission gaps** — clinical inactive buttons, housekeeping module availability, biomedical mystery action.
5. **Row-level actions** — ensure table/record icon buttons always set `tooltip` and `semanticLabel`.
6. **Localization** — add missing keys to `app_en.arb`; run codegen if needed.
7. **Clean up legacy code** — see cleanup section below.
8. **Quality gate** — see verification section below.

---

## Cleanup tasks

| Task | Details |
| ---- | ------- |
| Remove `AppIconButton` | Migrate remaining usages to `AppButton` via [`frontend/tool/migrate_icon_button.py`](frontend/tool/migrate_icon_button.py) and [`fix_icon_button_labels.py`](frontend/tool/fix_icon_button_labels.py); delete [`app_icon_button.dart`](frontend/lib/shared/components/app_icon_button.dart) once unused |
| Remove stray `iconOnly: true` in toolbars | Toolbar actions should rely on `AppActionLabelScope`, not hard-coded icon-only |
| Update `platform-behavior.mdc` doc | Replace `AppIconButton` references with `AppButton` |
| Delete obsolete migration scripts | After migration completes, remove one-off scripts from `frontend/tool/` or document them in [`tool/README.md`](frontend/tool/README.md) |
| Format touched files | `dart format` on all changed Dart files |
| Fix analyzer warnings | Resolve all `flutter analyze` issues introduced or exposed by this work — no `// ignore` unless justified |

---

## Verification (quality gate)

Run from `frontend/`:

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test test/shared/layout/app_workspace_toolbar_test.dart
flutter test
```

Manual smoke test at **`1280×800`** (desktop) and **`360×640`** (mobile):

- [ ] Every module workspace toolbar action shows icon + label on desktop.
- [ ] Refresh, More actions, and global actions match module-specific actions visually.
- [ ] Narrow width: title + page icon + More actions stay on one line; overflow menu lists all hidden actions with labels.
- [ ] More actions button shows pointer cursor and tooltip on hover (web/desktop).
- [ ] No unexplained disabled toolbar buttons for platform admin.
- [ ] Rooms & beds: create room/bed opens existing dialogs.
- [ ] IPD/ICU board toggles use consistent, subtler corner radius.

---

## Definition of done

- Shared toolbar/button behavior is correct and covered by passing widget tests.
- All module workspaces in the audit table use `AppWorkspaceToolbar` / `appWorkspaceToolbarWithLabels` with consistent labeled desktop actions.
- No remaining `AppIconButton` usages; no toolbar `AppButton(iconOnly: true)` except popup menu triggers and intentional compact row actions.
- `flutter analyze` and `flutter test` pass with no new lint debt.
- User-visible strings are localized in `app_en.arb`.
