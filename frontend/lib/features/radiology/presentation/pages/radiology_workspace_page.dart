import 'dart:async';

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
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_lookups.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/presentation/controllers/radiology_workspace_controller.dart';
import 'package:hosspi_hms/features/radiology/presentation/radiology_access.dart';
import 'package:hosspi_hms/features/radiology/presentation/widgets/radiology_next_action_cell.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
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
    if (encounterId.isEmpty && orderId.isEmpty) {
      return;
    }
    final RadiologyOrder? order = _findOrderByRoute(encounterId, orderId);
    if (order == null || !mounted) {
      return;
    }
    final AppAccessPolicy accessPolicy = ref.read(appAccessPolicyProvider);
    final RadiologyDeskSection gateSection = section ?? _section;
    final bool canRequest =
        radiologyStripCreateRequirement(gateSection).isAllowed(accessPolicy);
    final bool canWork = switch (gateSection) {
      RadiologyDeskSection.worklist =>
        RadiologyWorklistAtomPermissions.write.isAllowed(accessPolicy),
      RadiologyDeskSection.reporting =>
        RadiologyReportingAtomPermissions.write.isAllowed(accessPolicy),
      RadiologyDeskSection.released =>
        RadiologyReleasedAtomPermissions.write.isAllowed(accessPolicy),
      RadiologyDeskSection.allOrders =>
        RadiologyAllOrdersAtomPermissions.write.isAllowed(accessPolicy),
      RadiologyDeskSection.followUps =>
        RadiologyFollowUpsAtomPermissions.write.isAllowed(accessPolicy),
    };
    final bool canViewBilling = switch (gateSection) {
      RadiologyDeskSection.worklist =>
        RadiologyWorklistAtomPermissions.billingHold.isAllowed(accessPolicy),
      RadiologyDeskSection.reporting =>
        RadiologyReportingAtomPermissions.billingHold.isAllowed(accessPolicy),
      RadiologyDeskSection.released =>
        RadiologyReleasedAtomPermissions.billingHold.isAllowed(accessPolicy),
      RadiologyDeskSection.allOrders =>
        RadiologyAllOrdersAtomPermissions.billingHold.isAllowed(accessPolicy),
      RadiologyDeskSection.followUps =>
        RadiologyFollowUpsAtomPermissions.billingHold.isAllowed(accessPolicy),
    };
    await _openRadiologyDetailDialog(
      context,
      ref,
      widget.state,
      order,
      canWork: canWork,
      canRequest: canRequest,
      canViewBilling: canViewBilling,
    );
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
    AppAccessPolicy accessPolicy, {
    required RadiologyDeskSection section,
  }) {
    if (section.isFollowUps) {
      return null;
    }

    return AppAccessActionGate(
      requirement: radiologyStripCreateRequirement(section),
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
    AppAccessPolicy accessPolicy, {
    required RadiologyDeskSection section,
  }) {
    if (section.isFollowUps) {
      return const <Widget>[];
    }
    final bool isPatientsView =
        state.query.view == RadiologyWorkbenchView.patients;
    final String viewLabel = isPatientsView
        ? l10n.radiologyOrdersViewAction
        : l10n.radiologyPatientsViewAction;
    return <Widget>[
      AppTabToolbarAction(
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
      ),
      AppAccessActionGate(
        requirement: radiologyStripConfigureRequirement(section),
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
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final RadiologyWorkspaceState state = widget.state;
    final controller = ref.read(radiologyWorkspaceControllerProvider.notifier);
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final List<RadiologyDeskSection> allowedSections =
        radiologyAllowedSections(accessPolicy);
    final RadiologyDeskSection effectiveSection =
        allowedSections.contains(_section)
        ? _section
        : (radiologyFallbackSection(accessPolicy) ?? _section);
    // Section atom maps (Worklist / Reporting / Released / All) share the same
    // ∩ write / billing helpers; resolve via strip create + billing hold so
    // inventory keys stay the single vocabulary for this board.
    final bool canRequest =
        radiologyStripCreateRequirement(effectiveSection).isAllowed(accessPolicy);
    final bool canWork = switch (effectiveSection) {
      RadiologyDeskSection.worklist =>
        RadiologyWorklistAtomPermissions.write.isAllowed(accessPolicy),
      RadiologyDeskSection.reporting =>
        RadiologyReportingAtomPermissions.write.isAllowed(accessPolicy),
      RadiologyDeskSection.released =>
        RadiologyReleasedAtomPermissions.write.isAllowed(accessPolicy),
      RadiologyDeskSection.allOrders =>
        RadiologyAllOrdersAtomPermissions.write.isAllowed(accessPolicy),
      RadiologyDeskSection.followUps =>
        RadiologyFollowUpsAtomPermissions.write.isAllowed(accessPolicy),
    };
    final bool canViewBilling = switch (effectiveSection) {
      RadiologyDeskSection.worklist =>
        RadiologyWorklistAtomPermissions.billingHold.isAllowed(accessPolicy),
      RadiologyDeskSection.reporting =>
        RadiologyReportingAtomPermissions.billingHold.isAllowed(accessPolicy),
      RadiologyDeskSection.released =>
        RadiologyReleasedAtomPermissions.billingHold.isAllowed(accessPolicy),
      RadiologyDeskSection.allOrders =>
        RadiologyAllOrdersAtomPermissions.billingHold.isAllowed(accessPolicy),
      RadiologyDeskSection.followUps =>
        RadiologyFollowUpsAtomPermissions.billingHold.isAllowed(accessPolicy),
    };
    final AppFailure? lastFailure = state.lastFailure;

    if (effectiveSection != _section && allowedSections.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _section == effectiveSection) {
          return;
        }
        setState(() => _section = effectiveSection);
        _updateUrlForSection(effectiveSection);
        _applyStageForSection(effectiveSection);
      });
    }

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (allowedSections.isNotEmpty)
              AppTabStrip(
                tabs: <AppTabItem>[
                  for (final RadiologyDeskSection section in allowedSections)
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
                selectedId: effectiveSection.name,
                onTabTapped: (String tabId) {
                  for (final RadiologyDeskSection section in allowedSections) {
                    if (section.name == tabId) {
                      setState(() => _section = section);
                      _updateUrlForSection(section);
                      _applyStageForSection(section);
                      break;
                    }
                  }
                },
                primaryAction: _buildPrimaryAction(
                  l10n,
                  state,
                  accessPolicy,
                  section: effectiveSection,
                ),
                secondaryActions: _buildSecondaryActions(
                  l10n,
                  state,
                  accessPolicy,
                  section: effectiveSection,
                ),
              ),
            SizedBox(height: theme.spacing.sm),
            if (allowedSections.isEmpty)
              AppWorkspaceStatePanel.empty(
                title: l10n.radiologyNoOrdersTitle,
                body: l10n.radiologyNoOrdersBody,
                icon: Icons.inbox_outlined,
              )
            else if (lastFailure != null && !effectiveSection.isFollowUps) ...<Widget>[
              AppFailureStateView(
                failure: lastFailure,
                onRetry: controller.refresh,
              ),
              SizedBox(height: theme.spacing.md),
            ],
            if (allowedSections.isNotEmpty && effectiveSection.isFollowUps)
              const FollowUpWorklistPanel(
                scope: FollowUpWorklistScope(),
                storageKeyPrefix: 'radiology_follow_ups',
                readRequirement: RadiologyFollowUpsAtomPermissions.tab,
                writeRequirement: RadiologyFollowUpsAtomPermissions.write,
              )
            else if (allowedSections.isNotEmpty)
              _RadiologyOrderBoard(
                section: effectiveSection,
                state: state,
                canWork: canWork,
                canRequest: canRequest,
                canViewBilling: canViewBilling,
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
    required this.canViewBilling,
    required this.searchController,
    required this.columnVisibilityController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  final RadiologyDeskSection section;
  final RadiologyWorkspaceState state;
  final bool canWork;
  final bool canRequest;
  final bool canViewBilling;
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
          if (canViewBilling)
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
          if (canViewBilling && nextBillingGate != state.query.billingGate) {
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
            canViewBilling: canViewBilling,
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
              canViewBilling: canViewBilling,
            )
          : _orderViewWorklistColumns(
              context,
              state: state,
              canWork: canWork,
              canRequest: canRequest,
              canViewBilling: canViewBilling,
            ),
      columnChoices: _optionalRadiologyWorklistColumns(
        context,
        canViewBilling: canViewBilling,
      ),
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
          trailing: RadiologyNextActionCell(
            order: item,
            state: state,
            canWork: canWork,
            canRequest: canRequest,
            canViewBilling: canViewBilling,
            resolveLabel: _nextActionLabel,
            openDetailDialog: _openRadiologyDetailDialog,
          ),
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
    required this.canViewBilling,
  });

  final RadiologyWorkspaceState state;
  final bool canWork;
  final bool canRequest;
  final bool canViewBilling;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    // Watch live controller state so detail view-mode / mutation flags update,
    // but keep the opened workflow snapshot when a background refresh briefly
    // clears selection (and preserve order fields used by billing chrome).
    final RadiologyWorkspaceState? live = _watchState(ref);
    final RadiologyWorkspaceState effective = live == null
        ? state
        : state.copyWith(
            detailViewMode: live.detailViewMode,
            selectedWorkflow: live.selectedWorkflow ?? state.selectedWorkflow,
            isMutating: live.isMutating,
            isRefreshingDetail: live.isRefreshingDetail,
          );
    final RadiologyWorkflow? workflow = effective.selectedWorkflow;

    if (effective.isRefreshingDetail && workflow == null) {
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
      state: effective,
      workflow: workflow,
      canWork: canWork,
      canRequest: canRequest,
      canViewBilling: canViewBilling,
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
  required bool canViewBilling,
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
        canViewBilling: canViewBilling,
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
    required this.canViewBilling,
  });

  final RadiologyWorkspaceState state;
  final RadiologyWorkflow workflow;
  final bool canWork;
  final bool canRequest;
  final bool canViewBilling;

  @override
  ConsumerState<_RadiologyDetailBody> createState() =>
      _RadiologyDetailBodyState();
}

class _RadiologyDetailBodyState extends ConsumerState<_RadiologyDetailBody> {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final RadiologyOrder order = widget.workflow.order;

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
        SizedBox(height: theme.spacing.lg),
        _ProcedureWorkbenchSection(
          workflow: widget.workflow,
          state: widget.state,
          canWork: widget.canWork,
          onMarkDone: widget.canWork && !widget.state.isMutating
              ? () => _markProcedureDone(context, ref, order)
              : null,
          onMarkReportDone: widget.canWork && !widget.state.isMutating
              ? () => _showReportDialog(context, ref, widget.workflow)
              : null,
          onUndo: widget.canWork && !widget.state.isMutating
              ? () => _undoProcedureWorkbenchStatus(context, ref, widget.workflow)
              : null,
          onCancel: widget.canWork &&
                  widget.workflow.nextActions.canCancel &&
                  !widget.state.isMutating
              ? () => _showCancelDialog(context, ref)
              : null,
        ),
      ],
    );
  }

  List<Widget> _buildHeaderActions(BuildContext context) {
    // Assign and Start imaging are intentionally omitted from this workbench;
    // Procedure done is the single acquisition confirmation.
    return const <Widget>[];
  }
}

enum _ProcedureWorkbenchStatus {
  pending,
  inProcess,
  waitingForReport,
  reported,
  cancelled,
}

_ProcedureWorkbenchStatus _procedureWorkbenchStatus(RadiologyWorkflow workflow) {
  final RadiologyOrder order = workflow.order;
  if (order.isCancelled) {
    return _ProcedureWorkbenchStatus.cancelled;
  }
  if (order.hasFinalResult) {
    return _ProcedureWorkbenchStatus.reported;
  }
  final bool hasStudy =
      order.imagingStudies.isNotEmpty || (order.studyCount > 0);
  if (hasStudy) {
    return _ProcedureWorkbenchStatus.waitingForReport;
  }
  if (order.normalizedStatus == 'IN_PROCESS') {
    return _ProcedureWorkbenchStatus.inProcess;
  }
  return _ProcedureWorkbenchStatus.pending;
}

String _procedureWorkbenchStatusLabel(
  AppLocalizations l10n,
  _ProcedureWorkbenchStatus status,
) {
  switch (status) {
    case _ProcedureWorkbenchStatus.pending:
      return l10n.radiologyProcedureStatusPending;
    case _ProcedureWorkbenchStatus.inProcess:
      return l10n.radiologyStatusInProcess;
    case _ProcedureWorkbenchStatus.waitingForReport:
      return l10n.radiologyProcedureStatusWaitingReport;
    case _ProcedureWorkbenchStatus.reported:
      return l10n.radiologyProcedureStatusReported;
    case _ProcedureWorkbenchStatus.cancelled:
      return l10n.radiologyStatusCancelled;
  }
}

String _procedureBodyOrganLabel(_ProcedureWorkbenchRow row) {
  final List<String> parts = <String>[
    if ((row.bodyRegion ?? '').trim().isNotEmpty) row.bodyRegion!.trim(),
    if ((row.laterality ?? '').trim().isNotEmpty) row.laterality!.trim(),
  ];
  return parts.join(' · ');
}

@immutable
final class _ProcedureWorkbenchRow {
  const _ProcedureWorkbenchRow({
    required this.selectionKey,
    required this.id,
    required this.name,
    this.modality,
    this.bodyRegion,
    this.laterality,
  });

  final String selectionKey;
  final String id;
  final String name;
  final String? modality;
  final String? bodyRegion;
  final String? laterality;
}

List<_ProcedureWorkbenchRow> _procedureWorkbenchRows(RadiologyOrder order) {
  if (order.requestedTests.isNotEmpty) {
    return <_ProcedureWorkbenchRow>[
      for (int index = 0; index < order.requestedTests.length; index++)
        _ProcedureWorkbenchRow(
          selectionKey:
              '${order.effectiveDisplayId}:${order.requestedTests[index].radiologyTestId ?? index}',
          id: order.effectiveDisplayId,
          name:
              (order.requestedTests[index].testDisplayName ??
                      order.testDisplayName ??
                      order.effectiveDisplayId)
                  .trim(),
          modality:
              order.requestedTests[index].modality ?? order.modality,
          bodyRegion:
              order.requestedTests[index].bodyRegion ?? order.bodyRegion,
          laterality:
              order.requestedTests[index].laterality ?? order.laterality,
        ),
    ];
  }
  return <_ProcedureWorkbenchRow>[
    _ProcedureWorkbenchRow(
      selectionKey: order.effectiveDisplayId,
      id: order.effectiveDisplayId,
      name: (order.testDisplayName ?? order.effectiveDisplayId).trim(),
      modality: order.modality,
      bodyRegion: order.bodyRegion,
      laterality: order.laterality,
    ),
  ];
}

Future<void> _undoProcedureWorkbenchStatus(
  BuildContext context,
  WidgetRef ref,
  RadiologyWorkflow workflow,
) async {
  final AppLocalizations l10n = context.l10n;
  final RadiologyOrder order = workflow.order;
  final RadiologyResult? draft = order.latestDraftResult;
  final ImagingStudy? study = order.latestStudy ??
      (workflow.studies.isEmpty ? null : workflow.studies.last);

  final bool undoDraft = draft != null;
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    builder: (_) => AppConfirmActionDialog(
      title: undoDraft
          ? l10n.radiologyUndoDraftReportTitle
          : l10n.radiologyUndoProcedureDoneTitle,
      body: undoDraft
          ? l10n.radiologyUndoDraftReportBody
          : l10n.radiologyUndoProcedureDoneBody,
      submitLabel: l10n.radiologyUndoProcedureAction,
      destructive: true,
      icon: const Icon(Icons.undo_outlined),
      onConfirm: () async => null,
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }

  final RadiologyWorkspaceController controller = ref.read(
    radiologyWorkspaceControllerProvider.notifier,
  );
  AppFailure? failure;
  if (undoDraft) {
    failure = await controller.undoDraftResult(draft);
  } else if (study != null) {
    failure = await controller.undoStudy(study);
  }
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

class _ProcedureWorkbenchSection extends StatefulWidget {
  const _ProcedureWorkbenchSection({
    required this.workflow,
    required this.state,
    required this.canWork,
    this.onMarkDone,
    this.onMarkReportDone,
    this.onUndo,
    this.onCancel,
  });

  final RadiologyWorkflow workflow;
  final RadiologyWorkspaceState state;
  final bool canWork;
  final VoidCallback? onMarkDone;
  final VoidCallback? onMarkReportDone;
  final VoidCallback? onUndo;
  final VoidCallback? onCancel;

  @override
  State<_ProcedureWorkbenchSection> createState() =>
      _ProcedureWorkbenchSectionState();
}

class _ProcedureWorkbenchSectionState extends State<_ProcedureWorkbenchSection> {
  final Set<String> _selectedKeys = <String>{};
  int? _hoveredRowIndex;
  int _hoverGeneration = 0;

  RadiologyWorkflow get workflow => widget.workflow;
  RadiologyWorkspaceState get state => widget.state;

  @override
  void didUpdateWidget(covariant _ProcedureWorkbenchSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Set<String> validKeys = _procedureWorkbenchRows(workflow.order)
        .map((_ProcedureWorkbenchRow row) => row.selectionKey)
        .toSet();
    _selectedKeys.removeWhere((String key) => !validKeys.contains(key));
  }

  void _setHoveredRow(int? index) {
    if (_hoveredRowIndex == index) {
      return;
    }
    setState(() => _hoveredRowIndex = index);
  }

  void _onRowHover(int index, bool hovering) {
    if (hovering) {
      _hoverGeneration += 1;
      _setHoveredRow(index);
      return;
    }
    final int generation = _hoverGeneration;
    Future<void>.delayed(Duration.zero, () {
      if (!mounted || _hoverGeneration != generation) {
        return;
      }
      if (_hoveredRowIndex == index) {
        _setHoveredRow(null);
      }
    });
  }

  void _toggleAll(List<_ProcedureWorkbenchRow> rows, bool? value) {
    setState(() {
      if (value == true) {
        _selectedKeys
          ..clear()
          ..addAll(rows.map((_ProcedureWorkbenchRow row) => row.selectionKey));
      } else {
        _selectedKeys.clear();
      }
    });
  }

  void _toggleRow(String key, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedKeys.add(key);
      } else {
        _selectedKeys.remove(key);
      }
    });
  }

  Future<void> _openProcedureDetails(
    BuildContext context,
    _ProcedureWorkbenchRow row,
  ) async {
    await showAppDialog<void>(
      context: context,
      builder: (_) => _ProcedureDetailsDialog(
        row: row,
        workflow: workflow,
        state: state,
        canWork: widget.canWork,
        onMarkDone: widget.onMarkDone,
        onMarkReportDone: widget.onMarkReportDone,
        onUndo: widget.onUndo,
        onCancel: widget.onCancel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final RadiologyOrder order = workflow.order;
    final List<_ProcedureWorkbenchRow> rows = _procedureWorkbenchRows(order);
    final _ProcedureWorkbenchStatus status = _procedureWorkbenchStatus(workflow);
    final RadiologyNextActions next = workflow.nextActions;
    final bool waitingForReport =
        status == _ProcedureWorkbenchStatus.waitingForReport;
    final bool reported = status == _ProcedureWorkbenchStatus.reported;
    final bool pendingLike =
        status == _ProcedureWorkbenchStatus.pending ||
        status == _ProcedureWorkbenchStatus.inProcess;
    final bool canRunProcedureDone =
        widget.canWork &&
        widget.onMarkDone != null &&
        next.canCreateStudy &&
        pendingLike;
    final bool canMarkReportDone =
        widget.onMarkReportDone != null && waitingForReport;
    final bool canViewReport =
        widget.onMarkReportDone != null && reported;
    final bool canUndo =
        widget.canWork &&
        widget.onUndo != null &&
        !order.hasFinalResult &&
        (order.hasDraftResult ||
            order.imagingStudies.isNotEmpty ||
            order.studyCount > 0 ||
            workflow.studies.isNotEmpty);
    final bool canCancel =
        widget.onCancel != null && next.canCancel && pendingLike;
    final bool allSelected =
        rows.isNotEmpty && _selectedKeys.length == rows.length;
    final bool someSelected = _selectedKeys.isNotEmpty && !allSelected;

    final Color borderColor = colors.outlineVariant;
    final TableBorder tableBorder = TableBorder(
      horizontalInside: BorderSide(color: borderColor),
      verticalInside: BorderSide(color: borderColor),
    );
    final Color hoverRowColor = colors.surfaceContainerHighest.withValues(
      alpha: 0.55,
    );

    return AppCollapsibleSection(
      title: l10n.radiologyProceduresSectionTitle,
      titleIcon: Icons.biotech_outlined,
      contentPadding: EdgeInsets.zero,
      headerActions: <Widget>[
        if (canRunProcedureDone)
          AppButton.tertiary(
            dense: true,
            label: l10n.radiologyMarkProcedureDoneSelectedAction,
            leadingIcon: Icons.check_circle_outline,
            isLoading: state.isMutating,
            onPressed: _selectedKeys.isEmpty || state.isMutating
                ? null
                : widget.onMarkDone,
          ),
        if (canCancel)
          AppButton.tertiary(
            dense: true,
            label: l10n.radiologyCancelSelectedAction,
            leadingIcon: Icons.cancel_outlined,
            color: colors.error,
            isLoading: state.isMutating,
            onPressed: _selectedKeys.isEmpty || state.isMutating
                ? null
                : widget.onCancel,
          ),
      ],
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Table(
                border: tableBorder,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const <int, TableColumnWidth>{
                  0: FixedColumnWidth(40),
                  1: FixedColumnWidth(40),
                  2: FlexColumnWidth(1.1),
                  3: FlexColumnWidth(2.0),
                  4: FlexColumnWidth(1.0),
                  5: FlexColumnWidth(1.0),
                  6: FlexColumnWidth(2.2),
                  7: FlexColumnWidth(2.8),
                },
                children: <TableRow>[
                  TableRow(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh.withValues(
                        alpha: 0.72,
                      ),
                    ),
                    children: <Widget>[
                      _ProcedureTableCell(
                        child: Checkbox(
                          tristate: true,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          value: allSelected
                              ? true
                              : (someSelected ? null : false),
                          onChanged: rows.isEmpty
                              ? null
                              : (bool? value) => _toggleAll(rows, value == true),
                        ),
                      ),
                      _ProcedureTableCell.header(
                        l10n.radiologyProcedureNumberColumnLabel,
                      ),
                      _ProcedureTableCell.header(
                        l10n.radiologyProcedureIdColumnLabel,
                      ),
                      _ProcedureTableCell.header(
                        l10n.radiologyProcedureNameColumnLabel,
                      ),
                      _ProcedureTableCell.header(l10n.radiologyModalityLabel),
                      _ProcedureTableCell.header(
                        l10n.radiologyProcedureBodyColumnLabel,
                      ),
                      _ProcedureTableCell.header(
                        l10n.radiologyProcedureStatusColumnLabel,
                      ),
                      _ProcedureTableCell.header(
                        l10n.radiologyProcedureActionsColumnLabel,
                      ),
                    ],
                  ),
                  for (int index = 0; index < rows.length; index++)
                    TableRow(
                      decoration: BoxDecoration(
                        color: _hoveredRowIndex == index ? hoverRowColor : null,
                      ),
                      children: <Widget>[
                        _ProcedureTableCell(
                          onHoverChanged: (bool hovering) {
                            _onRowHover(index, hovering);
                          },
                          child: Checkbox(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            value: _selectedKeys.contains(
                              rows[index].selectionKey,
                            ),
                            onChanged: (bool? value) => _toggleRow(
                              rows[index].selectionKey,
                              value,
                            ),
                          ),
                        ),
                        _ProcedureTableCell(
                          onHoverChanged: (bool hovering) {
                            _onRowHover(index, hovering);
                          },
                          onTap: () {
                            _openProcedureDetails(this.context, rows[index]);
                          },
                          child: Text('${index + 1}'),
                        ),
                        _ProcedureTableCell(
                          onHoverChanged: (bool hovering) {
                            _onRowHover(index, hovering);
                          },
                          onTap: () {
                            _openProcedureDetails(this.context, rows[index]);
                          },
                          debugKey: ValueKey<String>(
                            'radiology-procedure-id-${rows[index].selectionKey}',
                          ),
                          child: Text(
                            rows[index].id,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _ProcedureTableCell(
                          onHoverChanged: (bool hovering) {
                            _onRowHover(index, hovering);
                          },
                          onTap: () {
                            _openProcedureDetails(this.context, rows[index]);
                          },
                          child: Text(
                            rows[index].name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _ProcedureTableCell(
                          onHoverChanged: (bool hovering) {
                            _onRowHover(index, hovering);
                          },
                          onTap: () {
                            _openProcedureDetails(this.context, rows[index]);
                          },
                          child: Text(
                            _modalityLabelOrNull(
                                  l10n,
                                  rows[index].modality,
                                ) ??
                                (rows[index].modality ?? '—'),
                          ),
                        ),
                        _ProcedureTableCell(
                          onHoverChanged: (bool hovering) {
                            _onRowHover(index, hovering);
                          },
                          onTap: () {
                            _openProcedureDetails(this.context, rows[index]);
                          },
                          child: Text(
                            _procedureBodyOrganLabel(rows[index]).ifEmpty('—'),
                          ),
                        ),
                        _ProcedureTableCell(
                          onHoverChanged: (bool hovering) {
                            _onRowHover(index, hovering);
                          },
                          onTap: () {
                            _openProcedureDetails(this.context, rows[index]);
                          },
                          child: _ProcedureStatusLabel(
                            label: _procedureWorkbenchStatusLabel(l10n, status),
                            tone: switch (status) {
                              _ProcedureWorkbenchStatus.pending =>
                                AppWorkspaceStatusTone.warning,
                              _ProcedureWorkbenchStatus.inProcess =>
                                AppWorkspaceStatusTone.info,
                              _ProcedureWorkbenchStatus.waitingForReport =>
                                AppWorkspaceStatusTone.info,
                              _ProcedureWorkbenchStatus.reported =>
                                AppWorkspaceStatusTone.success,
                              _ProcedureWorkbenchStatus.cancelled =>
                                AppWorkspaceStatusTone.error,
                            },
                          ),
                        ),
                        _ProcedureTableCell(
                          onHoverChanged: (bool hovering) {
                            _onRowHover(index, hovering);
                          },
                          child: AppActionLabelScope(
                            showLabels: true,
                            forceIconOnly: false,
                            plainChrome: true,
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: OverflowBar(
                                spacing: theme.spacing.xs,
                                overflowSpacing: theme.spacing.xs,
                                overflowAlignment: OverflowBarAlignment.end,
                                children: <Widget>[
                                  if (canRunProcedureDone)
                                    AppButton.secondary(
                                      dense: true,
                                      label:
                                          l10n.radiologyMarkProcedureDoneAction,
                                      leadingIcon: Icons.check_circle_outline,
                                      isLoading: state.isMutating,
                                      onPressed: state.isMutating
                                          ? null
                                          : widget.onMarkDone,
                                    ),
                                  if (canMarkReportDone)
                                    AppButton.primary(
                                      dense: true,
                                      label: l10n.radiologyCreateReportAction,
                                      leadingIcon: Icons.edit_note_outlined,
                                      onPressed: widget.onMarkReportDone,
                                    ),
                                  if (canViewReport)
                                    AppButton.primary(
                                      dense: true,
                                      label: l10n.radiologyViewReportAction,
                                      leadingIcon: Icons.description_outlined,
                                      onPressed: widget.onMarkReportDone,
                                    ),
                                  if (canUndo)
                                    AppButton.tertiary(
                                      dense: true,
                                      label: l10n.radiologyUndoProcedureAction,
                                      leadingIcon: Icons.undo_outlined,
                                      onPressed: state.isMutating
                                          ? null
                                          : widget.onUndo,
                                    ),
                                  if (canCancel)
                                    AppButton.tertiary(
                                      dense: true,
                                      label: l10n.radiologyCancelOrderAction,
                                      leadingIcon: Icons.cancel_outlined,
                                      color: colors.error,
                                      isLoading: state.isMutating,
                                      onPressed: state.isMutating
                                          ? null
                                          : widget.onCancel,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProcedureDetailsDialog extends StatelessWidget {
  const _ProcedureDetailsDialog({
    required this.row,
    required this.workflow,
    required this.state,
    required this.canWork,
    this.onMarkDone,
    this.onMarkReportDone,
    this.onUndo,
    this.onCancel,
  });

  final _ProcedureWorkbenchRow row;
  final RadiologyWorkflow workflow;
  final RadiologyWorkspaceState state;
  final bool canWork;
  final VoidCallback? onMarkDone;
  final VoidCallback? onMarkReportDone;
  final VoidCallback? onUndo;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final RadiologyOrder order = workflow.order;
    final _ProcedureWorkbenchStatus status = _procedureWorkbenchStatus(workflow);
    final RadiologyNextActions next = workflow.nextActions;
    final bool waitingForReport =
        status == _ProcedureWorkbenchStatus.waitingForReport;
    final bool reported = status == _ProcedureWorkbenchStatus.reported;
    final bool pendingLike =
        status == _ProcedureWorkbenchStatus.pending ||
        status == _ProcedureWorkbenchStatus.inProcess;
    final bool canRunProcedureDone =
        canWork && onMarkDone != null && next.canCreateStudy && pendingLike;
    final bool canMarkReportDone = onMarkReportDone != null && waitingForReport;
    final bool canOpenReport = onMarkReportDone != null && reported;
    final bool canUndo =
        canWork &&
        onUndo != null &&
        !order.hasFinalResult &&
        (order.hasDraftResult ||
            order.imagingStudies.isNotEmpty ||
            order.studyCount > 0 ||
            workflow.studies.isNotEmpty);
    final bool canCancel =
        onCancel != null && next.canCancel && pendingLike;
    final AppWorkspaceStatusTone statusTone = switch (status) {
      _ProcedureWorkbenchStatus.pending => AppWorkspaceStatusTone.warning,
      _ProcedureWorkbenchStatus.inProcess => AppWorkspaceStatusTone.info,
      _ProcedureWorkbenchStatus.waitingForReport => AppWorkspaceStatusTone.info,
      _ProcedureWorkbenchStatus.reported => AppWorkspaceStatusTone.success,
      _ProcedureWorkbenchStatus.cancelled => AppWorkspaceStatusTone.error,
    };
    final String nextStepHint = switch (status) {
      _ProcedureWorkbenchStatus.pending =>
        l10n.radiologyProcedureDetailsPendingHint,
      _ProcedureWorkbenchStatus.inProcess =>
        l10n.radiologyProcedureDetailsInProcessHint,
      _ProcedureWorkbenchStatus.waitingForReport =>
        l10n.radiologyProcedureDetailsWaitingReportHint,
      _ProcedureWorkbenchStatus.reported =>
        l10n.radiologyProcedureDetailsReportedHint,
      _ProcedureWorkbenchStatus.cancelled =>
        l10n.radiologyProcedureDetailsCancelledHint,
    };
    final String modalityValue =
        _modalityLabelOrNull(l10n, row.modality) ?? (row.modality ?? '—');
    final String bodyOrgan = _procedureBodyOrganLabel(row).ifEmpty('—');

    void runAndClose(VoidCallback? action) {
      if (action == null) {
        return;
      }
      Navigator.of(context).maybePop();
      action();
    }

    return AppDialog(
      title: Text(
        l10n.radiologyProcedureDetailsDialogTitle,
        key: const ValueKey<String>('radiology-procedure-details-title'),
      ),
      icon: const Icon(Icons.biotech_outlined),
      scrollable: true,
      maxWidth: 640,
      pinActionsToBottom: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppCollapsibleSection(
            title: row.name,
            titleIcon: Icons.biotech_outlined,
            headerActions: <Widget>[
              _ProcedureStatusLabel(
                label: _procedureWorkbenchStatusLabel(l10n, status),
                tone: statusTone,
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _ProcedureDetailParameterRow(
                  icon: Icons.tag_outlined,
                  parameter: l10n.radiologyProcedureIdColumnLabel,
                  value: AppCopyableIdentifier(
                    value: row.id,
                    tooltip: l10n.copyIdentifierAction,
                    copiedMessage: l10n.identifierCopiedMessage,
                  ),
                ),
                SizedBox(height: theme.spacing.md),
                _ProcedureDetailParameterRow(
                  icon: Icons.camera_alt_outlined,
                  parameter: l10n.radiologyModalityLabel,
                  value: Text(
                    modalityValue,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: theme.spacing.md),
                _ProcedureDetailParameterRow(
                  icon: Icons.accessibility_new_outlined,
                  parameter: l10n.radiologyProcedureBodyColumnLabel,
                  value: Text(
                    bodyOrgan,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: theme.spacing.md),
                _ProcedureDetailParameterRow(
                  icon: Icons.tips_and_updates_outlined,
                  parameter: l10n.radiologyProcedureDetailsNextStepLabel,
                  value: Text(
                    nextStepHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        if (canCancel)
          AppButton.tertiary(
            label: l10n.radiologyCancelOrderAction,
            leadingIcon: Icons.cancel_outlined,
            color: colors.error,
            isLoading: state.isMutating,
            onPressed: state.isMutating ? null : () => runAndClose(onCancel),
          ),
        if (canUndo)
          AppButton.tertiary(
            label: l10n.radiologyUndoProcedureAction,
            leadingIcon: Icons.undo_outlined,
            isLoading: state.isMutating,
            onPressed: state.isMutating ? null : () => runAndClose(onUndo),
          ),
        if (canRunProcedureDone)
          AppButton.primary(
            label: l10n.radiologyMarkProcedureDoneAction,
            leadingIcon: Icons.check_circle_outline,
            isLoading: state.isMutating,
            onPressed: state.isMutating ? null : () => runAndClose(onMarkDone),
          ),
        if (canMarkReportDone || canOpenReport)
          AppButton.primary(
            label: canMarkReportDone
                ? l10n.radiologyCreateReportAction
                : l10n.radiologyViewReportAction,
            leadingIcon: canMarkReportDone
                ? Icons.edit_note_outlined
                : Icons.description_outlined,
            onPressed: () => runAndClose(onMarkReportDone),
          ),
      ],
    );
  }
}

class _ProcedureDetailParameterRow extends StatelessWidget {
  const _ProcedureDetailParameterRow({
    required this.icon,
    required this.parameter,
    required this.value,
  });

  final IconData icon;
  final String parameter;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String label = parameter.trim().endsWith(':')
        ? parameter.trim()
        : '${parameter.trim()}:';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: colors.primary),
        SizedBox(width: theme.spacing.sm),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(child: value),
      ],
    );
  }
}

class _ProcedureStatusLabel extends StatelessWidget {
  const _ProcedureStatusLabel({required this.label, required this.tone});

  final String label;
  final AppWorkspaceStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = switch (tone) {
      AppWorkspaceStatusTone.neutral => theme.colorScheme.onSurfaceVariant,
      AppWorkspaceStatusTone.success => theme.statusColors.success,
      AppWorkspaceStatusTone.warning => theme.statusColors.warning,
      AppWorkspaceStatusTone.error => theme.statusColors.error,
      AppWorkspaceStatusTone.info => theme.statusColors.info,
    };
    final IconData icon = switch (tone) {
      AppWorkspaceStatusTone.neutral => Icons.radio_button_unchecked,
      AppWorkspaceStatusTone.success => Icons.check_circle_outline,
      AppWorkspaceStatusTone.warning => Icons.warning_amber_outlined,
      AppWorkspaceStatusTone.error => Icons.error_outline,
      AppWorkspaceStatusTone.info => Icons.info_outline,
    };

    return Semantics(
      label: label,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: theme.appTokens.listIconSize, color: color),
          ),
          SizedBox(width: theme.spacing.xs),
          Expanded(
            child: Text(
              label,
              softWrap: true,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcedureTableCell extends StatelessWidget {
  const _ProcedureTableCell({
    required this.child,
    this.onTap,
    this.onHoverChanged,
    this.debugKey,
  }) : _headerLabel = null;

  const _ProcedureTableCell.header(String label)
    : child = null,
      onTap = null,
      onHoverChanged = null,
      debugKey = null,
      _headerLabel = label;

  final Widget? child;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onHoverChanged;
  final Key? debugKey;
  final String? _headerLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget content = _headerLabel != null
        ? Text(
            _headerLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          )
        : child!;
    Widget cell = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      child: content,
    );
    if (onTap != null) {
      cell = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: cell,
      );
    }
    if (onHoverChanged != null) {
      cell = MouseRegion(
        onEnter: (_) => onHoverChanged!(true),
        onExit: (_) => onHoverChanged!(false),
        child: cell,
      );
    }
    if (debugKey != null) {
      return KeyedSubtree(key: debugKey, child: cell);
    }
    return cell;
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
                fontWeight: FontWeight.w600,
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

Future<void> _markProcedureDone(
  BuildContext context,
  WidgetRef ref,
  RadiologyOrder order,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    builder: (_) => AppConfirmActionDialog(
      title: l10n.radiologyMarkProcedureDoneConfirmTitle,
      body: l10n.radiologyMarkProcedureDoneConfirmBody,
      submitLabel: l10n.radiologyMarkProcedureDoneAction,
      icon: const Icon(Icons.check_circle_outline),
      submitLeadingIcon: Icons.check_circle_outline,
      onConfirm: () async => null,
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }

  final String modality = _studyModalityForOrder(order);
  final AppFailure? failure = await ref
      .read(radiologyWorkspaceControllerProvider.notifier)
      .createStudy(<String, Object?>{
        'modality': modality,
        if ((order.room ?? '').trim().isNotEmpty) 'room': order.room!.trim(),
        if ((order.equipmentRegistryId ?? '').trim().isNotEmpty)
          'equipment_registry_id': order.equipmentRegistryId!.trim(),
        'performed_at': DateTime.now().toUtc().toIso8601String(),
      });
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

String _studyModalityForOrder(RadiologyOrder order) {
  final String normalized = order.normalizedModality
      .replaceAll('-', '')
      .replaceAll('_', '');
  if (radiologyModalities.contains(order.normalizedModality)) {
    return order.normalizedModality;
  }
  if (normalized == 'XRAY') {
    return 'XRAY';
  }
  for (final String modality in radiologyModalities) {
    if (modality == normalized || modality.replaceAll('_', '') == normalized) {
      return modality;
    }
  }
  return 'OTHER';
}

Future<void> _showReportDialog(
  BuildContext context,
  WidgetRef ref,
  RadiologyWorkflow workflow,
) async {
  final bool? saved = await showAppDialog<bool>(
    context: context,
    builder: (_) => _ReportEditDialog(
      workflow: workflow,
      onSubmit: (Map<String, Object?> payload) => ref
          .read(radiologyWorkspaceControllerProvider.notifier)
          .draftResult(payload),
      onFinalize: workflow.order.latestDraftResult == null
          ? null
          : (Map<String, Object?> payload) {
              final RadiologyResult draft = workflow.order.latestDraftResult!;
              return ref
                  .read(radiologyWorkspaceControllerProvider.notifier)
                  .finalizeResult(draft, payload);
            },
      onSyncPacs: workflow.order.latestStudy == null
          ? null
          : (Map<String, Object?> payload) {
              final ImagingStudy study = workflow.order.latestStudy!;
              return ref
                  .read(radiologyWorkspaceControllerProvider.notifier)
                  .syncStudyToPacs(study, payload);
            },
      onUploadLocal: workflow.order.latestStudy == null
          ? null
          : (List<StudyAssetUploadRequest> uploads) {
              final ImagingStudy study = workflow.order.latestStudy!;
              return ref
                  .read(radiologyWorkspaceControllerProvider.notifier)
                  .uploadStudyAssets(study: study, uploads: uploads);
            },
      onPrint: () => _showRadiologyPrintDialog(context, workflow),
    ),
  );
  if (saved == true && context.mounted) {
    _showMutationResult(context, null);
  }
}

class _ReportEditDialog extends StatefulWidget {
  const _ReportEditDialog({
    required this.workflow,
    required this.onSubmit,
    this.onFinalize,
    this.onSyncPacs,
    this.onUploadLocal,
    this.onPrint,
  });

  final RadiologyWorkflow workflow;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;
  final Future<AppFailure?> Function(Map<String, Object?> payload)? onFinalize;
  final Future<AppFailure?> Function(Map<String, Object?> payload)? onSyncPacs;
  final Future<AppFailure?> Function(List<StudyAssetUploadRequest> uploads)?
  onUploadLocal;
  final Future<void> Function()? onPrint;

  RadiologyOrder get order => workflow.order;

  @override
  State<_ReportEditDialog> createState() => _ReportEditDialogState();
}

class _ReportEditDialogState extends State<_ReportEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _techniqueController = TextEditingController();
  final TextEditingController _findingsController = TextEditingController();
  final TextEditingController _impressionController = TextEditingController();
  final TextEditingController _recommendationController =
      TextEditingController();
  final TextEditingController _reportController = TextEditingController();
  VoidCallback? _handleReportTextChanged;
  bool _isSubmitting = false;
  bool _isUploading = false;
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
      _techniqueController,
      _findingsController,
      _impressionController,
      _recommendationController,
      _reportController,
    ]) {
      controller.addListener(_handleReportTextChanged!);
    }
  }

  @override
  void dispose() {
    final VoidCallback? listener = _handleReportTextChanged;
    if (listener != null) {
      _techniqueController.removeListener(listener);
      _findingsController.removeListener(listener);
      _impressionController.removeListener(listener);
      _recommendationController.removeListener(listener);
      _reportController.removeListener(listener);
    }
    _techniqueController.dispose();
    _findingsController.dispose();
    _impressionController.dispose();
    _recommendationController.dispose();
    _reportController.dispose();
    super.dispose();
  }

  String get _composedReportText => _composeRadiologyReportText(
    technique: _techniqueController.text.trim(),
    findings: _findingsController.text.trim(),
    impression: _impressionController.text.trim(),
    recommendation: _recommendationController.text.trim(),
    narrative: _reportController.text.trim(),
  );

  Future<void> _submit({bool finalize = false}) async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final String findings = _findingsController.text.trim();
    final String reportText = _composedReportText.trim();
    // Accept structured findings or a legacy draft that only stored report_text.
    if (findings.isEmpty && reportText.isEmpty) {
      setState(() {
        _failure = AppFailure.validation(
          detailMessage: context.l10n.radiologyFieldRequiredLabel(
            context.l10n.radiologyFindingsLabel,
          ),
          validationFields: const <String>{'findings'},
          fieldMessages: <String, String>{
            'findings': context.l10n.radiologyFieldRequiredLabel(
              context.l10n.radiologyFindingsLabel,
            ),
          },
        );
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final String impression = _impressionController.text.trim();
    final String resolvedFindings =
        findings.isNotEmpty ? findings : reportText;
    final String resolvedReportText =
        reportText.isNotEmpty ? reportText : resolvedFindings;

    AppFailure? failure = await widget.onSubmit(<String, Object?>{
      'findings': resolvedFindings,
      'impression': impression,
      'technique': _techniqueController.text.trim(),
      'recommendation': _recommendationController.text.trim(),
      'report_text': resolvedReportText,
    });

    if (failure == null &&
        finalize &&
        widget.onFinalize != null &&
        widget.order.latestDraftResult != null) {
      failure = await widget.onFinalize!(<String, Object?>{
        'report_text': resolvedReportText,
      });
    }

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

  Future<void> _attachLocalImages() async {
    if (widget.onUploadLocal == null) {
      _showSnack(context.l10n.radiologyPerformStudyFirstMessage);
      return;
    }
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
      setState(() => _isUploading = true);
      final List<StudyAssetUploadRequest> uploads = <StudyAssetUploadRequest>[];
      for (final XFile file in files.take(8)) {
        final int sizeBytes = await file.length();
        uploads.add(
          StudyAssetUploadRequest(
            fileName: file.name,
            contentType: file.mimeType,
            sizeBytes: sizeBytes,
          ),
        );
      }
      final AppFailure? failure = await widget.onUploadLocal!(uploads);
      if (!mounted) {
        return;
      }
      setState(() => _isUploading = false);
      if (failure != null) {
        setState(() => _failure = failure);
        return;
      }
      _insertReference(
        '${context.l10n.radiologyImageSourceLocalLabel}: ${uploads.map((StudyAssetUploadRequest u) => u.fileName).join(', ')}',
      );
      _showSnack(context.l10n.radiologySavedMessage);
    } catch (_) {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _attachRemoteImage() async {
    final Map<String, String>? result = await showAppDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _RemoteImageForm(),
    );
    if (result == null || !mounted) {
      return;
    }
    final String url = result['url'] ?? '';
    final String caption = result['caption'] ?? '';
    final String label = caption.isEmpty
        ? '${context.l10n.radiologyImageSourceRemoteLabel}: $url'
        : '${context.l10n.radiologyImageSourceRemoteLabel}: $caption ($url)';
    _insertReference(label);
  }

  Future<void> _attachFromPacs() async {
    if (widget.onSyncPacs == null) {
      _showSnack(context.l10n.radiologyPerformStudyFirstMessage);
      return;
    }
    final Map<String, Object?>? payload =
        await showAppDialog<Map<String, Object?>>(
          context: context,
          builder: (_) => const _PacsSyncForm(),
        );
    if (payload == null || !mounted) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSyncPacs!(payload);
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);
    if (failure != null) {
      setState(() => _failure = failure);
      return;
    }
    _insertReference(
      '${context.l10n.radiologyImageSourcePacsLabel}: ${payload['accession_number'] ?? payload['study_instance_uid'] ?? 'synced'}',
    );
    _showSnack(context.l10n.radiologySavedMessage);
  }

  void _insertExistingStudyImages() {
    final List<_RadiologyReportReference> references =
        _radiologyReportReferences(context.l10n, widget.order);
    if (references.isEmpty) {
      _showSnack(context.l10n.radiologyNoExistingStudyImagesMessage);
      return;
    }
    for (final _RadiologyReportReference reference in references) {
      _insertReference(reference.text);
    }
  }

  void _showSnack(String message) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool busy = _isSubmitting || _isUploading;

    return AppDialog(
      title: Text(l10n.radiologyReportDialogTitle),
      icon: const Icon(Icons.edit_note_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 760,
      closeEnabled: !busy,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !busy,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          AppRichTextEditor(
            controller: _techniqueController,
            labelText: l10n.radiologyTechniqueLabel,
            minLines: 3,
            maxLines: 8,
          ),
          SizedBox(height: theme.spacing.md),
          AppRichTextEditor(
            controller: _findingsController,
            labelText: l10n.radiologyFindingsLabel,
            minLines: 5,
            maxLines: 12,
          ),
          SizedBox(height: theme.spacing.md),
          AppRichTextEditor(
            controller: _impressionController,
            labelText: l10n.radiologyImpressionLabel,
            minLines: 4,
            maxLines: 10,
          ),
          SizedBox(height: theme.spacing.md),
          AppRichTextEditor(
            controller: _recommendationController,
            labelText: l10n.radiologyRecommendationLabel,
            minLines: 3,
            maxLines: 8,
          ),
          SizedBox(height: theme.spacing.md),
          AppRichTextEditor(
            controller: _reportController,
            labelText: l10n.radiologyReportTextLabel,
            minLines: 6,
            maxLines: 14,
          ),
          SizedBox(height: theme.spacing.md),
          AppSectionPanel(
            title: l10n.radiologyImageSourcesTitle,
            description: l10n.radiologyImageSourcesBody,
            leadingIcon: Icons.collections_outlined,
            children: <Widget>[
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: <Widget>[
                  AppButton.tertiary(
                    dense: true,
                    label: l10n.radiologyImageSourceLocalAction,
                    leadingIcon: Icons.folder_open_outlined,
                    isLoading: _isUploading,
                    onPressed: busy ? null : _attachLocalImages,
                  ),
                  AppButton.tertiary(
                    dense: true,
                    label: l10n.radiologyImageSourceRemoteAction,
                    leadingIcon: Icons.link_outlined,
                    onPressed: busy ? null : _attachRemoteImage,
                  ),
                  AppButton.tertiary(
                    dense: true,
                    label: l10n.radiologyImageSourcePacsAction,
                    leadingIcon: Icons.cloud_sync_outlined,
                    onPressed: busy ? null : _attachFromPacs,
                  ),
                  AppButton.tertiary(
                    dense: true,
                    label: l10n.radiologyImageSourceExistingAction,
                    leadingIcon: Icons.photo_library_outlined,
                    onPressed: busy ? null : _insertExistingStudyImages,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          AppClinicalResultsPreview(
            title: l10n.radiologyReportLivePreviewTitle,
            status: AppClinicalResultStatus.preliminary,
            isEmpty: _composedReportText.trim().isEmpty,
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
        ],
      ),
      actions: <Widget>[
        AppAccessActionGate(
          requirement: radiologyPrintReportRequirement,
          builder: (BuildContext context, bool isAllowed) {
            return AppButton.tertiary(
              label: l10n.radiologyPrintReportAction,
              leadingIcon: Icons.print_outlined,
              enabled: isAllowed && !busy && widget.onPrint != null,
              onPressed: !isAllowed || busy || widget.onPrint == null
                  ? null
                  : () => widget.onPrint!(),
            );
          },
        ),
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !busy,
          onPressed: busy ? null : () => Navigator.of(context).pop(false),
        ),
        if (widget.onFinalize != null && widget.order.latestDraftResult != null)
          AppButton.secondary(
            label: l10n.radiologyReleaseReportAction,
            leadingIcon: Icons.verified_outlined,
            isLoading: _isSubmitting,
            onPressed: busy ? null : () => _submit(finalize: true),
          ),
        AppButton.primary(
          label: l10n.radiologyDraftReportAction,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSubmitting,
          onPressed: busy ? null : () => _submit(),
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

class _RemoteImageForm extends StatefulWidget {
  const _RemoteImageForm();

  @override
  State<_RemoteImageForm> createState() => _RemoteImageFormState();
}

class _RemoteImageFormState extends State<_RemoteImageForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.radiologyRemoteImageDialogTitle),
      icon: const Icon(Icons.link_outlined),
      scrollable: true,
      maxWidth: 520,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _urlController,
            labelText: l10n.radiologyRemoteImageUrlLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              l10n.radiologyFieldRequiredLabel(l10n.radiologyRemoteImageUrlLabel),
            ),
          ),
          AppTextField(
            controller: _captionController,
            labelText: l10n.radiologyRemoteImageCaptionLabel,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: l10n.radiologyImageSourceRemoteAction,
        submitIcon: Icons.link_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: () {
          if (!validateAndSaveAppForm(_formKey)) {
            return;
          }
          Navigator.of(context).pop(<String, String>{
            'url': _urlController.text.trim(),
            'caption': _captionController.text.trim(),
          });
        },
      ),
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

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(_CancelForm.dialogTitle(l10n)),
      icon: const Icon(_CancelForm.dialogIcon),
      scrollable: true,
      maxWidth: 560,
      pinActionsToBottom: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppRichTextEditor(
            controller: _reasonController,
            labelText: l10n.radiologyCancellationReasonLabel,
            hintText: l10n.radiologyCancellationReasonHint,
            isRequired: true,
            minLines: 4,
            maxLines: 10,
            validator: AppValidators.requiredText(
              l10n.radiologyFieldRequiredLabel(
                l10n.radiologyCancellationReasonLabel,
              ),
            ),
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
    final String reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      return;
    }
    Navigator.of(context).pop(<String, Object?>{
      'reason': reason,
    });
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
  required bool canViewBilling,
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
      canViewBilling: canViewBilling,
    ),
  ];
}

List<AppListTableColumn<RadiologyOrder>> _orderViewWorklistColumns(
  BuildContext context, {
  required RadiologyWorkspaceState state,
  required bool canWork,
  required bool canRequest,
  required bool canViewBilling,
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
      canViewBilling: canViewBilling,
    ),
  ];
}

List<AppListTableColumn<RadiologyOrder>> _optionalRadiologyWorklistColumns(
  BuildContext context, {
  required bool canViewBilling,
}) {
  return <AppListTableColumn<RadiologyOrder>>[
    _radiologyPatientIdColumn(context),
    _radiologyOrderIdentifierColumn(context, RadiologyWorkbenchView.patients),
    _radiologyPriorityColumn(context),
    _radiologyModalityColumn(context),
    _radiologyBodyRegionColumn(context),
    _radiologyLateralityColumn(context),
    _radiologyEncounterColumn(context),
    if (canViewBilling) _radiologyBillingColumn(context),
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
  required bool canViewBilling,
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
        canViewBilling: canViewBilling,
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
