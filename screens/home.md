# Action inventory — `/`

Primary surface: `HomePage` (`frontend/lib/features/home/presentation/pages/home_page.dart`).

Authority: shell route is authenticated; tab content requires `profile:read`
(`homeTabReadRequirement` / `AppAccessGate`). Per-atom KPI / queue / alert /
chart / shortcut / action gates use `HomeDashboardAtomPermissions` and
`homeActionLibrary` (all-of within each atom; union across grants). Backend
RBAC remains authoritative for mutations opened from dialogs.

Permission helpers: `frontend/lib/features/home/presentation/home_access.dart`
(`homeTabReadRequirement`, `homeChartsRequirement`, `homeAtomRequirement`,
`homeStatusCardRequirement`, `homeShortcutRequirement`).

Dialog chrome: each home-invoked `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Permission atom map

| Atom | Intent | Requirement |
| --- | --- | --- |
| Home surface (`HomePage` body) | read | `profile:read` ∩ (`homeTabReadRequirement`) |
| Load / **Try again** | read chrome | `profile:read` ∩ |
| Tenant / Facility / Branch + **Open dashboard** | navigate / chrome | `profile:read` ∩ (context panel when required) |
| Status / KPI cards | read (navigate when entitled) | Per-card `requiredPermissions` / `HomeDashboardAtomPermissions.statusCards` ∩ |
| Next steps (`AppQuickActions`) | create / update / navigate | Per-action `HomeActionDefinition.requiredPermissions` ∩ (+ modules / shell route) |
| Queue / results / follow-ups rows | read / navigate | Per-item catalog ∩ (`queueItems` / module slug) |
| Alerts rows | read / navigate | Per-alert catalog ∩ (`alerts`) |
| Empty-queue manage actions | create / update / navigate | Same as Next-step action defs ∩; ids excluded when already in Next steps |
| **View all** (queue / results / follow-ups) | navigate | First filtered item target; absent when no entitled target |
| Quick links (module shortcuts) | navigate | Per-shortcut catalog ∩ (`homeShortcutRequirement` / `shortcuts`) |
| Trend / distribution charts | read | `reports:read` ∩ (`homeChartsRequirement`) |
| Nested write dialogs opened from Next steps / empty manage / metric actions | create / update / approve | Parent action / card write keys ∩; dialog not opened without those rights (`homeInvokeAction` re-checks `isAllowed`) |
| Tab create / update / delete matrix rows | — | _(n/a — verbs live on per-atom Dashboard.md / action defs)_ |
| Nested cross-module matrix rows | — | _(n/a at tab matrix; cross-module atoms use their own module `*:read`/`*:write`)_ |

Union across grants filters the visible atom set; intersection within each atom.
Subscription / plan module map strips atoms whose permission domains are inactive
even when a role pack string is present. Shell keeps Home for authenticated users;
without `profile:read` the body is empty (`SizedBox.shrink`), not a “no access” banner.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Super-admin **Next steps** create + manage for same domains | Create tenant/facility/role/user vs manage lists | **Split** — creates stay in Next steps; manage actions only on empty queue |
| Tenant-admin **manage_users** + **manage_users_roles** | Same manage-users dialog | **Removed** `manage_users_roles`; keep `manage_users` on empty queue only |
| Tenant-admin manage actions also in Next steps | Same manage dialogs | **Moved** manage to empty queue; Next steps are create / onboard only |
| Facility-admin / receptionist **Book appointment** + **Check in patient** | Both navigated to `/reception?section=appointments` | **Removed** check-in from those profiles; nurse keeps check-in (no book) |
| Empty-queue actions repeating Next steps | Same labeled actions twice | **Removed** overlapping `emptyActionIds`; mapper also excludes quick-action ids |
| Patient **Update my profile** + **View my care** | Both opened `/profile` | **Merged** — Next steps: Update my profile + Contact facility |
| Legacy action ids (`new_patient`, `lab_order`, …) | Parallel defs for same goals | **Canonicalized** via `homeActionCanonicalIds` to one primary definition |
| Quick links matching a Next-step route | Module shortcut + quick action | **Kept** filter in `homeShortcutsExcludingQuickActions` |

---

## Home dashboard screen

### Load / retry

- **Try again**
  - Location: `AsyncStateScaffold` on load failure.
  - Opens modal: No.
  - Immediate result: Clears optimistic patch and reloads dashboard.
  - Condition: Load failure.

### Tenant context (when `isTenantContextRequired`)

- **Tenant / Facility / Branch** selects + **Open dashboard**
  - Location: `HomeTenantContextPanel`.
  - Opens modal: No.
  - Immediate result: Navigates to `/?tenant_id=…&facility_id=…`.
  - Condition: Context required; Open dashboard enabled when tenant selected.
- **Tenant shortcut buttons** (lookups failure fallback)
  - Location: Same panel.
  - Opens modal: No.
  - Immediate result: Opens dashboard scoped to that tenant.
  - Condition: Lookups error/empty with `tenantOptions` present.

### Next steps (`AppQuickActions`)

Role-specific primary actions from `profile.quickActionIds` (permission-filtered). Representative entries:

- **Create tenant / facility / role / user** (super-admin)
- **Create facility / role / user / Add staff profile** (tenant-admin)
- **Register patient / Book appointment** (facility-admin, receptionist; receptionist also **Route patient**)
- **Continue consultation / Order lab / Order imaging / Write clinical note** (doctor)
- **Update my profile / Contact facility** (patient, limited account)

  - Location: Next steps strip.
  - Opens modal: Dialog for create/manage/onboard actions; otherwise navigates to workspace.
  - Immediate result: Dialog save refreshes dashboard; navigation opens target route.
  - Condition: Action allowed by modules, roles, permissions, and shell route; unauthorized actions absent.

### Priority / queue panel

- **Queue / alerts / results / follow-ups** rows
  - Location: `DashboardPriorityPanel`.
  - Opens modal: No (navigates via worklist target).
  - Immediate result: Opens module route or subscription surface when entitled.
  - Condition: Profile shows that section; row has accessible target.
- **Empty-queue manage actions** (platform / org admin; billing review actions)
  - Location: Empty queue panel only.
  - Opens modal: Matching manage dialog, or navigates for billing review.
  - Immediate result: Same as Next-step invoke path; never repeats an id already in Next steps.
  - Condition: Queue empty; action authorized.
- **View all**
  - Location: Queue / results / follow-ups header when a first target exists.
  - Opens modal: No.
  - Immediate result: Navigates to first queue target.
  - Condition: At least one item with a target.

### Quick links

- **Module shortcuts** (Reception, Patients, OPD, …)
  - Location: Priority panel shortcuts.
  - Opens modal: No (subscription shortcut may open dialog for non-elevated users).
  - Immediate result: Navigates to module; routes already covered by Next steps are hidden.
  - Condition: Profile shortcuts enabled; shell access granted.

### Metrics strip

- **Status cards**
  - Location: Metric strip.
  - Opens modal: Optional metric action dialog when configured.
  - Immediate result: Navigates via `homeMetricNavigation` or invokes metric action.
  - Condition: Card actionable and entitled; otherwise display-only.

### Charts

- Trend / distribution charts (progressive detail; empty messages when no data).
  - Condition: Profile shows charts when data rules allow.
