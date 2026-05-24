import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/presentation/controllers/radiology_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_radiology_order_action_dialog.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/print_form_template.dart';

typedef _RadiologyResultMutation =
    Future<AppFailure?> Function(
      RadiologyResult result,
      Map<String, Object?> payload,
    );

class RadiologyWorkspacePage extends ConsumerWidget {
  const RadiologyWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<RadiologyWorkspaceState>> workspace = ref.watch(
      radiologyWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<RadiologyWorkspaceState>(
      value: workspace,
      appBarTitle: l10n.radiologyTitle,
      loadingTitle: l10n.radiologyLoadingTitle,
      loadingBody: l10n.radiologyLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(radiologyWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, RadiologyWorkspaceState state) {
        return _RadiologyWorkspaceContent(state: state);
      },
    );
  }
}

class _RadiologyWorkspaceContent extends ConsumerStatefulWidget {
  const _RadiologyWorkspaceContent({required this.state});

  final RadiologyWorkspaceState state;

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

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<RadiologyOrder>();
  }

  @override
  void didUpdateWidget(covariant _RadiologyWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String search = widget.state.query.search;
    if (_searchController.text != search) {
      _searchController.value = TextEditingValue(text: search);
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final RadiologyWorkspaceState state = widget.state;
    final controller = ref.read(radiologyWorkspaceControllerProvider.notifier);
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canRequest = accessPolicy.grantsAny(const <AppPermission>[
      AppPermissions.clinicalWrite,
      AppPermissions.radiologyWrite,
    ]);
    final bool canWork = accessPolicy.grants(AppPermissions.radiologyWrite);
    final AppFailure? lastFailure = state.lastFailure;

    return AppWorkspace(
      title: l10n.radiologyTitle,
      leadingIcon: AppRouteIcons.radiology,
      status: AppWorkspaceStatus(
        label: state.isMutating
            ? l10n.radiologySavingStatus
            : l10n.radiologyLiveStatus,
        tone: state.isMutating
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
        icon: state.isMutating ? Icons.sync_outlined : Icons.sensors_outlined,
      ),
      primaryAction: canRequest
          ? AppButton.primary(
              label: l10n.radiologyRequestImagingAction,
              leadingIcon: Icons.add,
              enabled: !state.isMutating,
              onPressed: () => _showCreateOrderDialog(context, ref),
            )
          : null,
      secondaryActions: <Widget>[
        AppButton.secondary(
          label: state.query.view == RadiologyWorkbenchView.patients
              ? l10n.radiologyOrdersViewAction
              : l10n.radiologyPatientsViewAction,
          leadingIcon: Icons.swap_horiz_outlined,
          onPressed: state.isMutating
              ? null
              : () => controller.applyView(
                  state.query.view == RadiologyWorkbenchView.patients
                      ? RadiologyWorkbenchView.orders
                      : RadiologyWorkbenchView.patients,
                ),
        ),
        if (canWork)
          AppButton.secondary(
            label: l10n.radiologyConfigurationsAction,
            leadingIcon: Icons.tune_outlined,
            enabled: !state.isMutating,
            onPressed: state.isMutating
                ? null
                : () => _showRadiologyConfigurationsDialog(
                    context,
                    ref,
                    tenantId: accessPolicy.tenantId,
                  ),
          ),
        AppButton.secondary(
          label: l10n.commonRefreshActionLabel,
          leadingIcon: Icons.refresh,
          isLoading: state.isRefreshing,
          onPressed: state.isRefreshing ? null : controller.refresh,
        ),
      ],
      compactSummaryCards: true,
      summaryCards: <Widget>[
        if (state.summary.totalForView(state.query.view) > 0)
          AppWorkspaceSummaryCard(
            label: state.query.view == RadiologyWorkbenchView.patients
                ? l10n.radiologyPatientsSummaryLabel
                : l10n.radiologyTotalOrdersSummaryLabel,
            value: state.summary.totalForView(state.query.view).toString(),
            icon: Icons.assignment_outlined,
            compact: true,
            onPressed: controller.clearFilters,
          ),
        if (state.summary.orderedForView(state.query.view) > 0)
          AppWorkspaceSummaryCard(
            label: state.query.view == RadiologyWorkbenchView.patients
                ? l10n.radiologyPatientsWaitingImagingSummaryLabel
                : l10n.radiologyWaitingImagingSummaryLabel,
            value: state.summary.orderedForView(state.query.view).toString(),
            icon: Icons.pending_actions_outlined,
            tone: AppWorkspaceStatusTone.warning,
            compact: true,
            onPressed: () => controller.applyStage('ORDERED'),
          ),
        if (state.reportingCount > 0)
          AppWorkspaceSummaryCard(
            label: l10n.radiologyReportingSummaryLabel,
            value: state.reportingCount.toString(),
            icon: Icons.edit_note_outlined,
            tone: AppWorkspaceStatusTone.info,
            compact: true,
            onPressed: () => controller.applyStage('REPORTING'),
          ),
        if (state.releasedCount > 0)
          AppWorkspaceSummaryCard(
            label: l10n.radiologyReleasedSummaryLabel,
            value: state.releasedCount.toString(),
            icon: Icons.verified_outlined,
            tone: AppWorkspaceStatusTone.success,
            compact: true,
            onPressed: () => controller.applyStage('COMPLETED'),
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (lastFailure != null) ...<Widget>[
            AppFailureStateView(
              failure: lastFailure,
              onRetry: controller.refresh,
            ),
            SizedBox(height: Theme.of(context).spacing.md),
          ],
          _RadiologyOrderBoard(
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
    );
  }
}

class _RadiologyOrderBoard extends ConsumerWidget {
  const _RadiologyOrderBoard({
    required this.state,
    required this.canWork,
    required this.canRequest,
    required this.searchController,
    required this.columnVisibilityController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

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

    return AppWorkspaceDetailPanel(
      title: state.query.view == RadiologyWorkbenchView.patients
          ? l10n.radiologyPatientsWorklistTitle
          : l10n.radiologyWorklistTitle,
      description: state.query.view == RadiologyWorkbenchView.patients
          ? l10n.radiologyPatientsWorklistDescription
          : l10n.radiologyWorklistDescription,
      child: AppListTable<RadiologyOrder>(
        page: state.orders,
        isLoading: state.isRefreshing,
        columnVisibilityController: columnVisibilityController,
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        columnVisibilityTitle: l10n.radiologyTableColumnsTitle,
        columnVisibilityApplyLabel: l10n.radiologyApplyColumnsAction,
        columnVisibilityResetLabel: l10n.radiologyResetColumnsAction,
        columnVisibilityCancelLabel: l10n.commonCancelActionLabel,
        search: AppListTableSearch<RadiologyOrder>(
          controller: searchController,
          semanticLabel: l10n.radiologySearchLabel,
          hintText: l10n.radiologySearchHint,
          isLoading: state.isRefreshing,
          matcher: (_, _) => true,
          onChanged: onSearchChanged,
          onSubmitted: onSearchSubmitted,
          onClear: () {
            onSearchSubmitted('');
          },
          showAdvancedFilterButton: true,
          advancedFilterButtonLabel: l10n.radiologyFiltersLabel,
          advancedFilterTitle: l10n.radiologyFiltersLabel,
          advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
          advancedFilterResetLabel: l10n.radiologyClearFiltersAction,
          advancedFilterCancelLabel: l10n.commonCancelActionLabel,
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
        columns: <AppListTableColumn<RadiologyOrder>>[
          if (state.query.view == RadiologyWorkbenchView.orders)
            _radiologyOrderIdentifierColumn(l10n, state.query.view),
          _radiologyPatientColumn(l10n),
          if (state.query.view == RadiologyWorkbenchView.patients)
            _radiologyOrderIdentifierColumn(l10n, state.query.view),
          AppListTableColumn<RadiologyOrder>(
            id: 'study',
            label: l10n.radiologyStudyColumnLabel,
            sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
                appListTableCompareText(
                  left.testDisplayName ?? left.radiologyTestId,
                  right.testDisplayName ?? right.radiologyTestId,
                ),
            cellBuilder: (BuildContext context, RadiologyOrder item) {
              return _TwoLineCell(
                title:
                    item.testsSummary ??
                    item.testDisplayName ??
                    l10n.profileUnknownValue,
                subtitle: _joinDisplay(<String?>[
                  _modalityLabelOrNull(l10n, item.modality),
                  item.bodyRegion,
                  item.laterality,
                ]),
              );
            },
          ),
          AppListTableColumn<RadiologyOrder>(
            id: 'priority',
            label: l10n.radiologyPriorityColumnLabel,
            sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
                appListTableCompareText(left.priority, right.priority),
            cellBuilder: (BuildContext context, RadiologyOrder item) {
              return Text(_valueOrUnknown(context, item.priority));
            },
          ),
        ],
        columnChoices: <AppListTableColumn<RadiologyOrder>>[
          AppListTableColumn<RadiologyOrder>(
            id: 'billing',
            label: l10n.radiologyPaymentAuthColumnLabel,
            sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
                appListTableCompareText(
                  _billingGateLabel(context, left),
                  _billingGateLabel(context, right),
                ),
            cellBuilder: (BuildContext context, RadiologyOrder item) {
              return Text(_billingGateLabel(context, item));
            },
          ),
          AppListTableColumn<RadiologyOrder>(
            id: 'status',
            label: l10n.radiologyStatusColumnLabel,
            sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
                appListTableCompareText(left.status, right.status),
            cellBuilder: (BuildContext context, RadiologyOrder item) {
              return AppWorkspaceStatusBadge(
                status: _orderStatus(context, item),
              );
            },
          ),
          AppListTableColumn<RadiologyOrder>(
            id: 'modality',
            label: l10n.radiologyModalityLabel,
            sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
                appListTableCompareText(left.modality, right.modality),
            cellBuilder: (BuildContext context, RadiologyOrder item) {
              return Text(
                _valueOrUnknown(
                  context,
                  _modalityLabelOrNull(l10n, item.modality),
                ),
              );
            },
          ),
          AppListTableColumn<RadiologyOrder>(
            id: 'ordered_at',
            label: l10n.radiologyOrderedAtLabel,
            sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
                appListTableCompareDateTime(left.orderedAt, right.orderedAt),
            cellBuilder: (BuildContext context, RadiologyOrder item) {
              return Text(
                _valueOrUnknown(
                  context,
                  _formatDateTimeOrNull(context, item.orderedAt),
                ),
              );
            },
          ),
          AppListTableColumn<RadiologyOrder>(
            id: 'next_action',
            label: l10n.radiologyNextActionColumnLabel,
            sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
                appListTableCompareText(
                  _nextActionLabel(context, left),
                  _nextActionLabel(context, right),
                ),
            cellBuilder: (BuildContext context, RadiologyOrder item) {
              return Text(_nextActionLabel(context, item));
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, RadiologyOrder item) {
          return _RadiologyOrderListTile(order: item);
        },
      ),
    );
  }
}

class _RadiologyOrderListTile extends StatelessWidget {
  const _RadiologyOrderListTile({required this.order});

  final RadiologyOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.all(theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  order.patientDisplayName ?? l10n.profileUnknownValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              AppWorkspaceStatusBadge(status: _orderStatus(context, order)),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            _joinDisplay(<String?>[
              order.isPatientGroup
                  ? _activeOrderCountLabel(l10n, order.activeOrderCount)
                  : order.effectiveDisplayId,
              order.testsSummary ?? order.testDisplayName,
              _modalityLabelOrNull(l10n, order.modality),
            ]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            _nextActionLabel(context, order),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
      return AppWorkspaceDetailPanel(
        title: l10n.radiologyDetailTitle,
        child: AppWorkspaceStatePanel.loading(
          title: l10n.radiologyDetailLoadingTitle,
          body: l10n.radiologyDetailLoadingBody,
          minHeight: 360,
        ),
      );
    }

    if (workflow == null) {
      return AppWorkspaceDetailPanel(
        title: l10n.radiologyDetailTitle,
        child: AppWorkspaceStatePanel.empty(
          title: l10n.radiologyNoSelectionTitle,
          body: l10n.radiologyNoSelectionBody,
          icon: Icons.touch_app_outlined,
          minHeight: 360,
        ),
      );
    }

    return AppWorkspaceDetailPanel(
      title: l10n.radiologyDetailTitle,
      description: workflow.order.effectiveDisplayId,
      child: _RadiologyDetailBody(
        state: state,
        workflow: workflow,
        canWork: canWork,
        canRequest: canRequest,
      ),
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

class _RadiologyDetailBody extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final RadiologyOrder order = workflow.order;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppWorkspacePatientContextHeader(
          patientName: order.patientDisplayName ?? l10n.profileUnknownValue,
          patientNumber: '',
          semanticLabel: l10n.radiologyPatientContextLabel,
          status: _orderStatus(context, order),
          alerts: <AppWorkspaceStatus>[
            if (!order.hasBillingGate)
              AppWorkspaceStatus(
                label: l10n.radiologyBillingGateUnavailable,
                tone: AppWorkspaceStatusTone.warning,
                icon: Icons.receipt_long_outlined,
              ),
          ],
          actions: canWork
              ? <Widget>[
                  if (workflow.nextActions.canAssign)
                    AppButton.secondary(
                      label: l10n.radiologyAssignAction,
                      leadingIcon: Icons.person_add_alt_outlined,
                      isLoading: state.isMutating,
                      onPressed: () => _showAssignDialog(context, ref),
                    ),
                  if (workflow.nextActions.canStart)
                    AppButton.secondary(
                      label: l10n.radiologyStartImagingAction,
                      leadingIcon: Icons.play_arrow_outlined,
                      isLoading: state.isMutating,
                      onPressed: () => _submitNotesOnly(
                        context: context,
                        title: l10n.radiologyStartDialogTitle,
                        notesLabel: l10n.radiologyNotesLabel,
                        submitLabel: l10n.radiologyStartImagingAction,
                        submit: ref
                            .read(radiologyWorkspaceControllerProvider.notifier)
                            .startOrder,
                      ),
                    ),
                  if (workflow.nextActions.canCreateStudy)
                    AppButton.secondary(
                      label: l10n.radiologyPerformStudyAction,
                      leadingIcon: Icons.add_a_photo_outlined,
                      isLoading: state.isMutating,
                      onPressed: () => _showStudyDialog(context, ref, order),
                    ),
                  if (workflow.nextActions.canCancel)
                    AppButton.tertiary(
                      label: l10n.radiologyCancelOrderAction,
                      leadingIcon: Icons.cancel_outlined,
                      isLoading: state.isMutating,
                      onPressed: () => _showCancelDialog(context, ref),
                    ),
                ]
              : const <Widget>[],
        ),
        SizedBox(height: theme.spacing.md),
        _WorkflowSummarySection(order: order),
        SizedBox(height: theme.spacing.lg),
        _RequestSection(order: order, canEdit: canWork && !state.isMutating),
        SizedBox(height: theme.spacing.lg),
        _ReportingSection(state: state, workflow: workflow, canWork: canWork),
        SizedBox(height: theme.spacing.lg),
        _StudiesSection(state: state, workflow: workflow, canWork: canWork),
        SizedBox(height: theme.spacing.lg),
        _DoctorReviewPanel(order: order),
        SizedBox(height: theme.spacing.lg),
        _TimelineSection(workflow: workflow),
      ],
    );
  }
}

class _WorkflowSummarySection extends StatelessWidget {
  const _WorkflowSummarySection({required this.order});

  final RadiologyOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return _DetailSection(
      title: l10n.radiologyWorkflowSummaryTitle,
      children: <Widget>[
        _DetailLine(
          label: l10n.radiologyOrderedAtLabel,
          value: _formatDateTimeOrNull(context, order.orderedAt),
        ),
        _DetailLine(
          label: l10n.radiologyModalityLabel,
          value: _modalityLabelOrNull(l10n, order.modality),
        ),
        _DetailLine(
          label: l10n.radiologyPaymentLabel,
          value: order.paymentStatus,
        ),
        _DetailLine(
          label: l10n.radiologyAuthorizationLabel,
          value: order.authorizationStatus,
        ),
        if ((order.encounterId ?? '').trim().isNotEmpty)
          _DetailLine(
            label: l10n.radiologyEncounterLabel,
            value: order.encounterId,
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

    return _DetailSection(
      title: l10n.radiologyRequestDetailsTitle,
      actions: <Widget>[
        AppIconButton(
          icon: Icons.edit_outlined,
          semanticLabel: l10n.radiologyEditRequestDetailsAction,
          tooltip: l10n.radiologyEditRequestDetailsAction,
          onPressed: canEdit
              ? () => _showEditRequestDetailsDialog(context, ref, order)
              : null,
        ),
      ],
      children: <Widget>[
        _DetailLine(
          label: l10n.radiologyStudyLabel,
          value: order.testDisplayName,
        ),
        _DetailLine(label: l10n.radiologyPriorityLabel, value: order.priority),
        _DetailLine(
          label: l10n.radiologyBodyRegionLabel,
          value: order.bodyRegion,
        ),
        _DetailLine(
          label: l10n.radiologyLateralityLabel,
          value: order.laterality,
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
  final AppLocalizations l10n = context.l10n;
  final Map<String, Object?>? payload = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(l10n.radiologyEditRequestDetailsDialogTitle),
    content: _RequestDetailsEditForm(order: order),
    icon: const Icon(Icons.edit_outlined),
    maxWidth: 560,
  );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(radiologyWorkspaceControllerProvider.notifier)
      .updateOrderRequestDetails(payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

class _RequestDetailsEditForm extends StatefulWidget {
  const _RequestDetailsEditForm({required this.order});

  final RadiologyOrder order;

  @override
  State<_RequestDetailsEditForm> createState() => _RequestDetailsEditFormState();
}

class _RequestDetailsEditFormState extends State<_RequestDetailsEditForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _bodyRegionController;
  late final TextEditingController _notesController;
  String? _priority;
  String? _laterality;

  @override
  void initState() {
    super.initState();
    _priority = _trimmedOrNull(widget.order.priority);
    _laterality = _trimmedOrNull(widget.order.laterality);
    _bodyRegionController = TextEditingController(
      text: widget.order.bodyRegion ?? '',
    );
    _notesController = TextEditingController(
      text: widget.order.clinicalNote ?? '',
    );
  }

  @override
  void dispose() {
    _bodyRegionController.dispose();
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
          value: _priority,
          labelText: l10n.radiologyPriorityLabel,
          options: _radiologyPriorityOptions(l10n),
          onChanged: (String? value) => setState(() => _priority = value),
        ),
        AppTextField(
          controller: _bodyRegionController,
          labelText: l10n.radiologyBodyRegionLabel,
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
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.radiologySaveRequestDetailsAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'clinical_note': _trimmedOrNull(_notesController.text),
              'request_details': <String, Object?>{
                'priority': _priority,
                'body_region': _trimmedOrNull(_bodyRegionController.text),
                'laterality': _laterality,
              },
            });
          },
        ),
      ],
    );
  }
}

class _ReportingSection extends ConsumerWidget {
  const _ReportingSection({
    required this.state,
    required this.workflow,
    required this.canWork,
  });

  final RadiologyWorkspaceState state;
  final RadiologyWorkflow workflow;
  final bool canWork;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final RadiologyResult? latest = workflow.order.latestResult;
    final RadiologyResult? draft = workflow.order.latestDraftResult;
    final RadiologyResult? released = workflow.order.latestReleasedResult;
    final bool canDraft = canWork && workflow.nextActions.canCreateDraftResult;
    final bool canFinalize =
        canWork && workflow.nextActions.canFinalizeResult && draft != null;
    final bool canRequest =
        canWork && workflow.nextActions.canRequestFinalization && draft != null;
    final bool canAttest =
        canWork && workflow.nextActions.canAttestFinalization && draft != null;
    final bool canAddendum =
        canWork && workflow.nextActions.canAddAddendum && released != null;

    return AppWorkspaceDetailPanel(
      title: l10n.radiologyReportSectionTitle,
      description: l10n.radiologyReportSectionBody,
      actions: <Widget>[
        AppIconButton(
          icon: Icons.print_outlined,
          semanticLabel: l10n.radiologyPrintReportAction,
          tooltip: l10n.radiologyPrintReportAction,
          onPressed: state.isMutating
              ? null
              : () => _showRadiologyPrintDialog(context, workflow),
        ),
        if (canDraft)
          AppIconButton(
            icon: Icons.edit_note_outlined,
            semanticLabel: l10n.radiologyDraftReportAction,
            tooltip: l10n.radiologyDraftReportAction,
            onPressed: state.isMutating
                ? null
                : () => _showReportDialog(context, ref, workflow.order),
          ),
        if (canFinalize)
          AppIconButton(
            icon: Icons.verified_outlined,
            semanticLabel: l10n.radiologyReleaseReportAction,
            tooltip: l10n.radiologyReleaseReportAction,
            onPressed: state.isMutating
                ? null
                : () => _showFinalizeDialog(context, ref, draft),
          ),
        if (canRequest)
          AppIconButton(
            icon: Icons.how_to_reg_outlined,
            semanticLabel: l10n.radiologyRequestFinalizationAction,
            tooltip: l10n.radiologyRequestFinalizationAction,
            onPressed: state.isMutating
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
        if (canAttest)
          AppIconButton(
            icon: Icons.assignment_turned_in_outlined,
            semanticLabel: l10n.radiologyAttestFinalizationAction,
            tooltip: l10n.radiologyAttestFinalizationAction,
            onPressed: state.isMutating
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
        if (canAddendum)
          AppIconButton(
            icon: Icons.post_add_outlined,
            semanticLabel: l10n.radiologyAddendumAction,
            tooltip: l10n.radiologyAddendumAction,
            onPressed: state.isMutating
                ? null
                : () => _showAddendumDialog(context, ref, released),
          ),
      ],
      child: latest == null
          ? AppWorkspaceStatePanel.empty(
              title: l10n.radiologyNoReportTitle,
              body: l10n.radiologyNoReportBody,
              icon: Icons.description_outlined,
              minHeight: 180,
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
                AppReportPreviewPanel(
                  title: l10n.radiologyGeneratedReportPreviewTitle,
                  selectable: true,
                  child: Text(
                    latest.reportText ?? l10n.radiologyEmptyReportBody,
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
  });

  final RadiologyWorkspaceState state;
  final RadiologyWorkflow workflow;
  final bool canWork;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<ImagingStudy> studies = workflow.studies;

    return AppWorkspaceDetailPanel(
      title: l10n.radiologyStudiesAssetsTitle,
      description: l10n.radiologyStudiesAssetsBody,
      child: studies.isEmpty
          ? AppWorkspaceStatePanel.empty(
              title: l10n.radiologyNoStudiesTitle,
              body: l10n.radiologyNoStudiesBody,
              icon: Icons.image_search_outlined,
              minHeight: 180,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final ImagingStudy study in studies) ...<Widget>[
                  _StudyBlock(
                    study: study,
                    canSync:
                        canWork &&
                        state.isMutating == false &&
                        workflow.nextActions.canPacsSync &&
                        study.hasAssets,
                    onSync: () => _showPacsSyncDialog(context, ref, study),
                  ),
                  if (study != studies.last) SizedBox(height: theme.spacing.md),
                ],
              ],
            ),
    );
  }
}

class _StudyBlock extends StatelessWidget {
  const _StudyBlock({
    required this.study,
    required this.canSync,
    required this.onSync,
  });

  final ImagingStudy study;
  final bool canSync;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

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
              children: <Widget>[
                Expanded(
                  child: _TwoLineCell(
                    title: study.effectiveDisplayId,
                    subtitle: _joinDisplay(<String?>[
                      _modalityLabelOrNull(l10n, study.modality),
                      _formatDateTimeOrNull(context, study.performedAt),
                    ]),
                  ),
                ),
                AppButton.secondary(
                  label: l10n.radiologySyncPacsAction,
                  leadingIcon: Icons.cloud_sync_outlined,
                  enabled: canSync,
                  onPressed: canSync ? onSync : null,
                ),
              ],
            ),
            SizedBox(height: theme.spacing.md),
            Text(l10n.radiologyAssetsLabel, style: theme.textTheme.labelLarge),
            SizedBox(height: theme.spacing.xs),
            if (study.assets.isEmpty)
              Text(
                l10n.radiologyNoAssetsLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final ImagingAsset asset in study.assets)
                _DetailLine(
                  label: asset.displayId ?? l10n.profileUnknownValue,
                  value: _joinDisplay(<String?>[
                    asset.fileName,
                    asset.contentType,
                    asset.storageKey,
                  ]),
                ),
            SizedBox(height: theme.spacing.md),
            Text(
              l10n.radiologyPacsLinksLabel,
              style: theme.textTheme.labelLarge,
            ),
            SizedBox(height: theme.spacing.xs),
            if (study.pacsLinks.isEmpty)
              Text(
                l10n.radiologyNoPacsLinksLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final PacsLink link in study.pacsLinks)
                SelectableText(
                  link.url ?? link.displayId ?? l10n.profileUnknownValue,
                  style: theme.textTheme.bodyMedium,
                ),
            SizedBox(height: theme.spacing.md),
            // Backend upload initialization/commit routes exist, but the
            // frontend storage-provider binary transfer contract is not wired in
            // this workspace yet. Keep the attachment surface visible and
            // disabled instead of pretending files have been persisted.
            AppFileUploadPanel(
              title: l10n.radiologyAttachImagesTitle,
              emptyDescription: l10n.radiologyAttachImagesDisabledBody,
              chooseLabel: l10n.radiologyChooseImagesAction,
              clearLabel: l10n.radiologyClearSelectedImagesAction,
              fileNames: const <String>[],
              enabled: false,
              onChoose: () {},
              onClear: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorReviewPanel extends StatelessWidget {
  const _DoctorReviewPanel({required this.order});

  final RadiologyOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool released = order.hasFinalResult;

    return AppWorkspaceDetailPanel(
      title: l10n.radiologyDoctorReviewTitle,
      description: released
          ? l10n.radiologyDoctorReviewReleasedBody
          : l10n.radiologyDoctorReviewPendingBody,
      child: AppWorkspaceStatusBadge(
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
      child: workflow.timeline.isEmpty
          ? AppWorkspaceStatePanel.empty(
              title: l10n.radiologyNoTimelineTitle,
              body: l10n.radiologyNoTimelineBody,
              icon: Icons.timeline_outlined,
              minHeight: 160,
            )
          : AppWorkspaceActivityList(
              items: <AppWorkspaceActivityItem>[
                for (final RadiologyTimelineItem item in workflow.timeline)
                  AppWorkspaceActivityItem(
                    title: item.label,
                    subtitle: _formatDateTime(context, item.occurredAt),
                    icon: Icons.radio_button_checked,
                  ),
              ],
            ),
    );
  }
}

Future<void> _showCreateOrderDialog(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = context.l10n;
  final Map<String, Object?>? payload = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(l10n.radiologyCreateOrderDialogTitle),
    content: const _CreateOrderForm(),
    icon: const Icon(Icons.add_a_photo_outlined),
    maxWidth: 640,
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

    return AppFormShell(
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
              Text(
                l10n.radiologySelectAtLeastOneTestMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
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
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.radiologyRequestImagingAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
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
                    'request_details': <String, Object?>{
                      'modality': request.modality,
                      'body_region': request.bodyRegion,
                      'laterality': request.laterality,
                      'priority': request.priority,
                    },
                  },
              ],
            });
          },
        ),
      ],
    );
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
    final List<ClinicalActionCatalogOption> catalog = _radiologyCatalogOptions(
      state,
    );
    if (catalog.isEmpty) {
      setState(() => _selectionTouched = true);
      return;
    }
    List<ClinicalActionRadiologyRequest> selected =
        List<ClinicalActionRadiologyRequest>.of(_requests);
    final bool? updated = await showAppDialog<bool>(
      context: context,
      builder: (_) => ClinicalRadiologyOrderActionDialog(
        referenceData: ClinicalActionReferenceData(radiologyTests: catalog),
        initialRequests: _requests,
        onSubmit:
            ({required List<ClinicalActionRadiologyRequest> requests}) async {
              selected = requests;
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
            child: _TwoLineCell(
              title: title,
              subtitle: _joinDisplay(<String?>[
                _modalityLabelOrNull(l10n, request.modality),
                request.bodyRegion,
                request.laterality,
                request.priority,
                request.clinicalNote,
              ]),
            ),
          ),
          AppIconButton(
            icon: Icons.close,
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
  await ref
      .read(radiologyWorkspaceControllerProvider.notifier)
      .refreshConfigurations();
  if (!context.mounted) {
    return;
  }
  await showAppDialog<void>(
    context: context,
    builder: (_) => _RadiologyConfigurationsDialog(tenantId: tenantId),
  );
}

class _RadiologyConfigurationsDialog extends ConsumerStatefulWidget {
  const _RadiologyConfigurationsDialog({this.tenantId});

  final String? tenantId;

  @override
  ConsumerState<_RadiologyConfigurationsDialog> createState() =>
      _RadiologyConfigurationsDialogState();
}

class _RadiologyConfigurationsDialogState
    extends ConsumerState<_RadiologyConfigurationsDialog> {
  static const int _maxVisibleItems = 140;

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<RadiologyCatalogTest>
  _testColumnController =
      AppListTableColumnVisibilityController<RadiologyCatalogTest>();
  RadiologyWorkspaceState? _dialogState;

  @override
  void dispose() {
    _searchController.dispose();
    _testColumnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AsyncValue<Result<RadiologyWorkspaceState>> asyncState = ref.watch(
      radiologyWorkspaceControllerProvider,
    );
    final RadiologyWorkspaceState? latest = _stateFromAsync(asyncState);
    if (latest != null && _configurationStateChanged(_dialogState, latest)) {
      _dialogState = latest;
    }
    final RadiologyWorkspaceState? state = _dialogState ?? latest;
    final String query = _searchController.text;
    final List<RadiologyCatalogTest> tests = state == null
        ? const <RadiologyCatalogTest>[]
        : state.catalogTests
              .where((RadiologyCatalogTest test) => test.matchesSearch(query))
              .toList(growable: false);
    final bool isBusy = state?.isMutating == true || asyncState.isLoading;

    return AppDialog(
      title: Text(l10n.radiologyConfigurationsDialogTitle),
      icon: const Icon(Icons.tune_outlined),
      scrollable: true,
      maxWidth: 980,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.radiologyConfigurationsDialogBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          if (state == null && asyncState.isLoading)
            AppWorkspaceStatePanel.loading(
              title: l10n.radiologyConfigurationsLoadingTitle,
              body: l10n.radiologyConfigurationsLoadingBody,
              minHeight: 220,
            )
          else
            _buildTestsTable(context, tests, isBusy),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCloseActionLabel,
          onPressed: isBusy ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildTestsTable(
    BuildContext context,
    List<RadiologyCatalogTest> tests,
    bool isBusy,
  ) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return AppListTable<RadiologyCatalogTest>(
      items: tests,
      isLoading: isBusy,
      maxVisibleItems: _maxVisibleItems,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      columnVisibilityController: _testColumnController,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.radiologyTableColumnsTitle,
      columnVisibilityApplyLabel: l10n.radiologyApplyColumnsAction,
      columnVisibilityResetLabel: l10n.radiologyResetColumnsAction,
      columnVisibilityCancelLabel: l10n.commonCancelActionLabel,
      search: AppListTableSearch<RadiologyCatalogTest>(
        controller: _searchController,
        semanticLabel: l10n.radiologyConfigurationSearchLabel,
        hintText: l10n.radiologyConfigurationSearchHint,
        matcher: (RadiologyCatalogTest item, String query) =>
            item.matchesSearch(query),
        onChanged: (_) => setState(() {}),
        trailingActions: <AppSearchBarAction>[
          AppSearchBarAction(
            icon: Icons.add_circle_outline,
            label: l10n.radiologyCreateImagingTestAction,
            tooltip: l10n.radiologyCreateImagingTestAction,
            enabled: !isBusy,
            onPressed: isBusy
                ? null
                : () => _openRadiologyTestConfigurationDialog(
                    context,
                    tenantId: widget.tenantId,
                  ),
          ),
          AppSearchBarAction(
            icon: Icons.refresh_outlined,
            label: l10n.commonRefreshActionLabel,
            tooltip: l10n.commonRefreshActionLabel,
            enabled: !isBusy,
            onPressed: isBusy ? null : () => _refreshConfigurations(context),
          ),
        ],
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.radiologyNoImagingTestsTitle,
        body: l10n.radiologyNoImagingTestsBody,
        icon: Icons.image_search_outlined,
        minHeight: 180,
      ),
      columns: <AppListTableColumn<RadiologyCatalogTest>>[
        AppListTableColumn<RadiologyCatalogTest>(
          id: 'name',
          label: l10n.radiologyTestNameLabel,
          sortComparator:
              (RadiologyCatalogTest left, RadiologyCatalogTest right) =>
                  appListTableCompareText(left.name, right.name),
          cellBuilder: (_, RadiologyCatalogTest item) => _IconTwoLineCell(
            icon: _radiologyModalityIcon(item.modality),
            title: item.name,
            subtitle: _joinDisplay(<String?>[
              item.effectiveId,
              item.isStandard
                  ? l10n.radiologyStandardCatalogBadge
                  : l10n.radiologyCustomCatalogBadge,
            ]),
          ),
        ),
        AppListTableColumn<RadiologyCatalogTest>(
          id: 'code',
          label: l10n.radiologyTestCodeLabel,
          sortComparator:
              (RadiologyCatalogTest left, RadiologyCatalogTest right) =>
                  appListTableCompareText(left.code, right.code),
          cellBuilder: (_, RadiologyCatalogTest item) =>
              Text(item.code ?? l10n.profileUnknownValue),
        ),
        AppListTableColumn<RadiologyCatalogTest>(
          id: 'modality',
          label: l10n.radiologyModalityLabel,
          sortComparator:
              (RadiologyCatalogTest left, RadiologyCatalogTest right) =>
                  appListTableCompareText(left.modality, right.modality),
          cellBuilder: (_, RadiologyCatalogTest item) => _ModalityLabel(
            modality: item.modality,
          ),
        ),
        _testActionsColumn(context, isBusy),
      ],
      columnChoices: <AppListTableColumn<RadiologyCatalogTest>>[
        AppListTableColumn<RadiologyCatalogTest>(
          id: 'source',
          label: l10n.radiologySourceColumnLabel,
          cellBuilder: (_, RadiologyCatalogTest item) => Text(
            item.isStandard
                ? l10n.radiologyStandardCatalogBadge
                : l10n.radiologyCustomCatalogBadge,
          ),
        ),
        AppListTableColumn<RadiologyCatalogTest>(
          id: 'body_region',
          label: l10n.radiologyBodyRegionLabel,
          cellBuilder: (_, RadiologyCatalogTest item) =>
              Text(item.bodyRegion ?? l10n.profileUnknownValue),
        ),
        AppListTableColumn<RadiologyCatalogTest>(
          id: 'laterality',
          label: l10n.radiologyLateralityLabel,
          cellBuilder: (_, RadiologyCatalogTest item) =>
              Text(item.laterality ?? l10n.profileUnknownValue),
        ),
      ],
      mobileItemBuilder: (BuildContext context, RadiologyCatalogTest item) {
        return Padding(
          padding: EdgeInsets.all(theme.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _IconTwoLineCell(
                icon: _radiologyModalityIcon(item.modality),
                title: item.name,
                subtitle: _joinDisplay(<String?>[
                  item.code,
                  _modalityLabelOrNull(l10n, item.modality),
                  item.isStandard
                      ? l10n.radiologyStandardCatalogBadge
                      : l10n.radiologyCustomCatalogBadge,
                ]),
              ),
              SizedBox(height: theme.spacing.xs),
              _testActionButtons(context, item, isBusy),
            ],
          ),
        );
      },
    );
  }

  AppListTableColumn<RadiologyCatalogTest> _testActionsColumn(
    BuildContext context,
    bool isBusy,
  ) {
    final AppLocalizations l10n = context.l10n;
    return AppListTableColumn<RadiologyCatalogTest>(
      id: 'actions',
      label: l10n.radiologyActionColumnLabel,
      alwaysVisible: true,
      cellBuilder: (BuildContext context, RadiologyCatalogTest item) {
        return _testActionButtons(context, item, isBusy);
      },
    );
  }

  Widget _testActionButtons(
    BuildContext context,
    RadiologyCatalogTest item,
    bool isBusy,
  ) {
    final AppLocalizations l10n = context.l10n;
    return Wrap(
      spacing: Theme.of(context).spacing.xs,
      runSpacing: Theme.of(context).spacing.xs,
      children: <Widget>[
        if (item.isStandard)
          AppIconButton(
            icon: Icons.copy_outlined,
            semanticLabel: l10n.radiologyCopyStandardTestAction,
            tooltip: l10n.radiologyCopyStandardTestAction,
            onPressed: isBusy
                ? null
                : () => _openRadiologyTestConfigurationDialog(
                    context,
                    initial: item,
                    copyStandard: true,
                    tenantId: widget.tenantId,
                  ),
          )
        else ...<Widget>[
          AppIconButton(
            icon: Icons.edit_outlined,
            semanticLabel: l10n.radiologyEditImagingTestAction,
            tooltip: l10n.radiologyEditImagingTestAction,
            onPressed: isBusy
                ? null
                : () => _openRadiologyTestConfigurationDialog(
                    context,
                    initial: item,
                    tenantId: widget.tenantId,
                  ),
          ),
          AppIconButton(
            icon: Icons.delete_outline,
            semanticLabel: l10n.radiologyDeleteImagingTestAction,
            tooltip: l10n.radiologyDeleteImagingTestAction,
            onPressed: isBusy
                ? null
                : () => _openDeleteRadiologyTestDialog(context, item),
          ),
        ],
      ],
    );
  }

  Future<void> _refreshConfigurations(BuildContext context) async {
    final AppFailure? failure = await ref
        .read(radiologyWorkspaceControllerProvider.notifier)
        .refreshConfigurations(search: _searchController.text.trim());
    if (context.mounted) {
      _showFailureIfNeeded(context, failure);
    }
  }

  Future<void> _openRadiologyTestConfigurationDialog(
    BuildContext context, {
    RadiologyCatalogTest? initial,
    bool copyStandard = false,
    String? tenantId,
  }) async {
    await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RadiologyTestConfigurationDialog(
        initial: initial,
        copyStandard: copyStandard,
        tenantId: tenantId,
      ),
    );
  }

  Future<void> _openDeleteRadiologyTestDialog(
    BuildContext context,
    RadiologyCatalogTest test,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: Text(l10n.radiologyDeleteImagingTestDialogTitle),
        icon: const Icon(Icons.delete_outline),
        content: Text(l10n.radiologyDeleteImagingTestDialogBody(test.name)),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppButton.primary(
            label: l10n.radiologyDeleteImagingTestAction,
            leadingIcon: Icons.delete_outline,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final AppFailure? failure = await ref
        .read(radiologyWorkspaceControllerProvider.notifier)
        .deleteRadiologyTest(test.id);
    if (context.mounted) {
      _showMutationResult(context, failure);
    }
  }

  RadiologyWorkspaceState? _stateFromAsync(
    AsyncValue<Result<RadiologyWorkspaceState>> value,
  ) {
    return value.asData?.value.when(
      success: (RadiologyWorkspaceState state) => state,
      failure: (_) => null,
    );
  }

  bool _configurationStateChanged(
    RadiologyWorkspaceState? current,
    RadiologyWorkspaceState next,
  ) {
    return current == null ||
        current.catalogTests != next.catalogTests ||
        current.isMutating != next.isMutating ||
        current.isRefreshing != next.isRefreshing;
  }
}

class _RadiologyTestConfigurationDialog extends ConsumerStatefulWidget {
  const _RadiologyTestConfigurationDialog({
    this.initial,
    this.copyStandard = false,
    this.tenantId,
  });

  final RadiologyCatalogTest? initial;
  final bool copyStandard;
  final String? tenantId;

  @override
  ConsumerState<_RadiologyTestConfigurationDialog> createState() =>
      _RadiologyTestConfigurationDialogState();
}

class _RadiologyTestConfigurationDialogState
    extends ConsumerState<_RadiologyTestConfigurationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late String _modality;
  AppFailure? _failure;
  bool _isSaving = false;

  bool get _isCreate => widget.initial == null || widget.copyStandard;

  @override
  void initState() {
    super.initState();
    final RadiologyCatalogTest? initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _codeController = TextEditingController(
      text: widget.copyStandard ? '' : initial?.code ?? '',
    );
    final String normalized = (initial?.modality ?? 'XRAY')
        .trim()
        .toUpperCase();
    _modality = radiologyModalities.contains(normalized) ? normalized : 'OTHER';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool canSubmit =
        !_isSaving && (!_isCreate || widget.tenantId != null);
    return AppDialog(
      title: Text(
        _isCreate
            ? l10n.radiologyCreateImagingTestAction
            : l10n.radiologyEditImagingTestAction,
      ),
      icon: const Icon(Icons.image_search_outlined),
      scrollable: true,
      maxWidth: 560,
      closeEnabled: !_isSaving,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        formStatus: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.initial?.isStandard == true && widget.copyStandard)
              AppWorkspaceStatePanel.empty(
                title: l10n.radiologyReadOnlyStandardTestTitle,
                body: l10n.radiologyReadOnlyStandardTestMessage,
                icon: Icons.lock_outline,
                minHeight: 96,
              ),
            if (_isCreate && widget.tenantId == null)
              Text(
                l10n.radiologyTenantRequiredForConfigMessage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            if (_failure != null) AppFailureStateView(failure: _failure!),
          ],
        ),
        children: <Widget>[
          AppTextField(
            controller: _nameController,
            labelText: l10n.radiologyTestNameLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              l10n.radiologyFieldRequiredLabel(l10n.radiologyTestNameLabel),
            ),
          ),
          AppTextField(
            controller: _codeController,
            labelText: l10n.radiologyTestCodeOptionalLabel,
          ),
          AppSelectField<String>(
            value: _modality,
            labelText: l10n.radiologyModalityLabel,
            isRequired: true,
            options: <AppSelectOption<String>>[
              for (final String modality in radiologyModalities)
                AppSelectOption<String>(
                  value: modality,
                  label: _modalityLabel(l10n, modality),
                  leadingIcon: Icon(_radiologyModalityIcon(modality)),
                ),
            ],
            validator: AppValidators.requiredValue(
              l10n.radiologyFieldRequiredLabel(l10n.radiologyModalityLabel),
            ),
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _modality = value);
              }
            },
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.radiologySaveConfigurationAction,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSaving,
          enabled: canSubmit,
          onPressed: canSubmit ? _submit : null,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(validateAndSaveAppForm(_formKey))) {
      return;
    }
    if (_isCreate && widget.tenantId == null) {
      setState(() {
        _failure = AppFailure.validation();
      });
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final Map<String, Object?> payload = <String, Object?>{
      if (_isCreate) 'tenant_id': widget.tenantId,
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim(),
      'modality': _modality,
    };
    final AppFailure? failure = _isCreate
        ? await ref
              .read(radiologyWorkspaceControllerProvider.notifier)
              .createRadiologyTest(payload)
        : await ref
              .read(radiologyWorkspaceControllerProvider.notifier)
              .updateRadiologyTest(widget.initial!.id, payload);
    if (failure == null) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      return;
    }
    if (mounted) {
      setState(() {
        _failure = failure;
        _isSaving = false;
      });
    }
  }
}

Future<void> _showAssignDialog(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = context.l10n;
  final Map<String, Object?>? payload = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(l10n.radiologyAssignDialogTitle),
    content: const _AssignForm(),
    icon: const Icon(Icons.person_add_alt_outlined),
    maxWidth: 520,
  );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(radiologyWorkspaceControllerProvider.notifier)
      .assignOrder(payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

class _AssignForm extends ConsumerStatefulWidget {
  const _AssignForm();

  @override
  ConsumerState<_AssignForm> createState() => _AssignFormState();
}

class _AssignFormState extends ConsumerState<_AssignForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  String? _assigneeUserId;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final RadiologyWorkspaceState? state = _watchState(ref);

    return AppFormShell(
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
        AppTextField(
          controller: _notesController,
          labelText: l10n.radiologyNotesLabel,
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.radiologyAssignAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            Navigator.of(context).pop(<String, Object?>{
              'assignee_user_id': _assigneeUserId,
              'notes': _notesController.text.trim(),
            });
          },
        ),
      ],
    );
  }
}

Future<void> _showStudyDialog(
  BuildContext context,
  WidgetRef ref,
  RadiologyOrder order,
) async {
  final AppLocalizations l10n = context.l10n;
  final Map<String, Object?>? payload = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(l10n.radiologyPerformStudyDialogTitle),
    content: _StudyForm(order: order),
    icon: const Icon(Icons.add_a_photo_outlined),
    maxWidth: 520,
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

  @override
  State<_StudyForm> createState() => _StudyFormState();
}

class _StudyFormState extends State<_StudyForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _performedAtController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  late String _modality;

  @override
  void initState() {
    super.initState();
    final String normalized = widget.order.normalizedModality;
    _modality = radiologyModalities.contains(normalized) ? normalized : 'OTHER';
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

    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
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
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.radiologyPerformStudyAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            Navigator.of(context).pop(<String, Object?>{
              'modality': _modality,
              'performed_at': _performedAtController.text.trim(),
              'notes': _notesController.text.trim(),
            });
          },
        ),
      ],
    );
  }
}

Future<void> _showReportDialog(
  BuildContext context,
  WidgetRef ref,
  RadiologyOrder order,
) async {
  final AppLocalizations l10n = context.l10n;
  final Map<String, Object?>? payload = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(l10n.radiologyReportDialogTitle),
    content: _ReportForm(order: order),
    icon: const Icon(Icons.edit_note_outlined),
    maxWidth: 680,
  );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(radiologyWorkspaceControllerProvider.notifier)
      .draftResult(payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

class _ReportForm extends StatefulWidget {
  const _ReportForm({required this.order});

  final RadiologyOrder order;

  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _findingsController = TextEditingController();
  final TextEditingController _impressionController = TextEditingController();
  final TextEditingController _reportController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reportController.text = widget.order.latestDraftResult?.reportText ?? '';
  }

  @override
  void dispose() {
    _findingsController.dispose();
    _impressionController.dispose();
    _reportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<_RadiologyReportReference> references =
        _radiologyReportReferences(l10n, widget.order);

    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _findingsController,
          labelText: l10n.radiologyFindingsLabel,
          isRequired: true,
          maxLines: 5,
          validator: AppValidators.requiredText(
            l10n.radiologyFieldRequiredLabel(l10n.radiologyFindingsLabel),
          ),
        ),
        AppTextField(
          controller: _impressionController,
          labelText: l10n.radiologyImpressionLabel,
          maxLines: 4,
        ),
        AppTextField(
          controller: _reportController,
          labelText: l10n.radiologyReportTextLabel,
          helperText: l10n.radiologyReportTextHelper,
          maxLines: 7,
        ),
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
                  for (final _RadiologyReportReference reference in references)
                    AppButton.tertiary(
                      label: reference.label,
                      leadingIcon: reference.icon,
                      onPressed: () => _insertReference(reference.text),
                    ),
                ],
              ),
          ],
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.radiologyDraftReportAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'findings': _findingsController.text.trim(),
              'impression': _impressionController.text.trim(),
              'report_text': _reportController.text.trim(),
            });
          },
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

class _RadiologyReportReference {
  const _RadiologyReportReference({
    required this.label,
    required this.text,
    required this.icon,
  });

  final String label;
  final String text;
  final IconData icon;
}

List<_RadiologyReportReference> _radiologyReportReferences(
  AppLocalizations l10n,
  RadiologyOrder order,
) {
  final List<_RadiologyReportReference> references =
      <_RadiologyReportReference>[];
  for (final ImagingStudy study in order.imagingStudies) {
    for (final ImagingAsset asset in study.assets) {
      final String label =
          asset.fileName ??
          asset.displayId ??
          asset.storageKey ??
          study.effectiveDisplayId;
      references.add(
        _RadiologyReportReference(
          label: l10n.radiologyInsertAssetReferenceAction(label),
          text: '${l10n.radiologyAssetReferencePrefix}: $label',
          icon: Icons.image_outlined,
        ),
      );
    }
    for (final PacsLink link in study.pacsLinks) {
      final String label =
          link.url ?? link.displayId ?? study.effectiveDisplayId;
      references.add(
        _RadiologyReportReference(
          label: l10n.radiologyInsertPacsReferenceAction(label),
          text: '${l10n.radiologyPacsReferencePrefix}: $label',
          icon: Icons.cloud_outlined,
        ),
      );
    }
  }
  return references;
}

Future<void> _showRadiologyPrintDialog(
  BuildContext context,
  RadiologyWorkflow workflow,
) async {
  await showAppDialog<void>(
    context: context,
    builder: (_) => _RadiologyPrintDialog(workflow: workflow),
  );
}

class _RadiologyPrintDialog extends ConsumerStatefulWidget {
  const _RadiologyPrintDialog({required this.workflow});

  final RadiologyWorkflow workflow;

  @override
  ConsumerState<_RadiologyPrintDialog> createState() =>
      _RadiologyPrintDialogState();
}

class _RadiologyPrintDialogState extends ConsumerState<_RadiologyPrintDialog> {
  _RadiologyPrintSettings _settings = const _RadiologyPrintSettings();
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return AppDialog(
      title: Text(l10n.radiologyPrintReportDialogTitle),
      icon: const Icon(Icons.print_outlined),
      scrollable: true,
      maxWidth: 860,
      closeEnabled: !_isPrinting,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.radiologyPrintReportDialogBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          Wrap(
            spacing: theme.spacing.md,
            runSpacing: theme.spacing.sm,
            children: <Widget>[
              _printSwitch(
                context,
                label: l10n.radiologyPrintIncludeHeaderLabel,
                value: true,
                enabled: false,
                onChanged: null,
              ),
              _printSwitch(
                context,
                label: l10n.radiologyPrintIncludePatientLabel,
                value: _settings.includePatient,
                onChanged: (bool value) =>
                    _update(_settings.copyWith(includePatient: value)),
              ),
              _printSwitch(
                context,
                label: l10n.radiologyPrintIncludeOrderLabel,
                value: _settings.includeOrder,
                onChanged: (bool value) =>
                    _update(_settings.copyWith(includeOrder: value)),
              ),
              _printSwitch(
                context,
                label: l10n.radiologyPrintIncludeStudiesLabel,
                value: _settings.includeStudies,
                onChanged: (bool value) =>
                    _update(_settings.copyWith(includeStudies: value)),
              ),
              _printSwitch(
                context,
                label: l10n.radiologyPrintIncludeReportLabel,
                value: _settings.includeReport,
                onChanged: (bool value) =>
                    _update(_settings.copyWith(includeReport: value)),
              ),
              _printSwitch(
                context,
                label: l10n.radiologyPrintIncludeReferencesLabel,
                value: _settings.includeReferences,
                onChanged: (bool value) =>
                    _update(_settings.copyWith(includeReferences: value)),
              ),
              _printSwitch(
                context,
                label: l10n.radiologyPrintIncludeSignerLabel,
                value: _settings.includeSigner,
                onChanged: (bool value) =>
                    _update(_settings.copyWith(includeSigner: value)),
              ),
              _printSwitch(
                context,
                label: l10n.radiologyPrintIncludeMetadataLabel,
                value: _settings.includeMetadata,
                onChanged: (bool value) =>
                    _update(_settings.copyWith(includeMetadata: value)),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          AppReportPreviewPanel(
            title: l10n.radiologyPrintPreviewTitle,
            selectable: true,
            child: Text(
              _radiologyPrintPreviewText(context, widget.workflow, _settings),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCloseActionLabel,
          enabled: !_isPrinting,
          onPressed: _isPrinting ? null : () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: l10n.radiologyPrintAction,
          leadingIcon: Icons.print_outlined,
          isLoading: _isPrinting,
          onPressed: _isPrinting ? null : _print,
        ),
      ],
    );
  }

  Widget _printSwitch(
    BuildContext context, {
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool enabled = true,
  }) {
    return SizedBox(
      width: 250,
      child: SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  void _update(_RadiologyPrintSettings settings) {
    setState(() => _settings = settings);
  }

  Future<void> _print() async {
    setState(() => _isPrinting = true);
    await printFormTemplateDocument(
      ref: ref,
      context: context,
      title: context.l10n.radiologyPrintReportTitle,
      subtitle: widget.workflow.order.patientDisplayName,
      bodyHtml: _radiologyPrintBodyHtml(context, widget.workflow, _settings),
      metadata: _settings.includeMetadata
          ? _radiologyPrintMetadata(context, widget.workflow)
          : const <PrintFormMetadataItem>[],
      footerNote: context.l10n.radiologyPrintFooterNote,
    );
    if (mounted) {
      setState(() => _isPrinting = false);
    }
  }
}

@immutable
final class _RadiologyPrintSettings {
  const _RadiologyPrintSettings({
    this.includePatient = true,
    this.includeOrder = true,
    this.includeStudies = true,
    this.includeReport = true,
    this.includeReferences = true,
    this.includeSigner = true,
    this.includeMetadata = false,
  });

  final bool includePatient;
  final bool includeOrder;
  final bool includeStudies;
  final bool includeReport;
  final bool includeReferences;
  final bool includeSigner;
  final bool includeMetadata;

  _RadiologyPrintSettings copyWith({
    bool? includePatient,
    bool? includeOrder,
    bool? includeStudies,
    bool? includeReport,
    bool? includeReferences,
    bool? includeSigner,
    bool? includeMetadata,
  }) {
    return _RadiologyPrintSettings(
      includePatient: includePatient ?? this.includePatient,
      includeOrder: includeOrder ?? this.includeOrder,
      includeStudies: includeStudies ?? this.includeStudies,
      includeReport: includeReport ?? this.includeReport,
      includeReferences: includeReferences ?? this.includeReferences,
      includeSigner: includeSigner ?? this.includeSigner,
      includeMetadata: includeMetadata ?? this.includeMetadata,
    );
  }
}

List<PrintFormMetadataItem> _radiologyPrintMetadata(
  BuildContext context,
  RadiologyWorkflow workflow,
) {
  final AppLocalizations l10n = context.l10n;
  final RadiologyOrder order = workflow.order;
  return <PrintFormMetadataItem>[
    PrintFormMetadataItem(
      label: l10n.radiologyOrderColumnLabel,
      value: order.effectiveDisplayId,
    ),
    PrintFormMetadataItem(
      label: l10n.radiologyStatusColumnLabel,
      value: _orderStatusLabel(l10n, order.status),
    ),
    PrintFormMetadataItem(
      label: l10n.radiologyModalityLabel,
      value: _modalityLabelOrNull(l10n, order.modality) ?? '',
    ),
  ];
}

String _radiologyPrintBodyHtml(
  BuildContext context,
  RadiologyWorkflow workflow,
  _RadiologyPrintSettings settings,
) {
  final AppLocalizations l10n = context.l10n;
  final RadiologyOrder order = workflow.order;
  final RadiologyResult? result = order.latestResult;
  final List<String> sections = <String>[];

  if (settings.includePatient) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.radiologyPrintPatientSectionTitle,
        bodyHtml: PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
          PrintFormMetadataItem(
            label: l10n.radiologyPatientLabel,
            value: order.patientDisplayName ?? l10n.profileUnknownValue,
          ),
          PrintFormMetadataItem(
            label: l10n.radiologyPatientIdLabel,
            value: order.patientId ?? l10n.profileUnknownValue,
          ),
        ]),
      ),
    );
  }
  if (settings.includeOrder) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.radiologyPrintOrderSectionTitle,
        bodyHtml: PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
          PrintFormMetadataItem(
            label: l10n.radiologyOrderColumnLabel,
            value: order.effectiveDisplayId,
          ),
          PrintFormMetadataItem(
            label: l10n.radiologyEncounterLabel,
            value: order.encounterId ?? l10n.profileUnknownValue,
          ),
          PrintFormMetadataItem(
            label: l10n.radiologyModalityLabel,
            value:
                _modalityLabelOrNull(l10n, order.modality) ??
                l10n.profileUnknownValue,
          ),
          PrintFormMetadataItem(
            label: l10n.radiologyStudyLabel,
            value:
                order.testsSummary ??
                order.testDisplayName ??
                l10n.profileUnknownValue,
          ),
          PrintFormMetadataItem(
            label: l10n.radiologyPriorityLabel,
            value: order.priority ?? l10n.profileUnknownValue,
          ),
          PrintFormMetadataItem(
            label: l10n.radiologyOrderedAtLabel,
            value:
                _formatDateTimeOrNull(context, order.orderedAt) ??
                l10n.profileUnknownValue,
          ),
          PrintFormMetadataItem(
            label: l10n.radiologyClinicalNotesLabel,
            value: order.clinicalNote ?? '',
          ),
        ]),
      ),
    );
  }
  if (settings.includeStudies) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.radiologyPrintStudiesSectionTitle,
        bodyHtml: _radiologyPrintStudiesHtml(context, workflow),
        avoidPageBreak: true,
      ),
    );
  }
  if (settings.includeReport) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.radiologyPrintReportSectionTitle,
        bodyHtml: _printParagraph(
          result?.reportText ?? l10n.radiologyEmptyReportBody,
        ),
      ),
    );
  }
  if (settings.includeReferences) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.radiologyPrintReferencesSectionTitle,
        bodyHtml: PrintFormTemplate.unorderedList(
          _radiologyReferenceStrings(workflow),
          emptyText: l10n.radiologyNoReportReferencesLabel,
        ),
        avoidPageBreak: true,
      ),
    );
  }
  if (settings.includeSigner) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.radiologyPrintSignerSectionTitle,
        bodyHtml: _radiologySignerHtml(context, result),
        avoidPageBreak: true,
      ),
    );
  }
  if (sections.isEmpty) {
    return _printParagraph(l10n.radiologyPrintNoSectionsSelected);
  }
  return sections.join('\n');
}

String _radiologyPrintStudiesHtml(
  BuildContext context,
  RadiologyWorkflow workflow,
) {
  final AppLocalizations l10n = context.l10n;
  final RadiologyOrder order = workflow.order;
  final List<List<String>> requestedRows = order.requestedTests.isEmpty
      ? <List<String>>[
          <String>[
            order.testDisplayName ??
                order.radiologyTestId ??
                l10n.profileUnknownValue,
            _modalityLabelOrNull(l10n, order.modality) ??
                l10n.profileUnknownValue,
            order.bodyRegion ?? l10n.profileUnknownValue,
            order.laterality ?? l10n.profileUnknownValue,
          ],
        ]
      : <List<String>>[
          for (final RadiologyRequestedTest test in order.requestedTests)
            <String>[
              test.testDisplayName ??
                  test.radiologyTestId ??
                  l10n.profileUnknownValue,
              _modalityLabelOrNull(l10n, test.modality) ??
                  l10n.profileUnknownValue,
              test.bodyRegion ?? l10n.profileUnknownValue,
              test.laterality ?? l10n.profileUnknownValue,
            ],
        ];
  final String testsTable = PrintFormTemplate.table(
    headers: <String>[
      l10n.radiologyStudyLabel,
      l10n.radiologyModalityLabel,
      l10n.radiologyBodyRegionLabel,
      l10n.radiologyLateralityLabel,
    ],
    rows: requestedRows,
    emptyText: l10n.radiologyNoStudiesBody,
  );
  final String studiesTable = PrintFormTemplate.table(
    headers: <String>[
      l10n.radiologyStudyLabel,
      l10n.radiologyModalityLabel,
      l10n.radiologyPerformedAtLabel,
      l10n.radiologyAssetsLabel,
    ],
    rows: <List<String>>[
      for (final ImagingStudy study in workflow.studies)
        <String>[
          study.effectiveDisplayId,
          _modalityLabelOrNull(l10n, study.modality) ??
              l10n.profileUnknownValue,
          _formatDateTimeOrNull(context, study.performedAt) ??
              l10n.profileUnknownValue,
          study.assetCount.toString(),
        ],
    ],
    emptyText: l10n.radiologyNoStudiesBody,
  );
  return '$testsTable\n$studiesTable';
}

String _radiologySignerHtml(BuildContext context, RadiologyResult? result) {
  final AppLocalizations l10n = context.l10n;
  if (result == null) {
    return _printParagraph(l10n.radiologyNoReportBody);
  }
  return PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
    PrintFormMetadataItem(
      label: l10n.radiologyReportedAtLabel,
      value:
          _formatDateTimeOrNull(context, result.reportedAt) ??
          l10n.profileUnknownValue,
    ),
    PrintFormMetadataItem(
      label: l10n.radiologyStatusColumnLabel,
      value: _resultStatusLabel(l10n, result.status),
    ),
    PrintFormMetadataItem(
      label: l10n.radiologyFinalizationRequestedLabel,
      value: result.finalization.requested
          ? l10n.commonYesLabel
          : l10n.commonNoLabel,
    ),
    PrintFormMetadataItem(
      label: l10n.radiologyFinalizationAttestedLabel,
      value: result.finalization.attested
          ? l10n.commonYesLabel
          : l10n.commonNoLabel,
    ),
  ]);
}

Iterable<String> _radiologyReferenceStrings(RadiologyWorkflow workflow) sync* {
  for (final ImagingStudy study in workflow.studies) {
    for (final ImagingAsset asset in study.assets) {
      yield _joinDisplay(<String?>[
        asset.fileName,
        asset.displayId,
        asset.contentType,
        study.effectiveDisplayId,
      ]);
    }
    for (final PacsLink link in study.pacsLinks) {
      yield _joinDisplay(<String?>[
        link.url,
        link.displayId,
        study.effectiveDisplayId,
      ]);
    }
  }
}

String _radiologyPrintPreviewText(
  BuildContext context,
  RadiologyWorkflow workflow,
  _RadiologyPrintSettings settings,
) {
  final AppLocalizations l10n = context.l10n;
  final RadiologyOrder order = workflow.order;
  final StringBuffer buffer = StringBuffer();
  buffer.writeln(l10n.radiologyPrintReportTitle);
  buffer.writeln(
    _joinDisplay(<String?>[
      order.patientDisplayName,
      order.effectiveDisplayId,
      order.testDisplayName ?? order.testsSummary,
    ]),
  );
  if (settings.includePatient) {
    buffer
      ..writeln('\n${l10n.radiologyPrintPatientSectionTitle}')
      ..writeln(order.patientDisplayName ?? l10n.profileUnknownValue)
      ..writeln(order.patientId ?? l10n.profileUnknownValue);
  }
  if (settings.includeOrder) {
    buffer
      ..writeln('\n${l10n.radiologyPrintOrderSectionTitle}')
      ..writeln(
        _joinDisplay(<String?>[
          order.effectiveDisplayId,
          _orderStatusLabel(l10n, order.status),
          _modalityLabelOrNull(l10n, order.modality),
        ]),
      );
  }
  if (settings.includeStudies) {
    buffer
      ..writeln('\n${l10n.radiologyPrintStudiesSectionTitle}')
      ..writeln(
        order.testsSummary ?? order.testDisplayName ?? l10n.profileUnknownValue,
      )
      ..writeln(l10n.radiologyPrintStudyCount(workflow.studies.length));
  }
  if (settings.includeReport) {
    buffer
      ..writeln('\n${l10n.radiologyPrintReportSectionTitle}')
      ..writeln(
        workflow.order.latestResult?.reportText ??
            l10n.radiologyEmptyReportBody,
      );
  }
  if (settings.includeReferences) {
    buffer
      ..writeln('\n${l10n.radiologyPrintReferencesSectionTitle}')
      ..writeln(
        _radiologyReferenceStrings(
          workflow,
        ).join('\n').ifEmpty(l10n.radiologyNoReportReferencesLabel),
      );
  }
  if (settings.includeSigner) {
    buffer
      ..writeln('\n${l10n.radiologyPrintSignerSectionTitle}')
      ..writeln(
        workflow.order.latestResult == null
            ? l10n.radiologyNoReportBody
            : _resultStatusLabel(l10n, workflow.order.latestResult!.status),
      );
  }
  if (settings.includeMetadata) {
    buffer
      ..writeln('\n${l10n.radiologyPrintIncludeMetadataLabel}')
      ..writeln(
        _radiologyPrintMetadata(context, workflow)
            .map(
              (PrintFormMetadataItem item) =>
                  '${item.label}: ${item.value}',
            )
            .join('\n'),
      );
  }
  return buffer.toString().trim();
}

String _printParagraph(String text) {
  final String escaped = PrintFormTemplate.escape(
    text.trim(),
  ).replaceAll('\n', '<br>');
  return '<p>$escaped</p>';
}

Future<void> _showFinalizeDialog(
  BuildContext context,
  WidgetRef ref,
  RadiologyResult result,
) async {
  final AppLocalizations l10n = context.l10n;
  final Map<String, Object?>? payload = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(l10n.radiologyReleaseReportDialogTitle),
    content: _FinalizeReportForm(result: result),
    icon: const Icon(Icons.verified_outlined),
    maxWidth: 620,
  );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(radiologyWorkspaceControllerProvider.notifier)
      .finalizeResult(result, payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}

class _FinalizeReportForm extends StatefulWidget {
  const _FinalizeReportForm({required this.result});

  final RadiologyResult result;

  @override
  State<_FinalizeReportForm> createState() => _FinalizeReportFormState();
}

class _FinalizeReportFormState extends State<_FinalizeReportForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _reportController;
  final TextEditingController _notesController = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _reportController,
          labelText: l10n.radiologyReportTextLabel,
          isRequired: true,
          maxLines: 8,
          validator: AppValidators.requiredText(
            l10n.radiologyFieldRequiredLabel(l10n.radiologyReportTextLabel),
          ),
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.radiologyReleaseNotesLabel,
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.radiologyReleaseReportAction,
          submitIcon: Icons.verified_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'report_text': _reportController.text.trim(),
              'notes': _notesController.text.trim(),
            });
          },
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
  final Map<String, Object?>? payload = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(title),
    content: _FinalizationNoteForm(submitLabel: submitLabel),
    icon: const Icon(Icons.how_to_reg_outlined),
    maxWidth: 560,
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
  const _FinalizationNoteForm({required this.submitLabel});

  final String submitLabel;

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

    return AppFormShell(
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
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: widget.submitLabel,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            Navigator.of(context).pop(<String, Object?>{
              'statement': _statementController.text.trim(),
              'reason': _reasonController.text.trim(),
              'notes': _notesController.text.trim(),
            });
          },
        ),
      ],
    );
  }
}

Future<void> _showAddendumDialog(
  BuildContext context,
  WidgetRef ref,
  RadiologyResult result,
) async {
  final AppLocalizations l10n = context.l10n;
  final Map<String, Object?>? payload = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(l10n.radiologyAddendumDialogTitle),
    content: const _AddendumForm(),
    icon: const Icon(Icons.post_add_outlined),
    maxWidth: 560,
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

    return AppFormShell(
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
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.radiologyAddendumAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'addendum_text': _addendumController.text.trim(),
              'notes': _notesController.text.trim(),
            });
          },
        ),
      ],
    );
  }
}

Future<void> _showCancelDialog(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = context.l10n;
  final Map<String, Object?>? payload = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(l10n.radiologyCancelDialogTitle),
    content: const _CancelForm(),
    icon: const Icon(Icons.cancel_outlined),
    maxWidth: 520,
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

    return AppFormShell(
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
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.radiologyCancelOrderAction,
          submitIcon: Icons.cancel_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'reason': _reasonController.text.trim(),
              'notes': _notesController.text.trim(),
            });
          },
        ),
      ],
    );
  }
}

Future<void> _showPacsSyncDialog(
  BuildContext context,
  WidgetRef ref,
  ImagingStudy study,
) async {
  final AppLocalizations l10n = context.l10n;
  final Map<String, Object?>? payload = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(l10n.radiologyPacsSyncDialogTitle),
    content: const _PacsSyncForm(),
    icon: const Icon(Icons.cloud_sync_outlined),
    maxWidth: 520,
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

  @override
  State<_PacsSyncForm> createState() => _PacsSyncFormState();
}

class _PacsSyncFormState extends State<_PacsSyncForm> {
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
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    return AppFormShell(
      formKey: formKey,
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
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.radiologySyncPacsAction,
          submitIcon: Icons.cloud_sync_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            Navigator.of(context).pop(<String, Object?>{
              'study_uid': _studyUidController.text.trim(),
              'notes': _notesController.text.trim(),
            });
          },
        ),
      ],
    );
  }
}

Future<void> _submitNotesOnly({
  required BuildContext context,
  required String title,
  required String notesLabel,
  required String submitLabel,
  required Future<AppFailure?> Function(Map<String, Object?> payload) submit,
}) async {
  final Map<String, Object?>? payload = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(title),
    content: _NotesOnlyForm(notesLabel: notesLabel, submitLabel: submitLabel),
    icon: const Icon(Icons.edit_note_outlined),
    maxWidth: 520,
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
  const _NotesOnlyForm({required this.notesLabel, required this.submitLabel});

  final String notesLabel;
  final String submitLabel;

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

    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _notesController,
          labelText: widget.notesLabel,
          maxLines: 4,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: widget.submitLabel,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            Navigator.of(
              context,
            ).pop(<String, Object?>{'notes': _notesController.text.trim()});
          },
        ),
      ],
    );
  }
}

List<AppSelectOption<String>> _radiologyPriorityOptions(
  AppLocalizations l10n,
) {
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
    ),
  ];
}

List<AppSelectOption<String>> _radiologyLateralityOptions(
  AppLocalizations l10n,
) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(value: 'LEFT', label: l10n.radiologyLateralityLeft),
    AppSelectOption<String>(value: 'RIGHT', label: l10n.radiologyLateralityRight),
    AppSelectOption<String>(
      value: 'BILATERAL',
      label: l10n.radiologyLateralityBilateral,
    ),
  ];
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

AppListTableColumn<RadiologyOrder> _radiologyPatientColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<RadiologyOrder>(
    id: 'patient',
    label: l10n.radiologyPatientColumnLabel,
    sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
        appListTableCompareText(left.patientDisplayName, right.patientDisplayName),
    cellBuilder: (BuildContext context, RadiologyOrder item) {
      return _TwoLineCell(
        title: item.patientDisplayName ?? l10n.profileUnknownValue,
        subtitle: _joinDisplay(<String?>[
          item.patientId,
          if (item.isPatientGroup)
            _activeOrderCountLabel(l10n, item.activeOrderCount)
          else
            item.displayId,
        ]),
      );
    },
  );
}

AppListTableColumn<RadiologyOrder> _radiologyOrderIdentifierColumn(
  AppLocalizations l10n,
  RadiologyWorkbenchView view,
) {
  return AppListTableColumn<RadiologyOrder>(
    id: 'orders',
    label: view == RadiologyWorkbenchView.patients
        ? l10n.radiologyOrdersColumnLabel
        : l10n.radiologyOrderColumnLabel,
    sortComparator: (RadiologyOrder left, RadiologyOrder right) =>
        appListTableCompareText(left.effectiveDisplayId, right.effectiveDisplayId),
    cellBuilder: (BuildContext context, RadiologyOrder item) {
      if (item.isPatientGroup) {
        final int activeOrders = item.activeOrderCount > 0
            ? item.activeOrderCount
            : item.orderCount;
        return Text(_activeOrderCountLabel(l10n, activeOrders));
      }
      return Text(item.effectiveDisplayId);
    },
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.children,
    this.actions = const <Widget>[],
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

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
              children: <Widget>[
                Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                ...actions,
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.maxLines = 2,
  });

  final String label;
  final String? value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String resolvedValue = _valueOrUnknown(context, value);

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 118,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Text(
              resolvedValue,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _TwoLineCell extends StatelessWidget {
  const _TwoLineCell({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle.trim().isNotEmpty)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _IconTwoLineCell extends StatelessWidget {
  const _IconTwoLineCell({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(
          icon,
          size: theme.appTokens.listIconSize,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(child: _TwoLineCell(title: title, subtitle: subtitle)),
      ],
    );
  }
}

class _ModalityLabel extends StatelessWidget {
  const _ModalityLabel({required this.modality});

  final String? modality;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    return Row(
      children: <Widget>[
        Icon(
          _radiologyModalityIcon(modality),
          size: theme.appTokens.listIconSize,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: theme.spacing.xs),
        Expanded(
          child: Text(
            _modalityLabelOrNull(l10n, modality) ?? l10n.profileUnknownValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

void _showMutationResult(BuildContext context, AppFailure? failure) {
  if (!context.mounted) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null
            ? l10n.radiologySavedMessage
            : l10n.failureMessage(failure),
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

AppWorkspaceStatus _orderStatus(BuildContext context, RadiologyOrder order) {
  final AppLocalizations l10n = context.l10n;
  return AppWorkspaceStatus(
    label: _orderStatusLabel(l10n, order.status),
    tone: _orderStatusTone(order.status),
    icon: _orderStatusIcon(order.status),
  );
}

AppWorkspaceStatus _resultStatus(BuildContext context, RadiologyResult result) {
  final AppLocalizations l10n = context.l10n;
  return AppWorkspaceStatus(
    label: _resultStatusLabel(l10n, result.status),
    tone: _resultStatusTone(result.status),
    icon: result.isReleased
        ? Icons.verified_outlined
        : Icons.description_outlined,
  );
}

String _stageFilterLabel(AppLocalizations l10n, String? stage) {
  return switch ((stage ?? '').trim().toUpperCase()) {
    'ALL' => l10n.radiologyStageAll,
    'ORDERED' => l10n.radiologyStageOrdered,
    'PROCESSING' => l10n.radiologyStageProcessing,
    'REPORTING' => l10n.radiologyStageReporting,
    'COMPLETED' => l10n.radiologyStageCompleted,
    'CANCELLED' => l10n.radiologyStageCancelled,
    _ => l10n.profileUnknownValue,
  };
}

String _orderStatusLabel(AppLocalizations l10n, String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'ORDERED' => l10n.radiologyStatusOrdered,
    'IN_PROCESS' => l10n.radiologyStatusInProcess,
    'COMPLETED' => l10n.radiologyStatusCompleted,
    'CANCELLED' => l10n.radiologyStatusCancelled,
    _ => l10n.profileUnknownValue,
  };
}

String _resultStatusLabel(AppLocalizations l10n, String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'DRAFT' => l10n.radiologyResultDraft,
    'FINAL' => l10n.radiologyResultFinal,
    'AMENDED' => l10n.radiologyResultAmended,
    _ => l10n.profileUnknownValue,
  };
}

String _modalityLabel(AppLocalizations l10n, String? modality) {
  return switch ((modality ?? '').trim().toUpperCase()) {
    'XRAY' || 'X_RAY' || 'X-RAY' => l10n.radiologyModalityXray,
    'CT' => l10n.radiologyModalityCt,
    'MRI' => l10n.radiologyModalityMri,
    'ULTRASOUND' => l10n.radiologyModalityUltrasound,
    'FLUOROSCOPY' => l10n.radiologyModalityFluoroscopy,
    'MAMMOGRAPHY' => l10n.radiologyModalityMammography,
    'NUCLEAR_MEDICINE' || 'NUCLEAR MEDICINE' =>
      l10n.radiologyModalityNuclearMedicine,
    'INTERVENTIONAL_RADIOLOGY' || 'INTERVENTIONAL RADIOLOGY' =>
      l10n.radiologyModalityInterventionalRadiology,
    'PET' => l10n.radiologyModalityPet,
    'ECG' => l10n.radiologyModalityEcg,
    'ECHO' => l10n.radiologyModalityEcho,
    'ENDO' => l10n.radiologyModalityEndo,
    'GASTRO' => l10n.radiologyModalityGastro,
    'OTHER' => l10n.radiologyModalityOther,
    _ => l10n.profileUnknownValue,
  };
}

String? _modalityLabelOrNull(AppLocalizations l10n, String? modality) {
  final String normalized = modality?.trim() ?? '';
  return normalized.isEmpty ? null : _modalityLabel(l10n, normalized);
}

IconData _radiologyModalityIcon(String? modality) {
  return switch ((modality ?? '').trim().toUpperCase()) {
    'XRAY' || 'X_RAY' || 'X-RAY' => Icons.photo_camera_outlined,
    'CT' => Icons.donut_large_outlined,
    'MRI' => Icons.all_out_outlined,
    'ULTRASOUND' || 'US' => Icons.graphic_eq_outlined,
    'FLUOROSCOPY' => Icons.video_camera_back_outlined,
    'MAMMOGRAPHY' => Icons.image_search_outlined,
    'PET' => Icons.blur_on_outlined,
    'NUCLEAR_MEDICINE' || 'NUCLEAR MEDICINE' => Icons.radio_button_checked,
    'INTERVENTIONAL_RADIOLOGY' || 'INTERVENTIONAL RADIOLOGY' =>
      Icons.medical_services_outlined,
    'ECG' => Icons.monitor_heart_outlined,
    'ECHO' => Icons.favorite_border,
    'ENDO' || 'GASTRO' => Icons.biotech_outlined,
    'OTHER' => Icons.image_search_outlined,
    _ => Icons.image_search_outlined,
  };
}

String _activeOrderCountLabel(AppLocalizations l10n, int count) {
  return count == 1
      ? l10n.radiologyOneActiveOrderLabel
      : l10n.radiologyActiveOrdersLabel(count);
}

List<ClinicalActionCatalogOption> _radiologyCatalogOptions(
  RadiologyWorkspaceState? state,
) {
  final List<RadiologyCatalogTest> catalogTests =
      state?.catalogTests ?? const <RadiologyCatalogTest>[];
  if (catalogTests.isNotEmpty) {
    return <ClinicalActionCatalogOption>[
      for (final RadiologyCatalogTest test in catalogTests)
        ClinicalActionCatalogOption(
          id: test.id,
          publicId: test.effectiveId,
          name: test.name,
          code: test.code,
          category: test.modality,
          secondaryText: _joinDisplay(<String?>[
            test.bodyRegion,
            test.laterality,
            test.procedureType,
            test.equipment,
          ]),
          status: test.status,
          searchText: _joinDisplay(<String?>[
            test.searchText,
            test.name,
            test.code,
            test.modality,
            test.bodyRegion,
            test.laterality,
            test.procedureType,
            test.equipment,
          ]),
          metadata: <String, Object?>{
            'modality': test.modality,
            'body_region': test.bodyRegion,
            'laterality': test.laterality,
            'procedure_type': test.procedureType,
            'equipment': test.equipment,
            'source': test.source,
          },
        ),
    ];
  }

  final List<RadiologyReferenceOption> references =
      state?.references.radiologyTests ?? const <RadiologyReferenceOption>[];
  return <ClinicalActionCatalogOption>[
    for (final RadiologyReferenceOption option in references)
      ClinicalActionCatalogOption(
        id: option.value,
        publicId: option.value,
        name: option.label,
        secondaryText: option.subtitle,
        searchText: option.displayLabel,
      ),
  ];
}

const String _radiologyStageFilterKey = 'stage';
const String _radiologyStatusFilterKey = 'status';
const String _radiologyModalityFilterKey = 'modality';

AppSearchBarFilterValue _radiologyFilterValue(RadiologyWorkspaceQuery query) {
  return AppSearchBarFilterValue(
    dateFrom: query.from,
    options: <String, String>{
      if (query.stage != 'ALL') _radiologyStageFilterKey: query.stage,
      if (query.status != null) _radiologyStatusFilterKey: query.status!,
      if (query.modality != null) _radiologyModalityFilterKey: query.modality!,
    },
  );
}

bool _hasRadiologyFilters(RadiologyWorkspaceQuery query) {
  return query.stage != 'ALL' ||
      query.status != null ||
      query.modality != null ||
      query.from != null;
}

List<AppSearchBarFilterChoice> _radiologyStageFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    for (final String stage in radiologyStageFilters)
      if (stage != 'ALL')
        AppSearchBarFilterChoice(
          value: stage,
          label: _stageFilterLabel(l10n, stage),
          icon: Icons.timeline_outlined,
        ),
  ];
}

List<AppSearchBarFilterChoice> _radiologyStatusFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    for (final String status in radiologyOrderStatuses)
      AppSearchBarFilterChoice(
        value: status,
        label: _orderStatusLabel(l10n, status),
        icon: Icons.task_alt_outlined,
      ),
  ];
}

List<AppSearchBarFilterChoice> _radiologyModalityFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    for (final String modality in radiologyModalities)
      AppSearchBarFilterChoice(
        value: modality,
        label: _modalityLabel(l10n, modality),
        icon: _radiologyModalityIcon(modality),
      ),
  ];
}

bool _isSameFilterDate(DateTime? left, DateTime? right) {
  if (left == null || right == null) {
    return left == null && right == null;
  }
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _nextActionLabel(BuildContext context, RadiologyOrder order) {
  final AppLocalizations l10n = context.l10n;
  if (order.normalizedStatus == 'CANCELLED') {
    return l10n.radiologyStatusCancelled;
  }
  if (!order.hasBillingGate) {
    return l10n.radiologyNextActionConfirmBilling;
  }
  if (order.normalizedStatus == 'ORDERED') {
    return l10n.radiologyNextActionStartImaging;
  }
  if (order.normalizedStatus == 'IN_PROCESS' && order.studyCount == 0) {
    return l10n.radiologyNextActionPerformStudy;
  }
  if (order.hasDraftResult) {
    return l10n.radiologyNextActionReleaseReport;
  }
  if (order.hasFinalResult) {
    return l10n.radiologyNextActionDoctorReview;
  }
  if (order.normalizedStatus == 'COMPLETED') {
    return l10n.radiologyNextActionDoctorReview;
  }
  return l10n.radiologyNextActionReportPending;
}

String _billingGateLabel(BuildContext context, RadiologyOrder order) {
  final AppLocalizations l10n = context.l10n;
  if (!order.hasBillingGate) {
    return l10n.radiologyBillingGateUnavailable;
  }

  return _joinDisplay(<String?>[
    order.paymentStatus,
    order.authorizationStatus,
  ]).ifEmpty(l10n.profileUnknownValue);
}

AppWorkspaceStatusTone _orderStatusTone(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'COMPLETED' => AppWorkspaceStatusTone.success,
    'CANCELLED' => AppWorkspaceStatusTone.error,
    'IN_PROCESS' => AppWorkspaceStatusTone.info,
    'ORDERED' => AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatusTone _resultStatusTone(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'FINAL' || 'AMENDED' => AppWorkspaceStatusTone.success,
    'DRAFT' => AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

IconData _orderStatusIcon(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'COMPLETED' => Icons.check_circle_outline,
    'CANCELLED' => Icons.cancel_outlined,
    'IN_PROCESS' => Icons.play_circle_outline,
    'ORDERED' => Icons.pending_actions_outlined,
    _ => Icons.radio_button_unchecked,
  };
}

String _formatDateTime(BuildContext context, DateTime? value) {
  return value == null
      ? context.l10n.profileUnknownValue
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String? _formatDateTimeOrNull(BuildContext context, DateTime? value) {
  return value == null
      ? null
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String? _trimmedOrNull(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

String _valueOrUnknown(BuildContext context, String? value) {
  return (value ?? '').trim().ifEmpty(context.l10n.profileUnknownValue);
}

String _joinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

extension on String {
  String ifEmpty(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}
