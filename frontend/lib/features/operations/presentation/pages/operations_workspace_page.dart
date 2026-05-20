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
import 'package:hosspi_hms/features/operations/domain/entities/operations_entities.dart';
import 'package:hosspi_hms/features/operations/presentation/controllers/operations_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class OperationsWorkspacePage extends ConsumerWidget {
  const OperationsWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<OperationsWorkspaceState>> workspace = ref.watch(
      operationsWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<OperationsWorkspaceState>(
      value: workspace,
      appBarTitle: l10n.operationsTitle,
      loadingTitle: l10n.operationsLoadingTitle,
      loadingBody: l10n.operationsLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(operationsWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, OperationsWorkspaceState state) {
        return _OperationsWorkspaceContent(state: state);
      },
    );
  }
}

class _OperationsWorkspaceContent extends ConsumerStatefulWidget {
  const _OperationsWorkspaceContent({required this.state});

  final OperationsWorkspaceState state;

  @override
  ConsumerState<_OperationsWorkspaceContent> createState() =>
      _OperationsWorkspaceContentState();
}

class _OperationsWorkspaceContentState
    extends ConsumerState<_OperationsWorkspaceContent> {
  static const AccessRequirement _mutationRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[AppPermissions.operationsWrite],
    activeModules: <String>['facilities-maintenance'],
  );

  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<OperationsWorkItem>
  _tableColumnController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<OperationsWorkItem>();
  }

  @override
  void didUpdateWidget(covariant _OperationsWorkspaceContent oldWidget) {
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
    final OperationsWorkspaceState state = widget.state;
    final OperationsWorkspaceController controller = ref.read(
      operationsWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool canMutate = _mutationRequirement.isAllowed(policy);
    final AppFailure? lastFailure = state.lastFailure;

    return AppWorkspace(
      title: l10n.operationsTitle,
      leadingIcon: AppRouteIcons.operations,
      compactSummaryCards: true,
      status: AppWorkspaceStatus(
        label: state.isMutating
            ? l10n.operationsSavingStatus
            : l10n.operationsLiveStatus,
        tone: state.isMutating
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
        icon: state.isMutating ? Icons.sync_outlined : Icons.sensors_outlined,
      ),
      primaryAction: canMutate
          ? AppButton.primary(
              label: l10n.operationsCreateRequestAction,
              leadingIcon: Icons.add,
              enabled: !state.isMutating,
              onPressed: () => _showCreateRequestDialog(context, ref, state),
            )
          : null,
      secondaryActions: <Widget>[
        AppButton.secondary(
          label: l10n.operationsOpenReportAction,
          leadingIcon: Icons.summarize_outlined,
          onPressed: () => _showOperationsReportDialog(context, state),
        ),
        AppIconButton(
          icon: Icons.refresh,
          semanticLabel: l10n.commonRefreshActionLabel,
          tooltip: l10n.commonRefreshActionLabel,
          isLoading: state.isRefreshing,
          onPressed: state.isRefreshing
              ? null
              : () async {
                  final AppFailure? failure = await controller.refresh();
                  if (context.mounted) {
                    _showFailureIfNeeded(context, failure);
                  }
                },
        ),
      ],
      summaryCards: _summaryCards(context, state, controller),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (lastFailure != null) ...<Widget>[
            AppFailureStateView(failure: lastFailure, onRetry: controller.refresh),
            SizedBox(height: Theme.of(context).spacing.md),
          ],
          _OperationsQueuePanel(
            state: state,
            searchController: _searchController,
            columnVisibilityController: _tableColumnController,
          ),
        ],
      ),
      detail: _OperationsDetailPanel(state: state, canMutate: canMutate),
    );
  }

  List<Widget> _summaryCards(
    BuildContext context,
    OperationsWorkspaceState state,
    OperationsWorkspaceController controller,
  ) {
    final Locale locale = Localizations.localeOf(context);
    final AppLocalizations l10n = context.l10n;
    final int total = state.workItems.totalItemCount ?? state.workItems.items.length;

    return <Widget>[
      if (total > 0)
        AppWorkspaceSummaryCard(
          label: l10n.operationsAllRequestsSummaryLabel,
          value: AppFormatters.compactNumber(total, locale),
          icon: Icons.inventory_2_outlined,
          compact: true,
          onPressed: controller.clearFilters,
        ),
      if (state.openCount > 0)
        AppWorkspaceSummaryCard(
          label: l10n.operationsOpenSummaryLabel,
          value: AppFormatters.compactNumber(state.openCount, locale),
          icon: Icons.pending_actions_outlined,
          tone: AppWorkspaceStatusTone.warning,
          compact: true,
          onPressed: () => controller.applyStatus('OPEN'),
        ),
      if (state.inProgressCount > 0)
        AppWorkspaceSummaryCard(
          label: l10n.operationsInProgressSummaryLabel,
          value: AppFormatters.compactNumber(state.inProgressCount, locale),
          icon: Icons.engineering_outlined,
          tone: AppWorkspaceStatusTone.info,
          compact: true,
          onPressed: () => controller.applyStatus('IN_PROGRESS'),
        ),
      if (state.completedCount > 0)
        AppWorkspaceSummaryCard(
          label: l10n.operationsCompletedSummaryLabel,
          value: AppFormatters.compactNumber(state.completedCount, locale),
          icon: Icons.task_alt_outlined,
          tone: AppWorkspaceStatusTone.success,
          compact: true,
          onPressed: () => controller.applyStatus('COMPLETED'),
        ),
      if (state.cancelledCount > 0)
        AppWorkspaceSummaryCard(
          label: l10n.operationsCancelledSummaryLabel,
          value: AppFormatters.compactNumber(state.cancelledCount, locale),
          icon: Icons.cancel_outlined,
          tone: AppWorkspaceStatusTone.error,
          compact: true,
          onPressed: () => controller.applyStatus('CANCELLED'),
        ),
      if (state.assetCount > 0)
        AppWorkspaceSummaryCard(
          label: l10n.operationsAssetsSummaryLabel,
          value: AppFormatters.compactNumber(state.assetCount, locale),
          icon: Icons.precision_manufacturing_outlined,
          compact: true,
        ),
    ];
  }
}

class _OperationsQueuePanel extends ConsumerWidget {
  const _OperationsQueuePanel({
    required this.state,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final OperationsWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<OperationsWorkItem>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final OperationsWorkspaceController controller = ref.read(
      operationsWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.operationsQueueTitle,
      description: l10n.operationsQueueDescription,
      child: AppListTable<OperationsWorkItem>(
        page: state.workItems,
        isLoading: state.isRefreshing,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        columnVisibilityController: columnVisibilityController,
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        search: AppListTableSearch<OperationsWorkItem>(
          controller: searchController,
          semanticLabel: l10n.operationsSearchLabel,
          hintText: l10n.operationsSearchHint,
          clearLabel: l10n.operationsClearFiltersAction,
          matcher: (_, _) => true,
          onSubmitted: controller.applySearch,
          onClear: () => controller.applySearch(''),
          showAdvancedFilterButton: true,
          advancedFilterButtonLabel: l10n.operationsFiltersLabel,
          advancedFilterTitle: l10n.operationsFiltersLabel,
          advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
          advancedFilterResetLabel: l10n.operationsClearFiltersAction,
          advancedFilterCancelLabel: l10n.commonCancelActionLabel,
          searchFieldLabel: l10n.operationsSearchFieldsLabel,
          allFieldsLabel: l10n.operationsAllFilterOption,
          searchFields: _operationsSearchFields(l10n),
          textFilters: _operationsTextFilters(l10n),
          dateFilterLabel: l10n.operationsReportedDateFilterLabel,
          dateFromLabel: l10n.operationsReportedFromLabel,
          dateToLabel: l10n.operationsReportedToLabel,
          datePickerButtonLabel: l10n.operationsPickReportedDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          filterGroups: <AppSearchBarFilterGroup>[
            AppSearchBarFilterGroup(
              key: _operationsStatusFilterKey,
              label: l10n.operationsStatusFilterLabel,
              allLabel: l10n.operationsAllFilterOption,
              choices: _statusFilterChoices(l10n),
            ),
            AppSearchBarFilterGroup(
              key: _operationsPriorityFilterKey,
              label: l10n.operationsPriorityFilterLabel,
              allLabel: l10n.operationsAllFilterOption,
              choices: _priorityFilterChoices(l10n),
            ),
          ],
          filterValue: _operationsFilterValue(state.query),
          hasActiveFilters: _hasOperationsFilters(state.query),
          onFilterChanged: (AppSearchBarFilterValue value) async {
            final AppFailure? failure = await controller.applyFilters(
              status: value.option(_operationsStatusFilterKey),
              priority: value.option(_operationsPriorityFilterKey),
              facilityId: value.text(_operationsFacilityFilterKey),
              assetId: value.text(_operationsAssetFilterKey),
              reportedFrom: value.dateFrom,
              reportedTo: value.dateTo,
            );
            if (context.mounted) {
              _showFailureIfNeeded(context, failure);
            }
          },
        ),
        itemKeyBuilder: (OperationsWorkItem item) => ValueKey<String>(item.id),
        onRowSelected: (OperationsWorkItem item) {
          unawaited(controller.selectItem(item));
        },
        previousPageLabel: l10n.opdPreviousPageLabel,
        nextPageLabel: l10n.opdNextPageLabel,
        pageLabelBuilder: (AppPage<OperationsWorkItem> page) {
          return l10n.operationsPageLabel(
            page.firstItemNumber,
            page.lastItemNumber,
            page.totalItemCount ?? page.lastItemNumber,
          );
        },
        onPageChanged: (AppPageRequest request) {
          unawaited(controller.changePage(request));
        },
        emptyBuilder: (BuildContext context) {
          return AppStateView(
            title: l10n.operationsNoRequestsTitle,
            body: l10n.operationsNoRequestsBody,
            variant: AppStateViewVariant.empty,
          );
        },
        columns: _operationColumns(l10n),
        columnChoices: _operationColumnChoices(l10n),
        mobileItemBuilder: (BuildContext context, OperationsWorkItem item) {
          return _OperationsRequestListTile(item: item);
        },
      ),
    );
  }
}

class _OperationsDetailPanel extends ConsumerWidget {
  const _OperationsDetailPanel({
    required this.state,
    required this.canMutate,
  });

  final OperationsWorkspaceState state;
  final bool canMutate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final OperationsWorkItem? item = state.selectedItem;
    if (item == null) {
      return AppWorkspaceDetailPanel(
        title: l10n.operationsDetailTitle,
        child: AppStateView(
          title: l10n.operationsNoSelectionTitle,
          body: l10n.operationsNoSelectionBody,
          variant: AppStateViewVariant.empty,
        ),
      );
    }

    return AppWorkspaceDetailPanel(
      title: l10n.operationsDetailTitle,
      description: item.effectiveDisplayId,
      actions: <Widget>[
        AppIconButton(
          icon: Icons.summarize_outlined,
          semanticLabel: l10n.operationsOpenReportAction,
          tooltip: l10n.operationsOpenReportAction,
          onPressed: () => _showRequestReportDialog(context, state, item),
        ),
      ],
      child: state.isRefreshingDetail
          ? const Center(child: CircularProgressIndicator())
          : _OperationsDetailBody(
              state: state,
              item: item,
              canMutate: canMutate,
            ),
    );
  }
}

class _OperationsDetailBody extends ConsumerWidget {
  const _OperationsDetailBody({
    required this.state,
    required this.item,
    required this.canMutate,
  });

  final OperationsWorkspaceState state;
  final OperationsWorkItem item;
  final bool canMutate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<Widget> children = <Widget>[
      _OperationsStatusBanner(item: item),
      AppInfoTileGrid(
        maxColumns: 2,
        items: <AppInfoTileData>[
          AppInfoTileData(
            label: l10n.operationsStatusColumnLabel,
            value: _statusLabel(l10n, item.status),
            icon: Icons.fact_check_outlined,
          ),
          AppInfoTileData(
            label: l10n.operationsPriorityColumnLabel,
            value: _priorityLabel(l10n, item.metadata.priority),
            icon: Icons.priority_high_outlined,
          ),
          AppInfoTileData(
            label: l10n.operationsCategoryLabel,
            value: _categoryLabel(l10n, item.metadata.category),
            icon: Icons.category_outlined,
          ),
          AppInfoTileData(
            label: l10n.operationsAssigneeColumnLabel,
            value: _display(item.metadata.assignee, l10n.operationsUnassignedValue),
            icon: Icons.assignment_ind_outlined,
          ),
          AppInfoTileData(
            label: l10n.operationsLocationColumnLabel,
            value: _locationLabel(l10n, item),
            icon: Icons.location_on_outlined,
          ),
          AppInfoTileData(
            label: l10n.operationsDueColumnLabel,
            value: _formatDateTimeOrFallback(
              context,
              item.dueAt,
              l10n.operationsNoDueTimeValue,
            ),
            icon: Icons.timer_outlined,
          ),
        ],
      ),
      AppSectionPanel(
        title: l10n.operationsIssueTitle,
        leadingIcon: Icons.report_problem_outlined,
        children: <Widget>[
          Text(_issueLabel(l10n, item)),
          if (_display(item.metadata.notes, '').isNotEmpty)
            Text(
              item.metadata.notes!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      if (canMutate) _OperationsActionPanel(item: item, state: state),
      _ServiceLogsPanel(logs: state.serviceLogs),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < children.length; index += 1) ...<Widget>[
          children[index],
          if (index < children.length - 1) SizedBox(height: theme.spacing.md),
        ],
      ],
    );
  }
}

class _OperationsStatusBanner extends StatelessWidget {
  const _OperationsStatusBanner({required this.item});

  final OperationsWorkItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppContentPanel(
      tone: _statusTone(item.status),
      density: AppContentPanelDensity.compact,
      child: Row(
        children: <Widget>[
          Icon(_statusIcon(item.status), size: Theme.of(context).appTokens.listIconSize),
          SizedBox(width: Theme.of(context).spacing.sm),
          Expanded(
            child: Text(
              _nextActionLabel(l10n, item),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationsActionPanel extends ConsumerWidget {
  const _OperationsActionPanel({required this.item, required this.state});

  final OperationsWorkItem item;
  final OperationsWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final OperationsWorkspaceController controller = ref.read(
      operationsWorkspaceControllerProvider.notifier,
    );

    return AppSectionPanel(
      title: l10n.operationsActionsTitle,
      leadingIcon: Icons.handyman_outlined,
      children: <Widget>[
        AppResponsiveWrap(
          minItemWidth: 180,
          maxColumns: 2,
          children: <Widget>[
            AppButton.secondary(
              label: l10n.operationsAssignAction,
              leadingIcon: Icons.assignment_ind_outlined,
              enabled: !state.isMutating && !item.isTerminal,
              onPressed: () => _showAssignDialog(context, ref),
            ),
            AppButton.secondary(
              label: l10n.operationsUpdateStatusAction,
              leadingIcon: Icons.fact_check_outlined,
              enabled: !state.isMutating,
              onPressed: () => _showStatusDialog(context, ref, item),
            ),
            AppButton.secondary(
              label: l10n.operationsAddServiceLogAction,
              leadingIcon: Icons.build_outlined,
              enabled: !state.isMutating && _hasValue(item.assetId),
              onPressed: () => _showServiceLogDialog(context, ref, state),
            ),
            AppButton.secondary(
              label: l10n.operationsPartsVendorAction,
              leadingIcon: Icons.local_shipping_outlined,
              enabled: !state.isMutating && !item.isTerminal,
              onPressed: () => _showNoteDialog(
                context,
                title: l10n.operationsPartsVendorAction,
                fieldLabel: l10n.operationsPartsVendorNoteLabel,
                submitLabel: l10n.operationsSaveNoteAction,
                kind: _noteKindPartsVendor,
                controller: controller,
              ),
            ),
            AppButton.secondary(
              label: l10n.operationsSafetyNoteAction,
              leadingIcon: Icons.health_and_safety_outlined,
              enabled: !state.isMutating,
              onPressed: () => _showNoteDialog(
                context,
                title: l10n.operationsSafetyNoteAction,
                fieldLabel: l10n.operationsSafetyNoteLabel,
                submitLabel: l10n.operationsSaveNoteAction,
                kind: _noteKindSafety,
                controller: controller,
              ),
            ),
            AppButton.secondary(
              label: l10n.operationsEvidenceNoteAction,
              leadingIcon: Icons.attach_file_outlined,
              enabled: !state.isMutating,
              onPressed: () => _showNoteDialog(
                context,
                title: l10n.operationsEvidenceNoteAction,
                fieldLabel: l10n.operationsEvidenceNoteLabel,
                submitLabel: l10n.operationsSaveNoteAction,
                kind: _noteKindEvidence,
                controller: controller,
              ),
            ),
            AppButton.secondary(
              label: l10n.operationsHandoverNoteAction,
              leadingIcon: Icons.swap_horiz_outlined,
              enabled: !state.isMutating,
              onPressed: () => _showNoteDialog(
                context,
                title: l10n.operationsHandoverNoteAction,
                fieldLabel: l10n.operationsHandoverNoteLabel,
                submitLabel: l10n.operationsSaveNoteAction,
                kind: _noteKindHandover,
                controller: controller,
              ),
            ),
            AppButton.secondary(
              label: l10n.operationsCloseoutNoteAction,
              leadingIcon: Icons.verified_outlined,
              enabled: !state.isMutating,
              onPressed: () => _showNoteDialog(
                context,
                title: l10n.operationsCloseoutNoteAction,
                fieldLabel: l10n.operationsCloseoutNoteLabel,
                submitLabel: l10n.operationsSaveNoteAction,
                kind: _noteKindCloseout,
                controller: controller,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ServiceLogsPanel extends StatelessWidget {
  const _ServiceLogsPanel({required this.logs});

  final AppPage<OperationsServiceLog> logs;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    if (logs.items.isEmpty) {
      return AppWorkspaceDetailPanel(
        title: l10n.operationsServiceLogsTitle,
        child: AppStateView(
          title: l10n.operationsNoServiceLogsTitle,
          body: l10n.operationsNoServiceLogsBody,
          variant: AppStateViewVariant.empty,
        ),
      );
    }

    return AppWorkspaceDetailPanel(
      title: l10n.operationsServiceLogsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var index = 0; index < logs.items.length; index += 1) ...<Widget>[
            _ServiceLogTile(log: logs.items[index]),
            if (index < logs.items.length - 1) SizedBox(height: theme.spacing.sm),
          ],
        ],
      ),
    );
  }
}

class _ServiceLogTile extends StatelessWidget {
  const _ServiceLogTile({required this.log});

  final OperationsServiceLog log;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppSectionPanel(
      density: AppContentPanelDensity.compact,
      leadingIcon: Icons.build_circle_outlined,
      title: _formatDateTimeOrFallback(
        context,
        log.servicedAt ?? log.createdAt,
        l10n.operationsUnknownValue,
      ),
      description: _display(log.assetLabel, log.assetId ?? l10n.operationsUnknownValue),
      children: <Widget>[
        Text(_display(log.notes, l10n.operationsNoNotesValue)),
      ],
    );
  }
}

class _OperationsRequestListTile extends StatelessWidget {
  const _OperationsRequestListTile({required this.item});

  final OperationsWorkItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppListItemRow(
      leadingIcon: _statusIcon(item.status),
      title: _issueLabel(l10n, item),
      subtitle: _joinDisplay(<String>[
        item.effectiveDisplayId,
        _locationLabel(l10n, item),
        _priorityLabel(l10n, item.metadata.priority),
      ]),
      trailing: _OperationStatusBadge(status: item.status),
      details: <Widget>[
        AppInlineMetaText(
          icon: Icons.next_plan_outlined,
          label: _nextActionLabel(l10n, item),
        ),
      ],
    );
  }
}

class _OperationStatusBadge extends StatelessWidget {
  const _OperationStatusBadge({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(
        label: _statusLabel(context.l10n, status),
        tone: _statusTone(status),
        icon: _statusIcon(status),
      ),
    );
  }
}

class _OperationPriorityBadge extends StatelessWidget {
  const _OperationPriorityBadge({required this.priority});

  final String? priority;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(
        label: _priorityLabel(context.l10n, priority),
        tone: _priorityTone(priority),
        icon: Icons.priority_high_outlined,
      ),
    );
  }
}

class _TwoLineCell extends StatelessWidget {
  const _TwoLineCell({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return AppListItemText(
      title: title,
      subtitle: subtitle,
      titleStyle: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _CreateRequestForm extends StatefulWidget {
  const _CreateRequestForm({required this.assets});

  final List<OperationsAsset> assets;

  @override
  State<_CreateRequestForm> createState() => _CreateRequestFormState();
}

class _CreateRequestFormState extends State<_CreateRequestForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _facilityController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _category = 'GENERAL_ASSET';
  String _priority = 'NORMAL';
  String? _assetId;

  @override
  void dispose() {
    _facilityController.dispose();
    _locationController.dispose();
    _issueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<String>(
          value: _category,
          labelText: l10n.operationsCategoryLabel,
          options: _categoryOptions(l10n),
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _category = value);
            }
          },
        ),
        AppSelectField<String>(
          value: _priority,
          labelText: l10n.operationsPriorityColumnLabel,
          options: _priorityOptions(l10n),
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _priority = value);
            }
          },
        ),
        AppTextField(
          controller: _facilityController,
          labelText: l10n.operationsFacilityFilterLabel,
          textInputAction: TextInputAction.next,
        ),
        AppSelectField<String>.searchable(
          value: _assetId,
          labelText: l10n.operationsAssetFilterLabel,
          options: _assetOptions(widget.assets, l10n),
          onChanged: (String? value) => setState(() => _assetId = value),
        ),
        AppTextField(
          controller: _locationController,
          labelText: l10n.operationsLocationNoteLabel,
          textInputAction: TextInputAction.next,
        ),
        AppTextField(
          controller: _issueController,
          labelText: l10n.operationsIssueFieldLabel,
          isRequired: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          validator: AppValidators.requiredText(l10n.validationRequired),
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.operationsNotesLabel,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.operationsCreateRequestSubmitAction,
          submitIcon: Icons.add,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: _submit,
        ),
      ],
    );
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(
      OperationsRequestDraft(
        category: _category,
        priority: _priority,
        issue: _issueController.text.trim(),
        facilityId: _facilityController.text.trim(),
        assetId: _assetId,
        location: _locationController.text.trim(),
        notes: _notesController.text.trim(),
      ),
    );
  }
}

class _AssignRequestForm extends StatefulWidget {
  const _AssignRequestForm();

  @override
  State<_AssignRequestForm> createState() => _AssignRequestFormState();
}

class _AssignRequestFormState extends State<_AssignRequestForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _assigneeController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _slaController = TextEditingController();

  @override
  void dispose() {
    _assigneeController.dispose();
    _summaryController.dispose();
    _slaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _assigneeController,
          labelText: l10n.operationsAssigneeFieldLabel,
          textInputAction: TextInputAction.next,
        ),
        AppTextField(
          controller: _slaController,
          labelText: l10n.operationsSlaHoursFieldLabel,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          textInputAction: TextInputAction.next,
        ),
        AppTextField(
          controller: _summaryController,
          labelText: l10n.operationsTriageSummaryFieldLabel,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.operationsAssignSubmitAction,
          submitIcon: Icons.assignment_ind_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: _submit,
        ),
      ],
    );
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(
      OperationsTriageDraft(
        assignedEngineer: _assigneeController.text.trim(),
        triageSummary: _summaryController.text.trim(),
        slaHours: int.tryParse(_slaController.text.trim()),
      ),
    );
  }
}

class _StatusUpdateForm extends StatefulWidget {
  const _StatusUpdateForm({required this.item});

  final OperationsWorkItem item;

  @override
  State<_StatusUpdateForm> createState() => _StatusUpdateFormState();
}

class _StatusUpdateFormState extends State<_StatusUpdateForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = operationsMaintenanceStatuses.contains(widget.item.normalizedStatus)
        ? widget.item.normalizedStatus
        : 'OPEN';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<String>(
          value: _status,
          labelText: l10n.operationsStatusColumnLabel,
          options: _statusOptions(l10n),
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _status = value);
            }
          },
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.operationsStatusNoteLabel,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.operationsUpdateStatusSubmitAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: _submit,
        ),
      ],
    );
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(
      OperationsStatusUpdateDraft(
        status: _status,
        notes: _notesController.text.trim(),
        resolvedAt: _status == 'COMPLETED' ? DateTime.now() : null,
      ),
    );
  }
}

class _ServiceLogForm extends StatefulWidget {
  const _ServiceLogForm({required this.assets, required this.initialAssetId});

  final List<OperationsAsset> assets;
  final String? initialAssetId;

  @override
  State<_ServiceLogForm> createState() => _ServiceLogFormState();
}

class _ServiceLogFormState extends State<_ServiceLogForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  late String? _assetId;

  @override
  void initState() {
    super.initState();
    _assetId = widget.initialAssetId;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<String>.searchable(
          value: _assetId,
          labelText: l10n.operationsAssetFilterLabel,
          isRequired: true,
          options: _assetOptions(widget.assets, l10n),
          validator: (String? value) =>
              _hasValue(value) ? null : l10n.validationRequired,
          onChanged: (String? value) => setState(() => _assetId = value),
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.operationsServiceNotesLabel,
          isRequired: true,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          validator: AppValidators.requiredText(l10n.validationRequired),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.operationsAddServiceLogSubmitAction,
          submitIcon: Icons.build_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: _submit,
        ),
      ],
    );
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey) || !_hasValue(_assetId)) {
      return;
    }
    Navigator.of(context).pop(
      OperationsServiceLogDraft(
        assetId: _assetId!,
        notes: _notesController.text.trim(),
        servicedAt: DateTime.now(),
      ),
    );
  }
}

Future<void> _showCreateRequestDialog(
  BuildContext context,
  WidgetRef ref,
  OperationsWorkspaceState state,
) async {
  final OperationsRequestDraft? draft = await showAppDialog<OperationsRequestDraft>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(context.l10n.operationsCreateRequestAction),
      icon: const Icon(Icons.add_task_outlined),
      scrollable: true,
      maxWidth: 720,
      content: _CreateRequestForm(assets: state.assets.items),
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }

  final AppFailure? failure = await ref
      .read(operationsWorkspaceControllerProvider.notifier)
      .createRequest(draft);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showAssignDialog(BuildContext context, WidgetRef ref) async {
  final OperationsTriageDraft? draft = await showAppDialog<OperationsTriageDraft>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(context.l10n.operationsAssignAction),
      icon: const Icon(Icons.assignment_ind_outlined),
      scrollable: true,
      maxWidth: 640,
      content: const _AssignRequestForm(),
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }

  final AppFailure? failure = await ref
      .read(operationsWorkspaceControllerProvider.notifier)
      .assignSelected(draft);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showStatusDialog(
  BuildContext context,
  WidgetRef ref,
  OperationsWorkItem item,
) async {
  final OperationsStatusUpdateDraft? draft =
      await showAppDialog<OperationsStatusUpdateDraft>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(context.l10n.operationsUpdateStatusAction),
      icon: const Icon(Icons.fact_check_outlined),
      scrollable: true,
      maxWidth: 640,
      content: _StatusUpdateForm(item: item),
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }

  final AppFailure? failure = await ref
      .read(operationsWorkspaceControllerProvider.notifier)
      .updateSelectedStatus(draft);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showServiceLogDialog(
  BuildContext context,
  WidgetRef ref,
  OperationsWorkspaceState state,
) async {
  final OperationsServiceLogDraft? draft =
      await showAppDialog<OperationsServiceLogDraft>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(context.l10n.operationsAddServiceLogAction),
      icon: const Icon(Icons.build_outlined),
      scrollable: true,
      maxWidth: 640,
      content: _ServiceLogForm(
        assets: state.assets.items,
        initialAssetId: state.selectedItem?.assetId,
      ),
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }

  final AppFailure? failure = await ref
      .read(operationsWorkspaceControllerProvider.notifier)
      .addServiceLog(draft);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

Future<void> _showNoteDialog(
  BuildContext context, {
  required String title,
  required String fieldLabel,
  required String submitLabel,
  required String kind,
  required OperationsWorkspaceController controller,
}) async {
  final String? note = await showAppDialog<String>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(title),
      icon: const Icon(Icons.edit_note_outlined),
      scrollable: true,
      maxWidth: 640,
      content: _NoteForm(fieldLabel: fieldLabel, submitLabel: submitLabel),
    ),
  );
  if (note == null || !context.mounted) {
    return;
  }

  final AppFailure? failure = await controller.appendSelectedNote(
    OperationsRequestNoteDraft(kind: kind, note: note),
  );
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

class _NoteForm extends StatefulWidget {
  const _NoteForm({required this.fieldLabel, required this.submitLabel});

  final String fieldLabel;
  final String submitLabel;

  @override
  State<_NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<_NoteForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _controller,
          labelText: widget.fieldLabel,
          isRequired: true,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          validator: AppValidators.requiredText(l10n.validationRequired),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: widget.submitLabel,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (validateAndSaveAppForm(_formKey)) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
        ),
      ],
    );
  }
}

Future<void> _showOperationsReportDialog(
  BuildContext context,
  OperationsWorkspaceState state,
) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => _OperationsReportDialog(state: state),
  );
}

Future<void> _showRequestReportDialog(
  BuildContext context,
  OperationsWorkspaceState state,
  OperationsWorkItem item,
) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => _OperationsReportDialog(state: state, item: item),
  );
}

class _OperationsReportDialog extends StatelessWidget {
  const _OperationsReportDialog({required this.state, this.item});

  final OperationsWorkspaceState state;
  final OperationsWorkItem? item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final OperationsWorkItem? request = item;

    return AppDialog(
      title: Text(l10n.operationsReportTitle),
      icon: const Icon(Icons.summarize_outlined),
      scrollable: true,
      maxWidth: 760,
      content: AppFormSection(
        children: <Widget>[
          AppReportSummaryGrid(
            records: <AppReportSummaryItem>[
              AppReportSummaryItem(
                label: l10n.operationsAllRequestsSummaryLabel,
                value: AppFormatters.compactNumber(
                  state.workItems.totalItemCount ?? state.workItems.items.length,
                  locale,
                ),
                icon: Icons.inventory_2_outlined,
              ),
              AppReportSummaryItem(
                label: l10n.operationsOpenSummaryLabel,
                value: AppFormatters.compactNumber(state.openCount, locale),
                icon: Icons.pending_actions_outlined,
              ),
              AppReportSummaryItem(
                label: l10n.operationsInProgressSummaryLabel,
                value: AppFormatters.compactNumber(state.inProgressCount, locale),
                icon: Icons.engineering_outlined,
              ),
              AppReportSummaryItem(
                label: l10n.operationsAssetsSummaryLabel,
                value: AppFormatters.compactNumber(state.assetCount, locale),
                icon: Icons.precision_manufacturing_outlined,
              ),
            ],
          ),
          AppReportPreviewPanel(
            title: l10n.operationsReportPreviewTitle,
            selectable: true,
            child: Text(_reportText(context, state, request)),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

List<AppListTableColumn<OperationsWorkItem>> _operationColumns(
  AppLocalizations l10n,
) {
  return <AppListTableColumn<OperationsWorkItem>>[
    AppListTableColumn<OperationsWorkItem>(
      label: l10n.operationsRequestColumnLabel,
      sortComparator: (OperationsWorkItem left, OperationsWorkItem right) =>
          appListTableCompareText(
        _issueLabel(l10n, left),
        _issueLabel(l10n, right),
      ),
      cellBuilder: (BuildContext context, OperationsWorkItem item) {
        return _TwoLineCell(
          title: _issueLabel(l10n, item),
          subtitle: item.effectiveDisplayId,
        );
      },
    ),
    AppListTableColumn<OperationsWorkItem>(
      label: l10n.operationsAreaColumnLabel,
      sortComparator: (OperationsWorkItem left, OperationsWorkItem right) =>
          appListTableCompareText(
        _categoryLabel(l10n, left.metadata.category),
        _categoryLabel(l10n, right.metadata.category),
      ),
      cellBuilder: (BuildContext context, OperationsWorkItem item) {
        return _TwoLineCell(
          title: _categoryLabel(l10n, item.metadata.category),
          subtitle: _display(item.assetLabel, item.assetId ?? ''),
        );
      },
    ),
    AppListTableColumn<OperationsWorkItem>(
      label: l10n.operationsPriorityColumnLabel,
      sortComparator: (OperationsWorkItem left, OperationsWorkItem right) =>
          appListTableCompareText(left.normalizedPriority, right.normalizedPriority),
      cellBuilder: (BuildContext context, OperationsWorkItem item) {
        return _OperationPriorityBadge(priority: item.metadata.priority);
      },
    ),
    AppListTableColumn<OperationsWorkItem>(
      label: l10n.operationsLocationColumnLabel,
      sortComparator: (OperationsWorkItem left, OperationsWorkItem right) =>
          appListTableCompareText(
        _locationLabel(l10n, left),
        _locationLabel(l10n, right),
      ),
      cellBuilder: (BuildContext context, OperationsWorkItem item) {
        return Text(_locationLabel(l10n, item));
      },
    ),
    AppListTableColumn<OperationsWorkItem>(
      label: l10n.operationsStatusColumnLabel,
      sortComparator: (OperationsWorkItem left, OperationsWorkItem right) =>
          appListTableCompareText(left.status, right.status),
      cellBuilder: (BuildContext context, OperationsWorkItem item) {
        return _OperationStatusBadge(status: item.status);
      },
    ),
  ];
}

List<AppListTableColumn<OperationsWorkItem>> _operationColumnChoices(
  AppLocalizations l10n,
) {
  return <AppListTableColumn<OperationsWorkItem>>[
    ..._operationColumns(l10n),
    AppListTableColumn<OperationsWorkItem>(
      label: l10n.operationsAssigneeColumnLabel,
      sortComparator: (OperationsWorkItem left, OperationsWorkItem right) =>
          appListTableCompareText(left.metadata.assignee, right.metadata.assignee),
      cellBuilder: (BuildContext context, OperationsWorkItem item) {
        return Text(_display(item.metadata.assignee, l10n.operationsUnassignedValue));
      },
    ),
    AppListTableColumn<OperationsWorkItem>(
      label: l10n.operationsDueColumnLabel,
      sortComparator: (OperationsWorkItem left, OperationsWorkItem right) =>
          appListTableCompareDateTime(left.dueAt, right.dueAt),
      cellBuilder: (BuildContext context, OperationsWorkItem item) {
        return Text(
          _formatDateTimeOrFallback(
            context,
            item.dueAt,
            l10n.operationsNoDueTimeValue,
          ),
        );
      },
    ),
    AppListTableColumn<OperationsWorkItem>(
      label: l10n.operationsNextActionColumnLabel,
      sortComparator: (OperationsWorkItem left, OperationsWorkItem right) =>
          appListTableCompareText(
        _nextActionLabel(l10n, left),
        _nextActionLabel(l10n, right),
      ),
      cellBuilder: (BuildContext context, OperationsWorkItem item) {
        return Text(_nextActionLabel(l10n, item));
      },
    ),
  ];
}

List<AppSearchBarFieldChoice> _operationsSearchFields(AppLocalizations l10n) {
  return <AppSearchBarFieldChoice>[
    AppSearchBarFieldChoice(
      field: 'request',
      label: l10n.operationsRequestColumnLabel,
      icon: Icons.confirmation_number_outlined,
    ),
    AppSearchBarFieldChoice(
      field: 'location',
      label: l10n.operationsLocationColumnLabel,
      icon: Icons.location_on_outlined,
    ),
    AppSearchBarFieldChoice(
      field: 'system',
      label: l10n.operationsAreaColumnLabel,
      icon: Icons.category_outlined,
    ),
    AppSearchBarFieldChoice(
      field: 'priority',
      label: l10n.operationsPriorityColumnLabel,
      icon: Icons.priority_high_outlined,
    ),
    AppSearchBarFieldChoice(
      field: 'status',
      label: l10n.operationsStatusColumnLabel,
      icon: Icons.fact_check_outlined,
    ),
    AppSearchBarFieldChoice(
      field: 'assignee',
      label: l10n.operationsAssigneeColumnLabel,
      icon: Icons.assignment_ind_outlined,
    ),
  ];
}

List<AppSearchBarTextFilter> _operationsTextFilters(AppLocalizations l10n) {
  return <AppSearchBarTextFilter>[
    AppSearchBarTextFilter(
      key: _operationsFacilityFilterKey,
      label: l10n.operationsFacilityFilterLabel,
      icon: Icons.business_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _operationsAssetFilterKey,
      label: l10n.operationsAssetFilterLabel,
      icon: Icons.precision_manufacturing_outlined,
      textInputAction: TextInputAction.done,
    ),
  ];
}

AppSearchBarFilterValue _operationsFilterValue(OperationsWorkItemQuery query) {
  return AppSearchBarFilterValue(
    dateFrom: query.reportedFrom,
    dateTo: query.reportedTo,
    texts: <String, String>{
      if (_hasValue(query.facilityId))
        _operationsFacilityFilterKey: query.facilityId!,
      if (_hasValue(query.assetId)) _operationsAssetFilterKey: query.assetId!,
    },
    options: <String, String>{
      if (_hasValue(query.status)) _operationsStatusFilterKey: query.status!,
      if (_hasValue(query.priority))
        _operationsPriorityFilterKey: query.priority!,
    },
  );
}

bool _hasOperationsFilters(OperationsWorkItemQuery query) {
  return _hasValue(query.status) ||
      _hasValue(query.priority) ||
      _hasValue(query.facilityId) ||
      _hasValue(query.assetId) ||
      query.reportedFrom != null ||
      query.reportedTo != null;
}

List<AppSearchBarFilterChoice> _statusFilterChoices(AppLocalizations l10n) {
  return <AppSearchBarFilterChoice>[
    for (final String status in operationsMaintenanceStatuses)
      AppSearchBarFilterChoice(
        value: status,
        label: _statusLabel(l10n, status),
        icon: _statusIcon(status),
      ),
  ];
}

List<AppSearchBarFilterChoice> _priorityFilterChoices(AppLocalizations l10n) {
  return <AppSearchBarFilterChoice>[
    for (final String priority in operationsRequestPriorities)
      AppSearchBarFilterChoice(
        value: priority,
        label: _priorityLabel(l10n, priority),
        icon: Icons.priority_high_outlined,
      ),
  ];
}

List<AppSelectOption<String>> _statusOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    for (final String status in operationsMaintenanceStatuses)
      AppSelectOption<String>(value: status, label: _statusLabel(l10n, status)),
  ];
}

List<AppSelectOption<String>> _priorityOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    for (final String priority in operationsRequestPriorities)
      AppSelectOption<String>(
        value: priority,
        label: _priorityLabel(l10n, priority),
      ),
  ];
}

List<AppSelectOption<String>> _categoryOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    for (final String category in operationsRequestCategories)
      AppSelectOption<String>(
        value: category,
        label: _categoryLabel(l10n, category),
      ),
  ];
}

List<AppSelectOption<String>> _assetOptions(
  List<OperationsAsset> assets,
  AppLocalizations l10n,
) {
  if (assets.isEmpty) {
    return <AppSelectOption<String>>[
      AppSelectOption<String>(
        value: '',
        label: l10n.operationsNoConfiguredAssetsOption,
        enabled: false,
      ),
    ];
  }

  return <AppSelectOption<String>>[
    for (final OperationsAsset asset in assets)
      AppSelectOption<String>(
        value: asset.effectiveDisplayId,
        label: asset.effectiveLabel,
      ),
  ];
}

String _statusLabel(AppLocalizations l10n, String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'OPEN' => l10n.operationsStatusOpen,
    'IN_PROGRESS' => l10n.operationsStatusInProgress,
    'COMPLETED' => l10n.operationsStatusCompleted,
    'CANCELLED' => l10n.operationsStatusCancelled,
    _ => l10n.operationsUnknownValue,
  };
}

String _priorityLabel(AppLocalizations l10n, String? priority) {
  return switch ((priority ?? '').trim().toUpperCase().replaceAll(' ', '_')) {
    'URGENT' => l10n.operationsPriorityUrgent,
    'HIGH' => l10n.operationsPriorityHigh,
    'NORMAL' => l10n.operationsPriorityNormal,
    'LOW' => l10n.operationsPriorityLow,
    _ => l10n.operationsPriorityNormal,
  };
}

String _categoryLabel(AppLocalizations l10n, String? category) {
  return switch ((category ?? '').trim().toUpperCase().replaceAll(' ', '_')) {
    'ELECTRICAL' => l10n.operationsCategoryElectrical,
    'PLUMBING' => l10n.operationsCategoryPlumbing,
    'WATER' => l10n.operationsCategoryWater,
    'POWER_BACKUP' => l10n.operationsCategoryPowerBackup,
    'HVAC' => l10n.operationsCategoryHvac,
    'GENERAL_ASSET' => l10n.operationsCategoryGeneralAsset,
    'SAFETY' => l10n.operationsCategorySafety,
    'OTHER' => l10n.operationsCategoryOther,
    _ => _display(category, l10n.operationsCategoryOther),
  };
}

AppWorkspaceStatusTone _statusTone(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'OPEN' => AppWorkspaceStatusTone.warning,
    'IN_PROGRESS' => AppWorkspaceStatusTone.info,
    'COMPLETED' => AppWorkspaceStatusTone.success,
    'CANCELLED' => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatusTone _priorityTone(String? priority) {
  return switch ((priority ?? '').trim().toUpperCase().replaceAll(' ', '_')) {
    'URGENT' => AppWorkspaceStatusTone.error,
    'HIGH' => AppWorkspaceStatusTone.warning,
    'LOW' => AppWorkspaceStatusTone.neutral,
    _ => AppWorkspaceStatusTone.info,
  };
}

IconData _statusIcon(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'OPEN' => Icons.pending_actions_outlined,
    'IN_PROGRESS' => Icons.engineering_outlined,
    'COMPLETED' => Icons.task_alt_outlined,
    'CANCELLED' => Icons.cancel_outlined,
    _ => Icons.radio_button_unchecked,
  };
}

String _nextActionLabel(AppLocalizations l10n, OperationsWorkItem item) {
  return switch (item.normalizedStatus) {
    'OPEN' => l10n.operationsNextActionAssign,
    'IN_PROGRESS' => _hasValue(item.assetId)
        ? l10n.operationsNextActionServiceLog
        : l10n.operationsNextActionUpdateStatus,
    'COMPLETED' => l10n.operationsNextActionCloseout,
    'CANCELLED' => l10n.operationsNextActionCancelled,
    _ => l10n.operationsNextActionReview,
  };
}

String _issueLabel(AppLocalizations l10n, OperationsWorkItem item) {
  return _display(item.metadata.issue, item.description ?? l10n.operationsUnknownValue);
}

String _locationLabel(AppLocalizations l10n, OperationsWorkItem item) {
  return _joinDisplay(<String>[
    _display(item.metadata.location, ''),
    _display(item.facilityLabel, item.facilityId ?? ''),
  ]).ifEmpty(l10n.operationsUnknownValue);
}

String _reportText(
  BuildContext context,
  OperationsWorkspaceState state,
  OperationsWorkItem? item,
) {
  final AppLocalizations l10n = context.l10n;
  final Locale locale = Localizations.localeOf(context);
  final StringBuffer buffer = StringBuffer()
    ..writeln(l10n.operationsReportTitle)
    ..writeln(l10n.operationsGeneratedAtLabel(
      AppFormatters.dateTime(DateTime.now(), locale),
    ))
    ..writeln()
    ..writeln(
      l10n.operationsReportSummaryLine(
        state.workItems.totalItemCount ?? state.workItems.items.length,
        state.openCount,
        state.inProgressCount,
        state.completedCount,
      ),
    );

  if (item != null) {
    buffer
      ..writeln()
      ..writeln(l10n.operationsRequestColumnLabel)
      ..writeln('${item.effectiveDisplayId} - ${_issueLabel(l10n, item)}')
      ..writeln('${l10n.operationsStatusColumnLabel}: ${_statusLabel(l10n, item.status)}')
      ..writeln('${l10n.operationsLocationColumnLabel}: ${_locationLabel(l10n, item)}')
      ..writeln('${l10n.operationsPriorityColumnLabel}: ${_priorityLabel(l10n, item.metadata.priority)}')
      ..writeln('${l10n.operationsNextActionColumnLabel}: ${_nextActionLabel(l10n, item)}');
  }

  return buffer.toString();
}

String _formatDateTimeOrFallback(
  BuildContext context,
  DateTime? value,
  String fallback,
) {
  return value == null
      ? fallback
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String _display(String? value, String fallback) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? fallback : normalized;
}

String _joinDisplay(Iterable<String> values) {
  return values
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

bool _hasValue(String? value) {
  return value != null && value.trim().isNotEmpty;
}

void _showMutationResult(BuildContext context, AppFailure? failure) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null
            ? context.l10n.operationsSavedMessage
            : context.l10n.failureMessage(failure),
      ),
    ),
  );
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null || !context.mounted) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

const String _operationsStatusFilterKey = 'status';
const String _operationsPriorityFilterKey = 'priority';
const String _operationsFacilityFilterKey = 'facility';
const String _operationsAssetFilterKey = 'asset';
const String _noteKindPartsVendor = 'PARTS_VENDOR';
const String _noteKindSafety = 'SAFETY';
const String _noteKindEvidence = 'EVIDENCE';
const String _noteKindHandover = 'HANDOVER';
const String _noteKindCloseout = 'CLOSEOUT';

extension on String {
  String ifEmpty(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}
