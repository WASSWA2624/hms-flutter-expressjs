import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  static const AccessRequirement _requestRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.labRead,
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
    ],
    activeModules: <String>['lab-workflows'],
  );
  static const AccessRequirement _mutationRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[AppPermissions.labWrite],
    activeModules: <String>['lab-workflows'],
  );

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
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
    final bool canRequest = _requestRequirement.isAllowed(policy);
    final bool canMutate = _mutationRequirement.isAllowed(policy);

    return AppWorkspace(
      title: l10n.labTitle,
      description: l10n.labDescription,
      compactSummaryCards: true,
      status: AppWorkspaceStatus(
        label: state.isSaving ? l10n.labSavingStatus : l10n.labLiveStatus,
        tone: state.isSaving
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
      ),
      primaryAction: canRequest
          ? AppButton.primary(
              label: l10n.labRequestOrderAction,
              leadingIcon: Icons.science_outlined,
              onPressed: () => _openOrderDialog(context, state),
            )
          : null,
      secondaryActions: <Widget>[
        if (canMutate)
          AppButton.secondary(
            label: l10n.labRecordQcAction,
            leadingIcon: Icons.fact_check_outlined,
            onPressed: () => _openQcDialog(context, state),
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
        _summaryCard(
          context,
          label: l10n.labTotalOrdersSummaryLabel,
          value: state.summary.totalOrders,
          icon: Icons.assignment_outlined,
          tone: AppWorkspaceStatusTone.info,
          onPressed: () => controller.applyScope(LabQueueScope.all),
        ),
        _summaryCard(
          context,
          label: l10n.labWaitingSampleSummaryLabel,
          value: state.summary.collectionQueue,
          icon: Icons.biotech_outlined,
          tone: AppWorkspaceStatusTone.warning,
          onPressed: () => controller.applyScope(LabQueueScope.collection),
        ),
        _summaryCard(
          context,
          label: l10n.labProcessingSummaryLabel,
          value: state.summary.processingQueue,
          icon: Icons.sync_outlined,
          tone: AppWorkspaceStatusTone.info,
          onPressed: () => controller.applyScope(LabQueueScope.processing),
        ),
        _summaryCard(
          context,
          label: l10n.labResultPendingSummaryLabel,
          value: state.summary.resultsQueue,
          icon: Icons.pending_actions_outlined,
          tone: AppWorkspaceStatusTone.warning,
          onPressed: () => controller.applyScope(LabQueueScope.results),
        ),
        _summaryCard(
          context,
          label: l10n.labCriticalSummaryLabel,
          value: state.summary.criticalResults,
          icon: Icons.priority_high_outlined,
          tone: AppWorkspaceStatusTone.error,
          onPressed: () => controller.applyScope(LabQueueScope.critical),
        ),
        _summaryCard(
          context,
          label: l10n.labCompletedSummaryLabel,
          value: state.summary.completedOrders,
          icon: Icons.verified_outlined,
          tone: AppWorkspaceStatusTone.success,
          onPressed: () => controller.applyScope(LabQueueScope.completed),
        ),
      ],
      filters: AppWorkspaceFilterBar(
        semanticLabel: l10n.labFiltersLabel,
        expandSearch: true,
        search: AppSearchField(
          controller: _searchController,
          semanticLabel: l10n.labSearchLabel,
          hintText: l10n.labSearchHint,
          onSubmitted: controller.applySearch,
          onClear: () => controller.applySearch(''),
        ),
        filters: <Widget>[
          AppSelectField<LabQueueScope>(
            value: state.query.scope,
            labelText: l10n.labScopeFilterLabel,
            options: _scopeOptions(l10n),
            onChanged: (LabQueueScope? value) {
              if (value != null) {
                controller.applyScope(value);
              }
            },
          ),
        ],
      ),
      body: _LabWorklistPanel(state: state),
      detail: _LabDetailPanel(state: state, canMutate: canMutate),
      activity: _LabCatalogQcPanel(state: state),
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
  const _LabWorklistPanel({required this.state});

  final LabWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final LabWorkspaceController controller = ref.read(
      labWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.labWorklistTitle,
      description: l10n.labWorklistDescription,
      child: AppPaginatedDataList<LabOrderSummary>(
        page: state.worklist,
        isLoading: state.isRefreshing,
        previousPageLabel: l10n.labPreviousPageLabel,
        nextPageLabel: l10n.labNextPageLabel,
        pageLabelBuilder: (AppPage<LabOrderSummary> page) {
          return _pageLabel(context, page);
        },
        onPageChanged: controller.changePage,
        onRowSelected: controller.selectOrder,
        emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
          title: l10n.labNoOrdersTitle,
          body: l10n.labNoOrdersBody,
          icon: Icons.science_outlined,
        ),
        columns: <AppDataColumn<LabOrderSummary>>[
          AppDataColumn<LabOrderSummary>(
            label: l10n.labPatientColumnLabel,
            cellBuilder: (_, LabOrderSummary item) {
              return _LabOrderIdentity(order: item);
            },
          ),
          AppDataColumn<LabOrderSummary>(
            label: l10n.labOrderColumnLabel,
            cellBuilder: (BuildContext context, LabOrderSummary item) {
              return Text(item.displayId ?? item.id);
            },
          ),
          AppDataColumn<LabOrderSummary>(
            label: l10n.labTestsColumnLabel,
            cellBuilder: (BuildContext context, LabOrderSummary item) {
              return Text(item.testsLabel ?? l10n.profileUnknownValue);
            },
          ),
          AppDataColumn<LabOrderSummary>(
            label: l10n.labSampleColumnLabel,
            cellBuilder: (BuildContext context, LabOrderSummary item) {
              return AppWorkspaceStatusBadge(status: _sampleStatus(context, item));
            },
          ),
          AppDataColumn<LabOrderSummary>(
            label: l10n.labResultColumnLabel,
            cellBuilder: (BuildContext context, LabOrderSummary item) {
              return AppWorkspaceStatusBadge(status: _resultStatus(context, item));
            },
          ),
          AppDataColumn<LabOrderSummary>(
            label: l10n.labNextActionColumnLabel,
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
                    AppWorkspaceStatusBadge(status: _orderStatus(context, item.status)),
                    AppWorkspaceStatusBadge(status: _sampleStatus(context, item)),
                    AppWorkspaceStatusBadge(status: _resultStatus(context, item)),
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
    final LabOrderWorkflow? workflow = state.selectedWorkflow;

    if (state.isRefreshingDetail) {
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
    final LabOrderItem? releasableItem = workflow.firstReleasableItem;
    final LabSample? receivableSample = workflow.firstReceivableSample;
    final LabSample? rejectableSample = workflow.firstRejectableSample;

    return AppWorkspaceDetailPanel(
      title: l10n.labDetailTitle,
      actions: <Widget>[
        if (canMutate && workflow.nextActions.canCollect)
          AppButton.secondary(
            label: l10n.labCollectSampleAction,
            leadingIcon: Icons.qr_code_scanner_outlined,
            onPressed: () => _openCollectDialog(context, workflow),
          ),
        if (canMutate &&
            workflow.nextActions.canReceiveSample &&
            receivableSample != null)
          AppButton.secondary(
            label: l10n.labReceiveSampleAction,
            leadingIcon: Icons.inventory_2_outlined,
            onPressed: () => _openReceiveDialog(context, workflow),
          ),
        if (canMutate &&
            workflow.nextActions.canReleaseResult &&
            releasableItem != null)
          AppButton.primary(
            label: l10n.labReleaseResultAction,
            leadingIcon: Icons.verified_outlined,
            onPressed: () => _openReleaseDialog(context, workflow),
          ),
        if (canMutate && rejectableSample != null)
          AppIconButton(
            icon: Icons.block_outlined,
            semanticLabel: l10n.labRejectSampleAction,
            tooltip: l10n.labRejectSampleAction,
            onPressed: () => _openRejectDialog(context, workflow),
          ),
        if (canMutate && workflow.nextActions.canReverseWorkflow)
          AppIconButton(
            icon: Icons.undo_outlined,
            semanticLabel: l10n.labReverseWorkflowAction,
            tooltip: l10n.labReverseWorkflowAction,
            onPressed: () => _openReverseDialog(context, workflow),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppWorkspacePatientContextHeader(
            patientName: order.patientDisplayName ?? l10n.profileUnknownValue,
            patientNumber: order.patientId ?? l10n.profileUnknownValue,
            semanticLabel: l10n.labPatientContextLabel,
            status: _orderStatus(context, order.status),
            alerts: <AppWorkspaceStatus>[
              if (order.hasCriticalResult)
                AppWorkspaceStatus(
                  label: l10n.labStatusCritical,
                  tone: AppWorkspaceStatusTone.error,
                  icon: Icons.priority_high_outlined,
                ),
              if (order.hasRejectedSample)
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
              ),
              AppWorkspacePatientContextField(
                label: l10n.labEncounterFieldLabel,
                value: order.encounterId ?? '',
                icon: Icons.medical_information_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.labOrderedAtFieldLabel,
                value: _dateTimeLabel(context, order.orderedAt),
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
            child: _LabItemList(items: order.items),
          ),
          _LabDetailSection(
            title: l10n.labSamplesSectionTitle,
            child: order.samples.isEmpty
                ? _EmptyInlineText(text: l10n.labNoSamplesLabel)
                : _LabSampleList(samples: order.samples),
          ),
          _LabDetailSection(
            title: l10n.labResultsSectionTitle,
            child: workflow.results.isEmpty
                ? _EmptyInlineText(text: l10n.labNoResultsLabel)
                : _LabResultList(results: workflow.results),
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

class _LabItemList extends StatelessWidget {
  const _LabItemList({required this.items});

  final List<LabOrderItem> items;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      children: <Widget>[
        for (final LabOrderItem item in items)
          _CompactRecordRow(
            title: item.displayTitle,
            subtitle: item.displaySubtitle ?? item.apiId,
            trailing: AppWorkspaceStatusBadge(
              status: _orderStatus(context, item.status),
            ),
          ),
        if (items.isEmpty) _EmptyInlineText(text: l10n.profileUnknownValue),
      ],
    );
  }
}

class _LabSampleList extends StatelessWidget {
  const _LabSampleList({required this.samples});

  final List<LabSample> samples;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final LabSample sample in samples)
          _CompactRecordRow(
            title: sample.displayId ?? sample.id,
            subtitle: _joinDisplay(<String?>[
              _dateTimeLabel(context, sample.collectedAt),
              _dateTimeLabel(context, sample.receivedAt),
            ]),
            trailing: AppWorkspaceStatusBadge(
              status: _statusBadge(context, sample.status),
            ),
          ),
      ],
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
            title: item.label ?? item.type ?? item.id,
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.labSavedMessage)),
                );
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
                value: _joinDisplay(<String?>[
                  order.patientDisplayName,
                  order.patientId,
                ]),
              ),
              _ReportLine(
                label: l10n.labReportOrderLabel,
                value: order.displayId ?? order.id,
              ),
              _ReportLine(
                label: l10n.labEncounterFieldLabel,
                value: order.encounterId,
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
                        label: l10n.labReportResultLabel,
                        value: result.displayValue,
                      ),
                      _ReportLine(
                        label: l10n.labReportRangeLabel,
                        value: result.referenceRangeSummary,
                      ),
                      _ReportLine(
                        label: l10n.labReportVerifiedLabel,
                        value: _dateTimeLabel(context, result.reportedAt),
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
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value == null || value!.isEmpty
                  ? context.l10n.profileUnknownValue
                  : value!,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabCatalogQcPanel extends StatelessWidget {
  const _LabCatalogQcPanel({required this.state});

  final LabWorkspaceState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppWorkspaceDetailPanel(
      title: l10n.labCatalogQcTitle,
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.labViewCatalogAction,
          leadingIcon: Icons.menu_book_outlined,
          onPressed: () => _openCatalogDialog(context, state),
        ),
      ],
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= 860;
          final List<Widget> panels = <Widget>[
            _CatalogPreview(
              title: l10n.labCatalogTitle,
              tests: state.catalogTests,
              panels: state.catalogPanels,
            ),
            _QcPreview(logs: state.qcLogs),
            const _LabBackendGaps(),
          ];
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _withGaps(context, panels),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: panels[0]),
              SizedBox(width: Theme.of(context).spacing.lg),
              Expanded(child: panels[1]),
              SizedBox(width: Theme.of(context).spacing.lg),
              Expanded(child: panels[2]),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _withGaps(BuildContext context, List<Widget> widgets) {
    final List<Widget> children = <Widget>[];
    for (var index = 0; index < widgets.length; index += 1) {
      if (index > 0) {
        children.add(SizedBox(height: Theme.of(context).spacing.lg));
      }
      children.add(widgets[index]);
    }
    return children;
  }
}

class _CatalogPreview extends StatelessWidget {
  const _CatalogPreview({
    required this.title,
    required this.tests,
    required this.panels,
  });

  final String title;
  final List<LabCatalogItem> tests;
  final List<LabCatalogItem> panels;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<LabCatalogItem> items = <LabCatalogItem>[...tests, ...panels]
        .take(6)
        .toList(growable: false);
    return _PreviewGroup(
      title: title,
      emptyText: l10n.labNoCatalogItemsLabel,
      children: <Widget>[
        for (final LabCatalogItem item in items)
          _CompactRecordRow(
            title: item.displayTitle,
            subtitle: item.displaySubtitle,
            leading: item.isPanel
                ? Icons.account_tree_outlined
                : Icons.science_outlined,
          ),
      ],
    );
  }
}

class _QcPreview extends StatelessWidget {
  const _QcPreview({required this.logs});

  final List<LabQcLog> logs;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return _PreviewGroup(
      title: l10n.labQcTitle,
      emptyText: l10n.labNoQcLogsLabel,
      children: <Widget>[
        for (final LabQcLog log in logs.take(6))
          _CompactRecordRow(
            title: log.displayTitle,
            subtitle: _joinDisplay(<String?>[
              _statusLabel(context, log.status),
              _dateTimeLabel(context, log.loggedAt),
              log.notes,
            ]),
            leading: Icons.fact_check_outlined,
          ),
      ],
    );
  }
}

class _LabBackendGaps extends StatelessWidget {
  const _LabBackendGaps();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return _PreviewGroup(
      title: l10n.labBackendGapsTitle,
      emptyText: l10n.labBackendGapsBody,
      children: <Widget>[
        _CompactRecordRow(
          title: l10n.labGapBillingTitle,
          subtitle: l10n.labGapBillingBody,
          leading: Icons.payments_outlined,
        ),
        _CompactRecordRow(
          title: l10n.labGapVerificationTitle,
          subtitle: l10n.labGapVerificationBody,
          leading: Icons.verified_user_outlined,
        ),
        _CompactRecordRow(
          title: l10n.labGapReportGenerationTitle,
          subtitle: l10n.labGapReportGenerationBody,
          leading: Icons.picture_as_pdf_outlined,
        ),
      ],
    );
  }
}

class _PreviewGroup extends StatelessWidget {
  const _PreviewGroup({
    required this.title,
    required this.emptyText,
    required this.children,
  });

  final String title;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: theme.textTheme.titleSmall),
        SizedBox(height: theme.spacing.sm),
        if (children.isEmpty) _EmptyInlineText(text: emptyText),
        ...children,
      ],
    );
  }
}

class _RequestOrderDialog extends ConsumerStatefulWidget {
  const _RequestOrderDialog({required this.state});

  final LabWorkspaceState state;

  @override
  ConsumerState<_RequestOrderDialog> createState() =>
      _RequestOrderDialogState();
}

class _RequestOrderDialogState extends ConsumerState<_RequestOrderDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _patientController;
  late final TextEditingController _encounterController;
  late final TextEditingController _searchController;
  final Set<String> _selectedTestIds = <String>{};
  final Set<String> _selectedPanelIds = <String>{};
  AppFailure? _failure;
  bool _isSaving = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _patientController = TextEditingController();
    _encounterController = TextEditingController();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _patientController.dispose();
    _encounterController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<LabCatalogItem> tests = _filterCatalog(
      widget.state.catalogTests,
    );
    final List<LabCatalogItem> panels = _filterCatalog(
      widget.state.catalogPanels,
    );

    return AppDialog(
      title: Text(l10n.labRequestOrderDialogTitle),
      icon: const Icon(Icons.science_outlined),
      scrollable: true,
      maxWidth: 720,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _patientController,
              labelText: l10n.labPatientIdLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _encounterController,
              labelText: l10n.labEncounterIdLabel,
              enabled: !_isSaving,
            ),
            AppSearchField(
              controller: _searchController,
              semanticLabel: l10n.labCatalogSearchLabel,
              hintText: l10n.labCatalogSearchHint,
              onChanged: (String value) {
                setState(() => _search = value);
              },
              onClear: () {
                setState(() => _search = '');
              },
            ),
            SizedBox(
              height: 360,
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: <Widget>[
                    TabBar(
                      tabs: <Widget>[
                        Tab(text: l10n.labTestsTabLabel),
                        Tab(text: l10n.labPanelsTabLabel),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: <Widget>[
                          _CatalogSelectionList(
                            items: tests,
                            selectedIds: _selectedTestIds,
                            emptyText: l10n.labNoCatalogItemsLabel,
                            onChanged: _setTestSelected,
                          ),
                          _CatalogSelectionList(
                            items: panels,
                            selectedIds: _selectedPanelIds,
                            emptyText: l10n.labNoCatalogItemsLabel,
                            onChanged: _setPanelSelected,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

  List<LabCatalogItem> _filterCatalog(List<LabCatalogItem> items) {
    return items
        .where((LabCatalogItem item) => item.matchesSearch(_search))
        .toList(growable: false);
  }

  void _setTestSelected(LabCatalogItem item, bool value) {
    setState(() {
      if (value) {
        _selectedTestIds.add(item.apiId);
      } else {
        _selectedTestIds.remove(item.apiId);
      }
    });
  }

  void _setPanelSelected(LabCatalogItem item, bool value) {
    setState(() {
      if (value) {
        _selectedPanelIds.add(item.apiId);
      } else {
        _selectedPanelIds.remove(item.apiId);
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_selectedTestIds.isEmpty && _selectedPanelIds.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .createOrder(<String, Object?>{
          'patient_id': _patientController.text.trim(),
          'encounter_id': _encounterController.text.trim(),
          'requested_tests': <Map<String, Object?>>[
            for (final String id in _selectedTestIds) <String, Object?>{
              'lab_test_id': id,
            },
          ],
          'requested_panels': <Map<String, Object?>>[
            for (final String id in _selectedPanelIds) <String, Object?>{
              'lab_panel_id': id,
            },
          ],
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

class _CatalogSelectionList extends StatelessWidget {
  const _CatalogSelectionList({
    required this.items,
    required this.selectedIds,
    required this.emptyText,
    required this.onChanged,
  });

  final List<LabCatalogItem> items;
  final Set<String> selectedIds;
  final String emptyText;
  final void Function(LabCatalogItem item, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: _EmptyInlineText(text: emptyText));
    }

    return ListView.separated(
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final LabCatalogItem item = items[index];
        return AppCheckboxField(
          title: item.displayTitle,
          subtitle: item.displaySubtitle,
          value: selectedIds.contains(item.apiId),
          onChanged: (bool value) => onChanged(item, value),
        );
      },
      separatorBuilder: (_, _) => const Divider(height: 1),
    );
  }
}

class _CollectDialog extends ConsumerStatefulWidget {
  const _CollectDialog({required this.workflow});

  final LabOrderWorkflow workflow;

  @override
  ConsumerState<_CollectDialog> createState() => _CollectDialogState();
}

class _CollectDialogState extends ConsumerState<_CollectDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _collectedAtController;
  late final TextEditingController _notesController;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _collectedAtController = TextEditingController(
      text: DateTime.now().toIso8601String(),
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _collectedAtController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.labCollectDialogTitle),
      icon: const Icon(Icons.qr_code_scanner_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _collectedAtController,
              labelText: l10n.labCollectedAtLabel,
              hintText: l10n.labDateTimeHint,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
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
        submitLabel: l10n.labCollectSampleAction,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (DateTime.tryParse(_collectedAtController.text.trim()) == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .collectSelected(<String, Object?>{
          'collected_at': _collectedAtController.text.trim(),
          'notes': _notesController.text.trim(),
        });
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

class _ReceiveSampleDialog extends ConsumerStatefulWidget {
  const _ReceiveSampleDialog({required this.workflow});

  final LabOrderWorkflow workflow;

  @override
  ConsumerState<_ReceiveSampleDialog> createState() =>
      _ReceiveSampleDialogState();
}

class _ReceiveSampleDialogState extends ConsumerState<_ReceiveSampleDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _receivedAtController;
  late final TextEditingController _notesController;
  String? _sampleId;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _sampleId = widget.workflow.firstReceivableSample?.apiId;
    _receivedAtController = TextEditingController(
      text: DateTime.now().toIso8601String(),
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _receivedAtController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.labReceiveDialogTitle),
      icon: const Icon(Icons.inventory_2_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>(
              value: _sampleId,
              labelText: l10n.labSampleFieldLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              options: <AppSelectOption<String>>[
                for (final LabSample sample
                    in widget.workflow.order.samples.where(
                  (LabSample sample) => sample.canReceive,
                ))
                  AppSelectOption<String>(
                    value: sample.apiId,
                    label: sample.displayId ?? sample.id,
                  ),
              ],
              onChanged: (String? value) => setState(() => _sampleId = value),
            ),
            AppTextField(
              controller: _receivedAtController,
              labelText: l10n.labReceivedAtLabel,
              hintText: l10n.labDateTimeHint,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
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
        submitLabel: l10n.labReceiveSampleAction,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String? sampleId = _sampleId;
    if (sampleId == null ||
        DateTime.tryParse(_receivedAtController.text.trim()) == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .receiveSample(sampleId, <String, Object?>{
          'received_at': _receivedAtController.text.trim(),
          'notes': _notesController.text.trim(),
        });
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

class _RejectSampleDialog extends ConsumerStatefulWidget {
  const _RejectSampleDialog({required this.workflow});

  final LabOrderWorkflow workflow;

  @override
  ConsumerState<_RejectSampleDialog> createState() =>
      _RejectSampleDialogState();
}

class _RejectSampleDialogState extends ConsumerState<_RejectSampleDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _reasonController;
  late final TextEditingController _notesController;
  String? _sampleId;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _sampleId = widget.workflow.firstRejectableSample?.apiId;
    _reasonController = TextEditingController();
    _notesController = TextEditingController();
  }

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
      title: Text(l10n.labRejectDialogTitle),
      icon: const Icon(Icons.block_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>(
              value: _sampleId,
              labelText: l10n.labSampleFieldLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              options: <AppSelectOption<String>>[
                for (final LabSample sample
                    in widget.workflow.order.samples.where(
                  (LabSample sample) => sample.canReject,
                ))
                  AppSelectOption<String>(
                    value: sample.apiId,
                    label: sample.displayId ?? sample.id,
                  ),
              ],
              onChanged: (String? value) => setState(() => _sampleId = value),
            ),
            AppTextField(
              controller: _reasonController,
              labelText: l10n.labRejectReasonLabel,
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
        submitLabel: l10n.labRejectSampleAction,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String? sampleId = _sampleId;
    if (sampleId == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .rejectSample(sampleId, <String, Object?>{
          'reason': _reasonController.text.trim(),
          'notes': _notesController.text.trim(),
        });
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

class _ReleaseResultDialog extends ConsumerStatefulWidget {
  const _ReleaseResultDialog({required this.workflow});

  final LabOrderWorkflow workflow;

  @override
  ConsumerState<_ReleaseResultDialog> createState() =>
      _ReleaseResultDialogState();
}

class _ReleaseResultDialogState extends ConsumerState<_ReleaseResultDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _valueController;
  late final TextEditingController _unitController;
  late final TextEditingController _textController;
  late final TextEditingController _reportedAtController;
  late final TextEditingController _notesController;
  String? _itemId;
  String _status = 'NORMAL';
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final LabOrderItem? item = widget.workflow.firstReleasableItem;
    _itemId = item?.apiId;
    _valueController = TextEditingController();
    _unitController = TextEditingController(text: item?.unit ?? '');
    _textController = TextEditingController();
    _reportedAtController = TextEditingController(
      text: DateTime.now().toIso8601String(),
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _valueController.dispose();
    _unitController.dispose();
    _textController.dispose();
    _reportedAtController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<LabOrderItem> items = widget.workflow.order.items
        .where((LabOrderItem item) => item.canRelease)
        .toList(growable: false);
    return AppDialog(
      title: Text(l10n.labReleaseDialogTitle),
      icon: const Icon(Icons.verified_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>(
              value: _itemId,
              labelText: l10n.labOrderItemFieldLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              options: <AppSelectOption<String>>[
                for (final LabOrderItem item in items)
                  AppSelectOption<String>(
                    value: item.apiId,
                    label: item.displayTitle,
                  ),
              ],
              onChanged: (String? value) {
                setState(() {
                  _itemId = value;
                  final LabOrderItem? item = _itemFor(value);
                  if (item != null && _unitController.text.trim().isEmpty) {
                    _unitController.text = item.unit ?? '';
                  }
                });
              },
            ),
            AppSelectField<String>(
              value: _status,
              labelText: l10n.labResultStatusLabel,
              enabled: !_isSaving,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: 'NORMAL',
                  label: l10n.labStatusNormal,
                ),
                AppSelectOption<String>(
                  value: 'ABNORMAL',
                  label: l10n.labStatusAbnormal,
                ),
                AppSelectOption<String>(
                  value: 'CRITICAL',
                  label: l10n.labStatusCritical,
                ),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
            ),
            AppTextField(
              controller: _valueController,
              labelText: l10n.labResultValueLabel,
              enabled: !_isSaving,
            ),
            AppTextField(
              controller: _unitController,
              labelText: l10n.labResultUnitLabel,
              enabled: !_isSaving,
            ),
            AppTextField(
              controller: _textController,
              labelText: l10n.labResultTextLabel,
              enabled: !_isSaving,
              maxLines: 3,
            ),
            AppTextField(
              controller: _reportedAtController,
              labelText: l10n.labReportedAtInputLabel,
              hintText: l10n.labDateTimeHint,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _notesController,
              labelText: l10n.labNotesLabel,
              enabled: !_isSaving,
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.labReleaseResultAction,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  LabOrderItem? _itemFor(String? id) {
    for (final LabOrderItem item in widget.workflow.order.items) {
      if (item.apiId == id) {
        return item;
      }
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String? itemId = _itemId;
    if (itemId == null ||
        DateTime.tryParse(_reportedAtController.text.trim()) == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .releaseOrderItem(itemId, <String, Object?>{
          'status': _status,
          'result_value': _valueController.text.trim(),
          'result_unit': _unitController.text.trim(),
          'result_text': _textController.text.trim(),
          'reported_at': _reportedAtController.text.trim(),
          'notes': _notesController.text.trim(),
        });
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

class _CatalogDialog extends StatefulWidget {
  const _CatalogDialog({required this.state});

  final LabWorkspaceState state;

  @override
  State<_CatalogDialog> createState() => _CatalogDialogState();
}

class _CatalogDialogState extends State<_CatalogDialog> {
  late final TextEditingController _searchController;
  String _search = '';

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
    return AppDialog(
      title: Text(l10n.labCatalogTitle),
      icon: const Icon(Icons.menu_book_outlined),
      maxWidth: 760,
      scrollable: true,
      content: AppFormSection(
        children: <Widget>[
          AppSearchField(
            controller: _searchController,
            semanticLabel: l10n.labCatalogSearchLabel,
            hintText: l10n.labCatalogSearchHint,
            onChanged: (String value) => setState(() => _search = value),
            onClear: () => setState(() => _search = ''),
          ),
          SizedBox(
            height: 420,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: <Widget>[
                  TabBar(
                    tabs: <Widget>[
                      Tab(text: l10n.labTestsTabLabel),
                      Tab(text: l10n.labPanelsTabLabel),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        _CatalogReadOnlyList(
                          items: _filtered(widget.state.catalogTests),
                          emptyText: l10n.labNoCatalogItemsLabel,
                        ),
                        _CatalogReadOnlyList(
                          items: _filtered(widget.state.catalogPanels),
                          emptyText: l10n.labNoCatalogItemsLabel,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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

  List<LabCatalogItem> _filtered(List<LabCatalogItem> items) {
    return items
        .where((LabCatalogItem item) => item.matchesSearch(_search))
        .toList(growable: false);
  }
}

class _CatalogReadOnlyList extends StatelessWidget {
  const _CatalogReadOnlyList({required this.items, required this.emptyText});

  final List<LabCatalogItem> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: _EmptyInlineText(text: emptyText));
    }
    return ListView.separated(
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final LabCatalogItem item = items[index];
        return _CompactRecordRow(
          title: item.displayTitle,
          subtitle: item.displaySubtitle,
          leading: item.isPanel
              ? Icons.account_tree_outlined
              : Icons.science_outlined,
          trailing: item.isPanel
              ? Text(
                  AppFormatters.compactNumber(
                    item.testCount,
                    Localizations.localeOf(context),
                  ),
                )
              : null,
        );
      },
      separatorBuilder: (_, _) => const Divider(height: 1),
    );
  }
}

Future<void> _openOrderDialog(
  BuildContext context,
  LabWorkspaceState state,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RequestOrderDialog(state: state),
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

Future<void> _openCollectDialog(
  BuildContext context,
  LabOrderWorkflow workflow,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CollectDialog(workflow: workflow),
    ),
  );
}

Future<void> _openReceiveDialog(
  BuildContext context,
  LabOrderWorkflow workflow,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReceiveSampleDialog(workflow: workflow),
    ),
  );
}

Future<void> _openRejectDialog(
  BuildContext context,
  LabOrderWorkflow workflow,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RejectSampleDialog(workflow: workflow),
    ),
  );
}

Future<void> _openReleaseDialog(
  BuildContext context,
  LabOrderWorkflow workflow,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReleaseResultDialog(workflow: workflow),
    ),
  );
}

Future<void> _openReverseDialog(
  BuildContext context,
  LabOrderWorkflow workflow,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ReverseWorkflowDialog(),
    ),
  );
}

Future<void> _openCatalogDialog(
  BuildContext context,
  LabWorkspaceState state,
) async {
  await showAppDialog<void>(
    context: context,
    builder: (_) => _CatalogDialog(state: state),
  );
}

Future<void> _showActionResult(
  BuildContext context,
  Future<bool?> result,
) async {
  final bool? saved = await result;
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.labSavedMessage)),
    );
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

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.failureMessage(failure))),
  );
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

AppWorkspaceStatus _sampleStatus(
  BuildContext context,
  LabOrderSummary order,
) {
  if (order.hasRejectedSample) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusRejected,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.block_outlined,
    );
  }
  if (order.samples.isEmpty) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusPending,
      tone: AppWorkspaceStatusTone.warning,
      icon: Icons.pending_outlined,
    );
  }
  final bool received = order.samples.any(
    (LabSample sample) => (sample.status ?? '').toUpperCase() == 'RECEIVED',
  );
  if (received) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusReceived,
      tone: AppWorkspaceStatusTone.success,
      icon: Icons.inventory_2_outlined,
    );
  }
  final bool collected = order.samples.any(
    (LabSample sample) => (sample.status ?? '').toUpperCase() == 'COLLECTED',
  );
  return AppWorkspaceStatus(
    label: collected
        ? context.l10n.labStatusCollected
        : context.l10n.labStatusPending,
    tone: collected ? AppWorkspaceStatusTone.info : AppWorkspaceStatusTone.warning,
    icon: collected ? Icons.biotech_outlined : Icons.pending_outlined,
  );
}

AppWorkspaceStatus _resultStatus(
  BuildContext context,
  LabOrderSummary order,
) {
  if (order.hasCriticalResult) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusCritical,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.priority_high_outlined,
    );
  }
  if (order.completedItemCount > 0 && order.completedItemCount >= order.itemCount) {
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
    tone: AppWorkspaceStatusTone.neutral,
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
  return switch (status) {
    'ORDERED' => l10n.labNextActionCollect,
    'COLLECTED' => l10n.labNextActionReceive,
    'IN_PROCESS' => l10n.labNextActionRelease,
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
  return AppFormatters.dateTime(value.toLocal(), Localizations.localeOf(context));
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
    '${l10n.labReportPatientLabel}: ${_joinDisplay(<String?>[order.patientDisplayName, order.patientId]) ?? l10n.profileUnknownValue}',
    '${l10n.labReportOrderLabel}: ${order.displayId ?? order.id}',
    '${l10n.labEncounterFieldLabel}: ${order.encounterId ?? l10n.profileUnknownValue}',
    for (final LabResult result in workflow.results) ...<String>[
      result.displayTitle,
      '${l10n.labReportResultLabel}: ${result.displayValue ?? l10n.profileUnknownValue}',
      '${l10n.labReportRangeLabel}: ${result.referenceRangeSummary ?? l10n.profileUnknownValue}',
      '${l10n.labReportVerifiedLabel}: ${_dateTimeLabel(context, result.reportedAt)}',
    ],
    l10n.labReportFooter,
  ];
  return lines.join('\n');
}

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
  return joined.isEmpty ? null : joined;
}
