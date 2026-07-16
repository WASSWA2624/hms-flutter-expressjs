# Standardize Billing Screen (Tabs & Toolbar)

## Objective

Refactor the Billing workspace (`/billing`, `BillingWorkspacePage`) so its chrome fully complies with `prompt.md`:
no dedicated screen title/header; `AppTabStrip` at the top; contextual toolbar immediately
beneath tabs; table-local actions limited to Filters and Settings; consistent naming.

## Compliance Checklist (from prompt.md)

- [ ] No dedicated screen title/header
- [ ] Shared `AppTabStrip` at top with consistent vertical padding
- [ ] Toolbar immediately under tabs via `primaryAction` / `secondaryActions`
- [ ] All former header / more-menu actions relocated into the contextual toolbar
- [ ] Toolbar actions change with the active tab
- [ ] Every screen retains at least one toolbar button overall
- [ ] Tables expose only Filters and Settings inside the table area
- [ ] Consistent button labels (l10n) across tabs

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every
step below precisely. Do not skip steps. Do not ask for clarification. Run tests and formatting
after implementation. Treat `prompt.md` as the normative layout contract.

**Do not invent new tab/table/search/filter chrome.** Reuse the shared components listed below.
**Preserve all Billing domain logic** (queue filtering, search/debounced search, advanced filters,
pagination, work-item detail dialog + mutation dialogs, shift/day close, invoice print/download,
permissions via `AppPermissions.billingWrite`, queue counts, realtime refresh via
`billingWorkspaceControllerProvider`, deep links including `action=pay`). This refactor is
**layout/chrome and label standardization only**.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`
  - Public widget: `BillingWorkspacePage` (`initialQuery: BillingWorkspaceQuery?`)
  - Content: `_BillingWorkspaceContent` / `_BillingWorkspaceContentState`
  - Table panel: `_BillingQueuePanel` → `AppListTable<BillingWorkItem>`
  - Detail: `_showBillingDetailDialog` → `BillingDetailBody` (dialog-only row actions — **do not** promote into screen toolbar)
  - Close flows: `_showShiftCloseDialog`, `_showDayCloseDialog` (currently wired from workspace toolbar)
- Controller: `frontend/lib/features/billing/presentation/controllers/billing_workspace_controller.dart`
  - Provider: `billingWorkspaceControllerProvider`
  - Key methods: `refresh()`, `applyQueue()`, `applySearch()`, `applyFilters()`, `clearFilters()`,
    `changePage()`, `selectItem()`, `receivePayment()`, `issueSelectedInvoice()`, `closeShift()`,
    `closeDay()`, plus claim/approval/refund/adjustment/void/send/pre-auth mutations
- Domain: `frontend/lib/features/billing/domain/entities/billing_entities.dart`
  - Enum: `BillingQueueType { all, needsIssue, pendingPayment, claimsPending, approvalRequired, overdue }`
  - Query: `BillingWorkspaceQuery.fromUri` parses `queue`/`filter`, `search`/`q`, patient/invoice/encounter/source/status, `action`
- Support labels/icons: `frontend/lib/features/billing/presentation/widgets/billing_support.dart`
  - `billingQueueLabel`, `billingQueueIcon`, `billingQueueCountTone`
- Dialogs/widgets (reuse, do not rewrite):
  - `billing_form_dialogs.dart`, `billing_detail_widgets.dart`, `billing_receive_payment_dialog.dart`,
    `billing_ledger_dialog.dart`, `billing_invoice_print_helpers.dart`
- Routes: `AppRoutes.billing` path `/billing` in `frontend/lib/app/router/app_routes.dart`
  - Router builder in `frontend/lib/app/router/app_router.dart`:
    `BillingWorkspacePage(initialQuery: BillingWorkspaceQuery.fromUri(state.uri))`
- Tests:
  - `frontend/test/features/billing/presentation/billing_workspace_page_test.dart` (tabs, URL queue, deep links, columns)
  - `frontend/test/features/billing/presentation/billing_workspace_controller_test.dart`
  - `frontend/test/features/billing/domain/billing_entities_test.dart` (queue slug parsing)
  - `frontend/test/features/billing/data/billing_dtos_test.dart`

### Current widget tree (data state)

```
AsyncStateScaffold<BillingWorkspaceState>(
  appBarTitle: l10n.billingWorkspaceTitle,  // loading/empty chrome only
  maxWidth: PageMaxWidth.dataHeavy,
  dataBuilder → _BillingWorkspaceContent
)
  └── AppWorkspace(
        title: billingWorkspaceTitle,
        leadingIcon: AppRouteIcons.billing,
        showHeader: false (default),
        toolbar: appWorkspaceToolbarWithLabels(   // ← RENDERS ABOVE TABS (gap)
          summaryNotifications: _summaryNotifications(...),  // queue jump chips
          secondary: [Close shift, Close day],
          onRefresh: controller.refresh,
        ),
        body: Column(
          ├── optional AppFailureStateView
          ├── AppTabStrip(tabs only — NO primaryAction / secondaryActions)
          ├── SizedBox(height: theme.spacing.sm)
          └── _BillingQueuePanel → AppListTable (search + Filters + Settings)
        ),
      )
```

### Tabs (validated against code + l10n)

| # | Tab label (EN / l10n key) | Enum | Query `?queue=` written by `_updateUrlForQueue` | Tab id (`AppTabItem.id`) | Count |
|---|---------------------------|------|--------------------------------------------------|--------------------------|-------|
| 1 | All billing work items (`billingAllWorkItems`) | `all` | *(omit when `all`)* | `all` | `summary.workloadCount` |
| 2 | Needs issue (`billingNeedsIssue`) | `needsIssue` | `needs-issue` | `needsIssue` | `summary.needsIssue` |
| 3 | Awaiting payment (`billingAwaitingPayment`) | `pendingPayment` | `pending-payment` | `pendingPayment` | `summary.pendingPayment` |
| 4 | Claims pending (`billingClaimsPending`) | `claimsPending` | `claims-pending` | `claimsPending` | `summary.claimsPending` |
| 5 | Approval required (`billingApprovalRequired`) | `approvalRequired` | `approval-required` | `approvalRequired` | `summary.approvalRequired` |
| 6 | Overdue (`billingOverdue`) | `overdue` | `overdue` | `overdue` | `summary.overdue` |

Notes:

- Labels come from `billingQueueLabel` in `billing_support.dart` (not `billingIssueQueue` / `billingApprovals` — those older keys appear only in `_summaryNotifications`).
- Deep-link tab state **is already URL-backed** via `?queue=` + `GoRouter.replace` in `_updateUrlForQueue` / `_selectQueue`. `BillingWorkspaceQuery.fromUri` also accepts enum names, server values (`PENDING_PAYMENT`), and kebab slugs. **Keep this; do not invent a second tab query key.**
- Additional deep-link params (`search`, `patientId`, `invoice`, `encounter`, `source`, `status`, `action=pay`) must keep working via `_applyRouteQuery` / `_autoOpenPaymentDialog`.

### Current toolbar / header (gaps)

1. **Workspace toolbar above tabs** via `AppWorkspace.toolbar` + `appWorkspaceToolbarWithLabels` — violates “toolbar immediately beneath tabs”.
2. **`AppTabStrip` has no `primaryAction` / `secondaryActions`** — toolbar is not under tabs and not tab-contextual.
3. **Summary notification chips** in the workspace toolbar duplicate tab counts and act as alternate tab selectors — remove from chrome (tabs already expose counts + selection).
4. Screen actions today (must relocate into `AppTabStrip` toolbar):
   - **Close shift** — `l10n.billingCloseShift`, icon `Icons.schedule_send_outlined`, gated by `canWrite`, → `_showShiftCloseDialog`
   - **Close day** — `l10n.billingCloseDay`, icon `Icons.today_outlined`, gated by `canWrite`, → `_showDayCloseDialog`
   - **Refresh** — via `onRefresh: controller.refresh` / `isRefreshing: state.isRefreshing`
5. **No overflow / “more” menu** for screen actions today (good — do not add one).
6. Row/detail actions (Receive payment, Issue, Refund, Claim submit/reconcile, Approve/Reject, Print, Download, Ledger, etc.) live inside `_showBillingDetailDialog` — **keep them dialog-local**.

### Current table chrome (gaps)

- Search: `AppListTableSearch` with `billingSearchHint` / `billingSearchSemanticLabel` — keep.
- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` → currently **"Table settings"** — must become standardized **"Settings"** (shared key).
- Filters: `advancedFilterButtonLabel` / `advancedFilterTitle` use `l10n.billingFiltersTitle` → **"Billing filters"** — must become standardized **"Filters"**.
- Filter dialog already has queue/source/status groups + text filters + issued-date range — **preserve behavior**; only fix labels and keep Filters inside table chrome.
- No other table header actions beyond search / Filters / Settings — keep it that way.

### Concrete `prompt.md` gaps to close

1. Replace `AppWorkspace` + above-tabs `toolbar` with Reception/HR-style headerless `ResponsivePage` + `AppTabStrip` toolbar under tabs.
2. Move Close shift / Close day / Refresh into `AppTabStrip.primaryAction` / `secondaryActions`, **contextual per active `BillingQueueType`**.
3. Remove `_summaryNotifications` from screen chrome (counts stay on tabs).
4. Standardize table Filters label to **"Filters"** and Settings to **"Settings"**.
5. Guarantee ≥1 toolbar button on every tab after contextualization.
6. Do not reintroduce `showHeader: true`, titled header bars, FABs, or header more-menus.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative layout contract)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  — headerless `ResponsivePage` + `AppTabStrip` + `SizedBox(theme.spacing.sm)` + `AppListTable`
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`
  — **copy this pattern** for per-tab `primaryAction` + `secondaryActions` helpers
- `frontend/lib/shared/components/app_tab_strip.dart`
  — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `showHeader` (default `false`); Billing must **stop** using `AppWorkspace` for this page chrome
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — reference only; do **not** keep `appWorkspaceToolbarWithLabels` on Billing after migration
- `frontend/lib/shared/layout/responsive_page.dart` — wrap success content like Reception/HR
- `frontend/lib/shared/components/app_list_table.dart` / `app_search_bar.dart` — Filters + Settings in table search chrome
- `frontend/lib/core/permissions/access_gate.dart` — optional `AppAccessActionGate`
- `frontend/lib/core/responsive/app_breakpoints.dart` — breakpoint tokens used by `ResponsivePage`

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| All billing work items | `/billing` (omit `queue` or treat as all) | Full workload across queues | **Close shift** (`billingCloseShift`, `Icons.schedule_send_outlined`) write-gated → `_showShiftCloseDialog` | **Close day** (`billingCloseDay`, `Icons.today_outlined`) write-gated → `_showDayCloseDialog`; **Refresh** (`commonRefreshActionLabel`, `Icons.refresh`) → `controller.refresh()`, `isLoading: state.isRefreshing` |
| Needs issue | `/billing?queue=needs-issue` | Draft / unissued invoices | **Refresh** (`commonRefreshActionLabel`) → `controller.refresh()` | **Close shift** (write-gated); **Close day** (write-gated) |
| Awaiting payment | `/billing?queue=pending-payment` | Issued invoices awaiting payment | **Close shift** (write-gated) → `_showShiftCloseDialog` | **Close day** (write-gated); **Refresh** |
| Claims pending | `/billing?queue=claims-pending` | Insurance claims in flight | **Refresh** → `controller.refresh()` | **Close shift** (write-gated); **Close day** (write-gated) |
| Approval required | `/billing?queue=approval-required` | Refunds/adjustments/voids needing approval | **Refresh** → `controller.refresh()` | **Close shift** (write-gated); **Close day** (write-gated) |
| Overdue | `/billing?queue=overdue` | Overdue balances | **Close day** (write-gated) → `_showDayCloseDialog` | **Close shift** (write-gated); **Refresh** |

Notes:

- Use `AppTabToolbarPrimary` for the single right-aligned primary CTA and `AppTabToolbarAction` for left-cluster secondaries (matches `AppTabStrip` contract / HR pattern).
- Write-gate Close shift / Close day with existing `canWrite = accessPolicy.grants(AppPermissions.billingWrite)` **or** an inline `AccessRequirement(anyPermissions: [AppPermissions.billingWrite])` + `AppAccessActionGate`. Prefer enabling/disabling (or hiding when denied) consistently with today’s `enabled: canWrite && !state.isSaving`.
- Prefer `AppTabToolbarAction` for Refresh (flat tab-toolbar style). Do **not** put Refresh / Close shift / Close day into `AppListTableSearch.trailingActions`.
- Do **not** move row/detail dialog actions into the tab toolbar.
- Every tab has ≥1 toolbar button (Refresh and/or Close shift/day).

### Routing

- Keep `/billing` registration in `app_router.dart` unchanged.
- Keep query key **`queue`** (already written by `_updateUrlForQueue` / parsed by `BillingWorkspaceQuery.fromUri`).
- Canonical write values must remain:
  - *(omit for all)* | `needs-issue` | `pending-payment` | `claims-pending` | `approval-required` | `overdue`
- Preserve `_queueToQueryValue`, `_selectQueue`, `_applyRouteQuery`, `_autoOpenPaymentDialog`, and `hasRouteTargeting` behavior.
- Do **not** rename the query key to `section`/`tab` unless also updating `BillingWorkspaceQuery.fromUri` + all tests — prefer keeping `queue`.

### Page Layout

Precise widget tree:

1. Keep `AsyncStateScaffold<BillingWorkspaceState>` for loading/error (drop `appBarTitle` if unused after chrome change is fine; do not invent a persistent title bar).
2. Success content: `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` → `SizedBox(width: double.infinity)` → `Column` (**no** `AppWorkspace`).
3. `AppTabStrip(tabs:, selectedId: _section.name, onTabTapped:, primaryAction: <per-queue>, secondaryActions: <per-queue>)`.
4. `SizedBox(height: theme.spacing.sm)` between strip and body (keep existing vertical rhythm).
5. Optional `AppFailureStateView` for `state.lastFailure` (keep under tabs or immediately above table — same as today relative to table; do not place above `AppTabStrip`).
6. Body: `_BillingQueuePanel` / `AppListTable<BillingWorkItem>` whose search chrome exposes **only**:
   - Search field
   - **Filters** (advanced filter button / dialog — existing filter groups)
   - **Settings** (column visibility)
7. No FAB / floating header actions / overflow more-menu / summary-notification toolbar chips for screen actions.

### Data & State Management

Reuse (do not fork):

- `billingWorkspaceControllerProvider` / `BillingWorkspaceController`
- `BillingQueueType` / `BillingWorkspaceQuery` / `BillingWorkspaceState` / `BillingWorkItem`
- `billingQueueLabel` / `billingQueueIcon` / `billingQueueCountTone`
- Permission: `appAccessPolicyProvider` + `AppPermissions.billingWrite`
- Existing dialog helpers on the page file

Add/adjust UI helpers only:

- `_buildPrimaryAction(...)` and `_buildSecondaryActions(...)` switching on `_section` (`BillingQueueType`) per the Tab Configuration table
- Remove `_summaryNotifications` entirely once chrome no longer needs it

## Implementation Steps

1. **Normalize Settings label** — File: `frontend/lib/l10n/app_en.arb`
   - Change `commonTableSettingsActionLabel` value from `"Table settings"` to `"Settings"`.
   - Keep the key name (prompt.md cites this key).
   - Regenerate l10n (`flutter gen-l10n` or the repo’s usual generator) so `app_localizations*.dart` update.

2. **Add Billing Filters label** — File: `frontend/lib/l10n/app_en.arb`
   - Add `billingFiltersLabel`: `"Filters"` (mirror `hrFiltersLabel` / `roomsBedsFiltersLabel`).
   - Keep `billingFiltersTitle` for any non-button copy if still referenced elsewhere, but **table chrome must use `billingFiltersLabel`**.
   - Regenerate l10n.

3. **Replace AppWorkspace chrome with ResponsivePage + contextual AppTabStrip toolbar** — File: `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`
   - Remove `AppWorkspace(...)`, `appWorkspaceToolbarWithLabels(...)`, `leadingIcon`, and `_summaryNotifications`.
   - Build success UI like Reception/HR:
     - `ResponsivePage` → `Column` → `AppTabStrip` → spacing → failure (optional) → `_BillingQueuePanel`.
   - Implement `_buildPrimaryAction` / `_buildSecondaryActions` per Tab Configuration.
   - Wire `primaryAction:` / `secondaryActions:` on `AppTabStrip`.
   - Keep `_selectQueue` / `_updateUrlForQueue` / route-query application unchanged in behavior.
   - Keep `canWrite` gating on Close shift / Close day; disable while `state.isSaving` as today.
   - Import `AppTabToolbarPrimary` / `AppTabToolbarAction` from shared components (already via `components.dart`).

4. **Fix table Filters / Settings labels** — same page file (`_BillingQueuePanel`)
   - Set `advancedFilterButtonLabel: l10n.billingFiltersLabel` (**must render as “Filters”**).
   - Set `advancedFilterTitle: l10n.billingFiltersLabel` (or a short dialog title still reading “Filters”).
   - Keep `advancedFilterApplyLabel: l10n.opdApplyFiltersAction`, `advancedFilterResetLabel: l10n.billingClearFilters` (or clear-filters equivalent).
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` (now “Settings”).
   - Do **not** add Refresh / Close shift / Close day / summary chips into table `trailingActions`.

5. **Update tests** — File: `frontend/test/features/billing/presentation/billing_workspace_page_test.dart`
   - Assert `AppTabStrip` still present; tab labels/counts still work.
   - Assert URL `queue` updates on tab switch (existing tests).
   - Assert deep links still select correct queue (existing tests).
   - Add/adjust assertions that Close shift / Close day / Refresh appear via tab toolbar (find by l10n text), and that toolbar primary/secondary **changes** when switching e.g. All → Needs issue → Overdue (different primary labels per table above).
   - Assert Filters button text is `Filters` and Settings control uses `Settings`.
   - Assert `AppWorkspace` is **not** used on the success path (or at least no workspace summary notification chrome).
   - Preserve column-layout tests.

6. **Format / analyze / run tests** — see Verification Steps.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `components.dart`) | Tabs + contextual toolbar under tabs |
| `AppListTable` / `AppListTableSearch` / column visibility | `package:hosspi_hms/shared/components/app_list_table.dart` | Work-item table; Filters + Settings only in table chrome |
| `AppSearchBar` filter groups | `package:hosspi_hms/shared/components/app_search_bar.dart` | Existing billing advanced filters |
| `ResponsivePage` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `layout.dart`) | Headerless page shell |
| `AsyncStateScaffold` | shared components / layout exports already used by page | Loading/error shell |
| `AppFailureStateView` | shared | Last-failure banner |
| `AppAccessActionGate` (optional) | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate write actions if preferred over raw `canWrite` |
| `AppBreakpoints` | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Via `ResponsivePage` / theme spacing |

**Forbidden:** new custom tab bars, new header title widgets, new overflow “more” menus for screen actions, reintroducing `AppWorkspace` toolbar-above-tabs for Billing, duplicating filter/settings controls outside the table search chrome.

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` (+ regenerated `app_localizations*.dart`) |
| Modify | `frontend/test/features/billing/presentation/billing_workspace_page_test.dart` |
| Do not modify (unless shared Settings label requires regeneration only) | Reception / HR / `app_tab_strip.dart` / router registration |
| Do not delete | Billing dialogs, controller, entities, repository |

## Cleanup: Remove Stale Code

- [ ] Remove `AppWorkspace` wrapper and `appWorkspaceToolbarWithLabels` usage from Billing success chrome
- [ ] Remove `_summaryNotifications` and any unused `AppWorkspaceSummaryNotification` imports/usages on this page
- [ ] Remove unused imports: `AppRouteIcons` (if only used for workspace leading), `appWorkspaceToolbarWithLabels`-only symbols if nothing else needs them
- [ ] Ensure no dead references to workspace header title/leading on Billing page
- [ ] Do not leave duplicate Refresh / Close shift / Close day both above tabs and under tabs

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter presentation/chrome refactor only.

## Responsive Design Requirements

- Desktop (≥1024px): full `AppTabStrip` + toolbar row; table with all queue-specific columns; Filters + Settings in table search chrome.
- Tablet (600–1023px): horizontal scroll for tabs if needed (`AppTabStrip` already scrolls); toolbar wraps via `Wrap` inside strip; table remains primary body.
- Mobile (<600px): keep existing `mobileItemBuilder: _BillingMobileTile`; toolbar actions remain visible under tabs (wrap); no separate mobile title header.

Follow `ResponsivePage` / `PageMaxWidth.dataHeavy` and `theme.spacing.sm` rhythm already used by Reception.

## Verification Steps

Run from `frontend/`:

```bash
dart format .
dart analyze --fatal-infos
flutter test test/features/billing/
flutter test test/shared/
```

If l10n was changed:

```bash
flutter gen-l10n
```

(or the repository’s documented l10n generation command), then re-run format/analyze/tests.

## Testing Requirements

- [ ] Tab switch updates URL `queue` (omit for All) and swaps toolbar primary/secondary per Tab Configuration
- [ ] Deep link `/billing?queue=…` opens correct tab; `action=pay` still auto-opens payment when applicable
- [ ] Per-tab toolbar shows only that tab’s configured actions (no stale workspace summary chips)
- [ ] Table chrome has only Filters + Settings (plus search); labels are exactly **Filters** and **Settings**
- [ ] No screen title/header chrome remains (`AppWorkspace` header/toolbar-above-tabs gone)
- [ ] At least one toolbar button exists on every tab
- [ ] `billingWrite` still gates Close shift / Close day
- [ ] Responsive layouts still work; existing column + queue tests pass

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs (`primaryAction` / `secondaryActions`)
- [ ] No dedicated header; no stray actions; no header more-menu; no summary-notification toolbar
- [ ] Domain logic preserved (queues, filters, dialogs, payments, close shift/day, deep links, realtime refresh)
- [ ] Analyze clean; tests pass; stale chrome code removed
