# Standardize Physiotherapy Screen

## Objective

Refactor the Physiotherapy workspace to match the standardized tab-and-table layout used by the Reception workspace. Replace the current summary-notification-chip scope navigation with a proper `AppTabStrip` tab bar, add URL-based section sync via query parameters, restructure the primary action button placement to be inline with the tab strip, and ensure the page layout, responsive behavior, and component usage are consistent with the Reception reference. All domain-specific business logic (controller, repository, entities, DTOs, dialogs, printing) must be preserved — only the UI scaffold and navigation layer changes.

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

## Current State (from audit)

### Core Files

- **Page:** `frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart` (~2142 lines)
- **Controller:** `frontend/lib/features/physiotherapy/presentation/controllers/physiotherapy_workspace_controller.dart` (~545 lines)
- **Entities:** `frontend/lib/features/physiotherapy/domain/entities/physiotherapy_entities.dart` (~714 lines)
- **Repository interface:** `frontend/lib/features/physiotherapy/domain/repositories/physiotherapy_repository.dart`
- **Repository impl:** `frontend/lib/features/physiotherapy/data/repositories/physiotherapy_repository_impl.dart`
- **DTOs:** `frontend/lib/features/physiotherapy/data/dtos/physiotherapy_dtos.dart`
- **Unit tests:** `frontend/test/features/physiotherapy/domain/physiotherapy_entities_test.dart`, `frontend/test/features/physiotherapy/presentation/physiotherapy_workspace_controller_test.dart`

### Route Definition

- **Route data:** `frontend/lib/app/router/app_routes.dart` — `AppRoutes.physiotherapy` at `/physiotherapy`
- **Router builder:** `frontend/lib/app/router/app_router.dart` — builds `PhysiotherapyWorkspacePage` with `PhysiotherapyWorkspaceQuery.fromUri(state.uri)`
- **Route icons:** `frontend/lib/app/router/app_route_icons.dart` — `Icons.accessibility_new_outlined` / `Icons.accessibility_new`

### Current Layout Problems

1. **No tab strip:** The workspace uses `AppWorkspaceSummaryNotification` chips rendered via `_summaryNotifications()` in the `AppWorkspace.toolbar` for scope switching (`referrals`, `today`, `missed`, `activePlans`, `followUpDue`, `completed`). There is no `AppTabStrip` widget.
2. **No URL section sync:** Scope changes are widget-level state managed by the controller's `applyScope()` method. The URL does not update when the scope changes — no `GoRouter.replace()` call with a `?section=` query parameter.
3. **Primary action placement is non-standard:** The primary action ("Schedule Session") and a secondary action ("Record Assessment") are embedded inside the `AppWorkspace.toolbar` via the `appWorkspaceToolbarWithLabels()` helper's `primary` and `secondary` parameters. In the Reception reference, the primary action is placed **inline to the right of the tab strip** inside a `Row`.
4. **Referrals button is duplicated:** A standalone "Referrals" `AppButton.secondary` is placed in the toolbar's `secondary` actions, redundant with the referrals summary notification chip.
5. **No per-tab column configuration:** The table uses a single set of columns (`_columns`) plus optional columns (`_optionalColumns`) regardless of which scope is active. The Reception pattern switches columns per tab via `_columnsForSection()`.

### What Already Works Well (Preserve)

- `AppListTable<TherapyWorkItem>` is correctly configured with search, pagination, column visibility, sort comparators, mobile builder, and empty state.
- Advanced filtering via `AppSearchBarFilterValue` with filter groups (scope, source, status, attendance) and text filters (therapist) and date filters — all wired to `applyWorklistFilters()`.
- The `PhysiotherapyWorkspaceController` uses Riverpod `AsyncNotifier` with realtime WebSocket sync and adaptive polling — identical to the canonical workspace controller pattern.
- Detail dialog pattern with `_openTherapyDetailDialog()` → `AppDialog` containing `_ActionsPanel`, `_OverviewPanel`, `_RecordsPanel`, `_UnavailableWorkflowsPanel`.
- Print support via `_printInstructions()`.
- All domain-specific dialogs (`_ScheduleSessionDialog`, `_AssessmentDialog`, `_SessionDialog`, `_AttendanceDialog`, `_PlanDialog`) with form validation.

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

| File | Key Patterns to Extract |
|------|------------------------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | `AppTabStrip` usage with `ReceptionDeskSection` enum, `_updateUrlForSection()` with `GoRouter.replace()`, primary action `AppButton.primary` in a `Row` next to tabs, per-tab column switching via `_columnsForSection()`, per-tab `columnVisibilityStorageKey` |
| `frontend/lib/features/reception/domain/entities/reception_entities.dart` | `ReceptionDeskSection` enum, `ReceptionWorkspaceQuery.fromUri()` with `section` query parameter parsing |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabStrip` constructor: `tabs`, `selectedId`, `onTabTapped`; `AppTabItem` constructor: `id`, `icon`, `label` |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable`, `AppListTableColumn`, `AppListTableSearch`, `AppListTableColumnVisibilityController` |
| `frontend/lib/shared/layout/app_workspace.dart` | `AppWorkspace`, `AppWorkspaceSummaryNotification`, `AppWorkspaceStatusBadge`, `AppWorkspaceStatusTone` |
| `frontend/lib/shared/components/app_state_view.dart` | `AsyncStateScaffold` with `keepPreviousDataDuringRefresh` |
| `frontend/lib/core/responsive/app_breakpoints.dart` | `AppBreakpoints`, `AppBreakpoint` enum, breakpoint thresholds |
| `frontend/lib/core/permissions/access_gate.dart` | `AppAccessActionGate` wrapping action buttons |

## Target Architecture

### Tab Configuration

| Tab Name | Route Query Value | Scope Enum | Description | Primary Action Button |
|----------|------------------|------------|-------------|----------------------|
| Referrals | `referrals` | `PhysiotherapyQueueScope.referrals` | Incoming referrals (REFERRAL, ACCEPTED, ASSESSMENT statuses) | "Schedule Session" → opens `_ScheduleSessionDialog` |
| Today | `today` | `PhysiotherapyQueueScope.today` | Sessions scheduled for today | "Record Session" → opens `_SessionDialog` |
| Active Plans | `active-plans` | `PhysiotherapyQueueScope.activePlans` | Patients with active treatment plans | "Schedule Session" → opens `_ScheduleSessionDialog` |
| Follow-Up | `follow-up` | `PhysiotherapyQueueScope.followUpDue` | Patients due for follow-up | "Schedule Follow-Up" → opens `ClinicalFollowUpActionDialog` |
| Missed | `missed` | `PhysiotherapyQueueScope.missed` | Missed appointments / no-shows | "Mark Attendance" → opens `_AttendanceDialog` |
| Completed | `completed` | `PhysiotherapyQueueScope.completed` | Completed therapy episodes | "Print Instructions" → calls `_printInstructions()` |

### Routing

The route stays as a flat `GoRoute` at `/physiotherapy` (no nested sub-routes). Tab selection is synced to the URL via the `?section=` query parameter, exactly as Reception does:

- URL pattern: `/physiotherapy?section=referrals`, `/physiotherapy?section=today`, etc.
- On tab tap → call `GoRouter.of(context).replace<void>(location)` with the updated query parameter.
- On page load → parse `section` from `PhysiotherapyWorkspaceQuery.fromUri(state.uri)` and set the initial tab.

### Page Layout

The target widget tree is:

```
Scaffold
└─ AppWorkspace
   ├─ title: l10n.physiotherapyTitle
   ├─ leadingIcon: Icons.accessibility_new_outlined
   ├─ toolbar: (refresh button only — no summary notifications, no primary/secondary action buttons in toolbar)
   └─ body: Column
      ├─ Row (tab strip + primary action)
      │  ├─ Expanded → AppTabStrip (6 tabs from PhysiotherapyQueueScope, labels include live counts)
      │  └─ AppAccessActionGate → AppButton.primary (label changes per tab)
      └─ Expanded → AppListTable<TherapyWorkItem> (columns change per tab, per-tab storage keys)
```

### Data & State Management

- **Keep** `physiotherapyWorkspaceControllerProvider` (`PhysiotherapyWorkspaceController`) as-is. It already manages scope changes via `applyScope()`.
- **Add** a local `_section` field (`late PhysiotherapyQueueScope _section`) in the `ConsumerStatefulWidget` state, synchronized with the controller's scope.
- When `_section` changes:
  1. Call `setState(() => _section = newScope)`.
  2. Call `controller.applyScope(newScope)`.
  3. Call `_updateUrlForSection(newScope)` to sync URL.

## Implementation Steps

### 1. Update `PhysiotherapyWorkspaceQuery` — File: `frontend/lib/features/physiotherapy/domain/entities/physiotherapy_entities.dart`

Add `section` field and parsing to `PhysiotherapyWorkspaceQuery`:

```dart
@immutable
final class PhysiotherapyWorkspaceQuery {
  const PhysiotherapyWorkspaceQuery({
    this.encounterId = '',
    this.sessionId = '',
    this.search = '',
    this.section = '',
  });

  factory PhysiotherapyWorkspaceQuery.fromUri(Uri uri) {
    final Map<String, String> params = uri.queryParameters;
    String pick(List<String> keys) {
      for (final String key in keys) {
        final String value = (params[key] ?? '').trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return PhysiotherapyWorkspaceQuery(
      encounterId: pick(<String>['encounterId', 'encounter_id', 'encounter']),
      sessionId: pick(<String>['sessionId', 'session_id', 'session']),
      search: pick(<String>['search', 'q']),
      section: pick(<String>['section']),
    );
  }

  final String encounterId;
  final String sessionId;
  final String search;
  final String section;

  bool get hasRouteTargeting =>
      encounterId.isNotEmpty || sessionId.isNotEmpty || search.isNotEmpty;

  String get signature => '$encounterId|$sessionId|$search|$section';
}
```

### 2. Refactor `PhysiotherapyWorkspacePage` — File: `frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart`

This is the main refactoring step. The page widget structure needs to change as follows:

#### 2a. Add imports

Add these imports at the top of the file:

```dart
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
```

#### 2b. Convert `_PhysiotherapyWorkspace` from `ConsumerWidget` to inner content of a `ConsumerStatefulWidget`

The current `_PhysiotherapyWorkspacePageState` should continue to own the `TextEditingController` and `AppListTableColumnVisibilityController`.

Add a new `_section` field:

```dart
late PhysiotherapyQueueScope _section;
```

Initialize it in `initState()`:

```dart
_section = _sectionFromQuery(widget.initialQuery) ?? PhysiotherapyQueueScope.referrals;
```

Add the section-from-query resolver:

```dart
static PhysiotherapyQueueScope? _sectionFromQuery(PhysiotherapyWorkspaceQuery? query) {
  if (query == null || query.section.isEmpty) return null;
  return _sectionFromQueryValue(query.section);
}

static PhysiotherapyQueueScope? _sectionFromQueryValue(String value) {
  return switch (value) {
    'referrals' => PhysiotherapyQueueScope.referrals,
    'today' => PhysiotherapyQueueScope.today,
    'active-plans' => PhysiotherapyQueueScope.activePlans,
    'follow-up' => PhysiotherapyQueueScope.followUpDue,
    'missed' => PhysiotherapyQueueScope.missed,
    'completed' => PhysiotherapyQueueScope.completed,
    _ => null,
  };
}

static String _sectionToQueryValue(PhysiotherapyQueueScope section) {
  return switch (section) {
    PhysiotherapyQueueScope.referrals => 'referrals',
    PhysiotherapyQueueScope.today => 'today',
    PhysiotherapyQueueScope.activePlans => 'active-plans',
    PhysiotherapyQueueScope.followUpDue => 'follow-up',
    PhysiotherapyQueueScope.missed => 'missed',
    PhysiotherapyQueueScope.completed => 'completed',
    PhysiotherapyQueueScope.all => 'referrals',
  };
}
```

#### 2c. Add URL sync method

```dart
void _updateUrlForSection(PhysiotherapyQueueScope section) {
  if (!mounted) return;
  final Map<String, String> params = <String, String>{
    'section': _sectionToQueryValue(section),
  };
  if (_searchController.text.trim().isNotEmpty) {
    params['search'] = _searchController.text.trim();
  }
  final String location = AppRoutes.physiotherapy.location(queryParameters: params);
  GoRouter.of(context).replace<void>(location);
}
```

#### 2d. Replace the `_PhysiotherapyWorkspace.build()` method body

Remove the `_summaryNotifications()` method entirely. Remove the `AppWorkspace.toolbar`'s `summaryNotifications`, `secondary`, and `primary` parameters.

Replace with this layout pattern:

```dart
@override
Widget build(BuildContext context) {
  final l10n = context.l10n;
  final controller = ref.read(physiotherapyWorkspaceControllerProvider.notifier);
  final isRefreshing = state.isRefreshing;

  return Scaffold(
    body: AppWorkspace(
      title: l10n.physiotherapyTitle,
      leadingIcon: Icons.accessibility_new_outlined,
      toolbar: appWorkspaceToolbarWithLabels(
        l10n,
        onRefresh: () async {
          await controller.refresh();
        },
        isRefreshing: isRefreshing,
      ),
      body: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: AppTabStrip(
                  tabs: <AppTabItem>[
                    for (final PhysiotherapyQueueScope scope in <PhysiotherapyQueueScope>[
                      PhysiotherapyQueueScope.referrals,
                      PhysiotherapyQueueScope.today,
                      PhysiotherapyQueueScope.activePlans,
                      PhysiotherapyQueueScope.followUpDue,
                      PhysiotherapyQueueScope.missed,
                      PhysiotherapyQueueScope.completed,
                    ])
                      AppTabItem(
                        id: scope.name,
                        icon: _sectionIcon(scope),
                        label: '${_sectionLabel(l10n, scope)} (${_sectionCount(state, scope)})',
                      ),
                  ],
                  selectedId: _section.name,
                  onTabTapped: (String tabId) {
                    for (final PhysiotherapyQueueScope scope in PhysiotherapyQueueScope.values) {
                      if (scope.name == tabId) {
                        setState(() => _section = scope);
                        controller.applyScope(scope);
                        _updateUrlForSection(scope);
                        break;
                      }
                    }
                  },
                ),
              ),
              SizedBox(width: Theme.of(context).spacing.md),
              _primaryActionForSection(context, ref, _section, state),
            ],
          ),
          Expanded(
            child: _buildWorklist(context, ref, controller),
          ),
        ],
      ),
    ),
  );
}
```

#### 2e. Add helper methods for tab strip

```dart
static IconData _sectionIcon(PhysiotherapyQueueScope scope) {
  return switch (scope) {
    PhysiotherapyQueueScope.referrals => Icons.assignment_outlined,
    PhysiotherapyQueueScope.today => Icons.today_outlined,
    PhysiotherapyQueueScope.activePlans => Icons.fact_check_outlined,
    PhysiotherapyQueueScope.followUpDue => Icons.notification_important_outlined,
    PhysiotherapyQueueScope.missed => Icons.event_busy_outlined,
    PhysiotherapyQueueScope.completed => Icons.task_alt_outlined,
    PhysiotherapyQueueScope.all => Icons.all_inbox_outlined,
  };
}

static String _sectionLabel(AppLocalizations l10n, PhysiotherapyQueueScope scope) {
  return switch (scope) {
    PhysiotherapyQueueScope.referrals => l10n.physiotherapyReferralsSummaryLabel,
    PhysiotherapyQueueScope.today => l10n.physiotherapyTodaySummaryLabel,
    PhysiotherapyQueueScope.activePlans => l10n.physiotherapyActivePlansSummaryLabel,
    PhysiotherapyQueueScope.followUpDue => l10n.physiotherapyFollowUpDueSummaryLabel,
    PhysiotherapyQueueScope.missed => l10n.physiotherapyMissedSummaryLabel,
    PhysiotherapyQueueScope.completed => l10n.physiotherapyCompletedSummaryLabel,
    PhysiotherapyQueueScope.all => l10n.physiotherapyScopeAll,
  };
}

static int _sectionCount(PhysiotherapyWorkspaceState state, PhysiotherapyQueueScope scope) {
  return switch (scope) {
    PhysiotherapyQueueScope.referrals => state.referralsCount,
    PhysiotherapyQueueScope.today => state.todayCount,
    PhysiotherapyQueueScope.activePlans => state.activePlansCount,
    PhysiotherapyQueueScope.followUpDue => state.followUpDueCount,
    PhysiotherapyQueueScope.missed => state.missedCount,
    PhysiotherapyQueueScope.completed => state.completedCount,
    PhysiotherapyQueueScope.all => state.worklist.items.length,
  };
}
```

#### 2f. Add per-tab primary action button

```dart
Widget _primaryActionForSection(
  BuildContext context,
  WidgetRef ref,
  PhysiotherapyQueueScope section,
  PhysiotherapyWorkspaceState state,
) {
  final l10n = context.l10n;
  final controller = ref.read(physiotherapyWorkspaceControllerProvider.notifier);

  return AppAccessActionGate(
    requirement: _therapyWriteRequirement,
    builder: (BuildContext context, bool isAllowed) {
      final (String label, IconData icon, VoidCallback? onPressed) = switch (section) {
        PhysiotherapyQueueScope.referrals || PhysiotherapyQueueScope.activePlans => (
          l10n.physiotherapyScheduleSessionAction,
          Icons.event_available_outlined,
          isAllowed && state.selectedDetail?.item.apiPatientId != null && !state.isSaving
              ? () => _openScheduleSession(context, controller, l10n)
              : null,
        ),
        PhysiotherapyQueueScope.today => (
          l10n.physiotherapyRecordSessionAction,
          Icons.directions_walk_outlined,
          isAllowed && !state.isSaving
              ? () => _openRecordSession(context, controller)
              : null,
        ),
        PhysiotherapyQueueScope.followUpDue => (
          l10n.physiotherapyScheduleFollowUpAction,
          Icons.notification_add_outlined,
          isAllowed && !state.isSaving
              ? () => _openScheduleFollowUp(context, controller, l10n)
              : null,
        ),
        PhysiotherapyQueueScope.missed => (
          l10n.physiotherapyMarkAttendanceAction,
          Icons.fact_check_outlined,
          isAllowed && !state.isSaving
              ? () => _openMarkAttendance(context, controller)
              : null,
        ),
        PhysiotherapyQueueScope.completed => (
          l10n.physiotherapyPrintInstructionsAction,
          Icons.print_outlined,
          state.selectedDetail != null
              ? () => _printInstructions(context, ref, state.selectedDetail!)
              : null,
        ),
        PhysiotherapyQueueScope.all => (
          l10n.physiotherapyScheduleSessionAction,
          Icons.event_available_outlined,
          isAllowed && !state.isSaving
              ? () => _openScheduleSession(context, controller, l10n)
              : null,
        ),
      };

      return AppButton.primary(
        label: label,
        leadingIcon: icon,
        enabled: onPressed != null,
        onPressed: onPressed,
      );
    },
  );
}
```

Add helper methods for the per-tab primary actions that open the existing dialogs. These delegate to the existing dialog infrastructure already in the file:

```dart
Future<void> _openScheduleSession(
  BuildContext context,
  PhysiotherapyWorkspaceController controller,
  AppLocalizations l10n,
) async {
  final _SchedulePayload? payload = await showAppDialog<_SchedulePayload>(
    context: context,
    builder: (_) => _ScheduleSessionDialog(
      title: l10n.physiotherapyScheduleSessionDialogTitle,
    ),
  );
  if (payload == null || !context.mounted) return;
  final AppFailure? failure = await controller.scheduleSession(
    startAt: payload.startAt,
    endAt: payload.endAt,
    reason: payload.reason,
  );
  if (!context.mounted) return;
  if (failure != null) _showFailure(context, failure);
}

Future<void> _openRecordSession(
  BuildContext context,
  PhysiotherapyWorkspaceController controller,
) async {
  final _SessionPayload? payload = await showAppDialog<_SessionPayload>(
    context: context,
    builder: (_) => const _SessionDialog(),
  );
  if (payload == null || !context.mounted) return;
  final AppFailure? failure = await controller.recordSession(
    note: payload.note,
    attendanceStatus: payload.attendanceStatus,
  );
  if (!context.mounted) return;
  if (failure != null) _showFailure(context, failure);
}

Future<void> _openScheduleFollowUp(
  BuildContext context,
  PhysiotherapyWorkspaceController controller,
  AppLocalizations l10n,
) async {
  final bool? saved = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ClinicalFollowUpActionDialog(
      title: l10n.physiotherapyScheduleFollowUpDialogTitle,
      submitLabel: l10n.physiotherapySaveAction,
      icon: const Icon(Icons.notification_add_outlined),
      dateLabel: l10n.physiotherapyDateFieldLabel,
      timeLabel: l10n.physiotherapyTimeFieldLabel,
      notesLabel: l10n.physiotherapyNoteFieldLabel,
      datePickerButtonLabel: l10n.patientsDatePickerAction,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      onSubmit: ({required DateTime scheduledAt, required String notes}) {
        return controller.scheduleFollowUp(
          scheduledAt: scheduledAt,
          notes: notes,
        );
      },
    ),
  );
  if (saved == true && context.mounted) _showSaved(context);
}

Future<void> _openMarkAttendance(
  BuildContext context,
  PhysiotherapyWorkspaceController controller,
) async {
  final _AttendancePayload? payload = await showAppDialog<_AttendancePayload>(
    context: context,
    builder: (_) => const _AttendanceDialog(),
  );
  if (payload == null || !context.mounted) return;
  final AppFailure? failure = await controller.markAttendance(
    status: payload.status,
    note: payload.note,
  );
  if (!context.mounted) return;
  if (failure != null) _showFailure(context, failure);
}
```

#### 2g. Update `_buildWorklist()` — per-tab column visibility storage keys

Modify the `AppListTable` constructor parameters to use per-tab storage keys:

```dart
columnVisibilityStorageKey: 'physiotherapy_${_section.name}',
columnWidthStorageKey: 'physiotherapy_cw_${_section.name}',
```

These parameters must be added to the existing `AppListTable<TherapyWorkItem>(...)` call. If `AppListTable` already has a `columnVisibilityStorageKey` set, update it. If not, add it.

#### 2h. Remove old code

- **Remove** the `_summaryNotifications()` method entirely.
- **Remove** the `_summaryNotification()` helper method.
- **Remove** the standalone "Referrals" `AppButton.secondary` from the toolbar.
- **Remove** the `primary` and `secondary` parameters from the `appWorkspaceToolbarWithLabels()` call.
- **Remove** the old primary action code (Schedule Session button and Record Assessment button) that was embedded in the toolbar.
- The toolbar should only retain `onRefresh` and `isRefreshing`.

### 3. Apply initial scope from route query — File: `frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart`

In `_applyRouteQuery()` (or `_scheduleRouteQuery()`), after handling `search` and `encounterId`/`sessionId`, also apply the `section` parameter:

```dart
Future<void> _applyRouteQuery(PhysiotherapyWorkspaceQuery query) async {
  final controller = ref.read(physiotherapyWorkspaceControllerProvider.notifier);
  
  // Apply section from URL if present
  final PhysiotherapyQueueScope? section = _sectionFromQuery(query);
  if (section != null && section != _section) {
    setState(() => _section = section);
    unawaited(controller.applyScope(section));
  }
  
  if (query.search.isNotEmpty) {
    _searchController.text = query.search;
    await controller.applySearch(query.search);
    return;
  }
  if (query.encounterId.isNotEmpty || query.sessionId.isNotEmpty) {
    final String term = query.encounterId.isNotEmpty ? query.encounterId : query.sessionId;
    _searchController.text = term;
    await controller.applySearch(term);
  }
}
```

### 4. No changes required — Files to leave untouched

- `frontend/lib/features/physiotherapy/presentation/controllers/physiotherapy_workspace_controller.dart` — No changes needed. The controller's `applyScope()` already handles scope changes correctly.
- `frontend/lib/features/physiotherapy/domain/repositories/physiotherapy_repository.dart` — No changes needed.
- `frontend/lib/features/physiotherapy/data/repositories/physiotherapy_repository_impl.dart` — No changes needed.
- `frontend/lib/features/physiotherapy/data/dtos/physiotherapy_dtos.dart` — No changes needed.
- `frontend/lib/app/router/app_router.dart` — No changes needed. The existing `GoRoute` already passes `PhysiotherapyWorkspaceQuery.fromUri(state.uri)` which will now include the `section` field.
- `frontend/lib/app/router/app_routes.dart` — No changes needed. Route stays at `/physiotherapy`.

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via barrel `components.dart`) | Tab strip with 6 tabs for queue scopes |
| `AppListTable<T>` | `package:hosspi_hms/shared/components/app_list_table.dart` (via barrel `components.dart`) | Already in use — keep as-is |
| `AppListTableSearch<T>` | Same as above | Already in use — keep as-is |
| `AppListTableColumnVisibilityController<T>` | Same as above | Already in use — keep as-is |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Already imported — wrap primary action button |
| `AppButton.primary()` | `package:hosspi_hms/shared/components/app_button.dart` (via barrel `components.dart`) | Already in use — move to inline with tab strip |
| `AsyncStateScaffold<T>` | `package:hosspi_hms/shared/components/app_state_view.dart` (via barrel `components.dart`) | Already in use — keep as-is |
| `AppWorkspace` | `package:hosspi_hms/shared/layout/app_workspace.dart` (via barrel `layout.dart`) | Already in use — remove summary notifications from toolbar |
| `AppWorkspaceStatusBadge` | Same as above | Already in use in table columns |
| `AppWorkspaceStatusTone` | Same as above | Already in use |

## Files to Create

No new files need to be created. All changes happen in existing files.

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/physiotherapy/domain/entities/physiotherapy_entities.dart` | Add `section` field to `PhysiotherapyWorkspaceQuery`, update `fromUri()` factory, update `signature` getter |
| `frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart` | Replace summary notification chips with `AppTabStrip`, add `_section` state field, add URL sync via `GoRouter.replace()`, move primary action inline with tabs, add per-tab primary action logic, add per-tab column visibility storage keys, add section helper methods, remove old `_summaryNotifications()` and `_summaryNotification()` methods, remove toolbar `primary`/`secondary`/`summaryNotifications` |

## Files to Delete (if any)

No files need to be deleted. The refactoring is entirely within existing files.

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove the `_summaryNotifications()` method from the workspace widget.
- [ ] Remove the `_summaryNotification()` helper method from the workspace widget.
- [ ] Remove the duplicate "Referrals" `AppButton.secondary` from the toolbar secondary actions.
- [ ] Remove the old `primary` and `secondary` parameters from the `appWorkspaceToolbarWithLabels()` call.
- [ ] Remove unused imports across all modified files (e.g., if `AppWorkspaceSummaryNotification` is no longer used after removing summary notifications, remove its import).
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.
- [ ] Verify no test files reference deleted code — update or remove stale tests.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. The refactoring only affects the Flutter UI layer (tab navigation and layout). No backend API changes, no new data fields, no schema modifications.

## Responsive Design Requirements

- **Desktop (≥840px / `AppBreakpoint.lg` and above):** Full table with all columns visible. Tab strip renders horizontally with labels. Primary action button shows label + icon inline with tabs.
- **Tablet (600–839px / `AppBreakpoint.md`):** `AppListTable` uses compact columns (136px default width). Tab strip may scroll horizontally. Primary action button may show icon-only if space is constrained.
- **Mobile (<600px / `AppBreakpoint.xs` + `AppBreakpoint.sm`):** `AppListTable` switches to list layout via `mobileItemBuilder` (already configured as `_TherapyWorklistMobileItem`). Tab strip scrolls horizontally. Primary action button renders as icon-only.

The existing `AppListTable` adaptive display mode handles the table-to-list switch automatically via `AppBreakpoints.fromConstraints()`. The existing `_TherapyWorklistMobileItem` mobile builder is preserved. No additional responsive wrappers are needed.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Format
dart format .

# Analyze
dart analyze --fatal-infos

# Run tests related to this screen
flutter test test/features/physiotherapy/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs calls `controller.applyScope()` with the correct scope and updates the URL via `GoRouter.replace()`
- [ ] Deep linking: constructing a `PhysiotherapyWorkspaceQuery.fromUri()` with `?section=today` returns `section: 'today'` and the page renders the "Today" tab as selected
- [ ] Table data: each tab filters the worklist by the correct scope (this is already handled by the controller — verify no regression)
- [ ] Search: the search bar continues to filter table rows via `applySearch()` and `matcher`
- [ ] Filter dialog: advanced filter button opens the filter UI and applies filters (verify no regression)
- [ ] Primary action: the primary action button label and behavior change per tab (referrals → Schedule Session, today → Record Session, etc.)
- [ ] Responsive layout: the `AppListTable` still switches to mobile list layout on `xs`/`sm` breakpoints
- [ ] No regressions: existing detail dialog, action panel, printing, and controller behavior still work

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The screen uses `AppTabStrip` with 6 tabs (Referrals, Today, Active Plans, Follow-Up, Missed, Completed)
- [ ] Each tab has its own URL section value that supports deep linking (e.g., `/physiotherapy?section=today`)
- [ ] Tab switching updates the URL via `GoRouter.replace()` and calls `controller.applyScope()` to filter data
- [ ] The primary action button is contextual per tab and positioned inline to the right of the tab strip
- [ ] The old summary notification chips are removed from the toolbar
- [ ] The page body continues to use `AppListTable<TherapyWorkItem>` with search, filter, pagination, column visibility
- [ ] Column visibility storage keys are per-tab (e.g., `physiotherapy_referrals`, `physiotherapy_today`)
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop (existing responsive behavior preserved)
- [ ] All domain-specific business logic (controller, repository, dialogs, print) is preserved unchanged
- [ ] The `_summaryNotifications()` and `_summaryNotification()` methods are removed
- [ ] No database migrations required — schema unchanged
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
