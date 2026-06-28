# UI Layout Unification — HOSSPI HMS

Unify the app shell, page headers, toolbars, and action buttons so every module workspace feels consistent, responsive, and polished. **Implement once in shared code, reuse everywhere, delete duplicates, and comply with all applicable frontend rules.**

---

## Governing principles

Every change in this pass must optimize for:

| Principle | Requirement |
|---|---|
| **Maximum reusability** | One shared widget per concern. Extend `lib/shared/` — never fork per module. |
| **Code clean-up** | Remove dead code, duplicate widgets, private `_ModuleText` classes, and inline layout clones as screens migrate. |
| **UI efficiency** | Fewer rebuilds, lazy lists, debounced search, targeted row refresh — no full-page reload when unnecessary. |
| **Uniformity** | Same header, toolbar, button types, status badges, and worklist chrome on every applicable screen. |
| **Rule compliance** | Follow all applicable `.cursor` rules listed below — no exceptions for convenience. |

**Conflict order** (from `frontend/.cursor/index.mdc`): security/privacy → API contract → index/owner file → other frontend rules.

---

## Applicable rules (mandatory compliance)

Read and follow these owner files before writing or migrating UI:

### UI and UX (primary for this pass)

| Rule file | Compliance requirement |
|---|---|
| [`ui-workspace.mdc`](frontend/.cursor/ui-workspace.mdc) | Mandatory layout stack; forbidden patterns; file size limits |
| [`components.mdc`](frontend/.cursor/components.mdc) | Use standard catalog; no parallel abstractions |
| [`design-system.mdc`](frontend/.cursor/design-system.mdc) | Theme tokens only — no hard-coded colors, spacing, typography |
| [`layouts.mdc`](frontend/.cursor/layouts.mdc) | Breakpoints, shell behavior, `PageMaxWidth`, responsive utilities |
| [`ui-patterns.mdc`](frontend/.cursor/ui-patterns.mdc) | Forms, tables, search debounce, pagination |
| [`ui-feedback.mdc`](frontend/.cursor/ui-feedback.mdc) | `AsyncStateScaffold`; loading/empty/error at page root — not inline |
| [`accessibility.mdc`](frontend/.cursor/accessibility.mdc) | Semantic labels, 48px targets, keyboard/focus, icon + text for status |
| [`multi_platform_input.mdc`](frontend/.cursor/multi_platform_input.mdc) | Touch, keyboard, hover, focus on web/desktop |
| [`assets_branding.mdc`](frontend/.cursor/assets_branding.mdc) | Icons and branding consistency |

### Cross-cutting (apply where touched)

| Rule file | Compliance requirement |
|---|---|
| [`localization_i18n.mdc`](frontend/.cursor/localization_i18n.mdc) | All strings in `app_en.arb`; no `_FeatureText` private copy classes |
| [`permissions.mdc`](frontend/.cursor/permissions.mdc) | `AppAccessActionGate` / typed permissions; hide disallowed actions |
| [`performance.mdc`](frontend/.cursor/performance.mdc) | `const` widgets, focused `ref.watch`, paginated tables, split large pages |
| [`architecture.mdc`](frontend/.cursor/architecture.mdc) | Presentation only in this pass — no business logic in shared widgets |
| [`coding_conventions.mdc`](frontend/.cursor/coding_conventions.mdc) | Naming, imports, file focus |
| [`project_structure.mdc`](frontend/.cursor/project_structure.mdc) | Shared code in `lib/shared/`; feature widgets in `presentation/widgets/` |
| [`realtime_sync.mdc`](frontend/.cursor/realtime_sync.mdc) | Preserve module realtime subscriptions after refactor |
| [`navigation.mdc`](frontend/.cursor/navigation.mdc) | Route guards unchanged; deep links still open same shared dialogs |
| [`checklists.mdc`](frontend/.cursor/checklists.mdc) | Per-feature and release gates before marking a screen done |
| [`.cursor/api-contract.mdc`](.cursor/api-contract.mdc) | Pagination, display IDs, no raw UUIDs in UI |

### Module flow references (UI sections only)

When migrating a module, also read its flow rule if present: `opd-flow`, `ipd-flow`, `icu-flow`, `lab-flow`, `radiology-flow`, `nursing-flow`, `discharge-flow`, `theater-flow`, `pharmacy-flow`, `emergency-flow`.

---

## Shared component strategy (reuse first)

**Before creating anything new**, search `frontend/lib/shared/` and the standard catalog in [`components.mdc`](frontend/.cursor/components.mdc).

### Primary shared widgets (use — do not reimplement)

| Widget | Path / barrel | Owns |
|---|---|---|
| `AppWorkspace` | `shared/layout/app_workspace.dart` | Page shell: header, summary, body, detail |
| `AppWorkspaceHeader` | same | Title, status, action row |
| `ResponsiveAppShell` | `shared/layout/responsive_shell_scaffold.dart` | App bar, sidebar, connectivity, account |
| `AppScreen` | `shared/layout/responsive_page.dart` | Settings-style non-queue pages |
| `AppListTable` | `shared/components/` | Worklist, pagination, mobile fallback |
| `AppButton` / `AppIconButton` | `shared/components/` | All toolbar and form actions |
| `AppDialog` / `AppWorkspaceMutationDialog` | `shared/components/` | All modals |
| `AsyncStateScaffold` | `shared/components/` | Loading, error, retry |
| `AppActionPanel` / `AppActionList` | `shared/actions/` | Grouped row/detail actions |
| `AppWorkspaceSummaryCard` | `shared/layout/app_workspace.dart` | Summary/filter cards |
| `AppActionLabelScope` | `shared/components/` | Responsive icon-only vs icon+label |

**Import barrels:** `shared/layout/layout.dart`, `shared/components/components.dart`, `shared/actions/actions.dart`.

### New shared widgets to add (once)

Implement these in `lib/shared/` — every workspace consumes them; no feature-local copies:

| Widget | Purpose |
|---|---|
| `AppConnectivityIndicator` | Network-style online/offline icon (replaces dot pill) |
| `AppFullscreenToggle` | Shell-level full-screen control |
| `AppWorkspaceToolbar` | Declarative left/right action clusters + overflow |
| `AppWorkspaceRefreshAction` | Standard refresh button with loading state |
| `AppWorkspaceBoardToggle` | Patient board / bed board (IPD, ICU, future) |
| `AppWorkspaceViewToggle` | Orders/patients view switch (Lab, Radiology pattern) |
| `AppGlobalFaultReportAction` | Equipment fault dialog entry point |
| `AppGlobalHousekeepingRequestAction` | Housekeeping/maintenance request entry point |
| `AppWorkspaceLiveStatus` | Standardized "Live sync" / "Saving" badge factory |

Shared widgets accept **localized strings and callbacks from callers** — they must not embed module-specific copy or business rules.

---

## Code clean-up requirements

As each screen migrates, clean up — do not leave old code alongside new:

1. **Delete** feature-local header/toolbar widgets superseded by shared components.
2. **Delete** private string classes (`_EmergencyText`, `_LabText`, etc.) — move keys to `app_en.arb`.
3. **Extract** inline UI blocks from pages exceeding ~800 lines into `presentation/widgets/` ([`ui-workspace.mdc`](frontend/.cursor/ui-workspace.mdc)).
4. **Remove** duplicate refresh/action implementations — one `AppWorkspaceRefreshAction` per page.
5. **Remove** hard-coded `Colors.*`, raw `TextStyle`, magic padding — use `theme.spacing`, `theme.textTheme`, `theme.colorScheme`.
6. **Remove** inline "Sign-in required" / auth blocks from content stack — gate at `AsyncStateScaffold` level.
7. **Consolidate** duplicate dialogs (add patient, start admission, create order) — one shared dialog widget per flow.
8. **Fix or remove** broken actions (e.g. biomedical action showing "This action isn't available").
9. **Run** `flutter analyze` after each module migration; fix new warnings in touched files.

### File size guidance

| File | Target |
|---|---|
| `*_workspace_page.dart` | Prefer `< 800` lines — extract widgets before adding more UI |
| `shared/layout/*.dart` | Keep focused; split if a file grows unwieldy |
| New feature widgets | One concern per file (summary cards, detail section, dialog) |

---

## UI efficiency requirements

| Area | Efficient pattern | Avoid |
|---|---|---|
| **Rebuilds** | `ref.watch` only what the widget needs; split header/toolbar into small widgets | Watching entire workspace state in header |
| **Lists/tables** | `AppListTable` with pagination; lazy builders | Loading full datasets; filtering huge lists in memory |
| **Search** | Debounced remote search in controller ([`ui-patterns.mdc`](frontend/.cursor/ui-patterns.mdc)) | Fetch-on-every-keystroke without debounce |
| **Refresh** | Row/detail/summary/badge targeted refresh after modal mutation | Full `invalidate` of all providers when one row changed |
| **Layout** | `const` constructors where possible; `LayoutBuilder` only when needed | Deep nesting of `Row`/`Column`/`Wrap` for toolbar |
| **Responsive** | Centralized `AppBreakpoints` — one layout path | Separate duplicate screens per breakpoint |
| **Dialogs** | Shared mutation dialogs; dismiss and refresh minimally | Full navigation reload after small edit |
| **Summary cards** | Hide zero-value cards; cards filter query in controller | Extra API calls per card click |

---

## Goal

One predictable layout system across clinical, operational, and admin screens:

1. **App shell** — logo, connectivity, notifications, account, full-screen toggle.
2. **Page header** — module icon, title, live/sync status.
3. **Toolbar** — page-specific actions on the **left**, global/common actions on the **right**.
4. **Content stack** — summary cards → search/filter bar → worklist/table → detail panel (when applicable).

Users should not notice layout differences when moving between OPD, IPD, Lab, Billing, etc.

---

## In scope

Migrate every screen that uses `AppWorkspace`, `AppWorkspaceHeader`, or `AppScreen` as its page root:

| Group | Screens (`*_workspace_page.dart` / registry) |
|---|---|
| Overview | Dashboard (`home_page.dart`) |
| Patient access | Patients, OPD, Emergency |
| Inpatient care | IPD, Rooms and beds, ICU, Nursing, Discharge |
| Clinical services | Clinical, Physiotherapy, Theater |
| Diagnostics & medication | Lab, Radiology, Pharmacy |
| Revenue cycle | Billing, Claims, Subscriptions |
| Facility operations | Operations, Housekeeping, Biomedical |
| People & comms | HR, Communications |
| Platform | Integrations, Reports, Access admin, Tenant/facility setup |
| Other modules | Mortuary |
| Configuration | Settings (`settings_page.dart` via `AppScreen`) |

**Out of scope:** Auth pages, profile, change-password flows, and one-off wizards that are not module work queues.

---

## Known inconsistencies (fix these)

Observed across current UI — do not preserve these patterns:

| Area | Problem | Target behavior |
|---|---|---|
| Refresh control | Mix of `AppIconButton` and `AppButton.secondary` with label | `AppWorkspaceRefreshAction` only; right cluster |
| Primary actions | Some use `primaryAction`, others put create/add in `secondaryActions` | One primary per screen via `AppWorkspaceToolbar` primary slot |
| Action order | Inconsistent ordering across modules | Standard order (see Toolbar spec) |
| Status label | "Live sync", "Live board", "Live", etc. | `AppWorkspaceLiveStatus` + `app_en.arb` keys |
| Connectivity | Dot + text pill; avatar dot on small screens | `AppConnectivityIndicator` in shell |
| Summary cards | Different counts, borders, filter behavior | `AppWorkspaceSummaryCard`; filter only, no duplicate modals |
| View toggles | IPD vs ICU board toggle styled differently | `AppWorkspaceBoardToggle` |
| Inline auth blocks | "Sign-in required" mid-page (Theater, Radiology) | `AsyncStateScaffold` / session gate at page root |
| Settings | Different header action pattern | Align with `AppWorkspaceToolbar` where practical |
| Duplicate toolbars | Raw `Row`/`Wrap` of mixed buttons per page | Declarative `AppWorkspaceToolbar` config |
| Private copy classes | `_ModuleText` throughout features | `context.l10n` only |

---

## Canonical page layout stack

Every module work queue must follow this stack ([`ui-workspace.mdc`](frontend/.cursor/ui-workspace.mdc)):

```
AsyncStateScaffold
└── ResponsivePage
    └── AppWorkspace (or AppScreen for settings-style pages)
        ├── AppWorkspaceHeader + AppWorkspaceToolbar
        ├── AppWorkspaceSummaryGrid (optional; hide zero-value cards)
        ├── AppWorkspaceFilterBar / search row
        ├── AppListTable or module body
        └── AppWorkspaceDetailPanel (optional)
```

**Behavior rules:**

- Summary cards **filter** the worklist — never open modal lists of the same data.
- Hospital workflow language in labels — never raw enum/API codes.
- Display IDs and patient names only — no raw UUIDs.
- Gate actions with `AppAccessActionGate` / `AppPermissionActionButton`.
- After modal mutations: refresh row, detail, summary counts, nav badges.
- Subscribe to module `RealtimeEventGroups` where already defined.

**Forbidden** ([`ui-workspace.mdc`](frontend/.cursor/ui-workspace.mdc)):

- Custom full-page `Scaffold` + hand-rolled table when `AppWorkspace` fits.
- Duplicate status chips for the same state.
- Hard-coded colors/spacing/`TextStyle` in feature presentation code.
- Inline `SnackBar` success copy bypassing localization.
- New table/list component when `AppListTable` suffices.

---

## 1. App shell header (top bar)

**Implement:** `AppConnectivityIndicator`, `AppFullscreenToggle` in `responsive_shell_scaffold.dart`.

### Large screens (md+)

Sidebar | logo + app name | … | connectivity | full-screen | notifications | account.

### Connectivity (`AppConnectivityIndicator`)

- Network-style icon (Windows 10 taskbar style): green when online, muted/red offline.
- Accessible label via `onlineLabel` / `offlineLabel`; tooltip on hover.
- Theme tokens only — no hard-coded colors.

### Small screens (xs–sm)

- Dedicated connectivity control in top bar — **not** on account avatar.
- Remove avatar status dot once indicator exists.

### Full-screen toggle (`AppFullscreenToggle`)

- Shell right cluster, before notifications.
- Web: `document.documentElement.requestFullscreen()` / exit API.
- Icon-only on xs–sm; icon + label on md+.
- Session-only — no persistence.

---

## 2. Page header & toolbar

**Implement:** `AppWorkspaceToolbar` — pages pass a declarative config, not raw widget lists.

### Header content

| Element | Large screens | Small screens (xs–sm) |
|---|---|---|
| Leading | `AppWorkspaceTitleIcon` | Icon only |
| Title | Module title (compact header style) | **Hidden** |
| Status | `AppWorkspaceLiveStatus` | **Hidden** on xs |
| Toolbar | Inline or stacked via `LayoutBuilder` | Dedicated row below icon |

### Toolbar layout

```
[ Page-specific actions …………………… Global actions | ⋮ overflow ]
     LEFT (start)                              RIGHT (end)
```

**Page-specific (left → right):**

1. View/mode toggles (`AppWorkspaceBoardToggle`, `AppWorkspaceViewToggle`)
2. Secondary module actions (config, catalog, reports, shift controls)
3. **Primary module action** — one `AppButton.primary` per screen

**Global (right cluster, via shared actions):**

1. `AppWorkspaceRefreshAction`
2. `AppGlobalHousekeepingRequestAction`
3. `AppGlobalFaultReportAction`

Use `AppActionLabelScope`: icon + label on md+; icon-only on xs–sm.

### Overflow menu

- Collapse excess actions into `PopupMenuButton` (⋮).
- Overflow items: icon + label.
- Keep refresh visible or first in overflow.
- Keyboard accessible ([`accessibility.mdc`](frontend/.cursor/accessibility.mdc)).

---

## 3. Global actions

Wire through shared widgets + provider/callback on `AppWorkspace` — **zero per-module dialog copies**.

| Action | Shared widget | Notes |
|---|---|---|
| Report equipment fault | `AppGlobalFaultReportAction` | Reuse biomedical fault dialog; photo, description, location, routing |
| Request housekeeping | `AppGlobalHousekeepingRequestAction` | Shared maintenance/cleaning form → housekeeping module |
| Refresh | `AppWorkspaceRefreshAction` | Every workspace page |

Permission-gate global actions where required ([`permissions.mdc`](frontend/.cursor/permissions.mdc)).

---

## 4. Per-screen action registry

**Primary** = one `AppButton.primary`. Everything else = secondary (left) or global (right).

| Screen | Primary action | Page-specific secondary actions |
|---|---|---|
| **Dashboard** | — | Quick actions in body; header: refresh only |
| **Patients** | Add patient | Emergency registration |
| **OPD** | Start OPD encounter | — |
| **Emergency** | Quick arrival | — |
| **IPD** | Start admission | `AppWorkspaceBoardToggle` |
| **Rooms and beds** | Set up (if permitted) | Manage layout/grid toggle |
| **ICU** | — | `AppWorkspaceBoardToggle` |
| **Nursing** | — | Shift key, ward context |
| **Discharge** | — | — |
| **Clinical** | — | — |
| **Physiotherapy** | — | — |
| **Theater** | Schedule case | — |
| **Lab** | Create lab order | `AppWorkspaceViewToggle`, lab configuration |
| **Radiology** | Request imaging | `AppWorkspaceViewToggle`, radiology configuration |
| **Pharmacy** | — | Catalog and store |
| **Billing** | — | Code shift, close day |
| **Claims** | Prepare claim | Request authorization |
| **Subscriptions** | Activate subscription | — |
| **Operations** | Create request | Report |
| **Housekeeping** | Create task | Create schedule, request maintenance, report |
| **Biomedical** | Register asset | Fix/remove unavailable action |
| **HR** | — | Work requests, HR activity |
| **Communications** | — | — |
| **Integrations** | Create integration | Create API, create webhook |
| **Reports** | — | — |
| **Settings** | — | Align refresh with shared pattern |
| **Access admin** | Primary admin action | — |
| **Tenant/facility setup** | — | — |
| **Mortuary** | — | — |

**Modals:** Same shared dialog for add patient, start admission, create order — including cross-module deep links.

---

## 5. Worklist & filter bar

Enforce existing unified pattern ([`ui-patterns.mdc`](frontend/.cursor/ui-patterns.mdc)):

- Section title + one-line description
- Full-width debounced search
- Filter (funnel) + column settings (gear) via shared filter bar
- `AppListTable`: sortable columns, zebra rows, pagination, mobile list fallback
- Localized empty/error states via `AsyncStateScaffold` / table empty state

Do not regress table styling during header refactor.

---

## 6. Status badge standardization

Use `AppWorkspaceLiveStatus` factory + `app_en.arb`:

| State | Label key pattern | Tone |
|---|---|---|
| Idle / subscribed | `*LiveStatus` | success |
| Saving / mutating | `*SavingStatus` | warning |
| Clinically distinct desk | module-specific key only when required | success |

---

## 7. Implementation order

### Phase 1 — Shared layer (no feature changes until this ships)

1. `AppConnectivityIndicator`, `AppFullscreenToggle`
2. `AppWorkspaceToolbar`, `AppWorkspaceRefreshAction`
3. `AppWorkspaceBoardToggle`, `AppWorkspaceViewToggle`
4. `AppGlobalFaultReportAction`, `AppGlobalHousekeepingRequestAction`
5. `AppWorkspaceLiveStatus`
6. Wire toolbar into `AppWorkspace` / `AppWorkspaceHeader`
7. Unit/widget tests for toolbar overflow and responsive label scope

### Phase 2 — Pilot migration + clean-up

OPD, IPD, Lab — migrate, delete old toolbar code, remove `_ModuleText` in those features, extract widgets if pages exceed 800 lines.

### Phase 3 — Rollout

Remaining registry screens — one PR per group (patient access, inpatient, clinical, diagnostics, revenue, facility, platform).

### Phase 4 — Dashboard & settings

Align headers without breaking custom dashboard body layouts.

### Phase 5 — Verification

Manual pass at `127.0.0.1:5201` on xs, sm, md, lg, xl for every in-scope route + `flutter analyze` + affected tests.

---

## 8. Pre-migration checklist (per screen)

Before marking a screen done ([`ui-workspace.mdc`](frontend/.cursor/ui-workspace.mdc) + [`checklists.mdc`](frontend/.cursor/checklists.mdc)):

1. [ ] Searched `lib/shared/` — no duplicate component created
2. [ ] Uses `AppWorkspaceToolbar` — no ad-hoc action `Row`/`Wrap`
3. [ ] All strings in `app_en.arb`; no `_FeatureText` class remains
4. [ ] Theme tokens only — no hard-coded colors/spacing/typography
5. [ ] Actions permission-gated; routes still guarded
6. [ ] Summary cards filter worklist; zero-value cards hidden when expected
7. [ ] Refresh uses `AppWorkspaceRefreshAction`; global actions present
8. [ ] Inline auth/error blocks removed from content stack
9. [ ] Page ≤ 800 lines or widgets extracted to `presentation/widgets/`
10. [ ] Dead code from old toolbar/header removed
11. [ ] `flutter analyze` clean for touched files
12. [ ] Realtime subscription preserved (if module had one)

---

## 9. Acceptance criteria

### Uniformity

- [ ] All in-scope screens use shared toolbar and global actions
- [ ] Refresh identical everywhere (icon, tooltip, loading)
- [ ] Primary action visually distinct and consistently placed
- [ ] Patient/bed board toggles match (IPD, ICU)
- [ ] Status badges use shared factory + l10n keys
- [ ] Small screens: icon + toolbar only; no title overflow

### Reusability & clean-up

- [ ] No feature-local header/toolbar clones remain
- [ ] No `_ModuleText` private string classes in migrated features
- [ ] Shared dialogs used for cross-module flows (add patient, admission, orders)
- [ ] No parallel button/table/workspace abstractions introduced
- [ ] Biomedical unavailable action fixed or removed

### Efficiency

- [ ] Toolbar/header split into small widgets; no whole-state watches in chrome
- [ ] Search debounced; tables paginated
- [ ] Modal mutations trigger targeted refresh, not full-page reload
- [ ] `const` used where applicable in shared chrome widgets

### Compliance

- [ ] [`design-system.mdc`](frontend/.cursor/design-system.mdc) — tokens only
- [ ] [`localization_i18n.mdc`](frontend/.cursor/localization_i18n.mdc) — no hard-coded UI strings
- [ ] [`accessibility.mdc`](frontend/.cursor/accessibility.mdc) — semantic labels, keyboard, focus
- [ ] [`permissions.mdc`](frontend/.cursor/permissions.mdc) — gated actions
- [ ] [`ui-feedback.mdc`](frontend/.cursor/ui-feedback.mdc) — async states at scaffold level
- [ ] [`performance.mdc`](frontend/.cursor/performance.mdc) — lazy lists, focused rebuilds
- [ ] `flutter analyze` and affected `flutter test` pass

---

## 10. Do not

- Add feature-local `_ModuleText` string classes — use `app_en.arb`.
- Create duplicate table/list/header/toolbar components when shared catalog covers the case.
- Put business logic or module copy inside `lib/shared/` widgets.
- Change backend API contracts, permissions model, or route guards — **layout and presentation only**.
- Hard-code colors, spacing, or typography in feature presentation code.
- Block urgent fixes on full page extraction — migrate incrementally via shared widgets.
- Ship a migrated screen without deleting superseded code.

---

## Overall outcome

One shared layout system: maximum component reuse, less duplicate code, faster UI, and full compliance with project rules. A clinician moving from Emergency → OPD → Lab → Discharge should recognize every control immediately on any screen size — and the codebase should have one obvious place to change toolbar behavior app-wide.
