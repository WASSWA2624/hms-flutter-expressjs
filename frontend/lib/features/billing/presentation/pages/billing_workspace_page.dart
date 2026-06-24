import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
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
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_detail_widgets.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_ledger_dialog.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
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
      appBarTitle: context.l10n.billingWorkspaceTitle,
      loadingTitle: context.l10n.billingLoadingTitle,
      loadingBody: context.l10n.billingLoadingBody,
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
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<BillingWorkItem>
  _tableColumnController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<BillingWorkItem>();
    _searchController.addListener(_onSearchChanged);
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
  void didUpdateWidget(covariant _BillingWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
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

    final AppLocalizations l10n = context.l10n;

    return AppWorkspace(
      title: l10n.billingWorkspaceTitle,
      leadingIcon: AppRouteIcons.billing,
      status: AppWorkspaceStatus(
        label: state.isSaving
            ? l10n.billingStatusPosting
            : l10n.billingStatusLive,
        tone: state.isSaving
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
        icon: state.isSaving ? Icons.sync_outlined : Icons.point_of_sale,
      ),
      secondaryActions: <Widget>[
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
        AppButton.secondary(
          label: l10n.commonRefreshActionLabel,
          leadingIcon: Icons.refresh,
          isLoading: state.isRefreshing,
          onPressed: state.isRefreshing ? null : controller.refresh,
        ),
      ],
      summaryCards: _summaryCards(context, ref, state),
      compactSummaryCards: true,
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
            searchController: _searchController,
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
    final AppLocalizations l10n = context.l10n;
    final BillingSummary summary = state.overview.summary;
    final Locale locale = Localizations.localeOf(context);
    final controller = ref.read(billingWorkspaceControllerProvider.notifier);

    return <Widget>[
      if (summary.workloadCount > 0)
        AppWorkspaceSummaryCard(
          label: l10n.billingAllWorkItems,
          value: AppFormatters.compactNumber(summary.workloadCount, locale),
          icon: Icons.inventory_2_outlined,
          compact: true,
          onPressed: () => controller.applyQueue(BillingQueueType.all),
        ),
      if (summary.pendingPayment > 0)
        AppWorkspaceSummaryCard(
          label: l10n.billingAwaitingPayment,
          value: AppFormatters.compactNumber(summary.pendingPayment, locale),
          icon: Icons.payments_outlined,
          tone: AppWorkspaceStatusTone.warning,
          compact: true,
          onPressed: () =>
              controller.applyQueue(BillingQueueType.pendingPayment),
        ),
      if (summary.needsIssue > 0)
        AppWorkspaceSummaryCard(
          label: l10n.billingIssueQueue,
          value: AppFormatters.compactNumber(summary.needsIssue, locale),
          icon: Icons.receipt_long_outlined,
          compact: true,
          onPressed: () => controller.applyQueue(BillingQueueType.needsIssue),
        ),
      if (summary.claimsPending > 0)
        AppWorkspaceSummaryCard(
          label: l10n.billingClaimsPending,
          value: AppFormatters.compactNumber(summary.claimsPending, locale),
          icon: Icons.health_and_safety_outlined,
          tone: AppWorkspaceStatusTone.info,
          compact: true,
          onPressed: () =>
              controller.applyQueue(BillingQueueType.claimsPending),
        ),
      if (summary.approvalRequired > 0)
        AppWorkspaceSummaryCard(
          label: l10n.billingApprovals,
          value: AppFormatters.compactNumber(summary.approvalRequired, locale),
          icon: Icons.rule_outlined,
          compact: true,
          onPressed: () =>
              controller.applyQueue(BillingQueueType.approvalRequired),
        ),
      if (summary.overdue > 0)
        AppWorkspaceSummaryCard(
          label: l10n.billingOverdue,
          value: AppFormatters.compactNumber(summary.overdue, locale),
          icon: Icons.warning_amber_outlined,
          tone: AppWorkspaceStatusTone.error,
          compact: true,
          onPressed: () => controller.applyQueue(BillingQueueType.overdue),
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
  });

  final BillingWorkspaceState state;
  final bool canWrite;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<BillingWorkItem>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final controller = ref.read(billingWorkspaceControllerProvider.notifier);

    return AppWorkspaceDetailPanel(
      title: billingQueueLabel(context, state.query.queue),
      description: l10n.billingWorklistDescription,
      child: AppListTable<BillingWorkItem>(
        page: state.workItems,
        isLoading: state.isRefreshing,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        columnVisibilityController: columnVisibilityController,
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
          advancedFilterCancelLabel: l10n.commonCancelActionLabel,
          enableDateFilter: false,
          allFieldsLabel: billingQueueLabel(context, BillingQueueType.all),
          filterGroups: <AppSearchBarFilterGroup>[
            AppSearchBarFilterGroup(
              key: _billingQueueFilterKey,
              label: l10n.billingQueueLabel,
              allLabel: billingQueueLabel(context, BillingQueueType.all),
              choices: _billingQueueFilterChoices(context),
            ),
          ],
          filterValue: _billingFilterValue(state.query),
          hasActiveFilters: state.query.queue != BillingQueueType.all,
          onFilterChanged: (AppSearchBarFilterValue value) {
            controller.applyQueue(
              _billingQueueFromFilter(value.option(_billingQueueFilterKey)),
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
        columns: <AppListTableColumn<BillingWorkItem>>[
          AppListTableColumn<BillingWorkItem>(
            label: l10n.billingPatientColumn,
            sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
                appListTableCompareText(
                  left.effectivePatientName,
                  right.effectivePatientName,
                ),
            cellBuilder: (BuildContext context, BillingWorkItem item) {
              return _TwoLineCell(
                title: billingPatientName(context, item),
                subtitle: billingJoinDisplay(<String?>[
                  item.effectivePatientNumber,
                  item.effectiveDisplayId,
                ]),
              );
            },
          ),
          AppListTableColumn<BillingWorkItem>(
            label: l10n.billingStatusColumn,
            sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
                appListTableCompareText(
                  left.clearanceState.name,
                  right.clearanceState.name,
                ),
            cellBuilder: (BuildContext context, BillingWorkItem item) {
              return BillingGateBadge(state: item.clearanceState);
            },
          ),
          AppListTableColumn<BillingWorkItem>(
            label: l10n.billingAmountColumn,
            numeric: true,
            sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
                appListTableCompareNumber(
                  left.effectiveTotal,
                  right.effectiveTotal,
                ),
            cellBuilder: (BuildContext context, BillingWorkItem item) {
              return Text(
                billingMoney(context, item.effectiveTotal, item.currency),
              );
            },
          ),
          AppListTableColumn<BillingWorkItem>(
            label: l10n.billingPaidColumn,
            numeric: true,
            sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
                appListTableCompareNumber(left.paidAmount, right.paidAmount),
            cellBuilder: (BuildContext context, BillingWorkItem item) {
              return Text(
                billingMoney(context, item.paidAmount, item.currency),
              );
            },
          ),
          AppListTableColumn<BillingWorkItem>(
            label: l10n.billingBalanceColumn,
            numeric: true,
            sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
                appListTableCompareNumber(left.balanceDue, right.balanceDue),
            cellBuilder: (BuildContext context, BillingWorkItem item) {
              return Text(
                billingMoney(context, item.balanceDue, item.currency),
              );
            },
          ),
          AppListTableColumn<BillingWorkItem>(
            label: l10n.billingUpdatedColumn,
            sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
                appListTableCompareDateTime(left.timelineAt, right.timelineAt),
            cellBuilder: (BuildContext context, BillingWorkItem item) {
              return Text(billingDateTime(context, item.timelineAt));
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
        onViewLedger: (item.patientId ?? item.effectivePatientNumber) != null
            ? () => showBillingLedgerDialog(context, ref, item: item)
            : null,
        onFinalizeEncounter: item.canFinalizeEncounterBilling
            ? () => _showFinalizeEncounterDialog(context, ref)
            : null,
      ),
      actions: <Widget>[
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
                    item.effectiveDisplayId,
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
              label: context.l10n.billingInvoiceLabel,
              value: widget.item.effectiveDisplayId,
              icon: Icons.receipt_long_outlined,
            ),
            AppReportSummaryItem(
              label: context.l10n.billingDueLabel,
              value: billingMoney(
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
          amountLabelText: context.l10n.billingAmountReceivedLabel,
          currencyLabelText: context.l10n.billingCurrencyLabel,
          isRequired: true,
          allowZero: false,
          maxAmount: widget.item.balanceDue,
        ),
        AppSelectField<String>(
          value: _method,
          labelText: context.l10n.billingPaymentMethodLabel,
          options: <AppSelectOption<String>>[
            for (final String method in billingPaymentMethods)
              AppSelectOption<String>(
                value: method,
                label: billingApiLabel(context, method),
              ),
          ],
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _method = value);
            }
          },
        ),
        AppTextField(
          controller: _referenceController,
          labelText: context.l10n.billingReferenceLabel,
          hintText: context.l10n.billingPaymentReferenceHint,
        ),
        AppTextField(
          controller: _payerController,
          labelText: context.l10n.billingPayerLabel,
          hintText: context.l10n.billingPayerHint,
        ),
        AppCheckboxField(
          title: context.l10n.billingGenerateReceiptLabel,
          value: _issueReceipt,
          onChanged: (bool value) => setState(() => _issueReceipt = value),
        ),
        AppFormActions(
          cancelLabel: context.l10n.commonCancelActionLabel,
          submitLabel: context.l10n.billingReceivePayment,
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
                reference: billingEmptyToNull(_referenceController.text),
                payer: billingEmptyToNull(_payerController.text),
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
          labelText: context.l10n.billingPaymentLabel,
          options: <AppSelectOption<String>>[
            for (final BillingPayment payment in widget.item.payments)
              if (payment.isRefundable)
                AppSelectOption<String>(
                  value: payment.id,
                  label: billingJoinDisplay(<String?>[
                    payment.effectiveDisplayId,
                    billingMoney(context, payment.amount, widget.item.currency),
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
          amountLabelText: context.l10n.billingRefundAmountLabel,
          currencyLabelText: context.l10n.billingCurrencyLabel,
          isRequired: true,
          allowZero: false,
        ),
        AppTextField(
          controller: _reasonController,
          labelText: context.l10n.billingReasonLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            context.l10n.billingRefundReasonValidation,
          ),
        ),
        AppTextField(
          controller: _notesController,
          labelText: context.l10n.billingNotesLabel,
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: context.l10n.commonCancelActionLabel,
          submitLabel: context.l10n.billingRequestRefund,
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
                notes: billingEmptyToNull(_notesController.text),
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
          labelText: context.l10n.billingAdjustmentAmountLabel,
          isRequired: true,
          validator: (String? value) {
            final String normalized = value?.replaceAll(',', '').trim() ?? '';
            if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(normalized)) {
              return context.l10n.billingAdjustmentAmountValidation;
            }
            return null;
          },
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        AppSelectField<String>(
          value: _status,
          labelText: context.l10n.billingAppliedStatusLabel,
          options: <AppSelectOption<String>>[
            AppSelectOption<String>(
              value: 'ISSUED',
              label: context.l10n.billingStatusIssued,
            ),
            AppSelectOption<String>(
              value: 'PARTIAL',
              label: context.l10n.billingStatusPartial,
            ),
            AppSelectOption<String>(
              value: 'PAID',
              label: context.l10n.billingStatusPaid,
            ),
            AppSelectOption<String>(
              value: 'DRAFT',
              label: context.l10n.billingStatusDraft,
            ),
          ],
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _status = value);
            }
          },
        ),
        AppTextField(
          controller: _reasonController,
          labelText: context.l10n.billingReasonLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            context.l10n.billingAdjustmentReasonValidation,
          ),
        ),
        AppTextField(
          controller: _notesController,
          labelText: context.l10n.billingNotesLabel,
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: context.l10n.commonCancelActionLabel,
          submitLabel: context.l10n.billingRequestAdjustment,
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
                notes: billingEmptyToNull(_notesController.text),
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
          validator: AppValidators.requiredText(
            context.l10n.billingReasonValidation,
          ),
        ),
        AppTextField(
          controller: _notesController,
          labelText: context.l10n.billingNotesLabel,
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
              'notes': billingEmptyToNull(_notesController.text),
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
          labelText: widget.email
              ? context.l10n.billingRecipientEmailLabel
              : context.l10n.billingNotesLabel,
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
            Navigator.of(context).pop(billingEmptyToNull(_controller.text));
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
            amountLabelText: context.l10n.billingExpectedAmountLabel,
            currencyLabelText: context.l10n.billingCurrencyLabel,
          ),
          AppCurrencyAmountField(
            amountController: _actualController,
            currency: appDefaultCurrencyCode,
            onCurrencyChanged: (_) {},
            amountLabelText: context.l10n.billingActualAmountLabel,
            currencyLabelText: context.l10n.billingCurrencyLabel,
          ),
        ],
        AppTextField(
          controller: _notesController,
          labelText: context.l10n.billingNotesLabel,
          maxLines: 3,
        ),
        AppCheckboxField(
          title: context.l10n.billingSubmitForApprovalLabel,
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
                expectedAmount: billingEmptyToNull(_expectedController.text),
                actualAmount: billingEmptyToNull(_actualController.text),
                notes: billingEmptyToNull(_notesController.text),
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
    title: Text(context.l10n.billingReceivePayment),
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
  _showMutationResult(context, ref, failure);
}

Future<void> _showRefundDialog(
  BuildContext context,
  WidgetRef ref,
  BillingWorkItem item,
) async {
  final BillingRefundDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(context.l10n.billingRequestRefund),
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
  _showMutationResult(context, ref, failure);
}

Future<void> _showAdjustmentDialog(
  BuildContext context,
  WidgetRef ref,
  BillingWorkItem item,
) async {
  final BillingAdjustmentDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(context.l10n.billingRequestAdjustment),
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
  _showMutationResult(context, ref, failure);
}

Future<void> _showVoidDialog(BuildContext context, WidgetRef ref) async {
  final Map<String, String?>? payload = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(context.l10n.billingVoidInvoice),
    icon: const Icon(Icons.block_outlined),
    content: _ReasonForm(
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
  final String? notes = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(context.l10n.billingIssueInvoice),
    icon: const Icon(Icons.outbox_outlined),
    content: _NotesForm(submitLabel: context.l10n.billingIssueAction),
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
  final String? recipientEmail = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(context.l10n.billingSendInvoice),
    icon: const Icon(Icons.send_outlined),
    content: _NotesForm(
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
  final BillingCloseDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(context.l10n.billingCloseShift),
    icon: const Icon(Icons.schedule_send_outlined),
    content: _CloseForm(
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
  final BillingCloseDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(context.l10n.billingCloseDay),
    icon: const Icon(Icons.today_outlined),
    content: _CloseForm(title: context.l10n.billingCloseDay, shiftClose: false),
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
  final String? notes = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(context.l10n.billingApproveAction),
    icon: const Icon(Icons.check_circle_outline),
    content: _NotesForm(submitLabel: context.l10n.billingApproveAction),
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
  final Map<String, String?>? payload = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(context.l10n.billingRejectAction),
    icon: const Icon(Icons.cancel_outlined),
    content: _ReasonForm(
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
  final String? notes = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(context.l10n.billingSubmitClaimAction),
    icon: const Icon(Icons.upload_outlined),
    content: _NotesForm(submitLabel: context.l10n.billingSubmitClaimAction),
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
  final BillingClaimActionDraft? draft = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(context.l10n.billingReconcileClaimAction),
    icon: const Icon(Icons.fact_check_outlined),
    content: const _ClaimReconcileForm(),
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

AppSearchBarFilterValue _billingFilterValue(BillingWorkspaceQuery query) {
  if (query.queue == BillingQueueType.all) {
    return AppSearchBarFilterValue.empty;
  }
  return AppSearchBarFilterValue(
    options: <String, String>{_billingQueueFilterKey: query.queue.name},
  );
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

class _ClaimReconcileForm extends StatefulWidget {
  const _ClaimReconcileForm();

  @override
  State<_ClaimReconcileForm> createState() => _ClaimReconcileFormState();
}

class _ClaimReconcileFormState extends State<_ClaimReconcileForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  String _status = 'APPROVED';

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
          labelText: l10n.billingStatusColumn,
          options: <AppSelectOption<String>>[
            AppSelectOption<String>(
              value: 'APPROVED',
              label: l10n.billingClaimStatusApproved,
            ),
            AppSelectOption<String>(
              value: 'REJECTED',
              label: l10n.billingClaimStatusRejected,
            ),
            AppSelectOption<String>(
              value: 'PAID',
              label: l10n.billingClaimStatusPaid,
            ),
          ],
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _status = value);
            }
          },
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.billingNotesLabel,
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.billingReconcileClaimAction,
          submitIcon: Icons.fact_check_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(
              BillingClaimActionDraft(
                status: _status,
                notes: billingEmptyToNull(_notesController.text),
              ),
            );
          },
        ),
      ],
    );
  }
}
