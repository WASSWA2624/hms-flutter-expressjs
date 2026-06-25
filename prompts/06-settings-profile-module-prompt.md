# Settings and User Profile Module — Implementation Prompt

## Objective

Complete **General Settings** and **User Profile** for HOSSPI HMS: user-level preferences (theme, language, accessibility), settings navigation hub, and profile display — distinct from tenant/facility administration.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — General settings row; Authentication row (password)
2. Platform UX rules in `frontend/.cursor/` — localization, accessibility, theme

**Central rule:** settings change **user experience** only, not hospital organizational data (that is [prompts/03-tenant-facility-module-prompt.md](./03-tenant-facility-module-prompt.md)) or clinical records.

---

## Global Implementation Standards

Mandatory platform rules for all work in this module.

| Area | Requirement |
| ---- | ----------- |
| Product scope | [app-write-up.mdc](../.cursor/app-write-up.mdc) — respect module boundaries; do not duplicate workflows owned elsewhere. |
| Patient flows | Align with [`.cursor/flows/`](../.cursor/flows/). Use [opd-flow.mdc](../.cursor/flows/opd-flow.mdc) and [ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) for journey touchpoints; read the module-specific flow file when one exists (lab, nursing, pharmacy, radiology, discharge, emergency, icu, theater). |
| Encounters | One active OPD encounter per outpatient visit; IPD admission as inpatient hub; overlays (ICU, Theater) and executing departments attach — never parallel admission records. |
| UI/UX | Modern, clean, minimal on-screen text; hospital workflow language (not enum names or UUIDs). Follow `frontend/.cursor/design-system.mdc`, `components.mdc`, `ui-patterns.mdc`, `ui-workspace.mdc`, `layouts.mdc`, `platform_guidelines.mdc`. Reuse `frontend/lib/shared/*` before creating new widgets. Responsive on Android, iOS, web, Windows, macOS, Linux. |
| Theming and i18n | Full theme support (light/dark/system). All user-visible strings in `app_en.arb` — no hardcoded labels. |
| Modal-first workflows | **All create/edit/approve/complete/handoff actions** use **in-page dialogs, bottom sheets, or nested modals**. Do **not** navigate to new routes for within-module workflows. Shell entry routes (`/opd`, `/ipd`, etc.) and deep-link **pre-selection** of a patient/record are allowed; selecting a row opens the workspace detail panel — not a separate workflow page. |
| Realtime sync | Subscribe to relevant `RealtimeEventGroups` in workspace controllers. After mutations, refresh affected rows, detail panels, summary cards, and nav badges. Keep UI, frontend state, backend services, and database consistent. |
| Architecture | UI/controllers → repository → API (`frontend/.cursor/feature_workflow.mdc`, `architecture.mdc`). Enforce RBAC + ABAC + tenant/facility scope + module entitlements (frontend `AccessGate` + backend authorization). |
| Database | Apply migrations for schema changes per backend standards; keep API contracts and schema aligned. |
| Quality gate | From `frontend/`: `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`. From `backend/`: targeted `npm test` for touched modules. |

---


## Flow Integration Requirements

### OPD / IPD (indirect)

| Concept | Settings responsibility |
| ------- | ----------------------- |
| Language | Localized OPD/IPD labels via `app_en.arb` + user locale preference |
| Theme / accessibility | Readable clinical workspaces under user preferences |
| No flow mutations | Settings never change OPD/IPD stages |

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Settings | `frontend/lib/features/settings/` | `settings_page`, workspace repository |
| Backend | `settings-workspace` | `GET /settings-workspace/workspace`, reference-data |
| Profile | `frontend/lib/features/profile/` | `user_profile_page.dart` — session display only |
| Auth password | `change_password_dialog.dart` in auth feature | |

### Known gaps

- Settings workspace is largely a **navigation hub** — few mutable preferences persisted
- Security sub-routes disabled in `settings_workspace_section.dart`
- Profile does not call `user-profile` APIs — shows `AuthSession` only
- Users/roles routes stubbed → [prompts/04-access-admin-module-prompt.md](./04-access-admin-module-prompt.md)
- Feature flag `settings_workspace_v1`

---

## Scope — Core Capabilities

1. **Preferences** — theme mode, language, accessibility options; persist per user.
2. **Settings hub** — deep links to tenant facility, subscriptions, access admin, integrations.
3. **Profile page** — display name, email, roles; link to change password.
4. **Profile edit** — wire `user-profile` API when available.
5. **Localization** — all settings strings in `app_en.arb`.

---

## UI / UX Requirements

- **Sectioned settings hub + profile view** — grouped preference sections (appearance/theme, language & region, accessibility, account/security) plus a profile panel showing name, email, and roles. No patient worklist, no summary/KPI cards.
- Preference controls (theme mode, language, accessibility) are edited inline or via **modal/bottom-sheet** (`frontend/lib/shared/components/app_dialog.dart`, `app_workspace_mutation_dialog.dart`); changes persist per user and apply immediately to the running app.
- Hub rows **deep-link** into admin modules (tenant/facility, subscriptions, access admin, integrations) through shell routes — those workflows are owned elsewhere and not duplicated here.
- Change password opens the auth `change_password_dialog` (modal-first), not a separate route.
- Reuse shared components: `app_content_panel.dart`, `app_info_tile.dart`, `app_switch_field.dart`, `app_select_field.dart`.
- Full theming (light/dark/system), all strings localized via `app_en.arb`, responsive across Android, iOS, web, Windows, macOS, Linux.
- Stable, error-free widgets; no runtime or compilation regressions.
- Pattern peers: other settings/preferences and profile screens, not clinical worklist workspaces.

---


## Architecture and Conventions

| Rule | Requirement |
| ---- | ----------- |
| Layering | Widgets → Riverpod controllers → repository interface → impl → API client. No API calls from widgets. |
| State | `AsyncNotifier` + `Result<T>` / `AppFailure` for errors. |
| Permissions | `AccessGate` / `AppAccessActionGate`; backend auth mandatory even when UI hides actions. |
| File size | Extract reusable widgets to `presentation/widgets/`; shared components to `frontend/lib/shared/`. |
| Realtime | `frontend/.cursor/realtime_sync.mdc` — partial refresh after modal success when supported. |

---


## Acceptance Criteria

- [ ] User can change theme/language and see effect on OPD/IPD workspaces.
- [ ] Settings hub navigates to implemented admin modules.
- [ ] Profile shows accurate session roles/permissions.
- [ ] Change password works from profile or settings entry point.

---

## Quality Gate

From `frontend/` when touching Flutter:

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

From `backend/` when touching API or schema:

```sh
npm test -- --testPathPattern="<module>"
```

Apply database migrations per backend workflow before merging schema changes.

---


## Key File References

```
frontend/lib/features/settings/
frontend/lib/features/profile/
backend/src/modules/settings-workspace/

Related prompts: prompts/01-auth-module-prompt.md, prompts/04-access-admin-module-prompt.md, prompts/03-tenant-facility-module-prompt.md
```
