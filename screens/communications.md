# Action inventory — `/communications`

Primary surface: `CommunicationsWorkspacePage` (`frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart`).

Access helpers: `frontend/lib/features/communications/presentation/communications_access.dart`.
- Read (∩): `communicationsWorkspaceReadRequirement` (`communications:read` + `notifications-communications`).
- Write (∩): `communicationsWorkspaceWriteRequirement` (`communications:write` + module) — New message/group, compose, thread menu, mark read/unread, conversation archive, manage members; template create/update when exposed.
- Delete (∩): `communicationsWorkspaceDeleteRequirement` (`communications:delete` + module) — notification Archive (backend bulk archive); hard delete thread/template when exposed.
- Route entry (∪): `communicationsWorkspaceEntryRequirement` (`communications:read` | `communications:write`).
- Tab strip filters via `communicationsAllowedPanels` / per-tab `*AtomPermissions.tab` (`CommunicationsMessagesAtomPermissions`, `CommunicationsNotificationsAtomPermissions`, `CommunicationsDeliveriesAtomPermissions`, `CommunicationsTemplatesAtomPermissions`). Unauthorized write/delete controls do not render (no disabled stubs / routine “no access” banners).

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** (primary on non-inbox; secondary on inbox) | Reload workspace | **Removed** — mutations / realtime / scaffold **Try again** refresh |
| Detail **Mark read / Mark unread** (+ confirm) vs row next-action | Toggle read state | **Removed** from detail — next-action is the sole primary; confirm removed (non-destructive) |
| Delivery detail footer **Open linked record** vs body control | Navigate to linked path | **Removed** footer — body control only when path exists; disabled empty control omitted |
| Disabled **Open linked record** when no path | No-op navigation | **Removed** — control absent unless `targetPath` is an internal route |

---

## Communications workspace screen

### Tab strip

- **Messages / Notifications / Deliveries / Templates**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `panel`, updates URL `?panel=…`, applies panel via controller.
  - Condition: Visible when `communicationsAllowedPanels` includes the panel (∩ `communications:read` + module).

- **New message** (primary)
  - Location: Tab-strip primary on Messages when write-authorized.
  - Opens modal: Yes — direct-message recipient + optional subject.
  - Immediate result: Creates conversation; snackbar; selects thread.
  - Condition: `CommunicationsMessagesAtomPermissions.newMessage` (write ∩); dialog also no-ops when unauthorized; omitted on other tabs.

- **New group** (secondary)
  - Location: Tab-strip secondary on Messages when write-authorized.
  - Opens modal: Yes — group name, members, sensitive flag.
  - Immediate result: Creates group conversation.
  - Condition: `CommunicationsMessagesAtomPermissions.newGroup` (write ∩); dialog also no-ops when unauthorized; omitted on other tabs.

Notifications, Deliveries, and Templates have no tab-strip toolbar actions. Tab-strip **Refresh** was removed.

- **Try again** (page load / inline failure)
  - Location: `AsyncStateScaffold` or `AppFailureStateView`.
  - Opens modal: No.
  - Immediate result: Retries workspace load / refresh.
  - Condition: Load or mutation failure surface.

### Messages (inbox)

- **Search**, message filter toggle (All / Unread / …), **Load more**
  - Location: Conversation list chrome (`CommunicationsConversationList`).
  - Immediate result: Filters / paginates conversations.
  - Condition: `CommunicationsMessagesAtomPermissions.listChrome` / `search` / `filters` / `pagination` (read ∩); list returns empty chrome when denied.
- **Select conversation** — opens thread (split on wide; full-screen with back on narrow). Condition: `rowSelect` (read ∩).
- **Compose / Send / Attach / Reply** — thread compose bar when `CommunicationsMessagesAtomPermissions.compose` (write ∩); unauthorized bar does not mount.
- **Thread menu** (favorite, flag, mark read, archive/unarchive) — overflow when `threadMenu` (write ∩); menu actions re-check before mutation (stale grants).
- **Manage members** (+ add/remove) — group overflow item + dialog when `manageMembers` (write ∩); dialog no-ops when unauthorized.

### Notifications / Deliveries / Templates tables

- **Search**, **Clear**, **Filters** (advanced: queue + flags), **Settings** (columns), pagination
  - Location: `AppListTable` / `AppSearchBar` chrome.
- **Row select** — opens the matching detail dialog (read-focused).
- **Next action** (Notifications)
  - Location: `next_action` column.
  - Opens modal: No for mark read/unread; opens detail when read-only (**View**).
  - Immediate result: Marks read/unread directly; snackbar on success.
  - Write shows Mark read/unread (`communicationsWrite`); read-only shows View.
- **Next action** (Deliveries)
  - Location: `next_action` column (`CommunicationsDeliveriesAtomPermissions.nextAction` / `view` / `openLinked`).
  - Immediate result: Opens linked record when path exists; otherwise opens delivery detail (View / View error).
  - Condition: read ∩; absent when unauthorized (no disabled stub).
- Templates have no next-action column; row select opens template detail (preview).

### Detail dialogs

#### Notification detail (from row select / deep link)

- Shows title, message, status badges, metadata, delivery history; **Open linked record** in body when path present and `CommunicationsNotificationsAtomPermissions.openLinked` (read ∩).
- **Archive** (footer) — confirm dialog; then archive mutation + snackbar. Condition: `communicationsDelete` / `CommunicationsNotificationsAtomPermissions.archive` (backend bulk archive; matrix delete).
- Mark read/unread absent from detail (row next-action only).
- Unauthorized deep links do not open the dialog (`detail` ∩).

#### Delivery detail (from row select / next-action View)

- Shows status, metadata, error panel when present, **Open linked record** in body when path present (`openLinked` ∩ read; omitted when path absent).
- List chrome / row select / detail gated via `listChrome` / `rowSelect` / `detail` (same ∩ as read); unauthorized dialog entry no-ops.
- No footer write / delete actions (read-only operational logs).

#### Template detail (from row select / deep link)

- Shows metadata + preview panel. Read-only preview (`CommunicationsTemplatesAtomPermissions.detail` / `preview` / `view`).
- List chrome / search / row select gated via `listChrome` / `search` / `rowSelect` (same ∩ as read); unauthorized deep links do not open the dialog.
- Create / Edit / Delete footer actions are not in the inventory UI; when exposed they use write ∩ / delete ∩ and must not mount unauthorized.

### Empty / loading / error / validation

- Empty panels: no conversations / notifications / deliveries / templates copy via `AppWorkspaceStatePanel`.
- Thread empty: first-message hint (write) or no-messages body (read-only).
- Compose / new-conversation validation stays in mutation dialogs; success/error via snackbar or inline failure.

---

## Verification (Req 7)

- Widget/unit tests in `frontend/test/features/communications/presentation/`:
  - `communications_access_test.dart` — requirement ∩/∪, module strip, plan delete cap, Messages/Notifications/Deliveries/Templates atom map reuse.
  - `communications_messages_permissions_test.dart` — unauthorized absence / authorized presence for Messages chrome, compose, thread menu, manage members; route-entry ∪; subscription strip (missing + EXPIRED module); plan delete cap; ABAC facility note; mobile/desktop; light/dark; post-send sync.
  - `communications_notifications_permissions_test.dart` — Notifications ∩ denial / presence, Archive delete gate, Mark read write gate, route-entry ∪, subscription/plan strip, sync, viewports, light/dark.
  - `communications_deliveries_permissions_test.dart` — Deliveries ∩ denial / presence, read-only logs, detail Open linked, route-entry ∪, subscription/plan strip, sync, viewports, light/dark.
  - `communications_templates_permissions_test.dart` — Templates ∩ denial / presence, detail preview without create/update/delete chrome, route-entry ∪, subscription strip (missing + EXPIRED module), plan delete strip, ABAC facility note, sync, viewports, light/dark.
  - `communications_workspace_page_test.dart` — **Refresh** absent; **New message** / **New group** only on Messages with write; notification/delivery detail inventory (non-Messages tabs).
- **Refresh** absent from the tab strip on inbox and other panels (desktop/mobile).
- **New message** / **New group** only on Messages with write; absent when unauthorized (including on Templates).
- Notification detail shows **Archive** only when `communications:delete` (no Mark read/unread); **Open linked record** when path present and `openLinked` (read ∩).
- Row **Mark read** / **Mark unread** complete without a confirm dialog and show success snackbar.
- Delivery detail has no duplicate Open linked footer when no path.
- Template detail is preview-only; no Create / Edit / Delete when unauthorized or when not inventoried.
- Read-only detail hides Archive / Mark read / Mark unread.
