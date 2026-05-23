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
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
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
                return Text(
                  activeOrders == 1
                      ? '1 active order'
                      : '$activeOrders active orders',
                );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          order.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),
        if (order.displaySubtitle != null)
          Text(
            order.displaySubtitle!,
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

class _LabDetailPanel extends ConsumerWidget {
  const _LabDetailPanel({required this.state, required this.canMutate});

  final LabWorkspaceState state;
  final bool canMutate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final LabWorkspaceState currentState = ref
            .watch(labWorkspaceControllerProvider)
            .asData
            ?.value
            .when(
              success: (LabWorkspaceState value) => value,
              failure: (_) => state,
            ) ??
        state;
    final LabOrderWorkflow? workflow = currentState.selectedWorkflow;

    if (currentState.isRefreshingDetail) {
      return AppWorkspaceDetailPanel(
        title: l10n.labDetailTitle,
        child: AppWorkspaceStatePanel.loading(
          title: l10n.labDetailLoadingTitle,
          body: l10n.labDetailLoadingBody,
          minHeight: 240,
        ),
      );
    }

    if (workflow == null) {
      return AppWorkspaceDetailPanel(
        title: l10n.labDetailTitle,
        child: AppWorkspaceStatePanel.empty(
          title: l10n.labNoSelectionTitle,
          body: l10n.labNoSelectionBody,
          icon: Icons.science_outlined,
          minHeight: 240,
        ),
      );
    }

    final LabOrderSummary order = workflow.order;
    final String? encounterId = order.encounterId;
    final String? orderedAtLabel = _optionalDateTimeLabel(context, order.orderedAt);
    final bool hasVerifiableItems = workflow.verifiableItems.isNotEmpty;

    return AppWorkspaceDetailPanel(
      title: l10n.labDetailTitle,
      actions: <Widget>[
        if (canMutate && hasVerifiableItems)
          AppButton.primary(
            label: l10n.labVerifyAllAction,
            leadingIcon: Icons.verified_outlined,
            onPressed: () => _openVerifyAllDialog(context, workflow),
          ),
        if (canMutate && workflow.nextActions.canReverseWorkflow)
          AppIconButton(
            icon: Icons.undo_outlined,
            semanticLabel: l10n.labReverseWorkflowAction,
            tooltip: l10n.labReverseWorkflowAction,
            onPressed: () => _openReverseDialog(context),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppWorkspacePatientContextHeader(
            patientName: order.patientDisplayName ?? l10n.profileUnknownValue,
            patientNumber: order.patientId ?? '',
            patientNumberLabel: l10n.labPatientIdFieldLabel,
            semanticLabel: l10n.labPatientContextLabel,
            copyPatientNumberTooltip: l10n.copyIdentifierAction,
            copyPatientNumberMessage: l10n.identifierCopiedMessage,
            showPatientNumberCopyIcon: order.patientId != null && order.patientId!.trim().isNotEmpty,
            status: _orderStatus(context, order.status),
            alerts: <AppWorkspaceStatus>[
              if (order.hasCriticalResult)
                AppWorkspaceStatus(
                  label: l10n.labStatusCritical,
                  tone: AppWorkspaceStatusTone.error,
                  icon: Icons.priority_high_outlined,
                ),
              if (order.hasRejectedItem)
                AppWorkspaceStatus(
                  label: l10n.labStatusRejected,
                  tone: AppWorkspaceStatusTone.error,
                  icon: Icons.block_outlined,
                ),
            ],
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.labOrderFieldLabel,
                value: order.displayId ?? order.id,
                icon: Icons.tag_outlined,
                copyable: true,
                copyTooltip: l10n.copyIdentifierAction,
                copiedMessage: l10n.identifierCopiedMessage,
              ),
              if (encounterId != null && encounterId.trim().isNotEmpty)
                AppWorkspacePatientContextField(
                  label: l10n.labEncounterFieldLabel,
                  value: encounterId,
                  icon: Icons.medical_information_outlined,
                  copyable: true,
                  copyTooltip: l10n.opdCopyEncounterIdAction,
                  copiedMessage: l10n.opdEncounterIdCopiedMessage,
                ),
              if (orderedAtLabel != null)
                AppWorkspacePatientContextField(
                  label: l10n.labOrderedAtFieldLabel,
                  value: orderedAtLabel,
                  icon: Icons.event_outlined,
                ),
              AppWorkspacePatientContextField(
                label: l10n.labTestsColumnLabel,
                value: order.testsLabel ?? '',
                icon: Icons.science_outlined,
              ),
            ],
          ),
          _LabDetailSection(
            title: l10n.labItemsSectionTitle,
            child: _LabResultEntryList(
              workflow: workflow,
              canMutate: canMutate,
            ),
          ),
          if (workflow.results.isNotEmpty)
            _LabDetailSection(
              title: l10n.labResultsSectionTitle,
              child: _LabResultList(results: workflow.results),
            ),
          if (workflow.results.isNotEmpty)
            _LabDetailSection(
              title: l10n.labReportPreviewTitle,
              child: _LabReportPreview(workflow: workflow),
            ),
          _LabDetailSection(
            title: l10n.labTimelineSectionTitle,
            child: workflow.timeline.isEmpty
                ? _EmptyInlineText(text: l10n.labNoTimelineLabel)
                : _LabTimelineList(items: workflow.timeline),
          ),
        ],
      ),
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
    builder: (_) => AppDialog(
      title: Text(context.l10n.labDetailTitle),
      icon: const Icon(Icons.science_outlined),
      scrollable: true,
      maxWidth: 980,
      content: _LabDetailPanel(state: state, canMutate: canMutate),
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
                onPressed: () => Navigator.of(context).pop(order.orderIds[index]),
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

class _LabDetailSection extends StatelessWidget {
  const _LabDetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: theme.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Divider(height: 1),
          SizedBox(height: theme.spacing.md),
          Text(title, style: theme.textTheme.titleSmall),
          SizedBox(height: theme.spacing.sm),
          child,
        ],
      ),
    );
  }
}

class _LabResultEntryList extends StatelessWidget {
  const _LabResultEntryList({required this.workflow, required this.canMutate});

  final LabOrderWorkflow workflow;
  final bool canMutate;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<LabOrderItem> items = workflow.order.items;
    if (items.isEmpty) {
      return _EmptyInlineText(text: l10n.labNoOrderItemsLabel);
    }

    return Column(
      children: <Widget>[
        for (final LabOrderItem item in items)
          _LabResultEntryRow(item: item, canMutate: canMutate),
      ],
    );
  }
}

class _LabResultEntryRow extends StatelessWidget {
  const _LabResultEntryRow({required this.item, required this.canMutate});

  final LabOrderItem item;
  final bool canMutate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final String? subtitle = _joinDisplay(<String?>[
      item.testCode == null ? null : '${l10n.labTestCodeLabel}: ${item.testCode}',
      item.resultKind == null ? null : _apiLabel(item.resultKind!),
      item.unit,
      item.displayReferenceRange == null
          ? null
          : '${l10n.labReferenceRangeLabel}: ${item.displayReferenceRange}',
      item.isRejected ? '${l10n.labRejectReasonLabel}: ${item.rejectionReason}' : null,
    ]);
    final String? resultValue = item.displayResultValue;
    final AppWorkspaceStatus status = item.isRejected
        ? AppWorkspaceStatus(
            label: l10n.labStatusRejected,
            tone: AppWorkspaceStatusTone.error,
            icon: Icons.block_outlined,
          )
        : _statusBadge(context, item.effectiveResultStatus ?? item.status);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: EdgeInsets.only(top: theme.spacing.xs),
                    child: Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (resultValue != null)
                  Padding(
                    padding: EdgeInsets.only(top: theme.spacing.xs),
                    child: Text(
                      '${l10n.labReportResultLabel}: $resultValue',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Wrap(
            spacing: theme.spacing.xs,
            runSpacing: theme.spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              AppWorkspaceStatusBadge(status: status),
              if (canMutate && item.canVerify)
                AppButton.secondary(
                  label: l10n.labVerifyResultAction,
                  leadingIcon: Icons.verified_outlined,
                  onPressed: () => _openVerifyResultDialog(context, item),
                ),
              if (canMutate && item.canReject)
                AppIconButton(
                  icon: Icons.block_outlined,
                  semanticLabel: l10n.labRejectOrderItemAction,
                  tooltip: l10n.labRejectOrderItemAction,
                  onPressed: () => _openRejectOrderItemDialog(context, item),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LabResultList extends StatelessWidget {
  const _LabResultList({required this.results});

  final List<LabResult> results;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      children: <Widget>[
        for (final LabResult result in results)
          _CompactRecordRow(
            title: result.displayTitle,
            subtitle: _joinDisplay(<String?>[
              result.displayValue,
              result.referenceRangeSummary == null
                  ? null
                  : '${l10n.labReferenceRangeLabel}: ${result.referenceRangeSummary}',
              result.reportedAt == null
                  ? null
                  : '${l10n.labReportedAtLabel}: ${_dateTimeLabel(context, result.reportedAt)}',
            ]),
            trailing: AppWorkspaceStatusBadge(
              status: _statusBadge(context, result.status),
            ),
          ),
      ],
    );
  }
}

class _LabTimelineList extends StatelessWidget {
  const _LabTimelineList({required this.items});

  final List<LabWorkflowTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final LabWorkflowTimelineItem item in items)
          _CompactRecordRow(
            title: item.label ?? item.type ?? context.l10n.profileUnknownValue,
            subtitle: _dateTimeLabel(context, item.occurredAt),
            leading: Icons.timeline_outlined,
          ),
      ],
    );
  }
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

class _LabReportPreview extends StatelessWidget {
  const _LabReportPreview({required this.workflow});

  final LabOrderWorkflow workflow;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final LabOrderSummary order = workflow.order;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: AppReportActionButton.copy(
            label: l10n.labCopyReportAction,
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: _reportText(context, workflow)),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.labSavedMessage)));
              }
            },
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        AppReportPreviewPanel(
          title: l10n.labReportTitle,
          selectable: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _ReportLine(
                label: l10n.labReportPatientLabel,
                value: order.patientDisplayName,
              ),
              _ReportLine(
                label: l10n.labPatientIdFieldLabel,
                value: order.patientId,
              ),
              _ReportLine(
                label: l10n.labEncounterFieldLabel,
                value: order.encounterId,
              ),
              _ReportLine(
                label: l10n.labReportOrderLabel,
                value: order.displayId ?? order.id,
              ),
              _ReportLine(
                label: l10n.labOrderedAtFieldLabel,
                value: _optionalDateTimeLabel(context, order.orderedAt),
              ),
              const Divider(height: 24),
              for (final LabResult result in workflow.results)
                Padding(
                  padding: EdgeInsets.only(bottom: theme.spacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        result.displayTitle,
                        style: theme.textTheme.titleSmall,
                      ),
                      _ReportLine(
                        label: l10n.labTestCodeLabel,
                        value: result.testCode,
                      ),
                      _ReportLine(
                        label: l10n.labReportResultLabel,
                        value: result.displayValue,
                      ),
                      _ReportLine(
                        label: l10n.labReportRangeLabel,
                        value: result.referenceRangeSummary,
                      ),
                      _ReportLine(
                        label: l10n.labResultFlagLabel,
                        value: result.resultFlag ?? result.status,
                      ),
                      _ReportLine(
                        label: l10n.labReportVerifiedLabel,
                        value: _optionalDateTimeLabel(context, result.reportedAt),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 24),
              Text(
                l10n.labReportFooter,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportLine extends StatelessWidget {
  const _ReportLine({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(normalized, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}


final class _ResultDraft {
  _ResultDraft(this.item)
    : valueController = TextEditingController(text: item.resultValue ?? ''),
      unitController = TextEditingController(text: item.resultUnit ?? item.unit ?? ''),
      textController = TextEditingController(text: item.resultText ?? ''),
      notesController = TextEditingController(),
      selectedOption = item.resultText ?? item.resultValue;

  final LabOrderItem item;
  final TextEditingController valueController;
  final TextEditingController unitController;
  final TextEditingController textController;
  final TextEditingController notesController;
  String? selectedOption;

  void dispose() {
    valueController.dispose();
    unitController.dispose();
    textController.dispose();
    notesController.dispose();
  }

  Map<String, Object?> toPayload({bool includeOrderItemId = false}) {
    final String value = valueController.text.trim();
    final String unit = unitController.text.trim();
    final String text = textController.text.trim();
    final bool hasOption = selectedOption?.trim().isNotEmpty ?? false;
    final String? option = hasOption ? selectedOption!.trim() : null;
    final Map<String, Object?> payload = <String, Object?>{
      if (includeOrderItemId) 'order_item_id': item.apiId,
      'reported_at': DateTime.now().toIso8601String(),
      'notes': notesController.text.trim(),
    };

    if (item.isNumeric) {
      payload['result_value'] = value;
      payload['result_unit'] = unit;
      return payload;
    }
    if (item.isQualitative) {
      payload['result_text'] = option ?? text;
      return payload;
    }
    payload['result_text'] = text;
    return payload;
  }
}

class _ResultInputFields extends StatefulWidget {
  const _ResultInputFields({required this.draft, required this.enabled});

  final _ResultDraft draft;
  final bool enabled;

  @override
  State<_ResultInputFields> createState() => _ResultInputFieldsState();
}

class _ResultInputFieldsState extends State<_ResultInputFields> {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final LabOrderItem item = widget.draft.item;
    final List<Widget> inputs = <Widget>[
      _CompactRecordRow(
        title: item.displayTitle,
        subtitle: _joinDisplay(<String?>[
          item.resultKind == null ? null : _apiLabel(item.resultKind!),
          item.unit,
          item.displayReferenceRange == null
              ? null
              : '${l10n.labReferenceRangeLabel}: ${item.displayReferenceRange}',
        ]),
      ),
    ];

    if (item.isNumeric) {
      inputs.addAll(<Widget>[
        AppTextField(
          controller: widget.draft.valueController,
          labelText: l10n.labResultValueLabel,
          enabled: widget.enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String? value) {
            final String normalized = value?.trim() ?? '';
            if (normalized.isEmpty) {
              return l10n.validationRequired;
            }
            return num.tryParse(normalized) == null
                ? l10n.labNumericRangeValidationMessage
                : null;
          },
        ),
        if (item.unitOptions.isEmpty)
          AppTextField(
            controller: widget.draft.unitController,
            labelText: l10n.labResultUnitLabel,
            enabled: widget.enabled,
          )
        else
          AppSelectField<String>(
            value: widget.draft.unitController.text.trim().isEmpty
                ? null
                : widget.draft.unitController.text.trim(),
            labelText: l10n.labResultUnitLabel,
            enabled: widget.enabled,
            options: <AppSelectOption<String>>[
              for (final LabUnitOption option in item.unitOptions)
                AppSelectOption<String>(
                  value: option.unit ?? option.label ?? option.id,
                  label: option.displayLabel,
                ),
            ],
            onChanged: (String? value) {
              setState(() {
                widget.draft.unitController.text = value ?? '';
              });
            },
          ),
      ]);
    } else if (item.isQualitative && item.resultOptions.isNotEmpty) {
      inputs.add(
        AppSelectField<String>(
          value: widget.draft.selectedOption,
          labelText: l10n.labResultValueLabel,
          enabled: widget.enabled,
          validator: AppValidators.requiredValue(l10n.validationRequired),
          options: <AppSelectOption<String>>[
            for (final LabResultOption option in item.resultOptions)
              AppSelectOption<String>(
                value: option.value ?? option.label ?? option.id,
                label: option.displayLabel,
              ),
          ],
          onChanged: (String? value) {
            setState(() => widget.draft.selectedOption = value);
          },
        ),
      );
    } else {
      inputs.add(
        AppTextField(
          controller: widget.draft.textController,
          labelText: item.isQualitative
              ? l10n.labResultValueLabel
              : l10n.labResultTextLabel,
          enabled: widget.enabled,
          maxLines: item.isText ? 3 : 1,
          validator: AppValidators.requiredText(l10n.validationRequired),
        ),
      );
    }

    inputs.add(
      AppTextField(
        controller: widget.draft.notesController,
        labelText: l10n.labNotesLabel,
        enabled: widget.enabled,
        maxLines: 2,
      ),
    );

    return AppFormSection(children: inputs);
  }
}

class _VerifyResultDialog extends ConsumerStatefulWidget {
  const _VerifyResultDialog({required this.item});

  final LabOrderItem item;

  @override
  ConsumerState<_VerifyResultDialog> createState() => _VerifyResultDialogState();
}

class _VerifyResultDialogState extends ConsumerState<_VerifyResultDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final _ResultDraft _draft;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _draft = _ResultDraft(widget.item);
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.labVerifyResultDialogTitle),
      icon: const Icon(Icons.verified_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            _ResultInputFields(draft: _draft, enabled: !_isSaving),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.labVerifyResultAction,
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
        .verifyOrderItem(widget.item.apiId, _draft.toPayload());
    _finish(failure);
  }

  void _finish(AppFailure? failure) {
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class _VerifyAllResultsDialog extends ConsumerStatefulWidget {
  const _VerifyAllResultsDialog({required this.workflow});

  final LabOrderWorkflow workflow;

  @override
  ConsumerState<_VerifyAllResultsDialog> createState() =>
      _VerifyAllResultsDialogState();
}

class _VerifyAllResultsDialogState extends ConsumerState<_VerifyAllResultsDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final List<_ResultDraft> _drafts;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _drafts = widget.workflow.verifiableItems.map(_ResultDraft.new).toList();
  }

  @override
  void dispose() {
    for (final _ResultDraft draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.labVerifyAllDialogTitle),
      icon: const Icon(Icons.fact_check_outlined),
      scrollable: true,
      maxWidth: 760,
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            for (final _ResultDraft draft in _drafts) ...<Widget>[
              _ResultInputFields(draft: draft, enabled: !_isSaving),
              const Divider(height: 24),
            ],
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.labVerifyAllAction,
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
    final List<Map<String, Object?>> results = _drafts
        .map((_ResultDraft draft) => draft.toPayload(includeOrderItemId: true))
        .toList(growable: false);
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .verifyAllResults(widget.workflow.order.apiId, results);
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

class _RejectOrderItemDialog extends ConsumerStatefulWidget {
  const _RejectOrderItemDialog({required this.item});

  final LabOrderItem item;

  @override
  ConsumerState<_RejectOrderItemDialog> createState() =>
      _RejectOrderItemDialogState();
}

class _RejectOrderItemDialogState extends ConsumerState<_RejectOrderItemDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  late final TextEditingController _customReasonController;
  String? _reason;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _customReasonController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.labRejectOrderItemDialogTitle),
      icon: const Icon(Icons.block_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            _CompactRecordRow(title: widget.item.displayTitle),
            AppSelectField<String>(
              value: _reason,
              labelText: l10n.labRejectReasonLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: l10n.labRejectReasonNotPerformedHere,
                  label: l10n.labRejectReasonNotPerformedHere,
                ),
                AppSelectOption<String>(
                  value: l10n.labRejectReasonInsufficientInfo,
                  label: l10n.labRejectReasonInsufficientInfo,
                ),
                AppSelectOption<String>(
                  value: l10n.labRejectReasonInvalidRequest,
                  label: l10n.labRejectReasonInvalidRequest,
                ),
                AppSelectOption<String>(
                  value: 'OTHER',
                  label: l10n.labRejectReasonOther,
                ),
              ],
              onChanged: (String? value) => setState(() => _reason = value),
            ),
            if (_reason == 'OTHER')
              AppTextField(
                controller: _customReasonController,
                labelText: l10n.labRejectCustomReasonLabel,
                enabled: !_isSaving,
                validator: AppValidators.requiredText(l10n.validationRequired),
                maxLines: 2,
              ),
            AppTextField(
              controller: _notesController,
              labelText: l10n.labNotesLabel,
              enabled: !_isSaving,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.labRejectOrderItemAction,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String? reason = _reason == 'OTHER'
        ? _customReasonController.text.trim()
        : _reason;
    if (reason == null || reason.trim().isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .rejectOrderItem(widget.item.apiId, <String, Object?>{
          'reason': reason,
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

class _TestCatalogDialog extends StatelessWidget {
  const _TestCatalogDialog({required this.state});

  final LabWorkspaceState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return AppDialog(
      title: Text(l10n.labReferenceRangesDialogTitle),
      icon: const Icon(Icons.tune_outlined),
      scrollable: true,
      maxWidth: 820,
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
          if (state.catalogTests.isEmpty)
            _EmptyInlineText(text: l10n.labNoCatalogItemsLabel)
          else
            for (final LabCatalogItem item in state.catalogTests)
              _CompactRecordRow(
                title: item.displayTitle,
                subtitle: item.displaySubtitle,
                trailing: AppButton.secondary(
                  label: l10n.labConfigureTestAction,
                  leadingIcon: Icons.edit_outlined,
                  onPressed: () => _openLabTestConfigurationDialog(
                    context,
                    item,
                  ),
                ),
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
}

class _LabTestConfigurationDialog extends ConsumerStatefulWidget {
  const _LabTestConfigurationDialog({required this.item});

  final LabCatalogItem item;

  @override
  ConsumerState<_LabTestConfigurationDialog> createState() =>
      _LabTestConfigurationDialogState();
}

class _LabTestConfigurationDialogState
    extends ConsumerState<_LabTestConfigurationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _categoryController;
  late final TextEditingController _specimenController;
  late final TextEditingController _unitController;
  late final TextEditingController _unitOptionsController;
  late final TextEditingController _resultOptionsController;
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
  String? _resultKind;
  String? _gender;
  String? _ageUnit = 'YEARS';
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final LabCatalogItem item = widget.item;
    final LabReferenceRange? range = item.referenceRanges.isEmpty
        ? null
        : item.referenceRanges.first;
    _nameController = TextEditingController(text: item.name ?? '');
    _codeController = TextEditingController(text: item.code ?? '');
    _categoryController = TextEditingController(text: item.category ?? '');
    _specimenController = TextEditingController(text: item.specimenType ?? '');
    _unitController = TextEditingController(text: item.unit ?? '');
    _unitOptionsController = TextEditingController(
      text: item.unitOptions
          .map((LabUnitOption option) => option.unit ?? option.label ?? '')
          .where((String value) => value.trim().isNotEmpty)
          .join(', '),
    );
    _resultOptionsController = TextEditingController(
      text: item.resultOptions
          .map((LabResultOption option) => option.value ?? option.label ?? '')
          .where((String value) => value.trim().isNotEmpty)
          .join(', '),
    );
    _rangeLabelController = TextEditingController(text: range?.label ?? '');
    _ageMinController = TextEditingController(text: range?.ageMinValue?.toString() ?? '');
    _ageMaxController = TextEditingController(text: range?.ageMaxValue?.toString() ?? '');
    _rangeUnitController = TextEditingController(text: range?.unit ?? item.unit ?? '');
    _normalMinController = TextEditingController(text: range?.normalMinValue ?? '');
    _normalMaxController = TextEditingController(text: range?.normalMaxValue ?? '');
    _criticalMinController = TextEditingController(text: range?.criticalMinValue ?? '');
    _criticalMaxController = TextEditingController(text: range?.criticalMaxValue ?? '');
    _referenceTextController = TextEditingController(text: range?.referenceText ?? '');
    _rangeNotesController = TextEditingController(text: range?.notes ?? '');
    _resultKind = item.resultKind ?? 'NUMERIC';
    _gender = range?.gender;
    _ageUnit = range?.ageMinUnit ?? range?.ageMaxUnit ?? 'YEARS';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _categoryController.dispose();
    _specimenController.dispose();
    _unitController.dispose();
    _unitOptionsController.dispose();
    _resultOptionsController.dispose();
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
      title: Text(l10n.labConfigureTestDialogTitle),
      icon: const Icon(Icons.edit_outlined),
      scrollable: true,
      maxWidth: 760,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _nameController,
              labelText: l10n.labTestNameLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _codeController,
              labelText: l10n.labTestCodeLabel,
              enabled: !_isSaving,
            ),
            AppTextField(
              controller: _categoryController,
              labelText: l10n.labCategoryLabel,
              enabled: !_isSaving,
            ),
            AppTextField(
              controller: _specimenController,
              labelText: l10n.labSpecimenTypeLabel,
              enabled: !_isSaving,
            ),
            AppSelectField<String>(
              value: _resultKind,
              labelText: l10n.labResultKindLabel,
              enabled: !_isSaving,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(value: 'NUMERIC', label: l10n.labResultKindNumeric),
                AppSelectOption<String>(value: 'QUALITATIVE', label: l10n.labResultKindQualitative),
                AppSelectOption<String>(value: 'TEXT', label: l10n.labResultKindText),
              ],
              onChanged: (String? value) => setState(() => _resultKind = value),
            ),
            AppTextField(
              controller: _unitController,
              labelText: l10n.labDefaultUnitLabel,
              enabled: !_isSaving,
            ),
            AppTextField(
              controller: _unitOptionsController,
              labelText: l10n.labUnitOptionsLabel,
              helperText: l10n.labCommaSeparatedHelper,
              enabled: !_isSaving,
            ),
            AppTextField(
              controller: _resultOptionsController,
              labelText: l10n.labQualitativeOptionsLabel,
              helperText: l10n.labCommaSeparatedHelper,
              enabled: !_isSaving,
            ),
            const Divider(height: 24),
            AppTextField(
              controller: _rangeLabelController,
              labelText: l10n.labReferenceRangeLabel,
              enabled: !_isSaving,
            ),
            AppSelectField<String>(
              value: _gender,
              labelText: l10n.labGenderApplicabilityLabel,
              enabled: !_isSaving,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(value: 'ANY', label: l10n.labGenderAnyLabel),
                AppSelectOption<String>(value: 'MALE', label: l10n.labGenderMaleLabel),
                AppSelectOption<String>(value: 'FEMALE', label: l10n.labGenderFemaleLabel),
              ],
              onChanged: (String? value) => setState(() => _gender = value),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppTextField(
                    controller: _ageMinController,
                    labelText: l10n.labAgeMinLabel,
                    enabled: !_isSaving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _ageMaxController,
                    labelText: l10n.labAgeMaxLabel,
                    enabled: !_isSaving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            AppSelectField<String>(
              value: _ageUnit,
              labelText: l10n.labAgeUnitLabel,
              enabled: !_isSaving,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(value: 'DAYS', label: l10n.labAgeUnitDays),
                AppSelectOption<String>(value: 'MONTHS', label: l10n.labAgeUnitMonths),
                AppSelectOption<String>(value: 'YEARS', label: l10n.labAgeUnitYears),
              ],
              onChanged: (String? value) => setState(() => _ageUnit = value),
            ),
            AppTextField(
              controller: _rangeUnitController,
              labelText: l10n.labResultUnitLabel,
              enabled: !_isSaving,
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppTextField(
                    controller: _normalMinController,
                    labelText: l10n.labNormalMinLabel,
                    enabled: !_isSaving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _normalMaxController,
                    labelText: l10n.labNormalMaxLabel,
                    enabled: !_isSaving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppTextField(
                    controller: _criticalMinController,
                    labelText: l10n.labCriticalMinLabel,
                    enabled: !_isSaving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _criticalMaxController,
                    labelText: l10n.labCriticalMaxLabel,
                    enabled: !_isSaving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
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
      actions: _dialogActions(
        context,
        submitLabel: l10n.commonSaveActionLabel,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_rangesAreValid()) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .updateLabTest(widget.item.apiId, _payload());
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
    return _isRangeValid(_normalMinController.text, _normalMaxController.text) &&
        _isRangeValid(_criticalMinController.text, _criticalMaxController.text) &&
        _isRangeValid(_ageMinController.text, _ageMaxController.text);
  }

  bool _isRangeValid(String minValue, String maxValue) {
    final String minText = minValue.trim();
    final String maxText = maxValue.trim();
    if (minText.isEmpty || maxText.isEmpty) {
      return true;
    }
    final num? minNumber = num.tryParse(minText);
    final num? maxNumber = num.tryParse(maxText);
    return minNumber != null && maxNumber != null && minNumber <= maxNumber;
  }

  Map<String, Object?> _payload() {
    final String unit = _unitController.text.trim();
    return <String, Object?>{
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim(),
      'category': _categoryController.text.trim(),
      'specimen_type': _specimenController.text.trim(),
      'result_kind': _resultKind,
      'unit': unit,
      'unit_options': _commaSeparated(_unitOptionsController.text)
          .asMap()
          .entries
          .map((MapEntry<int, String> entry) => <String, Object?>{
                'unit': entry.value,
                'label': entry.value,
                'is_default': entry.key == 0,
                'sort_order': entry.key,
              })
          .toList(growable: false),
      'result_options': _commaSeparated(_resultOptionsController.text)
          .asMap()
          .entries
          .map((MapEntry<int, String> entry) => <String, Object?>{
                'value': entry.value,
                'label': entry.value,
                'status': 'NORMAL',
                'sort_order': entry.key,
              })
          .toList(growable: false),
      'reference_ranges': <Map<String, Object?>>[
        <String, Object?>{
          if (widget.item.referenceRanges.isNotEmpty)
            'id': widget.item.referenceRanges.first.id,
          'label': _rangeLabelController.text.trim(),
          'gender': _gender,
          'age_min_value': _ageMinController.text.trim(),
          'age_min_unit': _ageUnit,
          'age_max_value': _ageMaxController.text.trim(),
          'age_max_unit': _ageUnit,
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
        },
      ],
    };
  }

  List<String> _commaSeparated(String value) {
    return value
        .split(',')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
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


Future<void> _openTestCatalogDialog(
  BuildContext context,
  LabWorkspaceState state,
) async {
  await showAppDialog<void>(
    context: context,
    builder: (_) => _TestCatalogDialog(state: state),
  );
}

Future<void> _openLabTestConfigurationDialog(
  BuildContext context,
  LabCatalogItem item,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LabTestConfigurationDialog(item: item),
    ),
  );
}

Future<void> _openVerifyResultDialog(
  BuildContext context,
  LabOrderItem item,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VerifyResultDialog(item: item),
    ),
  );
}

Future<void> _openVerifyAllDialog(
  BuildContext context,
  LabOrderWorkflow workflow,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VerifyAllResultsDialog(workflow: workflow),
    ),
  );
}

Future<void> _openRejectOrderItemDialog(
  BuildContext context,
  LabOrderItem item,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RejectOrderItemDialog(item: item),
    ),
  );
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

Future<void> _openReverseDialog(BuildContext context) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ReverseWorkflowDialog(),
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
  if (order.completedItemCount > 0 && order.completedItemCount >= order.itemCount) {
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

String _dateTimeLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return context.l10n.profileUnknownValue;
  }
  return AppFormatters.dateTime(
    value.toLocal(),
    Localizations.localeOf(context),
  );
}

String? _optionalDateTimeLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return null;
  }
  return AppFormatters.dateTime(
    value.toLocal(),
    Localizations.localeOf(context),
  );
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

String _reportText(BuildContext context, LabOrderWorkflow workflow) {
  final AppLocalizations l10n = context.l10n;
  final LabOrderSummary order = workflow.order;
  final List<String> lines = <String>[
    l10n.labReportTitle,
    ..._reportTextLines(<String, String?>{
      l10n.labReportPatientLabel: order.patientDisplayName,
      l10n.labPatientIdFieldLabel: order.patientId,
      l10n.labEncounterFieldLabel: order.encounterId,
      l10n.labReportOrderLabel: order.displayId ?? order.id,
      l10n.labOrderedAtFieldLabel: _optionalDateTimeLabel(context, order.orderedAt),
    }),
    for (final LabResult result in workflow.results) ...<String>[
      '',
      result.displayTitle,
      ..._reportTextLines(<String, String?>{
        l10n.labTestCodeLabel: result.testCode,
        l10n.labReportResultLabel: result.displayValue,
        l10n.labReportRangeLabel: result.referenceRangeSummary,
        l10n.labResultFlagLabel: result.resultFlag ?? result.status,
        l10n.labReportVerifiedLabel: _optionalDateTimeLabel(context, result.reportedAt),
      }),
    ],
    '',
    l10n.labReportFooter,
  ];
  return lines.join('\n');
}

List<String> _reportTextLines(Map<String, String?> fields) {
  return <String>[
    for (final MapEntry<String, String?> entry in fields.entries)
      if ((entry.value ?? '').trim().isNotEmpty)
        '${entry.key}: ${entry.value!.trim()}',
  ];
}

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
  return joined.isEmpty ? null : joined;
}
