# Standardize Subscriptions Tables

## Objective

Refactor every `AppListTable` on the Subscriptions workspace (`/subscriptions`, `SubscriptionsWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, overview metric cards, tab toolbar primary actions (`Create plan`, `Activate subscription`, etc.), advanced-filter field definitions, cohort dialogs, or `_openSubscriptionDetailDialog` / `_SubscriptionDetailPanel` internals unless required for compilation.

## Current State (from audit)

### Screen wiring

| Field | Value |
|-------|-------|
| Route | `/subscriptions` |
| Page widget | `SubscriptionsWorkspacePage` → `_SubscriptionsWorkspaceContent` |
| Primary file | `frontend/lib/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart` |
| Controller | `subscriptionsWorkspaceControllerProvider` (`SubscriptionsWorkspaceController`) |
| Entity | `SubscriptionItem` (`frontend/lib/features/subscriptions/domain/entities/subscription_entities.dart`) |
| Realtime | `listenForRealtimeRefresh` with `RealtimeEventGroups.subscriptions` + `SubscriptionsRealtimeDeltaApplier` |
| Detail dialog | `_openSubscriptionDetailDialog` → `AppDialog` hosting `_SubscriptionDetailPanel` |
| Deep-link query | `?panel=<value>` (`overview`, `catalog`, `operations`, `billing`, `governance`); also `resource`, `search`, `id`, `queue`, filter params |
| Write permission | `AppPermissions.subscriptionsWrite` via `appAccessPolicyProvider` |

### Panel tabs vs resources

`SubscriptionPanel` tabs (`_SubscriptionsPanelTabBar`) map to default `SubscriptionResource` via `applyPanel` → `_defaultResourceForPanel`:

| Panel tab (`SubscriptionPanel`) | Tab label (`_panelLabel`) | Default resource |
|--------------------------------|---------------------------|------------------|
| `overview` | Overview | `subscriptions` |
| `catalog` | Plans | `subscriptionPlans` |
| `operations` | Subscriptions | `subscriptions` |
| `billing` | Invoices | `subscriptionInvoices` |
| `governance` | Licenses | `licenses` |

A sixth tab **Notifications** (`_notificationsTabId`) is rendered but `_onTabTapped` returns early — no panel switch (preserve as-is).

Users can switch among all six resources via the **Resource** filter group in Advanced filters (`_filterGroups` → `_FilterKeys.resource`). The worklist columns are selected by `state.query.resource` in `_worklistColumns`, not by panel alone.

### Table inventory (one widget, three column profiles)

| # | Table widget | File | Entity | Resource binding | Declared columns today | Detail on row select |
|---|--------------|------|--------|------------------|------------------------|----------------------|
| 1 | `_SubscriptionsWorklistPanel` | `subscriptions_workspace_page.dart` | `SubscriptionItem` | `SubscriptionResource` via `_worklistColumns` | **4–5** (see matrix) | `onRowSelected` → `_openSubscriptionDetailDialog` ✓ |

There is **only one** `AppListTable` on this screen. The overview metric cards (`_SubscriptionOverviewPanel`) are not tabular worklists — do not convert them.

### Per-resource column matrix (current)

**`SubscriptionResource.subscriptionPlans`** — 4 declared columns (`_PlanColumnIds` present):

| # | id | Label (`_SubscriptionsText`) | Source field | Cell pattern |
|---|-----|------------------------------|--------------|--------------|
| 1 | `plan_name` | Plan | `name` / `title` | `Text` bold |
| 2 | `plan_id` | Plan ID | `effectiveDisplayId` | `Text` bodySmall |
| 3 | `monthly_price` | Monthly (USD) | `resolvedMonthlyPrice` | `_money` |
| 4 | `annual_price` | Annual (USD) | `resolvedAnnualPrice` | `_money` |

**`SubscriptionResource.subscriptions`** — 5 declared columns (**no `id` on columns**):

| # | Label | Source field | Cell pattern |
|---|-------|--------------|--------------|
| 1 | Tenant | `tenantLabel` + `effectiveDisplayId` | `_CopyableRecordCell` (**name + ID merged**) |
| 2 | Plan | `planLabel` | `Text` bold |
| 3 | Status | `primaryStatus` | `_StatusBadge` (`AppStatusBadge`) |
| 4 | Amount | `totalAmount` / `price` | `_amountOrLimit` |
| 5 | Expiry date | `_timelineDate` | `_date` |

**All other resources** (`modules`, `moduleSubscriptions`, `subscriptionInvoices`, `licenses`) — 5 declared columns via `default` branch (**no `id`**):

| # | Label | Source field | Cell pattern |
|---|-------|--------------|--------------|
| 1 | Record | `_primaryRecordLabel` + `effectiveDisplayId` | `_CopyableRecordCell` (**name + ID merged**) |
| 2 | Status | `primaryStatus` | `_StatusBadge` |
| 3 | Plan | `_uniquePlanLabel` | `_PlanBadge` |
| 4 | Amount / limit | `totalAmount` / `price` / limits | `_amountOrLimit` |
| 5 | Renewal / expiry | `_timelineDate` | `_date` |

**Automatic row-number column:** Not declared (correct).

### Search chrome (current)

`_SubscriptionsWorklistPanel` uses `AppListTableSearch<SubscriptionItem>` with:

| Control | Current | Required (`prompt.md`) |
|---------|---------|------------------------|
| Filters button label | `_SubscriptionsText.filters` → **"Subscription filters"** | **"Filters"** |
| Advanced filter modal title | `advancedFilterTitle: _SubscriptionsText.filters` → **"Subscription filters"** | **"Advanced filters"** |
| Settings button label | `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` → **"Settings"** ✓ | **"Settings"** |
| Settings modal title | **Missing** `columnVisibilityTitle` | **"Table Settings"** |
| Search matcher | `matcher: (_, _) => true` (**no local column matching**) | Must match all column + `columnChoices` display strings |
| Extra trailing controls | None ✓ | Filters + Settings only |
| Server search | `onSubmitted: controller.applySearch` ✓ | Keep server search; add client matcher for in-page filtering parity |

### Session persistence (current)

- `AppListTableColumnVisibilityController<SubscriptionItem>` owned by `_SubscriptionsWorkspaceContentState` ✓
- **Missing:** `columnVisibilityStorageKey` on `AppListTable`
- **Missing:** `columnWidthStorageKey` on `AppListTable`
- Controller is shared across all resources — without a per-resource storage key, column visibility will bleed when switching resources via panel or Advanced filters

### Row interaction (current)

- `onRowSelected` → `_openSubscriptionDetailDialog(context, ref, item, canWrite)` ✓
- Dialog selects item via `controller.selectItem(item)`; plan resources also call `loadPlanDetail` ✓
- `_DetailActions` exposes resource-specific follow-up actions (renew, change plan, collect invoice, enable/disable module, etc.) ✓
- Deep-link `recordId` auto-opens dialog via `ref.listen` on `subscriptionsWorkspaceControllerProvider` ✓
- **No next-action column** — correct for this screen (see workflow section below)

### Responsiveness (current)

- `displayMode` not set → defaults to `AppListTableDisplayMode.adaptive` ✓
- `mobileItemBuilder` → `_SubscriptionMobileTile`:
  - Uses `_primaryRecordLabel`, `_StatusBadge`, `_PlanBadge`, `_timelineDate` only
  - **Missing:** amount/limit on mobile for subscriptions and default profiles
  - **Not resource-aware:** same layout for plans vs invoices vs licenses
  - No explicit parity with desktop column priority per resource

### Workflow / next-action semantics

**No shared workflow registry** applies to `SubscriptionItem`. Status values (`primaryStatus`, `invoiceStatus`, `fitStatus`, etc.) are **data attributes**, not encounter-scoped workflow stages.

Per `prompt.md` §4 for screens **without workflow**: use up to five priority **data** columns only. **Do not** add a generic next-action column or `WorkflowActionButton`. Detail-dialog actions in `_DetailActions` remain the action surface.

| Resource | Status source (`primaryStatus`) | Detail actions (preserve) |
|----------|--------------------------------|---------------------------|
| `subscriptions` | `status` | Edit, Renew, Change plan, Activate, Cancel |
| `moduleSubscriptions` | `isActive` / `entitlementDenied` | Enable / Disable module |
| `subscriptionInvoices` | `invoiceStatus` / `billingStatus` | Collect invoice, Retry, Print |
| `licenses` | `status` | Update license |
| `subscriptionPlans` | N/A in table | Edit plan (dialog action bar) |
| `modules` | `status` / tier | View in detail |

Replace `_StatusBadge` (`AppStatusBadge`) with `AppWorkspaceStatusBadge` + `AppWorkspaceStatus` using existing `_statusLabel` / `_statusTone` / `_statusIcon` helpers for visual parity with Mortuary.

### Gap list vs `prompt.md`

| Gap | Severity |
|-----|----------|
| Search `matcher: (_, _) => true` — no column haystack | **Blocker** |
| Filters label / modal title non-standard ("Subscription filters") | **Blocker** |
| Missing `columnVisibilityTitle` ("Table Settings") | High |
| Missing `columnVisibilityStorageKey` / `columnWidthStorageKey` per resource | High |
| No `columnChoices` — optional fields not hideable behind Settings | High |
| `_CopyableRecordCell` merges record label + `effectiveDisplayId` in tenant/record columns | High |
| `_StatusBadge` uses `AppStatusBadge` not `AppWorkspaceStatusBadge` | Medium |
| Subscriptions + default column sets lack stable `id` strings | Medium |
| Mobile tile missing amount and resource-specific priority fields | Medium |
| Hardcoded `_SubscriptionsText` for filter/settings chrome instead of shared l10n | Medium |
| Plans profile at 4 columns — room for one more default or explicit `columnChoices` | Low |

### Realtime (current — preserve)

- `SubscriptionsWorkspaceController.build()` wires `listenForRealtimeRefresh` with `RealtimeEventGroups.subscriptions`
- `SubscriptionsRealtimeDeltaApplier.apply` upserts/removes `SubscriptionItem` rows in `state.items`
- Table reads `page: state.items` from provider — no direct widget mutation ✓

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — `columnChoices`, visibility memory, `displayMode`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist` Filters/Settings chrome, `_TwoLineCell`, `AppWorkspaceStatusBadge`
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — explicit action label patterns (reference only; **do not** add `WorkflowActionButton` here)
- `prompt.md`

Copy patterns:

```dart
// Standardized search chrome
search: AppListTableSearch<SubscriptionItem>(
  showAdvancedFilterButton: true,
  advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
  advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
  matcher: _matchesSubscriptionTableSearch, // real haystack — not (_, _) => true
  onSubmitted: controller.applySearch,
  onClear: () => controller.applySearch(''),
  // preserve existing filterGroups / onFilterChanged / hasActiveFilters
),
columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
columnVisibilityTitle: l10n.commonTableSettingsTitle,
```

```dart
// Single semantic field with primary/secondary tier (replace _CopyableRecordCell in table columns)
AppListItemText(
  title: item.tenantLabel ?? l10n.profileUnknownValue,
  subtitle: item.tenantId, // or omit subtitle if not part of same field
)
```

```dart
// Status column
AppWorkspaceStatusBadge(
  status: AppWorkspaceStatus(
    label: _statusLabel(item.primaryStatus),
    tone: _statusTone(item.primaryStatus),
    icon: _statusIcon(item.primaryStatus),
  ),
)
```

## Target Architecture

### Table inventory

| Table widget | Tab / resource profile | Entity | Default visible columns (max 5) | columnVisibilityStorageKey | columnWidthStorageKey |
|--------------|------------------------|--------|----------------------------------|----------------------------|------------------------|
| `_SubscriptionsWorklistPanel` | `subscriptionPlans` | `SubscriptionItem` | plan, monthly_price, annual_price, tier, status_or_modules | `subscriptions_ws_subscription_plans` | `subscriptions_cw_subscription_plans` |
| `_SubscriptionsWorklistPanel` | `subscriptions` | `SubscriptionItem` | tenant, plan, status, amount, expiry_date | `subscriptions_ws_subscriptions` | `subscriptions_cw_subscriptions` |
| `_SubscriptionsWorklistPanel` | `modules` | `SubscriptionItem` | module, status, tier, amount_limit, renewal_expiry | `subscriptions_ws_modules` | `subscriptions_cw_modules` |
| `_SubscriptionsWorklistPanel` | `moduleSubscriptions` | `SubscriptionItem` | module, tenant, status, plan, expiry_date | `subscriptions_ws_module_subscriptions` | `subscriptions_cw_module_subscriptions` |
| `_SubscriptionsWorklistPanel` | `subscriptionInvoices` | `SubscriptionItem` | invoice, tenant, status, amount, issued_at | `subscriptions_ws_subscription_invoices` | `subscriptions_cw_subscription_invoices` |
| `_SubscriptionsWorklistPanel` | `licenses` | `SubscriptionItem` | license, tenant, status, amount, expires_at | `subscriptions_ws_licenses` | `subscriptions_cw_licenses` |

Wire keys from `state.query.resource.serverValue` (normalize hyphens to underscores).

### Column plan (per resource)

Refactor `_worklistColumns` into a builder returning `(columns, columnChoices)` or equivalent. Every `AppListTableColumn` **must** have a stable `id`.

#### `subscriptionPlans`

| Position | Column id | Label | Source field | Notes |
|----------|-----------|-------|--------------|-------|
| 1 | `plan` | Plan | `name` | `AppListItemText` title=`name`, subtitle=`code` (one plan field) |
| 2 | `monthly_price` | Monthly (USD) | `resolvedMonthlyPrice` | `_money`; keep `numeric: true` |
| 3 | `annual_price` | Annual (USD) | `resolvedAnnualPrice` | `_money` |
| 4 | `tier` | Tier | `tierCode` | `_PlanBadge` or formatted tier label |
| 5 | `modules` | Modules | `activeModuleCount` / `maxModules` | e.g. `3 / 10` or `activeModuleCount` only |

**`columnChoices` (hidden by default):** `plan_id` (`effectiveDisplayId`), `billing_cycle`, `max_users`, `max_facilities`, `max_storage`, `updated_at`, `description`

#### `subscriptions`

| Position | Column id | Label | Source field | Notes |
|----------|-----------|-------|--------------|-------|
| 1 | `tenant` | Tenant | `tenantLabel` | `AppListItemText`; **do not** embed `effectiveDisplayId` here |
| 2 | `plan` | Plan | `planLabel` | `Text` bold |
| 3 | `status` | Status | `primaryStatus` | `AppWorkspaceStatusBadge` |
| 4 | `amount` | Amount | `totalAmount` / `price` | `_money` |
| 5 | `expiry_date` | Expiry date | `_timelineDate` | `_date` |

**`columnChoices`:** `subscription_id` (`effectiveDisplayId`), `billing_cycle`, `fit_status`, `start_date`, `change_status`, `tenant_id`

#### `modules`

| Position | Column id | Label | Source field | Notes |
|----------|-----------|-------|--------------|-------|
| 1 | `module` | Module | `name` | `AppListItemText` title=`name`, subtitle=`code` |
| 2 | `status` | Status | `primaryStatus` | `AppWorkspaceStatusBadge` |
| 3 | `tier` | Tier | `tierCode` | `_PlanBadge` |
| 4 | `amount_limit` | Amount / limit | limits / price | `_amountOrLimit` |
| 5 | `renewal_expiry` | Renewal / expiry | `_timelineDate` | `_date` |

**`columnChoices`:** `module_id`, `description`, `is_add_on`, `updated_at`

#### `moduleSubscriptions`

| Position | Column id | Label | Source field | Notes |
|----------|-----------|-------|--------------|-------|
| 1 | `module` | Module | `moduleLabel` | `AppListItemText` |
| 2 | `tenant` | Tenant | `tenantLabel` | single field |
| 3 | `status` | Status | `primaryStatus` | `AppWorkspaceStatusBadge` (denied → error tone) |
| 4 | `plan` | Plan | `planLabel` | `Text` |
| 5 | `expiry_date` | Expiry date | `_timelineDate` | `_date` |

**`columnChoices`:** `record_id`, `fit_status`, `eligibility`, `module_id`, `tenant_id`

#### `subscriptionInvoices`

| Position | Column id | Label | Source field | Notes |
|----------|-----------|-------|--------------|-------|
| 1 | `invoice` | Invoice | `invoiceDisplayId` | `AppListItemText` |
| 2 | `tenant` | Tenant | `tenantLabel` | single field |
| 3 | `status` | Status | `primaryStatus` | `AppWorkspaceStatusBadge` |
| 4 | `amount` | Amount | `totalAmount` / `price` | `_money` |
| 5 | `issued_at` | Issued at | `issuedAt` / `paidAt` | `_date` |

**`columnChoices`:** `invoice_id`, `billing_status`, `due_date`, `payment_method`

#### `licenses`

| Position | Column id | Label | Source field | Notes |
|----------|-----------|-------|--------------|-------|
| 1 | `license` | License | `licenseType` | `AppListItemText` |
| 2 | `tenant` | Tenant | `tenantLabel` | single field |
| 3 | `status` | Status | `primaryStatus` | `AppWorkspaceStatusBadge` |
| 4 | `amount` | Amount | `price` / `totalAmount` | `_money` if present |
| 5 | `expires_at` | Expires at | `expiresAt` / `_timelineDate` | `_date` |

**`columnChoices`:** `license_id`, `issued_at`, `start_date`, `end_date`

Pass hidden columns via `columnChoices` on `AppListTable<SubscriptionItem>`:

```dart
AppListTable<SubscriptionItem>(
  columns: defaultColumnsForResource(state.query.resource),
  columnChoices: optionalColumnsForResource(state.query.resource),
  columnVisibilityStorageKey: 'subscriptions_ws_${resourceKey}',
  columnWidthStorageKey: 'subscriptions_cw_${resourceKey}',
  columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
  columnVisibilityTitle: l10n.commonTableSettingsTitle,
  displayMode: AppListTableDisplayMode.adaptive,
  // ...
)
```

When `state.query.resource` changes, the table must rebuild with the new column profile **and** storage keys so visibility preferences are isolated per resource.

### Search chrome (per table)

Implement `_matchesSubscriptionTableSearch(SubscriptionItem item, String query, SubscriptionResource resource)` (or pass resource via closure) that lowercases a haystack built from **every** default and `columnChoices` column's display strings for the active resource, including:

- Formatted money (`_money`), dates (`_date`), status labels (`_statusLabel`)
- `_primaryRecordLabel`, `_uniquePlanLabel`, `_amountOrLimit` output
- Hidden choice fields when user toggles them visible (include all registered column ids in haystack regardless of visibility — search must match hidden columns per `prompt.md` §1)

Keep `onSubmitted` → `controller.applySearch` for server-side search. The matcher covers client-side filtering within the loaded page if `AppListTableSearch` applies it locally (match Mortuary `_matchesSearch` behavior).

- Filters: `advancedFilterButtonLabel: l10n.commonFiltersActionLabel` → **"Filters"**
- Advanced filters modal: `advancedFilterTitle: l10n.commonAdvancedFiltersTitle` → **"Advanced filters"**
- Settings: `commonTableSettingsActionLabel` / `commonTableSettingsTitle`
- Preserve existing `filterGroups`, `onFilterChanged`, `hasActiveFilters`, `enableDateFilter: false`
- Do **not** add export, refresh, or overflow to search chrome

### Row interaction

- Keep `onRowSelected` → `_openSubscriptionDetailDialog(context, ref, item, canWrite)`
- Preserve `itemKeyBuilder`, `rowColorBuilder` for plans/subscriptions tinting
- Do **not** add a table next-action column

### Mobile (`_SubscriptionMobileTile`)

Rebuild to accept `SubscriptionResource resource` (or derive from `item.resource`) and mirror each resource's five default columns:

- **Plans:** plan name, tier badge, monthly + annual summary line
- **Subscriptions:** tenant, plan, status badge, amount, expiry
- **Invoices:** invoice id, tenant, status, amount
- **Licenses:** license type, tenant, status, expiry
- **Module subscriptions:** module, tenant, status, expiry
- **Modules:** module name, status, tier

Keep row tap via `AppListTable` `onRowSelected`. Add trailing chevron for affordance (optional).

## Implementation Steps

1. **`frontend/lib/l10n/app_en.arb`**
   - Add shared keys if missing:
     - `commonFiltersActionLabel`: **"Filters"**
     - `commonAdvancedFiltersTitle`: **"Advanced filters"**
     - `commonTableSettingsTitle`: **"Table Settings"**
   - Run `flutter gen-l10n` during verification.
   - Prefer these shared keys over `_SubscriptionsText.filters` in table search chrome.

2. **`subscriptions_workspace_page.dart` — search chrome**
   - In `_SubscriptionsWorklistPanel`, replace `matcher: (_, _) => true` with `_matchesSubscriptionTableSearch` indexed to all column display values for `state.query.resource`.
   - Set `advancedFilterButtonLabel: context.l10n.commonFiltersActionLabel`.
   - Set `advancedFilterTitle: context.l10n.commonAdvancedFiltersTitle`.
   - Add `columnVisibilityTitle: context.l10n.commonTableSettingsTitle`.
   - Add per-resource `columnVisibilityStorageKey` and `columnWidthStorageKey`.
   - Set `displayMode: AppListTableDisplayMode.adaptive` explicitly.

3. **`subscriptions_workspace_page.dart` — column refactor**
   - Replace `_worklistColumns` with resource-aware factories returning `columns` + `columnChoices`.
   - Add stable `id` to every column.
   - Replace `_CopyableRecordCell` in **table** cells with `AppListItemText` (keep `_CopyableRecordCell` in detail header if desired).
   - Replace `_StatusBadge` in table/mobile with `AppWorkspaceStatusBadge` + `AppWorkspaceStatus` (retain `_statusLabel`, `_statusTone`, `_statusIcon`).
   - Pass `columnChoices` into `AppListTable`.
   - Keep `initialSortColumnKey` behavior for plans (`_PlanColumnIds.monthlyPrice` → `monthly_price` after rename).

4. **`subscriptions_workspace_page.dart` — mobile**
   - Refactor `_SubscriptionMobileTile` to resource-specific layout per target architecture.
   - Pass `item.resource` or active resource from parent.

5. **Cleanup**
   - Remove unused `_CopyableRecordCell` from table column builders if fully replaced.
   - Keep `_PlanColumnIds` in sync with new ids or migrate to a single `_SubscriptionColumnIds` namespace per resource.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Table shell |
| `AppListTableColumnVisibilityController` | `package:hosspi_hms/shared/components/components.dart` | Session column visibility |
| `AppListTableColumnVisibilityMemory` | `package:hosspi_hms/shared/components/app_list_table_column_visibility_memory.dart` | Backing store (via controller) |
| `AppListItemText` | `package:hosspi_hms/shared/components/app_list_item_text.dart` | Two-line single-field cells |
| `AppWorkspaceStatusBadge` / `AppWorkspaceStatus` | `package:hosspi_hms/shared/layout/layout.dart` | Status column + mobile |
| `appListTableCompareText` / `Number` / `DateTime` | `app_list_table.dart` | Sort comparators |
| `_openSubscriptionDetailDialog` | same file | Row selection destination |
| `_DetailActions` | same file | Detail dialog follow-up actions |

**Do not use** `WorkflowActionButton` on this screen.

## Files to Create / Modify / Delete

| File | Action |
|------|--------|
| `frontend/lib/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart` | **Modify** — table chrome, columns, matcher, mobile tile |
| `frontend/lib/l10n/app_en.arb` | **Modify** — add shared table chrome l10n keys |
| `frontend/lib/l10n/app_localizations.dart` | Auto-generated |
| `frontend/lib/l10n/app_localizations_en.dart` | Auto-generated |

No new files required unless you extract column builders to a `subscriptions_workspace_table_columns.dart` part file for readability (optional).

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only (per locale rule)
- Prefer shared keys: `commonTableSettingsActionLabel`, `commonFiltersActionLabel`, `commonAdvancedFiltersTitle`, `commonTableSettingsTitle`
- Existing `_SubscriptionsText` column labels may remain static for this pass unless you are already migrating the module to l10n — **must** migrate filter/settings chrome labels to shared l10n keys

## Database Migrations

No database migrations required — schema unchanged.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/subscriptions/
```

Manual smoke checks on `/subscriptions`:

1. Each resource profile (switch via panel tabs and Advanced filters → Resource): search, Filters, Settings only in table chrome
2. Column visibility persists per resource when switching catalog ↔ operations ↔ billing
3. ≤5 default columns; row number automatic
4. Row tap opens `_openSubscriptionDetailDialog` with `_DetailActions` for writable users
5. Mobile narrow width shows resource-appropriate fields
6. After a mutation (e.g. activate subscription), table refreshes via provider without manual reload

## Testing Requirements

- [ ] Each resource profile: search, Filters, Settings only in chrome
- [ ] Column visibility persists for session per `columnVisibilityStorageKey`
- [ ] ≤5 default columns; row number automatic
- [ ] No next-action column added (data-only entities)
- [ ] Row tap opens detail dialog
- [ ] Mobile list shows same priority fields per resource
- [ ] Realtime refresh still updates rows after mutations/events
- [ ] `AppPermissions.subscriptionsWrite` still gates write actions in detail dialog
- [ ] `subscriptions_workspace_controller_test.dart` still passes

Note: There is no `subscriptions_workspace_page_test.dart` today — rely on analyzer + controller tests unless you add focused widget tests for column counts and search matcher.

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for the `_SubscriptionsWorklistPanel` table across all six `SubscriptionResource` profiles
- [ ] Domain logic preserved (filters, pagination, permissions, dialogs, realtime, deep links)
- [ ] Analyze clean; `flutter test test/features/subscriptions/` passes
