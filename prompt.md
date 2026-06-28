# Workspace toolbar & shell polish — implementation prompt

## Goal

Finish the workspace toolbar rollout so every module screen behaves uniformly: no header overflow, a predictable **3 visible screen-specific actions + More** pattern, correct global actions, a working fullscreen toggle label, and cleaner summary-card chrome.

Most screens already use `AppWorkspace` + `appWorkspaceToolbarWithLabels`. This task closes the remaining gaps called out during manual QA.

---

## 1. Fix fullscreen toggle label/icon inversion

**Problem:** `AppFullscreenToggle` shows **“Exit full screen”** when not in fullscreen (and vice versa). Toggle works, but the affordance describes the wrong next action.

**Root cause (likely):** `_isFullscreen` is only updated after a local tap. It is not synced when fullscreen changes externally (Esc key, browser chrome, initial mount race).

**Files:**
- `frontend/lib/shared/layout/app_fullscreen_toggle.dart`
- `frontend/lib/shared/layout/app_fullscreen_platform_web.dart`
- `frontend/lib/shared/layout/app_fullscreen_platform_stub.dart`

**Requirements:**
- Listen for the platform fullscreen-change event on web (`fullscreenchange`) and call `setState` with `appFullscreenIsActive()`.
- On build, label and icon must always describe the **next** action:
  - Not fullscreen → label `workspaceFullscreenEnterLabel`, icon `Icons.fullscreen`
  - In fullscreen → label `workspaceFullscreenExitLabel`, icon `Icons.fullscreen_exit`
- Add/adjust widget tests (mirror `app_dialog_test.dart` fullscreen expectations).

---

## 2. Redesign toolbar overflow (“More actions”) behavior

**Problem:** On many screens the title-bar action row overflows. The **More** menu opens a bottom sheet that lays items out in a **horizontal `Wrap`**, so actions clip or hide instead of appearing as a vertical list.

**Files:**
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` (primary change)
- `frontend/lib/shared/layout/app_workspace.dart` (`AppWorkspaceHeader` layout constraints)
- `frontend/test/shared/layout/app_workspace_toolbar_test.dart`

### 2a. Visible action budget

Implement a single, shared rule in `AppWorkspaceToolbar`:

| Cluster | Rule |
|--------|------|
| **Screen-specific** (`secondary` + `primary`) | Show **at most 3** inline. If more exist, put the remainder behind **More actions**. |
| **Global** (refresh, request maintenance, report equipment fault) | Keep visible on the right when space allows. On very narrow widths they may collapse into More **after** screen-specific items are handled. |
| **More actions** | Always a dropdown/sheet with a **vertical** list (`Column` / `ListView` of full-width tappable rows), never a horizontal wrap. |

**Ordering inside More:** screen-specific overflow first (priority order preserved), then global actions if they did not fit inline.

### 2b. Overflow detection

Do **not** rely only on `constraints.maxWidth < AppBreakpoints.md`. Use available width in the header row (title + actions) so wide screens with many buttons (board toggles, billing close actions, etc.) still collapse correctly.

Suggested approach:
- Extend `AppWorkspaceToolbarConfig` with optional `maxVisibleScreenActions` (default `3`).
- Flatten `secondary` then `primary` into one ordered screen-specific list before splitting visible vs overflow.
- Treat `AppWorkspaceBoardToggle` / `AppWorkspaceViewToggle` as **one** screen-specific slot (they are wide).

### 2c. More menu UX

- Vertical list; each item uses the same action widgets (`AppButton`, `AppIconButton`, gated actions) at full row width.
- Sheet title = localized `workspaceToolbarOverflowLabel`.
- Accessible semantics (`button`, label per row).
- Update tests: opening More shows hidden labels; layout is vertical (no horizontal `Wrap` in sheet).

### 2d. Header overflow

In `AppWorkspaceHeader`, ensure the action bar never paints outside the header:
- `Flexible` / `Expanded` + `clipBehavior` or intrinsic measurement so title and actions share space without yellow/black overflow stripes.
- Board-toggle segments must not break layout (ICU/IPD separator rendering called out in QA).

---

## 3. Uniform screen-specific action sets (per module)

For **every** workspace page, audit toolbar config and ensure the **top 3 most-used module actions** are inline; everything else goes under More.

Use existing `AppActionItem` / dialog helpers in each feature where actions already exist in detail panels — surface the important ones in the toolbar.

### Screen audit checklist

| Screen | Current gap | Expected top inline actions (examples — use l10n + permission gates) |
|--------|-------------|---------------------------------------------------------------------|
| **Dashboard** (`home_page.dart`) | OK baseline | Refresh only (no module actions) |
| **Patients** | Verify icon-only pattern | Add patient, emergency register, (+ 1 more if exists) |
| **OPD** | OK | Start walk-in / encounter (+ module actions as added) |
| **Emergency** | Overflow | Triage / register / board actions — pick top 3 |
| **IPD** | Overflow (board toggle + admission) | Board toggle (1 slot), start admission, + 1 key action |
| **Rooms & beds** | Overflow | Manage catalog, setup, + 1 |
| **ICU** | Board toggle separator ugly; **no ICU actions in toolbar** | Board toggle (1 slot), start stay, record vitals/observation; rest in More |
| **Nursing** | Only shift-context icon | Shift context, record vitals, handover (+ rest in More) |
| **Clinical** (“critical”) | Overflow | Top 3 queue/encounter actions |
| **Physiotherapy** | Overflow + empty toolbar | Schedule session, referrals view, + 1 |
| **Theater** | Overflow | Schedule case (+ 2 module actions) |
| **Lab** | Overflow | View toggle (1 slot), create order, reference ranges |
| **Radiology** | Overflow | Top 3 imaging actions |
| **Pharmacy** | Overflow; More broken | Catalog, dispense/queue action, + 1 |
| **Billing** | Overflow | Close shift, close day (+ primary billing action) |
| **Housekeeping** | More menu layout only | Keep actions; fix More presentation |
| **Biomedical** | Reference | Register asset + module actions |
| **Subscriptions / Operations** | More menu layout | Fix More; keep refresh + admin actions |
| **Mortuary / HR / Communications / Integrations / Reports** | Verify | Top 3 per module |
| **Settings** (`settings_page.dart`) | **Skipped migration** — uses `AppScreen` + legacy `headerActions` | Migrate to `AppWorkspace` + `appWorkspaceToolbarWithLabels` with refresh (+ admin shortcuts in More if needed) |
| **Tenant facility setup** | Verify | Refresh + setup actions |

**ICU & Nursing specifically:** toolbar actions should mirror the highest-priority items from `_IcuActionPanel` / `_NursingActionBar`, wired through existing controllers and `AppAccessActionGate`.

---

## 4. Summary card / chrome styling

**Problem:** Summary cards and toolbar backgrounds look boxy; borders feel heavy.

**Files:** `frontend/lib/shared/layout/app_workspace.dart` (`AppWorkspaceSummaryCard`, header `DecoratedBox`)

**Requirements:**
- Reduce visual noise: prefer subtle elevation or `surfaceContainerLow` fill over hard `Border.all` on compact summary cards.
- Keep selected/active state obvious (tone color, not thick border).
- Header bottom divider (`outlineVariant`) is fine; do not add extra borders around action clusters.
- Match existing theme tokens (`theme.spacing`, `theme.radius`, `colorScheme`).

---

## 5. Implementation constraints

- Reuse `appWorkspaceToolbarWithLabels` — do not invent per-page overflow logic.
- Respect `AppAccessActionGate` / `AccessRequirement` on every action.
- Use existing l10n keys; add ARB entries only when missing.
- Keep `showFaultReport` / `showHousekeepingRequest` overrides (e.g. biomedical hides fault report).
- No new dependencies.
- Follow patterns in `opd_workspace_page.dart` and `patient_registry_page.dart` for gated toolbar buttons.

---

## 6. Acceptance criteria

1. Fullscreen button always shows the **next** action label/icon; Esc exit updates the button without a page reload.
2. No render overflow in workspace headers on QA screens at 1280×800 and 1024×768.
3. Every module workspace uses `appWorkspaceToolbarWithLabels` (including **Settings**).
4. Toolbar shows ≤ 3 screen-specific actions inline; additional module actions appear under **More** in a **vertical** list.
5. Global refresh / maintenance / fault actions use the shared action components (`AppWorkspaceRefreshAction`, etc.), not legacy one-offs.
6. ICU and Nursing toolbars expose module-relevant actions, not only board toggle / shift icon.
7. More menu never lays out actions in a horizontal wrap.
8. Widget tests cover: 3+ screen actions → More appears; sheet is vertical; fullscreen label sync.
9. `flutter test frontend/test/shared/layout/app_workspace_toolbar_test.dart` passes; run analyzer clean on touched files.

---

## 7. Suggested work order

1. Fullscreen toggle fix + test  
2. `AppWorkspaceToolbar` overflow refactor (config, More sheet, width logic)  
3. `AppWorkspaceHeader` layout hardening  
4. Settings migration to `AppWorkspace`  
5. Per-module toolbar audits (ICU, Nursing, Pharmacy, Billing, IPD, Rooms & beds first — highest overflow reports)  
6. Summary card border polish  
7. Full test pass + spot-check in browser at `.\tool\run_web_5201.ps1`
