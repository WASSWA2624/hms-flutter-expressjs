import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/presentation/controllers/lab_workspace_controller.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_result_entry_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
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
              onPressed: () =>
                  _openLabConfigurationsDialog(context, state, policy.tenantId),
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
          ? l10n.labPatientsWorklistDescription
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
            columns: <AppListTableColumn<LabOrderSummary>>[
              if (state.query.view == LabWorkbenchView.orders)
                _orderWorklistColumn(context, state.query.view)
              else
                _patientWorklistColumn(context),
              if (state.query.view == LabWorkbenchView.orders)
                _patientWorklistColumn(context)
              else
                _orderWorklistColumn(context, state.query.view),
              AppListTableColumn<LabOrderSummary>(
                id: 'entry_status',
                label: l10n.labEntryStatusColumnLabel,
                sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
                    appListTableCompareNumber(
                      _enteredResultItemCount(left),
                      _enteredResultItemCount(right),
                    ),
                cellBuilder: (BuildContext context, LabOrderSummary item) {
                  return AppWorkspaceStatusBadge(
                    status: _entryStatus(context, item),
                  );
                },
              ),
              AppListTableColumn<LabOrderSummary>(
                id: 'result_status',
                label: l10n.labResultStatusLabel,
                sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
                    appListTableCompareNumber(
                      _completedResultItemCount(left),
                      _completedResultItemCount(right),
                    ),
                cellBuilder: (BuildContext context, LabOrderSummary item) {
                  return AppWorkspaceStatusBadge(
                    status: _resultStatus(context, item),
                  );
                },
              ),
            ],
            columnChoices: <AppListTableColumn<LabOrderSummary>>[
              AppListTableColumn<LabOrderSummary>(
                id: 'tests',
                label: l10n.labTestsColumnLabel,
                sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
                    appListTableCompareText(left.testsLabel, right.testsLabel),
                cellBuilder: (BuildContext context, LabOrderSummary item) {
                  return Text(item.testsLabel ?? l10n.profileUnknownValue);
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
                  return Text(_nextActionLabel(context, item));
                },
              ),
            ],
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

AppListTableColumn<LabOrderSummary> _patientWorklistColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<LabOrderSummary>(
    id: 'patient',
    label: l10n.labPatientColumnLabel,
    sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
        appListTableCompareText(_patientSortKey(left), _patientSortKey(right)),
    cellBuilder: (_, LabOrderSummary item) {
      return _LabOrderIdentity(order: item);
    },
  );
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
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    if (order.isPatientGroup) {
      final int activeOrders = order.activeOrderCount > 0
          ? order.activeOrderCount
          : order.orderCount;
      final List<String> ids = order.orderDisplayIds.isNotEmpty
          ? order.orderDisplayIds
          : order.orderIds;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.labActiveOrderCount(activeOrders),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (ids.isNotEmpty)
            Text(
              ids.take(3).join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      );
    }

    return AppCopyableIdentifier(
      value: order.apiId,
      tooltip: l10n.copyIdentifierAction,
      copiedMessage: l10n.identifierCopiedMessage,
      textStyle: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LabOrderIdentity extends StatelessWidget {
  const _LabOrderIdentity({required this.order});

  final LabOrderSummary order;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? subtitle = order.isPatientGroup
        ? _joinNonEmpty(<String?>[
            order.patientId,
            order.encounterId,
            context.l10n.labActiveOrderCount(
              order.activeOrderCount > 0
                  ? order.activeOrderCount
                  : order.orderCount,
            ),
          ])
        : order.displaySubtitle;
    final String detailLine = _joinNonEmpty(<String?>[
      subtitle,
      order.encounterSourceLabel,
      order.encounterLocationLabel,
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          order.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (detailLine.isNotEmpty)
          Text(
            detailLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
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
  const _LabConfigurationsDialog({required this.state, this.tenantId});

  final LabWorkspaceState state;
  final String? tenantId;

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

  @override
  void initState() {
    super.initState();
    _dialogState = widget.state;
    _searchController = TextEditingController();
    _columnVisibilityController =
        AppListTableColumnVisibilityController<LabCatalogItem>();
  }

  @override
  void didUpdateWidget(covariant _LabConfigurationsDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldSyncCatalogState(_dialogState, widget.state)) {
      _dialogState = widget.state;
    }
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
          _LabConfigurationTabs(
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
          AppListTable<LabCatalogItem>(
            items: items,
            maxVisibleItems: _maxVisibleCatalogItems,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
                AppSearchBarAction(
                  icon: showingTests
                      ? Icons.add_circle_outline
                      : Icons.add_box_outlined,
                  label: showingTests
                      ? l10n.labCreateTestAction
                      : l10n.labCreatePanelAction,
                  tooltip: showingTests
                      ? l10n.labCreateTestAction
                      : l10n.labCreatePanelAction,
                  onPressed: () => showingTests
                      ? _openLabTestConfigurationDialog(
                          context,
                          state,
                          null,
                          tenantId: widget.tenantId,
                        )
                      : _openLabPanelDialog(context, state, widget.tenantId),
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
            emptyBuilder: (_) => AppMutedText(l10n.labNoCatalogItemsLabel),
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
                          : _openLabPanelDialog(
                              context,
                              state,
                              widget.tenantId,
                              item,
                            ),
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
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.tertiary(
              label: l10n.labQcLogsAction,
              leadingIcon: Icons.fact_check_outlined,
              onPressed: () => _openQcDialog(context, state),
            ),
          ),
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
        current.qcLogs != next.qcLogs;
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
        cellBuilder: (_, LabCatalogItem item) => Text(
          item.name ?? item.displayTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
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
        id: 'offered',
        label: l10n.labOfferedStatusLabel,
        sortComparator: (LabCatalogItem left, LabCatalogItem right) =>
            appListTableCompareText(
              left.isOfferedAtFacility ? '1' : '0',
              right.isOfferedAtFacility ? '1' : '0',
            ),
        cellBuilder: (_, LabCatalogItem item) => Text(
          item.isOfferedAtFacility
              ? l10n.labOfferedStatusLabel
              : l10n.labNotOfferedStatusLabel,
        ),
      ),
      AppListTableColumn<LabCatalogItem>(
        id: 'price',
        label: l10n.clinicalRequestUnitPriceLabel,
        sortComparator: (LabCatalogItem left, LabCatalogItem right) =>
            (left.unitPrice ?? 0).compareTo(right.unitPrice ?? 0),
        cellBuilder: (_, LabCatalogItem item) => Text(
          item.unitPrice?.toString() ?? l10n.clinicalRequestPriceNotSetLabel,
        ),
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
                  : _openLabPanelDialog(context, state, widget.tenantId, item),
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

class _LabConfigurationTabs extends StatelessWidget {
  const _LabConfigurationTabs({required this.value, required this.onChanged});

  final LabCatalogItemType value;
  final ValueChanged<LabCatalogItemType> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Row(
      children: <Widget>[
        Expanded(
          child: _LabConfigurationTab(
            label: l10n.labTestsTabLabel,
            icon: Icons.science_outlined,
            selected: value == LabCatalogItemType.test,
            onPressed: () => onChanged(LabCatalogItemType.test),
          ),
        ),
        Expanded(
          child: _LabConfigurationTab(
            label: l10n.labPanelsTabLabel,
            icon: Icons.dashboard_customize_outlined,
            selected: value == LabCatalogItemType.panel,
            onPressed: () => onChanged(LabCatalogItemType.panel),
          ),
        ),
      ],
    );
  }
}

class _LabConfigurationTab extends StatelessWidget {
  const _LabConfigurationTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color foreground = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    return Material(
      color: selected ? colorScheme.primaryContainer : colorScheme.surface,
      shape: Border.all(
        color: selected ? colorScheme.primary : colorScheme.outlineVariant,
      ),
      child: InkWell(
        onTap: selected ? null : onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.md,
            vertical: theme.spacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: theme.appTokens.listIconSize, color: foreground),
              SizedBox(width: theme.spacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
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
    final Result<List<LabCatalogItem>> result = await ref
        .read(labRepositoryProvider)
        .listFacilityLabTests(offeredOnly: true, limit: 200);
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
  String? tenantId,
) async {
  await _readLabController(context).loadFacilityCatalogConfig();
  if (!context.mounted) {
    return;
  }
  final LabWorkspaceState currentState =
      ProviderScope.containerOf(context)
          .read(labWorkspaceControllerProvider)
          .value
          ?.when(
            success: (LabWorkspaceState value) => value,
            failure: (_) => state,
          ) ??
      state;
  await showAppDialog<void>(
    context: context,
    builder: (_) => _LabConfigurationsDialog(
      state: currentState,
      tenantId: tenantId,
    ),
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
  LabCatalogItem? item, {
  String? tenantId,
}) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LabCatalogTestDialog(
        catalogTests: state.catalogTests,
        item: item,
        tenantId: tenantId,
        onCreate: (Map<String, Object?> payload) =>
            _readLabController(context).createLabTest(payload),
        onUpdate: (String id, Map<String, Object?> payload) =>
            _readLabController(context).updateLabTest(id, payload),
      ),
    ),
  );
}

Future<void> _openLabPanelDialog(
  BuildContext context,
  LabWorkspaceState state,
  String? tenantId, [
  LabCatalogItem? item,
]) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LabCatalogPanelDialog(
        catalogTests: state.catalogTests,
        catalogPanels: state.catalogPanels,
        item: item,
        tenantId: tenantId,
        onCreate: (Map<String, Object?> payload) =>
            _readLabController(context).createLabPanel(payload),
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
  return const ClinicalActionReferenceData();
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
  if (failure == null) {
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
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
  return _statusBadge(context, value);
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

AppWorkspaceStatus _statusBadge(BuildContext context, String? value) {
  final String status = (value ?? '').toUpperCase();
  return AppWorkspaceStatus(
    label: _statusLabel(context, value),
    tone: switch (status) {
      'COMPLETED' || 'NORMAL' || 'RECEIVED' => AppWorkspaceStatusTone.success,
      'CRITICAL' || 'CANCELLED' || 'REJECTED' => AppWorkspaceStatusTone.error,
      'ABNORMAL' ||
      'ORDERED' ||
      'COLLECTED' ||
      'PENDING' => AppWorkspaceStatusTone.warning,
      'IN_PROCESS' => AppWorkspaceStatusTone.info,
      _ => AppWorkspaceStatusTone.neutral,
    },
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

String _statusLabel(BuildContext context, String? value) {
  final AppLocalizations l10n = context.l10n;
  return switch ((value ?? '').toUpperCase()) {
    'ORDERED' => l10n.labStatusOrdered,
    'COLLECTED' => l10n.labStatusCollected,
    'IN_PROCESS' => l10n.labStatusInProcess,
    'COMPLETED' => l10n.labStatusCompleted,
    'CANCELLED' => l10n.labStatusCancelled,
    'PENDING' => l10n.labStatusPending,
    'NORMAL' => l10n.labStatusNormal,
    'ABNORMAL' => l10n.labStatusAbnormal,
    'CRITICAL' => l10n.labStatusCritical,
    'LOW' => l10n.labStatusLow,
    'HIGH' => l10n.labStatusHigh,
    'VERIFIED' => l10n.labStatusVerified,
    'REJECTED' => l10n.labStatusRejected,
    'RECEIVED' => l10n.labStatusReceived,
    final String status when status.trim().isNotEmpty => _apiLabel(status),
    _ => l10n.profileUnknownValue,
  };
}

String _apiLabel(String value) {
  final String normalized = value.trim().replaceAll('_', ' ').toLowerCase();
  if (normalized.isEmpty) {
    return value;
  }
  return normalized
      .split(RegExp(r'\s+'))
      .map((String word) {
        if (word.isEmpty) {
          return word;
        }
        return '${word.substring(0, 1).toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
}
