import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/presentation/controllers/claims_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

class ClaimsWorkspacePage extends ConsumerWidget {
  const ClaimsWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Result<ClaimsWorkspaceState>> value = ref.watch(
      claimsWorkspaceControllerProvider,
    );
    final AppLocalizations l10n = context.l10n;

    return value.when(
      data: (Result<ClaimsWorkspaceState> result) {
        return result.when(
          success: (ClaimsWorkspaceState state) {
            return _ClaimsWorkspaceContent(state: state);
          },
          failure: (AppFailure failure) {
            return ResponsivePage(
              maxWidth: PageMaxWidth.form,
              centerVertically: true,
              child: AppFailureStateView(
                failure: failure,
                title: l10n.claimsLoadErrorTitle,
                body: l10n.claimsLoadErrorBody,
                onRetry: () {
                  ref.invalidate(claimsWorkspaceControllerProvider);
                },
              ),
            );
          },
        );
      },
      error: (_, _) {
        return ResponsivePage(
          maxWidth: PageMaxWidth.form,
          centerVertically: true,
          child: AppStateView(
            variant: AppStateViewVariant.error,
            title: l10n.claimsLoadErrorTitle,
            body: l10n.errorUnexpectedMessage,
          ),
        );
      },
      loading: () {
        return ResponsivePage(
          maxWidth: PageMaxWidth.form,
          centerVertically: true,
          child: AppWorkspaceStatePanel.loading(
            title: l10n.claimsLoadingTitle,
            body: l10n.claimsLoadingBody,
          ),
        );
      },
    );
  }
}

class _ClaimsWorkspaceContent extends ConsumerStatefulWidget {
  const _ClaimsWorkspaceContent({required this.state});

  final ClaimsWorkspaceState state;

  @override
  ConsumerState<_ClaimsWorkspaceContent> createState() {
    return _ClaimsWorkspaceContentState();
  }
}

class _ClaimsWorkspaceContentState
    extends ConsumerState<_ClaimsWorkspaceContent> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<ClaimsQueueItem>
  _tableColumnController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<ClaimsQueueItem>();
  }

  @override
  void didUpdateWidget(covariant _ClaimsWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String search = widget.state.query.search;
    if (_searchController.text != search) {
      _searchController.value = TextEditingValue(text: search);
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
    final ClaimsWorkspaceState state = widget.state;
    final ClaimsWorkspaceController controller = ref.read(
      claimsWorkspaceControllerProvider.notifier,
    );
    final int allCount = state.queue.totalItemCount ?? state.queue.items.length;
    final int authorizationDeniedCount = _claimsCountForFilter(
      state,
      ClaimsQueueFilter.authorizationDenied,
    );
    final int rejectedClaimsCount = _claimsCountForFilter(
      state,
      ClaimsQueueFilter.claimRejected,
    );
    final int paidClaimsCount = _claimsCountForFilter(
      state,
      ClaimsQueueFilter.claimPaid,
    );
    final int cancelledClaimsCount = _claimsCountForFilter(
      state,
      ClaimsQueueFilter.claimCancelled,
    );

    return AppWorkspace(
      title: l10n.claimsWorkspaceTitle,
      leadingIcon: AppRouteIcons.claims,
      status: AppWorkspaceStatus(
        label: state.lastFailure == null
            ? l10n.claimsOperationalStatusLabel
            : l10n.claimsNeedsAttentionStatusLabel,
        tone: state.lastFailure == null
            ? AppWorkspaceStatusTone.success
            : AppWorkspaceStatusTone.warning,
      ),
      primaryAction: AppButton.primary(
        label: l10n.claimsRequestAuthorizationAction,
        leadingIcon: Icons.verified_user_outlined,
        isLoading: state.isSaving,
        onPressed: () {
          unawaited(
            _openRequestAuthorizationDialog(context, controller, state),
          );
        },
      ),
      secondaryActions: <Widget>[
        AppButton.secondary(
          label: l10n.claimsPrepareClaimAction,
          leadingIcon: Icons.receipt_long_outlined,
          isLoading: state.isSaving,
          onPressed: () {
            unawaited(_openPrepareClaimDialog(context, controller, state));
          },
        ),
        AppButton.tertiary(
          label: l10n.commonRefreshActionLabel,
          leadingIcon: Icons.refresh,
          isLoading: state.isRefreshing,
          onPressed: () async {
            final AppFailure? failure = await controller.refresh();
            if (context.mounted) {
              _showFailureIfNeeded(context, failure);
            }
          },
        ),
      ],
      compactSummaryCards: true,
      summaryCards: <Widget>[
        if (allCount > 0)
          AppWorkspaceSummaryCard(
            compact: true,
            label: l10n.claimsFilterAll,
            value: allCount.toString(),
            icon: Icons.inventory_2_outlined,
            onPressed: () {
              unawaited(_applySummaryFilter(controller, ClaimsQueueFilter.all));
            },
          ),
        if (state.authorizationPendingCount > 0)
          AppWorkspaceSummaryCard(
            compact: true,
            label: l10n.claimsAuthorizationPendingSummaryLabel,
            value: state.authorizationPendingCount.toString(),
            icon: Icons.schedule_outlined,
            tone: AppWorkspaceStatusTone.warning,
            onPressed: () {
              unawaited(
                _applySummaryFilter(
                  controller,
                  ClaimsQueueFilter.authorizationPending,
                ),
              );
            },
          ),
        if (state.authorizationApprovedCount > 0)
          AppWorkspaceSummaryCard(
            compact: true,
            label: l10n.claimsAuthorizationApprovedSummaryLabel,
            value: state.authorizationApprovedCount.toString(),
            icon: Icons.verified_outlined,
            tone: AppWorkspaceStatusTone.success,
            onPressed: () {
              unawaited(
                _applySummaryFilter(
                  controller,
                  ClaimsQueueFilter.authorizationApproved,
                ),
              );
            },
          ),
        if (state.submittedClaimsCount > 0)
          AppWorkspaceSummaryCard(
            compact: true,
            label: l10n.claimsSubmittedSummaryLabel,
            value: state.submittedClaimsCount.toString(),
            icon: Icons.outbox_outlined,
            tone: AppWorkspaceStatusTone.info,
            onPressed: () {
              unawaited(
                _applySummaryFilter(
                  controller,
                  ClaimsQueueFilter.claimSubmitted,
                ),
              );
            },
          ),
        if (authorizationDeniedCount > 0)
          AppWorkspaceSummaryCard(
            compact: true,
            label: l10n.claimsFilterAuthorizationDenied,
            value: authorizationDeniedCount.toString(),
            icon: Icons.report_gmailerrorred_outlined,
            tone: AppWorkspaceStatusTone.error,
            onPressed: () {
              unawaited(
                _applySummaryFilter(
                  controller,
                  ClaimsQueueFilter.authorizationDenied,
                ),
              );
            },
          ),
        if (rejectedClaimsCount > 0)
          AppWorkspaceSummaryCard(
            compact: true,
            label: l10n.claimsFilterClaimRejected,
            value: rejectedClaimsCount.toString(),
            icon: Icons.report_gmailerrorred_outlined,
            tone: AppWorkspaceStatusTone.error,
            onPressed: () {
              unawaited(
                _applySummaryFilter(
                  controller,
                  ClaimsQueueFilter.claimRejected,
                ),
              );
            },
          ),
        if (state.approvedClaimsCount > 0)
          AppWorkspaceSummaryCard(
            compact: true,
            label: l10n.claimsApprovedSummaryLabel,
            value: state.approvedClaimsCount.toString(),
            icon: Icons.fact_check_outlined,
            tone: AppWorkspaceStatusTone.success,
            onPressed: () {
              unawaited(
                _applySummaryFilter(
                  controller,
                  ClaimsQueueFilter.claimApproved,
                ),
              );
            },
          ),
        if (paidClaimsCount > 0)
          AppWorkspaceSummaryCard(
            compact: true,
            label: l10n.claimsFilterClaimPaid,
            value: paidClaimsCount.toString(),
            icon: Icons.task_alt_outlined,
            tone: AppWorkspaceStatusTone.neutral,
            onPressed: () {
              unawaited(
                _applySummaryFilter(controller, ClaimsQueueFilter.claimPaid),
              );
            },
          ),
        if (cancelledClaimsCount > 0)
          AppWorkspaceSummaryCard(
            compact: true,
            label: l10n.claimsFilterClaimCancelled,
            value: cancelledClaimsCount.toString(),
            icon: Icons.cancel_outlined,
            tone: AppWorkspaceStatusTone.neutral,
            onPressed: () {
              unawaited(
                _applySummaryFilter(
                  controller,
                  ClaimsQueueFilter.claimCancelled,
                ),
              );
            },
          ),
      ],
      body: _ClaimsQueuePanel(
        state: state,
        searchController: _searchController,
        columnVisibilityController: _tableColumnController,
      ),
    );
  }

  Future<void> _applySummaryFilter(
    ClaimsWorkspaceController controller,
    ClaimsQueueFilter filter,
  ) async {
    final AppFailure? failure = await controller.applyFilter(filter);
    if (mounted) {
      _showFailureIfNeeded(context, failure);
    }
  }
}

class _ClaimsQueuePanel extends ConsumerWidget {
  const _ClaimsQueuePanel({
    required this.state,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final ClaimsWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<ClaimsQueueItem>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ClaimsWorkspaceController controller = ref.read(
      claimsWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.claimsWorklistTitle,
      description: l10n.claimsWorklistDescription,
      child: SizedBox(
        height: 520,
        child: AppListTable<ClaimsQueueItem>(
          page: state.queue,
          isLoading: state.isRefreshing,
          columnVisibilityController: columnVisibilityController,
          columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
          search: AppListTableSearch<ClaimsQueueItem>(
            controller: searchController,
            semanticLabel: l10n.claimsSearchSemanticLabel,
            hintText: l10n.claimsSearchHint,
            matcher: (_, _) => true,
            onSubmitted: (String value) async {
              final AppFailure? failure = await controller.applySearch(value);
              if (context.mounted) {
                _showFailureIfNeeded(context, failure);
              }
            },
            onClear: () async {
              final AppFailure? failure = await controller.applySearch('');
              if (context.mounted) {
                _showFailureIfNeeded(context, failure);
              }
            },
            showAdvancedFilterButton: true,
            advancedFilterButtonLabel: l10n.claimsQueueFilterLabel,
            advancedFilterTitle: l10n.claimsQueueFilterLabel,
            advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
            advancedFilterResetLabel: l10n.opdClearFiltersAction,
            advancedFilterCancelLabel: l10n.commonCancelActionLabel,
            enableDateFilter: false,
            allFieldsLabel: l10n.claimsFilterAll,
            filterGroups: <AppSearchBarFilterGroup>[
              AppSearchBarFilterGroup(
                key: _claimsQueueFilterKey,
                label: l10n.claimsQueueFilterLabel,
                allLabel: l10n.claimsFilterAll,
                choices: _claimsQueueFilterChoices(l10n),
              ),
            ],
            filterValue: _claimsFilterValue(state.query),
            hasActiveFilters: state.query.filter != ClaimsQueueFilter.all,
            onFilterChanged: (AppSearchBarFilterValue value) async {
              final AppFailure? failure = await controller.applyFilter(
                _claimsFilterFromValue(value.option(_claimsQueueFilterKey)),
              );
              if (context.mounted) {
                _showFailureIfNeeded(context, failure);
              }
            },
          ),
          previousPageLabel: l10n.claimsPreviousPageLabel,
          nextPageLabel: l10n.claimsNextPageLabel,
          pageLabelBuilder: (AppPage<ClaimsQueueItem> page) {
            return l10n.claimsPageLabel(
              page.firstItemNumber,
              page.lastItemNumber,
              page.totalItemCount ?? page.items.length,
            );
          },
          onPageChanged: (AppPageRequest request) {
            unawaited(controller.changePage(request));
          },
          onRowSelected: (ClaimsQueueItem item) {
            unawaited(_openClaimsDetailDialog(context, ref, state, item));
          },
          emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
            title: l10n.claimsEmptyQueueTitle,
            body: l10n.claimsEmptyQueueBody,
            icon: Icons.inbox_outlined,
          ),
          columns: <AppListTableColumn<ClaimsQueueItem>>[
            AppListTableColumn<ClaimsQueueItem>(
              label: l10n.claimsTypeColumnLabel,
              sortComparator: (ClaimsQueueItem left, ClaimsQueueItem right) =>
                  appListTableCompareText(left.kind.name, right.kind.name),
              cellBuilder: (BuildContext context, ClaimsQueueItem item) {
                return Text(_kindLabel(context, item.kind));
              },
            ),
            AppListTableColumn<ClaimsQueueItem>(
              label: l10n.claimsReferenceColumnLabel,
              sortComparator: (ClaimsQueueItem left, ClaimsQueueItem right) =>
                  appListTableCompareText(left.displayId, right.displayId),
              cellBuilder: (BuildContext context, ClaimsQueueItem item) {
                return Text(item.displayId);
              },
            ),
            AppListTableColumn<ClaimsQueueItem>(
              label: l10n.claimsCoverageColumnLabel,
              sortComparator: (ClaimsQueueItem left, ClaimsQueueItem right) =>
                  appListTableCompareText(
                    left.coveragePlanDisplayId,
                    right.coveragePlanDisplayId,
                  ),
              cellBuilder: (BuildContext context, ClaimsQueueItem item) {
                return Text(_fallback(context, item.coveragePlanDisplayId));
              },
            ),
            AppListTableColumn<ClaimsQueueItem>(
              label: l10n.claimsInvoiceColumnLabel,
              sortComparator: (ClaimsQueueItem left, ClaimsQueueItem right) =>
                  appListTableCompareText(
                    left.invoiceDisplayId,
                    right.invoiceDisplayId,
                  ),
              cellBuilder: (BuildContext context, ClaimsQueueItem item) {
                return Text(_fallback(context, item.invoiceDisplayId));
              },
            ),
            AppListTableColumn<ClaimsQueueItem>(
              label: l10n.claimsStatusColumnLabel,
              sortComparator: (ClaimsQueueItem left, ClaimsQueueItem right) =>
                  appListTableCompareText(left.status, right.status),
              cellBuilder: (BuildContext context, ClaimsQueueItem item) {
                return AppWorkspaceStatusBadge(
                  status: _statusFor(context, item),
                );
              },
            ),
            AppListTableColumn<ClaimsQueueItem>(
              label: l10n.claimsTimelineColumnLabel,
              sortComparator: (ClaimsQueueItem left, ClaimsQueueItem right) =>
                  appListTableCompareDateTime(
                    left.timelineAt,
                    right.timelineAt,
                  ),
              cellBuilder: (BuildContext context, ClaimsQueueItem item) {
                return Text(_dateTimeLabel(context, item.timelineAt));
              },
            ),
          ],
          mobileItemBuilder: (BuildContext context, ClaimsQueueItem item) {
            return _MobileQueueItem(item: item);
          },
        ),
      ),
    );
  }
}

class _MobileQueueItem extends StatelessWidget {
  const _MobileQueueItem({required this.item});

  final ClaimsQueueItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.all(theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(_kindIcon(item.kind), size: theme.appTokens.listIconSize),
              SizedBox(width: theme.spacing.xs),
              Expanded(
                child: Text(
                  '${_kindLabel(context, item.kind)} ${item.displayId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              AppWorkspaceStatusBadge(status: _statusFor(context, item)),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            l10n.claimsMobileQueueSubtitle(
              _fallback(context, item.coveragePlanDisplayId),
              _fallback(
                context,
                item.invoiceDisplayId ?? item.patientDisplayId,
              ),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            _dateTimeLabel(context, item.timelineAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openClaimsDetailDialog(
  BuildContext context,
  WidgetRef ref,
  ClaimsWorkspaceState fallbackState,
  ClaimsQueueItem item,
) async {
  final ClaimsWorkspaceController controller = ref.read(
    claimsWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectItem(item);
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }

  final ClaimsWorkspaceState state = _readClaimsState(ref) ?? fallbackState;
  final ClaimsQueueDetail? detail = state.selectedDetail;
  if (detail == null) {
    return;
  }
  final AppLocalizations l10n = context.l10n;

  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.claimsDetailTitle),
      icon: const Icon(Icons.fact_check_outlined),
      scrollable: true,
      maxWidth: 960,
      content: _ClaimsDetailContent(state: state, detail: detail),
      actions: <Widget>[
        AppReportActionButton.print(
          label: l10n.claimsPrintStatementAction,
          onPressed: () async {
            final String title = detail.isAuthorization
                ? l10n.claimsAuthorizationStatementTitle
                : l10n.claimsClaimStatementTitle;
            await printFormTemplateDocument(
              ref: ref,
              context: context,
              title: title,
              subtitle: detail.item.displayId,
              bodyHtml: _claimsStatementHtml(context, detail),
              footerNote: l10n.claimsReportFooter,
            );
          },
        ),
      ],
    ),
  );
}

ClaimsWorkspaceState? _readClaimsState(WidgetRef ref) {
  return ref
      .read(claimsWorkspaceControllerProvider)
      .asData
      ?.value
      .when(
        success: (ClaimsWorkspaceState state) => state,
        failure: (_) => null,
      );
}

class _ClaimsDetailContent extends ConsumerWidget {
  const _ClaimsDetailContent({required this.state, required this.detail});

  final ClaimsWorkspaceState state;
  final ClaimsQueueDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ClaimsWorkspaceController controller = ref.read(
      claimsWorkspaceControllerProvider.notifier,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppWorkspacePatientContextHeader(
          patientName: _detailTitle(context, detail),
          patientNumber: _detailNumber(context, detail),
          demographics: _detailSubtitle(context, detail),
          semanticLabel: l10n.claimsPatientContextLabel,
          status: _statusFor(context, detail.item),
          fields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: l10n.claimsCoverageFieldLabel,
              value: _coverageLabel(context, detail),
              icon: Icons.verified_user_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.claimsPayerFieldLabel,
              value:
                  detail.coveragePlan?.providerName ??
                  l10n.claimsUnknownPayerLabel,
              icon: Icons.business_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.claimsInvoiceFieldLabel,
              value: _fallback(context, detail.claim?.invoiceDisplayId),
              icon: Icons.receipt_long_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.claimsAmountFieldLabel,
              value: _amountLabel(context, detail.invoice),
              icon: Icons.payments_outlined,
            ),
          ],
          actions: _detailActions(context, controller, state, detail),
        ),
        SizedBox(height: theme.spacing.lg),
        _BillingImpactPanel(detail: detail),
        SizedBox(height: theme.spacing.lg),
        _RequiredDocumentsPanel(detail: detail),
        SizedBox(height: theme.spacing.lg),
        _TimelinePanel(detail: detail),
      ],
    );
  }
}

class _BillingImpactPanel extends StatelessWidget {
  const _BillingImpactPanel({required this.detail});

  final ClaimsQueueDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ClaimInvoiceOption? invoice = detail.invoice;
    final CoveragePlanOption? coverage = detail.coveragePlan;
    final String body = detail.isAuthorization
        ? l10n.claimsAuthorizationBillingImpactBody
        : _claimBillingImpact(context, detail);

    return AppWorkspaceDetailPanel(
      title: l10n.claimsBillingImpactTitle,
      description: body,
      child: Wrap(
        spacing: Theme.of(context).spacing.sm,
        runSpacing: Theme.of(context).spacing.sm,
        children: <Widget>[
          _InfoTile(
            icon: Icons.verified_user_outlined,
            label: l10n.claimsCoveragePercentLabel,
            value: coverage?.coveragePercentage == null
                ? l10n.profileUnknownValue
                : l10n.claimsCoveragePercentValue(
                    coverage!.coveragePercentage!.toString(),
                  ),
          ),
          _InfoTile(
            icon: Icons.receipt_long_outlined,
            label: l10n.claimsInvoiceStatusLabel,
            value: _invoiceStatusLabel(context, invoice),
          ),
          _InfoTile(
            icon: Icons.payments_outlined,
            label: l10n.claimsPatientBalanceLabel,
            value: _patientBalanceLabel(context, detail),
          ),
        ],
      ),
    );
  }
}

class _RequiredDocumentsPanel extends StatelessWidget {
  const _RequiredDocumentsPanel({required this.detail});

  final ClaimsQueueDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppWorkspaceStatus> statuses = <AppWorkspaceStatus>[
      AppWorkspaceStatus(
        label: l10n.claimsDocumentInvoiceSummary,
        tone: detail.invoice == null && detail.isClaim
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
        icon: detail.invoice == null && detail.isClaim
            ? Icons.schedule_outlined
            : Icons.check_circle_outline,
      ),
      AppWorkspaceStatus(
        label: l10n.claimsDocumentCoveragePlan,
        tone: detail.coveragePlan == null
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
        icon: detail.coveragePlan == null
            ? Icons.schedule_outlined
            : Icons.check_circle_outline,
      ),
      AppWorkspaceStatus(
        label: l10n.claimsDocumentPayerResponse,
        tone: _hasPayerResponse(detail)
            ? AppWorkspaceStatusTone.success
            : AppWorkspaceStatusTone.info,
        icon: _hasPayerResponse(detail)
            ? Icons.check_circle_outline
            : Icons.info_outline,
      ),
    ];

    return AppWorkspaceDetailPanel(
      title: l10n.claimsRequiredDocumentsTitle,
      description: l10n.claimsRequiredDocumentsBody,
      child: Wrap(
        spacing: Theme.of(context).spacing.sm,
        runSpacing: Theme.of(context).spacing.sm,
        children: <Widget>[
          for (final AppWorkspaceStatus status in statuses)
            AppWorkspaceStatusBadge(status: status),
        ],
      ),
    );
  }
}

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({required this.detail});

  final ClaimsQueueDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppWorkspaceActivityItem> items = <AppWorkspaceActivityItem>[
      if (detail.authorization?.requestedAt != null)
        AppWorkspaceActivityItem(
          title: l10n.claimsTimelineAuthorizationRequested,
          subtitle: _dateTimeLabel(context, detail.authorization!.requestedAt),
          icon: Icons.schedule_outlined,
          tone: AppWorkspaceStatusTone.info,
        ),
      if (detail.authorization?.approvedAt != null)
        AppWorkspaceActivityItem(
          title: l10n.claimsTimelineAuthorizationResponded,
          subtitle: _dateTimeLabel(context, detail.authorization!.approvedAt),
          icon: Icons.verified_outlined,
          tone: AppWorkspaceStatusTone.success,
        ),
      if (detail.claim?.submittedAt != null)
        AppWorkspaceActivityItem(
          title: l10n.claimsTimelineClaimSubmitted,
          subtitle: _dateTimeLabel(context, detail.claim!.submittedAt),
          icon: Icons.outbox_outlined,
          tone: AppWorkspaceStatusTone.info,
        ),
      AppWorkspaceActivityItem(
        title: l10n.claimsTimelineCurrentStatus,
        subtitle: _statusLabel(context, detail.item),
        icon: _kindIcon(detail.item.kind),
        tone: _statusTone(detail.item),
      ),
    ];

    return AppWorkspaceActivityList(
      title: l10n.claimsTimelineTitle,
      description: l10n.claimsTimelineDescription,
      items: items,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return SizedBox(
      width: 220,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          color: colorScheme.surface,
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: theme.appTokens.listIconSize),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: theme.textTheme.labelLarge),
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoveragePlanDialog extends StatefulWidget {
  const _CoveragePlanDialog({
    required this.coveragePlans,
    required this.onSubmit,
  });

  final List<CoveragePlanOption> coveragePlans;
  final Future<AppFailure?> Function(String coveragePlanId) onSubmit;

  @override
  State<_CoveragePlanDialog> createState() => _CoveragePlanDialogState();
}

class _CoveragePlanDialogState extends State<_CoveragePlanDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _coveragePlanId;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormShell(
      formKey: _formKey,
      formStatus: _failure == null
          ? null
          : AppFailureStateView(failure: _failure!),
      children: <Widget>[
        AppSelectField<String>.searchable(
          labelText: l10n.claimsCoveragePlanFieldLabel,
          hintText: l10n.claimsCoveragePlanHint,
          value: _coveragePlanId,
          isRequired: true,
          enabled: widget.coveragePlans.isNotEmpty,
          validator: AppValidators.requiredValue<String>(
            l10n.claimsCoveragePlanRequiredMessage,
          ),
          options: _coveragePlanOptions(widget.coveragePlans),
          onChanged: (String? value) {
            setState(() {
              _coveragePlanId = value;
            });
          },
        ),
        if (widget.coveragePlans.isEmpty)
          AppWorkspaceStatePanel.state(
            variant: AppStateViewVariant.validation,
            title: l10n.claimsCoverageUnavailableTitle,
            body: l10n.claimsCoverageUnavailableBody,
            minHeight: 120,
          ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.claimsRequestAuthorizationSubmitAction,
          submitIcon: Icons.verified_user_outlined,
          isSubmitting: _isSubmitting,
          enabled: widget.coveragePlans.isNotEmpty,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(_coveragePlanId!);
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
}

class _PrepareClaimDialog extends StatefulWidget {
  const _PrepareClaimDialog({
    required this.coveragePlans,
    required this.invoices,
    required this.onSubmit,
  });

  final List<CoveragePlanOption> coveragePlans;
  final List<ClaimInvoiceOption> invoices;
  final Future<AppFailure?> Function({
    required String coveragePlanId,
    required String invoiceId,
  })
  onSubmit;

  @override
  State<_PrepareClaimDialog> createState() => _PrepareClaimDialogState();
}

class _PrepareClaimDialogState extends State<_PrepareClaimDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _coveragePlanId;
  String? _invoiceId;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool hasRequiredData =
        widget.coveragePlans.isNotEmpty && widget.invoices.isNotEmpty;

    return AppFormShell(
      formKey: _formKey,
      formStatus: _failure == null
          ? null
          : AppFailureStateView(failure: _failure!),
      children: <Widget>[
        AppSelectField<String>.searchable(
          labelText: l10n.claimsCoveragePlanFieldLabel,
          hintText: l10n.claimsCoveragePlanHint,
          value: _coveragePlanId,
          isRequired: true,
          enabled: widget.coveragePlans.isNotEmpty,
          validator: AppValidators.requiredValue<String>(
            l10n.claimsCoveragePlanRequiredMessage,
          ),
          options: _coveragePlanOptions(widget.coveragePlans),
          onChanged: (String? value) {
            setState(() {
              _coveragePlanId = value;
            });
          },
        ),
        AppSelectField<String>.searchable(
          labelText: l10n.claimsInvoiceFieldLabel,
          hintText: l10n.claimsInvoiceHint,
          value: _invoiceId,
          isRequired: true,
          enabled: widget.invoices.isNotEmpty,
          validator: AppValidators.requiredValue<String>(
            l10n.claimsInvoiceRequiredMessage,
          ),
          options: _invoiceOptions(context, widget.invoices),
          onChanged: (String? value) {
            setState(() {
              _invoiceId = value;
            });
          },
        ),
        if (!hasRequiredData)
          AppWorkspaceStatePanel.state(
            variant: AppStateViewVariant.validation,
            title: l10n.claimsPrepareClaimUnavailableTitle,
            body: l10n.claimsPrepareClaimUnavailableBody,
            minHeight: 120,
          ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.claimsPrepareClaimSubmitAction,
          submitIcon: Icons.receipt_long_outlined,
          isSubmitting: _isSubmitting,
          enabled: hasRequiredData,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      coveragePlanId: _coveragePlanId!,
      invoiceId: _invoiceId!,
    );
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
}

class _AuthorizationStatusDialog extends StatefulWidget {
  const _AuthorizationStatusDialog({
    required this.currentStatus,
    required this.onSubmit,
  });

  final String currentStatus;
  final Future<AppFailure?> Function(String status) onSubmit;

  @override
  State<_AuthorizationStatusDialog> createState() {
    return _AuthorizationStatusDialogState();
  }
}

class _AuthorizationStatusDialogState
    extends State<_AuthorizationStatusDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late String _status;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _status = widget.currentStatus.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormShell(
      formKey: _formKey,
      formStatus: _failure == null
          ? null
          : AppFailureStateView(failure: _failure!),
      children: <Widget>[
        AppSelectField<String>(
          labelText: l10n.claimsAuthorizationStatusFieldLabel,
          value: _status,
          isRequired: true,
          options: _authorizationStatusOptions(l10n),
          validator: AppValidators.requiredValue<String>(
            l10n.claimsStatusRequiredMessage,
          ),
          onChanged: (String? value) {
            setState(() {
              _status = value ?? _status;
            });
          },
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.claimsUpdateStatusSubmitAction,
          submitIcon: Icons.fact_check_outlined,
          isSubmitting: _isSubmitting,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(_status);
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
}

class _ClaimSubmitDialog extends StatefulWidget {
  const _ClaimSubmitDialog({required this.onSubmit});

  final Future<AppFailure?> Function(String notes) onSubmit;

  @override
  State<_ClaimSubmitDialog> createState() => _ClaimSubmitDialogState();
}

class _ClaimSubmitDialogState extends State<_ClaimSubmitDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;
  AppFailure? _failure;

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
      formStatus: _failure == null
          ? null
          : AppFailureStateView(failure: _failure!),
      children: <Widget>[
        AppTextField(
          controller: _notesController,
          labelText: l10n.claimsNotesFieldLabel,
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.claimsSubmitClaimSubmitAction,
          submitIcon: Icons.outbox_outlined,
          isSubmitting: _isSubmitting,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      _notesController.text.trim(),
    );
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
}

class _ClaimResponseDialog extends StatefulWidget {
  const _ClaimResponseDialog({
    required this.initialStatus,
    required this.submitLabel,
    required this.onSubmit,
  });

  final String initialStatus;
  final String submitLabel;
  final Future<AppFailure?> Function({
    required String status,
    required String notes,
  })
  onSubmit;

  @override
  State<_ClaimResponseDialog> createState() => _ClaimResponseDialogState();
}

class _ClaimResponseDialogState extends State<_ClaimResponseDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  late String _status;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
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
      formStatus: _failure == null
          ? null
          : AppFailureStateView(failure: _failure!),
      children: <Widget>[
        AppSelectField<String>(
          labelText: l10n.claimsClaimResponseFieldLabel,
          value: _status,
          isRequired: true,
          options: _claimResponseOptions(l10n),
          validator: AppValidators.requiredValue<String>(
            l10n.claimsStatusRequiredMessage,
          ),
          onChanged: (String? value) {
            setState(() {
              _status = value ?? _status;
            });
          },
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.claimsNotesFieldLabel,
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: widget.submitLabel,
          submitIcon: Icons.fact_check_outlined,
          isSubmitting: _isSubmitting,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      status: _status,
      notes: _notesController.text.trim(),
    );
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
}

Future<void> _openRequestAuthorizationDialog(
  BuildContext context,
  ClaimsWorkspaceController controller,
  ClaimsWorkspaceState state,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.claimsRequestAuthorizationDialogTitle),
    content: _CoveragePlanDialog(
      coveragePlans: state.referenceData.coveragePlans,
      onSubmit: (String coveragePlanId) {
        return controller.requestPreAuthorization(
          coveragePlanId: coveragePlanId,
        );
      },
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

Future<void> _openPrepareClaimDialog(
  BuildContext context,
  ClaimsWorkspaceController controller,
  ClaimsWorkspaceState state,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.claimsPrepareClaimDialogTitle),
    content: _PrepareClaimDialog(
      coveragePlans: state.referenceData.coveragePlans,
      invoices: state.referenceData.invoices,
      onSubmit: controller.prepareClaim,
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

Future<void> _openAuthorizationStatusDialog(
  BuildContext context,
  ClaimsWorkspaceController controller,
  ClaimsQueueDetail detail,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.claimsUpdateAuthorizationDialogTitle),
    content: _AuthorizationStatusDialog(
      currentStatus: detail.item.status,
      onSubmit: (String status) {
        return controller.updateAuthorizationStatus(status: status);
      },
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

Future<void> _openSubmitClaimDialog(
  BuildContext context,
  ClaimsWorkspaceController controller,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.claimsSubmitClaimDialogTitle),
    content: _ClaimSubmitDialog(
      onSubmit: (String notes) {
        return controller.submitClaim(notes: notes);
      },
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

Future<void> _openClaimResponseDialog(
  BuildContext context,
  ClaimsWorkspaceController controller, {
  required String initialStatus,
  required String title,
  required String submitLabel,
}) async {
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(title),
    content: _ClaimResponseDialog(
      initialStatus: initialStatus,
      submitLabel: submitLabel,
      onSubmit: controller.reconcileClaim,
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

List<Widget> _detailActions(
  BuildContext context,
  ClaimsWorkspaceController controller,
  ClaimsWorkspaceState state,
  ClaimsQueueDetail detail,
) {
  final AppLocalizations l10n = context.l10n;
  if (detail.isAuthorization) {
    return <Widget>[
      AppButton.secondary(
        label: l10n.claimsUpdateStatusAction,
        leadingIcon: Icons.fact_check_outlined,
        isLoading: state.isSaving,
        onPressed: () {
          unawaited(
            _openAuthorizationStatusDialog(context, controller, detail),
          );
        },
      ),
    ];
  }

  final String status = detail.item.status.toUpperCase();
  final bool canSubmit = status != 'PAID' && status != 'CANCELLED';
  final bool canRecord = status != 'PAID' && status != 'CANCELLED';

  return <Widget>[
    AppButton.secondary(
      label: status == 'REJECTED'
          ? l10n.claimsResubmitClaimAction
          : l10n.claimsSubmitClaimAction,
      leadingIcon: Icons.outbox_outlined,
      isLoading: state.isSaving,
      enabled: canSubmit,
      onPressed: () {
        unawaited(_openSubmitClaimDialog(context, controller));
      },
    ),
    AppButton.secondary(
      label: l10n.claimsRecordResponseAction,
      leadingIcon: Icons.fact_check_outlined,
      isLoading: state.isSaving,
      enabled: canRecord,
      onPressed: () {
        unawaited(
          _openClaimResponseDialog(
            context,
            controller,
            initialStatus: status == 'REJECTED' ? 'REJECTED' : 'APPROVED',
            title: l10n.claimsRecordResponseDialogTitle,
            submitLabel: l10n.claimsRecordResponseSubmitAction,
          ),
        );
      },
    ),
    AppButton.primary(
      label: l10n.claimsCloseClaimAction,
      leadingIcon: Icons.task_alt_outlined,
      isLoading: state.isSaving,
      enabled: status != 'PAID' && status != 'CANCELLED',
      onPressed: () {
        unawaited(
          _openClaimResponseDialog(
            context,
            controller,
            initialStatus: 'PAID',
            title: l10n.claimsCloseClaimDialogTitle,
            submitLabel: l10n.claimsCloseClaimSubmitAction,
          ),
        );
      },
    ),
  ];
}

const String _claimsQueueFilterKey = 'queue';

AppSearchBarFilterValue _claimsFilterValue(ClaimsQueueQuery query) {
  if (query.filter == ClaimsQueueFilter.all) {
    return AppSearchBarFilterValue.empty;
  }
  return AppSearchBarFilterValue(
    options: <String, String>{_claimsQueueFilterKey: query.filter.name},
  );
}

ClaimsQueueFilter _claimsFilterFromValue(String? value) {
  for (final ClaimsQueueFilter filter in ClaimsQueueFilter.values) {
    if (filter.name == value) {
      return filter;
    }
  }
  return ClaimsQueueFilter.all;
}

List<AppSearchBarFilterChoice> _claimsQueueFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    for (final ClaimsQueueFilter filter in ClaimsQueueFilter.values)
      if (filter != ClaimsQueueFilter.all)
        AppSearchBarFilterChoice(
          value: filter.name,
          label: _claimsFilterLabel(l10n, filter),
          icon: Icons.filter_list,
        ),
  ];
}

int _claimsCountForFilter(
  ClaimsWorkspaceState state,
  ClaimsQueueFilter filter,
) {
  final String? authorizationStatus = preAuthorizationStatusForFilter(filter);
  final String? claimStatus = insuranceClaimStatusForFilter(filter);
  return state.queue.items.where((ClaimsQueueItem item) {
    final String status = item.status.toUpperCase();
    if (item.isAuthorization && authorizationStatus != null) {
      return status == authorizationStatus;
    }
    if (item.isClaim && claimStatus != null) {
      return status == claimStatus;
    }
    return filter == ClaimsQueueFilter.all;
  }).length;
}

String _claimsFilterLabel(AppLocalizations l10n, ClaimsQueueFilter filter) {
  return switch (filter) {
    ClaimsQueueFilter.all => l10n.claimsFilterAll,
    ClaimsQueueFilter.authorizationPending =>
      l10n.claimsFilterAuthorizationPending,
    ClaimsQueueFilter.authorizationApproved =>
      l10n.claimsFilterAuthorizationApproved,
    ClaimsQueueFilter.authorizationDenied =>
      l10n.claimsFilterAuthorizationDenied,
    ClaimsQueueFilter.authorizationExpired =>
      l10n.claimsFilterAuthorizationExpired,
    ClaimsQueueFilter.claimSubmitted => l10n.claimsFilterClaimSubmitted,
    ClaimsQueueFilter.claimApproved => l10n.claimsFilterClaimApproved,
    ClaimsQueueFilter.claimRejected => l10n.claimsFilterClaimRejected,
    ClaimsQueueFilter.claimPaid => l10n.claimsFilterClaimPaid,
    ClaimsQueueFilter.claimCancelled => l10n.claimsFilterClaimCancelled,
  };
}

List<AppSelectOption<String>> _authorizationStatusOptions(
  AppLocalizations l10n,
) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(value: 'PENDING', label: l10n.claimsStatusPending),
    AppSelectOption<String>(
      value: 'APPROVED',
      label: l10n.claimsStatusApproved,
    ),
    AppSelectOption<String>(value: 'DENIED', label: l10n.claimsStatusDenied),
    AppSelectOption<String>(value: 'EXPIRED', label: l10n.claimsStatusExpired),
  ];
}

List<AppSelectOption<String>> _claimResponseOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: 'APPROVED',
      label: l10n.claimsStatusApproved,
    ),
    AppSelectOption<String>(
      value: 'REJECTED',
      label: l10n.claimsStatusRejected,
    ),
    AppSelectOption<String>(value: 'PAID', label: l10n.claimsStatusPaid),
  ];
}

List<AppSelectOption<String>> _coveragePlanOptions(
  List<CoveragePlanOption> plans,
) {
  return <AppSelectOption<String>>[
    for (final CoveragePlanOption plan in plans)
      AppSelectOption<String>(
        value: plan.apiId,
        label: _joinLabel(<String?>[plan.title, plan.subtitle]),
      ),
  ];
}

List<AppSelectOption<String>> _invoiceOptions(
  BuildContext context,
  List<ClaimInvoiceOption> invoices,
) {
  return <AppSelectOption<String>>[
    for (final ClaimInvoiceOption invoice in invoices)
      AppSelectOption<String>(
        value: invoice.apiId,
        label: _joinLabel(<String?>[
          invoice.title,
          invoice.patientDisplayId,
          _amountLabel(context, invoice),
        ]),
      ),
  ];
}

AppWorkspaceStatus _statusFor(BuildContext context, ClaimsQueueItem item) {
  return AppWorkspaceStatus(
    label: _statusLabel(context, item),
    tone: _statusTone(item),
    icon: _statusIcon(item),
  );
}

String _statusLabel(BuildContext context, ClaimsQueueItem item) {
  final AppLocalizations l10n = context.l10n;
  return switch (item.status.toUpperCase()) {
    'PENDING' => l10n.claimsStatusPending,
    'APPROVED' => l10n.claimsStatusApproved,
    'DENIED' => l10n.claimsStatusDenied,
    'EXPIRED' => l10n.claimsStatusExpired,
    'SUBMITTED' => l10n.claimsStatusSubmitted,
    'REJECTED' => l10n.claimsStatusRejected,
    'PAID' => l10n.claimsStatusPaid,
    'CANCELLED' => l10n.claimsStatusCancelled,
    _ => _apiLabel(item.status),
  };
}

AppWorkspaceStatusTone _statusTone(ClaimsQueueItem item) {
  return switch (item.status.toUpperCase()) {
    'APPROVED' || 'PAID' => AppWorkspaceStatusTone.success,
    'PENDING' || 'SUBMITTED' => AppWorkspaceStatusTone.info,
    'DENIED' || 'REJECTED' || 'EXPIRED' => AppWorkspaceStatusTone.error,
    'CANCELLED' => AppWorkspaceStatusTone.neutral,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

IconData _statusIcon(ClaimsQueueItem item) {
  return switch (item.status.toUpperCase()) {
    'APPROVED' || 'PAID' => Icons.check_circle_outline,
    'PENDING' || 'SUBMITTED' => Icons.schedule_outlined,
    'DENIED' || 'REJECTED' => Icons.report_gmailerrorred_outlined,
    'EXPIRED' || 'CANCELLED' => Icons.block_outlined,
    _ => Icons.info_outline,
  };
}

String _kindLabel(BuildContext context, ClaimsQueueKind kind) {
  final AppLocalizations l10n = context.l10n;
  return switch (kind) {
    ClaimsQueueKind.authorization => l10n.claimsAuthorizationTypeLabel,
    ClaimsQueueKind.claim => l10n.claimsClaimTypeLabel,
  };
}

IconData _kindIcon(ClaimsQueueKind kind) {
  return switch (kind) {
    ClaimsQueueKind.authorization => Icons.verified_user_outlined,
    ClaimsQueueKind.claim => Icons.receipt_long_outlined,
  };
}

String _detailTitle(BuildContext context, ClaimsQueueDetail detail) {
  if (detail.isAuthorization) {
    return detail.coveragePlan?.title ?? context.l10n.claimsAuthorizationTitle;
  }
  return detail.claim?.patientDisplayId ?? context.l10n.claimsClaimPatientTitle;
}

String _detailNumber(BuildContext context, ClaimsQueueDetail detail) {
  return detail.isClaim
      ? _fallback(context, detail.claim?.patientDisplayId)
      : detail.item.displayId;
}

String _detailSubtitle(BuildContext context, ClaimsQueueDetail detail) {
  return detail.isAuthorization
      ? context.l10n.claimsAuthorizationSubtitle
      : context.l10n.claimsClaimSubtitle(detail.item.displayId);
}

String _coverageLabel(BuildContext context, ClaimsQueueDetail detail) {
  final CoveragePlanOption? plan = detail.coveragePlan;
  if (plan == null) {
    return _fallback(context, detail.item.coveragePlanDisplayId);
  }
  return _joinLabel(<String?>[plan.title, plan.subtitle]);
}

String _amountLabel(BuildContext context, ClaimInvoiceOption? invoice) {
  final num? amount = invoice?.totalAmount;
  if (amount == null) {
    return context.l10n.profileUnknownValue;
  }
  return AppFormatters.currency(
    amount,
    Localizations.localeOf(context),
    currencyCode: invoice?.currency,
  );
}

String _invoiceStatusLabel(BuildContext context, ClaimInvoiceOption? invoice) {
  final String? status = invoice?.billingStatus ?? invoice?.status;
  if (status == null || status.trim().isEmpty) {
    return context.l10n.profileUnknownValue;
  }
  return _apiLabel(status);
}

String _patientBalanceLabel(BuildContext context, ClaimsQueueDetail detail) {
  final ClaimInvoiceOption? invoice = detail.invoice;
  final num? amount = invoice?.totalAmount;
  final int? coverage = detail.coveragePlan?.coveragePercentage;
  if (amount == null || coverage == null) {
    return context.l10n.profileUnknownValue;
  }
  final num balance = amount * ((100 - coverage).clamp(0, 100) / 100);
  return AppFormatters.currency(
    balance,
    Localizations.localeOf(context),
    currencyCode: invoice?.currency,
  );
}

String _claimBillingImpact(BuildContext context, ClaimsQueueDetail detail) {
  final AppLocalizations l10n = context.l10n;
  final String status = detail.item.status.toUpperCase();
  if (detail.invoiceUnavailable) {
    return l10n.claimsBillingInvoiceUnavailableBody;
  }
  return switch (status) {
    'APPROVED' => l10n.claimsBillingAuthorizedBody,
    'PAID' => l10n.claimsBillingPaidBody,
    'REJECTED' => l10n.claimsBillingRejectedBody,
    'SUBMITTED' => l10n.claimsBillingPendingBody,
    _ => l10n.claimsBillingNeutralBody,
  };
}

bool _hasPayerResponse(ClaimsQueueDetail detail) {
  return switch (detail.item.status.toUpperCase()) {
    'APPROVED' || 'DENIED' || 'REJECTED' || 'PAID' => true,
    _ => false,
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

String _fallback(BuildContext context, String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? context.l10n.profileUnknownValue : normalized;
}

String _joinLabel(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

String _apiLabel(String value) {
  final String normalized = value.trim().replaceAll(RegExp(r'[_-]+'), ' ');
  if (normalized.isEmpty) {
    return value;
  }
  return normalized
      .split(RegExp(r'\s+'))
      .map((String word) {
        if (word.isEmpty) {
          return word;
        }
        return '${word.substring(0, 1).toUpperCase()}${word.substring(1).toLowerCase()}';
      })
      .join(' ');
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

void _showSaved(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.claimsSavedMessage)));
}

String _claimsStatementHtml(BuildContext context, ClaimsQueueDetail detail) {
  final AppLocalizations l10n = context.l10n;
  final String factsHtml =
      PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
        PrintFormMetadataItem(
          label: l10n.claimsReferenceColumnLabel,
          value: detail.item.displayId,
        ),
        PrintFormMetadataItem(
          label: l10n.claimsStatusColumnLabel,
          value: _statusLabel(context, detail.item),
        ),
        PrintFormMetadataItem(
          label: l10n.claimsCoverageFieldLabel,
          value: _coverageLabel(context, detail),
        ),
        PrintFormMetadataItem(
          label: l10n.claimsInvoiceFieldLabel,
          value: _fallback(context, detail.claim?.invoiceDisplayId),
        ),
        PrintFormMetadataItem(
          label: l10n.claimsAmountFieldLabel,
          value: _amountLabel(context, detail.invoice),
        ),
      ]);
  final String impact = detail.isClaim
      ? _claimBillingImpact(context, detail)
      : l10n.claimsAuthorizationBillingImpactBody;
  final String impactHtml = PrintFormTemplate.section(
    title: l10n.claimsBillingImpactTitle,
    bodyHtml: '<p>${_htmlEscape(impact)}</p>',
  );

  return '$factsHtml$impactHtml';
}

String _htmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
