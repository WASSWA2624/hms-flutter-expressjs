import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

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

class _RadiologyWorkspaceContent extends ConsumerWidget {
  const _RadiologyWorkspaceContent({required this.state});

  final RadiologyWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
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
      description: l10n.radiologyDescription,
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
          label: l10n.radiologyRefreshCatalogAction,
          leadingIcon: Icons.manage_search,
          isLoading: state.isRefreshing,
          onPressed: state.isRefreshing
              ? null
              : () {
                  unawaited(controller.searchReferences());
                },
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
        AppWorkspaceSummaryCard(
          label: l10n.radiologyTotalOrdersSummaryLabel,
          value: state.summary.totalOrders.toString(),
          icon: Icons.assignment_outlined,
          compact: true,
        ),
        AppWorkspaceSummaryCard(
          label: l10n.radiologyWaitingImagingSummaryLabel,
          value: state.summary.orderedQueue.toString(),
          icon: Icons.pending_actions_outlined,
          tone: AppWorkspaceStatusTone.warning,
          compact: true,
        ),
        AppWorkspaceSummaryCard(
          label: l10n.radiologyReportingSummaryLabel,
          value: state.reportingCount.toString(),
          icon: Icons.edit_note_outlined,
          tone: AppWorkspaceStatusTone.info,
          compact: true,
        ),
        AppWorkspaceSummaryCard(
          label: l10n.radiologyReleasedSummaryLabel,
          value: state.releasedCount.toString(),
          icon: Icons.verified_outlined,
          tone: AppWorkspaceStatusTone.success,
          compact: true,
        ),
        AppWorkspaceSummaryCard(
          label: l10n.radiologyUnsyncedSummaryLabel,
          value: state.summary.unsyncedStudies.toString(),
          icon: Icons.cloud_off_outlined,
          tone: state.summary.unsyncedStudies > 0
              ? AppWorkspaceStatusTone.warning
              : AppWorkspaceStatusTone.neutral,
          compact: true,
        ),
      ],
      filters: _RadiologyFilterBar(state: state),
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
          _RadiologyOrderBoard(state: state),
        ],
      ),
      detail: _RadiologyOrderDetail(
        state: state,
        canWork: canWork,
        canRequest: canRequest,
      ),
      activity: const _RadiologyBackendGapsPanel(),
    );
  }
}

class _RadiologyFilterBar extends ConsumerStatefulWidget {
  const _RadiologyFilterBar({required this.state});

  final RadiologyWorkspaceState state;

  @override
  ConsumerState<_RadiologyFilterBar> createState() =>
      _RadiologyFilterBarState();
}

class _RadiologyFilterBarState extends ConsumerState<_RadiologyFilterBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
  }

  @override
  void didUpdateWidget(covariant _RadiologyFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String search = widget.state.query.search;
    if (_searchController.text != search) {
      _searchController.value = TextEditingValue(text: search);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final controller = ref.read(radiologyWorkspaceControllerProvider.notifier);
    final RadiologyWorkspaceQuery query = widget.state.query;

    return AppWorkspaceFilterBar(
      semanticLabel: l10n.radiologyFiltersLabel,
      expandSearch: true,
      search: AppSearchField(
        controller: _searchController,
        semanticLabel: l10n.radiologySearchLabel,
        hintText: l10n.radiologySearchHint,
        isLoading: widget.state.isRefreshing,
        onSubmitted: (String value) {
          unawaited(controller.applySearch(value));
        },
        onClear: () {
          unawaited(controller.applySearch(''));
        },
      ),
      filters: <Widget>[
        AppDateField(
          value: query.from,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          labelText: l10n.radiologyOrderDateFilterLabel,
          pickerButtonLabel: l10n.radiologyPickOrderDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          hintText: l10n.appDateFormatHint,
          onChanged: (DateTime? value) {
            unawaited(controller.applyOrderedDate(value));
          },
        ),
        AppSelectField<String>(
          value: query.stage,
          labelText: l10n.radiologyStageFilterLabel,
          options: <AppSelectOption<String>>[
            for (final String stage in radiologyStageFilters)
              AppSelectOption<String>(
                value: stage,
                label: _stageFilterLabel(l10n, stage),
              ),
          ],
          onChanged: (String? value) {
            unawaited(controller.applyStage(value ?? 'ALL'));
          },
        ),
        AppSelectField<String>(
          value: query.status,
          labelText: l10n.radiologyStatusFilterLabel,
          options: <AppSelectOption<String>>[
            for (final String status in radiologyOrderStatuses)
              AppSelectOption<String>(
                value: status,
                label: _orderStatusLabel(l10n, status),
              ),
          ],
          onChanged: (String? value) {
            unawaited(controller.applyStatus(value));
          },
        ),
        AppSelectField<String>(
          value: query.modality,
          labelText: l10n.radiologyModalityFilterLabel,
          options: <AppSelectOption<String>>[
            for (final String modality in radiologyModalities)
              AppSelectOption<String>(
                value: modality,
                label: _modalityLabel(l10n, modality),
              ),
          ],
          onChanged: (String? value) {
            unawaited(controller.applyModality(value));
          },
        ),
      ],
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.radiologyClearFiltersAction,
          leadingIcon: Icons.clear,
          onPressed: controller.clearFilters,
        ),
      ],
    );
  }
}

class _RadiologyOrderBoard extends ConsumerWidget {
  const _RadiologyOrderBoard({required this.state});

  final RadiologyWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final controller = ref.read(radiologyWorkspaceControllerProvider.notifier);

    return AppWorkspaceDetailPanel(
      title: l10n.radiologyWorklistTitle,
      description: l10n.radiologyWorklistDescription,
      child: AppPaginatedDataList<RadiologyOrder>(
        page: state.orders,
        isLoading: state.isRefreshing,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemKeyBuilder: (RadiologyOrder item) => ValueKey<String>(item.id),
        onRowSelected: (RadiologyOrder order) {
          unawaited(controller.selectOrder(order));
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
            title: l10n.radiologyNoOrdersTitle,
            body: l10n.radiologyNoOrdersBody,
            icon: Icons.inbox_outlined,
          );
        },
        columns: <AppDataColumn<RadiologyOrder>>[
          AppDataColumn<RadiologyOrder>(
            label: l10n.radiologyPatientColumnLabel,
            cellBuilder: (BuildContext context, RadiologyOrder item) {
              return _TwoLineCell(
                title: item.patientDisplayName ?? l10n.profileUnknownValue,
                subtitle: _joinDisplay(<String?>[item.patientId, item.encounterId]),
              );
            },
          ),
          AppDataColumn<RadiologyOrder>(
            label: l10n.radiologyOrderColumnLabel,
            cellBuilder: (BuildContext context, RadiologyOrder item) {
              return Text(item.effectiveDisplayId);
            },
          ),
          AppDataColumn<RadiologyOrder>(
            label: l10n.radiologyStudyColumnLabel,
            cellBuilder: (BuildContext context, RadiologyOrder item) {
              return _TwoLineCell(
                title: item.testDisplayName ?? l10n.profileUnknownValue,
                subtitle: _joinDisplay(<String?>[
                  _modalityLabelOrNull(l10n, item.modality),
                  item.bodyRegion,
                  item.laterality,
                ]),
              );
            },
          ),
          AppDataColumn<RadiologyOrder>(
            label: l10n.radiologyPriorityColumnLabel,
            cellBuilder: (BuildContext context, RadiologyOrder item) {
              return Text(_valueOrUnknown(context, item.priority));
            },
          ),
          AppDataColumn<RadiologyOrder>(
            label: l10n.radiologyPaymentAuthColumnLabel,
            cellBuilder: (BuildContext context, RadiologyOrder item) {
              return Text(_billingGateLabel(context, item));
            },
          ),
          AppDataColumn<RadiologyOrder>(
            label: l10n.radiologyStatusColumnLabel,
            cellBuilder: (BuildContext context, RadiologyOrder item) {
              return AppWorkspaceStatusBadge(
                status: _orderStatus(context, item),
              );
            },
          ),
          AppDataColumn<RadiologyOrder>(
            label: l10n.radiologyNextActionColumnLabel,
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
              order.effectiveDisplayId,
              order.testDisplayName,
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
          patientNumber:
              order.patientId ?? order.encounterId ?? order.effectiveDisplayId,
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
          fields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: l10n.radiologyEncounterLabel,
              value: order.encounterId ?? '',
              icon: Icons.assignment_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.radiologyOrderedAtLabel,
              value: _formatDateTime(context, order.orderedAt),
              icon: Icons.schedule,
            ),
            AppWorkspacePatientContextField(
              label: l10n.radiologyModalityLabel,
              value: _modalityLabel(l10n, order.modality),
              icon: Icons.view_in_ar_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.radiologyPaymentLabel,
              value: _valueOrUnknown(context, order.paymentStatus),
              icon: Icons.payments_outlined,
              tone: _gateTone(order.paymentStatus),
            ),
            AppWorkspacePatientContextField(
              label: l10n.radiologyAuthorizationLabel,
              value: _valueOrUnknown(context, order.authorizationStatus),
              icon: Icons.verified_user_outlined,
              tone: _gateTone(order.authorizationStatus),
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
                            .read(
                              radiologyWorkspaceControllerProvider.notifier,
                            )
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
        SizedBox(height: theme.spacing.lg),
        _RequestSection(order: order),
        SizedBox(height: theme.spacing.lg),
        _ReportingSection(
          state: state,
          workflow: workflow,
          canWork: canWork,
        ),
        SizedBox(height: theme.spacing.lg),
        _StudiesSection(
          state: state,
          workflow: workflow,
          canWork: canWork,
        ),
        SizedBox(height: theme.spacing.lg),
        _DoctorReviewPanel(order: order),
        SizedBox(height: theme.spacing.lg),
        _TimelineSection(workflow: workflow),
      ],
    );
  }
}

class _RequestSection extends StatelessWidget {
  const _RequestSection({required this.order});

  final RadiologyOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return _DetailSection(
      title: l10n.radiologyRequestDetailsTitle,
      children: <Widget>[
        _DetailLine(
          label: l10n.radiologyStudyLabel,
          value: order.testDisplayName,
        ),
        _DetailLine(
          label: l10n.radiologyPriorityLabel,
          value: order.priority,
        ),
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
                    canSync: canWork &&
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
                  label: asset.displayId ?? asset.id,
                  value: _joinDisplay(<String?>[
                    asset.fileName,
                    asset.contentType,
                    asset.storageKey,
                  ]),
                ),
            SizedBox(height: theme.spacing.md),
            Text(l10n.radiologyPacsLinksLabel, style: theme.textTheme.labelLarge),
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
                  link.url ?? link.displayId ?? link.id,
                  style: theme.textTheme.bodyMedium,
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

class _RadiologyBackendGapsPanel extends StatelessWidget {
  const _RadiologyBackendGapsPanel();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppWorkspaceActivityList(
      title: l10n.radiologyBackendGapsTitle,
      description: l10n.radiologyBackendGapsBody,
      emptyTitle: l10n.radiologyBackendGapsTitle,
      emptyBody: l10n.radiologyBackendGapsBody,
      items: <AppWorkspaceActivityItem>[
        AppWorkspaceActivityItem(
          title: l10n.radiologyGapSchedulingTitle,
          subtitle: l10n.radiologyGapBackendSubtitle,
          description: l10n.radiologyGapSchedulingBody,
          icon: Icons.event_busy_outlined,
          tone: AppWorkspaceStatusTone.warning,
        ),
        AppWorkspaceActivityItem(
          title: l10n.radiologyGapBillingTitle,
          subtitle: l10n.radiologyGapBackendSubtitle,
          description: l10n.radiologyGapBillingBody,
          icon: Icons.receipt_long_outlined,
          tone: AppWorkspaceStatusTone.warning,
        ),
      ],
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
  String? _patientId;
  String? _encounterId;
  String? _testId;

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final RadiologyWorkspaceState? state = _watchState(ref);
    final RadiologyReferenceData references =
        state?.references ?? RadiologyReferenceData.empty;
    final List<RadiologyReferenceOption> encounterOptions = _patientId == null
        ? references.encounters
        : references.encounters
              .where((RadiologyReferenceOption option) {
                return option.patientId == null || option.patientId == _patientId;
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
                labelText: l10n.radiologyReferenceSearchLabel,
                hintText: l10n.radiologyReferenceSearchHint,
                prefixIcon: const Icon(Icons.search),
                textInputAction: TextInputAction.search,
                onFieldSubmitted: _searchReferences,
              ),
            ),
            SizedBox(width: Theme.of(context).spacing.sm),
            Padding(
              padding: EdgeInsets.only(top: Theme.of(context).spacing.xs),
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
                (RadiologyReferenceOption option) => option.value == _encounterId,
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
        AppSelectField<String>.searchable(
          value: _testId,
          labelText: l10n.radiologyStudyLabel,
          isRequired: true,
          options: _referenceOptions(references.radiologyTests),
          validator: AppValidators.requiredValue(
            l10n.radiologyFieldRequiredLabel(l10n.radiologyStudyLabel),
          ),
          onChanged: (String? value) => setState(() => _testId = value),
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.radiologyClinicalNotesLabel,
          maxLines: 4,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.radiologyRequestImagingAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'patient_id': _patientId,
              'encounter_id': _encounterId,
              'radiology_test_id': _testId,
              'notes': _notesController.text.trim(),
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
  final AppLocalizations l10n = context.l10n;
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

List<AppSelectOption<String>> _referenceOptions(
  List<RadiologyReferenceOption> options,
) {
  return <AppSelectOption<String>>[
    for (final RadiologyReferenceOption option in options)
      AppSelectOption<String>(
        value: option.value,
        label: option.displayLabel,
      ),
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

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

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
            Text(title, style: theme.textTheme.titleSmall),
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
    'XRAY' => l10n.radiologyModalityXray,
    'CT' => l10n.radiologyModalityCt,
    'MRI' => l10n.radiologyModalityMri,
    'ULTRASOUND' => l10n.radiologyModalityUltrasound,
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

AppWorkspaceStatusTone _gateTone(String? value) {
  final String normalized = (value ?? '').trim().toUpperCase();
  if (normalized.isEmpty) {
    return AppWorkspaceStatusTone.neutral;
  }
  if (<String>['PAID', 'APPROVED', 'AUTHORIZED', 'CLEARED'].contains(normalized)) {
    return AppWorkspaceStatusTone.success;
  }
  if (<String>['DECLINED', 'DENIED', 'FAILED', 'CANCELLED'].contains(normalized)) {
    return AppWorkspaceStatusTone.error;
  }
  return AppWorkspaceStatusTone.warning;
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
