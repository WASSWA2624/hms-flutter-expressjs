import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_claim_print_helpers.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_invoice_print_helpers.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_receipt_print_helpers.dart';
import 'package:hosspi_hms/features/billing/presentation/controllers/billing_workspace_controller.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_adjustment_similarity.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_adjustment_similarity_dialog.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_charge_similarity.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_charge_similarity_dialog.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_detail_widgets.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_form_dialogs.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_ledger_dialog.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_price_book_dialogs.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_price_book_panel.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_quick_charge_dialog.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_receive_payment_dialog.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_refund_similarity.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_refund_similarity_dialog.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_workspace_table_support.dart';
import 'package:hosspi_hms/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
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
  late bool _priceBook;

  @override
  void initState() {
    super.initState();
    _section = _normalizeDeskSection(widget.state.query.queue);
    _priceBook = widget.initialQuery?.priceBook ?? widget.state.query.priceBook;
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<BillingWorkItem>();
    _searchController.addListener(_onSearchChanged);
    _scheduleRouteQuery(widget.initialQuery ?? widget.state.query);
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
    if (query == null) {
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

    if (query.priceBook) {
      if (!_priceBook) {
        setState(() => _priceBook = true);
      }
      if (mounted) {
        _updateUrlForPriceBook();
      }
      return;
    }

    if (_priceBook || query.queue != _section) {
      setState(() {
        _priceBook = false;
        _section = _normalizeDeskSection(query.queue);
      });
    }

    if (query.queue != BillingQueueType.all &&
        query.search.trim().isEmpty &&
        query.patientId.trim().isEmpty &&
        query.invoiceNumber.trim().isEmpty &&
        query.encounterId.trim().isEmpty &&
        query.sourceModule.trim().isEmpty &&
        query.billingStatus.trim().isEmpty &&
        !query.overdueOnly &&
        query.ageBucket.trim().isEmpty &&
        query.action.trim().isEmpty) {
      await controller.applyQueue(query.queue);
      if (mounted) {
        _updateUrlForQueue(query.queue, query: query);
      }
      return;
    }
    if (query.hasRouteTargeting) {
      await controller.applyFilters(query);
    }

    if (query.action.trim().toLowerCase() == 'pay' && mounted) {
      await _autoOpenPaymentDialog(query);
    }

    // Always write the canonical desk slug (aliases → work / collect / …).
    if (mounted) {
      _updateUrlForQueue(_section, query: query);
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
              item.displayId == targetInvoice ||
              item.id == targetInvoice);
      if (matchesEncounter || matchesInvoice) {
        target = item;
        break;
      }
    }

    if (target != null &&
        mounted &&
        canWriteBilling(ref.read(appAccessPolicyProvider)) &&
        target.canReceivePayment) {
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
    // Desk selection for Price book is owned by this page (URL / tab strip), not
    // by BillingWorkspaceController.query (work-queue only).
    if (!_priceBook && widget.state.query.queue != _section) {
      setState(() => _section = _normalizeDeskSection(widget.state.query.queue));
    }
  }

  static BillingQueueType _normalizeDeskSection(BillingQueueType queue) {
    return queue == BillingQueueType.overdue
        ? BillingQueueType.pendingPayment
        : queue;
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
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

  void _updateUrlForQueue(BillingQueueType queue, {BillingWorkspaceQuery? query}) {
    if (!mounted) return;
    final BillingWorkspaceQuery current = query ?? widget.state.query;
    final BillingQueueType desk =
        queue == BillingQueueType.overdue
        ? BillingQueueType.pendingPayment
        : queue;
    final Map<String, String> params = <String, String>{
      'section': desk.sectionQueryValue,
    };
    if (desk == BillingQueueType.pendingPayment && current.overdueOnly) {
      params['overdue'] = 'yes';
    }
    final String location = AppRoutes.billing.location(queryParameters: params);
    GoRouter.of(context).replace<void>(location);
  }

  void _updateUrlForPriceBook() {
    if (!mounted) return;
    final String location = AppRoutes.billing.location(
      queryParameters: const <String, String>{'section': 'prices'},
    );
    GoRouter.of(context).replace<void>(location);
  }

  void _selectQueue(BillingQueueType queue) {
    final BillingQueueType desk = _normalizeDeskSection(queue);
    if (_priceBook || _section != desk) {
      setState(() {
        _priceBook = false;
        _section = desk;
      });
    }
    _updateUrlForQueue(desk);
    ref.read(billingWorkspaceControllerProvider.notifier).applyQueue(desk);
  }

  void _selectPriceBook() {
    if (!_priceBook) {
      setState(() => _priceBook = true);
    }
    _updateUrlForPriceBook();
  }

  @override
  Widget build(BuildContext context) {
    final BillingWorkspaceState state = widget.state;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = canWriteBilling(accessPolicy);
    final List<BillingQueueType> visibleQueues = <BillingQueueType>[
      for (final BillingQueueType queue in BillingQueueType.values)
        if (queue.isDeskSection && canViewBillingQueue(accessPolicy, queue))
          queue,
    ];
    final bool showPriceBook = canViewBillingPriceBook(accessPolicy);
    if (visibleQueues.isEmpty && !showPriceBook) {
      // No authorized queues — omit chrome (no routine "no access" banner).
      return const SizedBox.shrink();
    }
    if (_priceBook && !showPriceBook) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_priceBook) {
          return;
        }
        final BillingQueueType fallback = visibleQueues.isEmpty
            ? BillingQueueType.all
            : visibleQueues.first;
        _selectQueue(fallback);
      });
    } else if (!_priceBook && !visibleQueues.contains(_section)) {
      final BillingQueueType fallback = visibleQueues.isEmpty
          ? BillingQueueType.all
          : visibleQueues.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _priceBook || visibleQueues.contains(_section)) {
          return;
        }
        _selectQueue(fallback);
      });
    }
    final BillingWorkspaceController controller = ref.read(
      billingWorkspaceControllerProvider.notifier,
    );
    // Mutation dialogs/snackbars already surface actionable errors. Do not park
    // a page-level failure banner between the tabs and table.
    final AppFailure? lastFailure = state.lastFailure is AppFailure
        ? state.lastFailure! as AppFailure
        : null;
    if (lastFailure != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.clearLastFailure();
      });
    }
    final ThemeData theme = Theme.of(context);

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: <AppTabItem>[
                for (final BillingQueueType queue in visibleQueues)
                  AppTabItem(
                    id: queue.name,
                    icon: billingQueueIcon(queue),
                    label: billingQueueLabel(context, queue),
                    tooltip: billingQueueTooltip(context, queue),
                    count: state.overview.summary.countFor(queue),
                    countTone: billingQueueCountTone(queue),
                  ),
                if (showPriceBook)
                  AppTabItem(
                    id: 'prices',
                    icon: Icons.menu_book_outlined,
                    label: context.l10n.billingPriceBookTab,
                    tooltip: context.l10n.billingPriceBookTooltip,
                    count: ref.watch(billingPriceBookActiveCountProvider),
                  ),
              ],
              selectedId: _priceBook ? 'prices' : _section.name,
              onTabTapped: (String tabId) {
                if (tabId == 'prices') {
                  _selectPriceBook();
                  return;
                }
                for (final BillingQueueType queue in visibleQueues) {
                  if (queue.name == tabId) {
                    _selectQueue(queue);
                    break;
                  }
                }
              },
            ),
            SizedBox(height: theme.spacing.md),
            if (_priceBook)
              const BillingPriceBookPanel()
            else
              _BillingQueuePanel(
                state: state,
                accessPolicy: accessPolicy,
                canWrite: canWrite,
                searchController: _searchController,
                columnVisibilityController: _tableColumnController,
                activeQueue: _section,
              ),
          ],
        ),
      ),
    );
  }
}

class _BillingQueuePanel extends ConsumerWidget {
  const _BillingQueuePanel({
    required this.state,
    required this.accessPolicy,
    required this.canWrite,
    required this.searchController,
    required this.columnVisibilityController,
    required this.activeQueue,
  });

  final BillingWorkspaceState state;
  final AppAccessPolicy accessPolicy;
  final bool canWrite;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<BillingWorkItem>
  columnVisibilityController;
  final BillingQueueType activeQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final controller = ref.read(billingWorkspaceControllerProvider.notifier);

    final AppListTable<BillingWorkItem> table = AppListTable<BillingWorkItem>(
      page: state.workItems,
      isLoading: state.isRefreshing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      columnVisibilityController: columnVisibilityController,
      columnVisibilityStorageKey: billingTableSettingsKey(activeQueue),
      columnWidthStorageKey: '${billingTableSettingsKey(activeQueue)}_cw',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      search: AppListTableSearch<BillingWorkItem>(
        controller: searchController,
        semanticLabel: l10n.billingSearchSemanticLabel,
        hintText: l10n.billingSearchHint,
        clearLabel: l10n.billingClearSearch,
        matcher: (BillingWorkItem item, String query) =>
            billingWorkItemMatchesSearch(context, item, query),
        onSubmitted: controller.applySearch,
        onClear: () => controller.applySearch(''),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.billingFiltersLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.billingClearFilters,
        dateFilterLabel: l10n.billingIssuedDateFilterLabel,
        dateFromLabel: l10n.opdDateFromLabel,
        dateToLabel: l10n.opdDateToLabel,
        allFieldsLabel: billingQueueLabel(context, BillingQueueType.all),
        textFilters: _billingTextFilters(l10n),
        filterGroups: _billingTableFilterGroups(context, activeQueue),
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
        // Trailing strip ownership (billing.md §5): Charge / Issue all /
        // Close shift·day / Add on their owner tabs only.
        trailingActions: _billingTrailingSearchActions(
          context,
          ref,
          l10n,
          activeQueue: activeQueue,
          state: state,
          canWrite: canWrite,
          enabled: !state.isSaving,
        ),
      ),
      itemKeyBuilder: (BillingWorkItem item) => ValueKey<String>(item.id),
      onRowSelected: (BillingWorkItem item) {
        controller.selectItem(item);
        _showBillingDetailDialog(
          context,
          ref,
          item,
          canWrite: canWrite,
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
        final String emptyBody = _billingEmptyBodyForQueue(l10n, activeQueue);
        final bool shortEmptyCopy =
            activeQueue == BillingQueueType.all ||
            activeQueue == BillingQueueType.claimsPending ||
            activeQueue == BillingQueueType.approvalRequired ||
            activeQueue == BillingQueueType.needsIssue ||
            activeQueue == BillingQueueType.pendingPayment;
        return AppWorkspaceStatePanel.empty(
          title: shortEmptyCopy ? emptyBody : l10n.billingEmptyTitle,
          body: shortEmptyCopy ? '' : emptyBody,
        );
      },
      columns: billingColumnsForQueue(
        context,
        l10n,
        activeQueue,
        ref: ref,
        accessPolicy: accessPolicy,
        canWrite: canWrite,
        isSaving: state.isSaving,
        onNextAction: _runBillingNextAction,
      ),
      columnChoices: billingColumnChoicesForQueue(
        context,
        l10n,
        activeQueue,
        ref: ref,
        accessPolicy: accessPolicy,
        canWrite: canWrite,
        isSaving: state.isSaving,
        onNextAction: _runBillingNextAction,
      ),
      mobileItemBuilder: (BuildContext context, BillingWorkItem item) {
        return AppListTableMobileItem(
          title: billingPatientName(context, item),
          caption: billingWorkItemPublicId(context, item),
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: billingWorkItemStatusLabel(context, item),
              icon: billingWorkItemStatusIcon(item),
            ),
            AppListTableMobileMeta(
              label: billingMoney(context, item.balanceDue, item.currency),
              icon: Icons.account_balance_wallet_outlined,
            ),
          ],
        );
      },
    );

    if (activeQueue != BillingQueueType.pendingPayment) {
      return table;
    }

    final ThemeData theme = Theme.of(context);
    final Color danger = theme.statusColors.danger;
    final int overdueCount = state.overview.summary.overdue;
    final bool overdueSelected = state.query.overdueOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.sm),
            child: FilterChip(
              key: const ValueKey<String>('billing-collect-overdue-chip'),
              selected: overdueSelected,
              showCheckmark: false,
              avatar: Icon(
                Icons.warning_amber_outlined,
                size: 18,
                color: danger,
              ),
              label: Text(
                overdueCount > 0
                    ? '${l10n.billingOverdue} ($overdueCount)'
                    : l10n.billingOverdue,
                style: TextStyle(color: danger),
              ),
              selectedColor: danger.withValues(alpha: 0.16),
              side: BorderSide(color: danger.withValues(alpha: 0.45)),
              onSelected: (bool selected) {
                unawaited(
                  _toggleCollectOverdueFilter(
                    context,
                    ref,
                    state: state,
                    selected: selected,
                  ),
                );
              },
            ),
          ),
        ),
        table,
      ],
    );
  }
}

Future<void> _toggleCollectOverdueFilter(
  BuildContext context,
  WidgetRef ref, {
  required BillingWorkspaceState state,
  required bool selected,
}) async {
  final BillingWorkspaceQuery next = state.query.copyWith(
    queue: BillingQueueType.pendingPayment,
    overdueOnly: selected,
  );
  await ref.read(billingWorkspaceControllerProvider.notifier).applyFilters(next);
  if (!context.mounted) {
    return;
  }
  final Map<String, String> params = <String, String>{'section': 'collect'};
  if (selected) {
    params['overdue'] = 'yes';
  }
  GoRouter.of(context).replace<void>(
    AppRoutes.billing.location(queryParameters: params),
  );
}

Future<void> _runBillingNextAction(
  BuildContext context,
  WidgetRef ref,
  BillingWorkItem item,
) async {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  if (!billingNextActionIsAllowed(policy, item)) {
    return;
  }
  // Select before mutation dialogs that operate on the workspace selection.
  ref.read(billingWorkspaceControllerProvider.notifier).selectItem(item);
  if (item.canApproveOrReject) {
    await _showApproveDialog(context, ref);
    return;
  }
  if (item.canIssue) {
    await _showIssueDialog(context, ref);
    return;
  }
  if (item.canReceivePayment) {
    await _showPaymentDialog(context, ref, item);
    return;
  }
  if (item.canSubmitClaim) {
    await _showSubmitClaimDialog(context, ref);
    return;
  }
  if (item.canReconcileClaim) {
    await _showReconcileClaimDialog(context, ref);
    return;
  }
  if (item.canApprovePreAuthorization) {
    await _showPreAuthStatusDialog(context, ref, status: 'APPROVED');
    return;
  }
  if (item.canRequestRefund) {
    await _showRefundDialog(context, ref, item);
    return;
  }
  if (item.canRequestAdjustment) {
    await _showAdjustmentDialog(context, ref, item);
    return;
  }
  if (item.canRequestVoid) {
    await _showVoidDialog(context, ref);
    return;
  }
  if (item.isInvoice && !billingWorkItemIsCancelled(item)) {
    await _showSendDialog(context, ref);
  }
}

Future<void> _showBillingDetailDialog(
  BuildContext context,
  WidgetRef ref,
  BillingWorkItem item, {
  required bool canWrite,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => _BillingLiveDetailDialog(
      initialItem: item,
      canWrite: canWrite,
    ),
  );
}

class _BillingLiveDetailDialog extends ConsumerStatefulWidget {
  const _BillingLiveDetailDialog({
    required this.initialItem,
    required this.canWrite,
  });

  final BillingWorkItem initialItem;
  final bool canWrite;

  @override
  ConsumerState<_BillingLiveDetailDialog> createState() =>
      _BillingLiveDetailDialogState();
}

class _BillingLiveDetailDialogState
    extends ConsumerState<_BillingLiveDetailDialog> {
  late BillingWorkItem _item = widget.initialItem;

  BillingWorkItem _resolveLiveItem(BillingWorkspaceState? state) {
    if (state == null) {
      return _item;
    }
    BillingWorkItem? live;
    if (state.selectedItem?.id == widget.initialItem.id) {
      live = state.selectedItem;
    } else {
      for (final BillingWorkItem candidate in state.workItems.items) {
        if (candidate.id == widget.initialItem.id) {
          live = candidate;
          break;
        }
      }
    }
    if (live == null) {
      return _item;
    }
    // Keep a locally paid snapshot if a queue refresh briefly returns unpaid.
    final bool cachedLooksPaid =
        _item.id == live.id &&
        _item.balanceDue <= 0.009 &&
        _item.paidAmount >= live.paidAmount;
    final bool liveLooksUnpaid =
        live.balanceDue > 0.009 &&
        (live.billingStatus ?? '').toUpperCase() != 'PAID';
    if (cachedLooksPaid && liveLooksUnpaid) {
      return _item;
    }
    return live;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canApprove = canApproveBillingMutations(accessPolicy);
    final bool canClaimsWrite = canWriteBillingClaims(accessPolicy);
    final bool canDocument = canReadBillingDocument(accessPolicy);
    final AsyncValue<Result<BillingWorkspaceState>> asyncState = ref.watch(
      billingWorkspaceControllerProvider,
    );
    final BillingWorkspaceState? workspace = asyncState.asData?.value.when(
      success: (BillingWorkspaceState value) => value,
      failure: (_) => null,
    );
    final BillingWorkItem item = _resolveLiveItem(workspace);
    _item = item;
    final bool isSaving = workspace?.isSaving ?? false;

    return AppDialog(
      title: Text(billingDetailTitle(context, item)),
      icon: const Icon(Icons.receipt_long_outlined),
      scrollable: true,
      maxWidth: 940,
      content: BillingDetailBody(
        item: item,
        canWrite: widget.canWrite,
        canApprove: canApprove,
        canWriteClaims: canClaimsWrite,
        isSaving: isSaving,
        onReceivePayment: widget.canWrite && item.canReceivePayment
            ? () => _showPaymentDialog(context, ref, item)
            : null,
        onIssue: widget.canWrite && item.canIssue
            ? () => _showIssueDialog(context, ref)
            : null,
        onRefund: widget.canWrite && item.canRequestRefund
            ? () => _showRefundDialog(context, ref, item)
            : null,
        onAdjust: widget.canWrite && item.canRequestAdjustment
            ? () => _showAdjustmentDialog(context, ref, item)
            : null,
        onVoid: widget.canWrite && item.canRequestVoid
            ? () => _showVoidDialog(context, ref)
            : null,
        onSend: widget.canWrite &&
                item.isInvoice &&
                !billingWorkItemIsCancelled(item)
            ? () => _showSendDialog(context, ref)
            : null,
        onApprove: canApprove && item.canApproveOrReject
            ? () => _showApproveDialog(context, ref)
            : null,
        onReject: canApprove && item.canApproveOrReject
            ? () => _showRejectDialog(context, ref)
            : null,
        onSubmitClaim: canClaimsWrite && item.canSubmitClaim
            ? () => _showSubmitClaimDialog(context, ref)
            : null,
        onReconcileClaim: canClaimsWrite && item.canReconcileClaim
            ? () => _showReconcileClaimDialog(context, ref)
            : null,
        onApprovePreAuthorization:
            canClaimsWrite && item.canApprovePreAuthorization
            ? () => _showPreAuthStatusDialog(context, ref, status: 'APPROVED')
            : null,
        onDenyPreAuthorization: canClaimsWrite && item.canDenyPreAuthorization
            ? () => _showPreAuthStatusDialog(context, ref, status: 'DENIED')
            : null,
        onViewLedger: canViewBillingLedger(accessPolicy, item) &&
                (item.patientId ?? item.effectivePatientNumber) != null
            ? () => showBillingLedgerDialog(context, ref, item: item)
            : null,
      ),
      // Inventory: invoice Print/Download; claim/pre-auth Print statement —
      // omit when unauthorized (no disabled stubs).
      actions: <Widget>[
        if (canDocument && item.isInvoice) ...<Widget>[
          AppReportActionButton.print(
            label: l10n.billingPrintInvoiceAction,
            tooltip: l10n.billingPrintInvoiceTooltip,
            onPressed: () => printBillingInvoice(
              ref: ref,
              context: context,
              item: item,
            ),
          ),
          AppReportActionButton.download(
            label: l10n.billingInvoiceLabel,
            tooltip: l10n.billingDocumentTooltip,
            onPressed: () => _downloadInvoiceDocument(context, ref, item),
          ),
        ],
        if (canDocument &&
            (item.isClaim || item.isPreAuthorization))
          AppReportActionButton.print(
            label: l10n.billingPrintClaimAction,
            tooltip: l10n.billingPrintClaimTooltip,
            onPressed: () => printBillingClaimOrPreAuth(
              ref: ref,
              context: context,
              item: item,
            ),
          ),
      ],
    );
  }
}

Future<void> _showPaymentDialog(
  BuildContext context,
  WidgetRef ref,
  BillingWorkItem item,
) async {
  ref.read(billingWorkspaceControllerProvider.notifier).selectItem(item);
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
  if (failure != null || !draft.issueReceipt || !context.mounted) {
    return;
  }
  final BillingWorkItem receiptItem = ref
          .read(billingWorkspaceControllerProvider)
          .asData
          ?.value
          .when(
            success: (BillingWorkspaceState state) =>
                state.selectedItem ?? item,
            failure: (_) => item,
          ) ??
      item;
  await printBillingReceipt(
    ref: ref,
    context: context,
    item: receiptItem,
    draft: draft,
  );
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

  final bool shouldSubmit = await _reviewRefundSimilarity(
    context,
    item: item,
    draft: draft,
  );
  if (!shouldSubmit || !context.mounted) {
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

Future<bool> _reviewRefundSimilarity(
  BuildContext context, {
  required BillingWorkItem item,
  required BillingRefundDraft draft,
}) async {
  final BillingRefundSimilarityResult check = checkBillingRefundSimilarity(
    invoice: item,
    draft: draft,
  );
  if (!check.hasMatches) {
    return true;
  }

  final BillingRefundSimilarityDialogResult result =
      await showBillingRefundSimilarityDialog(
        context,
        invoice: item,
        draft: draft,
        check: check,
      );
  if (!context.mounted) {
    return false;
  }
  switch (result.action) {
    case BillingRefundSimilarityAction.cancel:
      return false;
    case BillingRefundSimilarityAction.proceed:
      return true;
    case BillingRefundSimilarityAction.useExisting:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.billingRefundExistingSelectedSnackbar),
        ),
      );
      return false;
  }
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

  final bool shouldSubmit = await _reviewAdjustmentSimilarity(
    context,
    item: item,
    draft: draft,
  );
  if (!shouldSubmit || !context.mounted) {
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

Future<bool> _reviewAdjustmentSimilarity(
  BuildContext context, {
  required BillingWorkItem item,
  required BillingAdjustmentDraft draft,
}) async {
  final BillingAdjustmentSimilarityResult check =
      checkBillingAdjustmentSimilarity(invoice: item, draft: draft);
  if (!check.hasMatches) {
    return true;
  }

  final BillingAdjustmentSimilarityDialogResult result =
      await showBillingAdjustmentSimilarityDialog(
        context,
        invoice: item,
        draft: draft,
        check: check,
      );
  if (!context.mounted) {
    return false;
  }
  switch (result.action) {
    case BillingAdjustmentSimilarityAction.cancel:
      return false;
    case BillingAdjustmentSimilarityAction.proceed:
      return true;
    case BillingAdjustmentSimilarityAction.useExisting:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.billingAdjustExistingSelectedSnackbar),
        ),
      );
      return false;
  }
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

List<AppSearchBarAction> _billingTrailingSearchActions(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n, {
  required BillingQueueType activeQueue,
  required BillingWorkspaceState state,
  required bool canWrite,
  required bool enabled,
}) {
  // Trailing ownership (billing.md §5): Charge → Open work; Issue all → To issue;
  // Close shift/day → Collect due; none elsewhere.
  if (activeQueue == BillingQueueType.all) {
    if (!canWrite) {
      return const <AppSearchBarAction>[];
    }
    return <AppSearchBarAction>[
      AppSearchBarAction(
        icon: Icons.add_card_outlined,
        label: l10n.billingChargeAction,
        tooltip: l10n.billingChargeTooltip,
        enabled: enabled,
        onPressed: enabled ? () => _showChargeDialog(context, ref) : null,
      ),
    ];
  }
  if (activeQueue == BillingQueueType.approvalRequired ||
      activeQueue == BillingQueueType.claimsPending) {
    return const <AppSearchBarAction>[];
  }
  if (activeQueue == BillingQueueType.needsIssue) {
    if (!canWrite) {
      return const <AppSearchBarAction>[];
    }
    final List<BillingWorkItem> issuable = state.workItems.items
        .where((BillingWorkItem item) => item.canIssue)
        .toList(growable: false);
    final bool canIssueAll = enabled && issuable.isNotEmpty;
    return <AppSearchBarAction>[
      AppSearchBarAction(
        icon: Icons.outbox_outlined,
        label: l10n.billingIssueAllAction,
        tooltip: l10n.billingIssueAllAction,
        enabled: canIssueAll,
        onPressed: canIssueAll
            ? () => _showIssueAllDialog(context, ref, issuable)
            : null,
      ),
    ];
  }
  if (activeQueue == BillingQueueType.pendingPayment) {
    return _billingCloseSearchActions(
      context,
      ref,
      l10n,
      canWrite: canWrite,
      enabled: enabled,
    );
  }
  return const <AppSearchBarAction>[];
}

List<AppSearchBarAction> _billingCloseSearchActions(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n, {
  required bool canWrite,
  required bool enabled,
}) {
  if (!canWrite) {
    return const <AppSearchBarAction>[];
  }
  return <AppSearchBarAction>[
    AppSearchBarAction(
      icon: Icons.today_outlined,
      label: l10n.billingCloseDay,
      tooltip: l10n.billingCloseDay,
      enabled: enabled,
      onPressed: enabled ? () => _showDayCloseDialog(context, ref) : null,
    ),
    AppSearchBarAction(
      icon: Icons.schedule_send_outlined,
      label: l10n.billingCloseShift,
      tooltip: l10n.billingCloseShift,
      enabled: enabled,
      onPressed: enabled ? () => _showShiftCloseDialog(context, ref) : null,
    ),
  ];
}

Future<void> _showIssueAllDialog(
  BuildContext context,
  WidgetRef ref,
  List<BillingWorkItem> issuable,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AppConfirmActionDialog(
        title: l10n.billingIssueAllConfirmTitle,
        body: l10n.billingIssueAllConfirmBody,
        submitLabel: l10n.billingIssueAllAction,
        icon: const Icon(Icons.outbox_outlined),
      );
    },
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(billingWorkspaceControllerProvider.notifier)
      .issueInvoices(
        issuable.map((BillingWorkItem item) => item.id).toList(growable: false),
      );
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, ref, failure);
}

Future<void> _showChargeDialog(BuildContext context, WidgetRef ref) async {
  final BillingChargeDraft? draft = await showBillingQuickChargeDialog(context);
  if (draft == null || !context.mounted) {
    return;
  }

  final bool shouldCreate = await _reviewChargeSimilarity(
    context,
    ref,
    draft,
  );
  if (!shouldCreate || !context.mounted) {
    return;
  }

  final AppFailure? failure = await ref
      .read(billingWorkspaceControllerProvider.notifier)
      .createCharge(draft);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, ref, failure);
  if (failure != null || !context.mounted) {
    return;
  }
  // Charge creates a draft and lands on To issue (billing.md §4.1 / §7).
  await _openToIssueQueue(context, ref);
}

Future<bool> _reviewChargeSimilarity(
  BuildContext context,
  WidgetRef ref,
  BillingChargeDraft draft,
) async {
  final List<BillingWorkItem> candidates = await _loadChargeSimilarityCandidates(
    ref,
    draft,
  );
  if (!context.mounted) {
    return false;
  }
  final BillingChargeSimilarityResult check = checkBillingChargeSimilarity(
    draft: draft,
    candidates: candidates,
  );
  if (!check.hasMatches) {
    return true;
  }

  final BillingChargeSimilarityDialogResult result =
      await showBillingChargeSimilarityDialog(
        context,
        draft: draft,
        check: check,
      );
  if (!context.mounted) {
    return false;
  }
  switch (result.action) {
    case BillingChargeSimilarityAction.cancel:
      return false;
    case BillingChargeSimilarityAction.proceed:
      return true;
    case BillingChargeSimilarityAction.useExisting:
      final BillingWorkItem? existing = result.selectedItem;
      if (existing == null) {
        return false;
      }
      await _openExistingChargeDraft(context, ref, existing);
      return false;
  }
}

Future<List<BillingWorkItem>> _loadChargeSimilarityCandidates(
  WidgetRef ref,
  BillingChargeDraft draft,
) async {
  final List<BillingWorkItem> candidates = <BillingWorkItem>[];
  final AsyncValue<Result<BillingWorkspaceState>> workspace = ref.read(
    billingWorkspaceControllerProvider,
  );
  final Result<BillingWorkspaceState>? current = workspace.asData?.value;
  if (current != null) {
    current.when(
      success: (BillingWorkspaceState state) {
        candidates.addAll(state.workItems.items);
      },
      failure: (_) {},
    );
  }

  final String search =
      (draft.patientDisplayId ?? draft.patientDisplayName ?? '').trim();
  final Result<AppPage<BillingWorkItem>> drafts = await ref
      .read(billingRepositoryProvider)
      .listWorkItems(
        BillingWorkspaceQuery(
          queue: BillingQueueType.needsIssue,
          search: search,
        ),
      );
  drafts.when(
    success: (AppPage<BillingWorkItem> page) {
      candidates.addAll(page.items);
    },
    failure: (_) {},
  );

  final Map<String, BillingWorkItem> unique = <String, BillingWorkItem>{};
  for (final BillingWorkItem item in candidates) {
    unique[item.id] = item;
  }
  return unique.values.toList(growable: false);
}

Future<void> _openExistingChargeDraft(
  BuildContext context,
  WidgetRef ref,
  BillingWorkItem item,
) async {
  await _openToIssueQueue(context, ref);
  if (!context.mounted) {
    return;
  }
  ref.read(billingWorkspaceControllerProvider.notifier).selectItem(item);
  await _showBillingDetailDialog(
    context,
    ref,
    item,
    canWrite: canWriteBilling(ref.read(appAccessPolicyProvider)),
  );
}

Future<void> _openToIssueQueue(BuildContext context, WidgetRef ref) async {
  final String location = AppRoutes.billing.location(
    queryParameters: const <String, String>{'section': 'issue'},
  );
  GoRouter.of(context).replace<void>(location);
  await ref
      .read(billingWorkspaceControllerProvider.notifier)
      .applyQueue(BillingQueueType.needsIssue);
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

const String _billingSourceFilterKey = 'source_module';
const String _billingStatusFilterKey = 'billing_status';
const String _billingApprovalTypeFilterKey = 'approval_type';
const String _billingOverdueFilterKey = 'overdue';
const String _billingAgeFilterKey = 'age';
const String _billingFilterPatientId = 'patient_id';
const String _billingFilterInvoiceNumber = 'invoice_number';
const String _billingFilterEncounterId = 'encounter_id';

String _billingEmptyBodyForQueue(
  AppLocalizations l10n,
  BillingQueueType queue,
) {
  return switch (queue) {
    BillingQueueType.needsIssue => l10n.billingEmptyReadyToIssueBody,
    BillingQueueType.pendingPayment => l10n.billingEmptyCollectDueBody,
    BillingQueueType.claimsPending => l10n.billingEmptyClaimsPendingBody,
    BillingQueueType.approvalRequired => l10n.billingEmptyApprovalRequiredBody,
    BillingQueueType.overdue => l10n.billingEmptyOverdueBody,
    BillingQueueType.all => l10n.billingEmptyBody,
  };
}
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
      if (query.sourceModule.trim().isNotEmpty)
        _billingSourceFilterKey: query.sourceModule.trim(),
      if (query.billingStatus.trim().isNotEmpty)
        _billingStatusFilterKey: query.billingStatus.trim(),
      if (query.approvalType.trim().isNotEmpty)
        _billingApprovalTypeFilterKey: query.approvalType.trim(),
      if (query.overdueOnly) _billingOverdueFilterKey: 'yes',
      if (query.ageBucket.trim().isNotEmpty)
        _billingAgeFilterKey: query.ageBucket.trim(),
    },
  );
}

BillingWorkspaceQuery _billingQueryFromFilter(
  BillingWorkspaceQuery current,
  AppSearchBarFilterValue value,
) {
  return current.copyWith(
    // Queue stays with the tab strip — advanced filters must not restate it.
    patientId: value.text(_billingFilterPatientId) ?? '',
    invoiceNumber: value.text(_billingFilterInvoiceNumber) ?? '',
    encounterId: value.text(_billingFilterEncounterId) ?? '',
    sourceModule: value.option(_billingSourceFilterKey) ?? '',
    billingStatus: value.option(_billingStatusFilterKey) ?? '',
    approvalType: value.option(_billingApprovalTypeFilterKey) ?? '',
    overdueOnly: value.option(_billingOverdueFilterKey) == 'yes',
    ageBucket: value.option(_billingAgeFilterKey) ?? '',
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
      label: l10n.billingPatientFilterLabel,
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

List<AppSearchBarFilterGroup> _billingTableFilterGroups(
  BuildContext context,
  BillingQueueType queue,
) {
  final AppLocalizations l10n = context.l10n;
  if (queue == BillingQueueType.approvalRequired) {
    return <AppSearchBarFilterGroup>[
      AppSearchBarFilterGroup(
        key: _billingApprovalTypeFilterKey,
        label: l10n.billingApprovalTypeFilterLabel,
        allLabel: l10n.billingAnyApprovalTypeOption,
        choices: _billingApprovalTypeFilterChoices(context),
      ),
      AppSearchBarFilterGroup(
        key: _billingStatusFilterKey,
        label: l10n.billingStatusFilterLabel,
        allLabel: l10n.billingAnyStatusOption,
        choices: _billingApprovalStatusFilterChoices(context),
      ),
    ];
  }
  if (queue == BillingQueueType.needsIssue) {
    return <AppSearchBarFilterGroup>[
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
        choices: _billingNeedsIssueStatusFilterChoices(context),
      ),
    ];
  }
  if (queue == BillingQueueType.claimsPending) {
    return <AppSearchBarFilterGroup>[
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
        choices: _billingClaimsStatusFilterChoices(context),
      ),
    ];
  }
  if (queue == BillingQueueType.all) {
    return <AppSearchBarFilterGroup>[
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
        choices: _billingOpenWorkStatusFilterChoices(context),
      ),
    ];
  }
  if (queue == BillingQueueType.pendingPayment ||
      queue == BillingQueueType.overdue) {
    return <AppSearchBarFilterGroup>[
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
        choices: _billingCollectStatusFilterChoices(context),
      ),
      AppSearchBarFilterGroup(
        key: _billingOverdueFilterKey,
        label: l10n.billingOverdueFilterLabel,
        allLabel: l10n.billingAnyStatusOption,
        choices: _billingOverdueFilterChoices(context),
      ),
      AppSearchBarFilterGroup(
        key: _billingAgeFilterKey,
        label: l10n.billingAgeFilterLabel,
        allLabel: l10n.billingAnyStatusOption,
        choices: _billingAgeFilterChoices(context),
      ),
    ];
  }
  return <AppSearchBarFilterGroup>[
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

List<AppSearchBarFilterChoice> _billingOpenWorkStatusFilterChoices(
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
      icon: Icons.receipt_long_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'PARTIAL',
      label: l10n.billingStatusPartialOption,
      icon: Icons.pie_chart_outline,
    ),
    AppSearchBarFilterChoice(
      value: 'OVERDUE',
      label: l10n.billingStatusOverdueOption,
      icon: Icons.warning_amber_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'PENDING',
      label: l10n.billingStatusPendingApprovalOption,
      icon: Icons.rule_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'SUBMITTED',
      label: l10n.billingStatusClaimSubmittedOption,
      icon: Icons.upload_outlined,
    ),
  ];
}

List<AppSearchBarFilterChoice> _billingNeedsIssueStatusFilterChoices(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: 'DRAFT',
      label: l10n.billingStatusDraftOption,
      icon: Icons.edit_note_outlined,
    ),
  ];
}

List<AppSearchBarFilterChoice> _billingCollectStatusFilterChoices(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: 'ISSUED',
      label: l10n.billingStatusIssuedOption,
      icon: Icons.receipt_long_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'PARTIAL',
      label: l10n.billingStatusPartialOption,
      icon: Icons.pie_chart_outline,
    ),
    AppSearchBarFilterChoice(
      value: 'OVERDUE',
      label: l10n.billingOverdue,
      icon: Icons.warning_amber_outlined,
    ),
  ];
}

List<AppSearchBarFilterChoice> _billingOverdueFilterChoices(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: 'yes',
      label: l10n.billingOverdueYesOption,
      icon: Icons.warning_amber_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'no',
      label: l10n.billingOverdueNoOption,
      icon: Icons.check_circle_outline,
    ),
  ];
}

List<AppSearchBarFilterChoice> _billingAgeFilterChoices(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: '0-7',
      label: l10n.billingAge0to7Option,
      icon: Icons.today_outlined,
    ),
    AppSearchBarFilterChoice(
      value: '8-30',
      label: l10n.billingAge8to30Option,
      icon: Icons.date_range_outlined,
    ),
    AppSearchBarFilterChoice(
      value: '31+',
      label: l10n.billingAge31PlusOption,
      icon: Icons.history_outlined,
    ),
  ];
}

List<AppSearchBarFilterChoice> _billingClaimsStatusFilterChoices(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: 'PENDING',
      label: l10n.billingStatusAuthPendingOption,
      icon: Icons.schedule_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'SUBMITTED',
      label: l10n.billingStatusClaimSubmittedOption,
      icon: Icons.upload_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'REJECTED',
      label: l10n.billingStatusRejectedOption,
      icon: Icons.cancel_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'DENIED',
      label: l10n.billingStatusAuthDeniedOption,
      icon: Icons.block_outlined,
    ),
  ];
}

List<AppSearchBarFilterChoice> _billingApprovalTypeFilterChoices(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: 'REFUND',
      label: l10n.billingApprovalTypeRefundOption,
      icon: Icons.undo_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'VOID',
      label: l10n.billingApprovalTypeVoidOption,
      icon: Icons.block_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'ADJUSTMENT',
      label: l10n.billingApprovalTypeAdjustmentOption,
      icon: Icons.tune_outlined,
    ),
  ];
}

List<AppSearchBarFilterChoice> _billingApprovalStatusFilterChoices(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: 'PENDING',
      label: l10n.billingStatusPendingApprovalOption,
      icon: Icons.hourglass_empty_outlined,
    ),
  ];
}

List<AppSearchBarFilterChoice> _billingSourceFilterChoices(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: 'OPD',
      label: l10n.billingSourceOpd,
      icon: Icons.local_hospital_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'Emergency',
      label: l10n.billingSourceEmergency,
      icon: Icons.emergency_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'Inpatient',
      label: l10n.billingSourceInpatient,
      icon: Icons.bed_outlined,
    ),
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
    AppSearchBarFilterChoice(
      value: 'Theatre',
      label: l10n.billingSourceTheatre,
      icon: Icons.airline_seat_flat_angled_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'Clinical',
      label: l10n.billingSourceClinical,
      icon: Icons.medical_services_outlined,
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
      icon: Icons.receipt_long_outlined,
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
    AppSearchBarFilterChoice(
      value: 'CANCELLED',
      label: l10n.billingStatusCancelledOption,
      icon: Icons.block_outlined,
    ),
  ];
}
