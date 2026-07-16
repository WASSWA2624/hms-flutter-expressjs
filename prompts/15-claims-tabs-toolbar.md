# Standardize Claims Screen (Tabs & Toolbar)

## Objective

Refactor the Claims workspace (`/claims`, `ClaimsWorkspacePage`) so its chrome fully complies with `prompt.md`:
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

**Scope boundary:** Restructure Claims **screen chrome/layout only**. Do not rewrite queue detail
dialogs, authorization/claim mutation dialogs, insurance catalog forms, print/statement helpers,
or repository APIs unless required to keep chrome wiring compiling. Preserve permissions,
realtime refresh, section filters, pagination, summary chips, and deep links.

**Do not invent new tab/table/search/filter chrome.** Reuse the shared components listed below.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart`
  - Public widget: `ClaimsWorkspacePage` (`initialQuery: ClaimsWorkspaceQuery?`)
  - Content: `_ClaimsWorkspaceContent` / `_ClaimsWorkspaceContentState`
  - Queue body: `_ClaimsQueuePanel` → `AppListTable<ClaimsQueueItem>`
  - Setup body: `_ClaimsInsuranceSetupPanel` (non-table; catalog action buttons in body)
  - Summary chips: `_ClaimsSummaryBar` (Authorizations / Active Claims only)
  - Detail + mutation dialogs live in the same page file (`_openClaimsDetailDialog`,
    `_CoveragePlanDialog`, `_PrepareClaimDialog`, `_AuthorizationStatusDialog`,
    `_ClaimSubmitDialog`, `_ClaimResponseDialog`, etc.)
- Insurance catalog dialogs:
  `frontend/lib/features/claims/presentation/widgets/claims_insurance_config_dialogs.dart`
  - `openClaimsInsuranceCompanyDialog`
  - `openClaimsSchemeDialog`
  - `openClaimsSchemeOfferDialog`
  - `openClaimsEnrollmentDialog`
  - `openClaimsPriceBookEntryDialog`
  - `openClaimsInsurerIntegrationDialog`
- Controller: `frontend/lib/features/claims/presentation/controllers/claims_workspace_controller.dart`
  - Provider: `claimsWorkspaceControllerProvider`
  - Key methods already present: `refresh()`, `applySearch`, `applyFilter`, `changePage`,
    `selectItem`, `requestPreAuthorization`, `prepareClaim`, `submitClaim`, `reconcileClaim`,
    `syncClaimStatus`, `updateAuthorizationStatus`
- Domain: `frontend/lib/features/claims/domain/entities/claims_entities.dart`
  - `ClaimsWorkspaceQuery` (parses `section`/`panel`/`filter`/`tab`, `search`/`q`,
    `encounterId`, `patientId`, `action`)
  - `ClaimsDeskSection` enum: `authorizations`, `activeClaims`, `settled`, `insuranceSetup`
  - Helpers: `claimsDeskSectionFromQuery`, `claimsDeskSectionToQuery`
- Access: `frontend/lib/features/claims/presentation/claims_access.dart`
  - Write gate: `claimsWorkspaceWriteRequirement` (`billingWrite` + module `insurance-claims`)
  - Financial gate: `claimsFinancialApproveRequirement` (detail/settlement — keep in detail dialogs)
- Route: `AppRoutes.claims` path `/claims` in `frontend/lib/app/router/app_routes.dart`
- Router builder: `frontend/lib/app/router/app_router.dart` passes
  `ClaimsWorkspaceQuery.fromUri(state.uri)` into `ClaimsWorkspacePage`
- Tests today:
  - `frontend/test/features/claims/presentation/claims_workspace_page_test.dart` (tabs, URL,
    deep link, Insurance Setup body actions, summary bar, filter button labeled **Queue**)
  - `frontend/test/features/claims/domain/claims_entities_test.dart`
  - `frontend/test/features/claims/presentation/claims_access_test.dart`
  - `frontend/test/features/claims/presentation/claims_workspace_controller_test.dart`
  - `frontend/test/features/claims/data/claims_dtos_test.dart`

### Current widget tree (chrome)

1. `AsyncStateScaffold<ClaimsWorkspaceState>` (loading only — `loadingTitle` /
   `loadingBody`; **not** a persistent screen title bar)
2. `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy, scrollable: false)`
3. `Column` → `AppTabStrip` → `SizedBox(height: theme.spacing.sm)` → optional
   `_ClaimsSummaryBar` → body (`_ClaimsQueuePanel` or `_ClaimsInsuranceSetupPanel`)
4. **No** `AppWorkspace` title/header today (already compliant on dedicated title chrome)
5. **No** FAB / `PopupMenuButton` / overflow “more” menu on the page chrome today

### Tabs (validated against code)

Enum: `ClaimsDeskSection` in `claims_entities.dart`.
Tab ids in `AppTabStrip` use `section.name` (`authorizations`, `activeClaims`, `settled`,
`insuranceSetup`).

| # | Tab label (l10n → English) | Enum | Query `?section=` written by `_updateUrlForSection` | Count source |
|---|----------------------------|------|------------------------------------------------------|--------------|
| 1 | `claimsSectionAuthorizations` → **Authorizations** | `authorizations` | `authorizations` | `authorizationPendingCount + authorizationApprovedCount` |
| 2 | `claimsSectionActiveClaims` → **Active Claims** | `activeClaims` | `active-claims` | submitted + approved + partial + rejected counts |
| 3 | `claimsSectionSettled` → **Settled** | `settled` | `settled` | `paidClosedCount` |
| 4 | `claimsSectionInsuranceSetup` → **Insurance Setup** | `insuranceSetup` | `insurance-setup` | `0` (no badge count) |

Deep-link tab state **is already URL-backed** via `?section=…` and
`GoRouter.replace` in `_updateUrlForSection`. Keep this; do not invent a second query key.
Canonical write values must remain: `authorizations` | `active-claims` | `settled` | `insurance-setup`.
`ClaimsWorkspaceQuery.fromUri` already accepts aliases for the section key itself (`panel`,
`filter`, `tab`). Optionally harden `claimsDeskSectionFromQuery` to be case-insensitive and
accept underscore aliases (`active_claims`, `insurance_setup`) matching Reception’s pattern —
recommended but not required if tests already cover the canonical kebab values.

Additional deep-link behaviors to **preserve**:
- `search` / `q` → apply search
- `encounterId` / `patientId` → open matching queue detail dialog
- `action=preauth` → open request-authorization dialog

### Current toolbar (gaps)

`primaryAction` via `_buildPrimaryActionButton` (gated by `AppAccessActionGate` +
`claimsWorkspaceWriteRequirement`):

| Tab | Current primary | Notes |
|-----|-----------------|-------|
| Authorizations | `claimsRequestAuthorizationAction` (“Request authorization”) → `_openRequestAuthorizationDialog` | OK as primary |
| Active Claims | `claimsPrepareClaimAction` (“Prepare claim”) → `_openPrepareClaimDialog` | OK as primary |
| Settled | **`null`** (early return) | **Violates** “every screen must have ≥1 toolbar button” when Settled is active with no secondaries |
| Insurance Setup | `claimsAddCompanyAction` (“Add company”) → `openClaimsInsuranceCompanyDialog` | Primary OK, but other setup actions are **not** in toolbar |

- `secondaryActions`: **not passed** (empty / omitted).
- Toolbar is partially contextual (primary switches) but Settled is actionless and Insurance Setup
  secondaries live in the panel body instead of the tab toolbar.

### Current table / body chrome (gaps)

In `_ClaimsQueuePanel` (`AppListTable<ClaimsQueueItem>`):

- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` — shared key used by
  Reception/HR (English today: **“Table settings”**). **Keep this shared key** for
  cross-workspace consistency; do not invent a parallel Settings control on Claims alone.
- Filters: `showAdvancedFilterButton: true` with
  `advancedFilterButtonLabel: l10n.claimsQueueFilterLabel` ❌ English is **“Queue”** —
  must become the standardized label **“Filters”**.
- Search: keep `claimsSearchSemanticLabel` / `claimsSearchHint`.
- Filter groups / apply / reset / section-specific choices: keep behavior; only rename the
  **button** label to Filters.
- Existing test taps `find.textContaining('Queue')` — update that test to look for **Filters**.

In `_ClaimsInsuranceSetupPanel`:

- Dedicated in-panel title: `Text(l10n.claimsSectionInsuranceSetup)` + description — the title
  duplicates the tab label and reads as a mini screen header. **Remove the title `Text`**;
  keep a short description (or empty-state body) without acting as a page header.
- Action `Wrap` of six `AppButton.secondary` widgets (Add company / Add scheme / Add offer /
  Enroll patient / Add price / Insurer API) — these are **stray screen actions outside the
  tab toolbar**. Move them into `AppTabStrip` toolbar (primary + secondaries). After move,
  the panel should show setup guidance / empty content only (no action button row).

### Summary bar (preserve — not title chrome)

`_ClaimsSummaryBar` on Authorizations / Active Claims is a **status filter chip strip**, not a
dedicated screen title/header. Keep it between `AppTabStrip` and the table. Do **not** move
summary chips into the tab toolbar.

### Detail-dialog actions (preserve — not screen chrome)

Keep inside detail dialogs / `AppActionPanel` (do **not** promote to tab toolbar):
- Update authorization status, Submit/Resubmit claim, Record response, Sync claim status,
  Close claim, Print statement.

### Concrete `prompt.md` gaps to close

1. **Settled tab has no toolbar button** (`primaryAction: null`, no secondaries) — add at least
   **Refresh** (`commonRefreshActionLabel` → `claimsWorkspaceControllerProvider.notifier.refresh()`).
2. **Insurance Setup catalog actions live in the panel body** — relocate all six into the
   contextual tab toolbar; remove the body action `Wrap`.
3. **Insurance Setup panel still shows a section title** — remove title text; no dedicated header.
4. **Table Filters label is “Queue”** — must be **“Filters”** via a Claims (or shared) l10n key
   whose English value is exactly `Filters` (e.g. add `claimsFiltersLabel: "Filters"` and use it
   for `advancedFilterButtonLabel` / `advancedFilterTitle`; keep filter-group label for the
   queue status group if desired, or also use Filters for consistency).
5. **Guarantee ≥1 toolbar button on every tab** after contextualization.
6. Keep no dedicated title header; do not introduce `AppWorkspace(showHeader: true)`.
7. No screen-level more-menu exists today — do not create one; all actions stay visible toolbar buttons.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  — `ResponsivePage` + `AppTabStrip` + `SizedBox(height: theme.spacing.sm)` + table;
  no page title header; URL-backed `section` query
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`
  — **copy this pattern** for per-tab `primaryAction` + `secondaryActions` and table Filters
  labeled with `*FiltersLabel` = `"Filters"`
- `frontend/lib/shared/components/app_tab_strip.dart`
  — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `AppWorkspace` / `showHeader` (default `false`);
  Claims should continue **without** a titled workspace header (prefer `ResponsivePage` like Reception)
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — reference only
- `frontend/lib/shared/layout/responsive_page.dart`
- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableSearch`, Settings
- `frontend/lib/shared/components/app_search_bar.dart` — Filters via `showAdvancedFilterButton` /
  `advancedFilterButtonLabel` / `filterGroups`
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`
- `frontend/lib/core/responsive/app_breakpoints.dart` — breakpoint tokens

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| Authorizations | `/claims?section=authorizations` | Pre-auth queue (default filter `authorizationPending`) | **Request authorization** — `AppTabToolbarPrimary` + `AppAccessActionGate(claimsWorkspaceWriteRequirement)` → `_openRequestAuthorizationDialog` (`claimsRequestAuthorizationAction`, icon `Icons.verified_user_outlined`) | **Refresh** — `AppTabToolbarAction` (`commonRefreshActionLabel`, `Icons.refresh`) → `controller.refresh()` |
| Active Claims | `/claims?section=active-claims` | In-flight claims (default filter `claimSubmitted`) | **Prepare claim** — `AppTabToolbarPrimary` + write gate → `_openPrepareClaimDialog` (`claimsPrepareClaimAction`, icon `Icons.receipt_long_outlined`) | **Refresh** |
| Settled | `/claims?section=settled` | Paid/closed claims (default filter `claimPaid`) | **Refresh** — `AppTabToolbarPrimary` (`commonRefreshActionLabel`, icon `Icons.refresh`) → `controller.refresh()` (no write primary on this read-mostly tab) | *(none required)* — Refresh alone satisfies ≥1 button. Optional: omit secondaries. |
| Insurance Setup | `/claims?section=insurance-setup` | Insurance catalog configuration (non-table panel) | **Add company** — `AppTabToolbarPrimary` + write gate → `openClaimsInsuranceCompanyDialog` (`claimsAddCompanyAction`, icon `Icons.business_outlined`) | All remaining catalog actions as `AppTabToolbarAction`s, each gated by the same write requirement: **Add scheme** (`claimsAddSchemeAction` → `openClaimsSchemeDialog`), **Add offer** (`claimsAddOfferAction` → `openClaimsSchemeOfferDialog`), **Enroll patient** (`claimsAddEnrollmentAction` → `openClaimsEnrollmentDialog`), **Add price** (`claimsAddPriceBookAction` → `openClaimsPriceBookEntryDialog`), **Insurer API** (`claimsAddInsurerIntegrationAction` → `openClaimsInsurerIntegrationDialog`). Optionally also **Refresh**. |

Notes:

- Use `AppTabToolbarPrimary` for the single right-aligned primary CTA and `AppTabToolbarAction`
  for left-cluster secondaries (matches `AppTabStrip` contract).
- Rebuild toolbar on tab change (`setState` already updates `_section`).
- Disable mutation primaries when `state.isSaving` (already done for Request / Prepare).
- **Never** leave both `primaryAction == null` and empty `secondaryActions` on any tab.
- Do **not** put detail-scoped claim/auth actions into the tab toolbar.
- Keep `_ClaimsSummaryBar` in the body for Authorizations / Active Claims only.

### Routing

- Keep `/claims` registration in `app_router.dart` unchanged.
- Keep query key **`section`** (written by `_updateUrlForSection` / parsed by
  `ClaimsWorkspaceQuery.fromUri`).
- Canonical write values must remain:
  `authorizations` | `active-claims` | `settled` | `insurance-setup`
- On tab tap: keep `setState` + `_updateUrlForSection(section)` +
  `controller.applyFilter(_defaultFilterForSection(section))`.
- On deep link: keep `_applyRouteQuery` (section, search, encounter/patient detail open,
  `action=preauth`).
- When writing URL on tab change, today’s helper only writes `section` — **preserve that
  existing behavior** (do not expand URL sync scope in this chrome pass).

### Page Layout

Precise widget tree for `_ClaimsWorkspaceContentState.build`:

1. Keep `AsyncStateScaffold` + `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy, scrollable: false)`
   (equivalent to “no title header”; do **not** add `AppWorkspace(showHeader: true)`).
2. `AppTabStrip(tabs:, selectedId: _section.name, onTabTapped:, primaryAction: <per-tab>, secondaryActions: <per-tab>)`.
3. `SizedBox(height: theme.spacing.sm)` (keep existing vertical rhythm).
4. Optional `_ClaimsSummaryBar` when section is Authorizations or Active Claims.
5. Body:
   - Queue tabs → `_ClaimsQueuePanel` / `AppListTable` with **only** Filters + Settings in table chrome
   - Insurance Setup → `_ClaimsInsuranceSetupPanel` **without** action button Wrap and **without**
     section title `Text` (description-only or empty guidance is fine)
6. No FAB / floating header actions / overflow more-menu for screen actions

### Data & State Management

- Reuse `claimsWorkspaceControllerProvider` / `ClaimsWorkspaceController` — **no new providers**.
- Keep local `_section`, `_searchController`, `_tableColumnController`, route-query application.
- Keep `ClaimsQueueFilter` defaults per section via `_defaultFilterForSection`.
- Keep permission gates: `claimsWorkspaceWriteRequirement` for toolbar mutations;
  `claimsFinancialApproveRequirement` remains for detail-level financial actions if used.
- Dialog openers in `claims_insurance_config_dialogs.dart` stay; only **call sites** move from
  panel body into toolbar builders.

## Implementation Steps

1. **Add Filters l10n key** — File: `frontend/lib/l10n/app_en.arb` (and regenerate / sync other
   locale files per project convention)
   - Add `claimsFiltersLabel` with English value exactly **`Filters`** (and `@claimsFiltersLabel`
     description).
   - Do **not** change domain filter-choice labels (`claimsFilterAuthorizationPending`, etc.).

2. **Make toolbar fully contextual** — File:
   `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart`
   - Extend `_buildPrimaryActionButton` per Target Architecture (Settled → Refresh primary;
     other tabs unchanged primaries).
   - Add `_buildSecondaryActions(...)` returning `List<Widget>` of `AppTabToolbarAction`s
     switching on `_section`.
   - Wire `AppTabStrip(primaryAction:, secondaryActions:)`.
   - For Refresh: call `ref.read(claimsWorkspaceControllerProvider.notifier).refresh()` and
     surface failures with existing `_showFailureIfNeeded` if the Future returns `AppFailure?`.

3. **Relocate Insurance Setup actions into the toolbar** — same page file + keep dialog helpers
   - Move the six catalog actions into primary/secondaries as specified.
   - Strip `_ClaimsInsuranceSetupPanel` of the `Wrap` of `AppButton.secondary` and of the
     title `Text(l10n.claimsSectionInsuranceSetup)`.
   - Keep `claimsInsuranceSetupDescription` (or equivalent guidance) as non-header body copy.

4. **Fix table Filters label** — `_ClaimsQueuePanel`
   - Set `advancedFilterButtonLabel` and `advancedFilterTitle` to `l10n.claimsFiltersLabel`
     (**Filters**).
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel`.
   - Keep search, filter groups, pagination, row → detail dialog behavior.
   - Do not add Refresh / Request authorization / Prepare claim into table trailing actions.

5. **Optional query alias hardening** — File:
   `frontend/lib/features/claims/domain/entities/claims_entities.dart`
   - If you touch `claimsDeskSectionFromQuery`, normalize with `trim().toLowerCase()` and accept
     `active_claims` / `insurance_setup` aliases; update `claims_entities_test.dart` accordingly.
   - Do not change canonical `claimsDeskSectionToQuery` write values.

6. **Update tests** — File:
   `frontend/test/features/claims/presentation/claims_workspace_page_test.dart`
   - Settled tab: expect a Refresh toolbar affordance (`find.byTooltip('Refresh')` or
     `find.textContaining('Refresh')` within `AppTabStrip`).
   - Insurance Setup: actions must still be findable (now in toolbar under `AppTabStrip`), and
     body must **not** rely on the old in-panel button Wrap; table still absent.
   - Replace filter button finder `Queue` → **Filters**.
   - Keep existing deep-link / section URL / summary-bar tests green; adjust only where labels
     or action locations changed.

7. **Format, analyze, run Claims + shared tests** (see Verification Steps).

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `shared/components/components.dart`) | Tabs + contextual toolbar under tabs |
| `AppListTable` / `AppListTableSearch` / column visibility | `package:hosspi_hms/shared/components/app_list_table.dart` | Queue tables; Filters + Settings only in table chrome |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `shared/layout/layout.dart`) | Page shell without title header |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate write toolbar actions with `claimsWorkspaceWriteRequirement` |
| `AsyncStateScaffold` | shared layout/components (already used) | Loading / error / data shell |
| Breakpoints | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Follow existing ResponsivePage behavior |

**Forbidden:** new custom tab bars, new header widgets, FAB for screen actions, PopupMenu /
“more” overflow for screen/header actions, duplicate Filters/Settings implementations.

## Files to Create / Modify / Delete

### Modify

| File | Change |
|------|--------|
| `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart` | Contextual `primaryAction` / `secondaryActions`; Settled Refresh; relocate Insurance Setup actions; remove panel title + body action Wrap; Filters label |
| `frontend/lib/l10n/app_en.arb` (+ generated/synced locale outputs per repo practice) | Add `claimsFiltersLabel` = `"Filters"` |
| `frontend/test/features/claims/presentation/claims_workspace_page_test.dart` | Assert new toolbar/Filters locations; Settled Refresh; Insurance Setup toolbar |
| `frontend/lib/features/claims/domain/entities/claims_entities.dart` | Optional case-insensitive / alias hardening for `claimsDeskSectionFromQuery` |
| `frontend/test/features/claims/domain/claims_entities_test.dart` | Only if query helper aliases change |

### Do not delete

- `claims_insurance_config_dialogs.dart` (dialogs stay; call sites move)
- Detail/mutation dialog private widgets in the page file
- Controller / repository / DTO layers

### Create

- None required (unless you extract a tiny pure helper for toolbar action ids — optional)

## Cleanup: Remove Stale Code

- [ ] Remove Insurance Setup body `Wrap` of `AppButton.secondary` catalog actions after toolbar relocation
- [ ] Remove Insurance Setup panel title `Text(l10n.claimsSectionInsuranceSetup)` (tab already labels the section)
- [ ] Remove Settled early-return that forces `primaryAction: null` without a replacement action
- [ ] Stop using `claimsQueueFilterLabel` (“Queue”) as the table Filters **button** label
- [ ] Do not leave unused private helpers that only served the old panel button row
- [ ] Ensure no duplicate Add company (toolbar + panel)
- [ ] Do not introduce a screen-level more-menu

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter UI chrome refactor only.

## Responsive Design Requirements

- Desktop (≥1024px): full `AppTabStrip` + toolbar labels; queue `AppListTable` desktop columns.
- Tablet (600–1023px): horizontal scroll on tab chips (already in `AppTabStrip`); toolbar `Wrap`
  may wrap secondary actions; keep Filters + Settings in table search chrome.
- Mobile (<600px): keep `mobileItemBuilder: _MobileQueueItem`; toolbar actions remain visible
  (compact `AppTabToolbarPrimary` / `AppTabToolbarAction`); no separate mobile title header.
- Continue using `ResponsivePage` + `PageMaxWidth.dataHeavy`; do not add a titled app bar.

## Verification Steps

From `frontend/`:

```bash
dart format .
dart analyze --fatal-infos
flutter test test/features/claims/
flutter test test/shared/
```

If l10n codegen is required after arb edits, run the project’s usual localization generation
command before analyze/tests.

## Testing Requirements

- [ ] Tab switch updates URL `section` and toolbar actions
- [ ] Deep link `/claims?section=active-claims` (and other canonical values) opens correct tab
- [ ] Per-tab toolbar shows only that tab’s actions (Authorizations Request; Active Prepare;
      Settled Refresh; Insurance Setup Add company + catalog secondaries)
- [ ] Table chrome has only Filters and Settings (plus search) — no Request/Prepare/Refresh in table trailing
- [ ] Filters button label is exactly **Filters** (not Queue)
- [ ] No screen title/header chrome remains (including Insurance Setup panel title)
- [ ] At least one toolbar button exists on every tab, including Settled
- [ ] Permissions still gate write actions via `AppAccessActionGate` + `claimsWorkspaceWriteRequirement`
- [ ] Summary bar still appears only on Authorizations / Active Claims and still applies filters
- [ ] Detail dialog actions still work and remain outside the tab toolbar
- [ ] Responsive layouts still work
- [ ] Existing Claims widget/controller/entity tests updated and passing

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs (`primaryAction` / `secondaryActions`)
- [ ] No dedicated header; no stray Insurance Setup body actions; no header more-menu
- [ ] Domain logic preserved (queue filters, deep links, dialogs, permissions, realtime refresh)
- [ ] Analyze clean; tests pass; stale panel action chrome removed
