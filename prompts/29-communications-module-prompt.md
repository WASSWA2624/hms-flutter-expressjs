# Notifications and Communications Module — Implementation Prompt

## Objective

Complete **Notifications and Communications** for HOSSPI HMS: in-app notifications, unread badges, conversations, messages, workflow reminders, and delivery state — supporting staff coordination across OPD, IPD, and operational modules without replacing module-owned workflows.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Notifications and communications row
2. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §17 turnaround (notify doctor/nurse on critical results, housekeeping on bed release)
3. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — realtime row refresh after actions; notifications as secondary channel

**Central rule:** notifications **inform** and deep-link to module workspaces (`/opd?id=`, `/ipd?id=`, etc.) — they do not mutate clinical state without opening the target module action.

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

## Acceptance Criteria

- [ ] Users see unread notification count on app shell.
- [ ] Notifications deep-link to correct module when path provided.
- [ ] Conversations send/receive messages reliably.
- [ ] Communications does not bypass module permissions for clinical actions.

---

## Key File References

```
frontend/lib/features/communications/
backend/src/modules/communications-workspace/, notification/, conversation/

Related prompts: prompts/07-home-dashboard-module-prompt.md, prompts/12-opd-module-prompt.md, prompts/19-ipd-module-prompt.md
```
