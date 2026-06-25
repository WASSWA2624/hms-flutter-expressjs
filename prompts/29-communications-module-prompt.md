# Notifications and Communications Module — Implementation Prompt

## Objective

Complete **Notifications and Communications** for HOSSPI HMS: in-app notifications, unread badges, conversations, messages, workflow reminders, and delivery state — supporting staff coordination across OPD, IPD, and operational modules without replacing module-owned workflows.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Notifications and communications row
2. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §17 turnaround (notify doctor/nurse on critical results, housekeeping on bed release)
3. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — realtime row refresh after actions; notifications as secondary channel

**Central rule:** notifications **inform** and deep-link to module workspaces (`/opd?id=`, `/ipd?id=`, etc.) — they do not mutate clinical state without opening the target module action.

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

### OPD / IPD

| Concept | Communications responsibility |
| ------- | --------------------------- |
| Workflow reminders | Lab result ready, critical alert, pending discharge — link to Clinical/OPD/IPD |
| Deep links | Parse notification payload paths to pre-select patient in target workspace |
| Badge counts | `GET /notifications/metrics` drives app bar badge |
| Realtime | WebSocket domain events may also drive snackbars in modules — avoid duplicate noise |

### App write-up

- Conversations and messages for staff coordination (non-clinical record).

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend | `frontend/lib/features/communications/` | Workspace page, controller, repository |
| Backend | `communications-workspace`, `notification`, `conversation`, `message` | |
| APIs | `GET /communications-workspace/workspace`; conversation/message CRUD; notification read/archive | |
| Feature flag | `communications_workspace_v1` | |

### Known gaps

- Message attachments — backend supports multipart; frontend JSON-only
- `reference-data` / `resolve-legacy` unused
- Participant management UI limited
- Deep link handling from notifications inconsistent across modules
- Frontend tests limited

---

## Scope — Core Capabilities

1. **Notification inbox** — read, archive, unread filters; metrics badge.
2. **Conversations** — thread list, messages, participants.
3. **Compose and reply** — text + attachments when wired.
4. **Deep links** — open OPD/IPD/lab rows from notification tap.
5. **Realtime** — subscribe to notification group; increment badge.

---

## UI / UX Requirements

This is a **notifications and messaging** surface — an inbox/messaging paradigm, **not** a patient worklist.

- **Layout:** `AppWorkspace` shell hosting a two-pane inbox — left: filterable notification center and conversation/thread list (`AppListTable` / list items with unread vs read state, unread badges, last-message preview, timestamp); right: detail panel showing the selected notification or the full message thread.
- **Notification center:** unread/read state, per-category counts, and an unread badge that drives the app-shell badge; filters (unread, all, archived) refine the list in place — they do not open separate routes.
- **Compose / reply:** open in modals (`AppDialog` / `app_workspace_mutation_dialog`) for new message, reply, and participant management; attachments via `app_file_upload_panel` when wired. Use nested modals for sub-steps (e.g., add participant within compose).
- **Deep links:** tapping a notification informs and routes to the target module workspace (`/opd?id=`, `/ipd?id=`); it must not mutate clinical state in place.
- Theming (light/dark/system), full localization via `app_en.arb`, and responsive layout across Android, iOS, web, Windows, macOS, Linux (single-pane fallback on narrow widths).
- Stable, error-free widgets; no runtime or compilation regressions.
- Peer with inbox/messaging patterns (notification center, conversation threads) for consistency — not clinical worklists.

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

- [ ] Users see unread notification count on app shell.
- [ ] Notifications deep-link to correct module when path provided.
- [ ] Conversations send/receive messages reliably.
- [ ] Communications does not bypass module permissions for clinical actions.

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
frontend/lib/features/communications/
backend/src/modules/communications-workspace/, notification/, conversation/

Related prompts: prompts/07-home-dashboard-module-prompt.md, prompts/12-opd-module-prompt.md, prompts/19-ipd-module-prompt.md
```
