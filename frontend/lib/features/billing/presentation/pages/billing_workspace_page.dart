import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_invoice_print_helpers.dart';
import 'package:hosspi_hms/features/billing/presentation/controllers/billing_workspace_controller.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_detail_widgets.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_form_dialogs.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_ledger_dialog.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_receive_payment_dialog.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class BillingWorkspacePage extends ConsumerWidget {
  const BillingWorkspacePage({super.key, this.initialQuery});

  final BillingWorkspaceQuery? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Result<BillingWorkspaceState>> workspace = ref.watch(
      billingWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<BillingWorkspaceState>(
      value: workspace,
      appBarTitle: context.l10n.billingWorkspaceTitle,
      loadingTitle: context.l10n.billingLoadingTitle,
      loadingBody: context.l10n.billingLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(billingWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, BillingWorkspaceState state) {
        return _BillingWorkspaceContent(
          state: state,
          initialQuery: initialQuery,
        );
      },
    );
  }
}

class _BillingWorkspaceContent extends ConsumerStatefulWidget {
  const _BillingWorkspaceContent({required this.state, this.initialQuery});

  final BillingWorkspaceState state;
  final BillingWorkspaceQuery? initialQuery;

  @override
  ConsumerState<_BillingWorkspaceContent> createState() =>
      _BillingWorkspaceContentState();
}

class _BillingWorkspaceContentState
    extends ConsumerState<_BillingWorkspaceContent> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<BillingWorkItem>
  _tableColumnController;
  Timer? _searchDebounce;
  bool _handledRouteQuery = false;
  late BillingQueueType _section;

  @override
  void initState() {
    super.initState();
    _section = widget.state.query.queue;
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<BillingWorkItem>();
    _searchController.addListener(_onSearchChanged);
    _scheduleRouteQuery(widget.initialQuery);
    _refreshOnMount();
  }

  void _refreshOnMount() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(billingWorkspaceControllerProvider.notifier).refresh();
    });
  }

  void _scheduleRouteQuery(BillingWorkspaceQuery? query) {
    if (query == null || !query.hasRouteTargeting) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _handledRouteQuery) {
        return;
      }
      _handledRouteQuery = true;
      unawaited(_applyRouteQuery(query));
    });
  }

  Future<void> _applyRouteQuery(BillingWorkspaceQuery query) async {
    final BillingWorkspaceController controller = ref.read(
      billingWorkspaceControllerProvider.notifier,
    );

    if (query.queue != _section) {
      setState(() => _section = query.queue);
    }

    if (query.queue != BillingQueueType.all &&
        query.search.trim().isEmpty &&
        query.patientId.trim().isEmpty &&
        query.invoiceNumber.trim().isEmpty &&
        query.encounterId.trim().isEmpty &&
        query.sourceModule.trim().isEmpty &&
        query.billingStatus.trim().isEmpty &&
        query.action.trim().isEmpty) {
      await controller.applyQueue(query.queue);
      return;
    }
    if (query.hasRouteTargeting) {
      await controller.applyFilters(query);
    }

    if (query.action.trim().toLowerCase() == 'pay' && mounted) {
      await _autoOpenPaymentDialog(query);
    }
  }

  Future<void> _autoOpenPaymentDialog(BillingWorkspaceQuery query) async {
    final AsyncValue<Result<BillingWorkspaceState>> stateAsync = ref.read(
      billingWorkspaceControllerProvider,
    );
    BillingWorkspaceState? state;
    stateAsync.whenData((Result<BillingWorkspaceState> result) {
      result.when(
        success: (BillingWorkspaceState s) => state = s,
        failure: (_) {},
      );
    });
    if (state == null || !mounted) return;

    final String targetEncounter = query.encounterId.trim();
    final String targetInvoice = query.invoiceNumber.trim();

    BillingWorkItem? target;
    for (final BillingWorkItem item in state!.workItems.items) {
      final bool matchesEncounter =
          targetEncounter.isNotEmpty &&
          (item.encounterId == targetEncounter ||
              item.displayId == targetEncounter);
      final bool matchesInvoice =
          targetInvoice.isNotEmpty &&
          (item.invoiceDisplayId == targetInvoice ||
              item.displayId == targetInvoice);
      if (matchesEncounter || matchesInvoice) {
        target = item;
        break;
      }
    }

    if (target != null && mounted) {
      await _showPaymentDialog(context, ref, target);
    }
  }

  @override
  void didUpdateWidget(covariant _BillingWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery?.signature != widget.initialQuery?.signature) {
      _handledRouteQuery = false;
      _scheduleRouteQuery(widget.initialQuery);
    }
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
    if (widget.state.query.queue != _section) {
      setState(() => _section = widget.state.query.queue);
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      final String query = _searchController.text.trim();
      if (query == widget.state.query.search) {
        return;
      }
      ref.read(billingWorkspaceControllerProvider.notifier).applySearch(query);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tableColumnController.dispose();
    super.dispose();
  }

  static String _queueToQueryValue(BillingQueueType queue) {
    return switch (queue) {
      BillingQueueType.all => 'all',
      BillingQueueType.needsIssue => 'needs-issue',
      BillingQueueType.pendingPayment => 'pending-payment',
      BillingQueueType.claimsPending => 'claims-pending',
      BillingQueueType.approvalRequired => 'approval-required',
      BillingQueueType.overdue => 'overdue',
    };
  }

  void _updateUrlForQueue(BillingQueueType queue) {
    if (!mounted) return;
    final String tab = _queueToQueryValue(queue);
    final String location = AppRoutes.billing.location(
      queryParameters: <String, String>{if (tab != 'all') 'queue': tab},
    );
    GoRouter.of(context).replace<void>(location);
  }

  @override
  Widget build(BuildContext context) {
    final BillingWorkspaceState state = widget.state;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = accessPolicy.grants(AppPermissions.billingWrite);
    final controller = ref.read(billingWorkspaceControllerProvider.notifier);
    final AppFailure? lastFailure = state.lastFailure is AppFailure
        ? state.lastFailure! as AppFailure
        : null;

    final AppLocalizations l10n = context.l10n;

    return AppWorkspace(
      title: l10n.billingWorkspaceTitle,
      leadingIcon: AppRouteIcons.billing,
      toolbar: appWorkspaceToolbarWithLabels(
        l10n,
        summaryNotifications: _summaryNotifications(context, ref, state),
        secondary: <Widget>[
          AppButton.secondary(
            label: l10n.billingCloseShift,
            leadingIcon: Icons.schedule_send_outlined,
            enabled: canWrite && !state.isSaving,
            onPressed: () => _showShiftCloseDialog(context, ref),
          ),
          AppButton.secondary(
            label: l10n.billingCloseDay,
            leadingIcon: Icons.today_outlined,
            enabled: canWrite && !state.isSaving,
            onPressed: () => _showDayCloseDialog(context, ref),
          ),
        ],
        onRefresh: controller.refresh,
        isRefreshing: state.isRefreshing,
      ),
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
          Row(
            children: <Widget>[
              Expanded(
                child: AppTabStrip(
                  tabs: <AppTabItem>[
                    for (final BillingQueueType queue
                        in BillingQueueType.values)
                      AppTabItem(
                        id: queue.name,
                        icon: billingQueueIcon(queue),
                        label:
                            '${billingQueueLabel(context, queue)} (${state.overview.summary.countFor(queue)})',
                      ),
                  ],
                  selectedId: _section.name,
                  onTabTapped: (String tabId) {
                    for (final BillingQueueType queue
                        in BillingQueueType.values) {
                      if (queue.name == tabId) {
                        setState(() => _section = queue);
                        _updateUrlForQueue(queue);
                        ref
                            .read(billingWorkspaceControllerProvider.notifier)
                            .applyQueue(queue);
                        break;
                      }
                    }
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          _BillingQueuePanel(
            state: state,
            canWrite: canWrite,
            searchController: _searchController,
            columnVisibilityController: _tableColumnController,
            activeQueue: _section,
          ),
        ],
      ),
    );
  }

  List<AppWorkspaceSummaryNotification> _summaryNotifications(
    BuildContext context,
    WidgetRef ref,
    BillingWorkspaceState state,
  ) {
    final AppLocalizations l10n = context.l10n;
    final BillingSummary summary = state.overview.summary;
    final controller = ref.read(billingWorkspaceControllerProvider.notifier);

    return <AppWorkspaceSummaryNotification>[
      if (summary.workloadCount > 0)
        AppWorkspaceSummaryNotification(
          label: l10n.billingAllWorkItems,
          count: summary.workloadCount,
          icon: Icons.inventory_2_outlined,
          onSelected: () => controller.applyQueue(BillingQueueType.all),
        ),
      if (summary.pendingPayment > 0)
        AppWorkspaceSummaryNotification(
          label: l10n.billingAwaitingPayment,
          count: summary.pendingPayment,
          icon: Icons.payments_outlined,
          tone: AppWorkspaceStatusTone.warning,
          onSelected: () =>
              controller.applyQueue(BillingQueueType.pendingPayment),
        ),
      if (summary.needsIssue > 0)
        AppWorkspaceSummaryNotification(
          label: l10n.billingIssueQueue,
          count: summary.needsIssue,
          icon: Icons.receipt_long_outlined,
          onSelected: () => controller.applyQueue(BillingQueueType.needsIssue),
        ),
      if (summary.claimsPending > 0)
        AppWorkspaceSummaryNotification(
          label: l10n.billingClaimsPending,
          count: summary.claimsPending,
          icon: Icons.health_and_safety_outlined,
          tone: AppWorkspaceStatusTone.info,
          onSelected: () =>
              controller.applyQueue(BillingQueueType.claimsPending),
        ),
      if (summary.approvalRequired > 0)
        AppWorkspaceSummaryNotification(
          label: l10n.billingApprovals,
          count: summary.approvalRequired,
          icon: Icons.rule_outlined,
          onSelected: () =>
              controller.applyQueue(BillingQueueType.approvalRequired),
        ),
      if (summary.overdue > 0)
        AppWorkspaceSummaryNotification(
          label: l10n.billingOverdue,
          count: summary.overdue,
          icon: Icons.warning_amber_outlined,
          tone: AppWorkspaceStatusTone.error,
          onSelected: () => controller.applyQueue(BillingQueueType.overdue),
        ),
    ];
  }
}

class _BillingQueuePanel extends ConsumerWidget {
  const _BillingQueuePanel({
    required this.state,
    required this.canWrite,
    required this.searchController,
    required this.columnVisibilityController,
    required this.activeQueue,
  });

  final BillingWorkspaceState state;
  final bool canWrite;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<BillingWorkItem>
  columnVisibilityController;
  final BillingQueueType activeQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final controller = ref.read(billingWorkspaceControllerProvider.notifier);

    return AppListTable<BillingWorkItem>(
      page: state.workItems,
      isLoading: state.isRefreshing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      columnVisibilityController: columnVisibilityController,
      columnVisibilityStorageKey: 'billing_${activeQueue.name}',
      columnWidthStorageKey: 'billing_cw_${activeQueue.name}',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      search: AppListTableSearch<BillingWorkItem>(
        controller: searchController,
        semanticLabel: l10n.billingSearchSemanticLabel,
        hintText: l10n.billingSearchHint,
        clearLabel: l10n.billingClearSearch,
        matcher: (_, _) => true,
        onSubmitted: controller.applySearch,
        onClear: () => controller.applySearch(''),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.billingFiltersTitle,
        advancedFilterTitle: l10n.billingFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.billingClearFilters,
        dateFilterLabel: l10n.billingIssuedDateFilterLabel,
        dateFromLabel: l10n.opdDateFromLabel,
        dateToLabel: l10n.opdDateToLabel,
        allFieldsLabel: billingQueueLabel(context, BillingQueueType.all),
        textFilters: _billingTextFilters(l10n),
        filterGroups: _billingTableFilterGroups(context),
        filterValue: _billingFilterValue(state.query),
        hasActiveFilters: state.query.hasActiveFilters,
        onFilterChanged: (AppSearchBarFilterValue value) {
          if (!value.isActive) {
            unawaited(controller.clearFilters());
            return;
          }
          unawaited(
            controller.applyFilters(
              _billingQueryFromFilter(state.query, value),
            ),
          );
        },
      ),
      itemKeyBuilder: (BillingWorkItem item) => ValueKey<String>(item.id),
      onRowSelected: (BillingWorkItem item) {
        controller.selectItem(item);
        _showBillingDetailDialog(
          context,
          ref,
          item,
          canWrite: canWrite,
          isSaving: state.isSaving,
        );
      },
      previousPageLabel: l10n.billingPreviousPageLabel,
      nextPageLabel: l10n.billingNextPageLabel,
      pageLabelBuilder: (AppPage<BillingWorkItem> page) {
        final int total = page.totalItemCount ?? page.lastItemNumber;
        return '${page.firstItemNumber}-${page.lastItemNumber} of $total';
      },
      onPageChanged: controller.changePage,
      emptyBuilder: (BuildContext context) {
        return AppWorkspaceStatePanel.empty(
          title: l10n.billingEmptyTitle,
          body: l10n.billingEmptyBody,
        );
      },
      columns: _columnsForQueue(context, l10n, activeQueue),
      columnChoices: _columnChoices(l10n),
      mobileItemBuilder: (BuildContext context, BillingWorkItem item) {
        return _BillingMobileTile(item: item);
      },
    );
  }
}

List<AppListTableColumn<BillingWorkItem>> _columnsForQueue(
  BuildContext context,
  AppLocalizations l10n,
  BillingQueueType queue,
) {
  final AppListTableColumn<BillingWorkItem> patientName =
      AppListTableColumn<BillingWorkItem>(
        id: 'patient_name',
        label: l10n.billingPatientNameColumn,
        sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
            appListTableCompareText(
              left.effectivePatientName,
              right.effectivePatientName,
            ),
        cellBuilder: (BuildContext context, BillingWorkItem item) {
          return Text(
            billingPatientName(context, item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      );
  final AppListTableColumn<BillingWorkItem> patientId =
      AppListTableColumn<BillingWorkItem>(
        id: 'patient_id',
        label: l10n.billingPatientIdColumn,
        sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
            appListTableCompareText(
              left.effectivePatientNumber,
              right.effectivePatientNumber,
            ),
        cellBuilder: (BuildContext context, BillingWorkItem item) {
          return Text(
            item.effectivePatientNumber ?? l10n.profileUnknownValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      );
  final AppListTableColumn<BillingWorkItem> invoice =
      AppListTableColumn<BillingWorkItem>(
        id: 'invoice',
        label: l10n.billingInvoiceColumn,
        sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
            appListTableCompareText(
              left.effectiveDisplayId,
              right.effectiveDisplayId,
            ),
        cellBuilder: (BuildContext context, BillingWorkItem item) {
          return Text(
            item.effectiveDisplayId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      );
  final AppListTableColumn<BillingWorkItem> encounter =
      AppListTableColumn<BillingWorkItem>(
        id: 'encounter',
        label: l10n.billingEncounterLabel,
        sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
            appListTableCompareText(
              left.encounterDisplayId ?? left.encounterId,
              right.encounterDisplayId ?? right.encounterId,
            ),
        cellBuilder: (BuildContext context, BillingWorkItem item) {
          return Text(
            item.encounterDisplayId ??
                item.encounterId ??
                l10n.profileUnknownValue,
          );
        },
      );
  final AppListTableColumn<BillingWorkItem> source =
      AppListTableColumn<BillingWorkItem>(
        id: 'source',
        label: l10n.billingSourceColumn,
        sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
            appListTableCompareText(
              left.invoiceSourceSummary,
              right.invoiceSourceSummary,
            ),
        cellBuilder: (BuildContext context, BillingWorkItem item) {
          return Text(
            billingInvoiceSourceLabel(context, item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      );
  final AppListTableColumn<BillingWorkItem> status =
      AppListTableColumn<BillingWorkItem>(
        id: 'status',
        label: l10n.billingStatusColumn,
        sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
            appListTableCompareText(
              left.clearanceState.name,
              right.clearanceState.name,
            ),
        cellBuilder: (BuildContext context, BillingWorkItem item) {
          return BillingGateBadge(state: item.clearanceState);
        },
      );
  final AppListTableColumn<BillingWorkItem> amountDue =
      AppListTableColumn<BillingWorkItem>(
        id: 'amount_due',
        label: l10n.billingAmountDueColumn,
        numeric: true,
        sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
            appListTableCompareNumber(left.balanceDue, right.balanceDue),
        cellBuilder: (BuildContext context, BillingWorkItem item) {
          return Text(billingMoney(context, item.balanceDue, item.currency));
        },
      );
  final AppListTableColumn<BillingWorkItem> amountPaid =
      AppListTableColumn<BillingWorkItem>(
        id: 'amount_paid',
        label: l10n.billingPaidColumn,
        numeric: true,
        sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
            appListTableCompareNumber(left.paidAmount, right.paidAmount),
        cellBuilder: (BuildContext context, BillingWorkItem item) {
          return Text(billingMoney(context, item.paidAmount, item.currency));
        },
      );
  final AppListTableColumn<BillingWorkItem> balance =
      AppListTableColumn<BillingWorkItem>(
        id: 'balance',
        label: l10n.billingBalanceColumn,
        numeric: true,
        sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
            appListTableCompareNumber(left.balanceDue, right.balanceDue),
        cellBuilder: (BuildContext context, BillingWorkItem item) {
          return Text(billingMoney(context, item.balanceDue, item.currency));
        },
      );
  final AppListTableColumn<BillingWorkItem> updated =
      AppListTableColumn<BillingWorkItem>(
        id: 'updated',
        label: l10n.billingUpdatedColumn,
        sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
            appListTableCompareDateTime(left.timelineAt, right.timelineAt),
        cellBuilder: (BuildContext context, BillingWorkItem item) {
          return Text(billingDateTime(context, item.timelineAt));
        },
      );

  return switch (queue) {
    BillingQueueType.all => <AppListTableColumn<BillingWorkItem>>[
      patientName,
      patientId,
      invoice,
      source,
      status,
      amountDue,
      amountPaid,
    ],
    BillingQueueType.needsIssue => <AppListTableColumn<BillingWorkItem>>[
      patientName,
      invoice,
      encounter,
      source,
      amountDue,
    ],
    BillingQueueType.pendingPayment => <AppListTableColumn<BillingWorkItem>>[
      patientName,
      patientId,
      invoice,
      status,
      amountDue,
      amountPaid,
      balance,
    ],
    BillingQueueType.claimsPending => <AppListTableColumn<BillingWorkItem>>[
      patientName,
      invoice,
      encounter,
      source,
      status,
      amountDue,
    ],
    BillingQueueType.approvalRequired => <AppListTableColumn<BillingWorkItem>>[
      patientName,
      invoice,
      encounter,
      source,
      status,
      amountDue,
    ],
    BillingQueueType.overdue => <AppListTableColumn<BillingWorkItem>>[
      patientName,
      patientId,
      invoice,
      status,
      amountDue,
      amountPaid,
      updated,
    ],
  };
}

List<AppListTableColumn<BillingWorkItem>> _columnChoices(
  AppLocalizations l10n,
) {
  return <AppListTableColumn<BillingWorkItem>>[
    AppListTableColumn<BillingWorkItem>(
      id: 'balance',
      label: l10n.billingBalanceColumn,
      numeric: true,
      sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
          appListTableCompareNumber(left.balanceDue, right.balanceDue),
      cellBuilder: (BuildContext context, BillingWorkItem item) {
        return Text(billingMoney(context, item.balanceDue, item.currency));
      },
    ),
    AppListTableColumn<BillingWorkItem>(
      id: 'updated',
      label: l10n.billingUpdatedColumn,
      sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
          appListTableCompareDateTime(left.timelineAt, right.timelineAt),
      cellBuilder: (BuildContext context, BillingWorkItem item) {
        return Text(billingDateTime(context, item.timelineAt));
      },
    ),
  ];
}

Future<void> _showBillingDetailDialog(
  BuildContext context,
  WidgetRef ref,
  BillingWorkItem item, {
  required bool canWrite,
  required bool isSaving,
}) {
  final AppLocalizations l10n = context.l10n;
  return showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(billingDetailTitle(context, item)),
      icon: const Icon(Icons.receipt_long_outlined),
      scrollable: true,
      maxWidth: 940,
      content: BillingDetailBody(
        item: item,
        canWrite: canWrite,
        isSaving: isSaving,
        onReceivePayment: item.canReceivePayment
            ? () => _showPaymentDialog(context, ref, item)
            : null,
        onIssue: item.canIssue ? () => _showIssueDialog(context, ref) : null,
        onRefund: item.canRequestRefund
            ? () => _showRefundDialog(context, ref, item)
            : null,
        onAdjust: item.canRequestAdjustment
            ? () => _showAdjustmentDialog(context, ref, item)
            : null,
        onVoid: item.canRequestVoid
            ? () => _showVoidDialog(context, ref)
            : null,
        onSend: () => _showSendDialog(context, ref),
        onApprove: item.canApproveOrReject
            ? () => _showApproveDialog(context, ref)
            : null,
        onReject: item.canApproveOrReject
            ? () => _showRejectDialog(context, ref)
            : null,
        onSubmitClaim: item.canSubmitClaim
            ? () => _showSubmitClaimDialog(context, ref)
            : null,
        onReconcileClaim: item.canReconcileClaim
            ? () => _showReconcileClaimDialog(context, ref)
            : null,
        onApprovePreAuthorization: item.canApprovePreAuthorization
            ? () => _showPreAuthStatusDialog(context, ref, status: 'APPROVED')
            : null,
        onDenyPreAuthorization: item.canDenyPreAuthorization
            ? () => _showPreAuthStatusDialog(context, ref, status: 'DENIED')
            : null,
        onViewLedger: (item.patientId ?? item.effectivePatientNumber) != null
            ? () => showBillingLedgerDialog(context, ref, item: item)
            : null,
        onFinalizeEncounter: item.canFinalizeEncounterBilling
            ? () => _showFinalizeEncounterDialog(context, ref)
            : null,
      ),
      actions: <Widget>[
        AppReportActionButton.print(
          label: l10n.billingPrintInvoiceAction,
          enabled: item.isInvoice,
          tooltip: l10n.billingPrintInvoiceTooltip,
          onPressed: item.isInvoice
              ? () =>
                    printBillingInvoice(ref: ref, context: context, item: item)
              : null,
        ),
        AppReportActionButton.download(
          label: l10n.billingInvoiceLabel,
          enabled: item.isInvoice,
          tooltip: l10n.billingDocumentTooltip,
          onPressed: item.isInvoice
              ? () => _downloadInvoiceDocument(context, ref, item)
              : null,
        ),
      ],
    ),
  );
}

class _BillingMobileTile extends StatelessWidget {
  const _BillingMobileTile({required this.item});

  final BillingWorkItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.receipt_long_outlined, color: theme.colorScheme.primary),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  billingPatientName(context, item),
                  style: theme.textTheme.titleSmall,
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  billingJoinDisplay(<String?>[
                    item.effectivePatientNumber,
                    item.effectiveDisplayId,
                    item.encounterDisplayId ?? item.encounterId,
                    billingInvoiceSourceLabel(context, item),
                    billingMoney(context, item.balanceDue, item.currency),
                  ]),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          BillingGateBadge(state: item.clearanceState),
        ],
      ),
    );
  }
}

Future<void> _showPaymentDialog(
  BuildContext context,
  WidgetRef ref,
  BillingWorkItem item,
) async {
  final BillingPaymentDraft? draft = await showBillingReceivePaymentDialog(
    context,
    item: item,
  );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(billingWorkspaceControllerProvider.notifier)
      .receivePayment(draft);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, ref, failure);
}

Future<void> _showRefundDialog(
  BuildContext context,
  WidgetRef ref,
  BillingWorkItem item,
) async {
  final BillingRefundDraft? draft = await showAppDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => BillingRefundForm(
      dialogTitle: Text(context.l10n.billingRequestRefund),
      dialogIcon: const Icon(Icons.assignment_return_outlined),
      item: item,
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(billingWorkspaceControllerProvider.notifier)
      .requestRefund(draft);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, ref, failure);
}

Future<void> _showAdjustmentDialog(
  BuildContext context,
  WidgetRef ref,
  BillingWorkItem item,
) async {
  final BillingAdjustmentDraft? draft = await showAppDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => BillingAdjustmentForm(
      dialogTitle: Text(context.l10n.billingRequestAdjustment),
      dialogIcon: const Icon(Icons.tune),
      item: item,
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(billingWorkspaceControllerProvider.notifier)
      .requestAdjustment(draft);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, ref, failure);
}

Future<void> _showVoidDialog(BuildContext context, WidgetRef ref) async {
  final Map<String, String?>? payload = await showAppDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => BillingReasonForm(
      dialogTitle: Text(context.l10n.billingVoidInvoice),
      dialogIcon: const Icon(Icons.block_outlined),
      submitLabel: context.l10n.billingRequestVoidAction,
      reasonLabel: context.l10n.billingVoidReasonLabel,
    ),
  );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(billingWorkspaceControllerProvider.notifier)
      .requestInvoiceVoid(
        reason: payload['reason'] ?? '',
        notes: payload['notes'],
      );
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, ref, failure);
}

Future<void> _showIssueDialog(BuildContext context, WidgetRef ref) async {
  final String? notes = await showAppDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => BillingNotesForm(
      dialogTitle: Text(context.l10n.billingIssueInvoice),
      dialogIcon: const Icon(Icons.outbox_outlined),
      submitLabel: context.l10n.billingIssueAction,
    ),
  );
  if (!context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(billingWorkspaceControllerProvider.notifier)
      .issueSelectedInvoice(notes: notes);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, ref, failure);
}

Future<void> _showSendDialog(BuildContext context, WidgetRef ref) async {
  final String? recipientEmail = await showAppDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => BillingNotesForm(
      dialogTitle: Text(context.l10n.billingSendInvoice),
      dialogIcon: const Icon(Icons.send_outlined),
      submitLabel: context.l10n.billingSendAction,
      email: true,
    ),
  );
  if (!context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(billingWorkspaceControllerProvider.notifier)
      .sendSelectedInvoice(recipientEmail: recipientEmail);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, ref, failure);
}

Future<void> _showShiftCloseDialog(BuildContext context, WidgetRef ref) async {
  final BillingCloseDraft? draft = await showAppDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => BillingCloseForm(
      dialogTitle: Text(context.l10n.billingCloseShift),
      dialogIcon: const Icon(Icons.schedule_send_outlined),
      title: context.l10n.billingCloseShift,
      shiftClose: true,
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(billingWorkspaceControllerProvider.notifier)
      .closeShift(draft);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, ref, failure);
}

Future<void> _showDayCloseDialog(BuildContext context, WidgetRef ref) async {
  final BillingCloseDraft? draft = await showAppDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => BillingCloseForm(
      dialogTitle: Text(context.l10n.billingCloseDay),
      dialogIcon: const Icon(Icons.today_outlined),
      title: context.l10n.billingCloseDay,
      shiftClose: false,
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(billingWorkspaceControllerProvider.notifier)
      .closeDay(draft);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, ref, failure);
}

void _showMutationResult(
  BuildContext context,
  WidgetRef ref,
  AppFailure? failure,
) {
  if (!context.mounted) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  final bool pendingApproval =
      ref
          .read(billingWorkspaceControllerProvider)
          .asData
          ?.value
          .when(
            success: (BillingWorkspaceState state) =>
                state.lastActionPendingApproval,
            failure: (_) => false,
          ) ??
      false;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null
            ? (pendingApproval
                  ? l10n.billingActionPendingApproval
                  : l10n.billingActionSaved)
            : l10n.failureMessage(failure),
      ),
    ),
  );
}

Future<void> _downloadInvoiceDocument(
  BuildContext context,
  WidgetRef ref,
  BillingWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final Result<BillingInvoiceDocument> result = await ref
      .read(billingWorkspaceControllerProvider.notifier)
      .downloadInvoiceDocument(item.id);
  if (!context.mounted) {
    return;
  }
  bool saved = false;
  await result.when(
    success: (BillingInvoiceDocument document) async {
      saved = await _saveInvoicePdf(context, document);
    },
    failure: (AppFailure _) async {},
  );
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        saved
            ? l10n.billingDocumentDownloaded
            : l10n.billingDocumentUnavailable,
      ),
    ),
  );
}

Future<bool> _saveInvoicePdf(
  BuildContext context,
  BillingInvoiceDocument document,
) async {
  try {
    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: document.fileName,
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(
          label: context.l10n.billingPdfFileTypeLabel,
          extensions: <String>['pdf'],
        ),
      ],
    );
    if (location == null) {
      return false;
    }
    final XFile file = XFile.fromData(
      Uint8List.fromList(document.bytes),
      mimeType: 'application/pdf',
      name: document.fileName,
    );
    await file.saveTo(location.path);
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> _showApproveDialog(BuildContext context, WidgetRef ref) async {
  final String? notes = await showAppDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => BillingNotesForm(
      dialogTitle: Text(context.l10n.billingApproveAction),
      dialogIcon: const Icon(Icons.check_circle_outline),
      submitLabel: context.l10n.billingApproveAction,
    ),
  );
  if (!context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(billingWorkspaceControllerProvider.notifier)
      .approveSelectedApproval(
        BillingApprovalDecisionDraft(decisionNotes: notes),
      );
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, ref, failure);
}

Future<void> _showRejectDialog(BuildContext context, WidgetRef ref) async {
  final Map<String, String?>? payload = await showAppDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => BillingReasonForm(
      dialogTitle: Text(context.l10n.billingRejectAction),
      dialogIcon: const Icon(Icons.cancel_outlined),
      submitLabel: context.l10n.billingRejectAction,
      reasonLabel: context.l10n.billingReasonLabel,
    ),
  );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(billingWorkspaceControllerProvider.notifier)
      .rejectSelectedApproval(
        BillingApprovalDecisionDraft(
          reason: payload['reason'],
          decisionNotes: payload['notes'],
        ),
      );
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, ref, failure);
}

Future<void> _showSubmitClaimDialog(BuildContext context, WidgetRef ref) async {
  final String? notes = await showAppDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => BillingNotesForm(
      dialogTitle: Text(context.l10n.billingSubmitClaimAction),
      dialogIcon: const Icon(Icons.upload_outlined),
      submitLabel: context.l10n.billingSubmitClaimAction,
    ),
  );
  if (!context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(billingWorkspaceControllerProvider.notifier)
      .submitSelectedClaim(BillingClaimActionDraft(notes: notes));
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, ref, failure);
}

Future<void> _showReconcileClaimDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final BillingClaimActionDraft? draft = await showAppDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => BillingClaimReconcileForm(
      dialogTitle: Text(context.l10n.billingReconcileClaimAction),
      dialogIcon: const Icon(Icons.fact_check_outlined),
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(billingWorkspaceControllerProvider.notifier)
      .reconcileSelectedClaim(draft);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, ref, failure);
}

Future<void> _showPreAuthStatusDialog(
  BuildContext context,
  WidgetRef ref, {
  required String status,
}) async {
  final AppLocalizations l10n = context.l10n;
  final String? notes = await showAppDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => BillingNotesForm(
      dialogTitle: Text(
        status == 'APPROVED'
            ? l10n.billingPreAuthApproveAction
            : l10n.billingPreAuthDenyAction,
      ),
      dialogIcon: Icon(
        status == 'APPROVED'
            ? Icons.check_circle_outline
            : Icons.cancel_outlined,
      ),
      submitLabel: status == 'APPROVED'
          ? l10n.billingPreAuthApproveAction
          : l10n.billingPreAuthDenyAction,
    ),
  );
  if (!context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(billingWorkspaceControllerProvider.notifier)
      .updateSelectedPreAuthorization(<String, Object?>{
        'status': status,
        if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
      });
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, ref, failure);
}

Future<void> _showFinalizeEncounterDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.billingFinalizeEncounterAction),
      icon: const Icon(Icons.task_alt_outlined),
      content: Text(l10n.billingFinalizeEncounterBody),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.billingFinalizeEncounterAction,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(l10n.billingActionSaved)));
}

const String _billingQueueFilterKey = 'queue';
const String _billingSourceFilterKey = 'source_module';
const String _billingStatusFilterKey = 'billing_status';
const String _billingFilterPatientId = 'patient_id';
const String _billingFilterInvoiceNumber = 'invoice_number';
const String _billingFilterEncounterId = 'encounter_id';

AppSearchBarFilterValue _billingFilterValue(BillingWorkspaceQuery query) {
  if (!query.hasActiveFilters) {
    return AppSearchBarFilterValue.empty;
  }
  return AppSearchBarFilterValue(
    dateFrom: query.from,
    dateTo: query.to,
    texts: <String, String>{
      if (query.patientId.trim().isNotEmpty)
        _billingFilterPatientId: query.patientId.trim(),
      if (query.invoiceNumber.trim().isNotEmpty)
        _billingFilterInvoiceNumber: query.invoiceNumber.trim(),
      if (query.encounterId.trim().isNotEmpty)
        _billingFilterEncounterId: query.encounterId.trim(),
    },
    options: <String, String>{
      if (query.queue != BillingQueueType.all)
        _billingQueueFilterKey: query.queue.name,
      if (query.sourceModule.trim().isNotEmpty)
        _billingSourceFilterKey: query.sourceModule.trim(),
      if (query.billingStatus.trim().isNotEmpty)
        _billingStatusFilterKey: query.billingStatus.trim(),
    },
  );
}

BillingWorkspaceQuery _billingQueryFromFilter(
  BillingWorkspaceQuery current,
  AppSearchBarFilterValue value,
) {
  return current.copyWith(
    queue: _billingQueueFromFilter(value.option(_billingQueueFilterKey)),
    patientId: value.text(_billingFilterPatientId) ?? '',
    invoiceNumber: value.text(_billingFilterInvoiceNumber) ?? '',
    encounterId: value.text(_billingFilterEncounterId) ?? '',
    sourceModule: value.option(_billingSourceFilterKey) ?? '',
    billingStatus: value.option(_billingStatusFilterKey) ?? '',
    from: value.dateFrom,
    to: value.dateTo,
    clearFrom: value.dateFrom == null,
    clearTo: value.dateTo == null,
    pageRequest: current.pageRequest.first(),
  );
}

List<AppSearchBarTextFilter> _billingTextFilters(AppLocalizations l10n) {
  return <AppSearchBarTextFilter>[
    AppSearchBarTextFilter(
      key: _billingFilterPatientId,
      label: l10n.billingPatientIdColumn,
      icon: Icons.badge_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _billingFilterInvoiceNumber,
      label: l10n.billingInvoiceColumn,
      icon: Icons.receipt_long_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _billingFilterEncounterId,
      label: l10n.billingEncounterLabel,
      icon: Icons.tag_outlined,
      textInputAction: TextInputAction.done,
    ),
  ];
}

List<AppSearchBarFilterGroup> _billingTableFilterGroups(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return <AppSearchBarFilterGroup>[
    AppSearchBarFilterGroup(
      key: _billingQueueFilterKey,
      label: l10n.billingQueueLabel,
      allLabel: billingQueueLabel(context, BillingQueueType.all),
      choices: _billingQueueFilterChoices(context),
    ),
    AppSearchBarFilterGroup(
      key: _billingSourceFilterKey,
      label: l10n.billingSourceFilterLabel,
      allLabel: l10n.billingAnySourceOption,
      choices: _billingSourceFilterChoices(context),
    ),
    AppSearchBarFilterGroup(
      key: _billingStatusFilterKey,
      label: l10n.billingStatusFilterLabel,
      allLabel: l10n.billingAnyStatusOption,
      choices: _billingStatusFilterChoices(context),
    ),
  ];
}

List<AppSearchBarFilterChoice> _billingSourceFilterChoices(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: 'Laboratory',
      label: l10n.billingSourceLaboratory,
      icon: Icons.science_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'Radiology',
      label: l10n.billingSourceRadiology,
      icon: Icons.monitor_heart_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'Pharmacy',
      label: l10n.billingSourcePharmacy,
      icon: Icons.medication_outlined,
    ),
  ];
}

List<AppSearchBarFilterChoice> _billingStatusFilterChoices(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: 'DRAFT',
      label: l10n.billingStatusDraftOption,
      icon: Icons.edit_note_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'ISSUED',
      label: l10n.billingStatusIssuedOption,
      icon: Icons.payments_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'PARTIAL',
      label: l10n.billingStatusPartialOption,
      icon: Icons.pie_chart_outline,
    ),
    AppSearchBarFilterChoice(
      value: 'PAID',
      label: l10n.billingStatusPaidOption,
      icon: Icons.verified_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'OVERDUE',
      label: l10n.billingStatusOverdueOption,
      icon: Icons.warning_amber_outlined,
    ),
  ];
}

BillingQueueType _billingQueueFromFilter(String? value) {
  for (final BillingQueueType queue in BillingQueueType.values) {
    if (queue.name == value) {
      return queue;
    }
  }
  return BillingQueueType.all;
}

List<AppSearchBarFilterChoice> _billingQueueFilterChoices(
  BuildContext context,
) {
  return <AppSearchBarFilterChoice>[
    for (final BillingQueueType queue in BillingQueueType.values)
      if (queue != BillingQueueType.all)
        AppSearchBarFilterChoice(
          value: queue.name,
          label: billingQueueLabel(context, queue),
          icon: billingQueueIcon(queue),
        ),
  ];
}
