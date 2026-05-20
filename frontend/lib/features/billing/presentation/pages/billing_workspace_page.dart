import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/controllers/billing_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class BillingWorkspacePage extends ConsumerWidget {
  const BillingWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Result<BillingWorkspaceState>> workspace = ref.watch(
      billingWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<BillingWorkspaceState>(
      value: workspace,
      appBarTitle: 'Billing',
      loadingTitle: 'Loading billing workspace',
      loadingBody: 'Fetching invoices, payments, refunds, and closeout queues.',
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(billingWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, BillingWorkspaceState state) {
        return _BillingWorkspaceContent(state: state);
      },
    );
  }
}

class _BillingWorkspaceContent extends ConsumerStatefulWidget {
  const _BillingWorkspaceContent({required this.state});

  final BillingWorkspaceState state;

  @override
  ConsumerState<_BillingWorkspaceContent> createState() =>
      _BillingWorkspaceContentState();
}

class _BillingWorkspaceContentState
    extends ConsumerState<_BillingWorkspaceContent> {
  late final AppListTableColumnVisibilityController<BillingWorkItem>
  _tableColumnController;

  @override
  void initState() {
    super.initState();
    _tableColumnController =
        AppListTableColumnVisibilityController<BillingWorkItem>();
  }

  @override
  void dispose() {
    _tableColumnController.dispose();
    super.dispose();
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

    return AppWorkspace(
      title: 'Billing',
      leadingIcon: AppRouteIcons.billing,
      status: AppWorkspaceStatus(
        label: state.isSaving ? 'Posting' : 'Live',
        tone: state.isSaving
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
        icon: state.isSaving ? Icons.sync_outlined : Icons.point_of_sale,
      ),
      secondaryActions: <Widget>[
        AppButton.secondary(
          label: _BillingText.closeShift,
          leadingIcon: Icons.schedule_send_outlined,
          enabled: canWrite && !state.isSaving,
          onPressed: () => _showShiftCloseDialog(context, ref),
        ),
        AppButton.secondary(
          label: _BillingText.closeDay,
          leadingIcon: Icons.today_outlined,
          enabled: canWrite && !state.isSaving,
          onPressed: () => _showDayCloseDialog(context, ref),
        ),
        AppButton.secondary(
          label: context.l10n.commonRefreshActionLabel,
          leadingIcon: Icons.refresh,
          isLoading: state.isRefreshing,
          onPressed: state.isRefreshing ? null : controller.refresh,
        ),
      ],
      summaryCards: _summaryCards(context, ref, state),
      compactSummaryCards: true,
      filters: _BillingFilterBar(
        state: state,
        columnVisibilityController: _tableColumnController,
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
          _BillingQueuePanel(
            state: state,
            canWrite: canWrite,
            columnVisibilityController: _tableColumnController,
          ),
        ],
      ),
    );
  }

  List<Widget> _summaryCards(
    BuildContext context,
    WidgetRef ref,
    BillingWorkspaceState state,
  ) {
    final BillingSummary summary = state.overview.summary;
    final Locale locale = Localizations.localeOf(context);
    final controller = ref.read(billingWorkspaceControllerProvider.notifier);

    return <Widget>[
      AppWorkspaceSummaryCard(
        label: _BillingText.awaitingPayment,
        value: summary.pendingPayment.toString(),
        icon: Icons.payments_outlined,
        tone: AppWorkspaceStatusTone.warning,
        compact: true,
        onPressed: () => controller.applyQueue(BillingQueueType.pendingPayment),
      ),
      AppWorkspaceSummaryCard(
        label: _BillingText.partiallyPaid,
        value: state.partialPaidVisibleCount.toString(),
        icon: Icons.pie_chart_outline,
        tone: AppWorkspaceStatusTone.info,
        compact: true,
      ),
      AppWorkspaceSummaryCard(
        label: _BillingText.clearedVisible,
        value: state.clearedVisibleCount.toString(),
        icon: Icons.verified_outlined,
        tone: AppWorkspaceStatusTone.success,
        compact: true,
      ),
      AppWorkspaceSummaryCard(
        label: _BillingText.refundsToday,
        value: AppFormatters.currency(
          summary.refundsTodayTotal,
          locale,
          currencyCode: appDefaultCurrencyCode,
          decimalDigits: 0,
        ),
        icon: Icons.assignment_return_outlined,
        compact: true,
      ),
      AppWorkspaceSummaryCard(
        label: _BillingText.issueQueue,
        value: summary.needsIssue.toString(),
        icon: Icons.receipt_long_outlined,
        compact: true,
        onPressed: () => controller.applyQueue(BillingQueueType.needsIssue),
      ),
      AppWorkspaceSummaryCard(
        label: _BillingText.approvals,
        value: summary.approvalRequired.toString(),
        icon: Icons.rule_outlined,
        compact: true,
        onPressed: () =>
            controller.applyQueue(BillingQueueType.approvalRequired),
      ),
      AppWorkspaceSummaryCard(
        label: _BillingText.overdue,
        value: summary.overdue.toString(),
        icon: Icons.warning_amber_outlined,
        tone: AppWorkspaceStatusTone.error,
        compact: true,
        onPressed: () => controller.applyQueue(BillingQueueType.overdue),
      ),
      AppWorkspaceSummaryCard(
        label: _BillingText.paymentsToday,
        value: AppFormatters.currency(
          summary.paymentsTodayTotal,
          locale,
          currencyCode: appDefaultCurrencyCode,
          decimalDigits: 0,
        ),
        icon: Icons.point_of_sale,
        tone: AppWorkspaceStatusTone.success,
        compact: true,
      ),
    ];
  }
}

class _BillingFilterBar extends ConsumerStatefulWidget {
  const _BillingFilterBar({
    required this.state,
    required this.columnVisibilityController,
  });

  final BillingWorkspaceState state;
  final AppListTableColumnVisibilityController<BillingWorkItem>
  columnVisibilityController;

  @override
  ConsumerState<_BillingFilterBar> createState() => _BillingFilterBarState();
}

class _BillingFilterBarState extends ConsumerState<_BillingFilterBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
  }

  @override
  void didUpdateWidget(covariant _BillingFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_searchController.text != widget.state.query.search) {
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
    final controller = ref.read(billingWorkspaceControllerProvider.notifier);

    return AppWorkspaceFilterBar(
      semanticLabel: 'Billing filters',
      expandSearch: true,
      search: AppSearchBar(
        controller: _searchController,
        semanticLabel: 'Search billing worklist',
        hintText: _BillingText.searchHint,
        clearLabel: 'Clear billing search',
        onSubmitted: controller.applySearch,
        onClear: () => controller.applySearch(''),
        trailingActions: <AppSearchBarAction>[
          widget.columnVisibilityController.settingsAction(
            context,
            label: 'Table settings',
          ),
        ],
      ),
      filters: <Widget>[
        AppSelectField<BillingQueueType>(
          value: widget.state.query.queue,
          labelText: 'Queue',
          options: <AppSelectOption<BillingQueueType>>[
            for (final BillingQueueType queue in BillingQueueType.values)
              AppSelectOption<BillingQueueType>(
                value: queue,
                label: _queueLabel(queue),
              ),
          ],
          onChanged: (BillingQueueType? value) {
            if (value != null) {
              controller.applyQueue(value);
            }
          },
        ),
      ],
      actions: <Widget>[
        AppButton.tertiary(
          label: _BillingText.clear,
          leadingIcon: Icons.clear,
          onPressed: () => controller.applySearch(''),
        ),
      ],
    );
  }
}

class _BillingQueuePanel extends ConsumerWidget {
  const _BillingQueuePanel({
    required this.state,
    required this.canWrite,
    required this.columnVisibilityController,
  });

  final BillingWorkspaceState state;
  final bool canWrite;
  final AppListTableColumnVisibilityController<BillingWorkItem>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(billingWorkspaceControllerProvider.notifier);

    return AppWorkspaceDetailPanel(
      title: _queueLabel(state.query.queue),
      description: 'Simple cashier worklist backed by billing APIs.',
      child: AppListTable<BillingWorkItem>(
        page: state.workItems,
        isLoading: state.isRefreshing,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        columnVisibilityController: columnVisibilityController,
        itemKeyBuilder: (BillingWorkItem item) => ValueKey<String>(item.id),
        onRowSelected: (BillingWorkItem item) {
          controller.selectItem(item);
          _showBillingDetailDialog(
            context,
            item,
            canWrite: canWrite,
            isSaving: state.isSaving,
          );
        },
        previousPageLabel: 'Previous page',
        nextPageLabel: 'Next page',
        pageLabelBuilder: (AppPage<BillingWorkItem> page) {
          final int total = page.totalItemCount ?? page.lastItemNumber;
          return '${page.firstItemNumber}-${page.lastItemNumber} of $total';
        },
        onPageChanged: controller.changePage,
        emptyBuilder: (BuildContext context) {
          return const AppStateView(
            title: 'No billing items',
            body: 'This queue has no invoices or billing actions right now.',
            variant: AppStateViewVariant.empty,
          );
        },
        columns: <AppListTableColumn<BillingWorkItem>>[
          AppListTableColumn<BillingWorkItem>(
            label: _BillingText.patient,
            cellBuilder: (BuildContext context, BillingWorkItem item) {
              return _TwoLineCell(
                title: item.effectivePatientName,
                subtitle: _joinDisplay(<String?>[
                  item.effectivePatientNumber,
                  item.effectiveDisplayId,
                ]),
              );
            },
          ),
          AppListTableColumn<BillingWorkItem>(
            label: _BillingText.status,
            cellBuilder: (BuildContext context, BillingWorkItem item) {
              return BillingGateBadge(state: item.clearanceState);
            },
          ),
          AppListTableColumn<BillingWorkItem>(
            label: _BillingText.amount,
            numeric: true,
            cellBuilder: (BuildContext context, BillingWorkItem item) {
              return Text(_money(context, item.effectiveTotal, item.currency));
            },
          ),
          AppListTableColumn<BillingWorkItem>(
            label: _BillingText.paid,
            numeric: true,
            cellBuilder: (BuildContext context, BillingWorkItem item) {
              return Text(_money(context, item.paidAmount, item.currency));
            },
          ),
          AppListTableColumn<BillingWorkItem>(
            label: _BillingText.balance,
            numeric: true,
            cellBuilder: (BuildContext context, BillingWorkItem item) {
              return Text(_money(context, item.balanceDue, item.currency));
            },
          ),
          AppListTableColumn<BillingWorkItem>(
            label: _BillingText.updated,
            cellBuilder: (BuildContext context, BillingWorkItem item) {
              return Text(_dateTime(context, item.timelineAt));
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, BillingWorkItem item) {
          return _BillingMobileTile(item: item);
        },
      ),
    );
  }
}

Future<void> _showBillingDetailDialog(
  BuildContext context,
  BillingWorkItem item, {
  required bool canWrite,
  required bool isSaving,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(item.isInvoice ? 'Invoice detail' : 'Billing item'),
      icon: const Icon(Icons.receipt_long_outlined),
      scrollable: true,
      maxWidth: 940,
      content: _BillingDetailBody(
        item: item,
        canWrite: canWrite,
        isSaving: isSaving,
      ),
      actions: <Widget>[
        AppReportActionButton.download(
          label: _BillingText.invoice,
          enabled: item.isInvoice,
          tooltip: item.isInvoice
              ? 'Generated invoice document is available from the backend.'
              : 'Document output is only available for invoices.',
          onPressed: item.isInvoice
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Generated document endpoint confirmed; browser download is pending platform wiring.',
                      ),
                    ),
                  );
                }
              : null,
        ),
      ],
    ),
  );
}

class _BillingDetailBody extends ConsumerWidget {
  const _BillingDetailBody({
    required this.item,
    required this.canWrite,
    required this.isSaving,
  });

  final BillingWorkItem item;
  final bool canWrite;
  final bool isSaving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppWorkspacePatientContextHeader(
          patientName: item.effectivePatientName,
          patientNumber: item.effectivePatientNumber ?? item.effectiveDisplayId,
          status: AppWorkspaceStatus(
            label: _clearanceLabel(item.clearanceState),
            tone: _clearanceTone(item.clearanceState),
          ),
          fields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: _BillingText.invoice,
              value: item.effectiveDisplayId,
              icon: Icons.receipt_long_outlined,
            ),
            AppWorkspacePatientContextField(
              label: _BillingText.status,
              value: _apiLabel(item.billingStatus ?? item.status),
              icon: Icons.flag_outlined,
            ),
            AppWorkspacePatientContextField(
              label: _BillingText.paid,
              value: _money(context, item.paidAmount, item.currency),
              icon: Icons.payments_outlined,
              tone: AppWorkspaceStatusTone.success,
            ),
            AppWorkspacePatientContextField(
              label: _BillingText.balance,
              value: _money(context, item.balanceDue, item.currency),
              icon: Icons.account_balance_wallet_outlined,
              tone: item.balanceDue <= 0
                  ? AppWorkspaceStatusTone.success
                  : AppWorkspaceStatusTone.warning,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        if (canWrite && item.isInvoice)
          _BillingActionBar(item: item, isSaving: isSaving),
        if (canWrite && item.isInvoice) SizedBox(height: theme.spacing.md),
        _DepositPanel(),
        SizedBox(height: theme.spacing.md),
        _InvoiceLineItemsSection(item: item),
        SizedBox(height: theme.spacing.md),
        _PaymentsSection(item: item),
        SizedBox(height: theme.spacing.md),
        _AdjustmentsSection(item: item),
      ],
    );
  }
}

class _BillingActionBar extends ConsumerWidget {
  const _BillingActionBar({required this.item, required this.isSaving});

  final BillingWorkItem item;
  final bool isSaving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppActionList(
      actions: <AppActionItem>[
        AppActionItem(
          label: _BillingText.receivePayment,
          leadingIcon: Icons.point_of_sale,
          enabled: item.canReceivePayment && !isSaving,
          variant: AppActionVariant.primary,
          onPressed: () => _showPaymentDialog(context, ref, item),
        ),
        AppActionItem(
          label: _BillingText.issue,
          leadingIcon: Icons.outbox_outlined,
          enabled: item.canIssue && !isSaving,
          onPressed: () => _showIssueDialog(context, ref),
        ),
        AppActionItem(
          label: _BillingText.refund,
          leadingIcon: Icons.assignment_return_outlined,
          enabled: item.canRequestRefund && !isSaving,
          onPressed: () => _showRefundDialog(context, ref, item),
        ),
        AppActionItem(
          label: _BillingText.adjust,
          leadingIcon: Icons.tune,
          enabled: item.canRequestAdjustment && !isSaving,
          onPressed: () => _showAdjustmentDialog(context, ref, item),
        ),
        AppActionItem(
          label: _BillingText.voidAction,
          leadingIcon: Icons.block_outlined,
          enabled: item.canRequestVoid && !isSaving,
          onPressed: () => _showVoidDialog(context, ref),
        ),
        AppActionItem(
          label: _BillingText.send,
          leadingIcon: Icons.send_outlined,
          enabled: !isSaving,
          onPressed: () => _showSendDialog(context, ref),
        ),
      ],
    );
  }
}

class _DepositPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppReportPreviewPanel(
      title: 'Deposits',
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_outline),
          SizedBox(width: Theme.of(context).spacing.sm),
          const Expanded(
            child: Text(
              'Admission deposits are not exposed by the current backend route set, so the cashier UI does not create local deposit records.',
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceLineItemsSection extends StatelessWidget {
  const _InvoiceLineItemsSection({required this.item});

  final BillingWorkItem item;

  @override
  Widget build(BuildContext context) {
    if (item.items.isEmpty) {
      return const _DetailSection(
        title: 'Line items',
        child: Text(_BillingText.noLineItems),
      );
    }

    return _DetailSection(
      title: 'Line items',
      child: Column(
        children: <Widget>[
          for (final BillingInvoiceItem lineItem in item.items)
            _DetailRow(
              title: lineItem.description,
              subtitle: 'Qty ${lineItem.quantity}',
              trailing: _money(context, lineItem.totalPrice, item.currency),
            ),
        ],
      ),
    );
  }
}

class _PaymentsSection extends StatelessWidget {
  const _PaymentsSection({required this.item});

  final BillingWorkItem item;

  @override
  Widget build(BuildContext context) {
    if (item.payments.isEmpty) {
      return const _DetailSection(
        title: 'Payments',
        child: Text(_BillingText.noPayments),
      );
    }

    return _DetailSection(
      title: 'Payments',
      child: Column(
        children: <Widget>[
          for (final BillingPayment payment in item.payments)
            _DetailRow(
              title: _joinDisplay(<String?>[
                payment.effectiveDisplayId,
                _apiLabel(payment.method),
              ]),
              subtitle: _joinDisplay(<String?>[
                _apiLabel(payment.status),
                payment.transactionRef,
                _dateTime(context, payment.paidAt),
              ]),
              trailing: _money(context, payment.amount, item.currency),
            ),
        ],
      ),
    );
  }
}

class _AdjustmentsSection extends StatelessWidget {
  const _AdjustmentsSection({required this.item});

  final BillingWorkItem item;

  @override
  Widget build(BuildContext context) {
    if (item.adjustments.isEmpty) {
      return const _DetailSection(
        title: 'Adjustments',
        child: Text(_BillingText.noAdjustments),
      );
    }

    return _DetailSection(
      title: 'Adjustments',
      child: Column(
        children: <Widget>[
          for (final BillingAdjustment adjustment in item.adjustments)
            _DetailRow(
              title: adjustment.displayId ?? adjustment.id,
              subtitle: _joinDisplay(<String?>[
                _apiLabel(adjustment.status),
                adjustment.reason,
              ]),
              trailing: _money(context, adjustment.amount, item.currency),
            ),
        ],
      ),
    );
  }
}

class BillingGateBadge extends StatelessWidget {
  const BillingGateBadge({required this.state, super.key});

  final BillingClearanceState state;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(
        label: _clearanceLabel(state),
        tone: _clearanceTone(state),
        icon: _clearanceIcon(state),
      ),
    );
  }
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
                  item.effectivePatientName,
                  style: theme.textTheme.titleSmall,
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  _joinDisplay(<String?>[
                    item.effectiveDisplayId,
                    _money(context, item.balanceDue, item.currency),
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

class _TwoLineCell extends StatelessWidget {
  const _TwoLineCell({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (subtitle.trim().isNotEmpty)
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

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: theme.textTheme.titleSmall),
        SizedBox(height: theme.spacing.sm),
        child,
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;

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
                Text(title, style: theme.textTheme.bodyMedium),
                if (subtitle.trim().isNotEmpty)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Text(trailing, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _PaymentForm extends StatefulWidget {
  const _PaymentForm({required this.item});

  final BillingWorkItem item;

  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _payerController = TextEditingController();
  String _method = 'CASH';
  bool _issueReceipt = true;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.item.balanceDue.clamp(0, double.infinity).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _payerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppReportSummaryGrid(
          records: <AppReportSummaryItem>[
            AppReportSummaryItem(
              label: _BillingText.invoice,
              value: widget.item.effectiveDisplayId,
              icon: Icons.receipt_long_outlined,
            ),
            AppReportSummaryItem(
              label: _BillingText.due,
              value: _money(
                context,
                widget.item.balanceDue,
                widget.item.currency,
              ),
              icon: Icons.account_balance_wallet_outlined,
            ),
          ],
        ),
        AppCurrencyAmountField(
          amountController: _amountController,
          currency: widget.item.currency ?? appDefaultCurrencyCode,
          onCurrencyChanged: (_) {},
          amountLabelText: 'Amount received',
          currencyLabelText: 'Currency',
          isRequired: true,
          allowZero: false,
          maxAmount: widget.item.balanceDue,
        ),
        AppSelectField<String>(
          value: _method,
          labelText: 'Payment method',
          options: <AppSelectOption<String>>[
            for (final String method in billingPaymentMethods)
              AppSelectOption<String>(value: method, label: _apiLabel(method)),
          ],
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _method = value);
            }
          },
        ),
        AppTextField(
          controller: _referenceController,
          labelText: 'Reference',
          hintText: _BillingText.paymentReferenceHint,
        ),
        AppTextField(
          controller: _payerController,
          labelText: 'Payer',
          hintText: _BillingText.payerHint,
        ),
        AppCheckboxField(
          title: 'Generate receipt after payment',
          value: _issueReceipt,
          onChanged: (bool value) => setState(() => _issueReceipt = value),
        ),
        AppFormActions(
          cancelLabel: context.l10n.commonCancelActionLabel,
          submitLabel: 'Receive payment',
          submitIcon: Icons.point_of_sale,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(
              BillingPaymentDraft(
                amount: _amountController.text,
                method: _method,
                reference: _emptyToNull(_referenceController.text),
                payer: _emptyToNull(_payerController.text),
                issueReceipt: _issueReceipt,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RefundForm extends StatefulWidget {
  const _RefundForm({required this.item});

  final BillingWorkItem item;

  @override
  State<_RefundForm> createState() => _RefundFormState();
}

class _RefundFormState extends State<_RefundForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  late String _paymentId;

  @override
  void initState() {
    super.initState();
    final BillingPayment payment = widget.item.firstRefundablePayment!;
    _paymentId = payment.id;
    _amountController = TextEditingController(
      text: payment.amount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<String>(
          value: _paymentId,
          labelText: 'Payment',
          options: <AppSelectOption<String>>[
            for (final BillingPayment payment in widget.item.payments)
              if (payment.isRefundable)
                AppSelectOption<String>(
                  value: payment.id,
                  label: _joinDisplay(<String?>[
                    payment.effectiveDisplayId,
                    _money(context, payment.amount, widget.item.currency),
                  ]),
                ),
          ],
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _paymentId = value);
            }
          },
        ),
        AppCurrencyAmountField(
          amountController: _amountController,
          currency: widget.item.currency ?? appDefaultCurrencyCode,
          onCurrencyChanged: (_) {},
          amountLabelText: 'Refund amount',
          currencyLabelText: 'Currency',
          isRequired: true,
          allowZero: false,
        ),
        AppTextField(
          controller: _reasonController,
          labelText: 'Reason',
          isRequired: true,
          validator: AppValidators.requiredText('Enter a refund reason.'),
        ),
        AppTextField(
          controller: _notesController,
          labelText: 'Notes',
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: context.l10n.commonCancelActionLabel,
          submitLabel: 'Request refund',
          submitIcon: Icons.assignment_return_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(
              BillingRefundDraft(
                paymentId: _paymentId,
                amount: _amountController.text,
                reason: _reasonController.text.trim(),
                notes: _emptyToNull(_notesController.text),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AdjustmentForm extends StatefulWidget {
  const _AdjustmentForm({required this.item});

  final BillingWorkItem item;

  @override
  State<_AdjustmentForm> createState() => _AdjustmentFormState();
}

class _AdjustmentFormState extends State<_AdjustmentForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _status = 'ISSUED';

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _amountController,
          labelText: 'Adjustment amount (+/-)',
          isRequired: true,
          validator: (String? value) {
            final String normalized = value?.replaceAll(',', '').trim() ?? '';
            if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(normalized)) {
              return 'Enter a signed amount, for example -10.00 or 25.00.';
            }
            return null;
          },
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        AppSelectField<String>(
          value: _status,
          labelText: 'Applied status',
          options: const <AppSelectOption<String>>[
            AppSelectOption<String>(
              value: 'ISSUED',
              label: _BillingText.issued,
            ),
            AppSelectOption<String>(
              value: 'PARTIAL',
              label: _BillingText.partial,
            ),
            AppSelectOption<String>(value: 'PAID', label: _BillingText.paid),
            AppSelectOption<String>(value: 'DRAFT', label: _BillingText.draft),
          ],
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _status = value);
            }
          },
        ),
        AppTextField(
          controller: _reasonController,
          labelText: 'Reason',
          isRequired: true,
          validator: AppValidators.requiredText('Enter an adjustment reason.'),
        ),
        AppTextField(
          controller: _notesController,
          labelText: 'Notes',
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: context.l10n.commonCancelActionLabel,
          submitLabel: 'Request adjustment',
          submitIcon: Icons.tune,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(
              BillingAdjustmentDraft(
                amount: _amountController.text,
                reason: _reasonController.text.trim(),
                status: _status,
                notes: _emptyToNull(_notesController.text),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ReasonForm extends StatefulWidget {
  const _ReasonForm({required this.submitLabel, required this.reasonLabel});

  final String submitLabel;
  final String reasonLabel;

  @override
  State<_ReasonForm> createState() => _ReasonFormState();
}

class _ReasonFormState extends State<_ReasonForm> {
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
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _reasonController,
          labelText: widget.reasonLabel,
          isRequired: true,
          validator: AppValidators.requiredText('Enter a reason.'),
        ),
        AppTextField(
          controller: _notesController,
          labelText: 'Notes',
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: context.l10n.commonCancelActionLabel,
          submitLabel: widget.submitLabel,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, String?>{
              'reason': _reasonController.text.trim(),
              'notes': _emptyToNull(_notesController.text),
            });
          },
        ),
      ],
    );
  }
}

class _NotesForm extends StatefulWidget {
  const _NotesForm({required this.submitLabel, this.email = false});

  final String submitLabel;
  final bool email;

  @override
  State<_NotesForm> createState() => _NotesFormState();
}

class _NotesFormState extends State<_NotesForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _controller,
          labelText: widget.email ? 'Recipient email' : 'Notes',
          keyboardType: widget.email ? TextInputType.emailAddress : null,
          maxLines: widget.email ? 1 : 3,
        ),
        AppFormActions(
          cancelLabel: context.l10n.commonCancelActionLabel,
          submitLabel: widget.submitLabel,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(_emptyToNull(_controller.text));
          },
        ),
      ],
    );
  }
}

class _CloseForm extends StatefulWidget {
  const _CloseForm({required this.title, required this.shiftClose});

  final String title;
  final bool shiftClose;

  @override
  State<_CloseForm> createState() => _CloseFormState();
}

class _CloseFormState extends State<_CloseForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _expectedController = TextEditingController();
  final TextEditingController _actualController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _submit = true;

  @override
  void dispose() {
    _expectedController.dispose();
    _actualController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        if (widget.shiftClose) ...<Widget>[
          AppCurrencyAmountField(
            amountController: _expectedController,
            currency: appDefaultCurrencyCode,
            onCurrencyChanged: (_) {},
            amountLabelText: 'Expected amount',
            currencyLabelText: 'Currency',
          ),
          AppCurrencyAmountField(
            amountController: _actualController,
            currency: appDefaultCurrencyCode,
            onCurrencyChanged: (_) {},
            amountLabelText: 'Actual amount',
            currencyLabelText: 'Currency',
          ),
        ],
        AppTextField(
          controller: _notesController,
          labelText: 'Notes',
          maxLines: 3,
        ),
        AppCheckboxField(
          title: 'Submit for approval',
          value: _submit,
          onChanged: (bool value) => setState(() => _submit = value),
        ),
        AppFormActions(
          cancelLabel: context.l10n.commonCancelActionLabel,
          submitLabel: widget.title,
          submitIcon: Icons.task_alt_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(
              BillingCloseDraft(
                expectedAmount: _emptyToNull(_expectedController.text),
                actualAmount: _emptyToNull(_actualController.text),
                notes: _emptyToNull(_notesController.text),
                submit: _submit,
              ),
            );
          },
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
  final BillingPaymentDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: const Text(_BillingText.receivePayment),
    icon: const Icon(Icons.point_of_sale),
    content: _PaymentForm(item: item),
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
  _showMutationResult(context, failure);
}

Future<void> _showRefundDialog(
  BuildContext context,
  WidgetRef ref,
  BillingWorkItem item,
) async {
  final BillingRefundDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: const Text(_BillingText.requestRefund),
    icon: const Icon(Icons.assignment_return_outlined),
    content: _RefundForm(item: item),
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
  _showMutationResult(context, failure);
}

Future<void> _showAdjustmentDialog(
  BuildContext context,
  WidgetRef ref,
  BillingWorkItem item,
) async {
  final BillingAdjustmentDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: const Text(_BillingText.requestAdjustment),
    icon: const Icon(Icons.tune),
    content: _AdjustmentForm(item: item),
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
  _showMutationResult(context, failure);
}

Future<void> _showVoidDialog(BuildContext context, WidgetRef ref) async {
  final Map<String, String?>? payload = await showAppWorkspaceActionDialog(
    context: context,
    title: const Text(_BillingText.voidInvoice),
    icon: const Icon(Icons.block_outlined),
    content: const _ReasonForm(
      submitLabel: 'Request void',
      reasonLabel: 'Void reason',
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
  _showMutationResult(context, failure);
}

Future<void> _showIssueDialog(BuildContext context, WidgetRef ref) async {
  final String? notes = await showAppWorkspaceActionDialog(
    context: context,
    title: const Text(_BillingText.issueInvoice),
    icon: const Icon(Icons.outbox_outlined),
    content: const _NotesForm(submitLabel: 'Issue'),
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
  _showMutationResult(context, failure);
}

Future<void> _showSendDialog(BuildContext context, WidgetRef ref) async {
  final String? recipientEmail = await showAppWorkspaceActionDialog(
    context: context,
    title: const Text(_BillingText.sendInvoice),
    icon: const Icon(Icons.send_outlined),
    content: const _NotesForm(submitLabel: 'Send', email: true),
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
  _showMutationResult(context, failure);
}

Future<void> _showShiftCloseDialog(BuildContext context, WidgetRef ref) async {
  final BillingCloseDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: const Text(_BillingText.closeShift),
    icon: const Icon(Icons.schedule_send_outlined),
    content: const _CloseForm(title: 'Close shift', shiftClose: true),
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
  _showMutationResult(context, failure);
}

Future<void> _showDayCloseDialog(BuildContext context, WidgetRef ref) async {
  final BillingCloseDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: const Text(_BillingText.closeDay),
    icon: const Icon(Icons.today_outlined),
    content: const _CloseForm(title: 'Close day', shiftClose: false),
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
  _showMutationResult(context, failure);
}

void _showMutationResult(BuildContext context, AppFailure? failure) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null
            ? 'Billing action saved.'
            : context.l10n.failureMessage(failure),
      ),
    ),
  );
}

String _queueLabel(BillingQueueType queue) {
  return switch (queue) {
    BillingQueueType.needsIssue => 'Needs issue',
    BillingQueueType.pendingPayment => 'Awaiting payment',
    BillingQueueType.claimsPending => 'Claims pending',
    BillingQueueType.approvalRequired => 'Approval required',
    BillingQueueType.overdue => 'Overdue',
  };
}

abstract final class _BillingText {
  static const String adjust = 'Adjust';
  static const String amount = 'Amount';
  static const String approvals = 'Approvals';
  static const String awaitingPayment = 'Awaiting payment';
  static const String balance = 'Balance';
  static const String clear = 'Clear';
  static const String clearedVisible = 'Cleared visible';
  static const String closeDay = 'Close day';
  static const String closeShift = 'Close shift';
  static const String draft = 'Draft';
  static const String due = 'Due';
  static const String invoice = 'Invoice';
  static const String issue = 'Issue';
  static const String issued = 'Issued';
  static const String issueInvoice = 'Issue invoice';
  static const String issueQueue = 'Issue queue';
  static const String noAdjustments = 'No billing adjustments recorded.';
  static const String noLineItems = 'No line items returned for this invoice.';
  static const String noPayments = 'No payments recorded for this invoice.';
  static const String overdue = 'Overdue';
  static const String paid = 'Paid';
  static const String partiallyPaid = 'Partially paid';
  static const String partial = 'Partial';
  static const String patient = 'Patient';
  static const String payerHint = 'Patient, sponsor, insurer, or contact';
  static const String paymentReferenceHint =
      'Mobile money, card, or bank reference';
  static const String paymentsToday = 'Payments today';
  static const String receivePayment = 'Receive payment';
  static const String refund = 'Refund';
  static const String refundsToday = 'Refunds today';
  static const String requestAdjustment = 'Request adjustment';
  static const String requestRefund = 'Request refund';
  static const String searchHint = 'Invoice, patient, or reference';
  static const String send = 'Send';
  static const String sendInvoice = 'Send invoice';
  static const String status = 'Status';
  static const String updated = 'Updated';
  static const String voidAction = 'Void';
  static const String voidInvoice = 'Void invoice';
}

String _clearanceLabel(BillingClearanceState state) {
  return switch (state) {
    BillingClearanceState.cleared => 'Cleared',
    BillingClearanceState.partiallyPaid => 'Partially paid',
    BillingClearanceState.deferred => 'Deferred',
    BillingClearanceState.insured => 'Insured',
    BillingClearanceState.pendingAuthorization => 'Pending authorization',
    BillingClearanceState.blocked => 'Blocked',
  };
}

AppWorkspaceStatusTone _clearanceTone(BillingClearanceState state) {
  return switch (state) {
    BillingClearanceState.cleared => AppWorkspaceStatusTone.success,
    BillingClearanceState.partiallyPaid => AppWorkspaceStatusTone.info,
    BillingClearanceState.deferred => AppWorkspaceStatusTone.neutral,
    BillingClearanceState.insured => AppWorkspaceStatusTone.info,
    BillingClearanceState.pendingAuthorization =>
      AppWorkspaceStatusTone.warning,
    BillingClearanceState.blocked => AppWorkspaceStatusTone.error,
  };
}

IconData _clearanceIcon(BillingClearanceState state) {
  return switch (state) {
    BillingClearanceState.cleared => Icons.verified_outlined,
    BillingClearanceState.partiallyPaid => Icons.pie_chart_outline,
    BillingClearanceState.deferred => Icons.schedule_outlined,
    BillingClearanceState.insured => Icons.health_and_safety_outlined,
    BillingClearanceState.pendingAuthorization => Icons.rule_outlined,
    BillingClearanceState.blocked => Icons.lock_outline,
  };
}

String _money(BuildContext context, num value, String? currencyCode) {
  return AppFormatters.currency(
    value,
    Localizations.localeOf(context),
    currencyCode: currencyCode ?? appDefaultCurrencyCode,
    decimalDigits: value % 1 == 0 ? 0 : 2,
  );
}

String _dateTime(BuildContext context, DateTime? value) {
  return value == null
      ? 'Not recorded'
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String _apiLabel(String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return 'Unknown';
  }
  return normalized
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return lower.substring(0, 1).toUpperCase() + lower.substring(1);
      })
      .join(' ');
}

String _joinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

String? _emptyToNull(String value) {
  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
