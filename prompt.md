# Communications Workspace — Messaging UX, Shared Patterns & Extensible Architecture

## Objective

Elevate the **staff messaging** experience in Communications to match the quality of other HMS workspaces—while **maximizing reusability, uniformity, and flexibility** so new panels, filters, and messaging flows can be added without duplicating UI or controller logic.

**Entry point:** `/communications` → **Messages** panel (UI label; server key remains `panel=inbox`).

**Screenshots (current UI):**
- List shows recipient **email** instead of staff name; thread pane empty (*“No messages are available for this thread.”*)
- **New group**: name entered, **Create group** disabled with no explanation (no members added).
- Panel tabs cause visible full-workspace refresh on switch.
- Message filters use bordered `FilterChip`; panel tabs use `AppButton` — **inconsistent**.
- Notifications / Deliveries / Templates panels otherwise work (failure detail, template preview).

---

## Design Principles

### 1. Reusability

Prefer **one shared implementation** consumed by Communications (and future modules) over feature-local copies.

| Concern | Reuse / extract | Do **not** duplicate |
|---------|-----------------|----------------------|
| Panel & filter toggles | New shared `AppWorkspaceOptionToggle<T>` | `_PanelSelector` + `_FilterChips` each inventing toggle UI |
| Master–detail layout | `AppWorkspaceSplitContent` | Custom `Row` + fixed heights in inbox panel |
| Mutation dialogs | `showAppWorkspaceMutationDialog` | Raw `showAppDialog` for new message / group |
| Person labels | Shared `resolvePersonDisplayName` | Ad-hoc title logic in list, thread, dialogs |
| Compose area | Configurable `CommunicationsComposeBar` (or future `AppMessageComposeBar`) | Inline TextField + buttons in thread view |
| Empty / read-only states | `AppMessagePanel`, `AppWorkspaceStatePanel` | Custom centered text per screen |
| Staff picker | `AppSelectField.searchable` (already used) | One-off dropdown implementations |
| Time formatting | `communications_formatters.dart` | Inline `DateFormat` calls |

Extract to `frontend/lib/shared/` when **two or more** workspaces need the same control; keep communications-specific wiring in `features/communications/`.

### 2. Uniformity

Match established HMS workspace conventions so Communications feels native beside HR, Lab, Radiology, etc.

| Pattern | Reference | Apply here |
|---------|-----------|------------|
| Granular refresh flags | `HrWorkspaceController` — `isRefreshingStaff`, `isRefreshingDetail` | `isRefreshingConversations`, `isRefreshingThread`, `isRefreshingNotifications`, … |
| Panel body shell | `AppWorkspaceDetailPanel` + description | All four Communications panels |
| Toolbar | `appWorkspaceToolbarWithLabels` | Already used — keep |
| Tables | `AppListTable` + column visibility | Notifications, Deliveries, Templates — unchanged |
| Buttons | `AppButton` variants (`primary` / `secondary` / `tertiary` / `iconOnly`) | Filters, actions, compose |
| Dialogs | `AppDialog`, `showAppWorkspaceMutationDialog` | New conversation flows |
| Permissions | `AppPermissions.communicationsRead` / `communicationsWrite` | Compose + mutations |
| l10n | `app_en.arb` keys with `@` descriptions | All user-facing copy |
| Spacing / radius | `theme.spacing`, `theme.radius` | No magic numbers |

**Rule:** If HR or another workspace already solves a layout/interaction problem, adopt that solution—do not introduce a third pattern.

### 3. Flexibility

Design for **extension without refactors**:

- **Stable API contract:** Keep `CommunicationsPanel.inbox` server value `inbox`; change **UI label only** to *Messages*. New filters use `query.filter` string keys the backend can ignore until supported.
- **Filter registry:** Define filters as a **data-driven list** (`id`, `label`, `serverFilter`, `clientPredicate`, `icon`) so adding *Sent* / *Read* / future queues is a registry entry—not a new widget.
- **Dual filter execution:** Try server filter first; fall back to `clientPredicate` when API lacks support (non-destructive, with optional info banner).
- **Compose bar props:** `canWrite`, `readOnlyMessage`, `autofocus`, `maxAttachments`, `onSent` — reusable beyond Communications.
- **Panel cache:** Keyed by `(panel, filterSignature)`; invalidation rules explicit (search/filter/page vs panel switch).
- **Route sync:** Query object serializes to/from URI; deep links for `conversationId`, `panel`, `filter` work without controller rewrites.

---

## Problem Statement

| Area | Current behavior | Issue |
|------|------------------|-------|
| Naming | Tab labeled **Inbox** | Ambiguous; UI should say **Messages** with clear sub-filters |
| Tab switching | `applyPanel` → `_applyQuery` → full `getWorkspace` + clears selections | Full flash/reload; violates HR-style granular refresh |
| Thread selection | `selectConversation` local-only | Never calls `getConversation`; list rows lack full `messages[]` |
| Compose | Hidden when `!canWrite`; missing when thread empty | Users cannot send or attach |
| Titles | Email fallback when profile empty | Should use shared display-name resolver |
| Filters | `FilterChip` | Inconsistent with `AppButton` panel tabs |
| New group | Create disabled silently | Needs `AppTextField.helperText` validation copy |
| Sent / Read | Not available | Need registry entry + server or client predicate |

**Critical gap:** `CommunicationsRepository.getConversation` exists but `selectConversation` never invokes it.

---

## Current Implementation

| Area | Location |
|------|----------|
| Workspace page | `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart` |
| Inbox layout | `frontend/lib/features/communications/presentation/widgets/communications_inbox_panel.dart` |
| Conversation list | `frontend/lib/features/communications/presentation/widgets/communications_conversation_list.dart` |
| Thread / compose | `communications_thread_view.dart`, `communications_compose_bar.dart` |
| New conversation dialogs | `communications_new_conversation_dialog.dart` |
| Controller | `communications_workspace_controller.dart` |
| Repository / DTOs | `communications_repository_impl.dart`, `communications_dtos.dart` |
| Backend serializers | `backend/.../communications-workspace.serializers.js` — `personName`, `conversationTitle` |
| **Shared references** | `app_workspace.dart` (`AppWorkspaceSplitContent`, `AppWorkspaceFilterBar`), `app_workspace_mutation_dialog.dart`, `hr_workspace_controller.dart` (granular refresh), `app_workspace_board_toggle.dart` |

---

## Shared Components to Introduce or Reuse

### A. `AppWorkspaceOptionToggle<T>` *(new, shared)*

Generic single-select control for **panel tabs** and **message filters**.

```dart
// frontend/lib/shared/layout/app_workspace_option_toggle.dart
AppWorkspaceOptionToggle<CommunicationsPanel>(
  value: selectedPanel,
  options: panelOptions, // label, icon, value
  onChanged: controller.applyPanel,
);

AppWorkspaceOptionToggle<String>(
  value: activeFilterId,
  options: messageFilterRegistry,
  onChanged: controller.applyMessageFilter,
);
```

- Implementation: `Wrap` of `AppButton` (`primary` when selected, `secondary` otherwise)—same visual language as today's `_PanelSelector`.
- Replace both `_PanelSelector` and `_FilterChips` in Communications; export from `shared/layout/layout.dart`.
- Optional later: compact mode via `AppWorkspaceBoardToggle` (`SegmentedButton`) for ≤4 options on narrow screens.

### B. `AppWorkspaceSplitContent` *(existing)*

Refactor `CommunicationsInboxPanel` to use shared split layout instead of manual `Row` / fixed `640` height:

- **Primary:** conversation list + filters + search.
- **Detail:** `CommunicationsThreadView` or empty `AppWorkspaceStatePanel`.
- **Breakpoint:** `AppBreakpoints.lg` (already used); mobile shows thread full-screen with back affordance.

### C. `resolvePersonDisplayName` *(new, shared)*

```dart
// frontend/lib/core/utils/person_display_name.dart (or shared/formatters/)
String resolvePersonDisplayName({
  String? firstName,
  String? lastName,
  String? displayName,
  String? username,
  String? email,
  String? fallbackId,
});
```

- Use in: conversation list title, thread header, mention overlay, member chips, dialogs.
- Mirror fallback chain in backend `personName` so client and server stay aligned.
- Avatar initials: shared helper `personInitials(displayName)`.

### D. `showAppWorkspaceMutationDialog` *(existing)*

Migrate `_NewDirectMessageDialog` and `_NewGroupDialog` to workspace mutation dialog shell:

- Consistent actions footer, loading state, `initialMaximized` when needed.
- Shared validation: required fields via `AppTextField.isRequired` + `helperText` / `errorText`.

### E. Granular refresh state *(pattern from HR)*

Extend `CommunicationsWorkspaceState`:

| Flag | When true |
|------|-----------|
| `isRefreshingConversations` | List/filter/search fetch |
| `isRefreshingThread` | `getConversation` in flight |
| `isRefreshingNotifications` | Notifications panel fetch |
| `isRefreshingDeliveries` | Deliveries panel fetch |
| `isRefreshingTemplates` | Templates panel fetch |

`AsyncStateScaffold` loads **once** on first entry; subsequent updates use inline indicators only.

### F. Message filter registry *(new, feature-local config)*

```dart
final class CommunicationsMessageFilter {
  const CommunicationsMessageFilter({
    required this.id,
    required this.labelKey,
    this.serverFilter,
    this.unreadOnly = false,
    this.clientPredicate,
  });
  // ...
}

const List<CommunicationsMessageFilter> kCommunicationsMessageFilters = [ ... ];
```

Adding a filter = one registry constant + l10n key + (optional) backend `buildConversationWhere` branch.

---

## Target UX

### Messages panel (UI) / inbox (API)

**Top-level Communications tabs** (unchanged structure, uniform toggle):

| Tab | Purpose |
|-----|---------|
| **Messages** | Staff DM + groups |
| **Notifications** | Workflow alerts |
| **Deliveries** | Delivery log |
| **Templates** | Message templates |

**Message sub-filters** (registry-driven, same toggle component):

| Filter | Server | Client fallback |
|--------|--------|-----------------|
| All | — | pass-through |
| Unread | `unreadOnly` / `UNREAD` | `conversation.unread` |
| Sent | `SENT` *(new)* | `lastMessage.senderUserId == currentUserId` |
| Read | `READ` *(new)* | `!conversation.unread` |
| Favorites | `FAVORITES` | `isFavorite` |
| Flagged | `FLAGGED` | `isFlagged` |
| Archived | `ARCHIVED` | `archived` |

### Thread & compose (uniform states)

| State | Shared component |
|-------|------------------|
| Loading thread | Inline progress in detail pane (`isRefreshingThread`) |
| Empty + writable | `AppMessagePanel` + visible compose + first-message hint |
| Empty + read-only | `AppMessagePanel` + read-only banner (not hidden compose row) |
| Populated | `CommunicationsThreadView` + compose |

**Selection flow:** optimistic row highlight → set `conversationId` in query/URL → `getConversation` → render messages → auto-mark read.

### New conversation dialogs (uniform mutation pattern)

- **New message:** recipient `AppSelectField.searchable`; on success → select thread, load messages, `autofocus` compose, snackbar.
- **New group:** name + ≥1 member; `helperText` when name without members; sensitive toggle unchanged; attachments **only** in compose bar post-create.

---

## Implementation Requirements

### 1. Shared layout & toggles

- Create `AppWorkspaceOptionToggle<T>` in `shared/layout/`.
- Replace `_PanelSelector` and `_FilterChips` with it.
- Refactor `CommunicationsInboxPanel` onto `AppWorkspaceSplitContent`.

### 2. Controller architecture

- Add granular `isRefreshing*` flags; remove blanket full-scaffold reload on panel switch.
- Per-panel cache: retain last fetched `AppPage` per `CommunicationsPanel` when switching tabs.
- `selectConversation` → async `loadConversation(id)` via `getConversation`.
- `applyPanel`: swap active panel from cache; fetch only if stale.
- `applyMessageFilter`: read from registry; map to query; server + client predicate as per §Filter registry.
- Sync query ↔ route on every `_applyQuery` (mirror patterns from other workspaces using `context.go`).

### 3. Display names

- Add `resolvePersonDisplayName` + `personInitials` in shared/core.
- Use in `communications_formatters.dart` (`communicationsConversationAvatarLabel`, etc.).
- Backend: extend `personName` with `display_name` / `username`; ensure list + detail queries `include` profile.

### 4. Compose bar flexibility

Extend `CommunicationsComposeBar`:

| Prop | Purpose |
|------|---------|
| `canWrite` | Enable input + send |
| `readOnlyBanner` | Shown when `!canWrite` instead of `SizedBox.shrink()` |
| `autofocus` | After new conversation |
| `maxAttachments` | Default 5; configurable |
| `onSent` | Optional callback for snackbar / scroll |

### 5. Dialogs

- Refactor new message / group to `showAppWorkspaceMutationDialog`.
- Group validation: `AppTextField.helperText: l10n.communicationsGroupMembersRequiredHelper` when name filled, members empty.

### 6. l10n (`app_en.arb`)

| Key | Copy |
|-----|------|
| `communicationsMessagesPanelLabel` | Messages |
| `communicationsSentFilterLabel` | Sent |
| `communicationsReadFilterLabel` | Read |
| `communicationsComposeReadOnlyBody` | You can view this thread but cannot send messages. |
| `communicationsFirstMessageHint` | Send the first message to start this conversation. |
| `communicationsGroupMembersRequiredHelper` | Add at least one member to create the group. |
| `communicationsConversationStartedMessage` | Conversation started — send your first message. |
| `communicationsClientFilterNotice` | Some filters are applied locally until server support is available. |

Retarget `communicationsInboxPanelLabel` → **Messages** (same string value).

### 7. Backend (optional parallel)

- `personName` enrichment; `SENT` / `READ` in `buildConversationWhere`.
- Always return `last_message.sender` on conversation list for client fallback.

### 8. Tests

| Test | Asserts |
|------|---------|
| `AppWorkspaceOptionToggle` widget | Selected option uses `AppButtonVariant.primary` |
| Controller | `selectConversation` → `getConversation`; granular flags |
| Controller | `applyPanel` restores cached panel without empty flash |
| Filter registry | Client predicate applied when server filter unsupported |
| Group dialog | `helperText` visible; Create disabled without members |
| Compose bar | Read-only banner when `!canWrite`; visible on empty writable thread |

### 9. Quality gate

- `flutter analyze` clean on touched files.
- `flutter test` for new/changed tests.
- Manual QA: `.\tool\run_web_5201.ps1` → `/communications` (checklist below).

---

## Acceptance Criteria

- [ ] **`AppWorkspaceOptionToggle`** drives both panel tabs and message filters; no `FilterChip` in Communications.
- [ ] **`AppWorkspaceSplitContent`** powers Messages master–detail layout.
- [ ] **Granular refresh flags** — no full `AsyncStateScaffold` reload on tab/filter switch.
- [ ] **Filter registry** — All, Unread, Sent, Read, Favorites, Flagged, Archived; extensible by adding registry entries.
- [ ] **`resolvePersonDisplayName`** used consistently; list/header show staff names, not emails, when data exists.
- [ ] **Thread load** on select; compose send + attach works with `communicationsWrite`.
- [ ] **Read-only** users see banner, not a blank footer.
- [ ] **New group** shows `helperText` when Create is disabled; succeeds with name + member.
- [ ] **Mutation dialogs** use `showAppWorkspaceMutationDialog`.
- [ ] **Server key `inbox` unchanged**; UI label is **Messages**.
- [ ] Widget + controller tests pass; manual QA checklist passes.

### Manual QA checklist

- [ ] Panel tabs switch instantly (cached data, inline refresh only).
- [ ] Select thread → messages load → compose visible.
- [ ] Send text + attach file → appears in thread.
- [ ] Display name shown instead of email.
- [ ] Sent / Read filters work (server or client path).
- [ ] New group helper text + successful create flow.

---

## Out of Scope

- SMS carrier / delivery failure remediation (Deliveries is observability).
- Template authoring changes.
- Real-time typing indicators.
- Renaming sidebar **Communications** nav item.
- Promoting `CommunicationsComposeBar` to global `AppMessageComposeBar` **unless** a second feature needs it in this task (keep interface flexible for later extraction).
