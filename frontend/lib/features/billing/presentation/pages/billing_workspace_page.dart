import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/currency/effective_default_currency_provider.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_invoice_print_helpers.dart';
import 'package:hosspi_hms/features/billing/presentation/controllers/billing_workspace_controller.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_detail_widgets.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_ledger_dialog.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_receive_payment_dialog.dart';
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
        columns: <AppListTableColumn<BillingWorkItem>>[
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
          ),
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
          ),
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
          ),
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
          ),
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
          ),
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
          ),
          AppListTableColumn<BillingWorkItem>(
            id: 'amount_due',
            label: l10n.billingAmountDueColumn,
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
            id: 'amount_paid',
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
        ],
        columnChoices: <AppListTableColumn<BillingWorkItem>>[
          AppListTableColumn<BillingWorkItem>(
            id: 'balance',
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
            id: 'updated',
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

class _RefundForm extends StatefulWidget {
  const _RefundForm({
    required this.dialogTitle,
    this.dialogIcon,
    required this.item,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
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

  void _submit() {
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
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
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
                      billingMoney(
                        context,
                        payment.amount,
                        widget.item.currency,
                      ),
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
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: context.l10n.billingRequestRefund,
        submitIcon: Icons.assignment_return_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}

class _AdjustmentForm extends StatefulWidget {
  const _AdjustmentForm({
    required this.dialogTitle,
    this.dialogIcon,
    required this.item,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
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

  void _submit() {
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
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
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
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: context.l10n.billingRequestAdjustment,
        submitIcon: Icons.tune,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}

class _ReasonForm extends StatefulWidget {
  const _ReasonForm({
    required this.dialogTitle,
    this.dialogIcon,
    required this.submitLabel,
    required this.reasonLabel,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
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

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(<String, String?>{
      'reason': _reasonController.text.trim(),
      'notes': billingEmptyToNull(_notesController.text),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
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
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: widget.submitLabel,
        submitIcon: Icons.save_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}

class _NotesForm extends StatefulWidget {
  const _NotesForm({
    required this.dialogTitle,
    this.dialogIcon,
    required this.submitLabel,
    this.email = false,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
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

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(billingEmptyToNull(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
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
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: widget.submitLabel,
        submitIcon: Icons.save_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}

class _CloseForm extends ConsumerStatefulWidget {
  const _CloseForm({
    required this.dialogTitle,
    this.dialogIcon,
    required this.title,
    required this.shiftClose,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
  final String title;
  final bool shiftClose;

  @override
  ConsumerState<_CloseForm> createState() => _CloseFormState();
}

class _CloseFormState extends ConsumerState<_CloseForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _expectedController = TextEditingController();
  final TextEditingController _actualController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _submitForApproval = true;

  @override
  void dispose() {
    _expectedController.dispose();
    _actualController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(
      BillingCloseDraft(
        expectedAmount: billingEmptyToNull(_expectedController.text),
        actualAmount: billingEmptyToNull(_actualController.text),
        notes: billingEmptyToNull(_notesController.text),
        submit: _submitForApproval,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String defaultCurrency = ref.watch(effectiveDefaultCurrencyProvider);
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          if (widget.shiftClose) ...<Widget>[
            AppCurrencyAmountField(
              amountController: _expectedController,
              currency: defaultCurrency,
              onCurrencyChanged: (_) {},
              amountLabelText: context.l10n.billingExpectedAmountLabel,
              currencyLabelText: context.l10n.billingCurrencyLabel,
            ),
            AppCurrencyAmountField(
              amountController: _actualController,
              currency: defaultCurrency,
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
            value: _submitForApproval,
            onChanged: (bool value) =>
                setState(() => _submitForApproval = value),
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: widget.title,
        submitIcon: Icons.task_alt_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
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
    builder: (_) => _RefundForm(
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
    builder: (_) => _AdjustmentForm(
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
    builder: (_) => _ReasonForm(
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
    builder: (_) => _NotesForm(
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
    builder: (_) => _NotesForm(
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
    builder: (_) => _CloseForm(
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
    builder: (_) => _CloseForm(
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
    builder: (_) => _NotesForm(
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
    builder: (_) => _ReasonForm(
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
    builder: (_) => _NotesForm(
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
    builder: (_) => _ClaimReconcileForm(
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
    builder: (_) => _NotesForm(
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

class _ClaimReconcileForm extends StatefulWidget {
  const _ClaimReconcileForm({required this.dialogTitle, this.dialogIcon});

  final Widget dialogTitle;
  final Widget? dialogIcon;

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

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(
      BillingClaimActionDraft(
        status: _status,
        notes: billingEmptyToNull(_notesController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
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
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: l10n.billingReconcileClaimAction,
        submitIcon: Icons.fact_check_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}
