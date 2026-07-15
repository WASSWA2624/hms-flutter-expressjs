# Standardize Claims Screen

## Objective

Refactor the Claims workspace to match the standardized tab-and-table layout established by the Reception workspace. The current implementation is a monolithic ~2175-line page that uses `AppWorkspace` with summary notification cards as navigation, a single flat `AppListTable`, and 7 secondary toolbar buttons for insurance catalog management. This refactor will introduce routable `AppTabStrip` tabs that group the claims workflow into logical stages (Authorizations, Active Claims, Settled, Insurance Setup), add `?section=` URL deep-linking per tab, provide tab-contextual primary action buttons, and per-tab column configurations — all while preserving the existing domain logic, detail dialog, form dialogs, realtime sync, and server-side pagination.

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

## Current State (from audit)

### Files in scope

| File | Purpose | Lines |
|------|---------|-------|
| `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart` | Main page widget + queue panel + detail dialog + 5 form dialogs + helpers | ~2175 |
| `frontend/lib/features/claims/presentation/controllers/claims_workspace_controller.dart` | AsyncNotifier state controller | ~516 |
| `frontend/lib/features/claims/domain/entities/claims_entities.dart` | Domain value objects, query, filter enum, state | ~641 |
| `frontend/lib/features/claims/domain/repositories/claims_repository.dart` | Abstract repository interface | ~49 |
| `frontend/lib/features/claims/data/repositories/claims_repository_impl.dart` | Repository implementation (API calls) | ~331 |
| `frontend/lib/features/claims/data/dtos/claims_dtos.dart` | JSON DTO classes | ~470 |
| `frontend/lib/features/claims/presentation/widgets/claims_insurance_config_dialogs.dart` | Insurance catalog CRUD dialogs | ~1275 |
| `frontend/lib/features/claims/presentation/widgets/insurance_authorization_panel.dart` | Reusable auth panel (used by IPD) | ~205 |
| `frontend/lib/features/claims/data/repositories/insurance_catalog_repository.dart` | Insurance catalog CRUD client | ~226 |

### Route definition

```dart
// frontend/lib/app/router/app_routes.dart (lines 287-298)
static const AppRouteData claims = AppRouteData(
  name: 'claims',
  path: '/claims',
  access: AppRouteAccess.authenticated,
  requiredAnyPermissions: <AppPermission>[
    AppPermissions.billingRead,
    AppPermissions.billingWrite,
    AppPermissions.financialApprove,
  ],
  requiredAnyRoles: billingWorkspaceRoles,
  requiredActiveModules: <String>['insurance-claims'],
);
```

```dart
// frontend/lib/app/router/app_router.dart (lines 155-162)
GoRoute(
  path: AppRoutes.claims.path,
  name: AppRoutes.claims.name,
  builder: (_, GoRouterState state) {
    return ClaimsWorkspacePage(
      initialQuery: ClaimsWorkspaceQuery.fromUri(state.uri),
    );
  },
),
```

### Current problems / inconsistencies

- **No routable tabs**: Navigation uses 11 `AppWorkspaceSummaryNotification` cards in the toolbar as quick-filter buttons. There is no `AppTabStrip`.
- **No `?section=` URL sync**: `ClaimsWorkspaceQuery` supports `encounterId`, `patientId`, `action`, `search` but has no `section` parameter. Deep-linking to a specific tab is impossible.
- **Monolithic page file**: The single page file contains the page widget, queue panel, detail content, 5 private form dialog widgets, and 30+ helper functions — all in one 2175-line file.
- **7 secondary toolbar buttons**: Insurance catalog management actions (Add Company, Add Scheme, Add Offer, Add Enrollment, Add Price Book, Add Insurer Integration) crowd the toolbar alongside the primary "Request Authorization" button.
- **Fixed table height**: The queue panel uses `SizedBox(height: 520)` around `AppListTable`, which is rigid and does not respond to viewport.
- **Single column set for all items**: The same 6 columns (Type, Reference, Coverage, Invoice, Status, Timeline) are used regardless of whether the user is viewing authorizations or claims.
- **No per-section `columnVisibilityStorageKey`**: Column visibility preferences are not scoped per tab.
- **Uses `AppWorkspace`** as the outer shell, whereas the Reception reference builds a custom layout with `ResponsivePage` + `AppTabStrip` directly.

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

| File | What to extract |
|------|----------------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | Tab structure with `AppTabStrip` + `ReceptionDeskSection` enum, URL sync via `GoRouter.replace` with `?section=`, per-section column sets, single `AppListTable<_ReceptionDeskRow>` with section-scoped `columnVisibilityStorageKey`, `mobileItemBuilder`, `AppAccessActionGate` + `AppButton.primary` placement in `Row` alongside tab strip |
| `frontend/lib/features/reception/domain/entities/reception_entities.dart` | `ReceptionWorkspaceQuery` with `section` field, `ReceptionDeskSection` enum, `fromUri` factory parsing `?section=` |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabStrip` and `AppTabItem` API — constructor params: `tabs`, `selectedId`, `onTabTapped` |
| `frontend/lib/shared/layout/app_workspace.dart` | `AppWorkspace` widget (current shell — will be replaced with `ResponsivePage` + custom layout) |
| `frontend/lib/shared/layout/responsive_page.dart` | `ResponsivePage` widget — used by Reception as the outer responsive wrapper with `maxWidth: PageMaxWidth.dataHeavy` |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable<T>` — `columnVisibilityStorageKey`, `columnWidthStorageKey`, `search`, `mobileItemBuilder`, `emptyBuilder`, `page`, `onPageChanged` |
| `frontend/lib/core/responsive/app_breakpoints.dart` | `AppBreakpoints` — `of(context)`, `fromConstraints`, `isMobile` property |
| `frontend/lib/features/reception/presentation/reception_access.dart` | `AccessRequirement` constants pattern |

### Key patterns from Reception reference

**Tab strip + action button layout:**
```dart
Row(
  children: <Widget>[
    Expanded(
      child: AppTabStrip(
        tabs: <AppTabItem>[
          for (final SectionEnum section in SectionEnum.values)
            AppTabItem(
              id: section.name,
              icon: _sectionIcon(section),
              label: '${_sectionLabel(l10n, section)} (${_sectionCount(state, section)})',
            ),
        ],
        selectedId: _section.name,
        onTabTapped: (String tabId) {
          for (final SectionEnum section in SectionEnum.values) {
            if (section.name == tabId) {
              setState(() => _section = section);
              _updateUrlForSection(section);
              break;
            }
          }
        },
      ),
    ),
    AppAccessActionGate(
      requirement: writeRequirement,
      builder: (BuildContext context, bool isAllowed) {
        return AppButton.primary(
          label: _primaryActionLabel(l10n, _section),
          leadingIcon: _primaryActionIcon(_section),
          enabled: isAllowed,
          onPressed: isAllowed ? () => _primaryAction(_section) : null,
        );
      },
    ),
  ],
),
```

**URL sync per tab:**
```dart
void _updateUrlForSection(ClaimsDeskSection section) {
  if (!mounted) return;
  final String tab = _sectionToQueryValue(section);
  final String location = AppRoutes.claims.location(
    queryParameters: <String, String>{
      if (tab.isNotEmpty) 'section': tab,
    },
  );
  GoRouter.of(context).replace<void>(location);
}
```

**Per-section column sets and storage keys:**
```dart
AppListTable<RowType>(
  items: rows,
  columns: _columnsForSection(_section),
  columnVisibilityStorageKey: 'claims_${_section.name}',
  columnWidthStorageKey: 'claims_cw_${_section.name}',
  // ...
),
```

## Target Architecture

### Tab Configuration

| Tab Name | Enum Value | Route Query Value | Description | Primary Action Button |
|----------|-----------|-------------------|-------------|----------------------|
| Authorizations | `authorizations` | `?section=authorizations` | Pre-authorization requests in all statuses (PENDING, APPROVED, DENIED, EXPIRED) | "Request Authorization" → opens `_CoveragePlanDialog` |
| Active Claims | `activeClaims` | `?section=active-claims` | Insurance claims still in progress (SUBMITTED, APPROVED, PARTIAL, REJECTED) | "Prepare Claim" → opens `_PrepareClaimDialog` |
| Settled | `settled` | `?section=settled` | Resolved claims (PAID, CANCELLED) | None (no primary action) |
| Insurance Setup | `insuranceSetup` | `?section=insurance-setup` | Insurance company, scheme, offer, enrollment, price book, and integration management | "Add Company" → opens `openClaimsInsuranceCompanyDialog` |

### Section Enum

```dart
/// Desk sections for the Claims workspace tab strip.
enum ClaimsDeskSection {
  authorizations,
  activeClaims,
  settled,
  insuranceSetup,
}
```

### Routing

**File to modify:** `frontend/lib/features/claims/domain/entities/claims_entities.dart`

Add a `section` field to `ClaimsWorkspaceQuery`:
```dart
final class ClaimsWorkspaceQuery {
  const ClaimsWorkspaceQuery({
    this.encounterId = '',
    this.patientId = '',
    this.action = '',
    this.search = '',
    this.section = '',
  });

  factory ClaimsWorkspaceQuery.fromUri(Uri uri) {
    final Map<String, String> params = uri.queryParameters;
    String pick(List<String> keys) {
      for (final String key in keys) {
        final String value = (params[key] ?? '').trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }
    return ClaimsWorkspaceQuery(
      encounterId: pick(<String>['encounterId', 'encounter_id', 'encounter']),
      patientId: pick(<String>['patientId', 'patient_id', 'patient']),
      action: pick(<String>['action']),
      search: pick(<String>['search', 'q']),
      section: pick(<String>['section', 'panel', 'filter', 'tab']),
    );
  }

  final String encounterId;
  final String patientId;
  final String action;
  final String search;
  final String section;

  bool get hasRouteTargeting =>
      encounterId.isNotEmpty || patientId.isNotEmpty ||
      action.isNotEmpty || search.isNotEmpty;

  String get signature => '$encounterId|$patientId|$action|$search|$section';
}
```

Also add the `ClaimsDeskSection` enum and the query-to-section parsing helper to the same file:
```dart
enum ClaimsDeskSection {
  authorizations,
  activeClaims,
  settled,
  insuranceSetup,
}

ClaimsDeskSection claimsDeskSectionFromQuery(String value) {
  return switch (value) {
    'authorizations' => ClaimsDeskSection.authorizations,
    'active-claims' => ClaimsDeskSection.activeClaims,
    'settled' => ClaimsDeskSection.settled,
    'insurance-setup' => ClaimsDeskSection.insuranceSetup,
    _ => ClaimsDeskSection.authorizations,
  };
}

String claimsDeskSectionToQuery(ClaimsDeskSection section) {
  return switch (section) {
    ClaimsDeskSection.authorizations => 'authorizations',
    ClaimsDeskSection.activeClaims => 'active-claims',
    ClaimsDeskSection.settled => 'settled',
    ClaimsDeskSection.insuranceSetup => 'insurance-setup',
  };
}
```

**No changes needed to `app_router.dart` or `app_routes.dart`** — the route definition already passes the full URI to `ClaimsWorkspaceQuery.fromUri`, which will now parse `?section=`.

### Page Layout

Replace the `AppWorkspace` shell in `_ClaimsWorkspaceContent.build()` with a `ResponsivePage`-based layout matching the Reception pattern:

```
_ClaimsWorkspaceContent (ConsumerStatefulWidget)
├── owns: _section (ClaimsDeskSection), _searchController, _columnVisibilityController
└── build:
    └── ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)
        └── Column
            ├── Row  ← tab strip + primary action button
            │   ├── Expanded → AppTabStrip (4 tabs from ClaimsDeskSection)
            │   └── _primaryActionButton(l10n, _section, state, controller)
            ├── SizedBox(height: spacing.md)
            ├── _ClaimsSummaryBar (summary notification cards — condensed, only shown for authorizations & activeClaims tabs)
            ├── SizedBox(height: spacing.md)
            └── Expanded → _ClaimsQueuePanel (for authorizations/activeClaims/settled tabs)
                          OR _ClaimsInsuranceSetupPanel (for insuranceSetup tab)
```

The `_ClaimsSummaryBar` is a new small widget that wraps the relevant summary notification cards from the current toolbar into a horizontal scrollable `Wrap` placed below the tab strip. It only appears on the `authorizations` and `activeClaims` tabs. This preserves the quick-filter summary cards as supplementary navigation within each tab. On the `insuranceSetup` tab, display a management panel with action buttons for Add Company, Add Scheme, Add Offer, Add Enrollment, Add Price Book, and Add Insurer Integration.

### Data & State Management

**No changes needed to the controller** (`claims_workspace_controller.dart`). It already:
- Uses `AsyncNotifierProvider<ClaimsWorkspaceController, Result<ClaimsWorkspaceState>>`
- Supports `applyFilter(ClaimsQueueFilter)` for server-side filtering
- Supports `applySearch(String)` for search
- Supports `changePage(AppPageRequest)` for pagination
- Has realtime sync via `listenForRealtimeRefresh`

The tab switching will translate each `ClaimsDeskSection` to a `ClaimsQueueFilter` and call `controller.applyFilter(...)`:
```dart
ClaimsQueueFilter _defaultFilterForSection(ClaimsDeskSection section) {
  return switch (section) {
    ClaimsDeskSection.authorizations => ClaimsQueueFilter.authorizationPending,
    ClaimsDeskSection.activeClaims => ClaimsQueueFilter.claimSubmitted,
    ClaimsDeskSection.settled => ClaimsQueueFilter.claimPaid,
    ClaimsDeskSection.insuranceSetup => ClaimsQueueFilter.all,
  };
}
```

Within each tab, the advanced filter panel (already wired via `AppListTableSearch.filterGroups`) provides sub-status filtering. Scope the filter choices per tab:
- **Authorizations tab**: Show only authorization-related filters (Pending, Approved, Denied, Expired)
- **Active Claims tab**: Show only active claim filters (Submitted, Approved, Partial, Rejected)
- **Settled tab**: Show only settled filters (Paid, Cancelled)
- **Insurance Setup tab**: No filter panel (not a queue view)

### Per-Tab Column Configuration

**Authorizations tab columns:**

| Column | ID | Description |
|--------|----|-------------|
| Reference | `auth_reference` | Pre-authorization display ID |
| Patient | `auth_patient` | Patient display ID (if available) |
| Coverage Plan | `auth_coverage` | Coverage plan display ID |
| Status | `auth_status` | Status badge (PENDING/APPROVED/DENIED/EXPIRED) |
| Approved Amount | `auth_approved_amount` | Approved amount (currency formatted) |
| Requested At | `auth_requested_at` | Request timestamp |

**Active Claims tab columns:**

| Column | ID | Description |
|--------|----|-------------|
| Reference | `claim_reference` | Claim display ID |
| Patient | `claim_patient` | Patient display ID |
| Coverage Plan | `claim_coverage` | Coverage plan display ID |
| Invoice | `claim_invoice` | Invoice display ID |
| Claim Amount | `claim_amount` | Claim amount (currency formatted) |
| Status | `claim_status` | Status badge (SUBMITTED/APPROVED/PARTIAL/REJECTED) |
| Submitted At | `claim_submitted_at` | Submission timestamp |

**Settled tab columns:**

| Column | ID | Description |
|--------|----|-------------|
| Reference | `settled_reference` | Claim display ID |
| Patient | `settled_patient` | Patient display ID |
| Coverage Plan | `settled_coverage` | Coverage plan display ID |
| Invoice | `settled_invoice` | Invoice display ID |
| Claim Amount | `settled_claim_amount` | Claim amount |
| Settlement Amount | `settled_settlement_amount` | Settlement amount |
| Status | `settled_status` | Status badge (PAID/CANCELLED) |
| Timeline | `settled_timeline` | Resolution timestamp |

## Implementation Steps

### 1. **Add `ClaimsDeskSection` enum and update `ClaimsWorkspaceQuery`** — File: `frontend/lib/features/claims/domain/entities/claims_entities.dart`

- Add the `ClaimsDeskSection` enum with values: `authorizations`, `activeClaims`, `settled`, `insuranceSetup`.
- Add `claimsDeskSectionFromQuery(String)` and `claimsDeskSectionToQuery(ClaimsDeskSection)` helper functions.
- Add `section` field to `ClaimsWorkspaceQuery`.
- Update `ClaimsWorkspaceQuery.fromUri` to parse `section` from query parameters (aliases: `section`, `panel`, `filter`, `tab`).
- Update `signature` getter to include `section`.

### 2. **Create `claims_access.dart`** — File: `frontend/lib/features/claims/presentation/claims_access.dart`

- Define `AccessRequirement` constants for the claims workspace, following the pattern in `frontend/lib/features/reception/presentation/reception_access.dart`.
- Define `claimsWorkspaceWriteRequirement` gating `AppPermissions.billingWrite`.
- Define `claimsFinancialApproveRequirement` gating `AppPermissions.financialApprove`.

### 3. **Refactor `claims_workspace_page.dart`** — File: `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart`

This is the main change. Restructure the page to follow the Reception pattern:

**3a. Keep `ClaimsWorkspacePage` (outer `ConsumerWidget`) unchanged** — it already correctly watches `claimsWorkspaceControllerProvider` and renders `AsyncStateScaffold`.

**3b. Refactor `_ClaimsWorkspaceContent`** to:
- Add `ClaimsDeskSection _section` state field, initialized from `widget.initialQuery?.section` via `claimsDeskSectionFromQuery`.
- Add `_updateUrlForSection(ClaimsDeskSection)` method that calls `GoRouter.of(context).replace<void>(location)` with `?section=` query param (exact pattern from Reception).
- Replace the `AppWorkspace(...)` return value with `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` containing a `Column`:
  - **Row 1**: `Expanded(child: AppTabStrip(...))` + primary action button wrapped in `AppAccessActionGate`.
  - **Row 2** (conditional): `_ClaimsSummaryBar` — only for `authorizations` and `activeClaims` tabs.
  - **Row 3**: `Expanded` containing either `_ClaimsQueuePanel` or `_ClaimsInsuranceSetupPanel` based on `_section`.
- Apply `controller.applyFilter(...)` on tab change with the appropriate default filter.
- On `initState`, if `widget.initialQuery?.section` is non-empty, set `_section` from it.

**3c. Make the primary action button tab-contextual:**
```dart
Widget _primaryActionButton(
  AppLocalizations l10n,
  ClaimsDeskSection section,
  ClaimsWorkspaceState state,
  ClaimsWorkspaceController controller,
) {
  return switch (section) {
    ClaimsDeskSection.authorizations => AppButton.primary(
        label: l10n.claimsRequestAuthorizationAction,
        leadingIcon: Icons.verified_user_outlined,
        isLoading: state.isSaving,
        onPressed: () => unawaited(
          _openRequestAuthorizationDialog(context, controller, state),
        ),
      ),
    ClaimsDeskSection.activeClaims => AppButton.primary(
        label: l10n.claimsPrepareClaimAction,
        leadingIcon: Icons.receipt_long_outlined,
        isLoading: state.isSaving,
        onPressed: () => unawaited(
          _openPrepareClaimDialog(context, controller, state),
        ),
      ),
    ClaimsDeskSection.settled => const SizedBox.shrink(),
    ClaimsDeskSection.insuranceSetup => AppButton.primary(
        label: l10n.claimsAddCompanyAction,
        leadingIcon: Icons.business_outlined,
        onPressed: () => unawaited(
          openClaimsInsuranceCompanyDialog(
            context: context, ref: ref,
            referenceData: state.referenceData,
          ),
        ),
      ),
  };
}
```

**3d. Add tab icons:**
```dart
static IconData _sectionIcon(ClaimsDeskSection section) {
  return switch (section) {
    ClaimsDeskSection.authorizations => Icons.verified_user_outlined,
    ClaimsDeskSection.activeClaims => Icons.receipt_long_outlined,
    ClaimsDeskSection.settled => Icons.task_alt_outlined,
    ClaimsDeskSection.insuranceSetup => Icons.business_outlined,
  };
}
```

**3e. Add tab labels with counts:**
```dart
String _sectionLabel(AppLocalizations l10n, ClaimsDeskSection section) {
  return switch (section) {
    ClaimsDeskSection.authorizations => l10n.claimsAuthorizationTypeLabel,
    ClaimsDeskSection.activeClaims => l10n.claimsClaimTypeLabel,
    ClaimsDeskSection.settled => l10n.claimsFilterClaimPaid, // "Settled"
    ClaimsDeskSection.insuranceSetup => l10n.claimsAddCompanyAction, // "Insurance Setup" — add new l10n key if needed
  };
}

int _sectionCount(ClaimsWorkspaceState state, ClaimsDeskSection section) {
  return switch (section) {
    ClaimsDeskSection.authorizations =>
      state.authorizationPendingCount + state.authorizationApprovedCount,
    ClaimsDeskSection.activeClaims =>
      state.submittedClaimsCount + state.approvedClaimsCount +
      state.partialClaimsCount + state.rejectedResubmissionCount,
    ClaimsDeskSection.settled => state.paidClosedCount,
    ClaimsDeskSection.insuranceSetup => 0,
  };
}
```

**3f. Update `_ClaimsQueuePanel`** to:
- Accept `ClaimsDeskSection section` as a constructor parameter.
- Use per-section column sets (see Per-Tab Column Configuration above).
- Use `columnVisibilityStorageKey: 'claims_${section.name}'`.
- Use `columnWidthStorageKey: 'claims_cw_${section.name}'`.
- Scope the `filterGroups` choices to only show relevant status filters for the current section.
- Remove the hardcoded `SizedBox(height: 520)` wrapper — let the table fill the available space via `Expanded` in the parent.

**3g. Create `_ClaimsInsuranceSetupPanel`** — a new private widget for the Insurance Setup tab. This panel displays the secondary action buttons (Add Scheme, Add Offer, Add Enrollment, Add Price Book, Add Insurer Integration) in a clean grid/list layout using `AppActionPanel` or a `Wrap` of `AppButton.secondary` widgets. This replaces the 6 secondary buttons that were previously in the toolbar.

**3h. Create `_ClaimsSummaryBar`** — a new private widget that renders the summary notification cards in a horizontal `Wrap` below the tab strip. It receives the `ClaimsWorkspaceState` and the current `ClaimsDeskSection` and only shows cards relevant to the current tab:
- **Authorizations tab**: Authorization Pending, Authorization Approved, Authorization Denied, Authorization Expired counts.
- **Active Claims tab**: Claims Submitted, Claims Approved, Claims Partial, Claims Rejected, Eligibility Pending, Claims To Submit, Ready To Settle counts.

Each card triggers `controller.applyFilter(...)` to narrow the in-tab filter.

**3i. Preserve all existing helper functions and private dialog classes** — `_CoveragePlanDialog`, `_PrepareClaimDialog`, `_AuthorizationStatusDialog`, `_ClaimSubmitDialog`, `_ClaimResponseDialog`, `_ClaimsDetailContent`, `_BillingImpactPanel`, `_RequiredDocumentsPanel`, `_TimelinePanel`, `_MobileQueueItem`, and all top-level helper functions (`_openClaimsDetailDialog`, `_openRequestAuthorizationDialog`, `_openPrepareClaimDialog`, `_openAuthorizationStatusDialog`, `_openSubmitClaimDialog`, `_openClaimResponseDialog`, `_detailActions`, `_statusFor`, `_statusLabel`, `_statusTone`, `_statusIcon`, `_kindLabel`, `_kindIcon`, `_claimsStatementHtml`, etc.). These contain domain logic that must be preserved as-is.

### 4. **Add imports** — File: `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart`

Add the following imports at the top of the file:
```dart
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/shared/components/app_tab_strip.dart';
```

Remove the import for `AppWorkspace`-related symbols if they are no longer used after the refactor. The `AppWorkspace` import comes through `package:hosspi_hms/shared/layout/layout.dart` which also exports `ResponsivePage`, so it may not need changing — just stop using `AppWorkspace` and `appWorkspaceToolbarWithLabels` in this file.

### 5. **Verify cross-module consumers are unaffected** — Files to check (READ ONLY):

These files import from the claims module. Verify they still compile after the entity changes:
- `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart` — uses `InsuranceAuthorizationPanel` (unchanged)
- `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart` — uses `InsuranceCatalogRepository` (unchanged)
- `frontend/lib/shared/opd_actions/opd_coverage_verification_panel.dart` — uses `claimsRepositoryProvider.loadReferenceData()` (unchanged)
- `frontend/lib/shared/components/opd_encounter_dialog.dart` — uses `InsuranceCatalogRepository` (unchanged)
- `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` — uses `InsuranceCatalogRepository` (unchanged)
- `frontend/lib/features/theater/presentation/widgets/theater_schedule_case_form.dart` — uses `InsuranceCatalogRepository` (unchanged)
- `frontend/lib/features/reception/presentation/widgets/reception_patient_actions.dart` — uses `claimsRepositoryProvider` (unchanged)
- `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart` — uses `claimsRepositoryProvider` (unchanged)
- `frontend/lib/shared/workflow_actions/workflow_action_registry.dart` — registers claims pre-auth workflow action (unchanged)

None of these should be affected because the refactor only adds new fields/types (additive) and restructures the presentation layer. No existing public API is removed.

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` | `package:hosspi_hms/shared/components/app_tab_strip.dart` | Tab strip widget for section navigation |
| `AppListTable<T>` | `package:hosspi_hms/shared/components/components.dart` | Data table — already used, add per-section column sets |
| `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Search integration — already used |
| `AppSearchBarFilterGroup` / `AppSearchBarFilterChoice` | `package:hosspi_hms/shared/components/components.dart` | Advanced filter panel — already used, scope per tab |
| `AsyncStateScaffold` | `package:hosspi_hms/shared/components/components.dart` | Async loading/error scaffold — already used |
| `ResponsivePage` | `package:hosspi_hms/shared/layout/layout.dart` | Responsive outer wrapper (replaces `AppWorkspace`) |
| `AppBreakpoints` | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Responsive breakpoint queries |
| `AppButton` | `package:hosspi_hms/shared/components/components.dart` | Primary/secondary buttons — already used |
| `AppAccessActionGate` | `package:hosspi_hms/shared/actions/actions.dart` | Permission gating for action buttons |
| `AppActionPanel` / `AppActionItem` | `package:hosspi_hms/shared/components/components.dart` | Grouped action buttons — already used in detail dialog |
| `AppPatientDetails` | `package:hosspi_hms/shared/components/components.dart` | Patient context header — already used |
| `AppWorkspaceSummaryNotification` | `package:hosspi_hms/shared/layout/layout.dart` | Summary notification cards — reuse for `_ClaimsSummaryBar` |
| `AppWorkspaceStatusBadge` | `package:hosspi_hms/shared/layout/layout.dart` | Status badges — already used |
| `AppTimeline` / `AppTimelineItem` | `package:hosspi_hms/shared/components/components.dart` | Activity timeline — already used |
| `AppDialog` / `showAppDialog` / `showAppWorkspaceActionDialog` | `package:hosspi_hms/shared/components/components.dart` | Modal dialogs — already used |
| `AppFormShell` / `AppFormActions` | `package:hosspi_hms/shared/forms/forms.dart` | Form wrapper — already used |
| `AppWorkspaceStatePanel` | `package:hosspi_hms/shared/layout/layout.dart` | Empty/validation state panels — already used |
| `AppInfoTileGrid` / `AppInfoTileData` | `package:hosspi_hms/shared/components/components.dart` | Info tile grid — already used |
| `AppWorkspaceDetailPanel` | `package:hosspi_hms/shared/layout/layout.dart` | Expandable detail sections — already used |

## Files to Create

| File Path | Purpose |
|-----------|---------|
| `frontend/lib/features/claims/presentation/claims_access.dart` | `AccessRequirement` constants for the claims module (`claimsWorkspaceWriteRequirement`, `claimsFinancialApproveRequirement`) |

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/claims/domain/entities/claims_entities.dart` | Add `ClaimsDeskSection` enum, `claimsDeskSectionFromQuery`/`claimsDeskSectionToQuery` helpers, add `section` field to `ClaimsWorkspaceQuery` |
| `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart` | Replace `AppWorkspace` with `ResponsivePage` + `AppTabStrip` layout, add tab state management, per-tab columns, URL sync, extract `_ClaimsSummaryBar` and `_ClaimsInsuranceSetupPanel` private widgets, remove hardcoded `SizedBox(height: 520)` |

## Files to Delete (if any)

No files need to be deleted. This refactor restructures existing code in place.

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove the `AppWorkspace` usage and `appWorkspaceToolbarWithLabels` call from `claims_workspace_page.dart` — replaced by `ResponsivePage` + `AppTabStrip`.
- [ ] Remove the 7 secondary `AppButton.secondary` widgets from the toolbar section — moved to `_ClaimsInsuranceSetupPanel`.
- [ ] Remove unused imports across all modified files (e.g., `AppWorkspace`-related imports if no longer needed).
- [ ] Remove the `SizedBox(height: 520)` hardcoded height wrapper around the queue panel.
- [ ] Verify that `AppWorkspaceSummaryNotification` is still imported (needed for `_ClaimsSummaryBar`) but that the old toolbar integration code is removed.
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.
- [ ] Verify no test files reference deleted code — update or remove stale tests.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. This refactor only restructures the frontend presentation layer (page layout, tab navigation, URL routing). The existing `ClaimsQueueFilter` enum already maps to the backend `claims-workspace` aggregator's `kind` and `status` parameters, and no new backend queries or schema changes are needed.

## Responsive Design Requirements

- **Desktop (≥1024px):** Full `AppListTable` with all columns visible per tab. Tab strip and primary action button in a single `Row`. Summary bar displays as horizontal `Wrap` of notification cards. Insurance Setup panel shows action buttons in a multi-column grid.
- **Tablet (600–1023px):** `AppListTable` with some columns hidden by default (user can restore via column visibility settings). Tab strip wraps to multiple lines if needed (`AppTabStrip` uses `Wrap` internally). Summary bar wraps naturally. Insurance Setup panel uses 2-column grid.
- **Mobile (<600px):** `AppListTable` switches to `mobileItemBuilder` (already implemented as `_MobileQueueItem`). Tab strip wraps to multiple lines. Primary action button may move below the tab strip in a separate `Row` if space is tight (check `AppBreakpoints.of(context).isMobile`). Insurance Setup panel uses single-column layout.

Use `AppBreakpoints.of(context)` or `AppBreakpoints.fromConstraints(constraints)` from `frontend/lib/core/responsive/app_breakpoints.dart`. Use `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` as the outer wrapper (matches Reception reference).

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Format
dart format .

# Analyze
dart analyze --fatal-infos

# Run tests related to this screen
flutter test test/features/claims/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs updates the URL with `?section=` parameter
- [ ] Deep linking: navigating directly to `/claims?section=active-claims` renders the Active Claims tab
- [ ] Default tab: navigating to `/claims` without `?section=` defaults to the Authorizations tab
- [ ] Table data: each tab displays the correct filtered dataset (authorizations vs active claims vs settled)
- [ ] Per-tab columns: Authorizations tab shows authorization-specific columns, Active Claims tab shows claim-specific columns
- [ ] Search: typing in the search bar filters table rows (server-side via controller)
- [ ] Filter panel: filter button opens the filter UI with tab-scoped filter choices
- [ ] Primary action: button label and behavior change per tab (Request Authorization / Prepare Claim / hidden / Add Company)
- [ ] Insurance Setup tab: displays management action buttons, not a data table
- [ ] Summary bar: only appears on Authorizations and Active Claims tabs with correct counts
- [ ] Summary card click: clicking a summary card applies the corresponding sub-filter
- [ ] Responsive layout: widget tests verify mobile builder is used below 600px breakpoint
- [ ] Detail dialog: tapping a row still opens the detail dialog with correct content
- [ ] No regressions: existing functionality (pre-auth request, claim preparation, claim response, sync, print) still works
- [ ] Cross-module: `InsuranceAuthorizationPanel` still renders correctly in IPD workspace

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The screen uses `AppTabStrip` with 4 routable tabs (Authorizations, Active Claims, Settled, Insurance Setup)
- [ ] Each tab has its own URL via `?section=` that supports deep linking
- [ ] The primary action button is contextual per tab and positioned correctly (right of tab strip)
- [ ] The Authorizations and Active Claims tabs use `AppListTable` with tab-specific column sets and per-section `columnVisibilityStorageKey`
- [ ] The Settled tab shows resolved claims with settlement-specific columns
- [ ] The Insurance Setup tab displays insurance catalog management actions
- [ ] Summary notification cards appear below the tab strip (not in a toolbar) and only for Authorizations/Active Claims tabs
- [ ] The page uses `ResponsivePage` instead of `AppWorkspace` as the outer shell
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop
- [ ] All old toolbar integration code is removed — no stale code remains
- [ ] Domain-specific business logic (detail dialog, form dialogs, status helpers, print templates) is preserved unchanged
- [ ] The controller (`ClaimsWorkspaceController`) is not modified — all tab logic is in the presentation layer
- [ ] No database migrations required — schema unchanged
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
- [ ] Cross-module consumers of claims entities/repositories are unaffected
