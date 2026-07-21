import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_lookups.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/presentation/controllers/radiology_workspace_controller.dart';
import 'package:hosspi_hms/features/radiology/presentation/widgets/radiology_next_action_cell.dart';
import 'package:hosspi_hms/features/radiology/presentation/widgets/radiology_workflow_progress_section.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_radiology_catalog_helpers.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_radiology_order_action_dialog.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/facility_catalog/facility_catalog_scope_section.dart';
import 'package:hosspi_hms/shared/follow_up/follow_up_worklist_panel.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/print_form_template.dart';
import 'package:hosspi_hms/shared/radiology_catalog/radiology_catalog_dialogs.dart';

part 'radiology_workspace_page.configurations.dart';
part 'radiology_workspace_page.detail_cells.dart';
part 'radiology_workspace_page.print.dart';

typedef _RadiologyResultMutation =
    Future<AppFailure?> Function(
      RadiologyResult result,
      Map<String, Object?> payload,
    );

class RadiologyWorkspacePage extends ConsumerWidget {
  const RadiologyWorkspacePage({this.initialQuery, super.key});

  final RadiologyWorkspaceQuery? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<RadiologyWorkspaceState>> workspace = ref.watch(
      radiologyWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<RadiologyWorkspaceState>(
      value: workspace,
      loadingTitle: l10n.radiologyLoadingTitle,
      loadingBody: l10n.radiologyLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      deferLoadingToShell: false,
      keepPreviousDataDuringRefresh: true,
      onRetry: () {
        ref.read(radiologyWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, RadiologyWorkspaceState state) {
        return _RadiologyWorkspaceContent(
          state: state,
          initialQuery: initialQuery,
        );
      },
    );
  }
}

class _RadiologyWorkspaceContent extends ConsumerStatefulWidget {
  const _RadiologyWorkspaceContent({required this.state, this.initialQuery});

  final RadiologyWorkspaceState state;
  final RadiologyWorkspaceQuery? initialQuery;

  @override
  ConsumerState<_RadiologyWorkspaceContent> createState() =>
      _RadiologyWorkspaceContentState();
}

class _RadiologyWorkspaceContentState
    extends ConsumerState<_RadiologyWorkspaceContent> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 220);

  static const AccessRequirement _requestRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.clinicalWrite,
      AppPermissions.radiologyWrite,
    ],
  );

  static const AccessRequirement _workRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[AppPermissions.radiologyWrite],
  );

  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<RadiologyOrder>
  _tableColumnController;
  Timer? _searchDebounce;
  String? _appliedRouteSignature;
  late RadiologyDeskSection _section;

  @override
  void initState() {
    super.initState();
    _section =
        _sectionFromQuery(widget.initialQuery?.section ?? '') ??
        RadiologyDeskSection.worklist;
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<RadiologyOrder>();
    _scheduleRouteQuery(widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant _RadiologyWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String search = widget.state.query.search;
    if (_searchController.text != search) {
      _searchController.value = TextEditingValue(text: search);
    }
    if (oldWidget.initialQuery?.signature != widget.initialQuery?.signature) {
      _scheduleRouteQuery(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _tableColumnController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      _applySearchNow(value);
    });
  }

  void _applySearchNow(String value) {
    _searchDebounce?.cancel();
    unawaited(
      ref
          .read(radiologyWorkspaceControllerProvider.notifier)
          .applySearch(value),
    );
  }

  void _scheduleRouteQuery(RadiologyWorkspaceQuery? query) {
    if (query == null || !query.hasRouteTargeting) return;
    if (_appliedRouteSignature == query.signature) return;
    _appliedRouteSignature = query.signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_applyRouteQuery(query));
    });
  }

  Future<void> _applyRouteQuery(RadiologyWorkspaceQuery query) async {
    final RadiologyDeskSection? section = _sectionFromQuery(query.section);
    if (section != null) {
      setState(() => _section = section);
      _applyStageForSection(section);
    }
    if (query.search.isNotEmpty) {
      _searchController.text = query.search;
      unawaited(
        ref
            .read(radiologyWorkspaceControllerProvider.notifier)
            .applySearch(query.search),
      );
    }
    final String encounterId = query.encounterId ?? '';
    final String orderId = query.orderId ?? '';
    if (encounterId.isNotEmpty || orderId.isNotEmpty) {
      final RadiologyOrder? order = _findOrderByRoute(encounterId, orderId);
      if (order != null) {
        await ref
            .read(radiologyWorkspaceControllerProvider.notifier)
            .selectOrder(order);
      }
    }
  }

  RadiologyOrder? _findOrderByRoute(String encounterId, String orderId) {
    for (final RadiologyOrder order in widget.state.orders.items) {
      if (orderId.isNotEmpty &&
          (order.id == orderId || order.displayId == orderId)) {
        return order;
      }
      if (encounterId.isNotEmpty && order.encounterId == encounterId) {
        return order;
      }
    }
    return null;
  }

  void _updateUrlForSection(RadiologyDeskSection section) {
    if (!mounted) return;
    final String tab = _sectionToQueryValue(section);
    final String location = AppRoutes.radiology.location(
      queryParameters: <String, String>{if (tab.isNotEmpty) 'section': tab},
    );
    GoRouter.of(context).replace<void>(location);
  }

  static String _sectionToQueryValue(RadiologyDeskSection section) {
    return switch (section) {
      RadiologyDeskSection.worklist => 'worklist',
      RadiologyDeskSection.reporting => 'reporting',
      RadiologyDeskSection.released => 'released',
      RadiologyDeskSection.allOrders => 'all',
      RadiologyDeskSection.followUps => 'follow-ups',
    };
  }

  RadiologyDeskSection? _sectionFromQuery(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'worklist':
      case 'work':
        return RadiologyDeskSection.worklist;
      case 'reporting':
      case 'reports':
      case 'draft':
        return RadiologyDeskSection.reporting;
      case 'released':
      case 'completed':
      case 'finalized':
        return RadiologyDeskSection.released;
      case 'all':
      case 'all_orders':
      case 'all-orders':
        return RadiologyDeskSection.allOrders;
      case 'follow-ups':
      case 'follow_ups':
      case 'followups':
        return RadiologyDeskSection.followUps;
      default:
        return null;
    }
  }

  void _applyStageForSection(RadiologyDeskSection section) {
    final RadiologyWorkspaceController controller = ref.read(
      radiologyWorkspaceControllerProvider.notifier,
    );
    switch (section) {
      case RadiologyDeskSection.worklist:
        unawaited(controller.applyStage('ALL'));
      case RadiologyDeskSection.reporting:
        unawaited(controller.applyStage('REPORTING'));
      case RadiologyDeskSection.released:
        unawaited(controller.applyStage('COMPLETED'));
      case RadiologyDeskSection.allOrders:
        unawaited(controller.applyStage('ALL'));
      case RadiologyDeskSection.followUps:
        break;
    }
  }

  String _sectionLabel(AppLocalizations l10n, RadiologyDeskSection section) {
    return switch (section) {
      RadiologyDeskSection.worklist => l10n.radiologyWorklistSummaryLabel,
      RadiologyDeskSection.reporting => l10n.radiologyReportingSummaryLabel,
      RadiologyDeskSection.released => l10n.radiologyReleasedSummaryLabel,
      RadiologyDeskSection.allOrders => l10n.radiologyAllOrdersSummaryLabel,
      RadiologyDeskSection.followUps => l10n.opdFollowUpsTitle,
    };
  }

  static IconData _sectionIcon(RadiologyDeskSection section) {
    return switch (section) {
      RadiologyDeskSection.worklist => Icons.pending_actions_outlined,
      RadiologyDeskSection.reporting => Icons.edit_note_outlined,
      RadiologyDeskSection.released => Icons.verified_outlined,
      RadiologyDeskSection.allOrders => Icons.assignment_outlined,
      RadiologyDeskSection.followUps => Icons.phone_callback_outlined,
    };
  }

  int? _sectionCount(
    RadiologyWorkspaceState state,
    RadiologyDeskSection section,
  ) {
    if (section.isFollowUps) {
      return null;
    }
    return switch (section) {
      RadiologyDeskSection.worklist => state.workloadCount,
      RadiologyDeskSection.reporting => state.reportingCount,
      RadiologyDeskSection.released => state.releasedCount,
      RadiologyDeskSection.allOrders => state.summary.totalForView(
        state.query.view,
      ),
      RadiologyDeskSection.followUps => null,
    };
  }

  static AppTabCountTone _sectionCountTone(RadiologyDeskSection section) {
    return switch (section) {
      RadiologyDeskSection.worklist ||
      RadiologyDeskSection.reporting => AppTabCountTone.warning,
      RadiologyDeskSection.released ||
      RadiologyDeskSection.allOrders ||
      RadiologyDeskSection.followUps => AppTabCountTone.info,
    };
  }

  Widget? _buildPrimaryAction(
    AppLocalizations l10n,
    RadiologyWorkspaceState state,
    AppAccessPolicy accessPolicy,
  ) {
    if (_section.isFollowUps) {
      return null;
    }
    final bool canRequest = _requestRequirement.isAllowed(accessPolicy);
    if (!canRequest) {
      return AppTabToolbarPrimary(
        label: l10n.commonRefreshActionLabel,
        icon: Icons.refresh_outlined,
        semanticLabel: l10n.commonRefreshActionLabel,
        tooltip: l10n.commonRefreshActionLabel,
        isLoading: state.isRefreshing,
        enabled: !state.isRefreshing,
        onPressed: state.isRefreshing
            ? null
            : () {
                unawaited(
                  ref
                      .read(radiologyWorkspaceControllerProvider.notifier)
                      .refresh(),
                );
              },
      );
    }

    return AppAccessActionGate(
      requirement: _requestRequirement,
      builder: (BuildContext context, bool isAllowed) {
        return AppTabToolbarPrimary(
          label: l10n.radiologyRequestImagingAction,
          icon: Icons.add,
          semanticLabel: l10n.radiologyRequestImagingAction,
          tooltip: l10n.radiologyRequestImagingAction,
          enabled: isAllowed && !state.isMutating,
          onPressed: isAllowed && !state.isMutating
              ? () => _showCreateOrderDialog(context, ref)
              : null,
        );
      },
    );
  }

  List<Widget> _buildSecondaryActions(
    AppLocalizations l10n,
    RadiologyWorkspaceState state,
    AppAccessPolicy accessPolicy,
  ) {
    final bool canRequest = _requestRequirement.isAllowed(accessPolicy);
    final bool isPatientsView =
        state.query.view == RadiologyWorkbenchView.patients;
    final String viewLabel = isPatientsView
        ? l10n.radiologyOrdersViewAction
        : l10n.radiologyPatientsViewAction;
    final AppTabToolbarAction viewToggle = AppTabToolbarAction(
      label: viewLabel,
      icon: Icons.swap_horiz_outlined,
      semanticLabel: viewLabel,
      tooltip: viewLabel,
      onPressed: state.isMutating
          ? null
          : () {
              unawaited(
                ref
                    .read(radiologyWorkspaceControllerProvider.notifier)
                    .applyView(
                      isPatientsView
                          ? RadiologyWorkbenchView.orders
                          : RadiologyWorkbenchView.patients,
                    ),
              );
            },
    );
    final AppTabToolbarAction refreshAction = AppTabToolbarAction(
      label: l10n.commonRefreshActionLabel,
      icon: Icons.refresh_outlined,
      semanticLabel: l10n.commonRefreshActionLabel,
      tooltip: l10n.commonRefreshActionLabel,
      isLoading: state.isRefreshing,
      enabled: !state.isRefreshing,
      onPressed: state.isRefreshing
          ? null
          : () {
              unawaited(
                ref
                    .read(radiologyWorkspaceControllerProvider.notifier)
                    .refresh(),
              );
            },
    );
    final Widget configurationsAction = AppAccessActionGate(
      requirement: _workRequirement,
      builder: (BuildContext context, bool isAllowed) {
        return AppTabToolbarAction(
          label: l10n.radiologyConfigurationsAction,
          icon: Icons.tune_outlined,
          semanticLabel: l10n.radiologyConfigurationsAction,
          tooltip: l10n.radiologyConfigurationsAction,
          enabled: isAllowed && !state.isMutating,
          onPressed: isAllowed && !state.isMutating
              ? () => _showRadiologyConfigurationsDialog(
                  context,
                  ref,
                  tenantId: accessPolicy.tenantId,
                )
              : null,
        );
      },
    );

    return switch (_section) {
      RadiologyDeskSection.worklist => <Widget>[
        viewToggle,
        if (canRequest) refreshAction,
        configurationsAction,
      ],
      RadiologyDeskSection.reporting || RadiologyDeskSection.released =>
        <Widget>[viewToggle, if (canRequest) refreshAction],
      RadiologyDeskSection.allOrders => <Widget>[
        viewToggle,
        if (canRequest) refreshAction,
        configurationsAction,
      ],
      RadiologyDeskSection.followUps => const <Widget>[],
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final RadiologyWorkspaceState state = widget.state;
    final controller = ref.read(radiologyWorkspaceControllerProvider.notifier);
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canRequest = _requestRequirement.isAllowed(accessPolicy);
    final bool canWork = _workRequirement.isAllowed(accessPolicy);
    final AppFailure? lastFailure = state.lastFailure;

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: <AppTabItem>[
                for (final RadiologyDeskSection section
                    in RadiologyDeskSection.values)
                  AppTabItem(
                    id: section.name,
                    icon: _sectionIcon(section),
                    label: _sectionLabel(l10n, section),
                    count: section == RadiologyDeskSection.followUps
                        ? ref.watch(
                            followUpTabCountProvider(
                              const FollowUpWorklistScope(),
                            ),
                          )
                        : _sectionCount(state, section),
                    countTone: _sectionCountTone(section),
                  ),
              ],
              selectedId: _section.name,
              onTabTapped: (String tabId) {
                for (final RadiologyDeskSection section
                    in RadiologyDeskSection.values) {
                  if (section.name == tabId) {
                    setState(() => _section = section);
                    _updateUrlForSection(section);
                    _applyStageForSection(section);
                    break;
                  }
                }
              },
              primaryAction: _buildPrimaryAction(l10n, state, accessPolicy),
              secondaryActions: _buildSecondaryActions(
                l10n,
                state,
                accessPolicy,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            if (lastFailure != null && !_section.isFollowUps) ...<Widget>[
              AppFailureStateView(
                failure: lastFailure,
                onRetry: controller.refresh,
              ),
              SizedBox(height: theme.spacing.md),
            ],
            if (_section.isFollowUps)
              const FollowUpWorklistPanel(
                scope: FollowUpWorklistScope(),
                storageKeyPrefix: 'radiology_follow_ups',
              )
            else
              _RadiologyOrderBoard(
              section: _section,
              state: state,
              canWork: canWork,
              canRequest: canRequest,
              searchController: _searchController,
              columnVisibilityController: _tableColumnController,
              onSearchChanged: _scheduleSearch,
              onSearchSubmitted: _applySearchNow,
            ),
          ],
        ),
      ),
    );
  }
}

class _RadiologyOrderBoard extends ConsumerWidget {
  const _RadiologyOrderBoard({
    required this.section,
    required this.state,
    required this.canWork,
    required this.canRequest,
    required this.searchController,
    required this.columnVisibilityController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  final RadiologyDeskSection section;
  final RadiologyWorkspaceState state;
  final bool canWork;
  final bool canRequest;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<RadiologyOrder>
  columnVisibilityController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final controller = ref.read(radiologyWorkspaceControllerProvider.notifier);
    final String storageSuffix = '${section.name}_${state.query.view.name}';

    return AppListTable<RadiologyOrder>(
      page: state.orders,
      isLoading: state.isRefreshing,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columnVisibilityStorageKey: 'radiology_$storageSuffix',
      columnWidthStorageKey: 'radiology_cw_$storageSuffix',
      columnVisibilityApplyLabel: l10n.radiologyApplyColumnsAction,
      columnVisibilityResetLabel: l10n.radiologyResetColumnsAction,
      search: AppListTableSearch<RadiologyOrder>(
        controller: searchController,
        semanticLabel: l10n.radiologySearchLabel,
        hintText: l10n.radiologySearchHint,
        matcher: (RadiologyOrder item, String query) =>
            _radiologyWorklistSearchMatcher(context, item, query),
        onChanged: onSearchChanged,
        onSubmitted: onSearchSubmitted,
        onClear: () {
          onSearchSubmitted('');
        },
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.radiologyClearFiltersAction,
        dateFilterLabel: l10n.radiologyOrderDateFilterLabel,
        dateFromLabel: l10n.radiologyOrderDateFilterLabel,
        dateToLabel: l10n.opdDateToLabel,
        datePickerButtonLabel: l10n.radiologyPickOrderDateAction,
        invalidDateMessage: l10n.appDateInvalidMessage,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        currentDate: DateTime.now(),
        allFieldsLabel: l10n.opdAllFieldsFilterLabel,
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _radiologyStageFilterKey,
            label: l10n.radiologyStageFilterLabel,
            allLabel: _stageFilterLabel(l10n, 'ALL'),
            choices: _radiologyStageFilterChoices(l10n),
          ),
          AppSearchBarFilterGroup(
            key: _radiologyStatusFilterKey,
            label: l10n.radiologyStatusFilterLabel,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: _radiologyStatusFilterChoices(l10n),
          ),
          AppSearchBarFilterGroup(
            key: _radiologyModalityFilterKey,
            label: l10n.radiologyModalityFilterLabel,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: _radiologyModalityFilterChoices(l10n),
          ),
          AppSearchBarFilterGroup(
            key: _radiologyPriorityFilterKey,
            label: l10n.radiologyPriorityFilterLabel,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: _radiologyPriorityFilterChoices(l10n),
          ),
          AppSearchBarFilterGroup(
            key: _radiologyBillingGateFilterKey,
            label: l10n.radiologyBillingGateFilterLabel,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: _radiologyBillingGateFilterChoices(l10n),
          ),
        ],
        filterValue: _radiologyFilterValue(state.query),
        hasActiveFilters: _hasRadiologyFilters(state.query),
        onFilterChanged: (AppSearchBarFilterValue value) async {
          final String nextStage =
              value.option(_radiologyStageFilterKey) ?? 'ALL';
          final String? nextStatus = value.option(_radiologyStatusFilterKey);
          final String? nextModality = value.option(
            _radiologyModalityFilterKey,
          );
          final String? nextPriority = value.option(
            _radiologyPriorityFilterKey,
          );
          final String? nextBillingGate = value.option(
            _radiologyBillingGateFilterKey,
          );
          final DateTime? nextDate = value.dateFrom;
          AppFailure? failure;
          if (nextStage != state.query.stage) {
            failure = await controller.applyStage(nextStage);
          }
          if (nextStatus != state.query.status) {
            failure ??= await controller.applyStatus(nextStatus);
          }
          if (nextModality != state.query.modality) {
            failure ??= await controller.applyModality(nextModality);
          }
          if (nextPriority != state.query.priority) {
            failure ??= await controller.applyPriority(nextPriority);
          }
          if (nextBillingGate != state.query.billingGate) {
            failure ??= await controller.applyBillingGate(nextBillingGate);
          }
          if (!_isSameFilterDate(nextDate, state.query.from)) {
            failure ??= await controller.applyOrderedDate(nextDate);
          }
          if (context.mounted) {
            _showFailureIfNeeded(context, failure);
          }
        },
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemKeyBuilder: (RadiologyOrder item) => ValueKey<String>(item.id),
      onRowSelected: (RadiologyOrder order) {
        unawaited(
          _openRadiologyDetailDialog(
            context,
            ref,
            state,
            order,
            canWork: canWork,
            canRequest: canRequest,
          ),
        );
      },
      previousPageLabel: l10n.radiologyPreviousPageLabel,
      nextPageLabel: l10n.radiologyNextPageLabel,
      pageLabelBuilder: (AppPage<RadiologyOrder> page) {
        return l10n.radiologyPageLabel(
          page.firstItemNumber,
          page.lastItemNumber,
          page.totalItemCount ?? page.lastItemNumber,
        );
      },
      onPageChanged: (AppPageRequest request) {
        unawaited(controller.changePage(request));
      },
      emptyBuilder: (BuildContext context) {
        return AppWorkspaceStatePanel.empty(
          title: state.query.view == RadiologyWorkbenchView.patients
              ? l10n.radiologyNoPatientsTitle
              : l10n.radiologyNoOrdersTitle,
          body: state.query.view == RadiologyWorkbenchView.patients
              ? l10n.radiologyNoPatientsBody
              : l10n.radiologyNoOrdersBody,
          icon: Icons.inbox_outlined,
        );
      },
      columns: state.query.view == RadiologyWorkbenchView.patients
          ? _patientViewWorklistColumns(
              context,
              state: state,
              canWork: canWork,
              canRequest: canRequest,
            )
          : _orderViewWorklistColumns(
              context,
              state: state,
              canWork: canWork,
              canRequest: canRequest,
            ),
      columnChoices: _optionalRadiologyWorklistColumns(context),
      mobileItemBuilder: (BuildContext context, RadiologyOrder item) {
        final AppLocalizations l10n = context.l10n;
        final AppWorkspaceStatus status = _orderStatus(context, item);
        return AppListTableMobileItem(
          title: item.patientDisplayName ?? l10n.profileUnknownValue,
          caption: item.patientId,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(label: status.label, icon: status.icon),
            AppListTableMobileMeta(
              label: _joinDisplay(<String?>[
                _radiologyStudyLabel(item, l10n),
                if (state.query.view == RadiologyWorkbenchView.patients)
                  _radiologyPriorityDisplayLabel(l10n, item.priority),
              ]),
              icon: Icons.biotech_outlined,
            ),
            if (state.query.view == RadiologyWorkbenchView.orders &&
                !item.isPatientGroup)
              AppListTableMobileMeta(
                label: item.effectiveDisplayId.ifEmpty(
                  l10n.profileUnknownValue,
                ),
                icon: Icons.tag,
              ),
          ],
        );
      },
    );
  }
}


class _RadiologyOrderDetail extends ConsumerWidget {
  const _RadiologyOrderDetail({
    required this.state,
    required this.canWork,
    required this.canRequest,
  });

  final RadiologyWorkspaceState state;
  final bool canWork;
  final bool canRequest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final RadiologyWorkflow? workflow = state.selectedWorkflow;

    if (state.isRefreshingDetail && workflow == null) {
      return AppWorkspaceStatePanel.loading(
        title: l10n.radiologyDetailLoadingTitle,
        body: l10n.radiologyDetailLoadingBody,
        minHeight: 360,
      );
    }

    if (workflow == null) {
      return AppWorkspaceStatePanel.empty(
        title: l10n.radiologyNoSelectionTitle,
        body: l10n.radiologyNoSelectionBody,
        icon: Icons.touch_app_outlined,
        minHeight: 360,
      );
    }

    return _RadiologyDetailBody(
      state: state,
      workflow: workflow,
      canWork: canWork,
      canRequest: canRequest,
    );
  }
}

Future<void> _openRadiologyDetailDialog(
  BuildContext context,
  WidgetRef ref,
  RadiologyWorkspaceState fallbackState,
  RadiologyOrder order, {
  required bool canWork,
  required bool canRequest,
}) async {
  final RadiologyWorkspaceController controller = ref.read(
    radiologyWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectOrder(order);
  if (context.mounted && failure != null) {
    _showMutationResult(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }

  final RadiologyWorkspaceState state =
      _readRadiologyState(ref) ?? fallbackState;
  if (state.selectedWorkflow == null) {
    return;
  }

  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(context.l10n.radiologyDetailTitle),
      icon: const Icon(Icons.medical_information_outlined),
      scrollable: true,
      maxWidth: 980,
      content: _RadiologyOrderDetail(
        state: state,
        canWork: canWork,
        canRequest: canRequest,
      ),
    ),
  );
}

RadiologyWorkspaceState? _readRadiologyState(WidgetRef ref) {
  return ref
      .read(radiologyWorkspaceControllerProvider)
      .asData
      ?.value
      .when(
        success: (RadiologyWorkspaceState state) => state,
        failure: (_) => null,
      );
}

class _RadiologyDetailBody extends ConsumerStatefulWidget {
  const _RadiologyDetailBody({
    required this.state,
    required this.workflow,
    required this.canWork,
    required this.canRequest,
  });

  final RadiologyWorkspaceState state;
  final RadiologyWorkflow workflow;
  final bool canWork;
  final bool canRequest;

  @override
  ConsumerState<_RadiologyDetailBody> createState() =>
      _RadiologyDetailBodyState();
}

class _RadiologyDetailBodyState extends ConsumerState<_RadiologyDetailBody> {
  final GlobalKey _requestSectionKey = GlobalKey();
  final GlobalKey _studiesSectionKey = GlobalKey();
  final GlobalKey _reportSectionKey = GlobalKey();
  final GlobalKey _doctorReviewSectionKey = GlobalKey();
  bool _workflowExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final RadiologyDetailViewMode inferred =
          widget.canRequest && !widget.canWork
          ? RadiologyDetailViewMode.reporting
          : RadiologyDetailViewMode.imagingFloor;
      ref
          .read(radiologyWorkspaceControllerProvider.notifier)
          .setDetailViewMode(inferred);
    });
  }

  void _scrollToSection(GlobalKey key) {
    final BuildContext? target = key.currentContext;
    if (target == null) {
      return;
    }
    unawaited(
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        alignment: 0.06,
      ),
    );
  }

  void _handleWorkflowStepTap(int stepIndex) {
    final GlobalKey target = switch (stepIndex) {
      0 || 1 || 2 => _requestSectionKey,
      3 || 4 => _studiesSectionKey,
      5 || 6 || 7 => _reportSectionKey,
      _ => _requestSectionKey,
    };
    _scrollToSection(target);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final RadiologyOrder order = widget.workflow.order;
    final RadiologyDetailViewMode viewMode = widget.state.detailViewMode;
    final bool imagingView = viewMode == RadiologyDetailViewMode.imagingFloor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppPatientDetails(
          patientName: order.patientDisplayName ?? l10n.profileUnknownValue,
          patientNumber: order.patientId ?? '',
          patientNumberLabel: l10n.radiologyPatientIdLabel,
          copyPatientNumberTooltip: l10n.copyIdentifierAction,
          copyPatientNumberMessage: l10n.identifierCopiedMessage,
          semanticLabel: l10n.radiologyPatientContextLabel,
          showAvatar: false,
          showActionLabels: true,
          status: _orderStatus(context, order),
          expandedFields: <AppWorkspacePatientContextField>[
            if ((order.testDisplayName ?? '').trim().isNotEmpty)
              AppWorkspacePatientContextField(
                label: l10n.radiologyStudyLabel,
                value: order.testDisplayName!,
              ),
            AppWorkspacePatientContextField(
              label: l10n.radiologyPaymentLabel,
              value: _billingGateLabel(context, order),
              icon: Icons.receipt_long_outlined,
              tone: _billingGateTone(order),
            ),
          ],
          alerts: <AppWorkspaceStatus>[
            if (order.hasFinalResult)
              AppWorkspaceStatus(
                label: l10n.radiologyDoctorReviewReadyLabel,
                tone: AppWorkspaceStatusTone.success,
                icon: Icons.verified_outlined,
              ),
          ],
          actions: _buildHeaderActions(context),
        ),
        SizedBox(height: theme.spacing.md),
        _WorkflowSummarySection(order: order),
        SizedBox(height: theme.spacing.md),
        _RadiologyViewModeSection(
          viewMode: viewMode,
          onViewModeChanged: (RadiologyDetailViewMode mode) {
            ref
                .read(radiologyWorkspaceControllerProvider.notifier)
                .setDetailViewMode(mode);
          },
        ),
        SizedBox(height: theme.spacing.md),
        RadiologyWorkflowProgressSection(
          workflow: widget.workflow,
          canMutate: widget.canWork,
          isSaving: widget.state.isMutating,
          expanded: _workflowExpanded,
          onExpandedChanged: (bool value) {
            setState(() => _workflowExpanded = value);
          },
          onStepTap: _handleWorkflowStepTap,
          onAssign: () => _showAssignDialog(context, ref),
          onStart: () => _submitNotesOnly(
            context: context,
            title: context.l10n.radiologyStartDialogTitle,
            notesLabel: context.l10n.radiologyNotesLabel,
            submitLabel: context.l10n.radiologyStartImagingAction,
            submit: ref
                .read(radiologyWorkspaceControllerProvider.notifier)
                .startOrder,
          ),
        ),
        SizedBox(height: theme.spacing.lg),
        ..._orderedDetailSections(
          context: context,
          imagingView: imagingView,
          l10n: l10n,
          theme: theme,
        ),
      ],
    );
  }

  List<Widget> _orderedDetailSections({
    required BuildContext context,
    required bool imagingView,
    required AppLocalizations l10n,
    required ThemeData theme,
  }) {
    final Widget requestSection = KeyedSubtree(
      key: _requestSectionKey,
      child: _RequestSection(
        order: widget.workflow.order,
        canEdit: widget.canWork && !widget.state.isMutating,
      ),
    );
    final Widget reportSection = KeyedSubtree(
      key: _reportSectionKey,
      child: _ReportingSection(
        state: widget.state,
        workflow: widget.workflow,
        canWork: widget.canWork,
        imagingView: imagingView,
      ),
    );
    final Widget studiesSection = KeyedSubtree(
      key: _studiesSectionKey,
      child: _StudiesSection(
        state: widget.state,
        workflow: widget.workflow,
        canWork: widget.canWork,
        imagingView: imagingView,
        onPerformStudy: widget.canWork && !widget.state.isMutating
            ? () => _showStudyDialog(context, ref, widget.workflow.order)
            : null,
      ),
    );
    final Widget doctorReview = KeyedSubtree(
      key: _doctorReviewSectionKey,
      child: _DoctorReviewPanel(
        order: widget.workflow.order,
        workflow: widget.workflow,
        canWork: widget.canWork,
        onOpenReport: () => _scrollToSection(_reportSectionKey),
      ),
    );
    final Widget timeline = _TimelineSection(workflow: widget.workflow);
    final List<Widget> sections = imagingView
        ? <Widget>[
            studiesSection,
            SizedBox(height: theme.spacing.lg),
            requestSection,
            SizedBox(height: theme.spacing.lg),
            reportSection,
          ]
        : <Widget>[
            requestSection,
            SizedBox(height: theme.spacing.lg),
            reportSection,
            SizedBox(height: theme.spacing.lg),
            studiesSection,
          ];
    if (widget.workflow.nextActions.canRequestFinalization ||
        widget.workflow.nextActions.canAttestFinalization ||
        widget.workflow.nextActions.canAddAddendum) {
      sections.addAll(<Widget>[
        SizedBox(height: theme.spacing.lg),
        doctorReview,
      ]);
    }
    sections.addAll(<Widget>[SizedBox(height: theme.spacing.lg), timeline]);
    return sections;
  }

  List<Widget> _buildHeaderActions(BuildContext context) {
    if (!widget.canWork) {
      return const <Widget>[];
    }
    final RadiologyWorkflow workflow = widget.workflow;
    final bool imagingView =
        widget.state.detailViewMode == RadiologyDetailViewMode.imagingFloor;
    final List<Widget> actions = <Widget>[];
    if (workflow.nextActions.billingGateBlocked) {
      actions.add(
        AppButton.secondary(
          label: context.l10n.radiologyBillingGateBlockedAction,
          leadingIcon: Icons.payments_outlined,
          onPressed: null,
        ),
      );
    }
    if (workflow.nextActions.canAssign) {
      actions.add(
        AppButton.secondary(
          label: context.l10n.radiologyAssignAction,
          leadingIcon: Icons.event_available_outlined,
          isLoading: widget.state.isMutating,
          onPressed: () => _showAssignDialog(context, ref),
        ),
      );
    }
    if (workflow.nextActions.canStart) {
      actions.add(
        AppButton.secondary(
          label: context.l10n.radiologyStartImagingAction,
          leadingIcon: Icons.play_arrow_outlined,
          isLoading: widget.state.isMutating,
          onPressed: () => _submitNotesOnly(
            context: context,
            title: context.l10n.radiologyStartDialogTitle,
            notesLabel: context.l10n.radiologyNotesLabel,
            submitLabel: context.l10n.radiologyStartImagingAction,
            submit: ref
                .read(radiologyWorkspaceControllerProvider.notifier)
                .startOrder,
          ),
        ),
      );
    }
    if (imagingView && workflow.nextActions.canCreateStudy) {
      actions.add(
        AppButton.secondary(
          label: context.l10n.radiologyPerformStudyAction,
          leadingIcon: Icons.add_a_photo_outlined,
          isLoading: widget.state.isMutating,
          onPressed: () => _showStudyDialog(context, ref, workflow.order),
        ),
      );
    }
    if (!imagingView && workflow.nextActions.canCreateDraftResult) {
      actions.add(
        AppButton.secondary(
          label: context.l10n.radiologyDraftReportAction,
          leadingIcon: Icons.edit_note_outlined,
          isLoading: widget.state.isMutating,
          onPressed: () => _showReportDialog(context, ref, workflow.order),
        ),
      );
    }
    if (!imagingView &&
        workflow.nextActions.canFinalizeResult &&
        workflow.order.latestDraftResult != null) {
      actions.add(
        AppButton.primary(
          label: context.l10n.radiologyReleaseReportAction,
          leadingIcon: Icons.verified_outlined,
          isLoading: widget.state.isMutating,
          onPressed: () => _showFinalizeDialog(
            context,
            ref,
            workflow.order.latestDraftResult!,
          ),
        ),
      );
    }
    if (workflow.nextActions.canCancel) {
      actions.add(
        AppButton.tertiary(
          label: context.l10n.radiologyCancelOrderAction,
          leadingIcon: Icons.cancel_outlined,
          isLoading: widget.state.isMutating,
          onPressed: () => _showCancelDialog(context, ref),
        ),
      );
    }
    return actions;
  }
}

class _RadiologyViewModeSection extends StatelessWidget {
  const _RadiologyViewModeSection({
    required this.viewMode,
    required this.onViewModeChanged,
  });

  final RadiologyDetailViewMode viewMode;
  final ValueChanged<RadiologyDetailViewMode> onViewModeChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool imagingFloor = viewMode == RadiologyDetailViewMode.imagingFloor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        RadioGroup<RadiologyDetailViewMode>(
          groupValue: viewMode,
          onChanged: (RadiologyDetailViewMode? selected) {
            if (selected != null) {
              onViewModeChanged(selected);
            }
          },
          child: Wrap(
            spacing: theme.spacing.xl,
            runSpacing: theme.spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _RadiologyViewModeRadioOption(
                value: RadiologyDetailViewMode.imagingFloor,
                icon: Icons.medical_services_outlined,
                label: l10n.radiologyViewModeImagingFloorLabel,
                onSelected: () =>
                    onViewModeChanged(RadiologyDetailViewMode.imagingFloor),
              ),
              _RadiologyViewModeRadioOption(
                value: RadiologyDetailViewMode.reporting,
                icon: Icons.description_outlined,
                label: l10n.radiologyViewModeReportingLabel,
                onSelected: () =>
                    onViewModeChanged(RadiologyDetailViewMode.reporting),
              ),
            ],
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          imagingFloor
              ? l10n.radiologyViewModeImagingFloorHelper
              : l10n.radiologyViewModeReportingHelper,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RadiologyViewModeRadioOption extends StatelessWidget {
  const _RadiologyViewModeRadioOption({
    required this.value,
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final RadiologyDetailViewMode value;
  final IconData icon;
  final String label;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSelected,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Radio<RadiologyDetailViewMode>(
              value: value,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            Icon(icon, size: theme.appTokens.listIconSize),
            SizedBox(width: theme.spacing.xs),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowSummarySection extends StatelessWidget {
  const _WorkflowSummarySection({required this.order});

  final RadiologyOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<_DetailLine> lines = <_DetailLine>[
      _DetailLine(
        label: l10n.radiologyOrderColumnLabel,
        value: order.effectiveDisplayId,
      ),
      _DetailLine(
        label: l10n.radiologyOrderedAtLabel,
        value: _formatDateTimeOrNull(context, order.orderedAt),
      ),
      _DetailLine(
        label: l10n.radiologyModalityLabel,
        value: _modalityLabelOrNull(l10n, order.modality),
      ),
      _DetailLine(
        label: l10n.radiologyEncounterLabel,
        value: order.encounterId,
      ),
      _DetailLine(
        label: l10n.radiologyPriorityLabel,
        value: _radiologyPriorityDisplayLabel(l10n, order.priority),
      ),
      _DetailLine(
        label: l10n.radiologyPaymentLabel,
        value: order.hasBillingGate
            ? clinicalRequestPaymentStatusDisplayLabel(
                l10n,
                order.effectivePaymentStatus,
              )
            : l10n.radiologyBillingGateUnavailable,
      ),
      if ((order.authorizationStatus ?? '').trim().isNotEmpty)
        _DetailLine(
          label: l10n.radiologyAuthorizationLabel,
          value: order.authorizationStatus,
        ),
    ];

    return AppSectionPanel(
      title: l10n.radiologyOrderMetadataTitle,
      spacing: Theme.of(context).spacing.sm,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= 720;
            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: lines,
              );
            }

            final int columnCount = lines.length <= 3 ? lines.length : 2;
            final int rowCount = (lines.length / columnCount).ceil();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int row = 0; row < rowCount; row++) ...<Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (
                        int column = 0;
                        column < columnCount;
                        column++
                      ) ...<Widget>[
                        if (row * columnCount + column < lines.length)
                          Expanded(child: lines[row * columnCount + column]),
                      ],
                    ],
                  ),
                  if (row < rowCount - 1)
                    SizedBox(height: Theme.of(context).spacing.xs),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RequestSection extends ConsumerWidget {
  const _RequestSection({required this.order, required this.canEdit});

  final RadiologyOrder order;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;

    return AppSectionPanel(
      title: l10n.radiologyRequestDetailsTitle,
      spacing: Theme.of(context).spacing.sm,
      trailing: AppButton(
        iconOnly: true,
        leadingIcon: Icons.edit_outlined,
        label: l10n.radiologyEditRequestDetailsAction,

        semanticLabel: l10n.radiologyEditRequestDetailsAction,
        tooltip: l10n.radiologyEditRequestDetailsAction,
        onPressed: canEdit
            ? () => _showEditRequestDetailsDialog(context, ref, order)
            : null,
      ),
      children: <Widget>[
        _DetailLine(
          label: l10n.radiologyBodyRegionLabel,
          value: order.bodyRegion,
        ),
        _DetailLine(
          label: l10n.radiologyLateralityLabel,
          value: order.laterality,
        ),
        _DetailLine(
          label: l10n.radiologyAssigneeLabel,
          value: order.assignedUserDisplayName ?? order.assignedUserId,
        ),
        _DetailLine(
          label: l10n.radiologyScheduledAtLabel,
          value: order.scheduledAt == null
              ? null
              : AppFormatters.mediumDate(
                  order.scheduledAt!,
                  Localizations.localeOf(context),
                ),
        ),
        _DetailLine(label: l10n.radiologyRoomLabel, value: order.room),
        _DetailLine(
          label: l10n.radiologyEquipmentLabel,
          value: order.equipmentDisplayName ?? order.equipmentRegistryId,
        ),
        _DetailLine(
          label: l10n.radiologyClinicalNotesLabel,
          value: order.clinicalNote,
          maxLines: 6,
        ),
      ],
    );
  }
}

Future<void> _showEditRequestDetailsDialog(
  BuildContext context,
  WidgetRef ref,
  RadiologyOrder order,
) async {
  final List<ClinicalActionCatalogOption> catalog = _radiologyCatalogOptions(
    _watchState(ref),
  );
  final bool? saved = await showAppDialog<bool>(
    context: context,
    builder: (_) => _RequestDetailsEditDialog(
      order: order,
      catalog: catalog,
      onSubmit: (Map<String, Object?> payload) => ref
          .read(radiologyWorkspaceControllerProvider.notifier)
          .updateOrderRequestDetails(payload),
    ),
  );
  if (saved == true && context.mounted) {
    _showMutationResult(context, null);
  }
}

class _RequestDetailsEditDialog extends StatefulWidget {
  const _RequestDetailsEditDialog({
    required this.order,
    required this.catalog,
    required this.onSubmit,
  });

  final RadiologyOrder order;
  final List<ClinicalActionCatalogOption> catalog;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;

  @override
  State<_RequestDetailsEditDialog> createState() =>
      _RequestDetailsEditDialogState();
}

class _RequestDetailsEditDialogState extends State<_RequestDetailsEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  String? _priority;
  String? _bodyRegion;
  String? _laterality;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _priority = _trimmedOrNull(widget.order.priority);
    _bodyRegion = _trimmedOrNull(widget.order.bodyRegion);
    _laterality = _trimmedOrNull(widget.order.laterality);
    _notesController = TextEditingController(
      text: widget.order.clinicalNote ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final AppFailure? failure = await widget.onSubmit(<String, Object?>{
      'clinical_note': _trimmedOrNull(_notesController.text),
      'request_details': <String, Object?>{
        'priority': _priority,
        'body_region': _bodyRegion,
        'laterality': _laterality,
      },
    });

    if (!mounted) {
      return;
    }

    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.radiologyEditRequestDetailsDialogTitle),
      icon: const Icon(Icons.edit_outlined),
      scrollable: true,
      maxWidth: 560,
      closeEnabled: !_isSubmitting,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSubmitting,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          AppSelectField<String>(
            value: _priority,
            labelText: l10n.radiologyPriorityLabel,
            helperText: _priority == 'STAT'
                ? l10n.radiologyPriorityStatHint
                : null,
            options: _radiologyPriorityOptions(l10n),
            onChanged: (String? value) => setState(() => _priority = value),
          ),
          AppSelectField<String>(
            value: _bodyRegion,
            labelText: l10n.radiologyBodyRegionLabel,
            hintText: l10n.clinicalRadiologyBodyRegionPickerHint,
            options: clinicalRadiologyBodyRegionOptions(
              widget.catalog,
              modality: widget.order.modality,
              laterality: _laterality,
              priority: _priority,
            ),
            onChanged: (String? value) => setState(() => _bodyRegion = value),
          ),
          AppSelectField<String>(
            value: _laterality,
            labelText: l10n.radiologyLateralityLabel,
            options: _radiologyLateralityOptions(l10n),
            onChanged: (String? value) => setState(() => _laterality = value),
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.radiologyClinicalNotesLabel,
            maxLines: 5,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSubmitting,
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.radiologySaveRequestDetailsAction,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }
}

class _ReportingSection extends ConsumerStatefulWidget {
  const _ReportingSection({
    required this.state,
    required this.workflow,
    required this.canWork,
    required this.imagingView,
  });

  final RadiologyWorkspaceState state;
  final RadiologyWorkflow workflow;
  final bool canWork;
  final bool imagingView;

  @override
  ConsumerState<_ReportingSection> createState() => _ReportingSectionState();
}

class _ReportingSectionState extends ConsumerState<_ReportingSection> {
  late final TextEditingController _inlineReportController;
  bool _isInlineSaving = false;

  @override
  void initState() {
    super.initState();
    _inlineReportController = TextEditingController(
      text: widget.workflow.order.latestDraftResult?.reportText ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _ReportingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String? nextText =
        widget.workflow.order.latestDraftResult?.reportText;
    if (nextText != null &&
        nextText != _inlineReportController.text &&
        !_inlineReportController.selection.isValid) {
      _inlineReportController.text = nextText;
    } else if (nextText != null &&
        nextText != _inlineReportController.text &&
        !_inlineReportController.text.contains(nextText)) {
      _inlineReportController.text = nextText;
    }
  }

  @override
  void dispose() {
    _inlineReportController.dispose();
    super.dispose();
  }

  Future<void> _saveInlineDraft() async {
    final RadiologyResult? draft = widget.workflow.order.latestDraftResult;
    if (draft == null) {
      return;
    }
    setState(() => _isInlineSaving = true);
    final AppFailure? failure = await ref
        .read(radiologyWorkspaceControllerProvider.notifier)
        .draftResult(<String, Object?>{
          'report_text': _inlineReportController.text.trim(),
        });
    if (mounted) {
      setState(() => _isInlineSaving = false);
      _showMutationResult(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final RadiologyResult? latest = widget.workflow.order.latestResult;
    final RadiologyResult? draft = widget.workflow.order.latestDraftResult;
    final RadiologyResult? released =
        widget.workflow.order.latestReleasedResult;
    final bool canDraft =
        widget.canWork && widget.workflow.nextActions.canCreateDraftResult;
    final bool canFinalize =
        widget.canWork &&
        widget.workflow.nextActions.canFinalizeResult &&
        draft != null;
    final bool canRequest =
        widget.canWork &&
        widget.workflow.nextActions.canRequestFinalization &&
        draft != null;
    final bool canAttest =
        widget.canWork &&
        widget.workflow.nextActions.canAttestFinalization &&
        draft != null;
    final bool canAddendum =
        widget.canWork &&
        widget.workflow.nextActions.canAddAddendum &&
        released != null;
    final bool showInlineEditor =
        !widget.imagingView && canDraft && draft != null;
    final bool imagingComplete = widget.workflow.studies.isNotEmpty;

    return AppWorkspaceDetailPanel(
      title: l10n.radiologyReportSectionTitle,
      description: widget.imagingView ? null : l10n.radiologyReportSectionBody,
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.radiologyPrintReportAction,
          leadingIcon: Icons.print_outlined,
          onPressed: widget.state.isMutating
              ? null
              : () => _showRadiologyPrintDialog(context, widget.workflow),
        ),
        if (!widget.imagingView && canDraft)
          AppButton.secondary(
            label: l10n.radiologyDraftReportAction,
            leadingIcon: Icons.edit_note_outlined,
            onPressed: widget.state.isMutating
                ? null
                : () => _showReportDialog(context, ref, widget.workflow.order),
          ),
        if (!widget.imagingView && canFinalize)
          AppButton.primary(
            label: l10n.radiologyReleaseReportAction,
            leadingIcon: Icons.verified_outlined,
            onPressed: widget.state.isMutating
                ? null
                : () => _showFinalizeDialog(context, ref, draft),
          ),
        if (!widget.imagingView && canRequest)
          AppButton.secondary(
            label: l10n.radiologyRequestFinalizationAction,
            leadingIcon: Icons.how_to_reg_outlined,
            onPressed: widget.state.isMutating
                ? null
                : () => _showFinalizationNoteDialog(
                    context,
                    ref,
                    draft,
                    l10n.radiologyRequestFinalizationDialogTitle,
                    l10n.radiologyRequestFinalizationAction,
                    ref
                        .read(radiologyWorkspaceControllerProvider.notifier)
                        .requestFinalization,
                  ),
          ),
        if (!widget.imagingView && canAttest)
          AppButton.secondary(
            label: l10n.radiologyAttestFinalizationAction,
            leadingIcon: Icons.assignment_turned_in_outlined,
            onPressed: widget.state.isMutating
                ? null
                : () => _showFinalizationNoteDialog(
                    context,
                    ref,
                    draft,
                    l10n.radiologyAttestFinalizationDialogTitle,
                    l10n.radiologyAttestFinalizationAction,
                    ref
                        .read(radiologyWorkspaceControllerProvider.notifier)
                        .attestFinalization,
                  ),
          ),
        if (!widget.imagingView && canAddendum)
          AppButton.tertiary(
            label: l10n.radiologyAddendumAction,
            leadingIcon: Icons.post_add_outlined,
            onPressed: widget.state.isMutating
                ? null
                : () => _showAddendumDialog(context, ref, released),
          ),
      ],
      child: latest == null
          ? AppWorkspaceStatePanel.empty(
              title: widget.imagingView
                  ? l10n.radiologyNoReportTitle
                  : imagingComplete
                  ? l10n.radiologyNoReportReadyTitle
                  : l10n.radiologyNoReportTitle,
              body: widget.imagingView
                  ? (imagingComplete
                        ? l10n.radiologyNoReportImagingFloorBody
                        : l10n.radiologyNoReportBody)
                  : (imagingComplete
                        ? l10n.radiologyNoReportReadyBody
                        : l10n.radiologyNoReportBody),
              icon: Icons.description_outlined,
              minHeight: widget.imagingView ? 120 : 180,
              action: !widget.imagingView && canDraft && imagingComplete
                  ? AppButton.primary(
                      label: l10n.radiologyDraftReportAction,
                      leadingIcon: Icons.edit_note_outlined,
                      onPressed: widget.state.isMutating
                          ? null
                          : () => _showReportDialog(
                              context,
                              ref,
                              widget.workflow.order,
                            ),
                    )
                  : null,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Wrap(
                  spacing: theme.spacing.sm,
                  runSpacing: theme.spacing.sm,
                  children: <Widget>[
                    AppWorkspaceStatusBadge(
                      status: _resultStatus(context, latest),
                    ),
                    if (latest.finalization.pendingAttestation)
                      AppWorkspaceStatusBadge(
                        status: AppWorkspaceStatus(
                          label: l10n.radiologyPendingAttestationLabel,
                          tone: AppWorkspaceStatusTone.warning,
                          icon: Icons.how_to_reg_outlined,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: theme.spacing.md),
                _DetailLine(
                  label: l10n.radiologyReportedAtLabel,
                  value: _formatDateTimeOrNull(context, latest.reportedAt),
                ),
                SizedBox(height: theme.spacing.md),
                if (showInlineEditor) ...<Widget>[
                  Text(
                    l10n.radiologyReportInlineEditHelper,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  AppTextField(
                    controller: _inlineReportController,
                    labelText: l10n.radiologyReportTextLabel,
                    minLines: 6,
                    maxLines: 14,
                    enabled: !widget.state.isMutating && !_isInlineSaving,
                  ),
                  SizedBox(height: theme.spacing.sm),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: AppButton.secondary(
                      label: l10n.radiologyDraftReportAction,
                      leadingIcon: Icons.save_outlined,
                      isLoading: _isInlineSaving,
                      onPressed: widget.state.isMutating
                          ? null
                          : _saveInlineDraft,
                    ),
                  ),
                  SizedBox(height: theme.spacing.md),
                  AppClinicalResultsPreview(
                    title: l10n.radiologyReportLivePreviewTitle,
                    status: AppClinicalResultStatus.preliminary,
                    isEmpty: _inlineReportController.text.trim().isEmpty,
                    emptyBody: l10n.radiologyEmptyReportBody,
                    child: AppClinicalResultEntryView(
                      entry: AppClinicalResultPreviewEntry(
                        id: 'inline-draft',
                        module: AppClinicalResultModule.radiology,
                        title: l10n.radiologyReportLivePreviewTitle,
                        status: AppClinicalResultStatus.preliminary,
                        radiology: AppClinicalRadiologyReportContent(
                          reportText: _inlineReportController.text.trim(),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: theme.spacing.md),
                ],
                AppClinicalResultsPreview(
                  title: l10n.radiologyGeneratedReportPreviewTitle,
                  status: _clinicalResultStatusForRadiology(latest),
                  isEmpty: (latest.reportText ?? '').trim().isEmpty,
                  emptyBody: l10n.radiologyEmptyReportBody,
                  printEligible: appClinicalResultsPrintEligible(
                    authorized: true,
                    hasPrintableReleasedContent:
                        latest.isReleased &&
                        (latest.reportText ?? '').trim().isNotEmpty,
                  ),
                  child: AppClinicalResultEntryView(
                    entry: _radiologyPreviewEntry(
                      result: latest,
                      title: l10n.radiologyGeneratedReportPreviewTitle,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StudiesSection extends ConsumerWidget {
  const _StudiesSection({
    required this.state,
    required this.workflow,
    required this.canWork,
    required this.imagingView,
    this.onPerformStudy,
  });

  final RadiologyWorkspaceState state;
  final RadiologyWorkflow workflow;
  final bool canWork;
  final bool imagingView;
  final VoidCallback? onPerformStudy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<ImagingStudy> studies = workflow.studies;
    final RadiologyResult? latestReport = workflow.order.latestResult;
    final bool canPerform =
        canWork && !state.isMutating && workflow.nextActions.canCreateStudy;

    return AppWorkspaceDetailPanel(
      title: l10n.radiologyStudiesAssetsTitle,
      child: studies.isEmpty
          ? AppWorkspaceStatePanel.empty(
              title: l10n.radiologyNoStudiesTitle,
              body: l10n.radiologyNoStudiesBody,
              icon: Icons.image_search_outlined,
              minHeight: 160,
              action: Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  AppButton.primary(
                    label: l10n.radiologyStudiesPerformStudyCta,
                    leadingIcon: Icons.add_a_photo_outlined,
                    onPressed: canPerform ? onPerformStudy : null,
                  ),
                  AppButton.secondary(
                    label: l10n.radiologyStudiesUploadImagesCta,
                    leadingIcon: Icons.upload_outlined,
                    onPressed: null,
                    tooltip: l10n.radiologyStudiesPerformFirstHint,
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (imagingView && latestReport != null) ...<Widget>[
                  Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        l10n.radiologyStudiesReportPreviewTitle,
                        style: theme.textTheme.titleSmall,
                      ),
                      leading: Icon(
                        Icons.description_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      children: <Widget>[
                        AppClinicalResultsPreview(
                          title: l10n.radiologyGeneratedReportPreviewTitle,
                          status: _clinicalResultStatusForRadiology(
                            latestReport,
                          ),
                          isEmpty: (latestReport.reportText ?? '')
                              .trim()
                              .isEmpty,
                          emptyBody: l10n.radiologyEmptyReportBody,
                          printEligible: appClinicalResultsPrintEligible(
                            authorized: true,
                            hasPrintableReleasedContent:
                                latestReport.isReleased &&
                                (latestReport.reportText ?? '')
                                    .trim()
                                    .isNotEmpty,
                          ),
                          child: AppClinicalResultEntryView(
                            entry: _radiologyPreviewEntry(
                              result: latestReport,
                              title: l10n.radiologyGeneratedReportPreviewTitle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: theme.spacing.md),
                ],
                for (final ImagingStudy study in studies) ...<Widget>[
                  _StudyBlock(
                    study: study,
                    canWork: canWork && !state.isMutating,
                    canSync:
                        canWork &&
                        !state.isMutating &&
                        workflow.nextActions.canPacsSync &&
                        study.hasAssets,
                    onSync: () => _showPacsSyncDialog(context, ref, study),
                    onUpload: (List<StudyAssetUploadRequest> uploads) => ref
                        .read(radiologyWorkspaceControllerProvider.notifier)
                        .uploadStudyAssets(study: study, uploads: uploads),
                    onRemoveAsset: (ImagingAsset asset) => ref
                        .read(radiologyWorkspaceControllerProvider.notifier)
                        .deleteStudyAsset(asset),
                  ),
                  if (study != studies.last) SizedBox(height: theme.spacing.md),
                ],
              ],
            ),
    );
  }
}

class _StudyBlock extends ConsumerStatefulWidget {
  const _StudyBlock({
    required this.study,
    required this.canWork,
    required this.canSync,
    required this.onSync,
    required this.onUpload,
    required this.onRemoveAsset,
  });

  final ImagingStudy study;
  final bool canWork;
  final bool canSync;
  final VoidCallback onSync;
  final Future<AppFailure?> Function(List<StudyAssetUploadRequest> uploads)
  onUpload;
  final Future<AppFailure?> Function(ImagingAsset asset) onRemoveAsset;

  @override
  ConsumerState<_StudyBlock> createState() => _StudyBlockState();
}

class _StudyBlockState extends ConsumerState<_StudyBlock> {
  final List<_PendingStudyAsset> _pendingAssets = <_PendingStudyAsset>[];
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final int assetCount = widget.study.assets.isNotEmpty
        ? widget.study.assets.length
        : widget.study.assetCount;
    final bool pacsSynced = widget.study.hasPacsLinks;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: AppListItemText(
                    title: widget.study.effectiveDisplayId,
                    subtitle: _joinDisplay(<String?>[
                      _modalityLabelOrNull(l10n, widget.study.modality),
                      _formatDateTimeOrNull(context, widget.study.performedAt),
                    ]),
                    titleStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  children: <Widget>[
                    AppWorkspaceStatusBadge(
                      status: AppWorkspaceStatus(
                        label: l10n.radiologyStudyAssetCountLabel(assetCount),
                        tone: assetCount > 0
                            ? AppWorkspaceStatusTone.success
                            : AppWorkspaceStatusTone.neutral,
                        icon: Icons.image_outlined,
                      ),
                    ),
                    AppWorkspaceStatusBadge(
                      status: AppWorkspaceStatus(
                        label: pacsSynced
                            ? l10n.radiologyPacsSyncStatusSynced
                            : l10n.radiologyPacsSyncStatusPending,
                        tone: pacsSynced
                            ? AppWorkspaceStatusTone.success
                            : AppWorkspaceStatusTone.warning,
                        icon: Icons.cloud_sync_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                AppButton.secondary(
                  label: l10n.radiologyStudiesUploadImagesCta,
                  leadingIcon: Icons.upload_outlined,
                  enabled: widget.canWork && !_isUploading,
                  onPressed: widget.canWork && !_isUploading
                      ? _pickImages
                      : null,
                ),
                AppButton.secondary(
                  label: l10n.radiologyStudiesCapturePhotoCta,
                  leadingIcon: Icons.photo_camera_outlined,
                  enabled: widget.canWork && !_isUploading,
                  onPressed: widget.canWork && !_isUploading
                      ? _pickImages
                      : null,
                ),
                AppButton.secondary(
                  label: l10n.radiologySyncPacsAction,
                  leadingIcon: Icons.cloud_sync_outlined,
                  enabled: widget.canSync && !_isUploading,
                  onPressed: widget.canSync ? widget.onSync : null,
                ),
              ],
            ),
            SizedBox(height: theme.spacing.md),
            Text(l10n.radiologyAssetsLabel, style: theme.textTheme.labelLarge),
            SizedBox(height: theme.spacing.xs),
            if (widget.study.assets.isEmpty)
              Text(
                l10n.radiologyNoAssetsLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final ImagingAsset asset in widget.study.assets)
                _StudyAssetTile(
                  asset: asset,
                  canEdit: widget.canWork && !_isUploading,
                  onRemove: () async {
                    final AppFailure? failure = await widget.onRemoveAsset(
                      asset,
                    );
                    if (context.mounted && failure != null) {
                      _showMutationResult(context, failure);
                    }
                  },
                ),
            SizedBox(height: theme.spacing.md),
            Text(
              l10n.radiologyPacsLinksLabel,
              style: theme.textTheme.labelLarge,
            ),
            SizedBox(height: theme.spacing.xs),
            if (widget.study.pacsLinks.isEmpty)
              Text(
                l10n.radiologyNoPacsLinksLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final PacsLink link in widget.study.pacsLinks)
                SelectableText(
                  link.url ?? link.displayId ?? l10n.profileUnknownValue,
                  style: theme.textTheme.bodyMedium,
                ),
            SizedBox(height: theme.spacing.md),
            if (_pendingAssets.isNotEmpty) ...<Widget>[
              for (final _PendingStudyAsset pending in _pendingAssets)
                _PendingStudyAssetTile(
                  pending: pending,
                  enabled: widget.canWork && !_isUploading,
                  onCaptionChanged: (String value) {
                    setState(() => pending.caption = value);
                  },
                  onRemove: () {
                    setState(() => _pendingAssets.remove(pending));
                  },
                ),
              SizedBox(height: theme.spacing.sm),
            ],
            AppFileUploadPanel(
              title: l10n.radiologyAttachImagesTitle,
              emptyDescription: l10n.radiologyAttachImagesBody,
              chooseLabel: l10n.radiologyChooseImagesAction,
              clearLabel: l10n.radiologyClearSelectedImagesAction,
              uploadLabel: l10n.radiologyUploadImagesAction,
              fileNames: _pendingAssets
                  .map((_PendingStudyAsset asset) => asset.file.name)
                  .toList(growable: false),
              enabled: widget.canWork && !_isUploading,
              isLoading: _isUploading,
              onChoose: _pickImages,
              onClear: () => setState(() => _pendingAssets.clear()),
              onUpload: _pendingAssets.isEmpty ? null : _uploadPendingAssets,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> files = await openFiles(
        acceptedTypeGroups: <XTypeGroup>[
          XTypeGroup(
            label: context.l10n.radiologyAttachImagesTitle,
            extensions: const <String>['jpg', 'jpeg', 'png', 'webp'],
            mimeTypes: const <String>['image/jpeg', 'image/png', 'image/webp'],
          ),
        ],
      );
      if (!mounted || files.isEmpty) {
        return;
      }
      setState(() {
        for (final XFile file in files.take(8)) {
          _pendingAssets.add(_PendingStudyAsset(file: file));
        }
      });
    } catch (_) {}
  }

  Future<void> _uploadPendingAssets() async {
    if (_pendingAssets.isEmpty) {
      return;
    }

    setState(() => _isUploading = true);
    final List<StudyAssetUploadRequest> uploads = <StudyAssetUploadRequest>[];
    for (final _PendingStudyAsset pending in _pendingAssets) {
      final int sizeBytes = await pending.file.length();
      uploads.add(
        StudyAssetUploadRequest(
          fileName: pending.file.name,
          contentType: pending.file.mimeType,
          sizeBytes: sizeBytes,
          caption: pending.caption,
        ),
      );
    }

    final AppFailure? failure = await widget.onUpload(uploads);
    if (!mounted) {
      return;
    }

    setState(() {
      _isUploading = false;
      if (failure == null) {
        _pendingAssets.clear();
      }
    });

    if (failure != null) {
      _showMutationResult(context, failure);
    }
  }
}

class _PendingStudyAsset {
  _PendingStudyAsset({required this.file});

  final XFile file;
  String caption = '';
}

class _PendingStudyAssetTile extends StatelessWidget {
  const _PendingStudyAssetTile({
    required this.pending,
    required this.enabled,
    required this.onCaptionChanged,
    required this.onRemove,
  });

  final _PendingStudyAsset pending;
  final bool enabled;
  final ValueChanged<String> onCaptionChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _StudyImagePreview(file: pending.file, size: 72),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: AppTextField(
              initialValue: pending.caption,
              labelText: l10n.radiologyAssetCaptionLabel,
              hintText: pending.file.name,
              enabled: enabled,
              onChanged: onCaptionChanged,
            ),
          ),
          AppButton(
            iconOnly: true,
            leadingIcon: Icons.delete_outline,
            label: l10n.radiologyRemoveAssetAction,
            semanticLabel: l10n.radiologyRemoveAssetAction,
            tooltip: l10n.radiologyRemoveAssetAction,
            onPressed: enabled ? onRemove : null,
          ),
        ],
      ),
    );
  }
}

class _StudyAssetTile extends StatelessWidget {
  const _StudyAssetTile({
    required this.asset,
    required this.canEdit,
    required this.onRemove,
  });

  final ImagingAsset asset;
  final bool canEdit;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _StudyAssetPlaceholder(
            label:
                asset.fileName ?? asset.displayId ?? l10n.profileUnknownValue,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  asset.fileName ?? asset.displayId ?? l10n.profileUnknownValue,
                  style: theme.textTheme.titleSmall,
                ),
                if ((asset.contentType ?? '').isNotEmpty)
                  Text(
                    asset.contentType!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (canEdit)
            AppButton(
              iconOnly: true,
              leadingIcon: Icons.delete_outline,
              label: l10n.radiologyRemoveAssetAction,

              semanticLabel: l10n.radiologyRemoveAssetAction,
              tooltip: l10n.radiologyRemoveAssetAction,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _StudyImagePreview extends StatefulWidget {
  const _StudyImagePreview({required this.file, this.size = 96});

  final XFile file;
  final double size;

  @override
  State<_StudyImagePreview> createState() => _StudyImagePreviewState();
}

class _StudyImagePreviewState extends State<_StudyImagePreview> {
  late Future<Uint8List> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = widget.file.readAsBytes();
  }

  @override
  void didUpdateWidget(_StudyImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file != widget.file) {
      _bytesFuture = widget.file.readAsBytes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytesFuture,
      builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
        if (!snapshot.hasData) {
          return SizedBox.square(
            dimension: widget.size,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return ClipRRect(
          child: Image.memory(
            snapshot.data!,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}

class _StudyAssetPlaceholder extends StatelessWidget {
  const _StudyAssetPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox.square(
      dimension: 72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Icon(
          Icons.image_outlined,
          color: theme.colorScheme.onSurfaceVariant,
          semanticLabel: label,
        ),
      ),
    );
  }
}

class _DoctorReviewPanel extends StatelessWidget {
  const _DoctorReviewPanel({
    required this.order,
    required this.workflow,
    required this.canWork,
    required this.onOpenReport,
  });

  final RadiologyOrder order;
  final RadiologyWorkflow workflow;
  final bool canWork;
  final VoidCallback onOpenReport;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool released = order.hasFinalResult;

    return AppWorkspaceDetailPanel(
      title: l10n.radiologyDoctorReviewTitle,
      description: released
          ? l10n.radiologyDoctorReviewReleasedBody
          : l10n.radiologyDoctorReviewPendingBody,
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.radiologyDoctorReviewOpenReportAction,
          leadingIcon: Icons.description_outlined,
          onPressed: onOpenReport,
        ),
        if (canWork && workflow.nextActions.canAttestFinalization)
          AppButton.primary(
            label: l10n.radiologyDoctorReviewAcknowledgeAction,
            leadingIcon: Icons.verified_outlined,
            onPressed: released ? null : onOpenReport,
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppWorkspaceStatusBadge(
            status: AppWorkspaceStatus(
              label: released
                  ? l10n.radiologyDoctorReviewReadyLabel
                  : l10n.radiologyDoctorReviewPendingLabel,
              tone: released
                  ? AppWorkspaceStatusTone.success
                  : AppWorkspaceStatusTone.warning,
              icon: released
                  ? Icons.notification_important_outlined
                  : Icons.pending_actions_outlined,
            ),
          ),
          if (order.results.isNotEmpty) ...<Widget>[
            SizedBox(height: Theme.of(context).spacing.sm),
            Text(
              l10n.radiologyReportVersionsTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: Theme.of(context).spacing.xs),
            for (final RadiologyResult result
                in order.results.toList()..sort(
                  (RadiologyResult a, RadiologyResult b) =>
                      b.reportVersion.compareTo(a.reportVersion),
                ))
              Padding(
                padding: EdgeInsets.only(bottom: Theme.of(context).spacing.xs),
                child: AppListItemText(
                  title: l10n.radiologyReportVersionLabel(result.reportVersion),
                  subtitle: <String?>[
                    result.normalizedStatus,
                    result.effectiveDisplayId,
                    if (result.parentResultId != null) result.parentResultId,
                  ].whereType<String>().join(' · '),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.workflow});

  final RadiologyWorkflow workflow;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppWorkspaceDetailPanel(
      title: l10n.radiologyTimelineTitle,
      child: AppTimeline(
        emptyTitle: l10n.radiologyNoTimelineTitle,
        emptyBody: l10n.radiologyNoTimelineBody,
        items: <AppTimelineItem>[
          for (final RadiologyTimelineItem item in workflow.timeline)
            AppTimelineItem(
              title: item.label,
              occurredAt: item.occurredAt,
              icon: Icons.timeline_outlined,
            ),
        ],
      ),
    );
  }
}

Future<void> _showCreateOrderDialog(BuildContext context, WidgetRef ref) async {
  final Map<String, Object?>? payload =
      await showAppDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => const _CreateOrderForm(),
      );

  if (payload == null || !context.mounted) {
    return;
  }

  final AppFailure? failure = await ref
      .read(radiologyWorkspaceControllerProvider.notifier)
      .createOrder(payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

class _CreateOrderForm extends ConsumerStatefulWidget {
  const _CreateOrderForm();

  static String dialogTitle(AppLocalizations l10n) =>
      l10n.radiologyCreateOrderDialogTitle;
  static const IconData dialogIcon = Icons.add_a_photo_outlined;

  @override
  ConsumerState<_CreateOrderForm> createState() => _CreateOrderFormState();
}

class _CreateOrderFormState extends ConsumerState<_CreateOrderForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<ClinicalActionRadiologyRequest> _requests =
      <ClinicalActionRadiologyRequest>[];
  String? _patientId;
  String? _encounterId;
  bool _selectionTouched = false;
  ClinicalRequestBillingSubmit? _billingSubmit;

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final RadiologyWorkspaceState? state = _watchState(ref);
    final RadiologyReferenceData references =
        state?.references ?? RadiologyReferenceData.empty;
    final List<RadiologyReferenceOption> encounterOptions = _patientId == null
        ? references.encounters
        : references.encounters
              .where((RadiologyReferenceOption option) {
                return option.patientId == null ||
                    option.patientId == _patientId;
              })
              .toList(growable: false);

    return AppDialog(
      title: Text(_CreateOrderForm.dialogTitle(l10n)),
      icon: const Icon(_CreateOrderForm.dialogIcon),
      scrollable: true,
      maxWidth: 640,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  controller: _searchController,
                  labelText: l10n.radiologyReferenceSearchOptionalLabel,
                  hintText: l10n.radiologyReferenceSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: _searchReferences,
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              Padding(
                padding: EdgeInsets.only(top: theme.spacing.xs),
                child: AppButton.secondary(
                  label: l10n.radiologySearchReferenceAction,
                  leadingIcon: Icons.manage_search,
                  isLoading: state?.isRefreshing ?? false,
                  onPressed: () => _searchReferences(_searchController.text),
                ),
              ),
            ],
          ),
          AppSelectField<String>.searchable(
            value: _patientId,
            labelText: l10n.radiologyPatientLabel,
            isRequired: true,
            options: _referenceOptions(references.patients),
            validator: AppValidators.requiredValue(
              l10n.radiologyFieldRequiredLabel(l10n.radiologyPatientLabel),
            ),
            onChanged: (String? value) {
              setState(() {
                _patientId = value;
                if (!encounterOptions.any(
                  (RadiologyReferenceOption option) =>
                      option.value == _encounterId,
                )) {
                  _encounterId = null;
                }
              });
            },
          ),
          AppSelectField<String>.searchable(
            value: _encounterId,
            labelText: l10n.radiologyEncounterLabel,
            options: _referenceOptions(encounterOptions),
            onChanged: (String? value) => setState(() => _encounterId = value),
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.radiologyClinicalNotesLabel,
            maxLines: 4,
          ),
          AppSectionPanel(
            title: l10n.clinicalRadiologyRequestSelectedTitle,
            description: _requests.isEmpty
                ? l10n.clinicalRadiologyRequestNoSelection
                : l10n.clinicalRadiologyRequestSelectedCount(_requests.length),
            leadingIcon: Icons.image_search_outlined,
            children: <Widget>[
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: <Widget>[
                  AppButton.secondary(
                    label: l10n.radiologySelectImagingTestsAction,
                    leadingIcon: Icons.playlist_add_outlined,
                    onPressed: () => _openSharedRadiologySelector(state),
                  ),
                  if (_requests.isNotEmpty)
                    AppButton.tertiary(
                      label: l10n.radiologyClearSelectedTestsAction,
                      leadingIcon: Icons.clear_all_outlined,
                      onPressed: () => setState(() => _requests.clear()),
                    ),
                ],
              ),
              if (_selectionTouched && _requests.isEmpty) ...<Widget>[
                SizedBox(height: theme.spacing.sm),
                AppFormInformationBanner.message(
                  message: l10n.radiologySelectAtLeastOneTestMessage,
                  variant: AppFormInformationVariant.error,
                ),
              ],
              if (_requests.isNotEmpty) ...<Widget>[
                SizedBox(height: theme.spacing.sm),
                for (final ClinicalActionRadiologyRequest request in _requests)
                  _SelectedRadiologyRequestSummary(
                    title: _radiologyRequestTitle(state, request),
                    request: request,
                    onRemove: () => setState(() => _requests.remove(request)),
                  ),
              ],
            ],
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: l10n.radiologyRequestImagingAction,
        submitIcon: Icons.save_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }

  void _submit() {
    setState(() => _selectionTouched = true);
    if (!validateAndSaveAppForm(_formKey) || _requests.isEmpty) {
      return;
    }
    final String sharedNote = _notesController.text.trim();
    Navigator.of(context).pop(<String, Object?>{
      'patient_id': _patientId,
      'encounter_id': _encounterId,
      'ordered_at': DateTime.now().toUtc().toIso8601String(),
      'notes': sharedNote,
      'requested_tests': <Map<String, Object?>>[
        for (final ClinicalActionRadiologyRequest request in _requests)
          <String, Object?>{
            'radiology_test_id': request.radiologyTestId,
            'clinical_note': (request.clinicalNote ?? '').trim().isEmpty
                ? sharedNote
                : request.clinicalNote,
            'request_details': mergeClinicalRequestBillingIntoRequestDetails(
              <String, Object?>{
                'modality': request.modality,
                'body_region': request.bodyRegion,
                'laterality': request.laterality,
                'priority': request.priority,
              },
              _billingSubmit,
              lineAmount: clinicalRequestBillingLineAmount(
                _billingSubmit,
                request.radiologyTestId,
              ),
            ),
          },
      ],
    });
  }

  void _searchReferences(String value) {
    unawaited(
      ref
          .read(radiologyWorkspaceControllerProvider.notifier)
          .searchReferences(search: value.trim(), patientId: _patientId),
    );
  }

  String _radiologyRequestTitle(
    RadiologyWorkspaceState? state,
    ClinicalActionRadiologyRequest request,
  ) {
    final String id = request.radiologyTestId.trim();
    if (id.isEmpty) {
      return id;
    }
    for (final ClinicalActionCatalogOption option in _radiologyCatalogOptions(
      state,
    )) {
      if (option.apiId == id || option.id == id || option.publicId == id) {
        return option.displayTitle;
      }
    }
    return id;
  }

  Future<void> _openSharedRadiologySelector(
    RadiologyWorkspaceState? state,
  ) async {
    List<ClinicalActionRadiologyRequest> selected =
        List<ClinicalActionRadiologyRequest>.of(_requests);
    final RadiologyReferenceData references =
        state?.references ?? RadiologyReferenceData.empty;
    final String? facilityId =
        state?.catalogScope?.facilityId ??
        ref.read(sessionStateProvider).session?.user?.facilityId;
    RadiologyReferenceOption? patientOption;
    if (_patientId != null) {
      for (final RadiologyReferenceOption option in references.patients) {
        if (option.value == _patientId) {
          patientOption = option;
          break;
        }
      }
    }
    RadiologyReferenceOption? encounterOption;
    if (_encounterId != null) {
      for (final RadiologyReferenceOption option in references.encounters) {
        if (option.value == _encounterId) {
          encounterOption = option;
          break;
        }
      }
    }
    final bool? updated = await showAppDialog<bool>(
      context: context,
      builder: (_) => ClinicalRadiologyOrderActionDialog(
        referenceData: ClinicalActionReferenceData(
          radiologyTests: _radiologyCatalogOptions(state),
        ),
        initialRequests: _requests,
        patientContext: ClinicalRequestPatientContext(
          patientName: patientOption?.displayLabel,
          patientId: _patientId,
          encounterId: encounterOption?.displayLabel ?? _encounterId,
        ),
        onSearchRadiologyTests:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'ALL',
            }) {
              return ref
                  .read(clinicalRepositoryProvider)
                  .searchClinicalTerms(
                    termType: termType,
                    query: query,
                    limit: limit ?? 80,
                    source: source,
                    facilityId: facilityId,
                  );
            },
        onSubmit:
            ({
              required List<ClinicalActionRadiologyRequest> requests,
              ClinicalRequestBillingSubmit? billing,
            }) async {
              selected = requests;
              _billingSubmit = billing;
              return null;
            },
      ),
    );
    if (!mounted || updated != true) {
      return;
    }
    setState(() {
      _requests
        ..clear()
        ..addAll(selected);
      _selectionTouched = true;
    });
  }
}

class _SelectedRadiologyRequestSummary extends StatelessWidget {
  const _SelectedRadiologyRequestSummary({
    required this.title,
    required this.request,
    required this.onRemove,
  });

  final String title;
  final ClinicalActionRadiologyRequest request;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: Row(
        children: <Widget>[
          Icon(
            _radiologyModalityIcon(request.modality),
            size: theme.appTokens.listIconSize,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: AppListItemText(
              title: title,
              subtitle: _joinDisplay(<String?>[
                _modalityLabelOrNull(l10n, request.modality),
                request.bodyRegion,
                request.laterality,
                request.priority,
                request.clinicalNote,
              ]),
              titleStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          AppButton(
            iconOnly: true,
            leadingIcon: Icons.close,
            label: l10n.clinicalRadiologyDeleteSelectionAction,

            semanticLabel: l10n.clinicalRadiologyDeleteSelectionAction,
            tooltip: l10n.clinicalRadiologyDeleteSelectionAction,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

Future<void> _showRadiologyConfigurationsDialog(
  BuildContext context,
  WidgetRef ref, {
  String? tenantId,
}) async {
  final RadiologyWorkspaceState? state = ref
      .read(radiologyWorkspaceControllerProvider)
      .asData
      ?.value
      .when(
        success: (RadiologyWorkspaceState value) => value,
        failure: (_) => null,
      );
  if (state == null || !context.mounted) {
    return;
  }
  await showAppDialog<void>(
    context: context,
    builder: (_) => _RadiologyConfigurationsDialog(state: state),
  );
}

class _AssignForm extends ConsumerStatefulWidget {
  const _AssignForm();

  static String dialogTitle(AppLocalizations l10n) =>
      l10n.radiologyAssignDialogTitle;
  static const IconData dialogIcon = Icons.person_add_alt_outlined;

  @override
  ConsumerState<_AssignForm> createState() => _AssignFormState();
}

class _AssignFormState extends ConsumerState<_AssignForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  String? _assigneeUserId;
  String? _equipmentRegistryId;
  DateTime? _scheduledAt;

  @override
  void initState() {
    super.initState();
    final RadiologyOrder? order = ref
        .read(radiologyWorkspaceControllerProvider)
        .asData
        ?.value
        .when(
          success: (RadiologyWorkspaceState value) =>
              value.selectedWorkflow?.order,
          failure: (_) => null,
        );
    _assigneeUserId = order?.assignedUserId;
    _equipmentRegistryId = order?.equipmentRegistryId;
    _scheduledAt = order?.scheduledAt;
    _roomController.text = order?.room ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final RadiologyWorkspaceState? state = _watchState(ref);
    final List<RadiologyEquipmentRecord> equipment =
        state?.equipmentRecords ?? const <RadiologyEquipmentRecord>[];

    return AppDialog(
      title: Text(_AssignForm.dialogTitle(l10n)),
      icon: const Icon(_AssignForm.dialogIcon),
      scrollable: true,
      maxWidth: 520,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppSelectField<String>.searchable(
            value: _assigneeUserId,
            labelText: l10n.radiologyAssigneeLabel,
            options: _referenceOptions(
              state?.references.assignees ?? const <RadiologyReferenceOption>[],
            ),
            onChanged: (String? value) {
              setState(() => _assigneeUserId = value);
            },
          ),
          AppDateField(
            value: _scheduledAt,
            labelText: l10n.radiologyScheduledAtLabel,
            firstDate: DateTime.now().subtract(const Duration(days: 1)),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            currentDate: DateTime.now(),
            pickerButtonLabel: l10n.patientsDatePickerAction,
            invalidDateMessage: l10n.appDateInvalidMessage,
            onChanged: (DateTime? value) {
              setState(() => _scheduledAt = value);
            },
          ),
          AppTextField(
            controller: _roomController,
            labelText: l10n.radiologyRoomLabel,
          ),
          AppSelectField<String>.searchable(
            value: _equipmentRegistryId,
            labelText: l10n.radiologyEquipmentLabel,
            options: equipment
                .map(
                  (RadiologyEquipmentRecord item) => AppSelectOption<String>(
                    value: item.effectiveId,
                    label: item.equipmentName,
                    searchText: <String?>[
                      item.equipmentName,
                      item.equipmentCode,
                      item.displayId,
                    ].whereType<String>().join(' '),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) {
              setState(() => _equipmentRegistryId = value);
            },
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.radiologyNotesLabel,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: l10n.radiologyAssignAction,
        submitIcon: Icons.save_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }

  void _submit() {
    Navigator.of(context).pop(<String, Object?>{
      'assignee_user_id': _assigneeUserId,
      'scheduled_at': _scheduledAt?.toUtc().toIso8601String(),
      'room': _roomController.text.trim(),
      'equipment_registry_id': _equipmentRegistryId,
      'notes': _notesController.text.trim(),
    });
  }
}

Future<void> _showStudyDialog(
  BuildContext context,
  WidgetRef ref,
  RadiologyOrder order,
) async {
  final Map<String, Object?>? payload =
      await showAppDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => _StudyForm(order: order),
      );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(radiologyWorkspaceControllerProvider.notifier)
      .createStudy(payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

class _StudyForm extends StatefulWidget {
  const _StudyForm({required this.order});

  final RadiologyOrder order;

  static String dialogTitle(AppLocalizations l10n) =>
      l10n.radiologyPerformStudyDialogTitle;
  static const IconData dialogIcon = Icons.add_a_photo_outlined;

  @override
  State<_StudyForm> createState() => _StudyFormState();
}

class _StudyFormState extends State<_StudyForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _performedAtController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  late String _modality;
  late bool _modalityMatchesOrder;

  @override
  void initState() {
    super.initState();
    final String normalized = widget.order.normalizedModality;
    _modality = radiologyModalities.contains(normalized) ? normalized : 'OTHER';
    _modalityMatchesOrder = _modality == normalized;
    _performedAtController.text = AppFormatters.dateTime(
      DateTime.now(),
      WidgetsBinding.instance.platformDispatcher.locale,
    );
  }

  @override
  void dispose() {
    _performedAtController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(_StudyForm.dialogTitle(l10n)),
      icon: const Icon(_StudyForm.dialogIcon),
      scrollable: true,
      maxWidth: 520,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          Text(
            l10n.radiologyStudyFormHelper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (!_modalityMatchesOrder)
            AppSelectField<String>(
              value: _modality,
              labelText: l10n.radiologyModalityLabel,
              options: <AppSelectOption<String>>[
                for (final String modality in radiologyModalities)
                  AppSelectOption<String>(
                    value: modality,
                    label: _modalityLabel(l10n, modality),
                    leadingIcon: Icon(_radiologyModalityIcon(modality)),
                  ),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _modality = value);
                }
              },
            ),
          AppTextField(
            controller: _performedAtController,
            labelText: l10n.radiologyPerformedAtLabel,
            hintText: l10n.radiologyDateTimeHint,
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.radiologyNotesLabel,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: l10n.radiologyPerformStudyAction,
        submitIcon: Icons.add_a_photo_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }

  void _submit() {
    Navigator.of(context).pop(<String, Object?>{
      'modality': _modality,
      'performed_at': _performedAtController.text.trim(),
      'notes': _notesController.text.trim(),
    });
  }
}

Future<void> _showReportDialog(
  BuildContext context,
  WidgetRef ref,
  RadiologyOrder order,
) async {
  final bool? saved = await showAppDialog<bool>(
    context: context,
    builder: (_) => _ReportEditDialog(
      order: order,
      onSubmit: (Map<String, Object?> payload) => ref
          .read(radiologyWorkspaceControllerProvider.notifier)
          .draftResult(payload),
    ),
  );
  if (saved == true && context.mounted) {
    _showMutationResult(context, null);
  }
}

class _ReportEditDialog extends StatefulWidget {
  const _ReportEditDialog({required this.order, required this.onSubmit});

  final RadiologyOrder order;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;

  @override
  State<_ReportEditDialog> createState() => _ReportEditDialogState();
}

class _ReportEditDialogState extends State<_ReportEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _findingsController = TextEditingController();
  final TextEditingController _impressionController = TextEditingController();
  final TextEditingController _reportController = TextEditingController();
  VoidCallback? _handleReportTextChanged;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final RadiologyResult? draft = widget.order.latestDraftResult;
    _reportController.text = draft?.reportText ?? '';
    _handleReportTextChanged = () {
      if (mounted) {
        setState(() {});
      }
    };
    for (final TextEditingController controller in <TextEditingController>[
      _findingsController,
      _impressionController,
      _reportController,
    ]) {
      controller.addListener(_handleReportTextChanged!);
    }
  }

  @override
  void dispose() {
    final VoidCallback? listener = _handleReportTextChanged;
    if (listener != null) {
      _findingsController.removeListener(listener);
      _impressionController.removeListener(listener);
      _reportController.removeListener(listener);
    }
    _findingsController.dispose();
    _impressionController.dispose();
    _reportController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final String findings = _findingsController.text.trim();
    final String impression = _impressionController.text.trim();
    final String reportText = _composeRadiologyReportText(
      findings: findings,
      impression: impression,
      narrative: _reportController.text.trim(),
    );

    final AppFailure? failure = await widget.onSubmit(<String, Object?>{
      'findings': findings,
      'impression': impression,
      'report_text': reportText,
    });

    if (!mounted) {
      return;
    }

    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<_RadiologyReportReference> references =
        _radiologyReportReferences(l10n, widget.order);

    return AppDialog(
      title: Text(l10n.radiologyReportDialogTitle),
      icon: const Icon(Icons.edit_note_outlined),
      scrollable: true,
      maxWidth: 680,
      closeEnabled: !_isSubmitting,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSubmitting,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          AppTextField(
            controller: _findingsController,
            labelText: l10n.radiologyFindingsLabel,
            isRequired: true,
            minLines: 5,
            maxLines: 12,
            validator: AppValidators.requiredText(
              l10n.radiologyFieldRequiredLabel(l10n.radiologyFindingsLabel),
            ),
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          AppTextField(
            controller: _impressionController,
            labelText: l10n.radiologyImpressionLabel,
            minLines: 4,
            maxLines: 10,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          AppTextField(
            controller: _reportController,
            labelText: l10n.radiologyReportTextLabel,
            helperText: l10n.radiologyReportTextHelper,
            minLines: 7,
            maxLines: 16,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          AppClinicalResultsPreview(
            title: l10n.radiologyReportLivePreviewTitle,
            status: AppClinicalResultStatus.preliminary,
            isEmpty: _composeRadiologyReportText(
              findings: _findingsController.text.trim(),
              impression: _impressionController.text.trim(),
              narrative: _reportController.text.trim(),
            ).trim().isEmpty,
            emptyBody: l10n.radiologyEmptyReportBody,
            child: AppClinicalResultEntryView(
              entry: AppClinicalResultPreviewEntry(
                id: 'draft-composer',
                module: AppClinicalResultModule.radiology,
                title: l10n.radiologyReportLivePreviewTitle,
                status: AppClinicalResultStatus.preliminary,
                radiology: AppClinicalRadiologyReportContent(
                  findings: _findingsController.text.trim(),
                  impression: _impressionController.text.trim(),
                  reportText: _reportController.text.trim(),
                ),
              ),
            ),
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          AppSectionPanel(
            title: l10n.radiologyReportReferencesTitle,
            description: references.isEmpty
                ? l10n.radiologyNoReportReferencesLabel
                : l10n.radiologyReportReferencesBody,
            leadingIcon: Icons.link_outlined,
            children: <Widget>[
              if (references.isEmpty)
                Text(l10n.radiologyNoReportReferencesLabel)
              else
                Wrap(
                  spacing: Theme.of(context).spacing.xs,
                  runSpacing: Theme.of(context).spacing.xs,
                  children: <Widget>[
                    for (final _RadiologyReportReference reference
                        in references)
                      AppButton.tertiary(
                        label: reference.label,
                        leadingIcon: reference.icon,
                        onPressed: _isSubmitting
                            ? null
                            : () => _insertReference(reference.text),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSubmitting,
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.radiologyDraftReportAction,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }

  void _insertReference(String text) {
    final String current = _reportController.text.trimRight();
    final String next = current.isEmpty ? text : '$current\n$text';
    _reportController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }
}

class _FinalizeReportDialog extends StatefulWidget {
  const _FinalizeReportDialog({required this.result, required this.onSubmit});

  final RadiologyResult result;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;

  @override
  State<_FinalizeReportDialog> createState() => _FinalizeReportDialogState();
}

class _FinalizeReportDialogState extends State<_FinalizeReportDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _reportController;
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _reportController = TextEditingController(text: widget.result.reportText);
  }

  @override
  void dispose() {
    _reportController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final AppFailure? failure = await widget.onSubmit(<String, Object?>{
      'report_text': _reportController.text.trim(),
      'notes': _notesController.text.trim(),
    });

    if (!mounted) {
      return;
    }

    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.radiologyReleaseReportDialogTitle),
      icon: const Icon(Icons.verified_outlined),
      scrollable: true,
      maxWidth: 620,
      closeEnabled: !_isSubmitting,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSubmitting,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          AppTextField(
            controller: _reportController,
            labelText: l10n.radiologyReportTextLabel,
            isRequired: true,
            minLines: 8,
            maxLines: 16,
            validator: AppValidators.requiredText(
              l10n.radiologyFieldRequiredLabel(l10n.radiologyReportTextLabel),
            ),
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.radiologyReleaseNotesLabel,
            minLines: 3,
            maxLines: 6,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSubmitting,
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.radiologyReleaseReportAction,
          leadingIcon: Icons.verified_outlined,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }
}

Future<void> _showFinalizationNoteDialog(
  BuildContext context,
  WidgetRef ref,
  RadiologyResult result,
  String title,
  String submitLabel,
  _RadiologyResultMutation submit,
) async {
  final Map<String, Object?>? payload =
      await showAppDialog<Map<String, Object?>>(
        context: context,
        builder: (_) =>
            _FinalizationNoteForm(dialogTitle: title, submitLabel: submitLabel),
      );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await submit(result, payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

class _FinalizationNoteForm extends StatefulWidget {
  const _FinalizationNoteForm({
    required this.dialogTitle,
    required this.submitLabel,
  });

  final String dialogTitle;
  final String submitLabel;
  static const IconData dialogIcon = Icons.how_to_reg_outlined;

  @override
  State<_FinalizationNoteForm> createState() => _FinalizationNoteFormState();
}

class _FinalizationNoteFormState extends State<_FinalizationNoteForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _statementController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _statementController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(widget.dialogTitle),
      icon: const Icon(_FinalizationNoteForm.dialogIcon),
      scrollable: true,
      maxWidth: 560,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _statementController,
            labelText: l10n.radiologyFinalizationStatementLabel,
            maxLines: 3,
          ),
          AppTextField(
            controller: _reasonController,
            labelText: l10n.radiologyFinalizationReasonLabel,
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.radiologyNotesLabel,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: widget.submitLabel,
        submitIcon: Icons.save_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }

  void _submit() {
    Navigator.of(context).pop(<String, Object?>{
      'statement': _statementController.text.trim(),
      'reason': _reasonController.text.trim(),
      'notes': _notesController.text.trim(),
    });
  }
}

Future<void> _showAddendumDialog(
  BuildContext context,
  WidgetRef ref,
  RadiologyResult result,
) async {
  final Map<String, Object?>? payload =
      await showAppDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => const _AddendumForm(),
      );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(radiologyWorkspaceControllerProvider.notifier)
      .addendumResult(result, payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

class _AddendumForm extends StatefulWidget {
  const _AddendumForm();

  static String dialogTitle(AppLocalizations l10n) =>
      l10n.radiologyAddendumDialogTitle;
  static const IconData dialogIcon = Icons.post_add_outlined;

  @override
  State<_AddendumForm> createState() => _AddendumFormState();
}

class _AddendumFormState extends State<_AddendumForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _addendumController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _addendumController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(_AddendumForm.dialogTitle(l10n)),
      icon: const Icon(_AddendumForm.dialogIcon),
      scrollable: true,
      maxWidth: 560,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _addendumController,
            labelText: l10n.radiologyAddendumTextLabel,
            isRequired: true,
            maxLines: 5,
            validator: AppValidators.requiredText(
              l10n.radiologyFieldRequiredLabel(l10n.radiologyAddendumTextLabel),
            ),
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.radiologyNotesLabel,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: l10n.radiologyAddendumAction,
        submitIcon: Icons.save_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(<String, Object?>{
      'addendum_text': _addendumController.text.trim(),
      'notes': _notesController.text.trim(),
    });
  }
}

Future<void> _showCancelDialog(BuildContext context, WidgetRef ref) async {
  final Map<String, Object?>? payload =
      await showAppDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => const _CancelForm(),
      );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(radiologyWorkspaceControllerProvider.notifier)
      .cancelOrder(payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

class _CancelForm extends StatefulWidget {
  const _CancelForm();

  static String dialogTitle(AppLocalizations l10n) =>
      l10n.radiologyCancelDialogTitle;
  static const IconData dialogIcon = Icons.cancel_outlined;

  @override
  State<_CancelForm> createState() => _CancelFormState();
}

class _CancelFormState extends State<_CancelForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(_CancelForm.dialogTitle(l10n)),
      icon: const Icon(_CancelForm.dialogIcon),
      scrollable: true,
      maxWidth: 520,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _reasonController,
            labelText: l10n.radiologyCancellationReasonLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              l10n.radiologyFieldRequiredLabel(
                l10n.radiologyCancellationReasonLabel,
              ),
            ),
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.radiologyNotesLabel,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: l10n.radiologyCancelOrderAction,
        submitIcon: Icons.cancel_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(<String, Object?>{
      'reason': _reasonController.text.trim(),
      'notes': _notesController.text.trim(),
    });
  }
}

Future<void> _showPacsSyncDialog(
  BuildContext context,
  WidgetRef ref,
  ImagingStudy study,
) async {
  final Map<String, Object?>? payload =
      await showAppDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => const _PacsSyncForm(),
      );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(radiologyWorkspaceControllerProvider.notifier)
      .syncStudyToPacs(study, payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

class _PacsSyncForm extends StatefulWidget {
  const _PacsSyncForm();

  static String dialogTitle(AppLocalizations l10n) =>
      l10n.radiologyPacsSyncDialogTitle;
  static const IconData dialogIcon = Icons.cloud_sync_outlined;

  @override
  State<_PacsSyncForm> createState() => _PacsSyncFormState();
}

class _PacsSyncFormState extends State<_PacsSyncForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _studyUidController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _studyUidController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(_PacsSyncForm.dialogTitle(l10n)),
      icon: const Icon(_PacsSyncForm.dialogIcon),
      scrollable: true,
      maxWidth: 520,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _studyUidController,
            labelText: l10n.radiologyStudyUidLabel,
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.radiologyNotesLabel,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: l10n.radiologySyncPacsAction,
        submitIcon: Icons.cloud_sync_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }

  void _submit() {
    Navigator.of(context).pop(<String, Object?>{
      'study_uid': _studyUidController.text.trim(),
      'notes': _notesController.text.trim(),
    });
  }
}

Future<void> _submitNotesOnly({
  required BuildContext context,
  required String title,
  required String notesLabel,
  required String submitLabel,
  required Future<AppFailure?> Function(Map<String, Object?> payload) submit,
}) async {
  final Map<String, Object?>? payload =
      await showAppDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => _NotesOnlyForm(
          dialogTitle: title,
          notesLabel: notesLabel,
          submitLabel: submitLabel,
        ),
      );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await submit(payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

class _NotesOnlyForm extends StatefulWidget {
  const _NotesOnlyForm({
    required this.dialogTitle,
    required this.notesLabel,
    required this.submitLabel,
  });

  final String dialogTitle;
  final String notesLabel;
  final String submitLabel;
  static const IconData dialogIcon = Icons.edit_note_outlined;

  @override
  State<_NotesOnlyForm> createState() => _NotesOnlyFormState();
}

class _NotesOnlyFormState extends State<_NotesOnlyForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(widget.dialogTitle),
      icon: const Icon(_NotesOnlyForm.dialogIcon),
      scrollable: true,
      maxWidth: 520,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _notesController,
            labelText: widget.notesLabel,
            maxLines: 4,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: widget.submitLabel,
        submitIcon: Icons.save_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }

  void _submit() {
    Navigator.of(
      context,
    ).pop(<String, Object?>{'notes': _notesController.text.trim()});
  }
}

List<AppSelectOption<String>> _radiologyPriorityOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: 'ROUTINE',
      label: l10n.radiologyPriorityRoutineLabel,
    ),
    AppSelectOption<String>(
      value: 'URGENT',
      label: l10n.radiologyPriorityUrgentLabel,
    ),
    AppSelectOption<String>(
      value: 'STAT',
      label: l10n.radiologyPriorityStatLabel,
      searchText: l10n.radiologyPriorityStatHint,
    ),
  ];
}

String? _radiologyPriorityDisplayLabel(
  AppLocalizations l10n,
  String? priority,
) {
  final String? normalized = priority?.trim().toUpperCase();
  return switch (normalized) {
    'ROUTINE' => l10n.radiologyPriorityRoutineLabel,
    'URGENT' => l10n.radiologyPriorityUrgentLabel,
    'STAT' => l10n.radiologyPriorityStatLabel,
    _ => priority,
  };
}

AppClinicalResultStatus _clinicalResultStatusForRadiology(
  RadiologyResult result,
) {
  final String status = result.normalizedStatus;
  if (status == 'AMENDED') {
    return AppClinicalResultStatus.corrected;
  }
  if (result.isReleased) {
    return AppClinicalResultStatus.verified;
  }
  if (result.isDraft) {
    return AppClinicalResultStatus.preliminary;
  }
  return AppClinicalResultStatus.unavailable;
}

AppClinicalResultPreviewEntry _radiologyPreviewEntry({
  required RadiologyResult result,
  required String title,
}) {
  return AppClinicalResultPreviewEntry(
    id: result.id,
    module: AppClinicalResultModule.radiology,
    title: title,
    status: _clinicalResultStatusForRadiology(result),
    occurredAt: result.reportedAt ?? result.updatedAt ?? result.createdAt,
    subtitle: result.testDisplayName,
    radiology: AppClinicalRadiologyReportContent(
      reportText: result.reportText,
      modality: result.modality,
    ),
  );
}

List<AppSelectOption<String>> _radiologyLateralityOptions(
  AppLocalizations l10n,
) {
  return clinicalRadiologyLateralityOptions(l10n);
}

List<AppSelectOption<String>> _referenceOptions(
  List<RadiologyReferenceOption> options,
) {
  return <AppSelectOption<String>>[
    for (final RadiologyReferenceOption option in options)
      AppSelectOption<String>(value: option.value, label: option.displayLabel),
  ];
}

RadiologyWorkspaceState? _watchState(WidgetRef ref) {
  final AsyncValue<Result<RadiologyWorkspaceState>> value = ref.watch(
    radiologyWorkspaceControllerProvider,
  );
  return switch (value.asData?.value) {
    ResultSuccess<RadiologyWorkspaceState>(value: final state) => state,
    _ => null,
  };
}

List<AppListTableColumn<RadiologyOrder>> _patientViewWorklistColumns(
  BuildContext context, {
  required RadiologyWorkspaceState state,
  required bool canWork,
  required bool canRequest,
}) {
  return <AppListTableColumn<RadiologyOrder>>[
    _radiologyPatientNameColumn(context),
    _radiologyStudyColumn(context),
    _radiologyPriorityColumn(context),
    _radiologyStatusColumn(context),
    _radiologyNextActionColumn(
      context,
      state: state,
      canWork: canWork,
      canRequest: canRequest,
    ),
  ];
}

List<AppListTableColumn<RadiologyOrder>> _orderViewWorklistColumns(
  BuildContext context, {
  required RadiologyWorkspaceState state,
  required bool canWork,
  required bool canRequest,
}) {
  return <AppListTableColumn<RadiologyOrder>>[
    _radiologyOrderIdentifierColumn(context, RadiologyWorkbenchView.orders),
    _radiologyPatientNameColumn(context),
    _radiologyStudyColumn(context),
    _radiologyStatusColumn(context),
    _radiologyNextActionColumn(
      context,
      state: state,
      canWork: canWork,
      canRequest: canRequest,
    ),
  ];
}

List<AppListTableColumn<RadiologyOrder>> _optionalRadiologyWorklistColumns(
  BuildContext context,
) {
  return <AppListTableColumn<RadiologyOrder>>[
    _radiologyPatientIdColumn(context),
    _radiologyOrderIdentifierColumn(context, RadiologyWorkbenchView.patients),
    _radiologyPriorityColumn(context),
    _radiologyModalityColumn(context),
    _radiologyBodyRegionColumn(context),
    _radiologyLateralityColumn(context),
    _radiologyEncounterColumn(context),
    _radiologyBillingColumn(context),
    _radiologyOrderedAtColumn(context),
  ];
}

AppListTableColumn<RadiologyOrder> _radiologyPatientNameColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<RadiologyOrder>(
    id: 'patient',
    label: l10n.radiologyPatientColumnLabel,
    sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
        appListTableCompareText(
          left.patientDisplayName,
          right.patientDisplayName,
        ),
    cellBuilder: (BuildContext context, RadiologyOrder item) {
      final AppLocalizations l10n = context.l10n;
      return AppListItemText(
        title: item.patientDisplayName ?? l10n.profileUnknownValue,
        subtitle: item.patientId,
      );
    },
  );
}

AppListTableColumn<RadiologyOrder> _radiologyPatientIdColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<RadiologyOrder>(
    id: 'patient_id',
    label: l10n.radiologyPatientIdLabel,
    sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
        appListTableCompareText(left.patientId, right.patientId),
    cellBuilder: (BuildContext context, RadiologyOrder item) {
      return _radiologyWorklistTextCell(context, item.patientId);
    },
  );
}

AppListTableColumn<RadiologyOrder> _radiologyStudyColumn(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<RadiologyOrder>(
    id: 'study',
    label: l10n.radiologyStudyColumnLabel,
    sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
        appListTableCompareText(
          _radiologyStudyLabel(left, l10n),
          _radiologyStudyLabel(right, l10n),
        ),
    cellBuilder: (BuildContext context, RadiologyOrder item) {
      return _radiologyWorklistTextCell(
        context,
        item.testsSummary ?? item.testDisplayName,
      );
    },
  );
}

AppListTableColumn<RadiologyOrder> _radiologyPriorityColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<RadiologyOrder>(
    id: 'priority',
    label: l10n.radiologyPriorityColumnLabel,
    sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
        appListTableCompareText(left.priority, right.priority),
    cellBuilder: (BuildContext context, RadiologyOrder item) {
      return _radiologyWorklistTextCell(
        context,
        _radiologyPriorityDisplayLabel(l10n, item.priority),
      );
    },
  );
}

AppListTableColumn<RadiologyOrder> _radiologyNextActionColumn(
  BuildContext context, {
  required RadiologyWorkspaceState state,
  required bool canWork,
  required bool canRequest,
}) {
  return AppListTableColumn<RadiologyOrder>(
    id: 'next_action',
    label: context.l10n.radiologyNextActionColumnLabel,
    alwaysVisible: true,
    sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
        appListTableCompareText(
          _nextActionLabel(context, left),
          _nextActionLabel(context, right),
        ),
    cellBuilder: (BuildContext context, RadiologyOrder item) {
      return RadiologyNextActionCell(
        order: item,
        state: state,
        canWork: canWork,
        canRequest: canRequest,
        resolveLabel: _nextActionLabel,
        openDetailDialog: _openRadiologyDetailDialog,
      );
    },
  );
}

AppListTableColumn<RadiologyOrder> _radiologyStatusColumn(
  BuildContext context,
) {
  return AppListTableColumn<RadiologyOrder>(
    id: 'status',
    label: context.l10n.radiologyStatusColumnLabel,
    sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
        appListTableCompareText(left.status, right.status),
    cellBuilder: (BuildContext context, RadiologyOrder item) {
      return AppWorkspaceStatusBadge(status: _orderStatus(context, item));
    },
  );
}

AppListTableColumn<RadiologyOrder> _radiologyModalityColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<RadiologyOrder>(
    id: 'modality',
    label: l10n.radiologyModalityLabel,
    sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
        appListTableCompareText(left.modality, right.modality),
    cellBuilder: (BuildContext context, RadiologyOrder item) {
      return _radiologyWorklistTextCell(
        context,
        _modalityLabelOrNull(l10n, item.modality),
      );
    },
  );
}

AppListTableColumn<RadiologyOrder> _radiologyBodyRegionColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<RadiologyOrder>(
    id: 'body_region',
    label: l10n.radiologyBodyRegionLabel,
    sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
        appListTableCompareText(left.bodyRegion, right.bodyRegion),
    cellBuilder: (BuildContext context, RadiologyOrder item) {
      return _radiologyWorklistTextCell(context, item.bodyRegion);
    },
  );
}

AppListTableColumn<RadiologyOrder> _radiologyLateralityColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<RadiologyOrder>(
    id: 'laterality',
    label: l10n.radiologyLateralityLabel,
    sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
        appListTableCompareText(left.laterality, right.laterality),
    cellBuilder: (BuildContext context, RadiologyOrder item) {
      return _radiologyWorklistTextCell(context, item.laterality);
    },
  );
}

AppListTableColumn<RadiologyOrder> _radiologyEncounterColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<RadiologyOrder>(
    id: 'encounter',
    label: l10n.radiologyEncounterColumnLabel,
    sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
        appListTableCompareText(left.encounterId, right.encounterId),
    cellBuilder: (BuildContext context, RadiologyOrder item) {
      return _radiologyWorklistTextCell(context, item.encounterId);
    },
  );
}

AppListTableColumn<RadiologyOrder> _radiologyBillingColumn(
  BuildContext context,
) {
  return AppListTableColumn<RadiologyOrder>(
    id: 'billing',
    label: context.l10n.radiologyPaymentAuthColumnLabel,
    sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
        appListTableCompareText(
          _billingGateLabel(context, left),
          _billingGateLabel(context, right),
        ),
    cellBuilder: (BuildContext context, RadiologyOrder item) {
      return _radiologyWorklistTextCell(
        context,
        _billingGateLabel(context, item),
      );
    },
  );
}

AppListTableColumn<RadiologyOrder> _radiologyOrderedAtColumn(
  BuildContext context,
) {
  return AppListTableColumn<RadiologyOrder>(
    id: 'ordered_at',
    label: context.l10n.radiologyOrderedAtLabel,
    sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
        appListTableCompareDateTime(left.orderedAt, right.orderedAt),
    cellBuilder: (BuildContext context, RadiologyOrder item) {
      return _radiologyWorklistTextCell(
        context,
        _formatDateTimeOrNull(context, item.orderedAt),
      );
    },
  );
}

AppListTableColumn<RadiologyOrder> _radiologyOrderIdentifierColumn(
  BuildContext context,
  RadiologyWorkbenchView view,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<RadiologyOrder>(
    id: 'orders',
    label: view == RadiologyWorkbenchView.patients
        ? l10n.radiologyOrdersColumnLabel
        : l10n.radiologyOrderColumnLabel,
    sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
        appListTableCompareText(
          left.effectiveDisplayId,
          right.effectiveDisplayId,
        ),
    cellBuilder: (BuildContext context, RadiologyOrder item) {
      if (item.isPatientGroup) {
        final int activeOrders = item.activeOrderCount > 0
            ? item.activeOrderCount
            : item.orderCount;
        return _radiologyWorklistTextCell(
          context,
          _activeOrderCountLabel(l10n, activeOrders),
        );
      }
      return _radiologyWorklistTextCell(context, item.effectiveDisplayId);
    },
  );
}
