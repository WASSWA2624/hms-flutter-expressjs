# Standardize Communications Tables

## Objective

Refactor every `AppListTable` on the Communications workspace (`/communications`, `CommunicationsWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

**Scope boundary:** Restructure **table chrome, columns, and row interactions only** for the three `AppListTable` widgets on Notifications, Deliveries, and Templates panels. Do **not** rewrite the Inbox/Messages panel (`CommunicationsInboxPanel`), domain APIs, permissions, or unrelated screen chrome unless required for compilation.

## Compliance Checklist (from prompt.md — per table)

- [ ] Global search matches all columns (including hidden)
- [ ] Search chrome has only Filters (Advanced filters modal) and Settings (Table Settings modal)
- [ ] Session-persisted column visibility via `AppListTableColumnVisibilityController`
- [ ] ≤ 5 declared columns; automatic row number only
- [ ] One semantic field per column; two-line display only for primary/secondary of one field
- [ ] Status + explicit next-action columns when entity has workflow
- [ ] Row tap opens reused detail dialog with follow-up actions
- [ ] Adaptive layout + `mobileItemBuilder` parity
- [ ] Real-time refresh via Riverpod providers

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification. Run tests and formatting after implementation. Treat `prompt.md` as the normative table contract.

**Screen binding**

| Field | Value |
|-------|-------|
| Route | `/communications` |
| Page widget | `CommunicationsWorkspacePage` |
| Primary page file | `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart` |
| Controller | `communicationsWorkspaceControllerProvider` → `CommunicationsWorkspaceController` |
| Deep-link pattern | `?panel=<value>` (`inbox`, `notifications`, `deliveries`, `templates`) |

**Panels with `AppListTable` (in scope):**

| Panel enum | Tab label (l10n) | Table widget |
|------------|------------------|--------------|
| `CommunicationsPanel.notifications` | `communicationsNotificationsPanelLabel` → "Notifications" | `_NotificationsTable` |
| `CommunicationsPanel.deliveries` | `communicationsDeliveriesPanelLabel` → "Deliveries" | `_DeliveriesTable` |
| `CommunicationsPanel.templates` | `communicationsTemplatesPanelLabel` → "Templates" | `_TemplatesTable` |

**Out of scope:** `CommunicationsPanel.inbox` uses `CommunicationsInboxPanel` / `CommunicationsConversationList` (not `AppListTable`).

## Current State (from audit)

### Shared search chrome — `_tableSearch<T>()` (lines ~1141–1184)

| Aspect | Current | Gap vs `prompt.md` |
|--------|---------|-------------------|
| Matcher | `matcher: (_, _) => true` — no column matching | §1: must match all declared + hidden column fields |
| Filters button | `communicationsAdvancedFiltersLabel` → "Filters" | OK for button label |
| Filters modal title | `communicationsAdvancedFiltersTitle` → **"Filters"** | §1: modal title must be **"Advanced filters"** |
| Settings button | `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` | OK |
| Settings modal title | **not set** (`columnVisibilityTitle` missing on all three tables) | §1: set `columnVisibilityTitle` to **"Table Settings"** |
| Server search | `onSubmitted` → `controller.applySearch(value)` | Keep server search; add client `matcher` / `searchMatcher` that mirrors the same fields for local filtering |

### Row interaction — inline detail panel (major gap)

| Aspect | Current | Gap vs `prompt.md` |
|--------|---------|-------------------|
| Layout | `AppWorkspace(detail: _CommunicationsDetailPanel(...))` side panel for non-inbox panels | §5: row tap must open a **modal dialog**, not inline side panel |
| `onRowSelected` | `controller.selectNotification` / `selectDelivery` / `selectTemplate` — updates `selected*` state only | Must select **then** open modal with detail content |
| Detail UI | `_CommunicationsDetailPanel` with `_notificationDetail`, `_deliveryDetail`, `_templateDetail` private methods | Extract/reuse in dialog; remove `AppWorkspace.detail` for table panels |

### Table 1 — `_NotificationsTable`

| Field | Value |
|-------|-------|
| File | `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart` |
| Entity | `NotificationItem` |
| Provider data | `state.notifications` via `communicationsWorkspaceControllerProvider` |
| Storage keys | `columnVisibilityStorageKey: 'communications_notifications'`, `columnWidthStorageKey: 'communications_cw_notifications'` |
| Column visibility controller | `_notificationColumns` (`AppListTableColumnVisibilityController<NotificationItem>`) |

**Current columns (5 — at budget limit, wrong layout for workflow):**

| # | id | Label key | Field(s) | Cell pattern |
|---|-----|-----------|----------|--------------|
| 1 | `alert` | `communicationsAlertColumnLabel` | `title` + `message` | `AppListItemText` (valid two-line single field) |
| 2 | `type` | `communicationsTypeColumnLabel` | `notificationType` | `Text(_apiLabel(...))` |
| 3 | `priority` | `communicationsPriorityColumnLabel` | `priority` | `AppWorkspaceStatusBadge` |
| 4 | `state` | `communicationsStateColumnLabel` | read/unread (`readAt`) | `AppWorkspaceStatusBadge` via `_readStatus` |
| 5 | `time` | `communicationsTimeColumnLabel` | `createdAt` | `Text(_dateTimeLabel(...))` |

**Workflow:** read/unread lifecycle with write actions: `markSelectedNotificationRead`, `markSelectedNotificationUnread`, `archiveSelectedNotification` (gated by `canWrite` / `AppPermissions.communicationsWrite`).

**Gaps:**
- No dedicated **next-action** column (§4)
- `priority` is a status badge in a data slot; should move to `columnChoices` (hidden by default)
- `state` (read/unread) should be column 4 (status); column 5 should be explicit next action
- `onRowSelected` opens inline panel, not modal
- `mobileItemBuilder` shows priority + read badges but no next-action control
- Search matcher does not cover: `title`, `message`, `notificationType`, `priority`, read label, `createdAt`, `contextType`, `contextPublicId`

### Table 2 — `_DeliveriesTable`

| Field | Value |
|-------|-------|
| Entity | `NotificationDelivery` |
| Storage keys | `communications_deliveries`, `communications_cw_deliveries` |
| Controller | `_deliveryColumns` |

**Current columns (5):**

| # | id | Label key | Field(s) | Cell pattern |
|---|-----|-----------|----------|--------------|
| 1 | `notification` | `communicationsNotificationColumnLabel` | `notificationTitle` + `errorMessage` | `AppListItemText` (valid) |
| 2 | `channel` | `communicationsChannelColumnLabel` | `channel` | `Text(_apiLabel(...))` |
| 3 | `recipient` | `communicationsRecipientColumnLabel` | `recipient.displayName` / `recipientTarget` | `Text(_deliveryRecipient(...))` |
| 4 | `status` | `communicationsStatusColumnLabel` | `status` | `AppWorkspaceStatusBadge` via `_deliveryStatus` |
| 5 | `attempts` | `communicationsAttemptsColumnLabel` | `attemptCount` | `Text(...)` |

**Workflow:** delivery status (`PENDING`, `RETRYING`, `FAILED`, `DELIVERED`, etc.); `retryable` field exists on entity but **no retry API** in `CommunicationsRepository`.

**Gaps:**
- No **next-action** column (§4) — status is correctly positioned at col 4 but col 5 is data (`attempts`), not action
- `attempts`, `sentAt`, `deliveredAt`, `failedAt`, `providerName` should move to `columnChoices` or detail-only
- Inline detail panel instead of modal
- Mobile lacks next-action
- Search matcher missing: `notificationTitle`, `errorMessage`, `channel`, recipient fields, `status`, `attemptCount`, `providerName`

### Table 3 — `_TemplatesTable`

| Field | Value |
|-------|-------|
| Entity | `CommunicationTemplate` |
| Storage keys | `communications_templates`, `communications_cw_templates` |
| Controller | `_templateColumns` |

**Current columns (4):**

| # | id | Label key | Field(s) | Cell pattern |
|---|-----|-----------|----------|--------------|
| 1 | `template` | `communicationsTemplateColumnLabel` | `name` + `description` | `AppListItemText` |
| 2 | `channel` | `communicationsChannelColumnLabel` | `channel` | `Text(_apiLabel(...))` |
| 3 | `state` | `communicationsStateColumnLabel` | `isActive` | `AppWorkspaceStatusBadge` via `_templateStatus` |
| 4 | `variables` | `communicationsVariablesColumnLabel` | `variableCount` | `Text(...)` |

**Workflow:** none — `isActive` is a static attribute, not a multi-step workflow. Per `prompt.md` §3: up to five data columns; no mandatory status/next-action pair.

**Gaps:**
- Inline detail panel instead of modal
- Missing `columnVisibilityTitle`
- Search matcher missing: `name`, `description`, `channel`, active label, `variableCount`, `subject`
- Optional: move `subject` into `columnChoices` as hidden column

### Realtime (§8) — already wired

`CommunicationsWorkspaceController.build()` calls `listenForRealtimeRefresh` with `RealtimeEventGroups.communications`. Tables read from controller state — **preserve this**; do not mutate table widgets directly.

### Database migrations

No database migrations required — schema unchanged.

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableColumn`, `AppListTableSearch`, `AppListTableColumnVisibilityController`, default `displayMode: AppListTableDisplayMode.adaptive`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist`: Filters/Settings chrome, `columnVisibilityTitle`, real search `matcher`, status + next-action columns, `columnChoices`
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn()` + `WorkflowActionButton` pattern (Communications uses simpler `AppButton`/`TextButton` actions — no encounter workflow)
- `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart` — `_openClaimsDetailDialog`: select item → `showAppDialog` + `AppDialog` with extracted detail content
- `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart` — `_openDischargeDetailDialog`, `_searchMatcher` static helper
- `prompt.md`

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey | columnWidthStorageKey |
|--------------|-------------|--------|-----------------------------------|----------------------------|----------------------|
| `_NotificationsTable` | `notifications` | `NotificationItem` | alert, type, time, status, next_action | `communications_notifications` | `communications_cw_notifications` |
| `_DeliveriesTable` | `deliveries` | `NotificationDelivery` | notification, channel, recipient, status, next_action | `communications_deliveries` | `communications_cw_deliveries` |
| `_TemplatesTable` | `templates` | `CommunicationTemplate` | template, channel, state, variables | `communications_templates` | `communications_cw_templates` |

### Column plan — `_NotificationsTable` (workflow entity)

| Position | Column id | Label (l10n) | Source field | Notes |
|----------|-----------|----------------|--------------|-------|
| 1 | `alert` | `communicationsAlertColumnLabel` | `title` / `message` | Keep `AppListItemText`; `alwaysVisible: true` |
| 2 | `type` | `communicationsTypeColumnLabel` | `notificationType` | `_apiLabel` |
| 3 | `time` | `communicationsTimeColumnLabel` | `createdAt` | `_dateTimeLabel` |
| 4 | `status` | `communicationsStateColumnLabel` | read/unread | `AppWorkspaceStatusBadge` via `_readStatus` — **second from right** |
| 5 | `next_action` | `communicationsNextActionColumnLabel` *(add)* | derived from `isRead` + `canWrite` | Explicit verb button — see below |

**`columnChoices` (hidden by default):**

| id | Label | Field |
|----|-------|-------|
| `priority` | `communicationsPriorityColumnLabel` | `priority` → `_priorityStatus` badge |
| `delivery_status` | `communicationsDeliveryStatusColumnLabel` *(add if needed)* | `effectiveDeliveryStatus` → `_deliveryStatus` badge |
| `context` | `communicationsContextLabel` | `contextType` + `contextPublicId` joined |

**Next-action labels (notifications, explicit verbs — never generic):**

| Condition | Label (l10n key) | Handler |
|-----------|------------------|---------|
| `canWrite && !item.isRead` | `communicationsMarkReadAction` | `_confirmAction` → `controller.markSelectedNotificationRead` (same as detail) |
| `canWrite && item.isRead` | `communicationsMarkUnreadAction` | `_confirmAction` → `controller.markSelectedNotificationUnread` |
| `canWrite` (secondary in detail) | `communicationsArchiveAction` | detail dialog only |
| Read-only | `communicationsViewNotificationAction` *(add)* | open detail dialog |

Use `AppButton` compact/secondary or `TextButton` in the cell — **not** `WorkflowActionButton` (no encounter workflow).

### Column plan — `_DeliveriesTable` (workflow entity)

| Position | Column id | Label | Source field | Notes |
|----------|-----------|-------|--------------|-------|
| 1 | `notification` | `communicationsNotificationColumnLabel` | `notificationTitle` / `errorMessage` | Keep `AppListItemText` |
| 2 | `channel` | `communicationsChannelColumnLabel` | `channel` | |
| 3 | `recipient` | `communicationsRecipientColumnLabel` | recipient | `_deliveryRecipient` |
| 4 | `status` | `communicationsStatusColumnLabel` | `status` | `_deliveryStatus` badge |
| 5 | `next_action` | `communicationsNextActionColumnLabel` | derived from `status` + `targetPath` | See below |

**`columnChoices`:** `attempts`, `sent_at`, `delivered_at`, `failed_at`, `provider` (map to existing label keys where possible: `communicationsAttemptsColumnLabel`, `communicationsSentAtLabel`, etc.)

**Next-action labels (deliveries):**

| Condition | Label | Handler |
|-----------|-------|---------|
| `targetPath` resolves via `_internalPath` | `communicationsOpenLinkedRecordAction` | `context.go(path)` |
| `status` is `FAILED` / `BOUNCED` / `ERROR` | `communicationsViewDeliveryErrorAction` *(add)* | open delivery detail dialog (scrolls to error panel) |
| Default | `communicationsViewDeliveryAction` *(add)* | open delivery detail dialog |

No retry mutation exists in `CommunicationsRepository` — do **not** invent a retry API.

### Column plan — `_TemplatesTable` (no workflow)

| Position | Column id | Label | Source field |
|----------|-----------|-------|--------------|
| 1 | `template` | `communicationsTemplateColumnLabel` | `name` / `description` |
| 2 | `channel` | `communicationsChannelColumnLabel` | `channel` |
| 3 | `state` | `communicationsStateColumnLabel` | `isActive` → `_templateStatus` |
| 4 | `variables` | `communicationsVariablesColumnLabel` | `variableCount` |

**`columnChoices`:** `subject` (`communicationsSubjectLabel` → `template.subject`)

No next-action column required. Row tap opens template detail modal.

### Search chrome (per table)

Apply to `_tableSearch<T>()` and each `AppListTable`:

```dart
// Filters
advancedFilterButtonLabel: l10n.commonFiltersActionLabel,  // add key → "Filters"
advancedFilterTitle: l10n.commonAdvancedFiltersTitle,        // add key → "Advanced filters"

// Settings (on each AppListTable)
columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
columnVisibilityTitle: l10n.commonTableSettingsTitle,       // add key → "Table Settings"
```

Add per-entity matchers (top-level functions in the same file or a new `communications_table_support.dart`):

- `_notificationSearchMatcher(NotificationItem item, String query)`
- `_deliverySearchMatcher(NotificationDelivery item, String query)`
- `_templateSearchMatcher(CommunicationTemplate item, String query)`

Each matcher must lowercase-compare `query` against **all** default + `columnChoices` field text values (use existing helpers: `_apiLabel`, `_readStateLabel`, `_dateTimeLabel`, `_deliveryRecipient`, etc.). Pass the correct matcher into `_tableSearch` based on `state.query.panel`, or set `searchMatcher` on `AppListTable` when using `searchListenable`.

Keep `onSubmitted` → `controller.applySearch(value)` for server-side search; client matcher handles in-page filtering per `AppListTable` contract.

### Row interaction

**Remove** inline detail for table panels:

```dart
// BEFORE (communications_workspace_page.dart ~line 313)
detail: state.query.panel == CommunicationsPanel.inbox
    ? null
    : _CommunicationsDetailPanel(state: state, canWrite: canWrite),

// AFTER
detail: null,  // all table-panel detail moves to modals
```

**Add** dialog openers (pattern from `_openClaimsDetailDialog`):

```dart
Future<void> _openNotificationDetailDialog(
  BuildContext context,
  WidgetRef ref,
  CommunicationsWorkspaceState state,
  NotificationItem item,
) async { ... }

Future<void> _openDeliveryDetailDialog(...) async { ... }
Future<void> _openTemplateDetailDialog(...) async { ... }
```

Each function:
1. Call existing `controller.selectNotification/selectDelivery/selectTemplate(item)`
2. `showAppDialog` with `AppDialog(scrollable: true, maxWidth: 960, ...)`
3. Reuse extracted content from current `_notificationDetail` / `_deliveryDetail` / `_templateDetail`
4. Dialog actions mirror detail panel actions (Mark read/unread, Archive for notifications; Open linked record when applicable)

**Wire `onRowSelected`:**

```dart
onRowSelected: (NotificationItem item) =>
    unawaited(_openNotificationDetailDialog(context, ref, state, item)),
```

Next-action column buttons must invoke the **same** handlers as dialog primary actions (not a different code path).

### Mobile parity

Update each `mobileItemBuilder` to include:
- Same priority fields as desktop cols 1–3
- Status badge (col 4 where workflow applies)
- Next-action control (col 5 where workflow applies) — trailing `AppButton` or inline action chip

Set explicitly on each table (default is already adaptive):

```dart
displayMode: AppListTableDisplayMode.adaptive,
```

## Implementation Steps

### Step 0 — Extract shared detail widgets

1. Create `frontend/lib/features/communications/presentation/widgets/communications_record_detail_widgets.dart` (or `communications_detail_dialogs.dart`).
2. Move `_notificationDetail`, `_deliveryDetail`, `_templateDetail`, `_LinkedRecordAction`, `_DeliveryHistory`, and `_confirmAction` helpers into this file as public widgets/functions:
   - `CommunicationsNotificationDetailContent`
   - `CommunicationsDeliveryDetailContent`
   - `CommunicationsTemplateDetailContent`
   - `showCommunicationsNotificationDetailDialog(...)`
   - `showCommunicationsDeliveryDetailDialog(...)`
   - `showCommunicationsTemplateDetailDialog(...)`
3. Keep formatting helpers (`_apiLabel`, `_deliveryStatus`, etc.) accessible — either export from the new file or a `communications_workspace_formatters.dart` to avoid duplication.

### Step 1 — `_NotificationsTable`

File: `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart`

1. Reorder columns to: `alert`, `type`, `time`, `status` (rename id from `state`), `next_action`.
2. Move `priority` (+ optional `delivery_status`, `context`) to `columnChoices`.
3. Add `columnVisibilityTitle: l10n.commonTableSettingsTitle`.
4. Implement `_notificationNextActionCell` with explicit verb labels.
5. Wire `onRowSelected` → `_openNotificationDetailDialog`.
6. Update `mobileItemBuilder` with status + next-action.
7. Pass `_notificationSearchMatcher` into search config.

### Step 2 — `_DeliveriesTable`

Same file.

1. Replace `attempts` default column with `next_action`; move `attempts` + timestamps + provider to `columnChoices`.
2. Add `columnVisibilityTitle`.
3. Implement `_deliveryNextActionCell` per status/`targetPath` rules above.
4. Wire `onRowSelected` → `_openDeliveryDetailDialog`.
5. Update `mobileItemBuilder`.
6. Pass `_deliverySearchMatcher`.

### Step 3 — `_TemplatesTable`

Same file.

1. Keep 4 default columns; add `subject` to `columnChoices`.
2. Add `columnVisibilityTitle`.
3. Wire `onRowSelected` → `_openTemplateDetailDialog`.
4. Pass `_templateSearchMatcher`.

### Step 4 — Search chrome standardization

In `_tableSearch<T>()`:
1. Replace `communicationsAdvancedFiltersTitle` with `commonAdvancedFiltersTitle` ("Advanced filters").
2. Replace `communicationsAdvancedFiltersLabel` with `commonFiltersActionLabel` ("Filters") if adding shared keys; otherwise update `communicationsAdvancedFiltersTitle` value in arb to "Advanced filters" and keep button label "Filters".
3. Fix `matcher` stub — panel-specific matcher or generic dispatch on `state.query.panel`.

### Step 5 — Remove inline detail panel

1. Set `AppWorkspace(detail: null)` always (inbox uses its own split layout inside body).
2. Delete `_CommunicationsDetailPanel` class once content is extracted.
3. Preserve deep-link selection: when `notificationId` / `templateId` is in query, auto-open the matching detail dialog on first frame (post-frame callback reading `state.selectedNotification` etc.).

### Step 6 — l10n

Add to `frontend/lib/l10n/app_en.arb` only:

```json
"commonFiltersActionLabel": "Filters",
"commonAdvancedFiltersTitle": "Advanced filters",
"commonTableSettingsTitle": "Table Settings",
"communicationsNextActionColumnLabel": "Action",
"communicationsViewNotificationAction": "View notification",
"communicationsViewDeliveryAction": "View delivery",
"communicationsViewDeliveryErrorAction": "View error",
"communicationsDeliveryStatusColumnLabel": "Delivery status"
```

Reuse existing keys wherever possible (`communicationsMarkReadAction`, `communicationsOpenLinkedRecordAction`, etc.).

Run `flutter gen-l10n` from `frontend/`.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | All three tables |
| `AppListTableColumnVisibilityController` | same | `_notificationColumns`, `_deliveryColumns`, `_templateColumns` |
| `AppListTableColumnVisibilityMemory` | `app_list_table.dart` | Session persistence via storage keys |
| `AppWorkspaceStatusBadge` / `AppWorkspaceStatus` | `components.dart` | Status columns |
| `AppListItemText` / `AppListItemRow` | `components.dart` | Two-line cells + mobile rows |
| `AppDialog` / `showAppDialog` | `components.dart` | Detail modals |
| `AppConfirmActionDialog` | `components.dart` | Mark read/unread/archive confirmations |
| `AppButton` | `components.dart` | Next-action column + dialog actions |
| `appListTableCompareText` / `appListTableCompareDateTime` / `appListTableCompareNumber` | `app_list_table.dart` | Sort comparators |

Do **not** create new table/search/filter primitives.

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart` |
| Create | `frontend/lib/features/communications/presentation/widgets/communications_detail_dialogs.dart` (or similar) |
| Modify | `frontend/lib/l10n/app_en.arb` |
| Modify | `frontend/test/features/communications/presentation/communications_workspace_page_test.dart` |
| Delete | `_CommunicationsDetailPanel` from workspace page after extraction |

## Testing Requirements

- [ ] Each table: search, Filters, Settings only in chrome (no extra trailing actions in `AppListTableSearch`)
- [ ] Advanced filters modal title reads **"Advanced filters"**
- [ ] Table Settings modal title reads **"Table Settings"**
- [ ] Column visibility persists for session per table storage key
- [ ] ≤5 default columns per table; row number automatic
- [ ] Notifications + Deliveries: explicit status + next-action labels (no "Action" / "Next step" generic text in cells)
- [ ] Row tap opens detail **dialog** (find `AppDialog` or dialog title text), not `AppWorkspaceDetailPanel` in split layout
- [ ] Mobile list (`AppListItemRow`) shows status + next-action for workflow tables
- [ ] Realtime refresh still updates rows after mutations/events (controller tests unchanged)
- [ ] Permissions still gate write actions (`canWrite` false → no Mark read / Mark unread buttons)
- [ ] Tab switching + deep links (`?panel=notifications`) still work

Update `communications_workspace_page_test.dart`:
- Add test: tap notification row → expect dialog with `communicationsNotificationDetailTitle`
- Add test: Deliveries tab shows next-action or status badge in table
- Adjust any test that expected side `AppWorkspaceDetailPanel` for table panels

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/communications/
```

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for every `AppListTable` on Communications (Notifications, Deliveries, Templates)
- [ ] Domain logic preserved (server search, filters, pagination, permissions, realtime, deep links)
- [ ] Inline side detail panel removed for table panels; modal detail with follow-up actions
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/communications/` passes
