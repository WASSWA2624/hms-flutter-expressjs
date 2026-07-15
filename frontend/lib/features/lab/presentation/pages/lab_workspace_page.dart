import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_lookups.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/presentation/controllers/lab_workspace_controller.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_status_display.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_result_entry_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/facility_catalog/facility_catalog_scope_section.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class LabWorkspacePage extends ConsumerWidget {
  const LabWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<LabWorkspaceState>> state = ref.watch(
      labWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<LabWorkspaceState>(
      value: state,
      loadingTitle: l10n.labLoadingTitle,
      loadingBody: l10n.labLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(labWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, LabWorkspaceState data) {
        return _LabWorkspaceContent(state: data);
      },
    );
  }
}

class _LabWorkspaceContent extends ConsumerStatefulWidget {
  const _LabWorkspaceContent({required this.state});

  final LabWorkspaceState state;

  @override
  ConsumerState<_LabWorkspaceContent> createState() =>
      _LabWorkspaceContentState();
}

class _LabWorkspaceContentState extends ConsumerState<_LabWorkspaceContent> {
  static const AccessRequirement _mutationRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[AppPermissions.labWrite],
    activeModules: <String>['lab-workflows'],
  );

  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<LabOrderSummary>
  _tableColumnController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<LabOrderSummary>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyScopeFromRoute());
  }

  void _applyScopeFromRoute() {
    if (!mounted) {
      return;
    }
    final String? scopeParam = GoRouterState.of(
      context,
    ).uri.queryParameters[_labScopeFilterKey];
    if (scopeParam == null || scopeParam.isEmpty) {
      return;
    }
    final LabQueueScope scope = _labScopeFromFilter(scopeParam);
    if (scope == widget.state.query.scope) {
      return;
    }
    unawaited(
      ref.read(labWorkspaceControllerProvider.notifier).applyScope(scope),
    );
  }

  @override
  void didUpdateWidget(covariant _LabWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _tableColumnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final LabWorkspaceState state = widget.state;
    final LabWorkspaceController controller = ref.read(
      labWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool canMutate = _mutationRequirement.isAllowed(policy);

    return AppWorkspace(
      title: l10n.labTitle,
      leadingIcon: AppRouteIcons.lab,
      toolbar: appWorkspaceToolbarWithLabels(
        l10n,
        summaryNotifications: <AppWorkspaceSummaryNotification>[
          if (state.summary.totalForView(state.query.view) > 0)
            _summaryNotification(
              context,
              label: state.query.view == LabWorkbenchView.patients
                  ? l10n.labPatientsSummaryLabel
                  : l10n.labTotalOrdersSummaryLabel,
              value: state.summary.totalForView(state.query.view),
              icon: Icons.assignment_outlined,
              tone: AppWorkspaceStatusTone.info,
              onPressed: () => controller.applyScope(LabQueueScope.all),
            ),
          if (state.summary.collectionForView(state.query.view) > 0)
            _summaryNotification(
              context,
              label: state.query.view == LabWorkbenchView.patients
                  ? l10n.labPatientsAwaitingResultsSummaryLabel
                  : l10n.labWaitingSampleSummaryLabel,
              value: state.summary.collectionForView(state.query.view),
              icon: Icons.biotech_outlined,
              tone: AppWorkspaceStatusTone.warning,
              onPressed: () => controller.applyScope(LabQueueScope.collection),
            ),
          if (state.summary.processingForView(state.query.view) > 0)
            _summaryNotification(
              context,
              label: state.query.view == LabWorkbenchView.patients
                  ? l10n.labPatientsProcessingSummaryLabel
                  : l10n.labProcessingSummaryLabel,
              value: state.summary.processingForView(state.query.view),
              icon: Icons.sync_outlined,
              tone: AppWorkspaceStatusTone.info,
              onPressed: () => controller.applyScope(LabQueueScope.processing),
            ),
          if (state.summary.resultsForView(state.query.view) > 0)
            _summaryNotification(
              context,
              label: state.query.view == LabWorkbenchView.patients
                  ? l10n.labPatientsPendingVerificationSummaryLabel
                  : l10n.labResultPendingSummaryLabel,
              value: state.summary.resultsForView(state.query.view),
              icon: Icons.pending_actions_outlined,
              tone: AppWorkspaceStatusTone.warning,
              onPressed: () => controller.applyScope(LabQueueScope.results),
            ),
          if (state.summary.criticalForView(state.query.view) > 0)
            _summaryNotification(
              context,
              label: state.query.view == LabWorkbenchView.patients
                  ? l10n.labPatientsCriticalSummaryLabel
                  : l10n.labCriticalSummaryLabel,
              value: state.summary.criticalForView(state.query.view),
              icon: Icons.priority_high_outlined,
              tone: AppWorkspaceStatusTone.error,
              onPressed: () => controller.applyScope(LabQueueScope.critical),
            ),
          if (state.summary.completedForView(state.query.view) > 0)
            _summaryNotification(
              context,
              label: state.query.view == LabWorkbenchView.patients
                  ? l10n.labPatientsCompletedSummaryLabel
                  : l10n.labCompletedSummaryLabel,
              value: state.summary.completedForView(state.query.view),
              icon: Icons.verified_outlined,
              tone: AppWorkspaceStatusTone.success,
              onPressed: () => controller.applyScope(LabQueueScope.completed),
            ),
        ],
        secondary: <Widget>[
          AppWorkspaceViewToggle(
            label: state.query.view == LabWorkbenchView.patients
                ? l10n.labOrdersViewAction
                : l10n.labPatientsViewAction,
            icon: Icons.swap_horiz_outlined,
            semanticLabel: state.query.view == LabWorkbenchView.patients
                ? l10n.labOrdersViewAction
                : l10n.labPatientsViewAction,
            tooltip: state.query.view == LabWorkbenchView.patients
                ? l10n.labOrdersViewAction
                : l10n.labPatientsViewAction,
            onPressed: () => controller.applyView(
              state.query.view == LabWorkbenchView.patients
                  ? LabWorkbenchView.orders
                  : LabWorkbenchView.patients,
            ),
          ),
          if (canMutate)
            AppButton.secondary(
              label: l10n.labReferenceRangesAction,
              leadingIcon: Icons.tune_outlined,
              semanticLabel: l10n.labReferenceRangesAction,
              tooltip: l10n.labReferenceRangesAction,
              onPressed: () => _openLabConfigurationsDialog(context, state),
            ),
        ],
        primary: canMutate
            ? AppButton.primary(
                label: l10n.labCreateAction,
                leadingIcon: Icons.add_circle_outline,
                semanticLabel: l10n.labCreateAction,
                tooltip: l10n.labCreateAction,
                enabled: !state.isSaving,
                onPressed: () => _openCreateLabOrderDialog(context, state),
              )
            : null,
        onRefresh: () async {
          final AppFailure? failure = await controller.refresh();
          if (context.mounted) {
            _showFailureIfNeeded(context, failure);
          }
        },
        isRefreshing: state.isRefreshing,
      ),

      body: _LabWorklistPanel(
        state: state,
        canMutate: canMutate,
        searchController: _searchController,
        columnVisibilityController: _tableColumnController,
        onSearchChanged: _scheduleWorklistSearch,
        onSearchSubmitted: _submitWorklistSearch,
        onSearchCleared: _clearWorklistSearch,
      ),
    );
  }

  void _scheduleWorklistSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      final LabWorkspaceState current = widget.state;
      if (current.query.search == value.trim()) {
        return;
      }
      unawaited(
        ref.read(labWorkspaceControllerProvider.notifier).applySearch(value),
      );
    });
  }

  void _submitWorklistSearch(String value) {
    _searchDebounce?.cancel();
    unawaited(
      ref.read(labWorkspaceControllerProvider.notifier).applySearch(value),
    );
  }

  void _clearWorklistSearch() {
    _searchDebounce?.cancel();
    unawaited(
      ref.read(labWorkspaceControllerProvider.notifier).applySearch(''),
    );
  }

  AppWorkspaceSummaryNotification _summaryNotification(
    BuildContext context, {
    required String label,
    required int value,
    required IconData icon,
    required AppWorkspaceStatusTone tone,
    required VoidCallback onPressed,
  }) {
    return AppWorkspaceSummaryNotification(
      label: label,
      count: value,
      icon: icon,
      tone: tone,
      onSelected: onPressed,
    );
  }
}

class _LabWorklistPanel extends ConsumerWidget {
  const _LabWorklistPanel({
    required this.state,
    required this.canMutate,
    required this.searchController,
    required this.columnVisibilityController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onSearchCleared,
  });

  final LabWorkspaceState state;
  final bool canMutate;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<LabOrderSummary>
  columnVisibilityController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onSearchCleared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final LabWorkspaceController controller = ref.read(
      labWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: state.query.view == LabWorkbenchView.patients
          ? l10n.labPatientsWorklistTitle
          : l10n.labWorklistTitle,
      description: state.query.view == LabWorkbenchView.patients
          ? null
          : l10n.labWorklistDescription,
      child: Stack(
        children: <Widget>[
          AppListTable<LabOrderSummary>(
            page: state.worklist,
            columnVisibilityController: columnVisibilityController,
            columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
            columnVisibilityTitle: l10n.labTableColumnsTitle,
            columnVisibilityApplyLabel: l10n.labApplyColumnsAction,
            columnVisibilityResetLabel: l10n.labResetColumnsAction,
            search: AppListTableSearch<LabOrderSummary>(
              controller: searchController,
              semanticLabel: l10n.labSearchLabel,
              hintText: l10n.labSearchHint,
              matcher: (_, _) => true,
              onChanged: onSearchChanged,
              onSubmitted: onSearchSubmitted,
              onClear: onSearchCleared,
              showAdvancedFilterButton: true,
              advancedFilterButtonLabel: l10n.labFiltersLabel,
              advancedFilterTitle: l10n.labFiltersLabel,
              advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
              advancedFilterResetLabel: l10n.opdClearFiltersAction,
              enableDateFilter: false,
              allFieldsLabel: l10n.labScopeAll,
              filterGroups: <AppSearchBarFilterGroup>[
                AppSearchBarFilterGroup(
                  key: _labScopeFilterKey,
                  label: l10n.labScopeFilterLabel,
                  allLabel: l10n.labScopeAll,
                  choices: _labScopeFilterChoices(l10n),
                ),
              ],
              filterValue: _labFilterValue(state.query),
              hasActiveFilters: state.query.scope != LabQueueScope.all,
              onFilterChanged: (AppSearchBarFilterValue value) {
                controller.applyScope(
                  _labScopeFromFilter(value.option(_labScopeFilterKey)),
                );
              },
            ),
            previousPageLabel: l10n.labPreviousPageLabel,
            nextPageLabel: l10n.labNextPageLabel,
            pageLabelBuilder: (AppPage<LabOrderSummary> page) {
              return _pageLabel(context, page);
            },
            onPageChanged: controller.changePage,
            onRowSelected: (LabOrderSummary order) {
              unawaited(
                _openLabDetailDialog(context, ref, state, order, canMutate),
              );
            },
            emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
              title: state.query.view == LabWorkbenchView.patients
                  ? l10n.labNoPatientsTitle
                  : l10n.labNoOrdersTitle,
              body: state.query.view == LabWorkbenchView.patients
                  ? l10n.labNoPatientsBody
                  : l10n.labNoOrdersBody,
              icon: Icons.science_outlined,
            ),
            columns: state.query.view == LabWorkbenchView.patients
                ? _patientViewWorklistColumns(context)
                : _orderViewWorklistColumns(context),
            columnChoices: _optionalWorklistColumns(context),
            mobileItemBuilder: (BuildContext context, LabOrderSummary item) {
              return AppListItemRow(
                title: item.displayTitle,
                subtitle: item.isPatientGroup ? item.patientId : item.apiId,
                details: <Widget>[
                  AppWorkspaceStatusBadge(
                    status: _orderStatus(context, item.status),
                  ),
                ],
                trailing: const Icon(Icons.chevron_right),
              );
            },
          ),
          if (state.isRefreshing)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}

List<AppListTableColumn<LabOrderSummary>> _patientViewWorklistColumns(
  BuildContext context,
) {
  return <AppListTableColumn<LabOrderSummary>>[
    _patientNameWorklistColumn(context),
    _patientIdWorklistColumn(context),
    _encounterWorklistColumn(context),
    _labEncounterWorklistColumn(context),
    _sourceLocationWorklistColumn(context),
    _orderWorklistColumn(context, LabWorkbenchView.patients),
    _entryStatusWorklistColumn(context),
    _billingWorklistColumn(context),
    _resultStatusWorklistColumn(context),
  ];
}

List<AppListTableColumn<LabOrderSummary>> _orderViewWorklistColumns(
  BuildContext context,
) {
  return <AppListTableColumn<LabOrderSummary>>[
    _orderWorklistColumn(context, LabWorkbenchView.orders),
    _patientNameWorklistColumn(context),
    _entryStatusWorklistColumn(context),
    _billingWorklistColumn(context),
    _resultStatusWorklistColumn(context),
  ];
}

List<AppListTableColumn<LabOrderSummary>> _optionalWorklistColumns(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppListTableColumn<LabOrderSummary>>[
    _patientIdWorklistColumn(context),
    _encounterWorklistColumn(context),
    _labEncounterWorklistColumn(context),
    _sourceLocationWorklistColumn(context),
    AppListTableColumn<LabOrderSummary>(
      id: 'tests',
      label: l10n.labTestsColumnLabel,
      sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
          appListTableCompareText(left.testsLabel, right.testsLabel),
      cellBuilder: (BuildContext context, LabOrderSummary item) {
        return _labWorklistTextCell(
          context,
          item.testsLabel ?? l10n.profileUnknownValue,
        );
      },
    ),
    AppListTableColumn<LabOrderSummary>(
      id: 'next_action',
      label: l10n.labNextActionColumnLabel,
      sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
          appListTableCompareText(
            _nextActionLabel(context, left),
            _nextActionLabel(context, right),
          ),
      cellBuilder: (BuildContext context, LabOrderSummary item) {
        return _labWorklistTextCell(context, _nextActionLabel(context, item));
      },
    ),
  ];
}

AppListTableColumn<LabOrderSummary> _patientNameWorklistColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'patient',
    label: l10n.labPatientColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareText(_patientSortKey(left), _patientSortKey(right)),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return _labWorklistTextCell(
        context,
        item.patientDisplayName ?? item.displayTitle,
      );
    },
  );
}

AppListTableColumn<LabOrderSummary> _patientIdWorklistColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'patient_id',
    label: l10n.labPatientIdColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareText(left.patientId, right.patientId),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return _labWorklistTextCell(
        context,
        item.patientId ?? l10n.profileUnknownValue,
      );
    },
  );
}

AppListTableColumn<LabOrderSummary> _encounterWorklistColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'encounter',
    label: l10n.labEncounterColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareText(left.encounterId, right.encounterId),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return _labWorklistTextCell(
        context,
        item.encounterId ?? l10n.profileUnknownValue,
      );
    },
  );
}

AppListTableColumn<LabOrderSummary> _labEncounterWorklistColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'lab_encounter',
    label: l10n.labLabEncounterColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareText(
          _labOrderEncounterLabel(left),
          _labOrderEncounterLabel(right),
        ),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return _labWorklistTextCell(
        context,
        _labOrderEncounterLabel(item) ?? l10n.profileUnknownValue,
      );
    },
  );
}

AppListTableColumn<LabOrderSummary> _sourceLocationWorklistColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'source_location',
    label: l10n.labSourceLocationColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareText(
          _sourceLocationLabel(left),
          _sourceLocationLabel(right),
        ),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return _labWorklistTextCell(
        context,
        _sourceLocationLabel(item) ?? l10n.profileUnknownValue,
      );
    },
  );
}

AppListTableColumn<LabOrderSummary> _entryStatusWorklistColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'entry_status',
    label: l10n.labEntryStatusColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareNumber(
          _enteredResultItemCount(left),
          _enteredResultItemCount(right),
        ),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return AppWorkspaceStatusBadge(status: _entryStatus(context, item));
    },
  );
}

AppListTableColumn<LabOrderSummary> _billingWorklistColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'billing',
    label: l10n.labPaymentColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareText(
          left.effectivePaymentStatus,
          right.effectivePaymentStatus,
        ),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return _labWorklistTextCell(context, _labBillingGateLabel(context, item));
    },
  );
}

AppListTableColumn<LabOrderSummary> _resultStatusWorklistColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'result_status',
    label: l10n.labResultStatusLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareNumber(
          _completedResultItemCount(left),
          _completedResultItemCount(right),
        ),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return AppWorkspaceStatusBadge(status: _resultStatus(context, item));
    },
  );
}

Widget _labWorklistTextCell(BuildContext context, String value) {
  final ThemeData theme = Theme.of(context);
  return Text(
    value,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: theme.textTheme.bodyMedium,
  );
}

String? _labOrderEncounterLabel(LabOrderSummary order) {
  if (order.isPatientGroup) {
    if (order.orderDisplayIds.isNotEmpty) {
      return order.orderDisplayIds.first;
    }
    if (order.orderIds.isNotEmpty) {
      return order.orderIds.first;
    }
  }
  return order.displayId ?? order.apiId;
}

String? _sourceLocationLabel(LabOrderSummary order) {
  return _joinNonEmpty(<String?>[
    order.encounterSourceLabel,
    order.encounterLocationLabel,
  ]);
}

AppListTableColumn<LabOrderSummary> _orderWorklistColumn(
  BuildContext context,
  LabWorkbenchView view,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'orders',
    label: view == LabWorkbenchView.patients
        ? l10n.labOrdersColumnLabel
        : l10n.labOrderColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareText(_orderSortKey(left), _orderSortKey(right)),
    cellBuilder: (BuildContext context, LabOrderSummary item) {
      return _LabOrderIdentifier(order: item);
    },
  );
}

String _patientSortKey(LabOrderSummary order) {
  final String value = _joinNonEmpty(<String?>[
    order.patientDisplayName,
    order.patientId,
    order.displayTitle,
  ]);
  return value.isNotEmpty ? value : order.id;
}

String _orderSortKey(LabOrderSummary order) {
  if (order.isPatientGroup) {
    final int activeOrders = order.activeOrderCount > 0
        ? order.activeOrderCount
        : order.orderCount;
    return activeOrders.toString().padLeft(4, '0');
  }
  return order.apiId;
}

class _LabOrderIdentifier extends StatelessWidget {
  const _LabOrderIdentifier({required this.order});

  final LabOrderSummary order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (order.isPatientGroup) {
      final int activeOrders = order.activeOrderCount > 0
          ? order.activeOrderCount
          : order.orderCount;
      final List<String> ids = order.orderDisplayIds.isNotEmpty
          ? order.orderDisplayIds
          : order.orderIds;
      final String summary = ids.isEmpty
          ? l10n.labActiveOrderCount(activeOrders)
          : '${l10n.labActiveOrderCount(activeOrders)} · ${ids.take(3).join(', ')}';
      return _labWorklistTextCell(context, summary);
    }

    return _labWorklistTextCell(context, order.displayId ?? order.apiId);
  }
}

Future<void> _openLabDetailDialog(
  BuildContext context,
  WidgetRef ref,
  LabWorkspaceState fallbackState,
  LabOrderSummary order,
  bool canMutate,
) async {
  final LabWorkspaceController controller = ref.read(
    labWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectOrder(order);
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }

  final LabWorkspaceState state = _readLabState(ref) ?? fallbackState;
  final bool hasSelection =
      state.selectedWorkflow != null || state.selectedWorkflows.isNotEmpty;
  if (!hasSelection) {
    return;
  }

  await showAppDialog<void>(
    context: context,
    builder: (_) => LabResultEntryDialog(
      canMutate: canMutate,
      onCreateAdditionalOrder: canMutate
          ? (BuildContext dialogContext, LabOrderWorkflow workflow) {
              return _openAdditionalLabOrderDialog(
                dialogContext,
                state,
                workflow.order,
              );
            }
          : null,
      onEditOrder: (BuildContext dialogContext, LabOrderWorkflow workflow) {
        return _openEditLabOrderDialog(dialogContext, state, workflow);
      },
      onDeleteOrder: (BuildContext dialogContext, LabOrderWorkflow workflow) {
        return _openDeleteLabOrderDialog(dialogContext, workflow);
      },
    ),
  );
}

LabWorkspaceState? _readLabState(WidgetRef ref) {
  return ref
      .read(labWorkspaceControllerProvider)
      .asData
      ?.value
      .when(success: (LabWorkspaceState state) => state, failure: (_) => null);
}

class _CompactRecordRow extends StatelessWidget {
  const _CompactRecordRow({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            SizedBox(width: theme.spacing.sm),
            Flexible(child: trailing!),
          ],
        ],
      ),
    );
  }
}

class _LabConfigurationsDialog extends ConsumerStatefulWidget {
  const _LabConfigurationsDialog({required this.state});

  final LabWorkspaceState state;

  @override
  ConsumerState<_LabConfigurationsDialog> createState() =>
      _LabConfigurationsDialogState();
}

class _LabConfigurationsDialogState
    extends ConsumerState<_LabConfigurationsDialog> {
  static const String _categoryFilterKey = 'category';
  static const String _resultKindFilterKey = 'result_kind';
  static const int _maxVisibleCatalogItems = 160;

  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<LabCatalogItem>
  _columnVisibilityController;
  late LabWorkspaceState _dialogState;
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;
  LabCatalogItemType _catalogType = LabCatalogItemType.test;
  String? _tenantId;
  String? _facilityId;
  bool _initializedScope = false;

  LabCatalogScope get _catalogScope =>
      LabCatalogScope(tenantId: _tenantId, facilityId: _facilityId);

  bool get _showTenantSelector {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    return policy.isElevated;
  }

  bool get _showFacilitySelector {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    if (policy.isElevated) {
      return true;
    }
    return policy.canManageTenant() && !policy.hasFacilityContext;
  }

  bool get _showScopeContextLabel {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    return !_showTenantSelector &&
        !_showFacilitySelector &&
        policy.hasFacilityContext;
  }

  bool get _canEnableOfferings {
    // Mirrors backend LAB_CONFIG_WRITE_ROLES (super/tenant/facility admin +
    // lab tech): all of these hold the lab:write permission.
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    return policy.grants(AppPermissions.labWrite);
  }

  @override
  void initState() {
    super.initState();
    _dialogState = widget.state;
    _searchController = TextEditingController();
    _columnVisibilityController =
        AppListTableColumnVisibilityController<LabCatalogItem>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_initializeScope());
    });
  }

  Future<void> _initializeScope() async {
    if (!mounted) {
      return;
    }
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    final LabCatalogScope? existingScope = widget.state.catalogScope;
    final String? tenantId = _showTenantSelector
        ? existingScope?.tenantId
        : policy.tenantId ?? existingScope?.tenantId;
    final bool hasResolvedTenant = tenantId?.trim().isNotEmpty ?? false;
    final String? facilityId = _resolveInitialFacilityId(
      policy: policy,
      existingScope: existingScope,
      hasResolvedTenant: hasResolvedTenant,
    );

    setState(() {
      _tenantId = tenantId;
      _facilityId = facilityId;
      _initializedScope = true;
    });
    await _reloadCatalogIfReady();
  }

  String? _resolveInitialFacilityId({
    required AppAccessPolicy policy,
    required LabCatalogScope? existingScope,
    required bool hasResolvedTenant,
  }) {
    if (!_showFacilitySelector) {
      return policy.facilityId ?? existingScope?.facilityId;
    }
    if (_showTenantSelector) {
      return hasResolvedTenant ? existingScope?.facilityId : null;
    }
    return policy.facilityId ?? existingScope?.facilityId;
  }

  Future<void> _reloadCatalogIfReady() async {
    await ref
        .read(labWorkspaceControllerProvider.notifier)
        .loadFacilityCatalogConfig(_catalogScope);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _columnVisibilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    ref.listen<AsyncValue<Result<LabWorkspaceState>>>(
      labWorkspaceControllerProvider,
      (_, AsyncValue<Result<LabWorkspaceState>> next) {
        final LabWorkspaceState? nextState = _workspaceStateFromAsync(next);
        if (nextState == null ||
            !_shouldSyncCatalogState(_dialogState, nextState)) {
          return;
        }
        setState(() => _dialogState = nextState);
      },
    );
    final LabWorkspaceState state = _dialogState;
    final List<LabCatalogItem> items = _filteredItems(state);
    final bool showingTests = _catalogType == LabCatalogItemType.test;
    final bool scopeReady = _catalogScope.isReady;
    final bool isLoading =
        scopeReady && (!_initializedScope || state.isLoadingCatalog);
    final AppFailure? loadFailure = state.catalogLoadFailure is AppFailure
        ? state.catalogLoadFailure as AppFailure
        : null;
    final AsyncValue<Result<HomeDashboardLookups>>? lookupsAsync =
        _initializedScope
        ? ref.watch(
            homeLookupsControllerProvider(
              HomeDashboardRequest(
                tenantId: _tenantId,
                facilityId: _facilityId,
              ),
            ),
          )
        : null;
    final List<HomeLookupOption> tenantOptions =
        lookupsAsync?.value?.when(
          success: (HomeDashboardLookups value) => value.tenants,
          failure: (_) => const <HomeLookupOption>[],
        ) ??
        const <HomeLookupOption>[];
    final bool hasTenant = _tenantId?.trim().isNotEmpty ?? false;
    final List<HomeLookupOption> facilityOptions = _facilityOptionsForScope(
      lookupsAsync: lookupsAsync,
      hasTenant: hasTenant,
    );
    final String? facilityLabel = _facilityLabel(facilityOptions);
    final String? tenantLabel = _tenantLabel(tenantOptions);
    final bool facilitySelectorEnabled = _showTenantSelector
        ? hasTenant
        : facilityOptions.isNotEmpty;

    return AppDialog(
      title: Text(l10n.labReferenceRangesDialogTitle),
      icon: const Icon(Icons.tune_outlined),
      scrollable: true,
      maxWidth: 980,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.labReferenceRangesDialogBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          FacilityCatalogScopeSection(
            labels: FacilityCatalogScopeLabels(
              facilityContextLabel: l10n.labConfigurationsFacilityContextLabel,
              selectTenantFirstTooltip:
                  l10n.labConfigurationsSelectTenantFirstTooltip,
              tenantLabel: l10n.settingsWorkspaceTenantLabel,
              facilityLabel: l10n.settingsWorkspaceFacilitySelectorLabel,
            ),
            scopeReady: scopeReady,
            showTenantSelector: _showTenantSelector,
            showFacilitySelector: _showFacilitySelector,
            showScopeContextLabel: _showScopeContextLabel,
            tenantOptions: tenantOptions,
            facilityOptions: facilityOptions,
            tenantId: _tenantId,
            facilityId: _facilityId,
            facilitySelectorEnabled: facilitySelectorEnabled,
            facilityLabel: facilityLabel,
            scopePromptMessage: _scopePromptMessage(
              l10n,
              tenantLabel: tenantLabel,
            ),
            onTenantChanged: (String? value) async {
              setState(() {
                _tenantId = value;
                _facilityId = null;
              });
              await _reloadCatalogIfReady();
            },
            onFacilityChanged: (String? value) async {
              setState(() => _facilityId = value);
              await _reloadCatalogIfReady();
            },
          ),
          if (scopeReady) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            _LabConfigurationTypeSelector(
              value: _catalogType,
              onChanged: (LabCatalogItemType value) {
                setState(() {
                  _catalogType = value;
                  _filterValue = AppSearchBarFilterValue.empty;
                  _searchController.clear();
                });
              },
            ),
            SizedBox(height: theme.spacing.md),
            if (isLoading)
              AppWorkspaceStatePanel.loading(
                title: l10n.labConfigurationsLoadingTitle,
                body: l10n.labConfigurationsLoadingBody,
                minHeight: 220,
              )
            else if (loadFailure != null &&
                state.catalogTests.isEmpty &&
                state.catalogPanels.isEmpty)
              AppFormInformationBanner.failure(
                context: context,
                failure: loadFailure,
              )
            else
              AppListTable<LabCatalogItem>(
                items: items,
                maxVisibleItems: _maxVisibleCatalogItems,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                tableHorizontalMargin: 0,
                columnVisibilityController: _columnVisibilityController,
                columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
                columnVisibilityTitle: l10n.labTableColumnsTitle,
                columnVisibilityApplyLabel: l10n.labApplyColumnsAction,
                columnVisibilityResetLabel: l10n.labResetColumnsAction,
                search: AppListTableSearch<LabCatalogItem>(
                  controller: _searchController,
                  semanticLabel: l10n.labCatalogSearchLabel,
                  hintText: l10n.labReferenceRangesSearchHint,
                  matcher: (LabCatalogItem item, String query) =>
                      item.matchesSearch(query),
                  trailingActions: <AppSearchBarAction>[
                    if (_canEnableOfferings)
                      AppSearchBarAction(
                        icon: showingTests
                            ? Icons.add_circle_outline
                            : Icons.add_box_outlined,
                        label: showingTests
                            ? l10n.labEnableTestAction
                            : l10n.labEnablePanelAction,
                        tooltip: showingTests
                            ? l10n.labEnableTestAction
                            : l10n.labEnablePanelAction,
                        onPressed: () => showingTests
                            ? _openEnableLabTestDialog(context, state)
                            : _openEnableLabPanelDialog(context, state),
                      ),
                  ],
                  showAdvancedFilterButton: true,
                  advancedFilterButtonLabel: l10n.labFiltersLabel,
                  advancedFilterTitle: l10n.labFiltersLabel,
                  advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
                  advancedFilterResetLabel: l10n.opdClearFiltersAction,
                  enableDateFilter: false,
                  allFieldsLabel: l10n.labScopeAll,
                  filterGroups: <AppSearchBarFilterGroup>[
                    AppSearchBarFilterGroup(
                      key: _categoryFilterKey,
                      label: l10n.labCategoryLabel,
                      allLabel: l10n.labScopeAll,
                      choices: _filterChoices(
                        _catalogItems(
                          state,
                        ).map((LabCatalogItem item) => item.category),
                      ),
                    ),
                    if (showingTests)
                      AppSearchBarFilterGroup(
                        key: _resultKindFilterKey,
                        label: l10n.labResultKindLabel,
                        allLabel: l10n.labScopeAll,
                        choices: _filterChoices(
                          state.catalogTests.map(
                            (LabCatalogItem item) => item.resultKind,
                          ),
                        ),
                      ),
                  ],
                  filterValue: _filterValue,
                  hasActiveFilters: _filterValue.isActive,
                  onFilterChanged: (AppSearchBarFilterValue value) {
                    setState(() => _filterValue = value);
                  },
                ),
                emptyBuilder: (_) => AppMutedText(
                  showingTests
                      ? l10n.labNoOfferedTestsLabel
                      : l10n.labNoOfferedPanelsLabel,
                ),
                columns: _defaultColumns(context, state, showingTests),
                columnChoices: _additionalColumns(context, showingTests),
                mobileItemBuilder: (BuildContext context, LabCatalogItem item) {
                  return _CompactRecordRow(
                    title: item.displayTitle,
                    subtitle: _joinNonEmpty(<String?>[
                      item.category,
                      if (showingTests) item.specimenType,
                      if (showingTests) _resultKindLabel(l10n, item.resultKind),
                      showingTests
                          ? _unitRangeSummary(context, item)
                          : l10n.clinicalLabOrderItemCount(item.testCount),
                    ]),
                    trailing: Wrap(
                      spacing: theme.spacing.xs,
                      runSpacing: theme.spacing.xs,
                      children: <Widget>[
                        AppButton.tertiary(
                          label: showingTests
                              ? l10n.labConfigureTestAction
                              : l10n.labUpdatePanelAction,
                          leadingIcon: Icons.edit_outlined,
                          onPressed: () => showingTests
                              ? _openLabTestConfigurationDialog(
                                  context,
                                  state,
                                  item,
                                )
                              : _openLabPanelDialog(context, state, item),
                        ),
                        AppButton(
                          iconOnly: true,
                          leadingIcon: Icons.delete_outline,
                          label: showingTests
                              ? l10n.labDeleteTestAction
                              : l10n.labDeletePanelAction,
                          semanticLabel: showingTests
                              ? l10n.labDeleteTestAction
                              : l10n.labDeletePanelAction,
                          tooltip: showingTests
                              ? l10n.labDeleteTestAction
                              : l10n.labDeletePanelAction,
                          onPressed: () => showingTests
                              ? _openDeleteLabTestDialog(context, item)
                              : _openDeleteLabPanelDialog(context, item),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const Divider(height: 24),
            Text(
              l10n.labQcLogsAction,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: theme.spacing.xs),
            AppMutedText(l10n.labQcLogsSectionBody),
            SizedBox(height: theme.spacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton.tertiary(
                label: l10n.labQcLogsAction,
                leadingIcon: Icons.fact_check_outlined,
                onPressed: () => _openQcDialog(context, state),
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  List<LabCatalogItem> _catalogItems(LabWorkspaceState state) {
    return _catalogType == LabCatalogItemType.test
        ? state.catalogTests
        : state.catalogPanels;
  }

  LabWorkspaceState? _workspaceStateFromAsync(
    AsyncValue<Result<LabWorkspaceState>> value,
  ) {
    return value.asData?.value.when(
      success: (LabWorkspaceState state) => state,
      failure: (_) => null,
    );
  }

  bool _shouldSyncCatalogState(
    LabWorkspaceState current,
    LabWorkspaceState next,
  ) {
    return current.catalogTests != next.catalogTests ||
        current.catalogPanels != next.catalogPanels ||
        current.catalogScope != next.catalogScope ||
        current.qcLogs != next.qcLogs ||
        current.isLoadingCatalog != next.isLoadingCatalog ||
        current.catalogLoadFailure != next.catalogLoadFailure;
  }

  String? _facilityLabel(List<HomeLookupOption> facilityOptions) {
    if (_facilityId == null || _facilityId!.trim().isEmpty) {
      return null;
    }
    for (final HomeLookupOption option in facilityOptions) {
      if (option.id == _facilityId) {
        return option.label;
      }
    }
    return null;
  }

  String? _tenantLabel(List<HomeLookupOption> tenantOptions) {
    if (_tenantId == null || _tenantId!.trim().isEmpty) {
      return null;
    }
    for (final HomeLookupOption option in tenantOptions) {
      if (option.id == _tenantId) {
        return option.label;
      }
    }
    return null;
  }

  List<HomeLookupOption> _facilityOptionsForScope({
    required AsyncValue<Result<HomeDashboardLookups>>? lookupsAsync,
    required bool hasTenant,
  }) {
    if (_showTenantSelector && !hasTenant) {
      return const <HomeLookupOption>[];
    }
    return lookupsAsync?.value?.when(
          success: (HomeDashboardLookups value) =>
              value.facilitiesForTenant(_tenantId),
          failure: (_) => const <HomeLookupOption>[],
        ) ??
        const <HomeLookupOption>[];
  }

  String _scopePromptMessage(
    AppLocalizations l10n, {
    required String? tenantLabel,
  }) {
    final bool hasTenant = _tenantId?.trim().isNotEmpty ?? false;
    final bool hasFacility = _facilityId?.trim().isNotEmpty ?? false;
    if (hasTenant && !hasFacility) {
      return l10n.labConfigurationsSelectFacilityOnlyBody(
        tenantLabel ?? l10n.profileUnknownValue,
      );
    }
    return l10n.labConfigurationsSelectScopeBody;
  }

  Future<void> _openEnableLabTestDialog(
    BuildContext context,
    LabWorkspaceState state,
  ) async {
    final LabWorkspaceController controller = _readLabController(context);
    final LabCatalogScope scope = _catalogScope;
    final AppLocalizations l10n = context.l10n;
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LabEnableFacilityOfferingDialog(
        kind: LabEnableOfferingKind.test,
        scope: scope,
        onSearchCatalog:
            ({
              required LabEnableOfferingKind kind,
              required LabCatalogScope scope,
              String? query,
              int limit = 100,
            }) {
              return controller.searchPlatformLabCatalogForOffering(
                type: LabCatalogItemType.test,
                scope: scope,
                query: query,
                limit: limit,
              );
            },
        onEnable: (String id, Map<String, Object?> payload) =>
            controller.updateLabTest(id, payload, scope: scope),
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (saved == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.labSavedMessage)));
      await _reloadCatalogIfReady();
    }
  }

  Future<void> _openEnableLabPanelDialog(
    BuildContext context,
    LabWorkspaceState state,
  ) async {
    final LabWorkspaceController controller = _readLabController(context);
    final LabCatalogScope scope = _catalogScope;
    final AppLocalizations l10n = context.l10n;
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LabEnableFacilityOfferingDialog(
        kind: LabEnableOfferingKind.panel,
        scope: scope,
        onSearchCatalog:
            ({
              required LabEnableOfferingKind kind,
              required LabCatalogScope scope,
              String? query,
              int limit = 100,
            }) {
              return controller.searchPlatformLabCatalogForOffering(
                type: LabCatalogItemType.panel,
                scope: scope,
                query: query,
                limit: limit,
              );
            },
        onEnable: (String id, Map<String, Object?> payload) =>
            controller.updateLabPanel(id, payload, scope: scope),
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (saved == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.labSavedMessage)));
      await _reloadCatalogIfReady();
    }
  }

  List<LabCatalogItem> _filteredItems(LabWorkspaceState state) {
    final String? category = _filterValue.option(_categoryFilterKey);
    final String? resultKind = _filterValue.option(_resultKindFilterKey);
    return _catalogItems(state)
        .where((LabCatalogItem item) {
          if (category != null && item.category != category) {
            return false;
          }
          if (_catalogType == LabCatalogItemType.test &&
              resultKind != null &&
              item.resultKind != resultKind) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<AppSearchBarFilterChoice> _filterChoices(Iterable<String?> values) {
    return _uniqueNonEmpty(values)
        .map(
          (String value) =>
              AppSearchBarFilterChoice(value: value, label: value),
        )
        .toList(growable: false);
  }

  List<AppListTableColumn<LabCatalogItem>> _defaultColumns(
    BuildContext context,
    LabWorkspaceState state,
    bool showingTests,
  ) {
    final AppLocalizations l10n = context.l10n;
    return <AppListTableColumn<LabCatalogItem>>[
      AppListTableColumn<LabCatalogItem>(
        id: 'name',
        label: showingTests ? l10n.labTestNameLabel : l10n.labPanelNameLabel,
        sortComparator: (LabCatalogItem left, LabCatalogItem right) =>
            appListTableCompareText(left.name, right.name),
        cellBuilder: (_, LabCatalogItem item) =>
            _catalogItemNameCell(item.name ?? item.displayTitle),
      ),
      AppListTableColumn<LabCatalogItem>(
        id: 'code',
        label: showingTests ? l10n.labTestCodeLabel : l10n.labPanelCodeLabel,
        sortComparator: (LabCatalogItem left, LabCatalogItem right) =>
            appListTableCompareText(left.code, right.code),
        cellBuilder: (_, LabCatalogItem item) =>
            Text(item.code ?? l10n.profileUnknownValue),
      ),
      AppListTableColumn<LabCatalogItem>(
        id: 'category',
        label: l10n.labCategoryLabel,
        sortComparator: (LabCatalogItem left, LabCatalogItem right) =>
            appListTableCompareText(left.category, right.category),
        cellBuilder: (_, LabCatalogItem item) =>
            Text(item.category ?? l10n.profileUnknownValue),
      ),
      AppListTableColumn<LabCatalogItem>(
        id: 'price',
        label: l10n.clinicalRequestUnitPriceLabel,
        sortComparator: (LabCatalogItem left, LabCatalogItem right) =>
            (left.unitPrice ?? 0).compareTo(right.unitPrice ?? 0),
        cellBuilder: (BuildContext context, LabCatalogItem item) =>
            Text(_formatCatalogUnitPrice(context, item, l10n)),
      ),
      _actionsColumn(context, state, showingTests),
    ];
  }

  List<AppListTableColumn<LabCatalogItem>> _additionalColumns(
    BuildContext context,
    bool showingTests,
  ) {
    final AppLocalizations l10n = context.l10n;
    return <AppListTableColumn<LabCatalogItem>>[
      if (showingTests)
        AppListTableColumn<LabCatalogItem>(
          id: 'specimen',
          label: l10n.labSpecimenTypeLabel,
          sortComparator: (LabCatalogItem left, LabCatalogItem right) =>
              appListTableCompareText(left.specimenType, right.specimenType),
          cellBuilder: (_, LabCatalogItem item) =>
              Text(item.specimenType ?? l10n.profileUnknownValue),
        ),
      if (showingTests)
        AppListTableColumn<LabCatalogItem>(
          id: 'kind',
          label: l10n.labResultKindLabel,
          sortComparator: (LabCatalogItem left, LabCatalogItem right) =>
              appListTableCompareText(left.resultKind, right.resultKind),
          cellBuilder: (_, LabCatalogItem item) =>
              Text(_resultKindLabel(l10n, item.resultKind)),
        ),
      AppListTableColumn<LabCatalogItem>(
        id: showingTests ? 'range' : 'tests_count',
        label: showingTests
            ? l10n.labUnitRangeCountColumnLabel
            : l10n.labTestsColumnLabel,
        cellBuilder: (_, LabCatalogItem item) => Text(
          showingTests
              ? _unitRangeSummary(context, item)
              : l10n.clinicalLabOrderItemCount(item.testCount),
        ),
      ),
      if (!showingTests)
        AppListTableColumn<LabCatalogItem>(
          id: 'description',
          label: l10n.labPanelDescriptionLabel,
          cellBuilder: (_, LabCatalogItem item) => Text(
            item.description ?? l10n.profileUnknownValue,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
  }

  AppListTableColumn<LabCatalogItem> _actionsColumn(
    BuildContext context,
    LabWorkspaceState state,
    bool showingTests,
  ) {
    final AppLocalizations l10n = context.l10n;
    return AppListTableColumn<LabCatalogItem>(
      id: 'actions',
      label: l10n.labActionColumnLabel,
      alwaysVisible: true,
      cellBuilder: (BuildContext context, LabCatalogItem item) {
        return Wrap(
          spacing: Theme.of(context).spacing.xs,
          runSpacing: Theme.of(context).spacing.xs,
          children: <Widget>[
            AppButton(
              iconOnly: true,
              leadingIcon: Icons.edit_outlined,
              label: showingTests
                  ? l10n.labConfigureTestAction
                  : l10n.labUpdatePanelAction,
              semanticLabel: showingTests
                  ? l10n.labConfigureTestAction
                  : l10n.labUpdatePanelAction,
              tooltip: showingTests
                  ? l10n.labConfigureTestAction
                  : l10n.labUpdatePanelAction,
              onPressed: () => showingTests
                  ? _openLabTestConfigurationDialog(context, state, item)
                  : _openLabPanelDialog(context, state, item),
            ),
            AppButton(
              iconOnly: true,
              leadingIcon: Icons.delete_outline,
              label: showingTests
                  ? l10n.labDeleteTestAction
                  : l10n.labDeletePanelAction,
              semanticLabel: showingTests
                  ? l10n.labDeleteTestAction
                  : l10n.labDeletePanelAction,
              tooltip: showingTests
                  ? l10n.labDeleteTestAction
                  : l10n.labDeletePanelAction,
              onPressed: () => showingTests
                  ? _openDeleteLabTestDialog(context, item)
                  : _openDeleteLabPanelDialog(context, item),
            ),
          ],
        );
      },
    );
  }
}

class _LabConfigurationTypeSelector extends StatelessWidget {
  const _LabConfigurationTypeSelector({
    required this.value,
    required this.onChanged,
  });

  final LabCatalogItemType value;
  final ValueChanged<LabCatalogItemType> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return RadioGroup<LabCatalogItemType>(
      groupValue: value,
      onChanged: (LabCatalogItemType? next) {
        if (next != null) {
          onChanged(next);
        }
      },
      child: Row(
        children: <Widget>[
          Expanded(
            child: _LabConfigurationTypeOption(
              value: LabCatalogItemType.test,
              groupValue: value,
              label: l10n.labTestsTabLabel,
              icon: Icons.science_outlined,
              colorScheme: colorScheme,
              theme: theme,
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: _LabConfigurationTypeOption(
              value: LabCatalogItemType.panel,
              groupValue: value,
              label: l10n.labPanelsTabLabel,
              icon: Icons.dashboard_customize_outlined,
              colorScheme: colorScheme,
              theme: theme,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabConfigurationTypeOption extends StatelessWidget {
  const _LabConfigurationTypeOption({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.icon,
    required this.colorScheme,
    required this.theme,
    required this.onChanged,
  });

  final LabCatalogItemType value;
  final LabCatalogItemType groupValue;
  final String label;
  final IconData icon;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final ValueChanged<LabCatalogItemType> onChanged;

  bool get _selected => groupValue == value;

  @override
  Widget build(BuildContext context) {
    final Color foreground = _selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: _selected ? null : () => onChanged(value),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Radio<LabCatalogItemType>(
              value: value,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Icon(icon, size: theme.appTokens.listIconSize, color: foreground),
            SizedBox(width: theme.spacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: _selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReverseWorkflowDialog extends ConsumerStatefulWidget {
  const _ReverseWorkflowDialog();

  @override
  ConsumerState<_ReverseWorkflowDialog> createState() =>
      _ReverseWorkflowDialogState();
}

class _ReverseWorkflowDialogState
    extends ConsumerState<_ReverseWorkflowDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _reasonController;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.labReverseDialogTitle),
      icon: const Icon(Icons.undo_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            AppTextField(
              controller: _reasonController,
              labelText: l10n.labReverseReasonLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.labReverseWorkflowAction,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .reverseSelected(<String, Object?>{
          'reason': _reasonController.text.trim(),
        });
    if (failure == null) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class _QcDialog extends ConsumerStatefulWidget {
  const _QcDialog({required this.state});

  final LabWorkspaceState state;

  @override
  ConsumerState<_QcDialog> createState() => _QcDialogState();
}

class _QcDialogState extends ConsumerState<_QcDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _statusController;
  late final TextEditingController _loggedAtController;
  late final TextEditingController _notesController;
  List<LabCatalogItem> _offeredTests = <LabCatalogItem>[];
  String? _labTestId;
  AppFailure? _failure;
  bool _isSaving = false;
  bool _isLoadingTests = true;

  @override
  void initState() {
    super.initState();
    _statusController = TextEditingController();
    _loggedAtController = TextEditingController(
      text: DateTime.now().toIso8601String(),
    );
    _notesController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_loadOfferedTests());
    });
  }

  Future<void> _loadOfferedTests() async {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    final LabCatalogScope scope =
        widget.state.catalogScope ??
        LabCatalogScope(
          tenantId: policy.tenantId,
          facilityId: policy.facilityId,
        );
    final Result<List<LabCatalogItem>> result = await ref
        .read(labRepositoryProvider)
        .listFacilityLabTests(
          tenantId: scope.tenantId,
          facilityId: scope.facilityId,
          offeredOnly: true,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingTests = false;
      _offeredTests = result.when(
        success: (List<LabCatalogItem> value) => value,
        failure: (_) => widget.state.catalogTests
            .where((LabCatalogItem item) => item.isOfferedAtFacility)
            .toList(growable: false),
      );
      _labTestId = _offeredTests.isEmpty ? null : _offeredTests.first.apiId;
    });
  }

  @override
  void dispose() {
    _statusController.dispose();
    _loggedAtController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.labRecordQcDialogTitle),
      icon: const Icon(Icons.fact_check_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            AppSelectField<String>.searchable(
              value: _labTestId,
              labelText: l10n.labQcTestFieldLabel,
              enabled: !_isSaving && !_isLoadingTests,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              options: <AppSelectOption<String>>[
                for (final LabCatalogItem item in _offeredTests)
                  AppSelectOption<String>(
                    value: item.apiId,
                    label: item.displayTitle,
                    leadingIcon: const Icon(Icons.science_outlined),
                    searchText: item.searchText,
                  ),
              ],
              onChanged: (String? value) => setState(() => _labTestId = value),
            ),
            AppTextField(
              controller: _statusController,
              labelText: l10n.labQcStatusFieldLabel,
              enabled: !_isSaving,
            ),
            AppTextField(
              controller: _loggedAtController,
              labelText: l10n.labLoggedAtLabel,
              hintText: l10n.labDateTimeHint,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _notesController,
              labelText: l10n.labQcNotesLabel,
              enabled: !_isSaving,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.labRecordQcAction,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String? labTestId = _labTestId;
    if (labTestId == null ||
        DateTime.tryParse(_loggedAtController.text.trim()) == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .createQcLog(<String, Object?>{
          'lab_test_id': labTestId,
          'status': _statusController.text.trim(),
          'logged_at': _loggedAtController.text.trim(),
          'notes': _notesController.text.trim(),
        });
    if (failure == null) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

Future<void> _openLabConfigurationsDialog(
  BuildContext context,
  LabWorkspaceState state,
) async {
  await showAppDialog<void>(
    context: context,
    builder: (_) => _LabConfigurationsDialog(state: state),
  );
}

Future<void> _openCreateLabOrderDialog(
  BuildContext context,
  LabWorkspaceState state,
) async {
  final LabOrderContextInput? orderContext =
      await showAppDialog<LabOrderContextInput>(
        context: context,
        barrierDismissible: false,
        builder: (_) => LabOrderContextDialog(worklist: state.worklist.items),
      );
  if (orderContext == null || !context.mounted) {
    return;
  }

  await _openLabOrderActionDialog(context, state, orderContext: orderContext);
}

Future<void> _openAdditionalLabOrderDialog(
  BuildContext context,
  LabWorkspaceState state,
  LabOrderSummary order,
) async {
  final String? patientId = order.patientId?.trim();
  if (patientId == null || patientId.isEmpty) {
    return;
  }

  await _openLabOrderActionDialog(
    context,
    state,
    orderContext: LabOrderContextInput(
      patientId: patientId,
      patientName: order.patientDisplayName,
      encounterId: order.encounterId,
    ),
  );
}

Future<void> _openLabOrderActionDialog(
  BuildContext context,
  LabWorkspaceState state, {
  required LabOrderContextInput orderContext,
}) async {
  ClinicalActionLabOrderRecord? existingOrder;
  final String? existingOrderId = orderContext.normalizedExistingOrderId;
  if (existingOrderId != null) {
    existingOrder = await _loadExistingLabOrderRecord(
      context,
      state,
      existingOrderId,
    );
    if (existingOrder == null || !context.mounted) {
      return;
    }
  }

  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalLabOrderActionDialog(
        referenceData: _clinicalReferenceData(state),
        existingOrder: existingOrder,
        patientContext: ClinicalRequestPatientContext(
          patientName: orderContext.patientName,
          patientId: orderContext.patientId,
          encounterId: orderContext.encounterId,
        ),
        onSearchLabTests:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'ALL',
            }) {
              return ProviderScope.containerOf(context)
                  .read(clinicalRepositoryProvider)
                  .searchClinicalCatalog(
                    termType: termType,
                    query: query,
                    limit: limit ?? 80,
                    source: source,
                    offeredOnly: true,
                    facilityId: state.catalogScope?.facilityId,
                  );
            },
        onRequest:
            ({
              required List<String> labTestIds,
              required List<String> labPanelIds,
              ClinicalRequestBillingSubmit? billing,
            }) {
              return _readLabController(context).createOrder(
                orderContext.toPayload(
                  labTestIds: labTestIds,
                  labPanelIds: labPanelIds,
                  billing: billing,
                ),
              );
            },
        onUpdate:
            ({
              required String labOrderId,
              required List<String> labTestIds,
              required List<String> labPanelIds,
              ClinicalRequestBillingSubmit? billing,
            }) {
              return _readLabController(context).updateOrder(
                labOrderId,
                orderContext.toPayload(
                  labTestIds: labTestIds,
                  labPanelIds: labPanelIds,
                  billing: billing,
                ),
              );
            },
      ),
    ),
  );
}

Future<void> _openLabTestConfigurationDialog(
  BuildContext context,
  LabWorkspaceState state,
  LabCatalogItem item,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LabCatalogTestDialog(
        catalogTests: state.catalogTests,
        item: item,
        onUpdate: (String id, Map<String, Object?> payload) =>
            _readLabController(context).updateLabTest(id, payload),
      ),
    ),
  );
}

Future<void> _openLabPanelDialog(
  BuildContext context,
  LabWorkspaceState state,
  LabCatalogItem item,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LabCatalogPanelDialog(
        catalogTests: state.catalogTests,
        catalogPanels: state.catalogPanels,
        item: item,
        onUpdate: (String id, Map<String, Object?> payload) =>
            _readLabController(context).updateLabPanel(id, payload),
      ),
    ),
  );
}

Future<void> _openEditLabOrderDialog(
  BuildContext context,
  LabWorkspaceState state,
  LabOrderWorkflow workflow,
) async {
  final LabOrderSummary order = workflow.order;
  final LabOrderContextInput? orderContext =
      await showAppDialog<LabOrderContextInput>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            LabOrderContextDialog(worklist: state.worklist.items, order: order),
      );
  if (orderContext == null || !context.mounted) {
    return;
  }

  await _openLabOrderActionDialog(context, state, orderContext: orderContext);
}

Future<ClinicalActionLabOrderRecord?> _loadExistingLabOrderRecord(
  BuildContext context,
  LabWorkspaceState fallbackState,
  String orderId,
) async {
  final AppFailure? failure = await _readLabController(
    context,
  ).selectOrderById(orderId);
  if (!context.mounted) {
    return null;
  }
  _showFailureIfNeeded(context, failure);
  if (failure != null) {
    return null;
  }

  final LabOrderWorkflow? workflow = _readLabStateFromContext(
    context,
  )?.selectedWorkflow;
  if (workflow != null && _isSameLabOrder(workflow.order, orderId)) {
    return _clinicalLabOrderRecord(workflow.order);
  }

  final LabOrderSummary? fallbackOrder = _findLabOrderById(
    fallbackState.worklist.items,
    orderId,
  );
  return fallbackOrder == null ? null : _clinicalLabOrderRecord(fallbackOrder);
}

LabOrderSummary? _findLabOrderById(
  Iterable<LabOrderSummary> orders,
  String orderId,
) {
  for (final LabOrderSummary order in orders) {
    if (_isSameLabOrder(order, orderId)) {
      return order;
    }
  }
  return null;
}

bool _isSameLabOrder(LabOrderSummary order, String orderId) {
  final String normalized = orderId.trim().toLowerCase();
  return normalized.isNotEmpty &&
      (<String?>[order.apiId, order.id, order.displayId]
          .whereType<String>()
          .map((String value) => value.trim().toLowerCase())
          .contains(normalized));
}

LabWorkspaceState? _readLabStateFromContext(BuildContext context) {
  return ProviderScope.containerOf(context)
      .read(labWorkspaceControllerProvider)
      .asData
      ?.value
      .when(success: (LabWorkspaceState state) => state, failure: (_) => null);
}

Future<void> _openDeleteLabOrderDialog(
  BuildContext context,
  LabOrderWorkflow workflow,
) async {
  final bool? deleted = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => LabDeleteReasonDialog(
      title: context.l10n.labDeleteOrderDialogTitle,
      body: context.l10n.labDeleteOrderDialogBody(
        workflow.order.displayId ?? workflow.order.apiId,
      ),
      submitLabel: context.l10n.labDeleteOrderAction,
      onDelete: (String reason) =>
          _readLabController(context).deleteOrder(workflow.order.apiId, reason),
    ),
  );
  if (deleted == true && context.mounted) {
    unawaited(Navigator.of(context).maybePop());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.labDeletedMessage)));
  }
}

Future<void> _openDeleteLabTestDialog(
  BuildContext context,
  LabCatalogItem item,
) async {
  final bool? deleted = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => LabDeleteReasonDialog(
      title: context.l10n.labDeleteTestDialogTitle,
      body: context.l10n.labDeleteTestDialogBody(item.displayTitle),
      submitLabel: context.l10n.labDeleteTestAction,
      onDelete: (String reason) =>
          _readLabController(context).deleteLabTest(item.apiId, reason),
    ),
  );
  if (deleted == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.labDeletedMessage)));
  }
}

Future<void> _openDeleteLabPanelDialog(
  BuildContext context,
  LabCatalogItem item,
) async {
  final bool? deleted = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => LabDeleteReasonDialog(
      title: context.l10n.labDeletePanelDialogTitle,
      body: context.l10n.labDeletePanelDialogBody(item.displayTitle),
      submitLabel: context.l10n.labDeletePanelAction,
      onDelete: (String reason) =>
          _readLabController(context).deleteLabPanel(item.apiId, reason),
    ),
  );
  if (deleted == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.labDeletedMessage)));
  }
}

Future<void> _openQcDialog(
  BuildContext context,
  LabWorkspaceState state,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QcDialog(state: state),
    ),
  );
}

Future<void> _showActionResult(
  BuildContext context,
  Future<bool?> result,
) async {
  final bool? saved = await result;
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.labSavedMessage)));
  }
}

LabWorkspaceController _readLabController(BuildContext context) {
  return ProviderScope.containerOf(
    context,
  ).read(labWorkspaceControllerProvider.notifier);
}

ClinicalActionReferenceData _clinicalReferenceData(LabWorkspaceState state) {
  return ClinicalActionReferenceData(
    labTests: state.catalogTests
        .where((LabCatalogItem item) => item.isOfferedAtFacility)
        .map(_clinicalCatalogOptionFromLabItem)
        .toList(growable: false),
    labPanels: state.catalogPanels
        .where((LabCatalogItem item) => item.isOfferedAtFacility)
        .map(_clinicalCatalogOptionFromLabItem)
        .toList(growable: false),
  );
}

ClinicalActionCatalogOption _clinicalCatalogOptionFromLabItem(
  LabCatalogItem item,
) {
  return ClinicalActionCatalogOption(
    id: item.id,
    publicId: item.apiId,
    name: item.name,
    code: item.code,
    category: item.category,
    secondaryText: item.specimenType ?? item.description,
    unitPrice: item.unitPrice,
    currency: item.currency,
    childIds: item.panelItems
        .map((LabPanelItem panelItem) => panelItem.labTestId)
        .whereType<String>()
        .toList(growable: false),
    childCodes: item.panelItems
        .map((LabPanelItem panelItem) => panelItem.testCode)
        .whereType<String>()
        .toList(growable: false),
  );
}

ClinicalActionLabOrderRecord _clinicalLabOrderRecord(LabOrderSummary order) {
  return ClinicalActionLabOrderRecord(
    id: order.apiId,
    labOrderItems: order.items
        .map(
          (LabOrderItem item) => ClinicalActionLabOrderItem(
            id: item.apiId,
            status: item.status,
            resultStatus: item.resultStatus,
            labTestId: item.labTestId,
            testDisplayName: item.testDisplayName,
            testCode: item.testCode,
            category: item.category,
            specimenType: item.specimenType,
            unit: item.unit,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
          ),
        )
        .toList(growable: false),
  );
}

List<Widget> _dialogActions(
  BuildContext context, {
  required String submitLabel,
  required bool isSaving,
  required VoidCallback onSubmit,
}) {
  final AppLocalizations l10n = context.l10n;
  return <Widget>[
    AppButton.tertiary(
      label: l10n.commonCancelActionLabel,
      enabled: !isSaving,
      onPressed: () => Navigator.of(context).pop(false),
    ),
    AppButton.primary(
      label: submitLabel,
      isLoading: isSaving,
      onPressed: onSubmit,
    ),
  ];
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  showAppFailureSnackBar(context, failure);
}

String _formatCatalogUnitPrice(
  BuildContext context,
  LabCatalogItem item,
  AppLocalizations l10n,
) {
  final num? price = item.unitPrice;
  if (price == null) {
    return l10n.clinicalRequestPriceNotSetLabel;
  }
  return AppFormatters.currency(
    price.toDouble(),
    Localizations.localeOf(context),
    currencyCode: item.currency ?? appDefaultCurrencyCode,
  );
}

Widget _catalogItemNameCell(String label, {double maxWidth = 280}) {
  return ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Tooltip(
      message: label,
      child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
    ),
  );
}

String _joinNonEmpty(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' • ');
}

List<String> _uniqueNonEmpty(Iterable<String?> values) {
  final Set<String> seen = <String>{};
  final List<String> result = <String>[];
  for (final String? value in values) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      continue;
    }
    final String key = trimmed.toLowerCase();
    if (seen.add(key)) {
      result.add(trimmed);
    }
  }
  result.sort(
    (String left, String right) =>
        left.toLowerCase().compareTo(right.toLowerCase()),
  );
  return result;
}

String _resultKindLabel(AppLocalizations l10n, String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'NUMERIC' => l10n.labResultKindNumeric,
    'QUALITATIVE' => l10n.labResultKindQualitative,
    'TEXT' => l10n.labResultKindText,
    _ => value?.trim().isNotEmpty == true ? value! : '—',
  };
}

String _unitRangeSummary(BuildContext context, LabCatalogItem item) {
  final int rangeCount = item.referenceRangeCount > 0
      ? item.referenceRangeCount
      : item.referenceRanges.length;
  final String summary = _joinNonEmpty(<String?>[
    item.unit,
    if (rangeCount > 0)
      context.l10n.labReferenceRangeCount(rangeCount)
    else
      item.referenceRange,
  ]);
  return summary.isEmpty ? context.l10n.profileUnknownValue : summary;
}

List<AppSelectOption<LabQueueScope>> _scopeOptions(AppLocalizations l10n) {
  return <AppSelectOption<LabQueueScope>>[
    AppSelectOption<LabQueueScope>(
      value: LabQueueScope.all,
      label: l10n.labScopeAll,
    ),
    AppSelectOption<LabQueueScope>(
      value: LabQueueScope.collection,
      label: l10n.labScopeCollection,
    ),
    AppSelectOption<LabQueueScope>(
      value: LabQueueScope.processing,
      label: l10n.labScopeProcessing,
    ),
    AppSelectOption<LabQueueScope>(
      value: LabQueueScope.results,
      label: l10n.labScopeResults,
    ),
    AppSelectOption<LabQueueScope>(
      value: LabQueueScope.critical,
      label: l10n.labScopeCritical,
    ),
    AppSelectOption<LabQueueScope>(
      value: LabQueueScope.completed,
      label: l10n.labScopeCompleted,
    ),
    AppSelectOption<LabQueueScope>(
      value: LabQueueScope.cancelled,
      label: l10n.labScopeCancelled,
    ),
  ];
}

const String _labScopeFilterKey = 'scope';

AppSearchBarFilterValue _labFilterValue(LabWorkbenchQuery query) {
  if (query.scope == LabQueueScope.all) {
    return AppSearchBarFilterValue.empty;
  }
  return AppSearchBarFilterValue(
    options: <String, String>{_labScopeFilterKey: query.scope.name},
  );
}

LabQueueScope _labScopeFromFilter(String? value) {
  for (final LabQueueScope scope in LabQueueScope.values) {
    if (scope.name == value) {
      return scope;
    }
  }
  return LabQueueScope.all;
}

List<AppSearchBarFilterChoice> _labScopeFilterChoices(AppLocalizations l10n) {
  return <AppSearchBarFilterChoice>[
    for (final AppSelectOption<LabQueueScope> option in _scopeOptions(l10n))
      if (option.value != LabQueueScope.all)
        AppSearchBarFilterChoice(
          value: option.value.name,
          label: option.label,
          icon: _labScopeIcon(option.value),
        ),
  ];
}

IconData _labScopeIcon(LabQueueScope scope) {
  return switch (scope) {
    LabQueueScope.all => Icons.assignment_outlined,
    LabQueueScope.collection => Icons.pending_actions_outlined,
    LabQueueScope.processing => Icons.sync_outlined,
    LabQueueScope.results => Icons.pending_actions_outlined,
    LabQueueScope.critical => Icons.priority_high_outlined,
    LabQueueScope.completed => Icons.verified_outlined,
    LabQueueScope.cancelled => Icons.block_outlined,
  };
}

String _pageLabel(BuildContext context, AppPage<LabOrderSummary> page) {
  final int total = page.totalItemCount ?? page.items.length;
  return context.l10n.labPageLabel(
    page.firstItemNumber,
    page.lastItemNumber,
    total,
  );
}

AppWorkspaceStatus _orderStatus(BuildContext context, String? value) {
  return labStatusBadge(context, value);
}

AppWorkspaceStatus _entryStatus(BuildContext context, LabOrderSummary order) {
  final AppLocalizations l10n = context.l10n;
  final int activeItems = _activeResultItemCount(order);
  final int enteredItems = _enteredResultItemCount(order);

  if ((order.status ?? '').toUpperCase() == 'CANCELLED') {
    return AppWorkspaceStatus(
      label: l10n.labStatusCancelled,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.block_outlined,
    );
  }
  if (order.hasRejectedItem) {
    return AppWorkspaceStatus(
      label: l10n.labStatusRejected,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.block_outlined,
    );
  }
  if (activeItems > 0 && order.completedItemCount >= activeItems) {
    return AppWorkspaceStatus(
      label: l10n.labStatusVerified,
      tone: AppWorkspaceStatusTone.success,
      icon: Icons.verified_outlined,
    );
  }
  if (activeItems > 0 && enteredItems >= activeItems) {
    return AppWorkspaceStatus(
      label: l10n.labStatusFilled,
      tone: AppWorkspaceStatusTone.info,
      icon: Icons.fact_check_outlined,
    );
  }
  if (enteredItems > 0 || order.inProcessItemCount > 0) {
    return AppWorkspaceStatus(
      label: l10n.labStatusPartiallyEntered,
      tone: AppWorkspaceStatusTone.warning,
      icon: Icons.pending_actions_outlined,
    );
  }
  return AppWorkspaceStatus(
    label: l10n.labStatusOrdered,
    icon: Icons.assignment_outlined,
  );
}

AppWorkspaceStatus _resultStatus(BuildContext context, LabOrderSummary order) {
  final AppLocalizations l10n = context.l10n;
  final int activeItems = _activeResultItemCount(order);
  final int enteredItems = _enteredResultItemCount(order);

  if (order.hasCriticalResult) {
    return AppWorkspaceStatus(
      label: l10n.labStatusCritical,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.priority_high_outlined,
    );
  }
  if ((order.status ?? '').toUpperCase() == 'CANCELLED' ||
      order.hasRejectedItem) {
    return AppWorkspaceStatus(
      label: order.hasRejectedItem
          ? l10n.labStatusRejected
          : l10n.labStatusCancelled,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.block_outlined,
    );
  }
  if (activeItems > 0 && order.completedItemCount >= activeItems) {
    return AppWorkspaceStatus(
      label: l10n.labStatusCompleted,
      tone: AppWorkspaceStatusTone.success,
      icon: Icons.verified_outlined,
    );
  }
  if (activeItems > 0 && enteredItems >= activeItems) {
    return AppWorkspaceStatus(
      label: l10n.labStatusFilled,
      tone: AppWorkspaceStatusTone.info,
      icon: Icons.fact_check_outlined,
    );
  }
  if (enteredItems > 0 || order.inProcessItemCount > 0) {
    return AppWorkspaceStatus(
      label: l10n.labStatusPartiallyFilled,
      tone: AppWorkspaceStatusTone.warning,
      icon: Icons.pending_actions_outlined,
    );
  }
  return AppWorkspaceStatus(
    label: l10n.labStatusOrdered,
    icon: Icons.radio_button_unchecked,
  );
}

int _activeResultItemCount(LabOrderSummary order) {
  final int active = order.itemCount - order.rejectedItemCount;
  return active < 0 ? 0 : active;
}

int _enteredResultItemCount(LabOrderSummary order) {
  final int enteredFromItems = order.items
      .where((LabOrderItem item) => !item.isRejected && item.hasResult)
      .length;
  final int statusCount = order.completedItemCount + order.inProcessItemCount;
  return enteredFromItems > statusCount ? enteredFromItems : statusCount;
}

int _completedResultItemCount(LabOrderSummary order) {
  return order.completedItemCount;
}

String _labBillingGateLabel(BuildContext context, LabOrderSummary order) {
  final AppLocalizations l10n = context.l10n;
  if (!order.hasBillingGate) {
    return l10n.clinicalRequestPaymentNotBilledLabel;
  }
  return clinicalRequestPaymentStatusDisplayLabel(
    l10n,
    order.effectivePaymentStatus,
  );
}

String _nextActionLabel(BuildContext context, LabOrderSummary order) {
  final AppLocalizations l10n = context.l10n;
  if ((order.status ?? '').toUpperCase() == 'CANCELLED') {
    return l10n.labNextActionCancelled;
  }
  if (order.hasCriticalResult) {
    return l10n.labNextActionReviewCritical;
  }
  final String status = (order.status ?? '').toUpperCase();
  if (order.verifiableItemCount > 0) {
    return l10n.labNextActionVerify;
  }
  return switch (status) {
    'ORDERED' || 'COLLECTED' => l10n.labNextActionEnterResult,
    'IN_PROCESS' => l10n.labNextActionVerify,
    'COMPLETED' => l10n.labNextActionCompleted,
    _ => l10n.labNextActionWatch,
  };
}
