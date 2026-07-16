# Standardize Integrations Tables

## Objective

Refactor every `AppListTable` on the Integrations workspace (`/integrations`, `IntegrationsWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, unrelated screen chrome (tab strip, summary filter toolbar actions, Refresh), or repository/controller mutation logic unless required for compilation.

---

## Current State (from audit)

### Screen inventory

| Field | Value |
|-------|-------|
| Route | `/integrations` |
| Page widget | `IntegrationsWorkspacePage` |
| Content state | `_IntegrationsWorkspaceContentState` |
| Primary file | `frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart` |
| Entity | `IntegrationWorkItem` |
| Provider | `integrationsWorkspaceControllerProvider` (`IntegrationsWorkspaceController`) |
| Detail dialog | `_openIntegrationDetailDialog` → `AppDialog` + `_IntegrationDetailPanel` (same file) |
| Deep link | `?section=<value>` (`integrations`, `api-keys`, `webhooks`, `logs`, `interop`); also `?panel=`, `?filter=`, `?kind=`, `?search=` / `?q=` via `IntegrationWorkspaceQuery.fromUri` |

There is **one** `AppListTable<IntegrationWorkItem>` instance in `_IntegrationWorklistPanel`. Tab switches change `IntegrationDeskSection section` and call `_columnsForSection(l10n, section)` — not separate table widgets.

### Tabs (`IntegrationDeskSection`)

| Tab enum | Label (l10n) | Filter (`IntegrationWorkspaceFilter`) | Toolbar primary |
|----------|--------------|---------------------------------------|-----------------|
| `integrations` | `integrationsFilterIntegrations` | `integrations` | Create integration |
| `apiKeys` | `integrationsFilterApiKeys` | `apiKeys` | Create API key |
| `webhooks` | `integrationsFilterWebhooks` | `webhooks` | Create webhook |
| `logs` | `integrationsFilterLogs` | `logs` | *(none)* |
| `interop` | `integrationsFilterInterop` | `interop` | *(none)* |

Tab strip secondary actions (Active / Warnings / Failed summary filters + Refresh) stay in `AppTabStrip.secondaryActions` — **do not** move them into table search chrome.

### Per-section columns today (all violate ≤5 declared columns)

#### Integrations — **8 columns**

| # | id | Label | Field / builder | Notes |
|---|-----|-------|-----------------|-------|
| 1 | `name` | Name | `item.title` | `alwaysVisible: true` |
| 2 | `type` | Type | `integration.integrationType` via `_scopeLabel` | |
| 3 | `status` | Status | `AppWorkspaceStatusBadge` | Workflow status — should be position 4 |
| 4 | `owner` | Owner | `integration.tenantLabel` | Should be `columnChoices` |
| 5 | `has_config` | Configuration | icon | Should be `columnChoices` |
| 6 | `webhook_count` | Related webhooks | count | Should be `columnChoices` |
| 7 | `log_count` | Related logs | count | Should be `columnChoices` |
| 8 | `last_updated` | Last event | `item.lastEventAt` | Keep as priority data |

**Missing:** dedicated `next_action` column with explicit verb control.

#### API keys — **7 columns**

| # | id | Label | Field | Notes |
|---|-----|-------|-------|-------|
| 1 | `name` | Name | `item.title` | `alwaysVisible: true` |
| 2 | `key_id` | Reference | `apiKey.maskedValue` | |
| 3 | `status` | Status | badge | Should be position 4 |
| 4 | `user` | Owner | `apiKey.userId` | Should be `columnChoices` |
| 5 | `permissions` | Permissions | `item.scope` via `_scopeLabel` | Should be `columnChoices` |
| 6 | `expires_at` | Expires at | `apiKey.expiresAt` | Should be `columnChoices` |
| 7 | `last_used` | Last event | `apiKey.lastUsedAt` | Priority data |

**Missing:** `next_action` column.

#### Webhooks — **6 columns**

| # | id | Label | Field | Notes |
|---|-----|-------|-------|-------|
| 1 | `event` | Event | `webhook.event` | `alwaysVisible: true` |
| 2 | `integration` | Integration | `webhook.integrationLabel` | |
| 3 | `target_host` | Target host | `webhook.targetHost` | |
| 4 | `status` | Status | badge | Should be position 4 |
| 5 | `integration_status` | Integration Status | combined label | Should be `columnChoices` |
| 6 | `created_at` | Last event | `webhook.createdAt` | Mislabeled; should be `columnChoices` |

**Missing:** `next_action` column.

#### Logs — **6 columns**

| # | id | Label | Field | Notes |
|---|-----|-------|-------|-------|
| 1 | `integration` | Integration | `item.title` | `alwaysVisible: true` |
| 2 | `status` | Status | badge | Should be position 4 |
| 3 | `message` | Sanitized log | `log.message` (2 lines) | Priority data |
| 4 | `logged_at` | Last event | `log.loggedAt` | |
| 5 | `integration_type` | Type | `log.integrationType` | Should be `columnChoices` |
| 6 | `requires_attention` | Next action | icon only | Generic column id; not an explicit verb button |

**Gap:** `requires_attention` is not a proper next-action control; status is in wrong position.

#### Interop — **6 columns**

| # | id | Label | Field | Notes |
|---|-----|-------|-------|-------|
| 1 | `title` | Name | interop title via `_interopTitle` | `alwaysVisible: true` |
| 2 | `scope` | Scope | `item.scope` | |
| 3 | `status` | Status | badge | Should be position 4 |
| 4 | `next_action` | Next action | `_nextActionLabel` text only | **Not** an action button |
| 5 | `unavailable_reason` | Interop readiness | reason text | Should be `columnChoices` |
| 6 | `last_updated` | Last event | `interop.updatedAt` | |

**Gap:** next-action is plain text, not a pressable control opening detail/context.

### Search chrome gaps (`_IntegrationWorklistPanel`)

| Requirement | Current state |
|-------------|---------------|
| Filters button label `Filters` | Present — `advancedFilterButtonLabel: l10n.integrationsFiltersLabel` (`"Filters"`) |
| Filters modal title **Advanced filters** | **Wrong** — `advancedFilterTitle: l10n.integrationsFiltersLabel` (`"Filters"`) |
| Settings label `Settings` | Present — `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` |
| Settings modal title **Table Settings** | **Missing** — no `columnVisibilityTitle` |
| Session column visibility | Present — `AppListTableColumnVisibilityController` + `columnVisibilityStorageKey: 'integrations_${section.name}'` |
| Column width persistence | Present — `columnWidthStorageKey: 'integrations_cw_${section.name}'` |
| `columnChoices` for hidden columns | **Missing** |
| Search matches all columns | **Broken/incomplete** — `matcher: (_, _) => true`; domain helper `matchesIntegrationSearch` exists but omits section-specific fields (masked key, event, message, formatted dates/status labels, webhook host, etc.) |
| `displayMode` | Defaults to `adaptive` in `AppListTable` — set explicitly for clarity |
| Extra search chrome actions | None (correct) |

Current search wiring:

```dart
search: AppListTableSearch<IntegrationWorkItem>(
  controller: searchController,
  matcher: (_, _) => true,
  showAdvancedFilterButton: true,
  advancedFilterButtonLabel: l10n.integrationsFiltersLabel,
  advancedFilterTitle: l10n.integrationsFiltersLabel,
  // ...
),
```

Search state flows: `onSubmitted` / `onClear` → `controller.applySearch` → `IntegrationWorkspaceState.workItems` filters via `matchesIntegrationSearch`. Keep that controller path; **also** wire `matcher` to a comprehensive local matcher for `AppListTable` parity and tests.

### Row interaction (current — mostly correct)

- `onRowSelected` → `_openIntegrationDetailDialog` (wired in `_IntegrationsWorkspaceContent`)
- Detail dialog reuses `_IntegrationDetailPanel` with `_detailActions` per `IntegrationWorkItemKind`
- **Gap:** next-action column does not invoke the same handlers as detail actions

### Mobile (`_MobileIntegrationItem`)

- Shows title, kind/scope subtitle, status badge, next-action **text**
- **Missing:** explicit next-action **button** matching desktop column
- **Missing:** section-aware priority fields (e.g. webhook event, log message snippet, masked key)

### Workflow / next-action codes (`IntegrationWorkItem.nextAction`)

| Kind | `nextAction` codes | Mapped l10n (`_nextActionLabel`) | Primary detail action to mirror |
|------|-------------------|----------------------------------|--------------------------------|
| `integration` | `review_failure` | `integrationsNextActionReviewFailure` | `_confirmTestConnection` or Configure (`_openIntegrationDialog`) |
| `integration` | `enable` | `integrationsNextActionEnable` | `_toggleIntegration` (enable) |
| `integration` | `monitor` | `integrationsNextActionMonitor` | `_confirmSyncNow` or open detail |
| `apiKey` | `review_key` | `integrationsNextActionReviewKey` | `_openPermissionDialog` |
| `apiKey` | `rotate_or_monitor` | `integrationsNextActionRotateOrMonitor` | Open detail (read/manage) |
| `webhook` | `enable_webhook` | `integrationsNextActionEnableWebhook` | `_toggleWebhook` (enable) |
| `webhook` | `monitor_delivery` | `integrationsNextActionMonitorDelivery` | `_confirmReplayWebhook` or detail |
| `log` | `replay_or_escalate` | `integrationsNextActionReplayOrEscalate` | `_confirmReplayLog` |
| `log` | `review` | `integrationsNextActionReview` | Open detail |
| `interop` | `RUN_AVAILABLE_ACTION` | `integrationsNextActionRunEndpoint` | Open detail (read-only interop panel) |
| `interop` | `USE_INTEGRATION_STATUS_AND_LOGS` | `integrationsNextActionUseStatusLogs` | Open detail; suggest Logs tab filter |

**Do not use `WorkflowActionButton`** — integrations are not encounter workflow entities. Use compact `AppButton` / `AppAccessActionGate` pattern (see Claims prompt).

### Realtime (preserve)

`IntegrationsWorkspaceController.build()` calls `listenForRealtimeRefresh` with `RealtimeEventGroups.integrations` and `refresh()` on events. Table reads `state.workItemsPage` from provider — keep this wiring.

### Permissions (preserve)

Write actions gated by `_integrationsManageRequirement` (`integrationWrite` / admin roles + `integrations-core` module). Gate next-action buttons with `AppAccessActionGate` same as toolbar/dialog actions.

---

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `columnChoices`, `columnVisibilityTitle`, default `displayMode: adaptive`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist` (Filters/Settings chrome, `columnChoices`, search matcher, mobile item)
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn()` column factory structure (adapt with `AppButton`, not `WorkflowActionButton`)
- `prompts/15-claims-prompt.md` — non-workflow next-action button pattern (`_ClaimsNextActionButton`)
- `prompt.md`

---

## Target Architecture

### Table inventory (after refactor)

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | `columnVisibilityStorageKey` |
|--------------|-------------|--------|----------------------------------|------------------------------|
| `_IntegrationWorklistPanel` | Integrations | `IntegrationWorkItem` | Name, Type, Last event, Status, Next action | `integrations_integrations` |
| `_IntegrationWorklistPanel` | API keys | `IntegrationWorkItem` | Name, Reference, Last used, Status, Next action | `integrations_apiKeys` |
| `_IntegrationWorklistPanel` | Webhooks | `IntegrationWorkItem` | Event, Integration, Target host, Status, Next action | `integrations_webhooks` |
| `_IntegrationWorklistPanel` | Logs | `IntegrationWorkItem` | Integration, Message, Logged at, Status, Next action | `integrations_logs` |
| `_IntegrationWorklistPanel` | Interop | `IntegrationWorkItem` | Name, Scope, Last updated, Status, Next action | `integrations_interop` |

Storage keys already follow `integrations_${section.name}` — keep unchanged.

### Column plan — Integrations tab

| Position | Column id | Label (l10n) | Source field | Notes |
|----------|-----------|--------------|--------------|-------|
| 1 | `name` | `integrationsNameColumnLabel` | `item.title` | `alwaysVisible: true`; optional `AppListItemText` subtitle with `displayId` if non-empty |
| 2 | `type` | `integrationsTypeColumnLabel` | `integration.integrationType` | `_scopeLabel` |
| 3 | `last_updated` | `integrationsLastEventColumnLabel` | `item.lastEventAt` | `_dateTimeLabel` |
| 4 | `status` | `integrationsStatusColumnLabel` | `item.status` | `AppWorkspaceStatusBadge` via `_statusFor` |
| 5 | `next_action` | `integrationsNextActionColumnLabel` | `item.nextAction` | Explicit verb `AppButton` → same handler as `_detailActions` |

**`columnChoices` (hidden by default):** `owner`, `has_config`, `webhook_count`, `log_count`

### Column plan — API keys tab

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `name` | Name | `item.title` | `alwaysVisible: true` |
| 2 | `key_id` | Reference | `apiKey.maskedValue` | |
| 3 | `last_used` | Last event | `apiKey.lastUsedAt` | |
| 4 | `status` | Status | `item.status` | `AppWorkspaceStatusBadge` |
| 5 | `next_action` | Next action | `item.nextAction` | Review key / rotate buttons |

**`columnChoices`:** `user`, `permissions`, `expires_at`

### Column plan — Webhooks tab

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `event` | Event | `webhook.event` | `alwaysVisible: true` |
| 2 | `integration` | Integration | `webhook.integrationLabel` | |
| 3 | `target_host` | Target host | `webhook.targetHost` | |
| 4 | `status` | Status | `item.status` | `AppWorkspaceStatusBadge` |
| 5 | `next_action` | Next action | `item.nextAction` | Enable / monitor delivery |

**`columnChoices`:** `integration_status`, `created_at`

### Column plan — Logs tab

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `integration` | Integration | `item.title` | `alwaysVisible: true` |
| 2 | `message` | Sanitized log | `log.message` | `maxLines: 2`, ellipsis |
| 3 | `logged_at` | Last event | `log.loggedAt` | |
| 4 | `status` | Status | `item.status` | `AppWorkspaceStatusBadge` |
| 5 | `next_action` | Next action | `item.nextAction` | Replay / Review button |

**`columnChoices`:** `integration_type`

Remove standalone `requires_attention` icon column — attention is conveyed via status tone + next-action label.

### Column plan — Interop tab

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `title` | Name | `interop.title` | `_interopTitle`; `alwaysVisible: true` |
| 2 | `scope` | Scope | `item.scope` | `_scopeLabel` |
| 3 | `last_updated` | Last event | `interop.updatedAt` | |
| 4 | `status` | Status | `item.status` | `AppWorkspaceStatusBadge` |
| 5 | `next_action` | Next action | `item.nextAction` | Compact button opening detail (interop is read-only) |

**`columnChoices`:** `unavailable_reason`

### Search chrome (all sections)

Refactor `_IntegrationWorklistPanel` `AppListTableSearch`:

```dart
matcher: (IntegrationWorkItem item, String query) =>
    integrationWorklistSearchMatcher(context, l10n, section, item, query),
```

Implement `integrationWorklistSearchMatcher` in `integrations_workspace_page.dart` (or a `integrations_workspace_table.dart` part file if the page grows) to lowercase-match **every** searchable field for the active section, including hidden `columnChoices` fields and **formatted** display values:

- Common: `title`, `displayId`, `status` (raw + `_statusLabelForValue`), `scope` (`_scopeLabel`), `owner`, `nextAction` (raw + `_nextActionLabel`), `kind.name`
- Integrations: `integrationType`, `tenantLabel`, config/webhook/log counts as strings, formatted `lastEventAt`
- API keys: `maskedValue`, `userId`, permission scope label, formatted `expiresAt` / `lastUsedAt`
- Webhooks: `event`, `integrationLabel`, `targetHost`, `integrationStatus`, formatted `createdAt`
- Logs: `message`, `integrationType`, formatted `loggedAt`
- Interop: `_interopTitle`, `_interopUnavailableReason`, formatted `updatedAt`

Keep `onSubmitted` / `onClear` calling `controller.applySearch`. Expand `matchesIntegrationSearch` in `integration_entities.dart` to include the same fields for provider-side filtering parity (or delegate to shared matcher).

Standardize chrome:

| Control | Wiring |
|---------|--------|
| Filters label | `advancedFilterButtonLabel: l10n.commonFiltersActionLabel` (add shared key `"Filters"`) or keep `integrationsFiltersLabel` (already `"Filters"`) |
| Filters modal title | `advancedFilterTitle: l10n.commonAdvancedFiltersTitle` (add key `"Advanced filters"`) |
| Settings label | `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` |
| Settings modal title | `columnVisibilityTitle: l10n.commonTableSettingsTitle` (add key `"Table Settings"`) |

Preserve existing advanced filter groups (`_integrationFilterKey`, `_statusFilterChoices`, `onFilterChanged` → `controller.applyFilter`).

Wire `columnChoices` to the **full** column superset per section; pass `columns:` as the ≤5 default-visible subset (Mortuary pattern: `columns` = defaults, `columnChoices` = all toggleable columns including defaults).

Add to `AppListTable`:

```dart
displayMode: AppListTableDisplayMode.adaptive,
columnVisibilityTitle: l10n.commonTableSettingsTitle,
columnChoices: _allColumnsForSection(l10n, section),
columns: _defaultColumnsForSection(l10n, section),
```

Refactor `_columnsForSection` into `_defaultColumnsForSection` + `_allColumnsForSection` (or equivalent).

### Next-action column implementation

Add a factory mirroring Emergency/Claims:

```dart
AppListTableColumn<IntegrationWorkItem> _integrationNextActionColumn(
  BuildContext context,
  WidgetRef ref,
  IntegrationDeskSection section,
  IntegrationWorkspaceState state,
  bool canManage,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'next_action',
    label: context.l10n.integrationsNextActionColumnLabel,
    alwaysVisible: true,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareText(a.nextAction, b.nextAction),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) {
      return _IntegrationNextActionButton(
        item: item,
        section: section,
        state: state,
        canManage: canManage,
      );
    },
  );
}
```

`_IntegrationNextActionButton` must:

1. Resolve label via `_nextActionLabel(context, item.nextAction)` (existing l10n keys — already explicit verbs).
2. Wrap write actions in `AppAccessActionGate(requirement: _integrationsManageRequirement, ...)`.
3. On press, invoke the **same** functions as `_detailActions` / `_openIntegrationDetailDialog` follow-ups:
   - `review_failure` → `_confirmTestConnection` (integration) or open detail
   - `enable` / `enable_webhook` → `_toggleIntegration` / `_toggleWebhook`
   - `monitor` → `_confirmSyncNow`
   - `review_key` → `_openPermissionDialog`
   - `rotate_or_monitor` → open detail dialog
   - `monitor_delivery` → open detail or `_confirmReplayWebhook`
   - `replay_or_escalate` → `_confirmReplayLog`
   - `review` → `_openIntegrationDetailDialog`
   - interop codes → `_openIntegrationDetailDialog` only
4. Use `AppButton` compact style (`iconOnly: false`, small padding) — match Claims/Reception inline button sizing.
5. For read-only users (`!canManage`), show label text without button or disabled tertiary button opening read-only detail.

Pass `canManage` from `_IntegrationWorklistPanel` (already available in parent via `appAccessPolicyProvider`).

### Row interaction

- Keep `onRowSelected` → `_openIntegrationDetailDialog`
- Next-action column must open the same dialogs/confirmations as detail actions — never navigate to generic `/integrations` home

### Mobile parity

Refactor `_MobileIntegrationItem` to accept `section`, `canManage`, and callbacks (or convert to `ConsumerWidget`):

- Section-specific primary field (name / event / log message / interop title)
- Secondary line: type, scope, target host, or masked key as appropriate
- `AppWorkspaceStatusBadge` (already present)
- Trailing compact `_IntegrationNextActionButton` (same widget as desktop column)

---

## Implementation Steps

### 1. Add shared l10n keys (`frontend/lib/l10n/app_en.arb` only)

Add if absent:

```json
"commonFiltersActionLabel": "Filters",
"commonAdvancedFiltersTitle": "Advanced filters",
"commonTableSettingsTitle": "Table Settings"
```

`integrationsNextActionColumnLabel` and per-action keys already exist. Run project l10n codegen after edits.

### 2. Refactor column builders

**File:** `frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart`

- Split `_integrationsSectionColumns`, `_apiKeysSectionColumns`, `_webhooksSectionColumns`, `_logsSectionColumns`, `_interopSectionColumns` into:
  - `_allColumnsForSection` — full superset for `columnChoices`
  - `_defaultColumnsForSection` — ≤5 defaults including `status` (pos 4) and `next_action` (pos 5)
- Remove excess columns from defaults; keep them only in `columnChoices`
- Reorder columns so `status` is second-from-right and `next_action` is rightmost on all workflow tabs
- Mark `next_action` `alwaysVisible: true`
- Add `_integrationNextActionColumn` + `_IntegrationNextActionButton` widget

### 3. Standardize `_IntegrationWorklistPanel` table chrome

In `_IntegrationWorklistPanel.build`:

- Add `columnChoices: _allColumnsForSection(l10n, section)`
- Change `columns:` to `_defaultColumnsForSection(l10n, section, ...)`
- Add `columnVisibilityTitle: l10n.commonTableSettingsTitle`
- Add `displayMode: AppListTableDisplayMode.adaptive`
- Fix `advancedFilterTitle` to `l10n.commonAdvancedFiltersTitle`
- Wire `matcher` to `integrationWorklistSearchMatcher`
- Pass `canManage` into column builders / next-action widget

### 4. Expand domain search helper

**File:** `frontend/lib/features/integrations/domain/entities/integration_entities.dart`

- Extend `matchesIntegrationSearch` to include section-relevant nested fields (or import shared matcher if extracted)
- Ensure formatted labels used in UI are searchable where practical

### 5. Mobile updates

- Update `_MobileIntegrationItem` for section-aware layout + next-action button
- Pass `section` from `_IntegrationWorklistPanel.mobileItemBuilder`

### 6. Preserve non-table behavior

Do **not** change:

- `IntegrationsWorkspaceController` mutation methods, realtime listener, pagination
- Tab strip labels, counts, URL `section` query sync (`_updateUrlForSection`)
- Toolbar primary create actions, secondary Active/Warning/Failed/Refresh actions
- `_IntegrationDetailPanel`, form dialogs (`_IntegrationConfigDialog`, `_ApiKeyDialog`, etc.)
- Permission requirement `_integrationsManageRequirement`
- Deep-link handling (`IntegrationWorkspaceQuery`, `_applyDeepLink`)

### 7. Update tests

**File:** `frontend/test/features/integrations/presentation/integrations_workspace_page_test.dart`

- Add tests: Settings opens with title **Table Settings**; Filters modal title **Advanced filters**
- Assert each section renders ≤5 default column headers (excluding auto row-number)
- Assert `columnChoices` is non-null on `AppListTable`
- Assert `matcher` is not `(_, _) => true`
- Mobile viewport test: status badge + next-action control visible
- Keep existing tab, deep-link, permission, and storage-key tests passing

---

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Table shell |
| `AppListTableColumnVisibilityController` | same | Session column visibility |
| `AppListItemText` | `package:hosspi_hms/shared/components/app_list_item_text.dart` | Optional name + reference two-line cell |
| `AppWorkspaceStatusBadge` / `AppWorkspaceStatus` | `components.dart` | Status column (position 4) |
| `AppButton` / `AppAccessActionGate` | `components.dart` / `package:hosspi_hms/core/permissions/access_gate.dart` | Next-action column (position 5) |
| `appListTableCompareText` / `appListTableCompareDateTime` | `components.dart` | Sort comparators |

**Do not** import `WorkflowActionButton` for this screen.

---

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart` |
| Modify | `frontend/lib/features/integrations/domain/entities/integration_entities.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` |
| Modify | `frontend/test/features/integrations/presentation/integrations_workspace_page_test.dart` |
| Optional create | `frontend/lib/features/integrations/presentation/widgets/integrations_workspace_table.dart` (only if page exceeds maintainability — prefer part file) |

No files to delete.

---

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only (per locale rule)
- Prefer shared keys: `commonTableSettingsActionLabel`, `commonFiltersActionLabel`, `commonAdvancedFiltersTitle`, `commonTableSettingsTitle`
- Keep existing `integrationsNextAction*` verb keys for button labels
- Filters **button** may keep `integrationsFiltersLabel` (`"Filters"`) or switch to `commonFiltersActionLabel`

---

## Database Migrations

No database migrations required — schema unchanged.

---

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/integrations/
```

---

## Testing Requirements

- [ ] Each section table: search, Filters, Settings only in chrome (no export/refresh in search bar)
- [ ] Filters modal titled **Advanced filters**; Settings modal titled **Table Settings**
- [ ] Column visibility persists for session per `integrations_${section.name}` key
- [ ] ≤5 default columns per section; row number automatic
- [ ] All sections: `status` badge column + explicit next-action verb button
- [ ] Row tap opens `_openIntegrationDetailDialog` with `_IntegrationDetailPanel`
- [ ] Next-action button opens same dialog/confirmation as detail actions
- [ ] Mobile list shows section priority fields + status + next-action control
- [ ] Realtime refresh still updates rows after mutations/events
- [ ] `AppAccessActionGate` still gates write next-actions; read-only users can open detail

---

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for the `_IntegrationWorklistPanel` table across all five `IntegrationDeskSection` tabs
- [ ] Domain logic, permissions, dialogs, and realtime behavior preserved
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/integrations/` passes
