# Action inventory — `/integrations`

Primary surface: `IntegrationsWorkspacePage` (`frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart`).

Write gate: `_integrationsManageRequirement` (`integrationWrite` / tenant / facility / system admin + `integrations-core` module). Unauthorized create / next-action write / detail write controls do not render.

Dialog chrome: each `AppDialog` has a labeled **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** | Reload workspace | **Removed** — mutations / realtime / scaffold **Try again** refresh |
| Tab-strip **Active / Warnings / Failed** | Status filter (replaced section filter) | **Removed** — advanced **Filters** is the sole status entry; status now scopes within the active section |
| Detail action matching row next-action (Test / Sync / Enable / Manage permissions / Enable webhook / Replay log) | Same mutation | **Omitted** from detail — next-action is the sole primary for that goal |
| `selectItem` before Test / Sync / Permissions / Replay confirms | Empty intermediate select | **Removed** — mutation dialogs open directly from next-action |
| Mobile list without next-action trailing | Same as desktop next-action | **Fixed** — `_IntegrationNextActionButton` on `AppListTableMobileItem.trailing` |

---

## Integrations workspace screen

### Tab strip

- **Integrations / API keys / Webhooks / Logs / Interop**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, applies section filter (preserves status filter).
  - Condition: Always when workspace loads; counts from loaded collections.

- **Create integration** (primary, Integrations)
  - Location: Tab-strip primary (`integrationsCreateIntegrationAction`).
  - Opens modal: Yes — create/edit integration form.
  - Immediate result: Creates integration; snackbar; workspace sync.
  - Condition: Manage requirement; omitted when unauthorized or on other tabs.

- **Create API key** (primary, API keys)
  - Location: Tab-strip primary (`integrationsCreateApiKeyAction`).
  - Opens modal: Yes — create API key form (+ secret reveal on success).
  - Condition: Manage requirement.

- **Create webhook** (primary, Webhooks)
  - Location: Tab-strip primary (`integrationsCreateWebhookAction`).
  - Opens modal: Yes — create/edit webhook form.
  - Condition: Manage requirement.

Logs and Interop have no tab-strip toolbar actions. Tab-strip **Refresh** and status shortcuts were removed.

- **Try again** (page load / inline failure)
  - Location: `AsyncStateScaffold` or failure snackbar surfaces.
  - Opens modal: No.
  - Immediate result: Retries workspace load / shows failure.
  - Condition: Load or mutation failure.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (advanced status), **Settings** (columns), pagination
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters (Active / Warning / Failed / Disabled); Table Settings.
  - Immediate result: Status filter applies **within** the active section tab; clear restores section-only view.
  - Condition: Always on the worklist.

### Row activation

- **Row select** (desktop / mobile)
  - Location: Table row / mobile list item.
  - Opens modal: Integration detail dialog (metadata + secondary writes).
  - Immediate result: Selects item and opens detail; omits the row next-action from detail actions.
  - Condition: When rows exist.

- **Next action** (labeled primary row control)
  - Location: `next_action` column; mobile `AppListTableMobileItem.trailing`.
  - Opens modal: Confirm / permissions / detail depending on action.
  - Immediate result:
    - Integrations: Test connection / Enable / Sync now (no empty select shell).
    - API keys: Manage permissions (warning) or open detail (healthy).
    - Webhooks: Enable webhook or open detail (active).
    - Logs: Replay (attention) or open detail (review).
    - Interop: Open detail (readiness guidance).
  - Condition: Write-gated actions omit when unauthorized; view-only next-actions remain for read users.

### Detail dialog (from row select / view next-action)

Shows reference, status, scope, last event, kind-specific panels (config, related webhooks/logs, masked secret, permissions, sanitized log, interop readiness).

Secondary writes when manage-authorized and not the row next-action:

- Integration: Configure; Test / Sync / Enable·Disable when not the next-action.
- API key: Manage permissions when not next-action; Enable·Disable; Revoke.
- Webhook: Edit; Replay; Enable·Disable when not next-action.
- Log: Replay when not next-action.
- Interop: no write actions.

### Empty / loading / error / validation

- Empty worklist: `integrationsEmptyTitle` / `integrationsEmptyBody`.
- Loading: `integrationsLoadingTitle` / `integrationsLoadingBody`.
- Form validation stays inside mutation dialogs; success/error via snackbar / action-result panel.

---

## Verification (Req 7)

- Widget tests in `frontend/test/features/integrations/presentation/integrations_workspace_page_test.dart` prove:
  - Tab-strip has no **Refresh** / **Active** / **Warnings** / **Failed** shortcuts.
  - Section create primaries remain on Integrations / API keys / Webhooks when write-authorized; absent when read-only.
  - Next-action column remains; mobile trailing next-action present.
  - Advanced filters remain the status entry point.
- Domain tests cover `statusFilter` parsing / section+status matching where added.
