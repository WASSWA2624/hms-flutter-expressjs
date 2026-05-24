import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
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
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';

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
      compactSummaryCards: true,
      status: AppWorkspaceStatus(
        label: state.isSaving ? l10n.labSavingStatus : l10n.labLiveStatus,
        tone: state.isSaving
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
      ),
      secondaryActions: <Widget>[
        AppButton.secondary(
          label: state.query.view == LabWorkbenchView.patients
              ? l10n.labOrdersViewAction
              : l10n.labPatientsViewAction,
          leadingIcon: Icons.swap_horiz_outlined,
          onPressed: () => controller.applyView(
            state.query.view == LabWorkbenchView.patients
                ? LabWorkbenchView.orders
                : LabWorkbenchView.patients,
          ),
        ),
        if (canMutate)
          AppButton.secondary(
            label: l10n.labCreateAction,
            leadingIcon: Icons.add_circle_outline,
            enabled: !state.isSaving,
            onPressed: () =>
                _openLabCreateActionDialog(context, state, policy.tenantId),
          ),
        if (canMutate)
          AppButton.secondary(
            label: l10n.labReferenceRangesAction,
            leadingIcon: Icons.tune_outlined,
            onPressed: () => _openTestCatalogDialog(context, state),
          ),
        AppIconButton(
          icon: Icons.refresh,
          semanticLabel: l10n.commonRefreshActionLabel,
          tooltip: l10n.commonRefreshActionLabel,
          isLoading: state.isRefreshing,
          onPressed: () async {
            final AppFailure? failure = await controller.refresh();
            if (context.mounted) {
              _showFailureIfNeeded(context, failure);
            }
          },
        ),
      ],
      summaryCards: <Widget>[
        if (state.summary.totalForView(state.query.view) > 0)
          _summaryCard(
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
          _summaryCard(
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
          _summaryCard(
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
          _summaryCard(
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
          _summaryCard(
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
          _summaryCard(
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
      body: _LabWorklistPanel(
        state: state,
        canMutate: canMutate,
        searchController: _searchController,
        columnVisibilityController: _tableColumnController,
      ),
    );
  }

  Widget _summaryCard(
    BuildContext context, {
    required String label,
    required int value,
    required IconData icon,
    required AppWorkspaceStatusTone tone,
    required VoidCallback onPressed,
  }) {
    return AppWorkspaceSummaryCard(
      label: label,
      value: AppFormatters.compactNumber(
        value,
        Localizations.localeOf(context),
      ),
      icon: icon,
      tone: tone,
      compact: true,
      onPressed: onPressed,
    );
  }
}

class _LabWorklistPanel extends ConsumerWidget {
  const _LabWorklistPanel({
    required this.state,
    required this.canMutate,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final LabWorkspaceState state;
  final bool canMutate;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<LabOrderSummary>
  columnVisibilityController;

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
      child: AppListTable<LabOrderSummary>(
        page: state.worklist,
        isLoading: state.isRefreshing,
        columnVisibilityController: columnVisibilityController,
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        search: AppListTableSearch<LabOrderSummary>(
          controller: searchController,
          semanticLabel: l10n.labSearchLabel,
          hintText: l10n.labSearchHint,
          matcher: (_, _) => true,
          onSubmitted: controller.applySearch,
          onClear: () => controller.applySearch(''),
          showAdvancedFilterButton: true,
          advancedFilterButtonLabel: l10n.labFiltersLabel,
          advancedFilterTitle: l10n.labFiltersLabel,
          advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
          advancedFilterResetLabel: l10n.opdClearFiltersAction,
          advancedFilterCancelLabel: l10n.commonCancelActionLabel,
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
          AppListTableColumn<LabOrderSummary>(
            label: l10n.labPatientColumnLabel,
            sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
                appListTableCompareText(left.displayTitle, right.displayTitle),
            cellBuilder: (_, LabOrderSummary item) {
              return _LabOrderIdentity(order: item);
            },
          ),
          AppListTableColumn<LabOrderSummary>(
            label: state.query.view == LabWorkbenchView.patients
                ? l10n.labOrdersColumnLabel
                : l10n.labOrderColumnLabel,
            sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
                appListTableCompareText(left.apiId, right.apiId),
            cellBuilder: (BuildContext context, LabOrderSummary item) {
              if (item.isPatientGroup) {
                final int activeOrders = item.activeOrderCount > 0
                    ? item.activeOrderCount
                    : item.orderCount;
                return Text(l10n.labActiveOrderCount(activeOrders));
              }
              return AppCopyableIdentifier(
                value: item.displayId,
                tooltip: context.l10n.copyIdentifierAction,
                copiedMessage: context.l10n.identifierCopiedMessage,
              );
            },
          ),
          AppListTableColumn<LabOrderSummary>(
            label: l10n.labTestsColumnLabel,
            sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
                appListTableCompareText(left.testsLabel, right.testsLabel),
            cellBuilder: (BuildContext context, LabOrderSummary item) {
              return Text(item.testsLabel ?? l10n.profileUnknownValue);
            },
          ),
          AppListTableColumn<LabOrderSummary>(
            label: l10n.labEntryStatusColumnLabel,
            sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
                appListTableCompareNumber(
                  left.verifiableItemCount,
                  right.verifiableItemCount,
                ),
            cellBuilder: (BuildContext context, LabOrderSummary item) {
              return AppWorkspaceStatusBadge(
                status: _entryStatus(context, item),
              );
            },
          ),
          AppListTableColumn<LabOrderSummary>(
            label: l10n.labResultColumnLabel,
            sortComparator: (LabOrderSummary left, LabOrderSummary right) =>
                appListTableCompareNumber(
                  left.completedItemCount,
                  right.completedItemCount,
                ),
            cellBuilder: (BuildContext context, LabOrderSummary item) {
              return AppWorkspaceStatusBadge(
                status: _resultStatus(context, item),
              );
            },
          ),
          AppListTableColumn<LabOrderSummary>(
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
          final ThemeData theme = Theme.of(context);
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.sm,
              vertical: theme.spacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _LabOrderIdentity(order: item),
                SizedBox(height: theme.spacing.xs),
                Text(
                  item.testsLabel ?? l10n.profileUnknownValue,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                SizedBox(height: theme.spacing.xs),
                Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  children: <Widget>[
                    AppWorkspaceStatusBadge(
                      status: _orderStatus(context, item.status),
                    ),
                    AppWorkspaceStatusBadge(
                      status: _entryStatus(context, item),
                    ),
                    AppWorkspaceStatusBadge(
                      status: _resultStatus(context, item),
                    ),
                  ],
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  _nextActionLabel(context, item),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          order.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),
        if (subtitle != null && subtitle.isNotEmpty)
          Text(
            subtitle,
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
  final String? selectedOrderId = await _resolveLabOrderSelection(
    context,
    order,
  );
  if (selectedOrderId == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await controller.selectOrderById(selectedOrderId);
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }

  final LabWorkspaceState state = _readLabState(ref) ?? fallbackState;
  if (state.selectedWorkflow == null) {
    return;
  }

  await showAppDialog<void>(
    context: context,
    builder: (_) => LabResultEntryDialog(
      canMutate: canMutate,
      onEditOrder: (BuildContext dialogContext, LabOrderWorkflow workflow) {
        return _openEditLabOrderDialog(dialogContext, state, workflow);
      },
      onDeleteOrder: (BuildContext dialogContext, LabOrderWorkflow workflow) {
        return _openDeleteLabOrderDialog(dialogContext, workflow);
      },
    ),
  );
}

Future<String?> _resolveLabOrderSelection(
  BuildContext context,
  LabOrderSummary order,
) async {
  if (!order.isPatientGroup || order.orderIds.length <= 1) {
    return order.apiId;
  }

  return showAppDialog<String>(
    context: context,
    builder: (_) => _LabOrderSelectorDialog(order: order),
  );
}

class _LabOrderSelectorDialog extends StatelessWidget {
  const _LabOrderSelectorDialog({required this.order});

  final LabOrderSummary order;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.labSelectOrderDialogTitle),
      icon: const Icon(Icons.assignment_outlined),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.labSelectOrderDialogBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          for (var index = 0; index < order.orderIds.length; index += 1)
            _CompactRecordRow(
              title: index < order.orderDisplayIds.length
                  ? order.orderDisplayIds[index]
                  : order.orderIds[index],
              subtitle: order.testsLabel,
              trailing: AppButton.secondary(
                label: l10n.commonSelectActionLabel,
                onPressed: () =>
                    Navigator.of(context).pop(order.orderIds[index]),
              ),
            ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

LabWorkspaceState? _readLabState(WidgetRef ref) {
  return ref
      .read(labWorkspaceControllerProvider)
      .asData
      ?.value
      .when(success: (LabWorkspaceState state) => state, failure: (_) => null);
}

class _CompactRecordRow extends StatelessWidget {
  const _CompactRecordRow({
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (leading != null) ...<Widget>[
            Icon(
              leading,
              size: theme.appTokens.listIconSize,
              color: theme.colorScheme.primary,
            ),
            SizedBox(width: theme.spacing.sm),
          ],
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

class _EmptyInlineText extends StatelessWidget {
  const _EmptyInlineText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _TestCatalogDialog extends ConsumerStatefulWidget {
  const _TestCatalogDialog({required this.state});

  final LabWorkspaceState state;

  @override
  ConsumerState<_TestCatalogDialog> createState() => _TestCatalogDialogState();
}

class _TestCatalogDialogState extends ConsumerState<_TestCatalogDialog> {
  static const String _categoryFilterKey = 'category';
  static const String _resultKindFilterKey = 'result_kind';

  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<LabCatalogItem>
  _columnVisibilityController;
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;
  LabCatalogItemType _catalogType = LabCatalogItemType.test;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _columnVisibilityController =
        AppListTableColumnVisibilityController<LabCatalogItem>();
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
    final LabWorkspaceState state =
        ref
            .watch(labWorkspaceControllerProvider)
            .asData
            ?.value
            .when(
              success: (LabWorkspaceState value) => value,
              failure: (_) => null,
            ) ??
        widget.state;
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
          SegmentedButton<LabCatalogItemType>(
            segments: <ButtonSegment<LabCatalogItemType>>[
              ButtonSegment<LabCatalogItemType>(
                value: LabCatalogItemType.test,
                icon: const Icon(Icons.science_outlined),
                label: Text(l10n.labTestsTabLabel),
              ),
              ButtonSegment<LabCatalogItemType>(
                value: LabCatalogItemType.panel,
                icon: const Icon(Icons.dashboard_customize_outlined),
                label: Text(l10n.labPanelsTabLabel),
              ),
            ],
            selected: <LabCatalogItemType>{_catalogType},
            onSelectionChanged: (Set<LabCatalogItemType> value) {
              setState(() {
                _catalogType = value.first;
                _filterValue = AppSearchBarFilterValue.empty;
                _searchController.clear();
              });
            },
          ),
          SizedBox(height: theme.spacing.md),
          AppListTable<LabCatalogItem>(
            items: items,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            columnVisibilityController: _columnVisibilityController,
            columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
            search: AppListTableSearch<LabCatalogItem>(
              controller: _searchController,
              semanticLabel: l10n.labCatalogSearchLabel,
              hintText: l10n.labReferenceRangesSearchHint,
              matcher: (LabCatalogItem item, String query) =>
                  item.matchesSearch(query),
              showAdvancedFilterButton: true,
              advancedFilterButtonLabel: l10n.labFiltersLabel,
              advancedFilterTitle: l10n.labFiltersLabel,
              advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
              advancedFilterResetLabel: l10n.opdClearFiltersAction,
              advancedFilterCancelLabel: l10n.commonCancelActionLabel,
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
            emptyBuilder: (_) =>
                _EmptyInlineText(text: l10n.labNoCatalogItemsLabel),
            columns: <AppListTableColumn<LabCatalogItem>>[
              AppListTableColumn<LabCatalogItem>(
                id: 'test',
                label: showingTests
                    ? l10n.labTestNameLabel
                    : l10n.labPanelNameLabel,
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
                label: showingTests
                    ? l10n.labTestCodeLabel
                    : l10n.labPanelCodeLabel,
                sortComparator: (LabCatalogItem left, LabCatalogItem right) =>
                    appListTableCompareText(left.code, right.code),
                cellBuilder: (_, LabCatalogItem item) => Text(item.code ?? '—'),
              ),
              AppListTableColumn<LabCatalogItem>(
                id: 'category',
                label: l10n.labCategoryLabel,
                sortComparator: (LabCatalogItem left, LabCatalogItem right) =>
                    appListTableCompareText(left.category, right.category),
                cellBuilder: (_, LabCatalogItem item) =>
                    Text(item.category ?? '—'),
              ),
              if (showingTests)
                AppListTableColumn<LabCatalogItem>(
                  id: 'specimen',
                  label: l10n.labSpecimenTypeLabel,
                  sortComparator: (LabCatalogItem left, LabCatalogItem right) =>
                      appListTableCompareText(
                        left.specimenType,
                        right.specimenType,
                      ),
                  cellBuilder: (_, LabCatalogItem item) =>
                      Text(item.specimenType ?? '—'),
                ),
              if (showingTests)
                AppListTableColumn<LabCatalogItem>(
                  id: 'kind',
                  label: l10n.labResultKindLabel,
                  sortComparator: (LabCatalogItem left, LabCatalogItem right) =>
                      appListTableCompareText(
                        left.resultKind,
                        right.resultKind,
                      ),
                  cellBuilder: (_, LabCatalogItem item) =>
                      Text(_resultKindLabel(l10n, item.resultKind)),
                ),
              AppListTableColumn<LabCatalogItem>(
                id: 'range',
                label: showingTests
                    ? l10n.labUnitRangeCountColumnLabel
                    : l10n.labTestsColumnLabel,
                cellBuilder: (_, LabCatalogItem item) => Text(
                  showingTests
                      ? _unitRangeSummary(context, item)
                      : l10n.clinicalLabOrderItemCount(item.testCount),
                ),
              ),
              AppListTableColumn<LabCatalogItem>(
                id: 'action',
                label: l10n.labActionColumnLabel,
                cellBuilder: (BuildContext context, LabCatalogItem item) {
                  return Wrap(
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
                            : _openLabPanelDialog(context, state, null, item),
                      ),
                      AppButton.tertiary(
                        label: showingTests
                            ? l10n.labDeleteTestAction
                            : l10n.labDeletePanelAction,
                        leadingIcon: Icons.delete_outline,
                        onPressed: () => showingTests
                            ? _openDeleteLabTestDialog(context, item)
                            : _openDeleteLabPanelDialog(context, item),
                      ),
                    ],
                  );
                },
              ),
            ],
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
                          : _openLabPanelDialog(context, state, null, item),
                    ),
                    AppIconButton(
                      icon: Icons.delete_outline,
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
}

enum _LabCreateAction { order, test, panel }

class _LabCreateActionDialog extends StatelessWidget {
  const _LabCreateActionDialog();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.labCreateChoiceDialogTitle),
      icon: const Icon(Icons.add_circle_outline),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.labCreateChoiceDialogBody),
          const SizedBox(height: 12),
          _CompactRecordRow(
            title: l10n.labCreateOrderAction,
            subtitle: l10n.labCreateOrderChoiceBody,
            leading: Icons.assignment_outlined,
            trailing: AppButton.tertiary(
              label: l10n.labCreateOrderAction,
              onPressed: () =>
                  Navigator.of(context).pop(_LabCreateAction.order),
            ),
          ),
          _CompactRecordRow(
            title: l10n.labCreateTestAction,
            subtitle: l10n.labCreateTestChoiceBody,
            leading: Icons.science_outlined,
            trailing: AppButton.tertiary(
              label: l10n.labCreateTestAction,
              onPressed: () => Navigator.of(context).pop(_LabCreateAction.test),
            ),
          ),
          _CompactRecordRow(
            title: l10n.labCreatePanelAction,
            subtitle: l10n.labCreatePanelChoiceBody,
            leading: Icons.dashboard_customize_outlined,
            trailing: AppButton.tertiary(
              label: l10n.labCreatePanelAction,
              onPressed: () =>
                  Navigator.of(context).pop(_LabCreateAction.panel),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _CreateLabOrderDialog extends ConsumerStatefulWidget {
  const _CreateLabOrderDialog({required this.state});

  final LabWorkspaceState state;

  @override
  ConsumerState<_CreateLabOrderDialog> createState() =>
      _CreateLabOrderDialogState();
}

class _CreateLabOrderDialogState extends ConsumerState<_CreateLabOrderDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _patientIdController;
  late final TextEditingController _encounterIdController;
  late final TextEditingController _orderedAtController;
  final List<LabCatalogItem> _selectedTests = <LabCatalogItem>[];
  final List<LabCatalogItem> _selectedPanels = <LabCatalogItem>[];
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _patientIdController = TextEditingController();
    _encounterIdController = TextEditingController();
    _orderedAtController = TextEditingController();
  }

  @override
  void dispose() {
    _patientIdController.dispose();
    _encounterIdController.dispose();
    _orderedAtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.labCreateOrderDialogTitle),
      icon: const Icon(Icons.assignment_outlined),
      scrollable: true,
      maxWidth: 860,
      content: Form(
        key: _formKey,
        child: Padding(
          padding: EdgeInsets.only(top: Theme.of(context).spacing.xs),
          child: AppFormSection(
            children: <Widget>[
              if (_failure != null) AppFailureStateView(failure: _failure!),
              _SearchableFreeTextField(
                controller: _patientIdController,
                labelText: l10n.labPatientIdLabel,
                enabled: !_isSaving,
                isRequired: true,
                options: _patientSuggestions,
                validator: AppValidators.requiredText(l10n.validationRequired),
              ),
              AppResponsiveFieldRow.two(
                gap: AppResponsiveFieldRowGap.form,
                left: _SearchableFreeTextField(
                  controller: _encounterIdController,
                  labelText: l10n.labEncounterIdLabel,
                  enabled: !_isSaving,
                  options: _encounterSuggestions,
                ),
                right: AppTextField(
                  controller: _orderedAtController,
                  labelText: l10n.labOrderedAtFieldLabel,
                  helperText: l10n.labDateTimeHint,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.datetime,
                  validator: _optionalDateTimeValidator(l10n),
                ),
              ),
              _CatalogSelectionPanel(
                tests: widget.state.catalogTests,
                panels: widget.state.catalogPanels,
                selectedTests: _selectedTests,
                selectedPanels: _selectedPanels,
                enabled: !_isSaving,
                onAddTest: _addTest,
                onAddPanel: _addPanel,
                onRemoveTest: _removeTest,
                onRemovePanel: _removePanel,
              ),
            ],
          ),
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.labCreateOrderSubmitAction,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  List<String> get _patientSuggestions {
    return _uniqueNonEmpty(
      widget.state.worklist.items.map(
        (LabOrderSummary order) => order.patientId,
      ),
    );
  }

  List<String> get _encounterSuggestions {
    final String patientText = _patientIdController.text.trim();
    final Iterable<LabOrderSummary> orders = patientText.isEmpty
        ? widget.state.worklist.items
        : widget.state.worklist.items.where(
            (LabOrderSummary order) =>
                order.patientId?.toLowerCase() == patientText.toLowerCase(),
          );
    return _uniqueNonEmpty(
      orders.map((LabOrderSummary order) => order.encounterId),
    );
  }

  void _addTest(LabCatalogItem item) {
    if (_containsCatalogItem(_selectedTests, item)) {
      return;
    }
    setState(() => _selectedTests.add(item));
  }

  void _addPanel(LabCatalogItem item) {
    if (_containsCatalogItem(_selectedPanels, item)) {
      return;
    }
    setState(() => _selectedPanels.add(item));
  }

  void _removeTest(LabCatalogItem item) {
    setState(
      () => _selectedTests.removeWhere(
        (LabCatalogItem selected) =>
            selected.apiId == item.apiId || selected.id == item.id,
      ),
    );
  }

  void _removePanel(LabCatalogItem item) {
    setState(
      () => _selectedPanels.removeWhere(
        (LabCatalogItem selected) =>
            selected.apiId == item.apiId || selected.id == item.id,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_selectedTests.isEmpty && _selectedPanels.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .createOrder(_payload());
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

  Map<String, Object?> _payload() {
    final String orderedAtText = _orderedAtController.text.trim();
    final DateTime? orderedAt = orderedAtText.isEmpty
        ? null
        : DateTime.tryParse(orderedAtText);
    return <String, Object?>{
      'patient_id': _patientIdController.text.trim(),
      'encounter_id': _encounterIdController.text.trim(),
      'ordered_at': orderedAt?.toUtc().toIso8601String() ?? orderedAtText,
      'requested_tests': _selectedTests
          .map(
            (LabCatalogItem item) => <String, Object?>{
              'lab_test_id': item.apiId,
            },
          )
          .toList(growable: false),
      'requested_panels': _selectedPanels
          .map(
            (LabCatalogItem item) => <String, Object?>{
              'lab_panel_id': item.apiId,
            },
          )
          .toList(growable: false),
    };
  }
}

class _LabPanelDialog extends ConsumerStatefulWidget {
  const _LabPanelDialog({required this.state, required this.tenantId});

  final LabWorkspaceState state;
  final String? tenantId;

  @override
  ConsumerState<_LabPanelDialog> createState() => _LabPanelDialogState();
}

class _LabPanelDialogState extends ConsumerState<_LabPanelDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _categoryController;
  late final TextEditingController _descriptionController;
  final List<LabCatalogItem> _selectedTests = <LabCatalogItem>[];
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _codeController = TextEditingController();
    _categoryController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.labCreatePanelDialogTitle),
      icon: const Icon(Icons.dashboard_customize_outlined),
      scrollable: true,
      maxWidth: 860,
      content: Form(
        key: _formKey,
        child: Padding(
          padding: EdgeInsets.only(top: Theme.of(context).spacing.xs),
          child: AppFormSection(
            children: <Widget>[
              if (_failure != null) AppFailureStateView(failure: _failure!),
              AppResponsiveFieldRow.two(
                gap: AppResponsiveFieldRowGap.form,
                left: AppTextField(
                  controller: _nameController,
                  labelText: l10n.labPanelNameLabel,
                  enabled: !_isSaving,
                  isRequired: true,
                  validator: AppValidators.requiredText(
                    l10n.validationRequired,
                  ),
                ),
                right: AppTextField(
                  controller: _codeController,
                  labelText: l10n.labPanelCodeLabel,
                  enabled: !_isSaving,
                ),
              ),
              _SearchableFreeTextField(
                controller: _categoryController,
                labelText: l10n.labCategoryLabel,
                enabled: !_isSaving,
                options: _uniqueNonEmpty(<String?>[
                  ...widget.state.catalogTests.map(
                    (LabCatalogItem item) => item.category,
                  ),
                  ...widget.state.catalogPanels.map(
                    (LabCatalogItem item) => item.category,
                  ),
                ]),
              ),
              AppTextField(
                controller: _descriptionController,
                labelText: l10n.labPanelDescriptionLabel,
                enabled: !_isSaving,
                maxLines: 3,
              ),
              _CatalogSelectionPanel(
                tests: widget.state.catalogTests,
                panels: const <LabCatalogItem>[],
                selectedTests: _selectedTests,
                selectedPanels: const <LabCatalogItem>[],
                enabled: !_isSaving,
                onAddTest: _addTest,
                onAddPanel: (_) {},
                onRemoveTest: _removeTest,
                onRemovePanel: (_) {},
              ),
            ],
          ),
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.labCreatePanelAction,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  void _addTest(LabCatalogItem item) {
    if (_containsCatalogItem(_selectedTests, item)) {
      return;
    }
    setState(() => _selectedTests.add(item));
  }

  void _removeTest(LabCatalogItem item) {
    setState(
      () => _selectedTests.removeWhere(
        (LabCatalogItem selected) =>
            selected.apiId == item.apiId || selected.id == item.id,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (widget.tenantId == null || _selectedTests.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .createLabPanel(_payload());
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

  Map<String, Object?> _payload() {
    return <String, Object?>{
      'tenant_id': widget.tenantId,
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim(),
      'category': _categoryController.text.trim(),
      'description': _descriptionController.text.trim(),
      'panel_items': _selectedTests
          .asMap()
          .entries
          .map((MapEntry<int, LabCatalogItem> entry) {
            return <String, Object?>{
              'lab_test_id': entry.value.apiId,
              'is_required': true,
              'instructions': null,
              'sort_order': entry.key,
            };
          })
          .toList(growable: false),
    };
  }
}

class _LabTestConfigurationDialog extends ConsumerStatefulWidget {
  const _LabTestConfigurationDialog({
    required this.state,
    required this.item,
    required this.tenantId,
  });

  final LabWorkspaceState state;
  final LabCatalogItem? item;
  final String? tenantId;

  @override
  ConsumerState<_LabTestConfigurationDialog> createState() =>
      _LabTestConfigurationDialogState();
}

class _LabTestConfigurationDialogState
    extends ConsumerState<_LabTestConfigurationDialog> {
  static const String _anyGenderValue = '__ANY__';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _categoryController;
  late final TextEditingController _specimenController;
  late final TextEditingController _unitController;
  late final TextEditingController _rangeLabelController;
  late final TextEditingController _ageMinController;
  late final TextEditingController _ageMaxController;
  late final TextEditingController _rangeUnitController;
  late final TextEditingController _normalMinController;
  late final TextEditingController _normalMaxController;
  late final TextEditingController _criticalMinController;
  late final TextEditingController _criticalMaxController;
  late final TextEditingController _referenceTextController;
  late final TextEditingController _rangeNotesController;
  late List<_EditableLabValue> _unitOptions;
  late List<_EditableLabValue> _resultOptions;
  String? _resultKind;
  String? _gender;
  String? _ageUnit = 'YEAR';
  AppFailure? _failure;
  bool _isSaving = false;

  bool get _isCreateMode => widget.item == null;

  @override
  void initState() {
    super.initState();
    final LabCatalogItem? item = widget.item;
    final LabReferenceRange? range = item?.referenceRanges.isEmpty ?? true
        ? null
        : item!.referenceRanges.first;
    _nameController = TextEditingController(text: item?.name ?? '');
    _codeController = TextEditingController(text: item?.code ?? '');
    _categoryController = TextEditingController(text: item?.category ?? '');
    _specimenController = TextEditingController(text: item?.specimenType ?? '');
    _unitController = TextEditingController(text: item?.unit ?? '');
    _unitOptions = (item?.unitOptions ?? const <LabUnitOption>[])
        .map(_EditableLabValue.fromUnitOption)
        .where((_EditableLabValue value) => value.value.trim().isNotEmpty)
        .toList(growable: true);
    _resultOptions = (item?.resultOptions ?? const <LabResultOption>[])
        .map(_EditableLabValue.fromResultOption)
        .where((_EditableLabValue value) => value.value.trim().isNotEmpty)
        .toList(growable: true);
    _rangeLabelController = TextEditingController(text: range?.label ?? '');
    _ageMinController = TextEditingController(
      text: range?.ageMinValue?.toString() ?? '',
    );
    _ageMaxController = TextEditingController(
      text: range?.ageMaxValue?.toString() ?? '',
    );
    _rangeUnitController = TextEditingController(
      text: range?.unit ?? item?.unit ?? '',
    );
    _normalMinController = TextEditingController(
      text: range?.normalMinValue ?? '',
    );
    _normalMaxController = TextEditingController(
      text: range?.normalMaxValue ?? '',
    );
    _criticalMinController = TextEditingController(
      text: range?.criticalMinValue ?? '',
    );
    _criticalMaxController = TextEditingController(
      text: range?.criticalMaxValue ?? '',
    );
    _referenceTextController = TextEditingController(
      text: range?.referenceText ?? '',
    );
    _rangeNotesController = TextEditingController(text: range?.notes ?? '');
    _resultKind = item?.resultKind ?? 'NUMERIC';
    _gender = range?.gender ?? _anyGenderValue;
    _ageUnit = range?.ageMinUnit ?? range?.ageMaxUnit ?? 'YEAR';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _categoryController.dispose();
    _specimenController.dispose();
    _unitController.dispose();
    _rangeLabelController.dispose();
    _ageMinController.dispose();
    _ageMaxController.dispose();
    _rangeUnitController.dispose();
    _normalMinController.dispose();
    _normalMaxController.dispose();
    _criticalMinController.dispose();
    _criticalMaxController.dispose();
    _referenceTextController.dispose();
    _rangeNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(
        _isCreateMode
            ? l10n.labCreateTestDialogTitle
            : l10n.labConfigureTestDialogTitle,
      ),
      icon: Icon(
        _isCreateMode ? Icons.add_circle_outline : Icons.edit_outlined,
      ),
      scrollable: true,
      maxWidth: 760,
      content: Form(
        key: _formKey,
        child: Padding(
          padding: EdgeInsets.only(top: Theme.of(context).spacing.xs),
          child: AppFormSection(
            children: <Widget>[
              if (_failure != null) AppFailureStateView(failure: _failure!),
              AppTextField(
                controller: _nameController,
                labelText: l10n.labTestNameLabel,
                enabled: !_isSaving,
                isRequired: true,
                validator: AppValidators.requiredText(l10n.validationRequired),
              ),
              AppResponsiveFieldRow.two(
                gap: AppResponsiveFieldRowGap.form,
                left: AppTextField(
                  controller: _codeController,
                  labelText: l10n.labTestCodeLabel,
                  enabled: !_isSaving,
                ),
                right: _SearchableFreeTextField(
                  controller: _categoryController,
                  labelText: l10n.labCategoryLabel,
                  enabled: !_isSaving,
                  options: _categoryOptions,
                ),
              ),
              AppResponsiveFieldRow.two(
                gap: AppResponsiveFieldRowGap.form,
                left: _SearchableFreeTextField(
                  controller: _specimenController,
                  labelText: l10n.labSpecimenTypeLabel,
                  enabled: !_isSaving,
                  options: _specimenOptions,
                ),
                right: AppSelectField<String>.searchable(
                  value: _resultKind,
                  labelText: l10n.labResultKindLabel,
                  enabled: !_isSaving,
                  allowClear: false,
                  isRequired: true,
                  validator: AppValidators.requiredValue(
                    l10n.validationRequired,
                  ),
                  options: <AppSelectOption<String>>[
                    AppSelectOption<String>(
                      value: 'NUMERIC',
                      label: l10n.labResultKindNumeric,
                    ),
                    AppSelectOption<String>(
                      value: 'QUALITATIVE',
                      label: l10n.labResultKindQualitative,
                    ),
                    AppSelectOption<String>(
                      value: 'TEXT',
                      label: l10n.labResultKindText,
                    ),
                  ],
                  onChanged: (String? value) =>
                      setState(() => _resultKind = value),
                ),
              ),
              _SearchableFreeTextField(
                controller: _unitController,
                labelText: l10n.labDefaultUnitLabel,
                enabled: !_isSaving,
                options: _unitOptionsCatalog,
              ),
              _EditableValueListField(
                labelText: l10n.labUnitOptionsLabel,
                values: _unitOptions,
                suggestions: _unitOptionsCatalog,
                enabled: !_isSaving,
                onAdd: (String value) {
                  setState(
                    () => _unitOptions.add(_EditableLabValue(value: value)),
                  );
                },
                onRemove: (_EditableLabValue value) {
                  setState(() => _unitOptions.remove(value));
                },
              ),
              _EditableValueListField(
                labelText: l10n.labQualitativeOptionsLabel,
                values: _resultOptions,
                suggestions: _resultOptionsCatalog,
                enabled: !_isSaving,
                onAdd: (String value) {
                  setState(
                    () => _resultOptions.add(_EditableLabValue(value: value)),
                  );
                },
                onRemove: (_EditableLabValue value) {
                  setState(() => _resultOptions.remove(value));
                },
              ),
              const Divider(height: 24),
              _SearchableFreeTextField(
                controller: _rangeLabelController,
                labelText: l10n.labReferenceRangeLabel,
                enabled: !_isSaving,
                options: _rangeLabelOptions,
              ),
              AppResponsiveFieldRow.two(
                gap: AppResponsiveFieldRowGap.form,
                left: AppSelectField<String>.searchable(
                  value: _gender,
                  labelText: l10n.labGenderApplicabilityLabel,
                  enabled: !_isSaving,
                  allowClear: false,
                  options: <AppSelectOption<String>>[
                    AppSelectOption<String>(
                      value: _anyGenderValue,
                      label: l10n.labGenderAnyLabel,
                    ),
                    AppSelectOption<String>(
                      value: 'MALE',
                      label: l10n.labGenderMaleLabel,
                    ),
                    AppSelectOption<String>(
                      value: 'FEMALE',
                      label: l10n.labGenderFemaleLabel,
                    ),
                    AppSelectOption<String>(
                      value: 'OTHER',
                      label: l10n.labGenderOtherLabel,
                    ),
                    AppSelectOption<String>(
                      value: 'UNKNOWN',
                      label: l10n.labGenderUnknownLabel,
                    ),
                  ],
                  onChanged: (String? value) =>
                      setState(() => _gender = value ?? _anyGenderValue),
                ),
                right: AppSelectField<String>.searchable(
                  value: _ageUnit,
                  labelText: l10n.labAgeUnitLabel,
                  enabled: !_isSaving,
                  allowClear: false,
                  options: <AppSelectOption<String>>[
                    AppSelectOption<String>(
                      value: 'DAY',
                      label: l10n.labAgeUnitDays,
                    ),
                    AppSelectOption<String>(
                      value: 'WEEK',
                      label: l10n.labAgeUnitWeeks,
                    ),
                    AppSelectOption<String>(
                      value: 'MONTH',
                      label: l10n.labAgeUnitMonths,
                    ),
                    AppSelectOption<String>(
                      value: 'YEAR',
                      label: l10n.labAgeUnitYears,
                    ),
                  ],
                  onChanged: (String? value) =>
                      setState(() => _ageUnit = value),
                ),
              ),
              AppResponsiveFieldRow.two(
                gap: AppResponsiveFieldRowGap.form,
                left: AppTextField(
                  controller: _ageMinController,
                  labelText: l10n.labAgeMinLabel,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: _nonNegativeNumberValidator(l10n),
                ),
                right: AppTextField(
                  controller: _ageMaxController,
                  labelText: l10n.labAgeMaxLabel,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: _orderedNumberValidator(
                    l10n,
                    _ageMinController,
                    allowEqual: false,
                    integerOnly: true,
                    nonNegative: true,
                  ),
                ),
              ),
              _SearchableFreeTextField(
                controller: _rangeUnitController,
                labelText: l10n.labResultUnitLabel,
                enabled: !_isSaving,
                options: _unitOptionsCatalog,
              ),
              AppResponsiveFieldRow.two(
                gap: AppResponsiveFieldRowGap.form,
                left: AppTextField(
                  controller: _normalMinController,
                  labelText: l10n.labNormalMinLabel,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: _decimalNumberValidator(l10n),
                ),
                right: AppTextField(
                  controller: _normalMaxController,
                  labelText: l10n.labNormalMaxLabel,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: _orderedNumberValidator(
                    l10n,
                    _normalMinController,
                    allowEqual: true,
                    integerOnly: false,
                  ),
                ),
              ),
              AppResponsiveFieldRow.two(
                gap: AppResponsiveFieldRowGap.form,
                left: AppTextField(
                  controller: _criticalMinController,
                  labelText: l10n.labCriticalMinLabel,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: _decimalNumberValidator(l10n),
                ),
                right: AppTextField(
                  controller: _criticalMaxController,
                  labelText: l10n.labCriticalMaxLabel,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: _orderedNumberValidator(
                    l10n,
                    _criticalMinController,
                    allowEqual: true,
                    integerOnly: false,
                  ),
                ),
              ),
              AppTextField(
                controller: _referenceTextController,
                labelText: l10n.labReferenceTextLabel,
                enabled: !_isSaving,
                maxLines: 2,
              ),
              AppTextField(
                controller: _rangeNotesController,
                labelText: l10n.labNotesLabel,
                enabled: !_isSaving,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: _isCreateMode
            ? l10n.labCreateTestAction
            : l10n.commonSaveActionLabel,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  List<String> get _categoryOptions {
    return _uniqueNonEmpty(
      widget.state.catalogTests.map((LabCatalogItem item) => item.category),
    );
  }

  List<String> get _specimenOptions {
    return _uniqueNonEmpty(
      widget.state.catalogTests.map((LabCatalogItem item) => item.specimenType),
    );
  }

  List<String> get _unitOptionsCatalog {
    return _uniqueNonEmpty(<String?>[
      for (final LabCatalogItem item in widget.state.catalogTests) item.unit,
      for (final LabCatalogItem item in widget.state.catalogTests)
        for (final LabUnitOption option in item.unitOptions)
          option.unit ?? option.label,
      for (final _EditableLabValue option in _unitOptions) option.value,
    ]);
  }

  List<String> get _resultOptionsCatalog {
    return _uniqueNonEmpty(<String?>[
      'Positive',
      'Negative',
      for (final LabCatalogItem item in widget.state.catalogTests)
        for (final LabResultOption option in item.resultOptions)
          option.value ?? option.label,
      for (final _EditableLabValue option in _resultOptions) option.value,
    ]);
  }

  List<String> get _rangeLabelOptions {
    return _uniqueNonEmpty(<String?>[
      'Adult',
      'Pediatric',
      'Neonate',
      for (final LabCatalogItem item in widget.state.catalogTests)
        for (final LabReferenceRange range in item.referenceRanges) range.label,
    ]);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_rangesAreValid()) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    if (_isCreateMode && widget.tenantId == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final LabWorkspaceController controller = ref.read(
      labWorkspaceControllerProvider.notifier,
    );
    final AppFailure? failure = _isCreateMode
        ? await controller.createLabTest(_payload())
        : await controller.updateLabTest(widget.item!.apiId, _payload());
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

  bool _rangesAreValid() {
    return _isRangeValid(
          _normalMinController.text,
          _normalMaxController.text,
          allowEqual: true,
        ) &&
        _isRangeValid(
          _criticalMinController.text,
          _criticalMaxController.text,
          allowEqual: true,
        ) &&
        _isRangeValid(
          _ageMinController.text,
          _ageMaxController.text,
          allowEqual: false,
        );
  }

  bool _isRangeValid(
    String minValue,
    String maxValue, {
    required bool allowEqual,
  }) {
    final String minText = minValue.trim();
    final String maxText = maxValue.trim();
    if (minText.isEmpty || maxText.isEmpty) {
      return true;
    }
    final num? minNumber = num.tryParse(minText);
    final num? maxNumber = num.tryParse(maxText);
    if (minNumber == null || maxNumber == null) {
      return false;
    }
    return allowEqual ? minNumber <= maxNumber : minNumber < maxNumber;
  }

  Map<String, Object?> _payload() {
    final String unit = _unitController.text.trim();
    final List<Map<String, Object?>> referenceRanges = _referenceRangePayloads(
      unit,
    );
    return <String, Object?>{
      if (_isCreateMode) 'tenant_id': widget.tenantId,
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim(),
      'category': _categoryController.text.trim(),
      'specimen_type': _specimenController.text.trim(),
      'result_kind': _resultKind,
      'unit': unit,
      'unit_options': _unitOptions
          .asMap()
          .entries
          .map((MapEntry<int, _EditableLabValue> entry) {
            return <String, Object?>{
              if (entry.value.id != null) 'id': entry.value.id,
              'unit': entry.value.value,
              'label': entry.value.label ?? entry.value.value,
              'is_default': entry.key == 0,
              'sort_order': entry.key,
            };
          })
          .toList(growable: false),
      'result_options': _resultOptions
          .asMap()
          .entries
          .map((MapEntry<int, _EditableLabValue> entry) {
            return <String, Object?>{
              if (entry.value.id != null) 'id': entry.value.id,
              'value': entry.value.value,
              'label': entry.value.label ?? entry.value.value,
              'status': 'NORMAL',
              'sort_order': entry.key,
            };
          })
          .toList(growable: false),
      'reference_ranges': referenceRanges,
    };
  }

  List<Map<String, Object?>> _referenceRangePayloads(String unit) {
    final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];
    final LabReferenceRange? existingRange =
        widget.item?.referenceRanges.isEmpty ?? true
        ? null
        : widget.item!.referenceRanges.first;
    final Map<String, Object?> firstRange = <String, Object?>{
      if (existingRange != null) 'id': existingRange.id,
      'label': _rangeLabelController.text.trim(),
      if (_gender != null && _gender != _anyGenderValue) 'gender': _gender,
      'age_min_value': _ageMinController.text.trim(),
      'age_min_unit': _ageMinController.text.trim().isEmpty ? null : _ageUnit,
      'age_max_value': _ageMaxController.text.trim(),
      'age_max_unit': _ageMaxController.text.trim().isEmpty ? null : _ageUnit,
      'unit': _rangeUnitController.text.trim().isEmpty
          ? unit
          : _rangeUnitController.text.trim(),
      'normal_min_value': _normalMinController.text.trim(),
      'normal_max_value': _normalMaxController.text.trim(),
      'critical_min_value': _criticalMinController.text.trim(),
      'critical_max_value': _criticalMaxController.text.trim(),
      'reference_text': _referenceTextController.text.trim(),
      'notes': _rangeNotesController.text.trim(),
      'sort_order': 0,
    };
    if (_rangeHasContent(firstRange)) {
      payloads.add(firstRange);
    }
    final Iterable<LabReferenceRange> additionalRanges =
        widget.item?.referenceRanges.skip(1) ?? const <LabReferenceRange>[];
    for (final LabReferenceRange range in additionalRanges) {
      payloads.add(_existingRangePayload(range));
    }
    return payloads;
  }

  Map<String, Object?> _existingRangePayload(LabReferenceRange range) {
    return <String, Object?>{
      'id': range.id,
      'label': range.label,
      'gender': range.gender,
      'age_min_value': range.ageMinValue,
      'age_min_unit': range.ageMinUnit,
      'age_max_value': range.ageMaxValue,
      'age_max_unit': range.ageMaxUnit,
      'unit': range.unit,
      'normal_min_value': range.normalMinValue,
      'normal_max_value': range.normalMaxValue,
      'critical_min_value': range.criticalMinValue,
      'critical_max_value': range.criticalMaxValue,
      'reference_text': range.referenceText,
      'notes': range.notes,
      'sort_order': range.sortOrder,
    };
  }

  bool _rangeHasContent(Map<String, Object?> range) {
    return range.entries.any((MapEntry<String, Object?> entry) {
      if (entry.key == 'id' ||
          entry.key == 'sort_order' ||
          entry.key == 'unit' ||
          entry.key == 'age_min_unit' ||
          entry.key == 'age_max_unit') {
        return false;
      }
      final Object? value = entry.value;
      return value != null && value.toString().trim().isNotEmpty;
    });
  }
}

class _CatalogSelectionPanel extends StatefulWidget {
  const _CatalogSelectionPanel({
    required this.tests,
    required this.panels,
    required this.selectedTests,
    required this.selectedPanels,
    required this.enabled,
    required this.onAddTest,
    required this.onAddPanel,
    required this.onRemoveTest,
    required this.onRemovePanel,
  });

  final List<LabCatalogItem> tests;
  final List<LabCatalogItem> panels;
  final List<LabCatalogItem> selectedTests;
  final List<LabCatalogItem> selectedPanels;
  final bool enabled;
  final ValueChanged<LabCatalogItem> onAddTest;
  final ValueChanged<LabCatalogItem> onAddPanel;
  final ValueChanged<LabCatalogItem> onRemoveTest;
  final ValueChanged<LabCatalogItem> onRemovePanel;

  @override
  State<_CatalogSelectionPanel> createState() => _CatalogSelectionPanelState();
}

class _CatalogSelectionPanelState extends State<_CatalogSelectionPanel> {
  late final TextEditingController _searchController;
  Set<LabCatalogItemType> _mode = <LabCatalogItemType>{LabCatalogItemType.test};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool showingPanels = _mode.contains(LabCatalogItemType.panel);
    final List<LabCatalogItem> source = showingPanels
        ? widget.panels
        : widget.tests;
    final List<LabCatalogItem> selected = showingPanels
        ? widget.selectedPanels
        : widget.selectedTests;
    final List<LabCatalogItem> visible = source
        .where(
          (LabCatalogItem item) => item.matchesSearch(_searchController.text),
        )
        .take(8)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentedButton<LabCatalogItemType>(
          segments: <ButtonSegment<LabCatalogItemType>>[
            ButtonSegment<LabCatalogItemType>(
              value: LabCatalogItemType.test,
              label: Text(l10n.clinicalLabRequestTestsModeLabel),
              icon: const Icon(Icons.science_outlined),
            ),
            if (widget.panels.isNotEmpty)
              ButtonSegment<LabCatalogItemType>(
                value: LabCatalogItemType.panel,
                label: Text(l10n.clinicalLabRequestPanelsModeLabel),
                icon: const Icon(Icons.dashboard_customize_outlined),
              ),
          ],
          selected: _mode,
          onSelectionChanged: widget.enabled
              ? (Set<LabCatalogItemType> value) {
                  setState(
                    () => _mode = value.isEmpty
                        ? <LabCatalogItemType>{LabCatalogItemType.test}
                        : value,
                  );
                }
              : null,
        ),
        SizedBox(height: theme.spacing.sm),
        AppTextField(
          controller: _searchController,
          labelText: l10n.clinicalLabRequestSearchLabel,
          hintText: l10n.clinicalLabRequestSearchHint,
          enabled: widget.enabled,
          prefixIcon: const Icon(Icons.search),
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: theme.spacing.sm),
        if (source.isEmpty)
          _EmptyInlineText(text: l10n.clinicalLabRequestNoCatalogOptions)
        else
          ...visible.map((LabCatalogItem item) {
            final bool alreadySelected = _containsCatalogItem(selected, item);
            return _CompactRecordRow(
              title: item.displayTitle,
              subtitle: item.displaySubtitle,
              trailing: AppButton.tertiary(
                label: l10n.clinicalLabRequestAddSelectionAction,
                leadingIcon: Icons.add,
                enabled: widget.enabled && !alreadySelected,
                onPressed: () => showingPanels
                    ? widget.onAddPanel(item)
                    : widget.onAddTest(item),
              ),
            );
          }),
        const Divider(height: 24),
        Text(
          l10n.clinicalLabRequestSelectedTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        if (widget.selectedTests.isEmpty && widget.selectedPanels.isEmpty)
          _EmptyInlineText(text: l10n.clinicalLabRequestNoSelection)
        else
          Wrap(
            spacing: theme.spacing.xs,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              for (final LabCatalogItem item in widget.selectedTests)
                InputChip(
                  label: Text(item.displayTitle),
                  avatar: const Icon(Icons.science_outlined),
                  onDeleted: widget.enabled
                      ? () => widget.onRemoveTest(item)
                      : null,
                ),
              for (final LabCatalogItem item in widget.selectedPanels)
                InputChip(
                  label: Text(item.displayTitle),
                  avatar: const Icon(Icons.dashboard_customize_outlined),
                  onDeleted: widget.enabled
                      ? () => widget.onRemovePanel(item)
                      : null,
                ),
            ],
          ),
      ],
    );
  }
}

class _EditableValueListField extends StatefulWidget {
  const _EditableValueListField({
    required this.labelText,
    required this.values,
    required this.suggestions,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final String labelText;
  final List<_EditableLabValue> values;
  final List<String> suggestions;
  final bool enabled;
  final ValueChanged<String> onAdd;
  final ValueChanged<_EditableLabValue> onRemove;

  @override
  State<_EditableValueListField> createState() =>
      _EditableValueListFieldState();
}

class _EditableValueListFieldState extends State<_EditableValueListField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SearchableFreeTextField(
          controller: _controller,
          labelText: widget.labelText,
          hintText: l10n.labAddValueFieldHint,
          enabled: widget.enabled,
          options: widget.suggestions,
          suffixIcon: IconButton(
            tooltip: l10n.labAddValueAction,
            onPressed: widget.enabled ? _addCurrentValue : null,
            icon: const Icon(Icons.add),
          ),
          onFieldSubmitted: (_) => _addCurrentValue(),
        ),
        if (widget.values.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Wrap(
            spacing: theme.spacing.xs,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              for (final _EditableLabValue value in widget.values)
                InputChip(
                  label: Text(value.value),
                  onDeleted: widget.enabled
                      ? () => widget.onRemove(value)
                      : null,
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _addCurrentValue() {
    final String value = _controller.text.trim();
    if (value.isEmpty) {
      return;
    }
    if (widget.values.any(
      (_EditableLabValue existing) =>
          existing.value.toLowerCase() == value.toLowerCase(),
    )) {
      _controller.clear();
      return;
    }
    widget.onAdd(value);
    _controller.clear();
  }
}

class _SearchableFreeTextField extends StatefulWidget {
  const _SearchableFreeTextField({
    required this.controller,
    required this.labelText,
    required this.options,
    this.enabled = true,
    this.isRequired = false,
    this.hintText,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String labelText;
  final List<String> options;
  final bool enabled;
  final bool isRequired;
  final String? hintText;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<_SearchableFreeTextField> createState() =>
      _SearchableFreeTextFieldState();
}

class _SearchableFreeTextFieldState extends State<_SearchableFreeTextField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue value) {
        final String query = value.text.trim().toLowerCase();
        final List<String> matches = widget.options
            .where(
              (String option) =>
                  query.isEmpty || option.toLowerCase().contains(query),
            )
            .take(10)
            .toList(growable: false);
        if (query.isEmpty ||
            matches.any((String option) => option.toLowerCase() == query)) {
          return matches;
        }
        return <String>[value.text.trim(), ...matches];
      },
      onSelected: (String value) {
        widget.controller.text = value;
      },
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController controller,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return AppTextField(
              controller: controller,
              focusNode: focusNode,
              labelText: widget.labelText,
              hintText: widget.hintText,
              suffixIcon: widget.suffixIcon,
              enabled: widget.enabled,
              isRequired: widget.isRequired,
              validator: widget.validator,
              onFieldSubmitted: (String value) {
                onFieldSubmitted();
                widget.onFieldSubmitted?.call(value);
              },
            );
          },
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            final ThemeData theme = Theme.of(context);
            final List<String> visibleOptions = options.toList(growable: false);
            if (visibleOptions.isEmpty) {
              return const SizedBox.shrink();
            }
            return Align(
              alignment: AlignmentDirectional.topStart,
              child: Material(
                elevation: 4,
                color: theme.colorScheme.surface,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 240,
                    maxWidth: 420,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: visibleOptions.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = visibleOptions[index];
                      return ListTile(
                        dense: true,
                        title: Text(option),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
    );
  }
}

@immutable
final class _EditableLabValue {
  const _EditableLabValue({required this.value, this.id, this.label});

  factory _EditableLabValue.fromUnitOption(LabUnitOption option) {
    return _EditableLabValue(
      id: option.id,
      value: option.unit ?? option.label ?? '',
      label: option.label,
    );
  }

  factory _EditableLabValue.fromResultOption(LabResultOption option) {
    return _EditableLabValue(
      id: option.id,
      value: option.value ?? option.label ?? '',
      label: option.label,
    );
  }

  final String value;
  final String? id;
  final String? label;
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
            if (_failure != null) AppFailureStateView(failure: _failure!),
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
  String? _labTestId;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _labTestId = widget.state.catalogTests.isEmpty
        ? null
        : widget.state.catalogTests.first.apiId;
    _statusController = TextEditingController();
    _loggedAtController = TextEditingController(
      text: DateTime.now().toIso8601String(),
    );
    _notesController = TextEditingController();
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
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>.searchable(
              value: _labTestId,
              labelText: l10n.labQcTestFieldLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              options: <AppSelectOption<String>>[
                for (final LabCatalogItem item in widget.state.catalogTests)
                  AppSelectOption<String>(
                    value: item.apiId,
                    label: item.displayTitle,
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

Future<void> _openLabCreateActionDialog(
  BuildContext context,
  LabWorkspaceState state,
  String? tenantId,
) async {
  final _LabCreateAction? action = await showAppDialog<_LabCreateAction>(
    context: context,
    builder: (_) => const _LabCreateActionDialog(),
  );
  if (action == null || !context.mounted) {
    return;
  }

  switch (action) {
    case _LabCreateAction.order:
      await _openCreateLabOrderDialog(context, state);
      break;
    case _LabCreateAction.test:
      await _openLabTestConfigurationDialog(
        context,
        state,
        null,
        tenantId: tenantId,
      );
      break;
    case _LabCreateAction.panel:
      await _openLabPanelDialog(context, state, tenantId);
      break;
  }
}

Future<void> _openTestCatalogDialog(
  BuildContext context,
  LabWorkspaceState state,
) async {
  await showAppDialog<void>(
    context: context,
    builder: (_) => _TestCatalogDialog(state: state),
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

  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalLabOrderActionDialog(
        referenceData: _clinicalReferenceData(state),
        onRequest:
            ({
              required List<String> labTestIds,
              required List<String> labPanelIds,
            }) {
              return _readLabController(context).createOrder(
                orderContext.toPayload(
                  labTestIds: labTestIds,
                  labPanelIds: labPanelIds,
                ),
              );
            },
        onUpdate:
            ({
              required String labOrderId,
              required List<String> labTestIds,
              required List<String> labPanelIds,
            }) {
              return _readLabController(context).updateOrder(
                labOrderId,
                orderContext.toPayload(
                  labTestIds: labTestIds,
                  labPanelIds: labPanelIds,
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

  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalLabOrderActionDialog(
        referenceData: _clinicalReferenceData(state),
        existingOrder: _clinicalLabOrderRecord(order),
        onRequest:
            ({
              required List<String> labTestIds,
              required List<String> labPanelIds,
            }) {
              return _readLabController(context).createOrder(
                orderContext.toPayload(
                  labTestIds: labTestIds,
                  labPanelIds: labPanelIds,
                ),
              );
            },
        onUpdate:
            ({
              required String labOrderId,
              required List<String> labTestIds,
              required List<String> labPanelIds,
            }) {
              return _readLabController(context).updateOrder(
                labOrderId,
                orderContext.toPayload(
                  labTestIds: labTestIds,
                  labPanelIds: labPanelIds,
                ),
              );
            },
      ),
    ),
  );
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
        .map(_clinicalCatalogOption)
        .toList(growable: false),
    labPanels: state.catalogPanels
        .map(_clinicalCatalogOption)
        .toList(growable: false),
  );
}

ClinicalActionCatalogOption _clinicalCatalogOption(LabCatalogItem item) {
  return ClinicalActionCatalogOption(
    id: item.id,
    publicId: item.displayId,
    name: item.name,
    code: item.code,
    category: item.category,
    secondaryText: _joinNonEmpty(<String?>[
      item.specimenType,
      item.resultKind,
      item.unit,
      item.referenceRange,
    ]),
    metadata: <String, Object?>{
      'type': item.type.name,
      if (item.description != null) 'description': item.description,
    },
    childIds: item.panelItems
        .map((LabPanelItem item) => item.labTestId)
        .whereType<String>()
        .toList(growable: false),
    childCodes: item.panelItems
        .map((LabPanelItem item) => item.testCode)
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

bool _containsCatalogItem(List<LabCatalogItem> items, LabCatalogItem item) {
  return items.any(
    (LabCatalogItem selected) =>
        selected.apiId == item.apiId || selected.id == item.id,
  );
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

FormFieldValidator<String> _optionalDateTimeValidator(AppLocalizations l10n) {
  return (String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty || DateTime.tryParse(text) != null) {
      return null;
    }
    return l10n.appDateInvalidMessage;
  };
}

FormFieldValidator<String> _decimalNumberValidator(AppLocalizations l10n) {
  return (String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty || num.tryParse(text) != null) {
      return null;
    }
    return l10n.labNumericRangeValidationMessage;
  };
}

FormFieldValidator<String> _nonNegativeNumberValidator(AppLocalizations l10n) {
  return (String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final int? parsed = int.tryParse(text);
    if (parsed != null && parsed >= 0) {
      return null;
    }
    return l10n.labNumericRangeValidationMessage;
  };
}

FormFieldValidator<String> _orderedNumberValidator(
  AppLocalizations l10n,
  TextEditingController minController, {
  required bool allowEqual,
  required bool integerOnly,
  bool nonNegative = false,
}) {
  return (String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final num? parsed = integerOnly ? int.tryParse(text) : num.tryParse(text);
    if (parsed == null || (nonNegative && parsed < 0)) {
      return l10n.labNumericRangeValidationMessage;
    }
    final String minText = minController.text.trim();
    if (minText.isEmpty) {
      return null;
    }
    final num? minValue = integerOnly
        ? int.tryParse(minText)
        : num.tryParse(minText);
    if (minValue == null || (nonNegative && minValue < 0)) {
      return null;
    }
    final bool inOrder = allowEqual ? minValue <= parsed : minValue < parsed;
    return inOrder ? null : l10n.labNumericRangeValidationMessage;
  };
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
  if (order.hasRejectedItem) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusRejected,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.block_outlined,
    );
  }
  if (order.verifiableItemCount > 0 || order.pendingItemCount > 0) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusPendingResults,
      tone: AppWorkspaceStatusTone.warning,
      icon: Icons.pending_actions_outlined,
    );
  }
  if (order.completedItemCount > 0 &&
      order.completedItemCount >= order.itemCount) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusVerified,
      tone: AppWorkspaceStatusTone.success,
      icon: Icons.verified_outlined,
    );
  }
  return AppWorkspaceStatus(
    label: context.l10n.labStatusOrdered,
    icon: Icons.assignment_outlined,
  );
}

AppWorkspaceStatus _resultStatus(BuildContext context, LabOrderSummary order) {
  if (order.hasCriticalResult) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusCritical,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.priority_high_outlined,
    );
  }
  if (order.completedItemCount > 0 &&
      order.completedItemCount >= order.itemCount) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusCompleted,
      tone: AppWorkspaceStatusTone.success,
      icon: Icons.verified_outlined,
    );
  }
  if (order.inProcessItemCount > 0) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusPending,
      tone: AppWorkspaceStatusTone.warning,
      icon: Icons.pending_actions_outlined,
    );
  }
  return AppWorkspaceStatus(
    label: context.l10n.labStatusOrdered,
    icon: Icons.radio_button_unchecked,
  );
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
