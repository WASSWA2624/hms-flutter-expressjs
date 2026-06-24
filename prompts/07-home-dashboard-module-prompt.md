# Home and Dashboard Module — Implementation Prompt

## Objective

Complete the **Home Dashboard and App Shell Entry** for HOSSPI HMS: role-based landing experience, workload summaries, quick actions into OPD/IPD and other modules, notification badges, and integration with backend dashboard workspace — the first screen staff see after login.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — App identity and shell; Reports/dashboards row (widgets may embed here)
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — queue entry points for OPD roles
3. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — admission/bed queue entry for IPD roles

**Central rule:** home **navigates** to module workspaces; it does not duplicate OPD/IPD worklists. Summary counts should match backend queue metrics when dashboard API provides them.

---

## Flow Integration Requirements

### OPD flow

| Concept | Home responsibility |
| ------- | ------------------- |
| Role cards | Reception, nurse, doctor quick links to `/opd` with optional scope |
| Queue previews | Show OPD stage counts when `dashboard-workspace` provides KPIs |
| Workload badges | Nav badge patterns consistent with `opdWorkspaceController.workloadCount` |

### IPD flow

| Concept | Home responsibility |
| ------- | ------------------- |
| Bed/admission previews | IPD pending bed, discharge planned counts when API embeds |
| Quick actions | Link to `/ipd`, `/nursing`, `/discharge` per role profile |

### App shell

- App bar, user menu, notification badge entry to [prompts/29-communications-module-prompt.md](./29-communications-module-prompt.md).
- HOSSPI HMS branding per app identity row.

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend | `frontend/lib/features/home/` | `home_page.dart`, `home_repository_impl`, dashboard profiles |
| Backend | `dashboard-workspace`, `dashboard-widget`, `kpi-snapshot` | |
| API | `GET /dashboard-workspace/workspace` | Lookups endpoint unused |
| Fallback | Static role-based cards when no tenant or `AppRole.other` | |

### Known gaps

- Heavy reliance on fallback stub data
- `/dashboard-workspace/lookups` not called
- Queue preview/alerts empty in fallback mode
- Feature flag `dashboard_workspace_v1`
- Home page very large — extract role profile widgets

---

## Scope — Core Capabilities

1. **Role-based dashboard** — different quick actions per doctor, nurse, admin, etc.
2. **Live KPIs** — OPD waiting counts, IPD bed pressure, critical alerts when backend supplies.
3. **Quick navigation** — one-click to highest-workload module for role.
4. **App shell polish** — consistent with `frontend/.cursor/layouts.mdc` and navigation rules.
5. **Realtime** — refresh counts on domain events where feasible.

---

## Acceptance Criteria

- [ ] After login, user lands on meaningful role-specific home.
- [ ] OPD/IPD entry points visible for clinical roles with correct permissions.
- [ ] Dashboard uses backend workspace when flag enabled; graceful fallback otherwise.
- [ ] Notification badge links to communications module.

---

## Key File References

```
frontend/lib/features/home/
backend/src/modules/dashboard-workspace/
frontend/lib/app/router/app_router.dart

Related prompts: prompts/12-opd-module-prompt.md, prompts/19-ipd-module-prompt.md, prompts/29-communications-module-prompt.md, prompts/30-reports-audit-module-prompt.md
```
