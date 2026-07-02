# Workspace Toolbar — Global Responsive Fix

## Objective

Fix responsive toolbar and workspace-header behavior **globally** across all authenticated HMS workspaces — not only Patient registry.

Apply the fix once in shared layout infrastructure where possible, then audit every non-auth screen that uses `AppWorkspace`.

**Discovered on:** `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`  
**Applies to:** All `AppWorkspace` screens under `frontend/lib/features/**` (see audit list below)

---

## Scope

### In scope

- Shared layout: `frontend/lib/shared/layout/app_workspace_toolbar.dart`, `app_workspace.dart`
- Every feature screen using `AppWorkspace` / `appWorkspaceToolbarWithLabels`
- Toolbar `primary` actions and, where relevant, the first pinned screen action in custom `toolbarLayoutActions` layouts (e.g. HR)

### Out of scope

- **Auth screens** — `frontend/lib/features/auth/**` (login, register, forgot/reset password, verify email). These use `AuthPageFrame`, not `AppWorkspace`.
- In-panel / detail-pane icon-only buttons (record actions, table row actions, dialog controls) — `iconOnly: true` is correct there
- Register patient dialog / form changes
- i18n changes

---

## Problem

Two regressions affecting workspace toolbars (observed on Patient registry, likely shared):

1. **Large screens (lg+):** Primary toolbar actions show **icon only** when they should show **icon + label**.
2. **Mobile (xs–sm):** Primary toolbar actions **disappear**; they should remain **visible as icon-only**, inline and tappable (not only inside the overflow menu).

Workspace header title behavior should also match the matrix below on all workspaces.

---

## Expected behavior (global contract)

Use `AppBreakpoints` as the source of truth (`frontend/lib/core/responsive/app_breakpoints.dart`).

| Breakpoint | Width | Workspace title | Toolbar primary action |
| ---------- | ----- | ----------------- | ---------------------- |
| **xs, sm** (mobile) | &lt; 600 | Hidden (module icon only) | Icon only, **always inline** |
| **md** (tablet) | 600–839 | Visible | Icon only |
| **lg+** (desktop) | ≥ 840 | Visible | Icon + label |

- `AppActionLabelScope` in `AppWorkspaceToolbar` already drives label vs icon-only via `showsToolbarActionLabels`.
- Global actions (refresh, fault report, housekeeping, notifications) may move to overflow on narrow widths.
- The workspace **primary action must never be dropped** from the inline toolbar on mobile.

**Reference tests** (define the contract):

- `frontend/test/shared/layout/app_workspace_toolbar_test.dart` — mobile / tablet / desktop primary-action cases
- `frontend/test/core/responsive/app_breakpoints_test.dart` — breakpoint label decisions

---

## Root causes to fix

### 1. Hardcoded `iconOnly: true` on toolbar actions

Some screens force icon-only mode on toolbar buttons, overriding `AppActionLabelScope`:

```dart
AppButton.primary(
  iconOnly: true,  // ← remove on workspace toolbar actions
  leadingIcon: Icons.person_add_alt_1_outlined,
  label: l10n.someAction,
  ...
)
```

`AppButton` already respects `AppActionLabelScope.forceIconOnly` from `AppWorkspaceToolbar`. **Do not** pass `iconOnly: true` on `config.primary`, `config.secondary`, or items in `toolbarLayoutActions` that should follow the global responsive contract.

Known violation: `patient_registry_page.dart`. Grep the codebase for other toolbar instances.

### 2. Overflow layout evicting pinned primary

Audit `AppWorkspaceToolbar._AdaptiveToolbarLayout` / `_measureOverflow` so `pinnedInlinePrimary` is **never** moved into the overflow menu, including when summary notifications and global actions are present.

---

## Scoped work

### 1. Shared infrastructure (required — fixes all workspaces at once)

- **`app_workspace_toolbar.dart`** — Ensure `pinnedInlinePrimary` stays inline on xs–md; fix `_measureOverflow` if it evicts the primary action.
- **`app_workspace.dart`** — Verify `_WorkspaceHeaderTitle` / header icon behavior matches the title matrix on all breakpoints.

### 2. Global screen audit (required)

Grep and fix every non-auth workspace screen. Start with:

```bash
rg "appWorkspaceToolbarWithLabels|AppWorkspaceToolbarConfig" frontend/lib/features --glob "*.dart"
rg "iconOnly:\s*true" frontend/lib/features --glob "*workspace*" --glob "*_page.dart"
```

**Workspace screens to verify** (all under `frontend/lib/features/`):

| Module | Page |
| ------ | ---- |
| Patients | `patients/.../patient_registry_page.dart` |
| OPD | `opd/.../opd_workspace_page.dart` |
| Emergency | `emergency/.../emergency_workspace_page.dart` |
| IPD | `ipd/.../ipd_workspace_page.dart` |
| ICU | `icu/.../icu_workspace_page.dart` |
| Nursing | `nursing/.../nursing_workspace_page.dart` |
| Clinical | `clinical/.../clinical_workspace_page.dart` |
| Lab | `lab/.../lab_workspace_page.dart` |
| Radiology | `radiology/.../radiology_workspace_page.dart` |
| Pharmacy | `pharmacy/.../pharmacy_workspace_page.dart` |
| Theater | `theater/.../theater_workspace_page.dart` |
| Physiotherapy | `physiotherapy/.../physiotherapy_workspace_page.dart` |
| Mortuary | `mortuary/.../mortuary_workspace_page.dart` |
| Billing | `billing/.../billing_workspace_page.dart` |
| Claims | `claims/.../claims_workspace_page.dart` |
| Discharge | `discharge/.../discharge_workspace_page.dart` |
| Housekeeping | `housekeeping/.../housekeeping_workspace_page.dart` |
| Biomedical | `biomedical/.../biomedical_workspace_page.dart` |
| Operations | `operations/.../operations_workspace_page.dart` |
| HR | `hr/.../hr_workspace_page.dart` |
| Rooms & beds | `rooms_beds/.../rooms_beds_workspace_page.dart` |
| Tenant facility | `tenant_facility/.../tenant_facility_setup_page.dart` |
| Access admin | `access_admin/.../access_admin_workspace_page.dart` |
| Subscriptions | `subscriptions/.../subscriptions_workspace_page.dart` |
| Integrations | `integrations/.../integrations_workspace_page.dart` |
| Communications | `communications/.../communications_workspace_page.dart` |
| Reports | `reports/.../reports_workspace_page.dart` |
| Settings | `settings/.../settings_page.dart` |
| Home | `home/.../home_page.dart` |

For each screen with a toolbar primary action: remove hardcoded `iconOnly: true`; keep `label`, `semanticLabel`, and `tooltip` for accessibility.

### 3. Tests

- Extend `app_workspace_toolbar_test.dart` if the overflow pin fix changes behavior.
- Add spot-check widget tests for 2–3 representative workspaces (e.g. Patients, OPD, HR) at mobile / tablet / desktop widths.
- Do **not** duplicate the same breakpoint matrix test in every feature module — shared toolbar tests are the contract.

---

## Acceptance criteria

- [ ] **Shared fix** in `app_workspace_toolbar.dart` (and header if needed) — all workspaces inherit correct behavior
- [ ] **No toolbar primary/secondary action** in any non-auth `AppWorkspace` screen hardcodes `iconOnly: true`
- [ ] **lg+ (≥ 840px):** Primary toolbar action shows icon **and** label on every workspace that defines one
- [ ] **md (600–839px):** Primary action icon only; workspace title visible
- [ ] **xs–sm (&lt; 600px):** Workspace title hidden; primary action icon remains **inline and tappable**
- [ ] Auth screens unchanged
- [ ] `flutter analyze` passes
- [ ] Shared toolbar tests + spot-check workspace tests pass

---

## Quality gate

From `frontend/`:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test test/shared/layout/app_workspace_toolbar_test.dart
flutter test test/core/responsive/app_breakpoints_test.dart
flutter test test/features/patients/presentation/patient_registry_page_test.dart
```

Add further workspace spot-check tests as implemented.
