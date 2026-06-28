# Shell Loading Bar & Seamless Screen Transitions

## Objective

Replace the full-screen circular loading spinner shown during route and workspace transitions with a **single, shell-level horizontal progress indicator** pinned immediately below the app header (`AppMenuBar`). Hold the previous screen visible until the destination screen is ready, then swap content in one step. Fix the header **online/offline connectivity indicator** so online reads green and offline reads red. Remove obsolete route-level loading UI that duplicates or conflicts with the new shell indicator.

**Smoke URL:** `127.0.0.1:5201` — verify on **Rooms and beds**, **Patients**, **Dashboard**, and one slow-loading module (e.g. Subscriptions or Radiology). Toggle Wi‑Fi off/on to confirm connectivity colors.

---

## Problems observed

### 1. Circular spinner flash on navigation

When switching sidebar destinations (e.g. Dashboard → Rooms and beds), the workspace briefly shows a **centered `CircularProgressIndicator`** inside `AsyncStateScaffold` / `AppStateView` while the new controller loads. The previous screen disappears first, leaving an empty or spinner-only body — poor perceived performance and jarring UX.

| Symptom | Likely cause |
|---------|----------------|
| Empty body or lone spinner between routes | `AsyncStateScaffold` `loading:` branch renders `AppStateScaffold` with `_StateVisual` → `CircularProgressIndicator` |
| Same pattern on first paint of many modules | Every workspace page root wraps content in `AsyncStateScaffold` |
| Hand-rolled spinners in sub-panels | `Center(child: CircularProgressIndicator())` in operations, HR, theater, ICU bed board, etc. |

### 2. No global navigation progress affordance

There is no shared indicator in the shell header region. Users cannot tell that navigation is in progress without the content area going blank.

**Target placement:** directly under `AppMenuBar` — the row with sidebar toggle, logo, app title, connectivity, fullscreen, notifications, and account avatar — spanning the full content width above sidebar + workspace.

### 3. Connectivity indicator looks disabled when online

`AppConnectivityIndicator` passes `color: theme.statusColors.success` (online) or `.error` (offline) into `AppButton`, but also sets `onPressed: null`. `AppButton` resolves `WidgetState.disabled` to `colorScheme.onSurface.withValues(alpha: 0.38)`, **overriding the intended green/red** — so online appears gray and offline change is barely visible.

---

## Target UX

### A. Shell loading bar (primary navigation feedback)

Introduce a shared **`AppShellLoadingBar`** (or equivalent) owned by the shell, not individual pages.

```
┌──────────────────────────────────────────────────────────────┐
│ [≡]  [Logo]  HOSSPI Hospital Management System    [wifi][⛶][🔔][PD] │  ← AppMenuBar
├──────────────────────────────────────────────────────────────┤
│ ████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  ← AppShellLoadingBar (2–3 px)
├──────────┬───────────────────────────────────────────────────┤
│ Sidebar  │  Previous OR new workspace content                │
│          │  (no full-page spinner during route change)       │
└──────────┴───────────────────────────────────────────────────┘
```

**Visual spec:**

| Property | Value |
|----------|-------|
| Height | `2`–`3` logical px (`minHeight: 2`, matching existing `LinearProgressIndicator` usage in IPD/Lab) |
| Width | Full shell content width (above sidebar + body) |
| Style | Indeterminate, left-to-right sweep; use `theme.colorScheme.primary` |
| Visibility | Shown only while shell navigation or initial workspace load is in progress; hidden when idle |
| Motion | Respect reduced-motion / accessibility — static pulsing bar or instant hide if `MediaQuery.disableAnimations` |
| Platforms | Web, desktop, mobile — same component, no platform forks |

**Behavior spec:**

| Event | Shell bar | Body content |
|-------|-----------|--------------|
| User selects new sidebar destination | Show bar | **Keep previous route's widget visible** until destination `AsyncValue` has data (success or failure) |
| Destination ready | Hide bar | Cross-fade or instant swap to new workspace content |
| In-place refresh (same route) | Optional brief bar OR inline panel progress | Do **not** replace entire workspace with full-page spinner; prefer existing inline `LinearProgressIndicator` patterns where already used |
| Startup / auth shell | Out of scope for shell bar | Keep existing `startup_shell.dart` behavior unless trivial to align |

Wire loading state at **`ResponsiveShellScaffold`** / router shell builder level — derive from route transition + destination workspace controller `AsyncValue.isLoading` on first load.

### B. Seamless screen transition (no empty flash)

**Rule:** The outgoing screen stays mounted and visible until the incoming screen's first meaningful state is available.

Implementation options (pick one, prefer least invasive):

1. **Shell child retention** — `ShellRoute` builder holds previous `child` in a stack/overlay until the new route's root provider reports `AsyncValue.hasValue` or `AsyncValue.hasError`.
2. **`AsyncStateScaffold` stale-while-revalidate** — add optional `keepPreviousData` / `previousValue` parameter so navigation does not fall through to the full-page loading branch when switching routes; shell bar carries loading feedback instead.
3. **Router-level deferred swap** — delay `GoRouter` child replacement until workspace controller finishes initial load.

Whichever approach is chosen, **remove the full-page loading scaffold from route-change paths**. Reserve full-page loading states for true cold starts (login, startup) only.

### C. Connectivity indicator — green online, red offline

Fix `AppConnectivityIndicator` so status color is always visible:

| State | Icon | Color | Tooltip |
|-------|------|-------|---------|
| Online | `Icons.wifi` | `theme.statusColors.success` (green) | localized online label |
| Offline | `Icons.wifi_off_outlined` | `theme.statusColors.error` (red) | localized offline label |

**Do not** use a disabled `AppButton` for a read-only status glyph if disabled styling mutes the color. Prefer one of:

- `AppButton` with `enabled: true` and `onPressed: () {}` no-op (only if focus/hover semantics are acceptable), or
- A dedicated stateless status chip/icon widget (no disabled foreground override), or
- Extend `AppButton` so explicit `color` wins over disabled muted foreground for `iconOnly` status indicators.

Verify with DevTools / manual test: toggle network offline — icon must turn **red** immediately; restore — **green**.

### D. Remove obsolete loading indicators

**Remove or replace** (route / workspace level only):

| Remove / replace | Keep (out of scope) |
|------------------|---------------------|
| Full-page `CircularProgressIndicator` in `AsyncStateScaffold` loading branch during shell navigation | Button `isLoading` spinners in `AppButton` |
| Ad-hoc `Center(child: CircularProgressIndicator())` on workspace pages used as page-level load (operations, HR, theater, ICU bed board, billing ledger dialog initial load) | Field-level spinners in `AppSelectField`, `AppSearchBar`, etc. |
| Duplicate top-level spinners that fire simultaneously with the new shell bar | Dialog/panel inline `LinearProgressIndicator(minHeight: 2)` for partial refreshes |
| Any dead/unused loading widgets or providers introduced for old navigation feedback | Patient detail skeleton + bar pattern in `patient_registry_page.dart` (good reference) |

After migration, **grep audit:** no `CircularProgressIndicator` used as the sole content of a workspace page root during navigation load.

---

## Primary files

| File | Change |
|------|--------|
| `frontend/lib/shared/layout/responsive_shell_scaffold.dart` | Mount `AppShellLoadingBar` below `AppMenuBar`; wire loading visibility |
| `frontend/lib/shared/components/app_state_view.dart` | `AsyncStateScaffold` — optional stale-while-revalidate; stop full-page spinner on route change |
| `frontend/lib/shared/layout/app_connectivity_indicator.dart` | Fix green/red visibility |
| `frontend/lib/shared/components/app_button.dart` | Only if needed: allow status `color` when non-interactive |
| `frontend/lib/app/router/app_router.dart` | Shell builder — child retention / loading signal to scaffold |
| `frontend/lib/core/network/app_connectivity_status.dart` | Confirm stream emits offline promptly (no change unless broken) |

**Reference patterns:**

- Inline bar: `ipd_workspace_page.dart`, `lab_workspace_page.dart` (`LinearProgressIndicator(minHeight: 2)`)
- Skeleton + bar: `patient_registry_page.dart` (detail dialog loading)
- Connectivity provider: `app_router.dart` → `ResponsiveAppShell(connectivityStatus: …)`

**Pages to audit for hand-rolled page spinners:**

`operations_workspace_page.dart`, `hr_workspace_page.dart`, `theater_workspace_page.dart`, `icu_bed_board_panel.dart`, `billing_ledger_dialog.dart`

---

## Scope & constraints

- **Shell-first** — one shared loading bar; pages emit loading state upward, they do not each render their own navigation spinner.
- **No behavior regression** — data fetching, permissions, retry, and error surfaces unchanged; only loading *presentation* and transition timing change.
- **Follow project rules:** `frontend/.cursor/ui-feedback.mdc`, `ui-patterns.mdc`, `components.mdc`, `accessibility.mdc`, `localization_i18n.mdc`.
- **Reuse theme tokens** — `colorScheme.primary`, `statusColors.success` / `.error`, `appTokens.dividerThickness`; no hard-coded hex in feature pages.
- **Localized tooltips** — reuse `appStatusOnlineLabel` / `appStatusOfflineLabel`; add l10n keys only if new strings are required.

---

## Acceptance criteria

1. Navigating **Dashboard → Rooms and beds → Patients** shows the **thin horizontal bar under the header** during load; **no centered circular spinner** and **no blank white workspace flash**.
2. Previous screen content remains visible until the destination workspace is ready (data or error), then transitions to the new screen.
3. `AppShellLoadingBar` is visible on mobile, tablet, and desktop widths and on web at `127.0.0.1:5201`.
4. Connectivity icon is **green** when online and **red with wifi-off icon** when offline; change is obvious within one connectivity event.
5. Grep: zero `CircularProgressIndicator` as the primary loading UI for workspace page roots triggered by sidebar navigation (button/field/dialog spinners exempt).
6. Existing tests pass; add widget test for `AppShellLoadingBar` visibility and `AppConnectivityIndicator` online/offline colors.
7. Manual smoke: sidebar hop across 4 modules, toggle offline mid-navigation, confirm bar + colors + no empty flash.

---

## Out of scope (this pass)

- Redesigning `AppMenuBar` layout, sidebar, or notification badge.
- Changing `AppButton` loading spinners on submit actions.
- Skeleton loaders for every module (optional follow-up; shell bar is sufficient for this pass).
- Auth pages, startup splash, and login flow loading (unless trivial one-line alignment).
- Backend or controller fetch logic — presentation and transition timing only.
