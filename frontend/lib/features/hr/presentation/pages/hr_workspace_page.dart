import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/access_admin/data/repositories/access_admin_repository_impl.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_access_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart'
    hide
        hrReadRequirement,
        hrWriteRequirement,
        hrRosterWriteRequirement,
        hrRosterApproveRequirement,
        hrRosterPublishRequirement,
        hrPayrollRequirement,
        HrHumanResourcesAtomPermissions,
        HrLeaveRequestsAtomPermissions,
        HrShiftsAtomPermissions,
        HrPayrollDraftsAtomPermissions,
        showHrMutationSnackBar,
        readHrWorkspaceState;
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_positions_panel.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_queue_switcher.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_request_leave_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_detail_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_details_body.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_print_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_workspace_form_fields.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

part 'hr_workspace_dialog_actions.dart';

class HrWorkspacePage extends ConsumerWidget {
  const HrWorkspacePage({super.key, this.initialQuery});

  /// Deep-link targeting parsed from the `/hr` route query string.
  final HrWorkspaceQuery? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<HrWorkspaceState>> workspace = ref.watch(
      hrWorkspaceControllerProvider,
    );

    return AppAccessGate(
      requirement: HrHumanResourcesAtomPermissions.routeEntry,
      deniedBuilder: (_, _) => AppStateScaffold(
        variant: AppStateViewVariant.forbidden,
        title: l10n.routeForbiddenTitle,
        body: l10n.routeForbiddenBody,
      ),
      child: AsyncStateScaffold<HrWorkspaceState>(
        value: workspace,
        appBarTitle: l10n.hrTitle,
        loadingTitle: l10n.hrLoadingTitle,
        loadingBody: l10n.hrLoadingBody,
        maxWidth: PageMaxWidth.dataHeavy,
        centerVertically: false,
        scrollable: false,
        onRetry: () {
          ref.read(hrWorkspaceControllerProvider.notifier).refresh();
        },
        dataBuilder: (BuildContext context, HrWorkspaceState state) {
          return _HrWorkspaceContent(state: state, initialQuery: initialQuery);
        },
      ),
    );
  }
}

class _HrWorkspaceContent extends ConsumerStatefulWidget {
  const _HrWorkspaceContent({required this.state, this.initialQuery});

  final HrWorkspaceState state;
  final HrWorkspaceQuery? initialQuery;

  @override
  ConsumerState<_HrWorkspaceContent> createState() =>
      _HrWorkspaceContentState();
}

class _HrWorkspaceContentState extends ConsumerState<_HrWorkspaceContent> {
  late final TextEditingController _workQueueSearchController;
  late final AppListTableColumnVisibilityController<HrWorkItem>
  _queueColumnController;
  late HrDeskSection _section;

  bool _deepLinkHandled = false;

  @override
  void initState() {
    super.initState();
    // Queue wins over section when both are present (flat IA deep-links).
    _section =
        HrDeskSection.fromQueue(widget.initialQuery?.queue) ??
        HrDeskSection.fromQuery(widget.initialQuery?.section ?? '') ??
        HrDeskSection.staffDirectory;
    _workQueueSearchController = TextEditingController(
      text: widget.state.workItemsQuery.search,
    );
    _queueColumnController =
        AppListTableColumnVisibilityController<HrWorkItem>();
    _scheduleDeepLink();
  }

  void _scheduleDeepLink() {
    final HrWorkspaceQuery? query = widget.initialQuery;
    if (query == null || !query.hasRouteTargeting || _deepLinkHandled) {
      return;
    }
    _deepLinkHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_handleDeepLink(query));
    });
  }

  Future<void> _handleDeepLink(HrWorkspaceQuery query) async {
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );

    // Queue owns the primary when both `?section=` and `?queue=` disagree.
    final HrDeskSection? sectionFromRoute =
        HrDeskSection.fromQueue(query.queue) ??
        HrDeskSection.fromQuery(query.section);
    if (sectionFromRoute != null && sectionFromRoute != _section) {
      setState(() => _section = sectionFromRoute);
    }

    final String? focusStaffId = query.focusStaffId?.trim();
    if (focusStaffId != null && focusStaffId.isNotEmpty) {
      setState(() => _section = HrDeskSection.staffDirectory);
      await openHrStaffDetailById(context, ref, focusStaffId);
      return;
    }

    final HrQueue? queue = query.queue;
    if (queue != null) {
      final AppFailure? failure = await controller.applyQueue(queue);
      if (!mounted) {
        return;
      }
      if (failure != null) {
        showHrMutationSnackBar(context, failure);
      } else {
        _updateUrlForSection(_section, queue: queue);
      }
      return;
    }

    if (sectionFromRoute != null) {
      _loadDataForSection(sectionFromRoute);
    }

    final String search = query.search.trim();
    if (search.isNotEmpty) {
      await controller.applyStaffSearch(search);
    }
  }

  void _loadDataForSection(HrDeskSection section) {
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final HrQueue? targetQueue = hrDefaultQueueForSection(section);
    if (targetQueue != null) {
      unawaited(controller.applyQueue(targetQueue));
    }
  }

  /// Same Users CRUD as Facility setup (`ManageUsersPanel`).
  Future<void> _onUsersMutated(bool _) async {
    await ref.read(hrWorkspaceControllerProvider.notifier).refresh();
  }

  void _updateUrlForSection(HrDeskSection section, {HrQueue? queue}) {
    if (!mounted) {
      return;
    }
    final String tab = section.routeQueryValue;
    final HrQueue? resolvedQueue = queue ?? hrDefaultQueueForSection(section);
    final String location = AppRoutes.hr.location(
      queryParameters: <String, String>{
        if (tab.isNotEmpty) 'section': tab,
        if (resolvedQueue != null) 'queue': resolvedQueue.value,
      },
    );
    GoRouter.of(context).replace<void>(location);
  }

  @override
  void didUpdateWidget(covariant _HrWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String workQueueSearch = widget.state.workItemsQuery.search;
    if (_workQueueSearchController.text != workQueueSearch) {
      _workQueueSearchController.text = workQueueSearch;
    }
  }

  @override
  void dispose() {
    _workQueueSearchController.dispose();
    _queueColumnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Result<HrWorkspaceState>>>(
      hrWorkspaceControllerProvider,
      (
        AsyncValue<Result<HrWorkspaceState>>? previous,
        AsyncValue<Result<HrWorkspaceState>> next,
      ) {
        final HrWorkspaceState? nextState = _hrStateFromAsync(next);
        if (nextState?.openStaffDetailAfterOnboarding != true) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) {
            return;
          }
          ref
              .read(hrWorkspaceControllerProvider.notifier)
              .clearOpenStaffDetailAfterOnboarding();
          await showHrStaffDetailDialog(context, ref);
        });
      },
    );

    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final HrWorkspaceState state = widget.state;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final List<HrDeskSection> visibleSections = hrAllowedSections(accessPolicy);
    if (visibleSections.isEmpty) {
      // No authorized sections — omit chrome (no routine "no access" banner).
      return const SizedBox.shrink();
    }
    final bool canShowCurrentSection = visibleSections.contains(_section);
    if (!canShowCurrentSection) {
      final HrDeskSection fallback =
          hrFallbackSection(accessPolicy) ?? visibleSections.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || visibleSections.contains(_section)) {
          return;
        }
        setState(() => _section = fallback);
        _updateUrlForSection(fallback);
        _loadDataForSection(fallback);
      });
    }
    final HrDeskSection activeSection = canShowCurrentSection
        ? _section
        : visibleSections.first;
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final AppFailure? lastFailure = state.lastFailure is AppFailure
        ? state.lastFailure! as AppFailure
        : null;

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      scrollable: false,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: <AppTabItem>[
                for (final HrDeskSection section in visibleSections)
                  AppTabItem(
                    id: section.name,
                    icon: _sectionIcon(section),
                    label: _sectionLabel(l10n, section),
                    count: _sectionCount(state, section),
                    countTone: _sectionCountTone(section),
                  ),
              ],
              selectedId: activeSection.name,
              onTabTapped: (String tabId) {
                for (final HrDeskSection section in visibleSections) {
                  if (section.name == tabId) {
                    setState(() => _section = section);
                    _updateUrlForSection(
                      section,
                      queue: hrDefaultQueueForSection(section),
                    );
                    _loadDataForSection(section);
                    break;
                  }
                }
              },
            ),
            SizedBox(height: theme.spacing.sm),
            if (lastFailure != null) ...<Widget>[
              AppFailureStateView(
                failure: lastFailure,
                onRetry: controller.refresh,
              ),
              SizedBox(height: theme.spacing.md),
            ],
            Expanded(
              child: _buildTabBody(state, controller, activeSection),
            ),
          ],
        ),
      ),
    );
  }

  /// Search-bar trailing actions after Export (Settings → Export → actions).
  ///
  /// Human resources hosts [ManageUsersPanel] (Facility setup Users CRUD), so
  /// Create user lives on that panel. Access creates live on the embedded
  /// Access panel; payroll runs from staff detail so the desk never guesses a
  /// staff member.
  List<AppSearchBarAction> _searchTrailingActions(
    AppLocalizations l10n,
    HrWorkspaceState state,
    HrDeskSection section,
  ) {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    return switch (section) {
      HrDeskSection.staffDirectory => const <AppSearchBarAction>[],
      HrDeskSection.positions => const <AppSearchBarAction>[],
      HrDeskSection.leaveRequests =>
        HrLeaveRequestsAtomPermissions.requestLeave.isAllowed(policy)
            ? <AppSearchBarAction>[
                AppSearchBarAction(
                  icon: Icons.event_busy_outlined,
                  label: l10n.hrRequestLeaveAction,
                  tooltip: l10n.hrRequestLeaveAction,
                  enabled: !state.isRefreshing,
                  onPressed: state.isRefreshing
                      ? null
                      : () => showHrRequestLeaveDialog(context, ref),
                ),
              ]
            : const <AppSearchBarAction>[],
      HrDeskSection.shiftRoster =>
        HrShiftsAtomPermissions.scheduleTemplates.isAllowed(policy)
            ? <AppSearchBarAction>[
                AppSearchBarAction(
                  icon: Icons.edit_calendar_outlined,
                  label: l10n.hrShiftTemplateAction,
                  tooltip: l10n.hrShiftTemplateAction,
                  enabled: !state.isRefreshing,
                  onPressed: state.isRefreshing
                      ? null
                      : () => unawaited(_createRosterTemplate()),
                ),
              ]
            : const <AppSearchBarAction>[],
      HrDeskSection.swapRequests ||
      HrDeskSection.unassignedShifts ||
      HrDeskSection.payroll ||
      HrDeskSection.access =>
        const <AppSearchBarAction>[],
    };
  }

  Future<void> _createRosterTemplate() async {
    final HrCreatedRosterTemplate? created =
        await showHrCreateRosterDialog(context, ref);
    if (created == null || !mounted) {
      return;
    }
    await showHrRosterDetailByIdDialog(
      context,
      ref,
      rosterId: created.id,
      rosterName: created.name,
      status: created.status ?? 'DRAFT',
    );
  }

  Widget _buildTabBody(
    HrWorkspaceState state,
    HrWorkspaceController controller,
    HrDeskSection section,
  ) {
    final List<AppSearchBarAction> searchTrailingActions =
        _searchTrailingActions(context.l10n, state, section);
    return switch (section) {
      // Identical Users CRUD as `/admin/setup?section=users`.
      HrDeskSection.staffDirectory => ManageUsersPanel(
        onMutated: (bool mutated) {
          if (mutated) {
            unawaited(_onUsersMutated(mutated));
          }
        },
        onOpenDetail: (AccessAdminItem item) =>
            openHrStaffDetailForDirectoryUser(context, ref, item),
      ),
      HrDeskSection.positions => const HrPositionsPanel(),
      HrDeskSection.leaveRequests ||
      HrDeskSection.swapRequests ||
      HrDeskSection.shiftRoster ||
      HrDeskSection.unassignedShifts ||
      HrDeskSection.payroll => _HrWorkQueueTable(
        section: section,
        searchController: _workQueueSearchController,
        columnVisibilityController: _queueColumnController,
        searchTrailingActions: searchTrailingActions,
        onPageChanged: controller.changeWorkItemsPage,
        onQueueChanged: (HrQueue queue) {
          _updateUrlForSection(section, queue: queue);
        },
      ),
      HrDeskSection.access => const HrAccessWorkspacePanel(embedded: true),
    };
  }
}

class _HrStaffDetailPanel extends ConsumerWidget {
  const _HrStaffDetailPanel({required this.state});

  final HrWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final HrStaffDetail? selected = state.selectedStaff;
    if (selected == null) {
      return AppCollapsibleSection(
        title: l10n.hrStaffDetailTitle,
        child: AppStateView(
          title: l10n.hrNoStaffSelectedTitle,
          body: l10n.hrNoStaffSelectedBody,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (state.isRefreshingDetail)
          const LinearProgressIndicator(minHeight: 2),
        if (selected.profile.isSeparated)
          Padding(
            padding: EdgeInsets.only(bottom: Theme.of(context).spacing.md),
            child: _HrSeparationBanner(profile: selected.profile),
          ),
        _HrStaffDetailBody(state: state, detail: selected),
      ],
    );
  }
}

class _HrStaffDetailBody extends ConsumerWidget {
  const _HrStaffDetailBody({required this.state, required this.detail});

  final HrWorkspaceState state;
  final HrStaffDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HrStaffDetailsBody(
      state: state,
      detail: detail,
    );
  }
}

class _HrWorkQueuePanel extends ConsumerWidget {
  const _HrWorkQueuePanel({
    required this.searchController,
    required this.columnVisibilityController,
    required this.onPageChanged,
  });

  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<HrWorkItem>
  columnVisibilityController;
  final ValueChanged<AppPageRequest> onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dialog browse: all queues via Filters (no nested tab strip).
    return _HrWorkQueueTable(
      searchController: searchController,
      columnVisibilityController: columnVisibilityController,
      onPageChanged: onPageChanged,
    );
  }
}

class _HrWorkQueueTable extends ConsumerStatefulWidget {
  const _HrWorkQueueTable({
    required this.searchController,
    required this.columnVisibilityController,
    required this.onPageChanged,
    this.section,
    this.searchTrailingActions = const <AppSearchBarAction>[],
    this.onQueueChanged,
  });

  /// Owning primary tab; `null` = dialog with all workspace queues.
  final HrDeskSection? section;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<HrWorkItem>
  columnVisibilityController;
  final List<AppSearchBarAction> searchTrailingActions;
  final ValueChanged<AppPageRequest> onPageChanged;
  final ValueChanged<HrQueue>? onQueueChanged;

  @override
  ConsumerState<_HrWorkQueueTable> createState() => _HrWorkQueueTableState();
}

class _HrWorkQueueTableState extends ConsumerState<_HrWorkQueueTable> {
  final Set<String> _selectedRosterKeys = <String>{};
  HrQueue? _selectionQueue;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _scheduleWorkItemsSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      final HrWorkspaceState? state = _hrStateFromAsync(
        ref.read(hrWorkspaceControllerProvider),
      );
      if (state != null &&
          state.workItemsQuery.search.trim() == value.trim()) {
        return;
      }
      unawaited(
        ref
            .read(hrWorkspaceControllerProvider.notifier)
            .applyWorkItemsSearch(value),
      );
    });
  }

  String _rosterSelectionKey(HrWorkItem item) {
    return (item.rosterId ?? item.backendIdentifier ?? item.effectiveId).trim();
  }

  void _syncSelectionForQueue(HrQueue queue, List<HrWorkItem> items) {
    if (_selectionQueue != queue) {
      _selectionQueue = queue;
      _selectedRosterKeys.clear();
      return;
    }
    if (queue != HrQueue.rosterDrafts || _selectedRosterKeys.isEmpty) {
      return;
    }
    final Set<String> visibleKeys = <String>{
      for (final HrWorkItem item in items) _rosterSelectionKey(item),
    }..removeWhere((String key) => key.isEmpty);
    _selectedRosterKeys.removeWhere(
      (String key) => !visibleKeys.contains(key),
    );
  }

  Future<void> _editRosterTemplate(HrWorkItem item) async {
    final String rosterId = _rosterSelectionKey(item);
    if (rosterId.isEmpty) {
      return;
    }
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final Result<Map<String, Object?>> result = await controller.getRoster(
      rosterId,
    );
    if (!mounted) {
      return;
    }
    final Map<String, Object?>? roster = result.when(
      success: (Map<String, Object?> value) => value,
      failure: (_) => null,
    );
    final AppFailure? failure = result.when(
      success: (_) => null,
      failure: (AppFailure value) => value,
    );
    if (failure != null || roster == null) {
      showHrMutationSnackBar(context, failure ?? const AppFailure.unexpected());
      return;
    }
    final bool saved = await showHrEditRosterDialog(
      context,
      ref,
      rosterId: rosterId,
      roster: roster,
    );
    if (saved && mounted) {
      unawaited(controller.refresh());
    }
  }

  Future<void> _softDeleteRosterTemplate(HrWorkItem item) async {
    final AppLocalizations l10n = context.l10n;
    final String rosterId = _rosterSelectionKey(item);
    if (rosterId.isEmpty) {
      return;
    }
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppConfirmActionDialog(
          title: l10n.hrRosterDeleteConfirmTitle,
          body: l10n.hrRosterDeleteConfirmMessage,
          submitLabel: l10n.hrRosterDeleteAction,
          destructive: true,
          submitLeadingIcon: Icons.delete_outline,
          onConfirm: () async {
            final AppFailure? failure = await ref
                .read(hrWorkspaceControllerProvider.notifier)
                .deleteRoster(rosterId);
            return failure;
          },
        );
      },
    );
    if (confirmed == true && mounted) {
      setState(() => _selectedRosterKeys.remove(rosterId));
      showHrMutationSnackBar(context, null);
    }
  }

  Future<void> _restoreRosterTemplate(HrWorkItem item) async {
    final AppLocalizations l10n = context.l10n;
    final String rosterId = _rosterSelectionKey(item);
    if (rosterId.isEmpty) {
      return;
    }
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppConfirmActionDialog(
          title: l10n.hrRosterRestoreConfirmTitle,
          body: l10n.hrRosterRestoreConfirmMessage,
          submitLabel: l10n.hrRosterRestoreAction,
          submitLeadingIcon: Icons.restore_outlined,
          onConfirm: () async {
            return ref
                .read(hrWorkspaceControllerProvider.notifier)
                .restoreRoster(rosterId);
          },
        );
      },
    );
    if (confirmed == true && mounted) {
      setState(() => _selectedRosterKeys.remove(rosterId));
      showHrMutationSnackBar(context, null);
    }
  }

  Future<void> _permanentDeleteRosterTemplate(HrWorkItem item) async {
    final AppLocalizations l10n = context.l10n;
    final String rosterId = _rosterSelectionKey(item);
    if (rosterId.isEmpty) {
      return;
    }
    final String confirmName =
        (item.rosterName ?? item.periodLabel ?? item.effectiveId).trim();
    final String? typed = await showAppDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppTextInputActionDialog(
          title: l10n.hrRosterPermanentDeleteConfirmTitle,
          description: l10n.hrRosterPermanentDeleteConfirmMessage,
          fieldLabel: l10n.tenantFacilityPermanentDeleteConfirmFieldLabel(
            confirmName,
          ),
          submitLabel: l10n.hrRosterPermanentDeleteAction,
          cancelLabel: l10n.commonCancelActionLabel,
          requiredMessage: l10n.validationRequired,
          confirmExactValue: confirmName,
          confirmMismatchMessage:
              l10n.tenantFacilityPermanentDeleteConfirmFieldLabel(confirmName),
          destructive: true,
          minLines: 1,
          maxLines: 1,
          icon: const Icon(Icons.delete_forever_outlined),
        );
      },
    );
    if (!mounted || typed == null) {
      return;
    }
    if (typed.trim().toLowerCase() != confirmName.trim().toLowerCase()) {
      return;
    }
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppConfirmActionDialog(
          title: l10n.hrRosterPermanentDeleteConfirmTitle,
          body: l10n.hrRosterPermanentDeleteConfirmMessage,
          highlightedText: confirmName,
          submitLabel: l10n.hrRosterPermanentDeleteAction,
          destructive: true,
          submitLeadingIcon: Icons.delete_forever_outlined,
          onConfirm: () async {
            return ref
                .read(hrWorkspaceControllerProvider.notifier)
                .permanentDeleteRoster(rosterId);
          },
        );
      },
    );
    if (confirmed == true && mounted) {
      setState(() => _selectedRosterKeys.remove(rosterId));
      showHrMutationSnackBar(context, null);
    }
  }

  Future<void> _bulkDeleteSelected({required bool permanent}) async {
    final AppLocalizations l10n = context.l10n;
    final List<String> ids = _selectedRosterKeys.toList(growable: false);
    if (ids.isEmpty) {
      return;
    }
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppConfirmActionDialog(
          title: permanent
              ? l10n.hrRosterPermanentDeleteSelectedConfirmTitle
              : l10n.hrRosterDeleteSelectedConfirmTitle,
          body: permanent
              ? l10n.hrRosterPermanentDeleteSelectedConfirmMessage(ids.length)
              : l10n.hrRosterDeleteSelectedConfirmMessage(ids.length),
          submitLabel: permanent
              ? l10n.hrRosterPermanentDeleteSelectedAction
              : l10n.hrRosterDeleteSelectedAction,
          destructive: true,
          submitLeadingIcon: permanent
              ? Icons.delete_forever_outlined
              : Icons.delete_outline,
          onConfirm: () async {
            final HrWorkspaceController controller = ref.read(
              hrWorkspaceControllerProvider.notifier,
            );
            for (final String id in ids) {
              final AppFailure? failure = permanent
                  ? await controller.permanentDeleteRoster(id)
                  : await controller.deleteRoster(id);
              if (failure != null) {
                return failure;
              }
            }
            return null;
          },
        );
      },
    );
    if (confirmed == true && mounted) {
      setState(() => _selectedRosterKeys.clear());
      showHrMutationSnackBar(context, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceState? state = _hrStateFromAsync(
      ref.watch(hrWorkspaceControllerProvider),
    );
    if (state == null) {
      return const SizedBox.shrink();
    }

    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final HrQueue queue = state.workItemsQuery.queue;
    final HrQueue defaultQueue =
        hrDefaultQueueForSection(widget.section ?? HrDeskSection.leaveRequests) ??
        HrQueue.leaveRequests;
    final List<HrQueue> queueChoices = hrQueuesForSection(widget.section, queue);
    final bool showQueueFacet =
        widget.section != HrDeskSection.payroll && queueChoices.length > 1;
    final List<HrWorkItem> visibleItems = state.workItems.items;
    _syncSelectionForQueue(queue, visibleItems);

    final bool isRosterQueue = queue == HrQueue.rosterDrafts;
    final bool deletedFilter =
        (state.workItemsQuery.status ?? '').trim().toUpperCase() == 'DELETED';
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canWriteRosters = HrShiftsAtomPermissions.write.isAllowed(
      accessPolicy,
    );

    void onRowSelected(HrWorkItem item) {
      if (item.queue == HrQueue.rosterDrafts) {
        unawaited(showHrRosterDetailDialog(context, ref, item));
        return;
      }
      _showWorkItemDialog(context, ref, item);
    }

    void onNextAction(HrWorkItem item) =>
        unawaited(_handleWorkItemNextAction(context, ref, item));

    final List<AppSearchBarAction> trailingActions = <AppSearchBarAction>[
      if (isRosterQueue &&
          canWriteRosters &&
          _selectedRosterKeys.isNotEmpty)
        AppSearchBarAction(
          icon: deletedFilter
              ? Icons.delete_forever_outlined
              : Icons.delete_outline,
          label: deletedFilter
              ? l10n.hrRosterPermanentDeleteSelectedAction
              : l10n.hrRosterDeleteSelectedAction,
          tooltip: deletedFilter
              ? l10n.hrRosterPermanentDeleteSelectedAction
              : l10n.hrRosterDeleteSelectedAction,
          destructive: true,
          enabled: !state.isRefreshingWorkItems && !state.isMutating,
          onPressed: state.isRefreshingWorkItems || state.isMutating
              ? null
              : () => unawaited(_bulkDeleteSelected(permanent: deletedFilter)),
        ),
      ...widget.searchTrailingActions,
    ];

    return AppListTable<HrWorkItem>(
      page: state.workItems,
      isLoading: state.isRefreshingWorkItems,
      columnVisibilityController: widget.columnVisibilityController,
      columnVisibilityStorageKey: 'hr_work_queue_${queue.name}_v2',
      columnWidthStorageKey: 'hr_work_queue_cw_${queue.name}_v2',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      search: AppListTableSearch<HrWorkItem>(
        controller: widget.searchController,
        semanticLabel: l10n.hrSearchLabel,
        hintText: l10n.hrSearchHint,
        clearLabel: l10n.hrClearFiltersAction,
        // Paginated queues are filtered on the server. A client matcher would
        // only search the current page and hide older matches (e.g. ROS0000001).
        matcher: (HrWorkItem _, String __) => true,
        onChanged: _scheduleWorkItemsSearch,
        onSubmitted: (String value) {
          _searchDebounce?.cancel();
          unawaited(controller.applyWorkItemsSearch(value));
        },
        onClear: () {
          _searchDebounce?.cancel();
          unawaited(controller.applyWorkItemsSearch(''));
        },
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.hrClearFiltersAction,
        allFieldsLabel: l10n.opdAllFieldsFilterLabel,
        filterGroups: <AppSearchBarFilterGroup>[
          if (showQueueFacet)
            AppSearchBarFilterGroup(
              key: _hrWorkItemQueueFilterKey,
              label: l10n.hrQueueColumnLabel,
              allLabel: l10n.opdAllFieldsFilterLabel,
              choices: <AppSearchBarFilterChoice>[
                for (final HrQueue choice in queueChoices)
                  AppSearchBarFilterChoice(
                    value: choice.value,
                    label: hrQueueLabel(l10n, choice),
                    icon: hrQueueIcon(choice),
                  ),
              ],
            ),
          AppSearchBarFilterGroup(
            key: _hrWorkItemStatusFilterKey,
            label: l10n.hrStatusColumnLabel,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: _workItemStatusFilterChoices(context),
          ),
        ],
        filterValue: _workItemFilterValue(
          state.workItemsQuery,
          includeQueue: showQueueFacet,
          defaultQueue: defaultQueue,
        ),
        hasActiveFilters: _hasWorkItemFilters(
          state.workItemsQuery,
          defaultQueue: defaultQueue,
          includeQueue: showQueueFacet,
        ),
        onFilterChanged: (AppSearchBarFilterValue value) {
          final HrQueue? parsed = HrQueue.fromValue(
            value.option(_hrWorkItemQueueFilterKey),
          );
          final HrQueue nextQueue = parsed != null &&
                  hrQueueAllowedOnSection(widget.section, parsed)
              ? parsed
              : (showQueueFacet ? defaultQueue : queue);
          unawaited(
            controller.applyWorkItemsScope(
              queue: nextQueue,
              status: value.option(_hrWorkItemStatusFilterKey),
              from: state.workItemsQuery.from,
              to: state.workItemsQuery.to,
            ),
          );
          widget.onQueueChanged?.call(nextQueue);
        },
        // Filters → Settings → Export → Delete selected → Create roster.
        trailingActions: trailingActions,
      ),
      itemKeyBuilder: (HrWorkItem item) => ValueKey<String>(item.id),
      onRowSelected: onRowSelected,
      previousPageLabel: l10n.hrPreviousQueuePageLabel,
      nextPageLabel: l10n.hrNextQueuePageLabel,
      pageLabelBuilder: (AppPage<HrWorkItem> page) {
        return l10n.hrPageLabel(
          page.firstItemNumber,
          page.lastItemNumber,
          page.totalItemCount ?? page.lastItemNumber,
        );
      },
      onPageChanged: widget.onPageChanged,
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.hrNoQueueItemsTitle,
        body: l10n.hrNoQueueItemsBody,
      ),
      columns: _workQueueColumns(
        context,
        queue,
        onNextAction: onNextAction,
        selectedRosterKeys: isRosterQueue ? _selectedRosterKeys : null,
        visibleRosterItems: isRosterQueue ? visibleItems : null,
        onRosterSelectionChanged: isRosterQueue
            ? (Set<String> next) => setState(() {
                _selectedRosterKeys
                  ..clear()
                  ..addAll(next);
              })
            : null,
        onEditRoster: isRosterQueue
            ? (HrWorkItem item) => unawaited(_editRosterTemplate(item))
            : null,
        onDeleteRoster: isRosterQueue
            ? (HrWorkItem item) => unawaited(_softDeleteRosterTemplate(item))
            : null,
        onRestoreRoster: isRosterQueue
            ? (HrWorkItem item) => unawaited(_restoreRosterTemplate(item))
            : null,
        onPermanentDeleteRoster: isRosterQueue
            ? (HrWorkItem item) =>
                  unawaited(_permanentDeleteRosterTemplate(item))
            : null,
        canWriteRosters: canWriteRosters,
        isMutating: state.isMutating,
      ),
      columnChoices: _workQueueColumnChoices(context, queue),
      mobileItemBuilder: (BuildContext context, HrWorkItem item) {
        return AppListTableMobileItem(
          title: _workItemTitle(context, item),
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: item.queue == HrQueue.rosterDrafts
                  ? hrRosterStatusLabel(context.l10n, item.status)
                  : _apiLabel(context, item.status),
            ),
            if (item.queue != HrQueue.rosterDrafts)
              AppListTableMobileMeta(
                label: _workItemPeriod(context, item),
                icon: Icons.date_range_outlined,
              ),
            if (item.queue == HrQueue.rosterDrafts)
              AppListTableMobileMeta(
                label: '${context.l10n.hrAssignmentsSectionTitle}: ${item.assignmentCount}',
                icon: Icons.groups_outlined,
              ),
          ],
          showAvatar: false,
        );
      },
    );
  }
}

class _HrSeparationBanner extends StatelessWidget {
  const _HrSeparationBanner({required this.profile});

  final HrStaffProfile profile;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String separationType = hrSeparationTypeLabel(
      l10n,
      profile.separationType,
    );
    final String lastDay = profile.separationDate == null
        ? l10n.profileUnknownValue
        : AppFormatters.shortDate(
            profile.separationDate!,
            Localizations.localeOf(context),
          );

    return Material(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(theme.radius.md),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Row(
          children: <Widget>[
            Icon(Icons.person_off_outlined, color: theme.colorScheme.error),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Text(
                l10n.hrSeparationBannerMessage(separationType, lastDay),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: AppFontWeight.emphasis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(
        label: _apiLabel(
          context,
          status,
        ).ifEmpty(context.l10n.profileUnknownValue),
        tone: _statusTone(status),
      ),
    );
  }
}



Future<void> _showWorkItemDialog(
  BuildContext context,
  WidgetRef ref,
  HrWorkItem item,
) async {
  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(_workItemTitle(context, item)),
      icon: Icon(hrQueueIcon(item.queue)),
      scrollable: true,
      maxWidth: 640,
      content: _WorkItemActions(item: item),
    ),
  );
}

/// Opens the queue-row primary mutation without the intermediate detail shell.
Future<void> _handleWorkItemNextAction(
  BuildContext context,
  WidgetRef ref,
  HrWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  switch (item.queue) {
    case HrQueue.leaveRequests:
      await _submitReason(
        context,
        title: l10n.hrApproveLeaveDialogTitle,
        submitLabel: l10n.hrApproveLeaveAction,
        requiredReason: false,
        onSubmit: (String? reason) =>
            controller.approveLeave(item, reason: reason),
      );
    case HrQueue.swapRequests:
      await _submitReason(
        context,
        title: l10n.hrApproveSwapDialogTitle,
        submitLabel: l10n.hrApproveSwapAction,
        requiredReason: false,
        onSubmit: (String? reason) =>
            controller.approveSwap(item, reason: reason),
      );
    case HrQueue.rosterDrafts:
      await _showRosterPublishDialog(context, controller, item);
    case HrQueue.unassignedShifts || HrQueue.overdueShifts:
      await _showOverrideShiftDialog(context, ref, item);
    case HrQueue.payrollDrafts:
      await _showProcessPayrollDialog(context, controller, item);
  }
}

class _WorkItemActions extends ConsumerWidget {
  const _WorkItemActions({required this.item});

  final HrWorkItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceState? state = readHrWorkspaceState(ref);
    final bool enabled = state?.isMutating != true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppInfoTileGrid(
          emptyValue: l10n.profileUnknownValue,
          items: <AppInfoTileData>[
            AppInfoTileData(
              label: l10n.hrQueueItemColumnLabel,
              value: item.effectiveId,
              icon: Icons.confirmation_number_outlined,
              copyable: true,
            ),
            AppInfoTileData(
              label: l10n.hrQueueColumnLabel,
              value: hrQueueLabel(l10n, item.queue),
              icon: hrQueueIcon(item.queue),
            ),
            AppInfoTileData(
              label: l10n.hrStatusColumnLabel,
              value: _apiLabel(context, item.status),
              icon: Icons.radio_button_checked,
            ),
            AppInfoTileData(
              label: l10n.hrPeriodColumnLabel,
              value: _workItemPeriod(context, item),
              icon: Icons.date_range_outlined,
            ),
          ],
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        AppQuickActions(
          title: context.l10n.patientsQuickActionsTitle,
          permissionActions: _workItemActions(context, ref, item, enabled),
        ),
      ],
    );
  }

  List<AppPermissionActionItem> _workItemActions(
    BuildContext context,
    WidgetRef ref,
    HrWorkItem item,
    bool enabled,
  ) {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    return switch (item.queue) {
      HrQueue.leaveRequests => <AppPermissionActionItem>[
        AppPermissionActionItem(
          requirement: HrLeaveRequestsAtomPermissions.approveLeave,
          label: l10n.hrApproveLeaveAction,
          icon: Icons.check_circle_outline,
          enabled: enabled,
          onPressed: () => _submitReason(
            context,
            title: l10n.hrApproveLeaveDialogTitle,
            submitLabel: l10n.hrApproveLeaveAction,
            requiredReason: false,
            onSubmit: (String? reason) =>
                controller.approveLeave(item, reason: reason),
          ),
        ),
        AppPermissionActionItem(
          requirement: HrLeaveRequestsAtomPermissions.rejectLeave,
          label: l10n.hrRejectLeaveAction,
          icon: Icons.cancel_outlined,
          enabled: enabled,
          onPressed: () => _submitReason(
            context,
            title: l10n.hrRejectLeaveDialogTitle,
            submitLabel: l10n.hrRejectLeaveAction,
            requiredReason: true,
            onSubmit: (String? reason) =>
                controller.rejectLeave(item, reason: reason ?? ''),
          ),
        ),
      ],
      HrQueue.swapRequests => <AppPermissionActionItem>[
        AppPermissionActionItem(
          requirement: HrShiftsAtomPermissions.approveSwap,
          label: l10n.hrApproveSwapAction,
          icon: Icons.check_circle_outline,
          enabled: enabled,
          onPressed: () => _submitReason(
            context,
            title: l10n.hrApproveSwapDialogTitle,
            submitLabel: l10n.hrApproveSwapAction,
            requiredReason: false,
            onSubmit: (String? reason) =>
                controller.approveSwap(item, reason: reason),
          ),
        ),
        AppPermissionActionItem(
          requirement: HrShiftsAtomPermissions.rejectSwap,
          label: l10n.hrRejectSwapAction,
          icon: Icons.cancel_outlined,
          enabled: enabled,
          onPressed: () => _submitReason(
            context,
            title: l10n.hrRejectSwapDialogTitle,
            submitLabel: l10n.hrRejectSwapAction,
            requiredReason: true,
            onSubmit: (String? reason) =>
                controller.rejectSwap(item, reason: reason ?? ''),
          ),
        ),
      ],
      HrQueue.rosterDrafts => <AppPermissionActionItem>[
        AppPermissionActionItem(
          requirement: HrShiftsAtomPermissions.previewRoster,
          label: l10n.hrPreviewRosterAction,
          icon: Icons.visibility_outlined,
          enabled: enabled,
          onPressed: () => showHrPreviewRosterDialog(context, ref, item),
        ),
        AppPermissionActionItem(
          requirement: HrShiftsAtomPermissions.generateRoster,
          label: l10n.hrGenerateRosterAction,
          icon: Icons.auto_awesome_outlined,
          enabled: enabled,
          onPressed: () =>
              _submitSimple(context, controller.generateRoster(item)),
        ),
        AppPermissionActionItem(
          requirement: HrShiftsAtomPermissions.publishRoster,
          label: l10n.hrPublishRosterAction,
          icon: Icons.publish_outlined,
          enabled: enabled,
          onPressed: () => _showRosterPublishDialog(context, controller, item),
        ),
      ],
      HrQueue.unassignedShifts ||
      HrQueue.overdueShifts => <AppPermissionActionItem>[
        AppPermissionActionItem(
          requirement: HrShiftsAtomPermissions.overrideShift,
          label: l10n.hrOverrideShiftAction,
          icon: Icons.manage_accounts_outlined,
          enabled: enabled,
          onPressed: () => _showOverrideShiftDialog(context, ref, item),
        ),
      ],
      HrQueue.payrollDrafts => <AppPermissionActionItem>[
        AppPermissionActionItem(
          requirement: HrPayrollDraftsAtomPermissions.preview,
          label: l10n.hrPreviewPayrollAction,
          icon: Icons.receipt_long_outlined,
          enabled: enabled,
          onPressed: () => showHrPreviewPayrollDialog(context, ref, item),
        ),
        AppPermissionActionItem(
          requirement: HrPayrollDraftsAtomPermissions.process,
          label: l10n.hrProcessPayrollAction,
          icon: Icons.price_check_outlined,
          enabled: enabled,
          onPressed: () => _showProcessPayrollDialog(context, controller, item),
        ),
      ],
    };
  }
}

Future<void> _submitReason(
  BuildContext context, {
  required String title,
  required String submitLabel,
  required bool requiredReason,
  required Future<AppFailure?> Function(String? reason) onSubmit,
}) async {
  final AppLocalizations l10n = context.l10n;
  final GlobalKey<HrReasonFieldsState> fieldsKey =
      GlobalKey<HrReasonFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(title),
    icon: const Icon(Icons.notes_outlined),
    submitLabel: submitLabel,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return HrReasonFields(key: fieldsKey, requiredReason: requiredReason);
        },
    onSubmit: () => onSubmit(fieldsKey.currentState?.reason),
  );
  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
}

Future<void> _showRosterPublishDialog(
  BuildContext context,
  HrWorkspaceController controller,
  HrWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final GlobalKey<HrRosterPublishFieldsState> fieldsKey =
      GlobalKey<HrRosterPublishFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrPublishRosterDialogTitle),
    icon: const Icon(Icons.publish_outlined),
    submitLabel: l10n.hrPublishRosterAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.publish_outlined,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return HrRosterPublishFields(key: fieldsKey);
        },
    onSubmit: () {
      final Map<String, Object?> payload =
          fieldsKey.currentState?.toPayload() ?? <String, Object?>{};
      return controller.publishRoster(
        item,
        notifyStaff: payload['notify_staff'] == true,
        allowPartialPublish: payload['allow_partial_publish'] == true,
        publishNote: payload['publish_note']?.toString(),
      );
    },
  );
  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
}

Future<void> _showOverrideShiftDialog(
  BuildContext context,
  WidgetRef ref,
  HrWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = readHrWorkspaceState(ref);
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final GlobalKey<HrOverrideShiftFieldsState> fieldsKey =
      GlobalKey<HrOverrideShiftFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrOverrideShiftDialogTitle),
    icon: const Icon(Icons.manage_accounts_outlined),
    submitLabel: l10n.hrOverrideShiftAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return HrOverrideShiftFields(
            key: fieldsKey,
            referenceData: state?.referenceData ?? const HrReferenceData(),
          );
        },
    onSubmit: () {
      final Map<String, Object?> payload =
          fieldsKey.currentState?.toPayload() ?? <String, Object?>{};
      return controller.overrideShift(
        item,
        staffProfileId: payload['staff_profile_id']?.toString() ?? '',
        reason: payload['reason']?.toString() ?? '',
      );
    },
  );
  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
}

Future<void> _showProcessPayrollDialog(
  BuildContext context,
  HrWorkspaceController controller,
  HrWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final GlobalKey<HrProcessPayrollFieldsState> fieldsKey =
      GlobalKey<HrProcessPayrollFieldsState>();
  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrProcessPayrollDialogTitle),
    icon: const Icon(Icons.price_check_outlined),
    submitLabel: l10n.hrProcessPayrollAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.price_check_outlined,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return HrProcessPayrollFields(key: fieldsKey);
        },
    onSubmit: () {
      final Map<String, Object?> payload =
          fieldsKey.currentState?.toPayload() ?? <String, Object?>{};
      return controller.processPayrollRun(
        item,
        replaceExistingItems: payload['replace_existing_items'] == true,
        notes: payload['notes']?.toString(),
      );
    },
  );
  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
}

Future<void> _submitSimple(
  BuildContext context,
  Future<AppFailure?> mutation,
) async {
  final AppFailure? failure = await mutation;
  if (context.mounted) {
    showHrMutationSnackBar(context, failure);
  }
}

HrWorkspaceState? _hrStateFromAsync(
  AsyncValue<Result<HrWorkspaceState>> asyncState,
) {
  return asyncState.asData?.value.when(
    success: (HrWorkspaceState state) => state,
    failure: (_) => null,
  );
}

String _sectionLabel(AppLocalizations l10n, HrDeskSection section) {
  return switch (section) {
    HrDeskSection.staffDirectory => l10n.hrStaffMembersSummaryLabel,
    HrDeskSection.positions => l10n.hrPositionsTabLabel,
    HrDeskSection.leaveRequests => l10n.hrLeaveRequestsSummaryLabel,
    HrDeskSection.swapRequests => l10n.hrQueueSwapRequests,
    HrDeskSection.shiftRoster => l10n.hrQueueRosterDrafts,
    HrDeskSection.unassignedShifts => l10n.hrQueueUnassignedShifts,
    HrDeskSection.payroll => l10n.hrPayrollDraftsSummaryLabel,
    HrDeskSection.access => l10n.hrManageAccessAction,
  };
}

IconData _sectionIcon(HrDeskSection section) {
  return switch (section) {
    HrDeskSection.staffDirectory => Icons.people_outlined,
    HrDeskSection.positions => Icons.work_outline,
    HrDeskSection.leaveRequests => Icons.event_busy_outlined,
    HrDeskSection.swapRequests => Icons.swap_horiz_outlined,
    HrDeskSection.shiftRoster => Icons.calendar_month_outlined,
    HrDeskSection.unassignedShifts => Icons.pending_actions_outlined,
    HrDeskSection.payroll => Icons.payments_outlined,
    HrDeskSection.access => Icons.manage_accounts_outlined,
  };
}

int _sectionCount(HrWorkspaceState state, HrDeskSection section) {
  final HrWorkspaceSummary summary = state.overview.summary;
  return switch (section) {
    HrDeskSection.staffDirectory =>
      state.staff.totalItemCount ?? state.staff.items.length,
    HrDeskSection.positions => state.positionsTotalCount,
    HrDeskSection.leaveRequests => summary.leaveRequests,
    HrDeskSection.swapRequests => summary.swapRequests,
    HrDeskSection.shiftRoster => summary.draftRosters,
    HrDeskSection.unassignedShifts =>
      summary.unassignedShifts + summary.overdueShifts,
    HrDeskSection.payroll => summary.payrollDraftRuns,
    HrDeskSection.access => 0,
  };
}

AppTabCountTone _sectionCountTone(HrDeskSection section) {
  return switch (section) {
    HrDeskSection.unassignedShifts => AppTabCountTone.danger,
    HrDeskSection.leaveRequests ||
    HrDeskSection.swapRequests => AppTabCountTone.warning,
    HrDeskSection.staffDirectory ||
    HrDeskSection.positions ||
    HrDeskSection.shiftRoster ||
    HrDeskSection.payroll ||
    HrDeskSection.access => AppTabCountTone.info,
  };
}

String _workItemTitle(BuildContext context, HrWorkItem item) {
  final AppLocalizations l10n = context.l10n;
  return switch (item.queue) {
    HrQueue.leaveRequests => hrJoinDisplay(<String?>[
      item.leaveType == null ? null : _apiLabel(context, item.leaveType),
      item.staffName,
      item.staffNumber,
    ]).ifEmpty(l10n.hrLeaveRequestTitle),
    HrQueue.swapRequests => hrJoinDisplay(<String?>[
      item.shiftType == null ? null : _apiLabel(context, item.shiftType),
      item.shiftId,
      item.staffNumber,
    ]).ifEmpty(l10n.hrSwapRequestTitle),
    HrQueue.rosterDrafts => hrJoinDisplay(<String?>[
      item.rosterName,
      item.periodLabel,
      item.rosterId,
    ]).ifEmpty(l10n.hrRosterDraftTitle),
    HrQueue.unassignedShifts || HrQueue.overdueShifts => hrJoinDisplay(
      <String?>[
        item.shiftType == null ? null : _apiLabel(context, item.shiftType),
        item.shiftId,
      ],
    ).ifEmpty(l10n.hrShiftQueueTitle),
    HrQueue.payrollDrafts => hrJoinDisplay(<String?>[
      item.periodLabel,
      item.payrollRunId ?? item.displayId,
    ]).ifEmpty(l10n.hrPayrollDraftTitle),
  };
}

String _workItemNextAction(BuildContext context, HrWorkItem item) {
  final AppLocalizations l10n = context.l10n;
  return switch (item.queue) {
    HrQueue.leaveRequests => l10n.hrApproveLeaveAction,
    HrQueue.swapRequests => l10n.hrApproveSwapAction,
    HrQueue.rosterDrafts => l10n.hrPublishRosterAction,
    HrQueue.unassignedShifts ||
    HrQueue.overdueShifts => l10n.hrOverrideShiftAction,
    HrQueue.payrollDrafts => l10n.hrProcessPayrollAction,
  };
}

String _workItemPeriod(BuildContext context, HrWorkItem item) {
  if ((item.periodLabel ?? '').trim().isNotEmpty) {
    return item.periodLabel!;
  }
  return hrDateRange(
    context,
    item.startAt,
    item.endAt,
  ).ifEmpty(context.l10n.profileUnknownValue);
}

String _apiLabel(BuildContext context, String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return '';
  }
  final AppLocalizations l10n = context.l10n;
  final String practitioner = l10n.hrReferencePractitionerTypeLabel(
    normalized,
    fallback: '',
  );
  if (practitioner.isNotEmpty && practitioner != normalized) {
    return practitioner;
  }
  final String payType = l10n.hrReferenceCompensationPayTypeLabel(
    normalized,
    fallback: '',
  );
  if (payType.isNotEmpty && payType != normalized) {
    return payType;
  }
  final String leaveType = l10n.hrReferenceLeaveTypeLabel(
    normalized,
    fallback: '',
  );
  if (leaveType.isNotEmpty && leaveType != normalized) {
    return leaveType;
  }
  final String halfDayPeriod = l10n.hrReferenceLeaveHalfDayPeriodLabel(
    normalized,
    fallback: '',
  );
  if (halfDayPeriod.isNotEmpty && halfDayPeriod != normalized) {
    return halfDayPeriod;
  }
  return normalized
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return lower.substring(0, 1).toUpperCase() + lower.substring(1);
      })
      .join(' ');
}

AppWorkspaceStatusTone _statusTone(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'ACTIVE' ||
    'APPROVED' ||
    'COMPLETED' ||
    'PUBLISHED' ||
    'PROCESSED' ||
    'PAID' => AppWorkspaceStatusTone.success,
    'REQUESTED' ||
    'DRAFT' ||
    'SCHEDULED' ||
    'PENDING' => AppWorkspaceStatusTone.warning,
    'REJECTED' ||
    'CANCELLED' ||
    'SUSPENDED' ||
    'INACTIVE' => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

const String _hrWorkItemStatusFilterKey = 'status';
const String _hrWorkItemQueueFilterKey = 'queue';

List<AppListTableColumn<HrWorkItem>> _workQueueColumns(
  BuildContext context,
  HrQueue queue, {
  required void Function(HrWorkItem item) onNextAction,
  Set<String>? selectedRosterKeys,
  ValueChanged<Set<String>>? onRosterSelectionChanged,
  List<HrWorkItem>? visibleRosterItems,
  ValueChanged<HrWorkItem>? onEditRoster,
  ValueChanged<HrWorkItem>? onDeleteRoster,
  ValueChanged<HrWorkItem>? onRestoreRoster,
  ValueChanged<HrWorkItem>? onPermanentDeleteRoster,
  bool canWriteRosters = false,
  bool isMutating = false,
}) {
  final AppLocalizations l10n = context.l10n;
  final List<AppListTableColumn<HrWorkItem>> dataColumns = switch (queue) {
    HrQueue.leaveRequests => <AppListTableColumn<HrWorkItem>>[
      _workItemLeaveTypeColumn(l10n, context),
      _workItemStaffColumn(l10n),
      _workItemPeriodColumn(l10n, context),
    ],
    HrQueue.swapRequests => <AppListTableColumn<HrWorkItem>>[
      _workItemShiftTypeColumn(l10n, context),
      _workItemStaffColumn(l10n),
      _workItemPeriodColumn(l10n, context),
    ],
    HrQueue.rosterDrafts => <AppListTableColumn<HrWorkItem>>[
      if (selectedRosterKeys != null &&
          onRosterSelectionChanged != null &&
          visibleRosterItems != null)
        _workItemRosterSelectColumn(
          l10n,
          visibleItems: visibleRosterItems,
          selectedKeys: selectedRosterKeys,
          onSelectionChanged: onRosterSelectionChanged,
          enabled: canWriteRosters && !isMutating,
        ),
      _workItemRosterColumn(l10n, context),
      _workItemAssignmentsColumn(l10n),
      _workItemRecurringColumn(l10n),
    ],
    HrQueue.unassignedShifts ||
    HrQueue.overdueShifts => <AppListTableColumn<HrWorkItem>>[
      _workItemShiftTypeColumn(l10n, context),
      _workItemShiftIdColumn(l10n),
      _workItemPeriodColumn(l10n, context),
    ],
    HrQueue.payrollDrafts => <AppListTableColumn<HrWorkItem>>[
      _workItemPayrollColumn(l10n, context),
      _workItemPayrollRunColumn(l10n),
      _workItemPeriodColumn(l10n, context),
    ],
  };

  if (queue == HrQueue.rosterDrafts) {
    return <AppListTableColumn<HrWorkItem>>[
      ...dataColumns,
      _workItemStatusColumn(l10n),
      _workItemRosterActionsColumn(
        l10n,
        canWrite: canWriteRosters,
        isMutating: isMutating,
        onEdit: onEditRoster,
        onDelete: onDeleteRoster,
        onRestore: onRestoreRoster,
        onPermanentDelete: onPermanentDeleteRoster,
      ),
    ];
  }

  return <AppListTableColumn<HrWorkItem>>[
    ...dataColumns,
    _workItemStatusColumn(l10n),
    _workItemNextActionColumn(l10n, context, onNextAction: onNextAction),
  ];
}

List<AppListTableColumn<HrWorkItem>> _workQueueColumnChoices(
  BuildContext context,
  HrQueue queue,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppListTableColumn<HrWorkItem>>[
    AppListTableColumn<HrWorkItem>(
      id: 'queue',
      label: l10n.hrQueueColumnLabel,
      sortComparator: (HrWorkItem left, HrWorkItem right) =>
          appListTableCompareText(left.queue.value, right.queue.value),
      cellBuilder: (BuildContext context, HrWorkItem item) {
        return Text(hrQueueLabel(context.l10n, item.queue));
      },
    ),
    AppListTableColumn<HrWorkItem>(
      id: 'staff_position',
      label: l10n.hrPositionLabel,
      sortComparator: (HrWorkItem left, HrWorkItem right) =>
          appListTableCompareText(left.staffPosition, right.staffPosition),
      cellBuilder: (BuildContext context, HrWorkItem item) {
        return Text(
          (item.staffPosition ?? '').trim().isNotEmpty
              ? item.staffPosition!
              : context.l10n.profileUnknownValue,
        );
      },
    ),
    AppListTableColumn<HrWorkItem>(
      id: 'reason',
      label: l10n.hrReasonLabel,
      sortComparator: (HrWorkItem left, HrWorkItem right) =>
          appListTableCompareText(left.reason, right.reason),
      cellBuilder: (BuildContext context, HrWorkItem item) {
        return Text(
          (item.reason ?? '').trim().isNotEmpty
              ? item.reason!
              : context.l10n.profileUnknownValue,
        );
      },
    ),
    AppListTableColumn<HrWorkItem>(
      id: 'effective_id',
      label: l10n.hrQueueItemColumnLabel,
      sortComparator: (HrWorkItem left, HrWorkItem right) =>
          appListTableCompareText(left.effectiveId, right.effectiveId),
      cellBuilder: (BuildContext context, HrWorkItem item) {
        return AppCopyableIdentifierCell(
          title: item.effectiveId,
          identifier: item.displayId,
        );
      },
    ),
  ];
}

AppListTableColumn<HrWorkItem> _workItemLeaveTypeColumn(
  AppLocalizations l10n,
  BuildContext context,
) {
  return AppListTableColumn<HrWorkItem>(
    id: 'leave_type',
    label: l10n.hrLeaveTypeLabel,
    sortComparator: (HrWorkItem left, HrWorkItem right) =>
        appListTableCompareText(left.leaveType, right.leaveType),
    cellBuilder: (BuildContext context, HrWorkItem item) {
      return Text(
        _apiLabel(
          context,
          item.leaveType,
        ).ifEmpty(context.l10n.profileUnknownValue),
      );
    },
  );
}

AppListTableColumn<HrWorkItem> _workItemStaffColumn(AppLocalizations l10n) {
  return AppListTableColumn<HrWorkItem>(
    id: 'staff',
    label: l10n.hrStaffColumnLabel,
    sortComparator: (HrWorkItem left, HrWorkItem right) =>
        appListTableCompareText(left.staffName, right.staffName),
    cellBuilder: (BuildContext context, HrWorkItem item) {
      final ThemeData theme = Theme.of(context);
      return AppListItemText(
        title: (item.staffName ?? '').trim().isNotEmpty
            ? item.staffName!
            : context.l10n.profileUnknownValue,
        subtitle: item.staffNumber,
        titleStyle: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: AppFontWeight.emphasis,
        ),
      );
    },
  );
}

AppListTableColumn<HrWorkItem> _workItemPeriodColumn(
  AppLocalizations l10n,
  BuildContext context,
) {
  return AppListTableColumn<HrWorkItem>(
    id: 'period',
    label: l10n.hrPeriodColumnLabel,
    sortComparator: (HrWorkItem left, HrWorkItem right) =>
        appListTableCompareDateTime(left.startAt, right.startAt),
    cellBuilder: (BuildContext context, HrWorkItem item) {
      return Text(_workItemPeriod(context, item));
    },
  );
}

AppListTableColumn<HrWorkItem> _workItemShiftTypeColumn(
  AppLocalizations l10n,
  BuildContext context,
) {
  return AppListTableColumn<HrWorkItem>(
    id: 'shift',
    label: l10n.hrShiftTypeLabel,
    sortComparator: (HrWorkItem left, HrWorkItem right) =>
        appListTableCompareText(left.shiftType, right.shiftType),
    cellBuilder: (BuildContext context, HrWorkItem item) {
      return Text(
        _apiLabel(
          context,
          item.shiftType,
        ).ifEmpty(context.l10n.profileUnknownValue),
      );
    },
  );
}

AppListTableColumn<HrWorkItem> _workItemShiftIdColumn(AppLocalizations l10n) {
  return AppListTableColumn<HrWorkItem>(
    id: 'shift_id',
    label: l10n.hrShiftIdLabel,
    sortComparator: (HrWorkItem left, HrWorkItem right) =>
        appListTableCompareText(left.shiftId, right.shiftId),
    cellBuilder: (BuildContext context, HrWorkItem item) {
      return AppCopyableIdentifierCell(
        title: (item.shiftId ?? '').trim().isNotEmpty
            ? item.shiftId!
            : context.l10n.profileUnknownValue,
        identifier: item.effectiveId,
      );
    },
  );
}

AppListTableColumn<HrWorkItem> _workItemRosterSelectColumn(
  AppLocalizations l10n, {
  required List<HrWorkItem> visibleItems,
  required Set<String> selectedKeys,
  required ValueChanged<Set<String>> onSelectionChanged,
  required bool enabled,
}) {
  String keyOf(HrWorkItem item) =>
      (item.rosterId ?? item.backendIdentifier ?? item.effectiveId).trim();

  List<String> keysFor(List<HrWorkItem> items) => <String>[
    for (final HrWorkItem item in items)
      if (keyOf(item).isNotEmpty) keyOf(item),
  ];

  return AppListTableColumn<HrWorkItem>(
    id: 'select',
    label: l10n.hrRosterSelectAllAction,
    alwaysVisible: true,
    fixedWidth: 48,
    headerBuilder: (BuildContext context) {
      // Resolve against the latest selection inside the builder so the header
      // stays in sync when only the Set contents change.
      final List<String> visibleKeys = keysFor(visibleItems);
      final bool allSelected =
          visibleKeys.isNotEmpty && visibleKeys.every(selectedKeys.contains);
      final bool someSelected = visibleKeys.any(selectedKeys.contains);
      final bool? checkboxValue = allSelected
          ? true
          : someSelected
          ? null
          : false;

      return Center(
        child: Checkbox(
          key: ValueKey<String>(
            'roster-select-all-${checkboxValue ?? 'partial'}-${selectedKeys.length}',
          ),
          tristate: true,
          visualDensity: VisualDensity.compact,
          value: checkboxValue,
          semanticLabel: l10n.hrRosterSelectAllAction,
          onChanged: !enabled || visibleKeys.isEmpty
              ? null
              : (bool? _) {
                  // Ignore Material's false→true→null cycle. From any non-all
                  // state (none / indeterminate), select all; from all, clear.
                  final Set<String> next = Set<String>.from(selectedKeys);
                  if (allSelected) {
                    next.removeAll(visibleKeys);
                  } else {
                    next.addAll(visibleKeys);
                  }
                  onSelectionChanged(next);
                },
        ),
      );
    },
    cellBuilder: (BuildContext context, HrWorkItem item) {
      final String key = keyOf(item);
      final bool selected = key.isNotEmpty && selectedKeys.contains(key);
      return Center(
        child: Checkbox(
          visualDensity: VisualDensity.compact,
          value: selected,
          onChanged: !enabled || key.isEmpty
              ? null
              : (bool? value) {
                  final Set<String> next = Set<String>.from(selectedKeys);
                  if (value == true) {
                    next.add(key);
                  } else {
                    next.remove(key);
                  }
                  onSelectionChanged(next);
                },
        ),
      );
    },
  );
}

AppListTableColumn<HrWorkItem> _workItemRosterActionsColumn(
  AppLocalizations l10n, {
  required bool canWrite,
  required bool isMutating,
  ValueChanged<HrWorkItem>? onEdit,
  ValueChanged<HrWorkItem>? onDelete,
  ValueChanged<HrWorkItem>? onRestore,
  ValueChanged<HrWorkItem>? onPermanentDelete,
}) {
  return AppListTableColumn<HrWorkItem>(
    id: 'actions',
    label: l10n.hrRosterActionsColumnLabel,
    alwaysVisible: true,
    preferredWidth: 220,
    cellBuilder: (BuildContext context, HrWorkItem item) {
      final ThemeData theme = Theme.of(context);
      final bool deleted =
          (item.status ?? '').trim().toUpperCase() == 'DELETED';
      final bool enabled = canWrite && !isMutating;
      if (!canWrite) {
        return const SizedBox.shrink();
      }
      final double gap = theme.spacing.xs;

      if (deleted) {
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            AppButton.tertiary(
              leadingIcon: Icons.restore_outlined,
              label: l10n.hrRosterRestoreAction,
              tooltip: l10n.hrRosterRestoreAction,
              dense: true,
              enabled: enabled,
              onPressed: enabled && onRestore != null
                  ? () => onRestore(item)
                  : null,
            ),
            AppButton.tertiary(
              leadingIcon: Icons.delete_forever_outlined,
              label: l10n.hrRosterPermanentDeleteAction,
              tooltip: l10n.hrRosterPermanentDeleteAction,
              dense: true,
              color: theme.colorScheme.error,
              enabled: enabled,
              onPressed: enabled && onPermanentDelete != null
                  ? () => onPermanentDelete(item)
                  : null,
            ),
          ],
        );
      }

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          AppButton.tertiary(
            leadingIcon: Icons.edit_outlined,
            label: l10n.commonEditActionLabel,
            tooltip: l10n.hrRosterEditDialogTitle,
            dense: true,
            enabled: enabled,
            onPressed: enabled && onEdit != null ? () => onEdit(item) : null,
          ),
          AppButton.tertiary(
            leadingIcon: Icons.delete_outline,
            label: l10n.hrRosterDeleteAction,
            tooltip: l10n.hrRosterDeleteAction,
            dense: true,
            color: theme.colorScheme.error,
            enabled: enabled,
            onPressed: enabled && onDelete != null ? () => onDelete(item) : null,
          ),
        ],
      );
    },
  );
}

AppListTableColumn<HrWorkItem> _workItemRosterColumn(
  AppLocalizations l10n,
  BuildContext context,
) {
  return AppListTableColumn<HrWorkItem>(
    id: 'roster',
    label: l10n.hrRosterDraftTitle,
    sortComparator: (HrWorkItem left, HrWorkItem right) =>
        appListTableCompareText(
          left.rosterName ?? left.periodLabel,
          right.rosterName ?? right.periodLabel,
        ),
    cellBuilder: (BuildContext context, HrWorkItem item) {
      return AppCopyableIdentifierCell(
        title: (item.rosterName ?? item.periodLabel ?? item.rosterId ?? '')
            .ifEmpty(context.l10n.hrRosterDraftTitle),
        identifier: item.rosterId ?? item.effectiveId,
      );
    },
  );
}

AppListTableColumn<HrWorkItem> _workItemRecurringColumn(AppLocalizations l10n) {
  return AppListTableColumn<HrWorkItem>(
    id: 'recurring',
    label: l10n.hrRosterRecurringLabel,
    sortComparator: (HrWorkItem left, HrWorkItem right) =>
        appListTableCompareNumber(
          left.isRecurring ? 1 : 0,
          right.isRecurring ? 1 : 0,
        ),
    cellBuilder: (BuildContext context, HrWorkItem item) {
      return Text(
        item.isRecurring
            ? context.l10n.commonYesLabel
            : context.l10n.commonNoLabel,
      );
    },
  );
}

AppListTableColumn<HrWorkItem> _workItemAssignmentsColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<HrWorkItem>(
    id: 'assignments',
    label: l10n.hrAssignmentsSectionTitle,
    sortComparator: (HrWorkItem left, HrWorkItem right) =>
        appListTableCompareNumber(left.assignmentCount, right.assignmentCount),
    cellBuilder: (BuildContext context, HrWorkItem item) {
      return Text(item.assignmentCount.toString());
    },
  );
}

AppListTableColumn<HrWorkItem> _workItemPayrollColumn(
  AppLocalizations l10n,
  BuildContext context,
) {
  return AppListTableColumn<HrWorkItem>(
    id: 'payroll',
    label: l10n.hrPayrollDraftTitle,
    sortComparator: (HrWorkItem left, HrWorkItem right) =>
        appListTableCompareText(left.periodLabel, right.periodLabel),
    cellBuilder: (BuildContext context, HrWorkItem item) {
      return Text(
        (item.periodLabel ?? '').trim().isNotEmpty
            ? item.periodLabel!
            : context.l10n.profileUnknownValue,
      );
    },
  );
}

AppListTableColumn<HrWorkItem> _workItemPayrollRunColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<HrWorkItem>(
    id: 'run_id',
    label: l10n.hrPayrollRunDialogTitle,
    sortComparator: (HrWorkItem left, HrWorkItem right) =>
        appListTableCompareText(left.payrollRunId, right.payrollRunId),
    cellBuilder: (BuildContext context, HrWorkItem item) {
      return AppCopyableIdentifierCell(
        title: item.payrollRunId ?? item.displayId ?? item.effectiveId,
        identifier: item.effectiveId,
      );
    },
  );
}

AppListTableColumn<HrWorkItem> _workItemStatusColumn(AppLocalizations l10n) {
  return AppListTableColumn<HrWorkItem>(
    id: 'status',
    label: l10n.hrStatusColumnLabel,
    sortComparator: (HrWorkItem left, HrWorkItem right) =>
        appListTableCompareText(left.status, right.status),
    cellBuilder: (BuildContext context, HrWorkItem item) {
      if (item.queue == HrQueue.rosterDrafts) {
        return _StatusBadge(
          status: hrRosterStatusLabel(context.l10n, item.status),
        );
      }
      return _StatusBadge(status: item.status);
    },
  );
}

AppListTableColumn<HrWorkItem> _workItemNextActionColumn(
  AppLocalizations l10n,
  BuildContext context, {
  required void Function(HrWorkItem item) onNextAction,
}) {
  return AppListTableColumn<HrWorkItem>(
    id: 'next_action',
    label: l10n.hrNextActionColumnLabel,
    alwaysVisible: true,
    cellBuilder: (BuildContext context, HrWorkItem item) {
      final AccessRequirement requirement = switch (item.queue) {
        HrQueue.leaveRequests => HrLeaveRequestsAtomPermissions.approveLeave,
        HrQueue.swapRequests => HrShiftsAtomPermissions.approveSwap,
        HrQueue.rosterDrafts => HrShiftsAtomPermissions.publishRoster,
        HrQueue.unassignedShifts ||
        HrQueue.overdueShifts => HrShiftsAtomPermissions.overrideShift,
        HrQueue.payrollDrafts => HrPayrollDraftsAtomPermissions.nextAction,
      };
      return AppAccessActionGate(
        requirement: requirement,
        builder: (BuildContext context, bool isAllowed) {
          return AppButton.tertiary(
            label: _workItemNextAction(context, item),
            enabled: isAllowed,
            onPressed: isAllowed ? () => onNextAction(item) : null,
          );
        },
      );
    },
  );
}

List<AppSearchBarFilterChoice> _workItemStatusFilterChoices(
  BuildContext context,
) {
  return <AppSearchBarFilterChoice>[
    for (final String status in <String>[
      'REQUESTED',
      'APPROVED',
      'REJECTED',
      'DRAFT',
      'PUBLISHED',
      'DELETED',
      'COMPLETED',
      'PROCESSED',
      'PAID',
      'ACTIVE',
    ])
      AppSearchBarFilterChoice(
        value: status,
        label: _apiLabel(context, status),
        icon: Icons.radio_button_checked,
      ),
  ];
}

AppSearchBarFilterValue _workItemFilterValue(
  HrWorkItemsQuery query, {
  required bool includeQueue,
  required HrQueue defaultQueue,
}) {
  // Only emit non-default queue so Filters chrome stays inactive on the
  // section default (avoids a permanent "Filters (1)" badge/tooltip).
  return AppSearchBarFilterValue(
    options: <String, String>{
      if (includeQueue && query.queue != defaultQueue)
        _hrWorkItemQueueFilterKey: query.queue.value,
      if (query.status != null) _hrWorkItemStatusFilterKey: query.status!,
    },
  );
}

bool _hasWorkItemFilters(
  HrWorkItemsQuery query, {
  required HrQueue defaultQueue,
  required bool includeQueue,
}) {
  final bool nonDefaultQueue =
      includeQueue && query.queue != defaultQueue;
  return nonDefaultQueue || query.status != null;
}

extension on String {
  String ifEmpty(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}
