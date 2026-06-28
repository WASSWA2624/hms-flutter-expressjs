# UI Layout Unification — HOSSPI HMS

Unify the app shell, page headers, toolbars, and action buttons so every module workspace feels consistent, responsive, and polished. Implement shared behavior once in `frontend/lib/shared/`, then migrate each applicable screen to use it.

**Reference contract:** `frontend/.cursor/ui-workspace.mdc`  
**Primary shared widgets:** `AppWorkspace`, `AppWorkspaceHeader`, `ResponsiveAppShell`, `AppScreen`, `AppListTable`, `AppButton`, `AppIconButton`, `AppDialog`

---

## Goal

One predictable layout system across clinical, operational, and admin screens:

1. **App shell** — logo, connectivity, notifications, account, optional full-screen toggle.
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
| Refresh control | Mix of `AppIconButton` and `AppButton.secondary` with label | One shared refresh action widget; same placement (right cluster, last item before overflow) |
| Primary actions | Some modules use `primaryAction`, others put create/add in `secondaryActions` | One primary create/start action per screen; use `primaryAction` slot |
| Action order | Refresh, config, view-toggle, and add buttons appear in different orders | Standard order (see Toolbar spec) |
| Status label | "Live sync", "Live board", "Live", "Discharge desk active", etc. | Standard status copy via `app_en.arb` keys |
| Connectivity | Green dot + "Online" text; on small screens dot also on avatar | Windows-style network icon; dedicated indicator on all breakpoints |
| Summary cards | Different card counts, borders, and filter behavior | Shared `AppWorkspaceSummaryCard`; cards filter worklist, never open duplicate modals |
| View toggles | Patient board / bed board styled differently on IPD vs ICU | Shared toggle component, same size and selected state |
| Inline auth blocks | "Sign-in required" between summary cards and table (Theater, Radiology) | Use `AsyncStateScaffold` / session gate at page level; never break the content stack |
| Settings | Uses `AppScreen` with different header action pattern | Align header/toolbar with workspace screens where practical |

---

## Canonical page layout stack

Every module work queue must follow this stack (from `ui-workspace.mdc`):

```
AsyncStateScaffold
└── ResponsivePage
    └── AppWorkspace (or AppScreen for settings-style pages)
        ├── AppWorkspaceHeader  — title, status, toolbar
        ├── AppWorkspaceSummaryGrid (optional; hide zero-value cards when pattern expects it)
        ├── AppWorkspaceFilterBar / search row (filter + settings icons)
        ├── AppListTable or module body
        └── AppWorkspaceDetailPanel (optional)
```

**Rules:**

- Import from `shared/layout/layout.dart`, `shared/components/components.dart`, `shared/actions/actions.dart` — no feature-local header/toolbar clones.
- Summary cards **filter** the current worklist; they must not open modal lists of the same data.
- Use hospital workflow language in labels — never raw enum/API codes in UI.
- Show display IDs and patient names only — no raw UUIDs.
- Gate actions with `AppAccessActionGate` / `AppPermissionActionButton`.
- After modal mutations, refresh the affected row, detail panel, summary counts, and nav badges.

---

## 1. App shell header (top bar)

**File:** `frontend/lib/shared/layout/responsive_shell_scaffold.dart` (and related shell widgets)

### Large screens (md+)

Keep current structure: sidebar | logo + app name | … | connectivity | notifications | account.

### Connectivity indicator

Replace the current dot + "Online"/"Offline" pill with a **network-style icon** (similar to Windows 10 taskbar):

- **Online:** green icon (wifi or signal bars).
- **Offline:** muted/red icon, visually distinct.
- Keep accessible text label (`onlineLabel` / `offlineLabel`) for screen readers.
- Tooltip on hover showing connection state.

### Small screens (xs–sm)

- Show connectivity as its **own control** in the top bar — not as a dot on the account avatar.
- Remove `showStatusDot` on `_UserAvatar` for compact breakpoints (or gate it off entirely once the dedicated indicator exists).

### Notifications & account

- Notifications button: unchanged; navigates to communications/notifications.
- Account menu: unchanged.

### Full-screen toggle (new)

Add a global control in the app shell header (right cluster, before notifications):

- Toggles browser/app full-screen via `fullscreen` API on web and platform equivalent elsewhere.
- Icon-only on small screens; icon + "Full screen" label on large screens.
- Persist nothing — toggle is session-only.

---

## 2. Page header & toolbar

**Implement in shared code** — extend `AppWorkspace` / `AppWorkspaceHeader` (or add `AppWorkspaceToolbar`) so pages declare actions declaratively instead of assembling raw widget lists.

### Header content

| Element | Large screens | Small screens (xs–sm) |
|---|---|---|
| Leading | Module icon (`AppWorkspaceTitleIcon`) | Module icon only |
| Title | Module title (`titleLarge` / compact header style) | **Hidden** — icon carries meaning |
| Status | `AppWorkspaceStatusBadge` e.g. "Live sync" | **Hidden** on xs; optional compact badge on sm |
| Toolbar | Full row below header when stacked | Dedicated toolbar row below icon row |

On small screens, the page title and status text currently overflow and push actions down — fix by hiding title/status and moving all actions into a single toolbar row.

### Toolbar layout

```
[ Page-specific actions …………………… Global actions | ⋮ overflow ]
     LEFT (start)                              RIGHT (end)
```

**Page-specific (left → right):**

1. View/mode toggles (patient board / bed board, orders/patients view, etc.)
2. Secondary module actions (config, catalog, reports, shift controls)
3. **Primary module action** — one per screen (Add patient, Start OPD, Schedule case, etc.)

**Global (right → left, rightmost first):**

1. **Refresh** (always present on workspace screens)
2. **Request housekeeping / maintenance**
3. **Report equipment fault**
4. *(App shell only)* Full-screen toggle

Use `AppButton.primary` for the single primary module action. Use `AppButton.secondary` (icon + label) or `AppIconButton` consistently via `AppActionLabelScope`:

- **Large screens:** icon left, label right.
- **Small screens:** icon only (`forceIconOnly: true`).

### Overflow menu

When actions do not fit the available width, collapse excess actions into a **⋮ overflow menu** (`PopupMenuButton`):

- Each overflow item shows **icon + label**.
- Prefer collapsing secondary/global actions before the primary module action.
- Never hide refresh entirely — keep it visible or as the first overflow item.

### Shared refresh action

Create `AppWorkspaceRefreshAction` (or equivalent) used by every workspace:

- `AppIconButton` with `Icons.refresh`, loading state, shared tooltip (`commonRefreshActionLabel`).
- Wired to each controller's `refresh()` method.

---

## 3. Global actions (every workspace page)

### Report equipment fault

- Available on nearly every in-scope page (respect permissions where biomedical write is required).
- Opens shared `AppDialog` / existing biomedical fault form.
- Fields: photo capture/upload, description, location, optional asset/equipment reference, routing hint (operations, biomedical, plumbing, etc.).
- Reuse biomedical fault dialog if it exists; do not duplicate forms per module.

### Request housekeeping / maintenance

- Available on every in-scope page.
- Opens shared dialog for cleaning/maintenance requests (dirty room, linen, spill, etc.).
- Routes to housekeeping module; request visible to responsible staff.

### Refresh

- Always in the global (right) cluster via shared widget.

Wire global actions through a shared provider or callback passed into `AppWorkspace` so individual pages do not reimplement dialogs.

---

## 4. Per-screen action registry

Use this registry when migrating each page. **Primary** = one `AppButton.primary`. Everything else = secondary (left) or global (right).

| Screen | Primary action | Page-specific secondary actions |
|---|---|---|
| **Dashboard** | — | Role quick actions stay in dashboard body; header: refresh only |
| **Patients** | Add patient | Emergency registration |
| **OPD** | Start OPD encounter | — |
| **Emergency** | Quick arrival | — |
| **IPD** | Start admission | Patient board / bed board toggle |
| **Rooms and beds** | Set up (if permitted) | Manage layout/grid toggle |
| **ICU** | — | Patient board / bed board toggle |
| **Nursing** | — | Shift key, ward context (if applicable) |
| **Discharge** | — | — |
| **Clinical** | — | — |
| **Physiotherapy** | — | — |
| **Theater** | Schedule case | — |
| **Lab** | Create lab order | Orders/patients view toggle, lab configuration |
| **Radiology** | Request imaging | Orders/patients view toggle, radiology configuration |
| **Pharmacy** | — | Catalog and store |
| **Billing** | — | Code shift, close day |
| **Claims** | Prepare claim | Request authorization |
| **Subscriptions** | Activate subscription | — |
| **Operations** | Create request | Report |
| **Housekeeping** | Create task | Create schedule, request maintenance, report |
| **Biomedical** | Register asset | Investigate/fix action that currently shows "This action isn't available" |
| **HR** | — | Work requests, HR activity |
| **Communications** | — | — |
| **Integrations** | Create integration | Create API, create webhook |
| **Reports** | — | — |
| **Settings** | — | Setup/deep links as today; align refresh with shared pattern |
| **Access admin** | Primary admin action as today | — |
| **Tenant/facility setup** | — | — |
| **Mortuary** | — | — |

**Patient board / bed board:** Use one shared `AppWorkspaceBoardToggle` on IPD, ICU, and any future screen that needs it — same visual design and semantics.

**Modals:** Adding a patient, starting an admission, or creating an order must use the **same dialog flow** wherever that action appears (including cross-module deep links).

---

## 5. Worklist & filter bar (unchanged but enforce)

Below the toolbar, keep the existing unified pattern already visible on most screens:

- Section title + one-line description ("OPD encounters", "Ward worklist", etc.)
- Full-width search with magnifying glass
- Filter (funnel) and column settings (gear) on the right
- `AppListTable` with sortable columns, zebra rows, pagination footer

Do not regress table styling when refactoring headers.

---

## 6. Status badge standardization

Add or reuse `app_en.arb` keys:

| State | Label | Tone |
|---|---|---|
| Idle / subscribed | Live sync | success |
| Saving / mutating | Saving | warning |
| Module-specific desk active | Use module-specific key only when clinically meaningful (e.g. discharge desk) | success |

Avoid one-off variants ("Live board", bare "Live") unless the module contract requires distinct meaning.

---

## 7. Implementation order

1. **Shared layer**
   - Network-style connectivity badge in shell.
   - Full-screen toggle in shell.
   - `AppWorkspaceToolbar` (or extend `AppWorkspaceHeader`) with left/right clusters, responsive labels, overflow.
   - `AppWorkspaceRefreshAction`, global fault report, global housekeeping request.
   - `AppWorkspaceBoardToggle` for IPD/ICU.

2. **Pilot migration** — OPD, IPD, Lab (representative patterns).

3. **Roll out** — remaining screens in the registry table.

4. **Dashboard & settings** — align headers/toolbars without breaking custom dashboard layouts.

5. **Verification** — manual pass at `127.0.0.1:5201` on xs, sm, md, lg breakpoints for every in-scope route.

---

## 8. Acceptance criteria

- [ ] All in-scope screens use the shared toolbar; no page builds ad-hoc `Row`/`Wrap` of mixed button types for header actions.
- [ ] Refresh looks and behaves identically everywhere (icon, tooltip, loading spinner).
- [ ] Primary action is visually distinct and consistently placed (left cluster, last secondary before globals, or dedicated primary slot).
- [ ] Global actions (refresh, fault report, housekeeping request) appear on every workspace page in the right cluster.
- [ ] Small screens: page title/status hidden; icon + toolbar only; no action wrapping that pushes content down.
- [ ] Overflow menu appears when actions exceed width; no clipped buttons.
- [ ] Connectivity uses network icon; small screens show dedicated indicator, not avatar dot.
- [ ] Full-screen toggle works on web.
- [ ] Patient/bed board toggles match between IPD and ICU.
- [ ] No inline "Sign-in required" blocks breaking the summary → table flow.
- [ ] All new strings in `app_en.arb`; no hard-coded colors/spacing in feature presentation code.
- [ ] Biomedical unavailable action investigated and either wired or removed.

---

## 9. Do not

- Add feature-local `_ModuleText` string classes — use localization.
- Create duplicate table/list components when `AppListTable` suffices.
- Change business logic, permissions, or API contracts — this is a **layout and action presentation** pass.
- Block urgent fixes on full extraction of large pages; migrate incrementally but always via shared widgets.

---

## Overall outcome

The header, page toolbar, and actions should feel like one system. A clinician moving from Emergency → OPD → Lab → Discharge should recognize every control immediately, on any screen size.
