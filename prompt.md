# HOSSPI UI — Global borderless buttons & workspace error fixes

## Goal

Unify every interactive button in the Flutter app behind **one** shared component with **no background and no border** in any state (default, hover, focus, pressed, selected, disabled). Buttons show **icon + label only**; hover/press feedback applies to **icon and label color/opacity**, never a container fill or overlay. Fix incorrect **“No connection”** error states on workspace screens and the **mortuary/materials workspace** load error.

---

## 1. Consolidate to a single global button

**Problem:** Button styling is split across `AppButton`, `AppGhostActionButton`, and `AppIconButton`, plus raw `FilledButton` / `OutlinedButton` / `TextButton` / `IconButton` in features. This causes inconsistent filled backgrounds (e.g. blue “Try again”, Claims “Request authorization”, Subscriptions “Activate subscription”).

**Do:**

1. Make `frontend/lib/shared/components/app_button.dart` the **only** button widget. Extend it so all current use cases are covered via properties (not separate widgets):
   - `label` (required for labeled actions; optional for icon-only)
   - `icon` / `leadingIcon`
   - `onPressed`, `enabled`, `isLoading`, `fullWidth`, `semanticLabel`, `tooltip`, `autofocus`
   - `variant` — keep semantic names (`primary`, `secondary`, `tertiary`) for **color/emphasis only**, not fill/border
   - `iconOnly` — compact icon-only mode (toolbar/header)
   - `color` — optional foreground override
2. **Remove** `AppGhostActionButton` and `AppIconButton` as separate public widgets. Migrate all call sites to `AppButton`. Keep thin deprecated aliases only if needed for a transitional PR; end state is one export from `components.dart`.
3. Update `frontend/.cursor/components.mdc` catalog to document the single `AppButton` API.
4. Grep and replace across `frontend/lib/`:
   - `AppGhostActionButton` → `AppButton`
   - `AppIconButton` → `AppButton` with `iconOnly: true`
   - Raw `FilledButton`, `OutlinedButton`, `ElevatedButton` in feature/presentation code → `AppButton`
   - `IconButton` in shell/toolbar/state views → `AppButton` icon-only (except non-action decorative icons)
5. Update `frontend/test/shared/components/app_button_test.dart` (and any ghost/icon button tests) for the unified API.

**Button style contract (all variants):**

| Property | Value |
|---|---|
| `backgroundColor` | Always `Colors.transparent` (all `WidgetState`s) |
| `side` / border | Always `BorderSide.none` |
| `overlayColor` | Always `null` (no Material splash/hover fill) |
| Hover | Increase icon/label opacity or shift foreground color (e.g. `onSurfaceVariant` → `primary`) |
| Press | Slightly stronger foreground emphasis + optional `AnimatedScale` (~0.98) on content |
| Focus | Visible focus ring on icon/label or underline — **not** a background |
| Disabled | Reduced foreground alpha; no background |
| Layout | Icon (20–24px) + `spacing.sm` gap + label; `labelLarge` w700 |
| Loading | Replace icon with `CircularProgressIndicator` (stroke 2); label unchanged |

---

## 2. Fix high-visibility offenders first

These are confirmed in code and match the screenshot audit:

| Location | Current issue | Fix |
|---|---|---|
| `app_state_view.dart` — `AppFailureStateView` retry action | Uses `AppButton.primary` → filled blue “Try again” | `AppButton` with refresh icon, borderless style |
| `responsive_shell_scaffold.dart` — `_ShellMenuItem` | `selectedColor` / `hoverColor` background on nav items | Remove `BoxDecoration.color`; selected = primary icon + label + left indicator bar only; hover = foreground color change only |
| `app_connectivity_indicator.dart` | Raw `IconButton` may show Material overlay | `AppButton` icon-only, borderless |
| `app_fullscreen_toggle.dart`, `app_workspace_toolbar.dart`, `app_toolbar_overflow_resolver.dart` | Header actions | All via unified borderless `AppButton` |
| `app_button.dart` — primary/secondary variants | Filled primary, outlined secondary | All variants borderless; variant = foreground color only |
| `app_workspace.dart` — navigation/summary cards with `navigation: true` | Background + border on hover/selected | Nav items: no background/border; selected/hover on icon+label only |

---

## 3. Fix false “No connection” workspace errors

**Problem:** Many module screens show `AppFailureStateView` with offline title **“No connection”** even when the app shell/header is usable. Dashboard and several modules (Rooms, Billing, Physiotherapy, Housekeeping, Communications, Integrations, Reports, Settings, Setup) do **not** show this — indicating inconsistent load/retry/connectivity handling, not a real global outage.

**Screens that incorrectly show “No connection” (fix required):**

Patients, OPD, Emergency, IPD, ICU, Nursing, Clinical, Theater, Lab, Radiology, Pharmacy, Subscriptions, Operations, Biomedical, HR

**Screens that load correctly (use as reference):**

Dashboard, Rooms & beds, Billing, Claims (content loads; button styling still wrong), Physiotherapy, Housekeeping, Communications, Integrations, Reports, Settings, Setup

**Do:**

1. Trace why failing workspaces return `AppFailureCategory.offline` — check `NetworkFailureMapper`, connectivity gating, and each workspace controller’s initial fetch (e.g. `patient_registry_controller`, `opd_workspace_controller`, etc.).
2. Align failing modules with working ones: same provider init pattern, don’t treat “API unreachable on first paint” as offline when connectivity says online; distinguish **offline**, **timeout**, **server error**, and **forbidden/module inactive**.
3. Ensure `AsyncStateScaffold` / `AppFailureStateView` `onRetry` invalidates the correct provider.
4. Verify with backend running locally (`127.0.0.1:5201`) that listed screens load data instead of offline state.

---

## 4. Fix mortuary / materials workspace error

**Problem:** Mortuary (user referred to as “materials”) shows *“Mortuary workspace unavailable — Try again or contact an administrator…”* when the workspace should not attempt a failing load, or should show the correct empty/forbidden/inactive state.

**Do:**

1. Review `mortuary_workspace_page.dart` and `mortuary_workspace_controller` — gate load on route access, facility context, and active module (same pattern as working modules).
2. If the user lacks facility context or module is inactive, show **forbidden** or **module inactive** state — not a generic load failure.
3. Retry action must use borderless `AppButton` with refresh icon.

---

## 5. Sweep remaining modules for background buttons

After core component work, verify no filled/outlined buttons remain on:

- **Claims** — “Request authorization”, “Prepare claim”, toolbar actions (`claims_workspace_page.dart`, `insurance_authorization_panel.dart`)
- **Subscriptions** — “Activate subscription”, plan/subscription CRUD actions (`subscriptions_workspace_page.dart`)
- **All other feature `presentation/pages/*_workspace_page.dart`** — toolbar primary/secondary actions
- **Dialogs** — `app_action_dialogs.dart`, clinical/opd/lab dialog action rows
- **Auth pages** — login/register/submit actions (borderless but keep emphasis via color)

---

## Acceptance criteria

- [ ] **One** button component (`AppButton`) used app-wide; `AppGhostActionButton` and `AppIconButton` removed from public API
- [ ] No button shows background, border, or Material overlay in any interaction state
- [ ] Hover/press visibly affects **icon and label only**
- [ ] Every action button has an appropriate **icon + label** (icon-only allowed only in compact toolbar contexts via `AppActionLabelScope`)
- [ ] “Try again” on error/offline states is borderless (icon + label)
- [ ] Sidebar nav selected/hover states have **no background fill**
- [ ] Header actions (connectivity, fullscreen, notifications, profile menu trigger) are borderless
- [ ] All 15 “No connection” screens load correctly when API is available
- [ ] Mortuary workspace shows correct state (not spurious load error)
- [ ] `flutter test frontend/test/shared/components/app_button_test.dart` passes
- [ ] `flutter test frontend/test/shared/components/app_state_view_test.dart` passes
- [ ] Manual smoke test on `127.0.0.1:5201` for every shell route in `AppRoutes.shellRoutes`

---

## Key files

```
frontend/lib/shared/components/app_button.dart          ← single source of truth
frontend/lib/shared/components/app_ghost_action_button.dart  ← remove/merge
frontend/lib/shared/components/app_icon_button.dart          ← remove/merge
frontend/lib/shared/components/app_state_view.dart           ← retry action
frontend/lib/shared/layout/responsive_shell_scaffold.dart    ← sidebar nav items
frontend/lib/shared/layout/app_workspace.dart                ← nav/summary cards
frontend/lib/app/theme/app_theme.dart                        ← global button themes
frontend/lib/core/network/network_failure_mapper.dart        ← offline classification
frontend/test/shared/components/app_button_test.dart
frontend/test/shared/components/app_state_view_test.dart
```

---

## Out of scope

- Dropdown / popup menu styling (user confirmed dropdowns look fine)
- `CircleAvatar` on profile (not a button)
- Non-interactive status chips and badges
