# Communications Module — Staff Messaging & In-App Coordination

## Objective

Transform **Communications** from a read-mostly admin workspace (thread tables, notification logs, delivery audit, template preview) into a **first-class in-app messaging experience** for hospital staff — direct messages, groups, @mentions, attachments, read state, and system notifications — while keeping the existing four-panel shell and backend contracts.

**Entry point:** `/communications` (sidebar → **Communications**)

**Screenshot (current UI):** four tabs — **Inbox**, **Notifications**, **Deliveries**, **Templates** — with a searchable `AppListTable` on the left and a static detail panel on the right (e.g. template preview for *Recall Alert*). Messaging today is table-centric, not chat-centric.

**Parent context:** [prompts/29-communications-module-prompt.md](./prompts/29-communications-module-prompt.md) — platform standards, RBAC, deep links, realtime, and quality gate. This prompt **extends** that document with product UX for staff messaging.

**Initial rollout persona:** HR administrator (current test account), but the module must work for **any staff role** with `communications:write` — not HR-only.

---

## Problem Statement (from current UI & requirements)

| Area | Current behavior | Issue |
|------|------------------|-------|
| Inbox layout | `AppListTable` of threads; detail shows metadata tiles + up to 8 `AppListItemRow` messages | Feels like an audit log, not a messenger; no persistent compose bar |
| New conversation | `createConversation` exists on controller/repository | **No UI** to start a DM or group |
| Compose / reply | `AppTextActionDialog` — plain text only | No rich input, no inline reply, no draft persistence |
| @mentions | Not implemented | User expects `@` → staff picker dropdown; mentioned users get notified |
| Attachments | Backend multipart supported; frontend JSON-only | Cannot attach files, images, or captured screenshots |
| Groups | `ConversationType.GROUP` in schema | No create-group flow, no member management UI |
| Read receipts | `last_read_at` on participants | Not surfaced per message or per participant in thread |
| Notifications tab | System/task alerts (lab, assignments, facility events) | Correct separation from messages, but list UX should mirror inbox polish |
| Inbox actions | Archive/unarchive, unread/sensitive filters | Missing **favorite/star**, **flag**, and quick filters users expect in messaging apps |
| Responsive | `AppWorkspace` two-pane on wide; table in list slot | Narrow widths need chat-first single-pane with back navigation |
| Templates / Deliveries | Read-only admin surfaces | Keep as-is for v1 of this prompt; do not block messaging work |

Staff coordinating handoffs (e.g. HR ↔ department heads) should experience something closer to **Teams / Slack / WhatsApp** — simple, fast, familiar — not a data grid with a send dialog.

---

## Current Implementation

| Area | Location |
|------|----------|
| Workspace page | `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart` |
| Controller | `frontend/lib/features/communications/presentation/controllers/communications_workspace_controller.dart` |
| Entities / drafts | `frontend/lib/features/communications/domain/entities/communications_entities.dart` — `CommunicationConversationDraft`, `CommunicationMessageDraft` |
| Repository / API | `frontend/lib/features/communications/data/repositories/communications_repository_impl.dart` |
| Backend models | `conversation`, `message`, `conversation_participant`, `message_attachment`, `notification`, `template` — `backend/prisma/schema.prisma` |
| Workspace API | `backend/src/modules/communications-workspace/` |
| Conversation API | `backend/src/modules/conversation/` |
| Feature flag | `communications_workspace_v1` |
| File upload pattern | `frontend/lib/shared/components/app_file_upload_panel.dart` (used in patients, radiology, nursing) |
| Searchable pickers | `AppSelectField.searchable` (HR onboarding, availability) |
| Modal mutations | `showAppWorkspaceMutationDialog`, `AppDialog` — per `frontend/.cursor/ui-workspace.mdc` |

**Send message today:** detail panel → **Send message** → `AppTextActionDialog` → `controller.sendMessage(content)`.

**Message thread today:** `_MessageThread` renders max 8 rows with sender name, preview, timestamp — no bubbles, no scroll-to-latest, no read ticks.

---

## Target UX

### 1. Information architecture (keep four panels)

| Panel | Purpose | Messaging prompt scope |
|-------|---------|------------------------|
| **Inbox** | Staff DMs + groups | **Primary focus** — redesign as chat workspace |
| **Notifications** | System events (tasks assigned, facility alerts, module deep links) | Polish list + detail; not composeable messages |
| **Deliveries** | Channel delivery audit (SMS, email, in-app) | Read-only; no change required for messaging v1 |
| **Templates** | Message templates (SMS, in-app) | Read-only; no change required for messaging v1 |

### 2. Inbox — chat-first two-pane layout

**Wide layout (`AppWorkspace`):**

| Left pane | Right pane |
|-----------|------------|
| Conversation list (not `AppListTable` for inbox) | Active thread |

**Left pane — conversation list**

- Toolbar actions: **New message** (DM), **New group**
- Search (reuse `AppSearchBar` patterns)
- Quick filters: All · Unread · Favorites · Flagged · Archived
- Each row: avatar(s), title (person name or group name), last-message preview, relative timestamp, unread badge, favorite/flag icons
- Row tap selects thread and loads messages in right pane
- Sort by `last_message_at` descending

**Right pane — thread view**

- Header: participant(s) or group name; member count for groups; overflow menu (view members, mute/archive, mark unread)
- Scrollable message list (newest at bottom); load older on scroll-up
- Message bubble layout: own messages aligned end, others start; show sender name in groups
- Every message: **timestamp** (absolute on hover/long-press, relative in bubble footer)
- **Read receipts** on own messages: sent ✓ / read ✓✓ derived from participants' `last_read_message_id` or `last_read_at`
- **Reply** to a specific message (quote snippet above composer)
- Sticky **composer** at bottom (not a modal):
  - Multiline text field
  - `@` mention: typing `@` opens staff search overlay (`AppSelectField.searchable` or dedicated mention overlay); selected user inserted as token; backend notified on send (see §4)
  - Attach: file picker + image paste/drag (web) + camera/gallery (mobile) via `AppFileUploadPanel`
  - Send button; disabled when empty and no pending attachments

**Narrow layout (phone / narrow web):**

- Single pane: conversation list **or** thread (not both)
- Back chevron from thread to list
- Composer remains sticky at bottom of thread

### 3. New direct message

Modal (`AppDialog` / `showAppWorkspaceMutationDialog`):

1. **To:** searchable staff picker (tenant/facility scoped; reuse HR staff search API or communications reference-data endpoint)
2. Optional subject
3. If a DM already exists with that participant, open existing thread instead of creating duplicate
4. On create → select thread in right pane with composer focused

### 4. New group

Modal (multi-step or single scrollable form):

1. **Group name** (required)
2. **Members:** multi-select staff picker with search
3. Optional: mark as sensitive (maps to `is_sensitive`)
4. On create → open group thread; creator is participant

**Group management** (overflow menu → **Manage members**):

- Add/remove participants (respect backend permissions)
- Show join date and last-read per member (admin view)

### 5. @mentions

- Composer detects `@` + query text → dropdown of matching staff (name, role, department)
- Insert mention as structured token in message body (plain-text fallback: `@Display Name`)
- On send: parse mentions; create in-app notification for each mentioned user (even if not in thread)
- Render mentions with distinct style in message bubbles
- If backend lacks mention table, store in message metadata or extend API in backend pass (document in PR)

### 6. Attachments

- Wire `sendMessage` to multipart upload when attachments present (mirror backend conversation message endpoint)
- Show attachment chips in composer before send
- In thread: image thumbnails (tap to preview); file rows with name, size, download/open
- Support screenshot paste on web/desktop where platform allows

### 7. Notifications panel (secondary)

- Keep separate from Inbox — these are **not** user-composed chats
- Examples: task assigned, recall due, bed released, lab critical
- Row: icon by type, title, snippet, timestamp, unread state
- Detail: full body, deep link to source module (`target_path`), mark read/unread, archive
- Tapping deep link navigates to OPD/IPD/etc. without mutating clinical state in Communications

### 8. Inbox metadata actions

| Action | Behavior |
|--------|----------|
| Favorite | Pin/star thread; filter **Favorites** |
| Flag | Mark for follow-up; filter **Flagged** |
| Archive | Existing archive flow; hide from default list |
| Mark read/unread | Per thread |

Implement via conversation flags on backend if missing (`is_favorite`, `is_flagged` per participant or conversation-level fields); add migration only if needed.

### 9. Visual & accessibility standards

- Follow `frontend/.cursor/design-system.mdc`, `ui-patterns.mdc`, `ui-workspace.mdc`, `layouts.mdc`
- Light/dark/system themes; all strings in `app_en.arb`
- Touch targets ≥ 44dp; composer accessible labels; screen-reader friendly thread structure
- Responsive on Android, iOS, web, Windows, macOS, Linux
- Peer apps for interaction patterns: inline composer, mention autocomplete, read receipts, group threads — **not** for branding copy

---

## Architecture & Conventions

| Rule | Requirement |
|------|-------------|
| Layering | Extract new UI to `frontend/lib/features/communications/presentation/widgets/` — e.g. `communications_conversation_list.dart`, `communications_thread_view.dart`, `communications_compose_bar.dart`, `communications_new_conversation_dialog.dart` |
| State | Keep `CommunicationsWorkspaceController`; add methods for favorites/flags/attachments as needed |
| No API in widgets | Repository → API only |
| Modal-first | New DM, new group, manage members, attachment preview — dialogs/sheets; **do not** add routes for within-module flows |
| Realtime | Existing `RealtimeEventGroups.communications` subscription — refresh active thread and conversation list on new messages |
| Permissions | `AppPermissions.communicationsWrite` for compose; `AccessGate` + backend auth |
| Clinical boundary | Notifications deep-link only; Communications does not own clinical mutations |

---

## Suggested Implementation Phases

### Phase A — Inbox chat shell (MVP visible improvement)

- [ ] Replace inbox `AppListTable` with conversation list component
- [ ] Thread view with scrollable bubbles + sticky composer (text only)
- [ ] New DM dialog wired to `createConversation`
- [ ] Narrow-width single-pane navigation

### Phase B — Rich messaging

- [ ] @mention autocomplete + notification side effect
- [ ] Multipart attachments via `AppFileUploadPanel`
- [ ] Reply-to-message
- [ ] Read receipt indicators

### Phase C — Groups & organization

- [ ] New group dialog + member management
- [ ] Favorite / flag filters and actions
- [ ] Group header with participant list

### Phase D — Polish & tests

- [ ] Widget tests for composer, mention picker, thread selection
- [ ] Controller tests for attachment + group flows
- [ ] Manual QA on web + one mobile target

---

## Acceptance Criteria

- [ ] HR (or any `communications:write` user) can start a DM from Inbox without developer workarounds
- [ ] User can create a group, add members, and all members see group messages
- [ ] Composer supports `@` staff mention with dropdown; mentioned user receives notification
- [ ] User can attach at least one file/image per message; attachment visible in thread
- [ ] Thread shows time-tagged messages; user can see read state on sent messages
- [ ] Tapping a conversation/group on the left shows the full thread on the right (wide) or navigates to thread (narrow)
- [ ] Notifications remain distinct from Inbox and deep-link to source modules
- [ ] UI is usable and attractive on desktop and mobile widths
- [ ] No regression: Deliveries and Templates panels still work read-only

---

## Quality Gate

From `frontend/`:

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

From `backend/` when touching API or schema:

```sh
npm test -- --testPathPattern="conversation|communications-workspace|notification"
```

Apply Prisma migrations per backend workflow before merging schema changes.

---

## Key File References

```
frontend/lib/features/communications/
frontend/lib/shared/components/app_file_upload_panel.dart
backend/src/modules/communications-workspace/
backend/src/modules/conversation/
backend/prisma/schema.prisma  (conversation, message, message_attachment)
prompts/29-communications-module-prompt.md
```
