import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_billing_helpers.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_catalog_dialog.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_instructions_print_helpers.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_order_item_pricing_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

class PharmacyWorkspacePage extends ConsumerWidget {
  const PharmacyWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<PharmacyWorkspaceState>> state = ref.watch(
      pharmacyWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<PharmacyWorkspaceState>(
      value: state,
      loadingTitle: l10n.pharmacyLoadingTitle,
      loadingBody: l10n.pharmacyLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(pharmacyWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, PharmacyWorkspaceState data) {
        return _PharmacyWorkspaceContent(state: data);
      },
    );
  }
}

class _PharmacyWorkspaceContent extends ConsumerStatefulWidget {
  const _PharmacyWorkspaceContent({required this.state});

  final PharmacyWorkspaceState state;

  @override
  ConsumerState<_PharmacyWorkspaceContent> createState() =>
      _PharmacyWorkspaceContentState();
}

class _PharmacyWorkspaceContentState
    extends ConsumerState<_PharmacyWorkspaceContent> {
  static const AccessRequirement _writeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[AppPermissions.pharmacyWrite],
  );

  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<PharmacyOrder>
  _tableColumnController;
  bool _handledSectionDeepLink = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<PharmacyOrder>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_handleSectionDeepLink());
    });
  }

  Future<void> _handleSectionDeepLink() async {
    if (_handledSectionDeepLink || !mounted) {
      return;
    }
    final String section =
        GoRouterState.of(context).uri.queryParameters['section']?.trim().toLowerCase() ??
        '';
    if (section != 'inventory' && section != 'stock') {
      return;
    }
    _handledSectionDeepLink = true;
    await openPharmacyCatalogDialog(
      context,
      ref,
      initialTab: PharmacyCatalogTab.inventory,
    );
  }

  @override
  void didUpdateWidget(covariant _PharmacyWorkspaceContent oldWidget) {
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

  Future<void> _openCatalogForInventoryAlert(
    PharmacyInventoryFilter filter,
  ) async {
    final AppFailure? failure = await ref
        .read(pharmacyWorkspaceControllerProvider.notifier)
        .applyInventoryFilter(filter);
    if (!mounted) {
      return;
    }
    _showFailureIfNeeded(context, failure);
    if (_readPharmacyState(ref) == null) {
      return;
    }
    await openPharmacyCatalogDialog(
      context,
      ref,
      initialTab: PharmacyCatalogTab.inventory,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyWorkspaceState state = widget.state;
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );

    return AppWorkspace(
      title: l10n.pharmacyTitle,
      leadingIcon: AppRouteIcons.pharmacy,
      toolbar: appWorkspaceToolbarWithLabels(
        l10n,
        summaryNotifications: <AppWorkspaceSummaryNotification>[
          if (state.workbench.summary.totalOrders > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.pharmacyFilterAll,
              count: state.workbench.summary.totalOrders,
              icon: Icons.inventory_2_outlined,
              onSelected: () => controller.applyFilter(PharmacyOrderFilter.all),
            ),
          if (state.workbench.summary.orderedQueue > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.pharmacySummaryReadyLabel,
              count: state.workbench.summary.orderedQueue,
              icon: Icons.medication_liquid_outlined,
              tone: AppWorkspaceStatusTone.info,
              onSelected: () =>
                  controller.applyFilter(PharmacyOrderFilter.ready),
            ),
          if (state.workbench.summary.partiallyDispensedQueue > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.pharmacySummaryPartialLabel,
              count: state.workbench.summary.partiallyDispensedQueue,
              icon: Icons.pending_actions_outlined,
              tone: AppWorkspaceStatusTone.warning,
              onSelected: () =>
                  controller.applyFilter(PharmacyOrderFilter.partial),
            ),
          if (state.workbench.summary.dispensedOrders > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.pharmacySummaryCompletedLabel,
              count: state.workbench.summary.dispensedOrders,
              icon: Icons.done_all_outlined,
              tone: AppWorkspaceStatusTone.success,
              onSelected: () =>
                  controller.applyFilter(PharmacyOrderFilter.completed),
            ),
          if (state.workbench.summary.dischargePendingQueue > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.pharmacyFilterDischarge,
              count: state.workbench.summary.dischargePendingQueue,
              icon: Icons.local_hospital_outlined,
              tone: AppWorkspaceStatusTone.warning,
              onSelected: () =>
                  controller.applyFilter(PharmacyOrderFilter.discharge),
            ),
          if (state.workbench.summary.outpatientQueue > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.pharmacyFilterOutpatient,
              count: state.workbench.summary.outpatientQueue,
              icon: Icons.person_outline,
              tone: AppWorkspaceStatusTone.info,
              onSelected: () =>
                  controller.applyFilter(PharmacyOrderFilter.outpatient),
            ),
          if (state.workbench.summary.wardQueue > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.pharmacyFilterWard,
              count: state.workbench.summary.wardQueue,
              icon: Icons.bed_outlined,
              tone: AppWorkspaceStatusTone.info,
              onSelected: () =>
                  controller.applyFilter(PharmacyOrderFilter.ward),
            ),
          if (state.workbench.summary.pendingPaymentQueue > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.pharmacyFilterPendingPayment,
              count: state.workbench.summary.pendingPaymentQueue,
              icon: Icons.payments_outlined,
              tone: AppWorkspaceStatusTone.warning,
              onSelected: () =>
                  controller.applyFilter(PharmacyOrderFilter.pendingPayment),
            ),
          if (state.workbench.summary.pendingAttestations > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.pharmacySummaryAttestationLabel,
              count: state.workbench.summary.pendingAttestations,
              icon: Icons.verified_outlined,
              tone: AppWorkspaceStatusTone.warning,
              onSelected: () =>
                  controller.applyFilter(PharmacyOrderFilter.partial),
            ),
          if (state.inventoryWorkbench.summary.criticalStockRows > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.pharmacySummaryLowStockLabel,
              count: state.inventoryWorkbench.summary.criticalStockRows,
              icon: Icons.warning_amber_outlined,
              tone: AppWorkspaceStatusTone.error,
              onSelected: () => unawaited(
                _openCatalogForInventoryAlert(PharmacyInventoryFilter.lowStock),
              ),
            ),
          if (state.inventoryWorkbench.summary.almostOutOfStockRows > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.pharmacySummaryAlmostOutLabel,
              count: state.inventoryWorkbench.summary.almostOutOfStockRows,
              icon: Icons.inventory_outlined,
              tone: AppWorkspaceStatusTone.warning,
              onSelected: () => unawaited(
                _openCatalogForInventoryAlert(
                  PharmacyInventoryFilter.almostOutOfStock,
                ),
              ),
            ),
          if (state.inventoryWorkbench.summary.expiringSoonRows > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.pharmacySummaryExpiringSoonLabel,
              count: state.inventoryWorkbench.summary.expiringSoonRows,
              icon: Icons.event_busy_outlined,
              tone: AppWorkspaceStatusTone.warning,
              onSelected: () => unawaited(
                _openCatalogForInventoryAlert(
                  PharmacyInventoryFilter.expiringSoon,
                ),
              ),
            ),
        ],
        maxVisibleScreenActions: 1,
        primary: AppButton.primary(
          label: l10n.pharmacyDispenseAction,
          leadingIcon: Icons.medication_liquid_outlined,
          onPressed: () => controller.applyFilter(PharmacyOrderFilter.ready),
        ),
        overflowSections: <AppToolbarOverflowSection>[
          AppToolbarOverflowSection(
            headerLabel: l10n.pharmacyCatalogPanelTitle,
            actions: <Widget>[
              AppButton.secondary(
                label: l10n.pharmacyCatalogPanelTitle,
                leadingIcon: Icons.inventory_2_outlined,
                onPressed: () {
                  unawaited(openPharmacyCatalogDialog(context, ref));
                },
              ),
            ],
          ),
          const AppToolbarOverflowSection(showsNotifications: true),
        ],
        onRefresh: () async {
          final AppFailure? failure = await controller.refresh();
          if (context.mounted) {
            _showFailureIfNeeded(context, failure);
          }
        },
        isRefreshing: state.isRefreshingOrders,
      ),

      body: _PharmacyQueuePanel(
        state: state,
        writeRequirement: _writeRequirement,
        searchController: _searchController,
        columnVisibilityController: _tableColumnController,
      ),
    );
  }
}

class _PharmacyQueuePanel extends ConsumerWidget {
  const _PharmacyQueuePanel({
    required this.state,
    required this.writeRequirement,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final PharmacyWorkspaceState state;
  final AccessRequirement writeRequirement;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<PharmacyOrder>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );

    return AppListTable<PharmacyOrder>(
      page: state.workbench.orders,
      isLoading: state.isRefreshingOrders,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      search: AppListTableSearch<PharmacyOrder>(
        controller: searchController,
        semanticLabel: l10n.pharmacySearchLabel,
        hintText: l10n.pharmacySearchHint,
        matcher: (_, _) => true,
        onSubmitted: controller.applySearch,
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.pharmacyQueueFilterLabel,
        advancedFilterTitle: l10n.pharmacyFiltersSemanticLabel,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        dateFilterLabel: l10n.pharmacyOrderDateFilterLabel,
        dateFromLabel: l10n.pharmacyOrderDateFilterLabel,
        dateToLabel: l10n.opdDateToLabel,
        datePickerButtonLabel: l10n.pharmacyPickOrderDateAction,
        invalidDateMessage: l10n.appDateInvalidMessage,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        currentDate: DateTime.now(),
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _pharmacyStatusFilterKey,
            label: l10n.pharmacyStatusFilterLabel,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: _pharmacyStatusFilterChoices(l10n),
          ),
          AppSearchBarFilterGroup(
            key: _pharmacyLocationFilterKey,
            label: l10n.pharmacyLocationFieldLabel,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: _pharmacyLocationFilterChoices(l10n),
          ),
          AppSearchBarFilterGroup(
            key: _pharmacyPaymentFilterKey,
            label: l10n.pharmacyPaymentColumnLabel,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: _pharmacyPaymentFilterChoices(l10n),
          ),
          AppSearchBarFilterGroup(
            key: _pharmacyPriorityFilterKey,
            label: l10n.pharmacyPriorityFieldLabel,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: _pharmacyPriorityFilterChoices(l10n),
          ),
          AppSearchBarFilterGroup(
            key: _pharmacyStockFilterKey,
            label: l10n.pharmacyFilterPartialStock,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: _pharmacyStockFilterChoices(l10n),
          ),
          AppSearchBarFilterGroup(
            key: _pharmacyUrgentFilterKey,
            label: l10n.pharmacyFilterUrgent,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: _pharmacyUrgentFilterChoices(l10n),
          ),
        ],
        filterValue: _pharmacyFilterValue(state.query),
        hasActiveFilters: !state.query.isDefaultFilters,
        onFilterChanged: (AppSearchBarFilterValue value) {
          unawaited(
            controller.applyAdvancedFilters(
              _pharmacyQueryFromFilterValue(state.query, value),
            ),
          );
        },
      ),
      previousPageLabel: l10n.opdPreviousPageLabel,
      nextPageLabel: l10n.opdNextPageLabel,
      pageLabelBuilder: (AppPage<PharmacyOrder> page) {
        return _pageLabel(context, page);
      },
      onPageChanged: controller.changePage,
      onRowSelected: (PharmacyOrder order) {
        unawaited(
          _openPharmacyDetailDialog(
            context,
            ref,
            state,
            order,
            writeRequirement,
          ),
        );
      },
      rowColorBuilder: _rowColor,
      emptyBuilder: (_) => AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: l10n.pharmacyNoOrdersTitle,
        body: l10n.pharmacyNoOrdersBody,
        icon: Icons.medication_liquid_outlined,
      ),
      columns: _defaultPharmacyWorklistColumns(context),
      columnChoices: _optionalPharmacyWorklistColumns(context),
      mobileItemBuilder: (BuildContext context, PharmacyOrder item) {
        return _PharmacyOrderListTile(order: item);
      },
    );
  }

  Color? _rowColor(BuildContext context, PharmacyOrder item) {
    if (item.hasPendingAttestation) {
      return Theme.of(
        context,
      ).statusColors.warningContainer.withValues(alpha: 0.22);
    }
    return null;
  }
}

class _PharmacyOrderPatientCell extends StatelessWidget {
  const _PharmacyOrderPatientCell({required this.order});

  final PharmacyOrder order;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      order.displayTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _PharmacyOrderListTile extends StatelessWidget {
  const _PharmacyOrderListTile({required this.order});

  final PharmacyOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            order.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            _locationLabel(context, order),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.sm),
          Wrap(
            spacing: theme.spacing.xs,
            runSpacing: theme.spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              AppWorkspaceStatusBadge(status: _orderStatus(context, order)),
              Text(
                _billingGateLabel(context, order),
                style: theme.textTheme.bodySmall,
              ),
              Text(
                _dispenseProgressLabel(context, order),
                style: theme.textTheme.bodySmall,
              ),
              if (order.hasPendingAttestation)
                AppWorkspaceStatusBadge(
                  status: AppWorkspaceStatus(
                    label: l10n.pharmacyPendingBatchLabel,
                    tone: AppWorkspaceStatusTone.warning,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PharmacyDetailPanel extends ConsumerWidget {
  const _PharmacyDetailPanel({
    required this.state,
    required this.writeRequirement,
  });

  final PharmacyWorkspaceState state;
  final AccessRequirement writeRequirement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyOrderWorkflow? workflow = state.selectedWorkflow;
    if (state.isRefreshingDetail && workflow == null) {
      return AppWorkspaceStatePanel.loading(
        title: l10n.pharmacyDetailLoadingTitle,
        body: l10n.pharmacyDetailLoadingBody,
      );
    }
    if (workflow == null) {
      return AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: l10n.pharmacyNoSelectionTitle,
        body: l10n.pharmacyNoSelectionBody,
        icon: Icons.receipt_long_outlined,
      );
    }

    final PharmacyOrder order = workflow.order;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppWorkspacePatientContextHeader(
          patientName: '',
          patientNumber: '',
          showAvatar: false,
          showPatientName: false,
          fieldStyle: AppWorkspacePatientContextFieldStyle.inline,
          fields: _pharmacyDetailContextFields(context, order),
        ),
        SizedBox(height: theme.spacing.md),
        _PharmacyActionPanel(
          workflow: workflow,
          writeRequirement: writeRequirement,
        ),
        SizedBox(height: theme.spacing.md),
        _MedicationItemsPanel(
          workflow: workflow,
          writeRequirement: writeRequirement,
        ),
        SizedBox(height: theme.spacing.md),
        _PharmacyWorkflowReadinessPanel(workflow: workflow),
        SizedBox(height: theme.spacing.md),
        _TimelinePanel(workflow: workflow),
      ],
    );
  }
}

Future<void> _openPharmacyDetailDialog(
  BuildContext context,
  WidgetRef ref,
  PharmacyWorkspaceState fallbackState,
  PharmacyOrder order,
  AccessRequirement writeRequirement,
) async {
  final PharmacyWorkspaceController controller = ref.read(
    pharmacyWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectOrder(order);
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }

  final PharmacyWorkspaceState state = _readPharmacyState(ref) ?? fallbackState;
  if (state.selectedWorkflow == null) {
    return;
  }

  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(context.l10n.pharmacyPrescriptionDetailTitle),
      icon: const Icon(Icons.receipt_long_outlined),
      scrollable: true,
      maxWidth: 980,
      content: _PharmacyDetailPanel(
        state: state,
        writeRequirement: writeRequirement,
      ),
    ),
  );
}

Future<void> _openRecordPaymentDialog(
  BuildContext context,
  WidgetRef ref,
  PharmacyOrder order,
) async {
  final ClinicalRequestBillingSubmit? billing =
      await showClinicalRequestBillingDialog(
        context: context,
        lineItems: pharmacyOrderBillingLineItems(order),
        initialPaymentStatus: clinicalRequestPaymentStatusFromValue(
          order.effectivePaymentStatus,
        ),
        initialPaidAmount: order.billing['paid_amount'] is num
            ? order.billing['paid_amount'] as num
            : num.tryParse(order.billing['paid_amount']?.toString() ?? ''),
        initialCurrency: order.billingCurrency,
      );
  if (billing == null || !context.mounted) {
    return;
  }

  final AppFailure? failure = await ref
      .read(pharmacyWorkspaceControllerProvider.notifier)
      .recordOrderBilling(billing.toPayloadMap());
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
    if (failure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pharmacySavedMessage)),
      );
    }
  }
}

PharmacyWorkspaceState? _readPharmacyState(WidgetRef ref) {
  return ref
      .read(pharmacyWorkspaceControllerProvider)
      .asData
      ?.value
      .when(
        success: (PharmacyWorkspaceState state) => state,
        failure: (_) => null,
      );
}

class _PharmacyActionPanel extends ConsumerWidget {
  const _PharmacyActionPanel({
    required this.workflow,
    required this.writeRequirement,
  });

  final PharmacyOrderWorkflow workflow;
  final AccessRequirement writeRequirement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final PharmacyOrder order = workflow.order;
    final bool canBill = ref
        .watch(appAccessPolicyProvider)
        .grants(AppPermissions.billingWrite);
    final bool canPrepare =
        workflow.nextActions.canPrepareDispense || order.canPrepareDispense;
    final bool canAttest =
        workflow.nextActions.canAttestDispense || order.canAttestDispense;
    final bool canCancel = workflow.nextActions.canCancel || order.canCancel;
    final bool canReturn = workflow.nextActions.canReturn || order.canReturn;
    final bool paymentBlocksDispense =
        order.requiresPaymentBeforeDispense && canPrepare;

    final List<AppActionItem> actions = <AppActionItem>[
      if (order.requiresPaymentBeforeDispense)
        AppActionItem(
          label: l10n.pharmacyRecordPaymentAction,
          leadingIcon: Icons.payments_outlined,
          enabled: canBill,
          onPressed: () => _openRecordPaymentDialog(context, ref, order),
        ),
      AppActionItem(
        label: l10n.pharmacyDispenseAction,
        leadingIcon: Icons.medication_liquid_outlined,
        enabled: canPrepare && !paymentBlocksDispense,
        tooltip: paymentBlocksDispense
            ? l10n.pharmacyDispenseBlockedPaymentBody
            : null,
        onPressed: () => _openDispenseDialog(context, workflow),
      ),
      AppActionItem(
        label: l10n.pharmacyAttestAction,
        leadingIcon: Icons.verified_outlined,
        enabled: canAttest,
        onPressed: () => _openAttestDialog(context, workflow),
      ),
      AppActionItem(
        label: l10n.pharmacyReturnAction,
        leadingIcon: Icons.keyboard_return_outlined,
        enabled: canReturn,
        onPressed: () => _openReturnDialog(context, workflow),
      ),
      AppActionItem(
        label: l10n.pharmacyCancelOrderAction,
        leadingIcon: Icons.cancel_outlined,
        enabled: canCancel,
        onPressed: () => _openCancelDialog(context),
      ),
    ];

    return AppAccessActionGate(
      requirement: writeRequirement,
      builder: (BuildContext context, bool isAllowed) => AppActionPanel(
        title: l10n.pharmacyActionsPanelTitle,
        titleIcon: Icons.touch_app_outlined,
        spacing: theme.spacing.xs,
        runSpacing: theme.spacing.xs,
        minItemWidth: 132,
        maxColumns: 6,
        actions: actions
            .map(
              (AppActionItem action) => AppActionItem(
                label: action.label,
                leadingIcon: action.leadingIcon,
                enabled: isAllowed && action.enabled,
                tooltip: action.tooltip,
                onPressed: action.onPressed,
              ),
            )
            .toList(growable: false),
        extraActions: <Widget>[
          AppReportActionButton.print(
            label: l10n.pharmacyPrintInstructionsAction,
            variant: AppButtonVariant.secondary,
            onPressed: () async {
              await printFormTemplateDocument(
                ref: ref,
                context: context,
                title: l10n.pharmacyReportTitle,
                patientContext: buildPrintFormPatientContext(
                  l10n,
                  patientName: workflow.order.displayTitle,
                  patientId: workflow.order.patientId,
                  encounterId: workflow.order.encounterId,
                ),
                contextReference: PrintFormContextReference(
                  label: l10n.pharmacyReportOrderLabel,
                  value: workflow.order.displayId ?? l10n.profileUnknownValue,
                ),
                bodyHtml: pharmacyInstructionsHtml(context, workflow),
                footerNote: l10n.pharmacyReportFooter,
                includeSignatures: true,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MedicationItemsPanel extends ConsumerWidget {
  const _MedicationItemsPanel({
    required this.workflow,
    required this.writeRequirement,
  });

  final PharmacyOrderWorkflow workflow;
  final AccessRequirement writeRequirement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyOrder order = workflow.order;
    final List<PharmacyOrderItem> items = workflow.items.isEmpty
        ? workflow.order.items
        : workflow.items;

    return AppWorkspaceDetailPanel(
      child: AppListTable<PharmacyOrderItem>(
        items: items,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        emptyBuilder: (_) => AppWorkspaceStatePanel.state(
          variant: AppStateViewVariant.empty,
          title: l10n.pharmacyNoMedicationTitle,
          body: l10n.pharmacyNoMedicationBody,
          icon: Icons.medication_outlined,
          minHeight: 180,
        ),
        columns: <AppListTableColumn<PharmacyOrderItem>>[
          AppListTableColumn<PharmacyOrderItem>(
            label: l10n.pharmacyMedicationColumnLabel,
            cellBuilder: (BuildContext context, PharmacyOrderItem item) {
              return Align(
                alignment: Alignment.topLeft,
                child: _MedicationCell(item: item),
              );
            },
          ),
          AppListTableColumn<PharmacyOrderItem>(
            label: l10n.pharmacyDoseColumnLabel,
            cellBuilder: (BuildContext context, PharmacyOrderItem item) {
              return Align(
                alignment: Alignment.topLeft,
                child: Text(item.doseLine),
              );
            },
          ),
          AppListTableColumn<PharmacyOrderItem>(
            label: l10n.pharmacyQuantityColumnLabel,
            cellBuilder: (BuildContext context, PharmacyOrderItem item) {
              return Align(
                alignment: Alignment.topLeft,
                child: Text(item.quantityLine),
              );
            },
          ),
          AppListTableColumn<PharmacyOrderItem>(
            label: l10n.pharmacyLinePriceColumnLabel,
            cellBuilder: (BuildContext context, PharmacyOrderItem item) {
              return Align(
                alignment: Alignment.topLeft,
                child: _MedicationPriceCell(order: order, item: item),
              );
            },
          ),
          AppListTableColumn<PharmacyOrderItem>(
            label: l10n.pharmacyLineActionsColumnLabel,
            cellBuilder: (BuildContext context, PharmacyOrderItem item) {
              return Align(
                alignment: Alignment.topLeft,
                child: _MedicationLineActions(
                  workflow: workflow,
                  item: item,
                  writeRequirement: writeRequirement,
                ),
              );
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, PharmacyOrderItem item) {
          final ThemeData theme = Theme.of(context);
          return Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MedicationCell(item: item),
                SizedBox(height: theme.spacing.sm),
                Text(item.doseLine, style: theme.textTheme.bodySmall),
                SizedBox(height: theme.spacing.xs),
                Text(item.quantityLine, style: theme.textTheme.bodySmall),
                SizedBox(height: theme.spacing.xs),
                _MedicationPriceCell(order: order, item: item),
                SizedBox(height: theme.spacing.sm),
                _MedicationLineActions(
                  workflow: workflow,
                  item: item,
                  writeRequirement: writeRequirement,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MedicationCell extends StatelessWidget {
  const _MedicationCell({required this.item});

  final PharmacyOrderItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.medicationLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if ((item.instructions ?? '').trim().isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            item.instructions!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _MedicationPriceCell extends StatelessWidget {
  const _MedicationPriceCell({required this.order, required this.item});

  final PharmacyOrder order;
  final PharmacyOrderItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final num? unitPrice = resolvePharmacyItemUnitPrice(
      order: order,
      item: item,
    );
    final num? lineTotal = resolvePharmacyItemLineTotal(
      order: order,
      item: item,
    );
    final String? currency = resolvePharmacyItemCurrency(
      order: order,
      item: item,
    );
    final PharmacyItemPriceSource source = resolvePharmacyItemPriceSource(
      order: order,
      item: item,
    );

    if (unitPrice == null || unitPrice <= 0) {
      return Text(
        l10n.pharmacyPriceUnavailableLabel,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    final String sourceLabel = switch (source) {
      PharmacyItemPriceSource.pharmacy => l10n.pharmacyPriceTierPharmacyLabel,
      PharmacyItemPriceSource.facility => l10n.pharmacyPriceTierFacilityLabel,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          clinicalRequestPriceLabel(context, unitPrice, currency),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          sourceLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (lineTotal != null && lineTotal > 0) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            '${l10n.pharmacyLineTotalLabel}: ${clinicalRequestPriceLabel(context, lineTotal, currency)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _MedicationLineActions extends ConsumerWidget {
  const _MedicationLineActions({
    required this.workflow,
    required this.item,
    required this.writeRequirement,
  });

  final PharmacyOrderWorkflow workflow;
  final PharmacyOrderItem item;
  final AccessRequirement writeRequirement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final PharmacyOrder order = workflow.order;
    final PharmacyItemPriceSource activeSource = resolvePharmacyItemPriceSource(
      order: order,
      item: item,
    );
    final bool canWrite = writeRequirement.isAllowed(
      ref.watch(appAccessPolicyProvider),
    );
    final List<Widget> actions = <Widget>[];

    if (pharmacyItemIsCancelled(item)) {
      return Text(
        l10n.pharmacyItemCancelledLabel,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    if (pharmacyItemNeedsStockMapping(item)) {
      actions.add(
        AppButton.tertiary(
          label: l10n.pharmacyMapStockAction,
          leadingIcon: Icons.inventory_2_outlined,
          enabled: canWrite,
          onPressed: canWrite
              ? () => openPharmacyCatalogDialog(context, ref)
              : null,
        ),
      );
    }

    if (pharmacyItemHasSelectablePrices(item)) {
      if (activeSource != PharmacyItemPriceSource.pharmacy) {
        actions.add(
          AppButton.tertiary(
            label: l10n.pharmacyUsePharmacyPriceAction,
            leadingIcon: Icons.local_pharmacy_outlined,
            enabled: canWrite,
            onPressed: canWrite
                ? () => _switchItemPriceSource(
                    context,
                    ref,
                    order,
                    item,
                    PharmacyItemPriceSource.pharmacy,
                  )
                : null,
          ),
        );
      }
      if (activeSource != PharmacyItemPriceSource.facility) {
        actions.add(
          AppButton.tertiary(
            label: l10n.pharmacyUseFacilityPriceAction,
            leadingIcon: Icons.account_balance_outlined,
            enabled: canWrite,
            onPressed: canWrite
                ? () => _switchItemPriceSource(
                    context,
                    ref,
                    order,
                    item,
                    PharmacyItemPriceSource.facility,
                  )
                : null,
          ),
        );
      }
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: theme.spacing.xs,
      runSpacing: theme.spacing.xs,
      children: actions,
    );
  }
}

class _PharmacyWorkflowReadinessPanel extends StatelessWidget {
  const _PharmacyWorkflowReadinessPanel({required this.workflow});

  final PharmacyOrderWorkflow workflow;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<PharmacyOrderItem> items = workflow.items.isEmpty
        ? workflow.order.items
        : workflow.items;
    final bool hasStockMapping =
        items.isNotEmpty &&
        items.every(
          (PharmacyOrderItem item) =>
              item.defaultStockMapping != null || item.stockMappings.isNotEmpty,
        );
    final bool hasPendingBatch = workflow.order.hasPendingAttestation;
    final bool canDispense =
        workflow.nextActions.canPrepareDispense ||
        workflow.order.canPrepareDispense;

    return AppWorkspaceDetailPanel(
      title: l10n.pharmacyWorkflowReadinessTitle,
      description: l10n.pharmacyWorkflowReadinessBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ReadinessLine(
            icon: canDispense ? Icons.check_circle_outline : Icons.info_outline,
            text: canDispense
                ? l10n.pharmacyReadinessDispenseAvailable
                : l10n.pharmacyReadinessDispenseBlocked,
          ),
          SizedBox(height: theme.spacing.xs),
          _ReadinessLine(
            icon: hasStockMapping
                ? Icons.inventory_2_outlined
                : Icons.warning_amber_outlined,
            text: hasStockMapping
                ? l10n.pharmacyReadinessStockMapped
                : l10n.pharmacyReadinessStockMissing,
          ),
          SizedBox(height: theme.spacing.xs),
          _ReadinessLine(
            icon: hasPendingBatch
                ? Icons.verified_outlined
                : Icons.fact_check_outlined,
            text: hasPendingBatch
                ? l10n.pharmacyReadinessAttestationRequired
                : l10n.pharmacyReadinessAttestationClear,
          ),
          SizedBox(height: theme.spacing.xs),
          _ReadinessLine(
            icon: Icons.print_outlined,
            text: l10n.pharmacyReadinessPrintReady,
          ),
        ],
      ),
    );
  }
}

class _ReadinessLine extends StatelessWidget {
  const _ReadinessLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          icon,
          size: theme.appTokens.listIconSize,
          color: theme.colorScheme.primary,
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({required this.workflow});

  final PharmacyOrderWorkflow workflow;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<PharmacyTimelineItem> timeline = workflow.timeline;
    return AppWorkspaceDetailPanel(
      title: l10n.pharmacyTimelinePanelTitle,
      description: l10n.pharmacyTimelinePanelDescription,
      child: timeline.isEmpty
          ? Text(l10n.pharmacyNoTimelineBody)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (
                  var index = 0;
                  index < timeline.length;
                  index += 1
                ) ...<Widget>[
                  _TimelineRow(item: timeline[index]),
                  if (index < timeline.length - 1)
                    SizedBox(height: theme.spacing.sm),
                ],
              ],
            ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item});

  final PharmacyTimelineItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          Icons.circle_outlined,
          size: theme.appTokens.listIconSize,
          color: theme.colorScheme.primary,
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _timelineLabel(context, item),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _dateTimeLabel(context, item.at),
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

class _DrugStockPanel extends ConsumerStatefulWidget {
  const _DrugStockPanel({required this.state});

  final PharmacyWorkspaceState state;

  @override
  ConsumerState<_DrugStockPanel> createState() => _DrugStockPanelState();
}

class _DrugStockPanelState extends ConsumerState<_DrugStockPanel> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.state.drugQuery.search,
    );
  }

  @override
  void didUpdateWidget(covariant _DrugStockPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.drugQuery.search != widget.state.drugQuery.search &&
        _searchController.text != widget.state.drugQuery.search) {
      _searchController.text = widget.state.drugQuery.search;
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
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
    final PharmacyWorkspaceState state = widget.state;

    return AppWorkspaceDetailPanel(
      title: l10n.pharmacyDrugPanelTitle,
      description: l10n.pharmacyDrugPanelDescription,
      child: AppListTable<PharmacyDrug>(
        page: state.drugs,
        isLoading: state.isRefreshingDrugs,
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        search: AppListTableSearch<PharmacyDrug>(
          controller: _searchController,
          semanticLabel: l10n.pharmacyDrugSearchLabel,
          hintText: l10n.pharmacyDrugSearchHint,
          matcher: (_, _) => true,
          onSubmitted: controller.applyDrugSearch,
          onClear: () {
            unawaited(controller.applyDrugSearch(''));
          },
          showAdvancedFilterButton: true,
          advancedFilterButtonLabel: l10n.pharmacyDrugFiltersSemanticLabel,
          advancedFilterTitle: l10n.pharmacyDrugFiltersSemanticLabel,
          advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
          advancedFilterResetLabel: l10n.opdClearFiltersAction,
          enableDateFilter: false,
          allFieldsLabel: l10n.opdAllFieldsFilterLabel,
          filterGroups: <AppSearchBarFilterGroup>[
            AppSearchBarFilterGroup(
              key: _pharmacyDrugStockStatusFilterKey,
              label: l10n.pharmacyStockStatusFilterLabel,
              allLabel: l10n.opdAllFieldsFilterLabel,
              choices: _stockStatusFilterChoices(l10n),
            ),
          ],
          filterValue: _pharmacyDrugFilterValue(state.drugQuery),
          hasActiveFilters: state.drugQuery.stockStatus != null,
          onFilterChanged: (AppSearchBarFilterValue value) {
            unawaited(
              controller.applyDrugStockStatus(
                value.option(_pharmacyDrugStockStatusFilterKey),
              ),
            );
          },
        ),
        previousPageLabel: l10n.opdPreviousPageLabel,
        nextPageLabel: l10n.opdNextPageLabel,
        pageLabelBuilder: (AppPage<PharmacyDrug> page) {
          return _pageLabel(context, page);
        },
        onPageChanged: controller.changeDrugPage,
        emptyBuilder: (_) => AppWorkspaceStatePanel.state(
          variant: AppStateViewVariant.empty,
          title: l10n.pharmacyNoDrugsTitle,
          body: l10n.pharmacyNoDrugsBody,
          icon: Icons.inventory_2_outlined,
          minHeight: 180,
        ),
        columns: <AppListTableColumn<PharmacyDrug>>[
          AppListTableColumn<PharmacyDrug>(
            label: l10n.pharmacyDrugColumnLabel,
            cellBuilder: (BuildContext context, PharmacyDrug item) {
              return _DrugCell(drug: item);
            },
          ),
          AppListTableColumn<PharmacyDrug>(
            label: l10n.pharmacyAvailableColumnLabel,
            numeric: true,
            cellBuilder: (BuildContext context, PharmacyDrug item) {
              return Text(_numberLabel(item.availableQuantity));
            },
          ),
          AppListTableColumn<PharmacyDrug>(
            label: l10n.pharmacyStockStatusColumnLabel,
            cellBuilder: (BuildContext context, PharmacyDrug item) {
              return AppWorkspaceStatusBadge(
                status: _stockStatus(context, item.stockStatus),
              );
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, PharmacyDrug item) {
          final ThemeData theme = Theme.of(context);
          return Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _DrugCell(drug: item),
                SizedBox(height: theme.spacing.sm),
                Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  children: <Widget>[
                    AppWorkspaceStatusBadge(
                      status: _stockStatus(context, item.stockStatus),
                    ),
                    Text(
                      l10n.pharmacyAvailableQuantityLabel(
                        _numberLabel(item.availableQuantity),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DrugCell extends StatelessWidget {
  const _DrugCell({required this.drug});

  final PharmacyDrug drug;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          drug.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          _joinDisplay(<String?>[drug.code, drug.displayId]),
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

class _DispenseDialog extends ConsumerStatefulWidget {
  const _DispenseDialog({required this.workflow});

  final PharmacyOrderWorkflow workflow;

  @override
  ConsumerState<_DispenseDialog> createState() => _DispenseDialogState();
}

class _DispenseDialogState extends ConsumerState<_DispenseDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _batchController;
  late final TextEditingController _statementController;
  late final TextEditingController _reasonController;
  late final List<_LineEditState> _lines;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _batchController = TextEditingController();
    _statementController = TextEditingController();
    _reasonController = TextEditingController();
    _lines = widget.workflow.items
        .where((PharmacyOrderItem item) => item.quantityRemaining > 0)
        .map((PharmacyOrderItem item) {
          return _LineEditState.forDispense(item);
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _batchController.dispose();
    _statementController.dispose();
    _reasonController.dispose();
    for (final _LineEditState line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.pharmacyDispenseDialogTitle),
      icon: const Icon(Icons.medication_liquid_outlined),
      initialMaximized: false,
      scrollable: true,
      pinActionsToBottom: true,
      content: AppFormShell(
        formKey: _formKey,
        formStatus: appFormGuidanceAndFailureStatus(
          context,
          guidanceMessage: widget.workflow.order.requiresPaymentBeforeDispense
              ? l10n.pharmacyDispenseBlockedPaymentBody
              : l10n.pharmacyDispenseDialogBody,
          failure: _failure,
        ),
        enabled: !_isSaving,
        children: <Widget>[
          AppTextField(
            controller: _batchController,
            labelText: l10n.pharmacyBatchRefLabel,
            enabled: !_isSaving,
          ),
          AppTextField(
            controller: _statementController,
            labelText: l10n.pharmacyStatementLabel,
            enabled: !_isSaving,
            maxLines: 3,
          ),
          AppTextField(
            controller: _reasonController,
            labelText: l10n.pharmacyReasonLabel,
            enabled: !_isSaving,
          ),
          for (final _LineEditState line in _lines)
            _LineEditTile(
              line: line,
              mode: _LineEditMode.dispense,
              isSaving: _isSaving,
            ),
        ],
      ),
      actions: _dialogActions(
        context,
        l10n.pharmacyPrepareDispenseAction,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final List<PharmacyDispenseLineInput> selected = _lines
        .map((line) => line.toDispenseInput())
        .whereType<PharmacyDispenseLineInput>()
        .toList(growable: false);
    if (selected.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(pharmacyWorkspaceControllerProvider.notifier)
        .prepareDispense(
          items: selected,
          dispenseBatchRef: _batchController.text.trim(),
          statement: _statementController.text.trim(),
          reason: _reasonController.text.trim(),
        );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
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

class _AttestDialog extends ConsumerStatefulWidget {
  const _AttestDialog({required this.workflow});

  final PharmacyOrderWorkflow workflow;

  @override
  ConsumerState<_AttestDialog> createState() => _AttestDialogState();
}

class _AttestDialogState extends ConsumerState<_AttestDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _batchController;
  late final TextEditingController _statementController;
  late final TextEditingController _reasonController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _batchController = TextEditingController(
      text: widget.workflow.order.firstPendingBatchRef ?? '',
    );
    _statementController = TextEditingController();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _batchController.dispose();
    _statementController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.pharmacyAttestDialogTitle),
      icon: const Icon(Icons.verified_outlined),
      initialMaximized: false,
      scrollable: true,
      pinActionsToBottom: true,
      content: AppFormShell(
        formKey: _formKey,
        formStatus: appFormGuidanceAndFailureStatus(
          context,
          guidanceMessage: l10n.pharmacyAttestDialogBody,
          failure: _failure,
        ),
        enabled: !_isSaving,
        children: <Widget>[
          AppTextField(
            controller: _batchController,
            labelText: l10n.pharmacyBatchRefLabel,
            enabled: !_isSaving,
            isRequired: true,
            validator: AppValidators.requiredText(l10n.validationRequired),
          ),
          AppTextField(
            controller: _statementController,
            labelText: l10n.pharmacyStatementLabel,
            enabled: !_isSaving,
            maxLines: 3,
          ),
          AppTextField(
            controller: _reasonController,
            labelText: l10n.pharmacyReasonLabel,
            enabled: !_isSaving,
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        l10n.pharmacyAttestAction,
        _isSaving,
        _submit,
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
        .read(pharmacyWorkspaceControllerProvider.notifier)
        .attestDispense(
          dispenseBatchRef: _batchController.text.trim(),
          statement: _statementController.text.trim(),
          reason: _reasonController.text.trim(),
        );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
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

class _ReturnDialog extends ConsumerStatefulWidget {
  const _ReturnDialog({required this.workflow});

  final PharmacyOrderWorkflow workflow;

  @override
  ConsumerState<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends ConsumerState<_ReturnDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _reasonController;
  late final TextEditingController _notesController;
  late final List<_LineEditState> _lines;
  final Set<String> _selectedLineIds = <String>{};
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
    _notesController = TextEditingController();
    final List<PharmacyOrderItem> items = widget.workflow.items.isEmpty
        ? widget.workflow.order.items
        : widget.workflow.items;
    _lines = items
        .where((PharmacyOrderItem item) => item.quantityDispensed > 0)
        .map((PharmacyOrderItem item) => _LineEditState.forReturn(item))
        .toList(growable: false);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    for (final _LineEditState line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.pharmacyReturnDialogTitle),
      icon: const Icon(Icons.keyboard_return_outlined),
      initialMaximized: false,
      scrollable: true,
      pinActionsToBottom: true,
      content: AppFormShell(
        formKey: _formKey,
        formStatus: appFormGuidanceAndFailureStatus(
          context,
          guidanceMessage: l10n.pharmacyReturnDialogBody,
          failure: _failure,
        ),
        enabled: !_isSaving,
        children: <Widget>[
          AppTextField(
            controller: _reasonController,
            labelText: l10n.pharmacyReasonLabel,
            enabled: !_isSaving,
            isRequired: true,
            validator: AppValidators.requiredText(l10n.validationRequired),
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.pharmacyNotesLabel,
            enabled: !_isSaving,
            maxLines: 3,
          ),
          _ReturnMedicationsTable(
            lines: _lines,
            selectedLineIds: _selectedLineIds,
            isSaving: _isSaving,
            onSelectedLineIdsChanged: (Set<String> value) {
              setState(() {
                _selectedLineIds
                  ..clear()
                  ..addAll(value);
              });
            },
            onEditLine: _editLine,
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        l10n.pharmacyReturnAction,
        _isSaving,
        _submit,
        cancelLeadingIcon: Icons.close,
        submitLeadingIcon: Icons.keyboard_return_outlined,
      ),
    );
  }

  Future<void> _editLine(_LineEditState line) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          _ReturnLineEditDialog(line: line, isSaving: _isSaving),
    );
    if (saved == true && mounted) {
      setState(() {
        _selectedLineIds.add(line.item.id);
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final List<PharmacyReturnLineInput> selected = _lines
        .where((_LineEditState line) => _selectedLineIds.contains(line.item.id))
        .map((line) => line.toReturnInput())
        .whereType<PharmacyReturnLineInput>()
        .toList(growable: false);
    if (selected.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(pharmacyWorkspaceControllerProvider.notifier)
        .returnDispense(
          items: selected,
          reason: _reasonController.text.trim(),
          notes: _notesController.text.trim(),
        );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
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

const String _returnTableSelectColumnKey = 'select';
const String _returnTableMedicationColumnKey = 'medication';
const String _returnTableDoseColumnKey = 'dose';
const String _returnTableQuantityColumnKey = 'quantity';
const String _returnTableReturnQuantityColumnKey = 'return_quantity';
const String _returnTableActionsColumnKey = 'actions';

class _ReturnMedicationsTable extends StatelessWidget {
  const _ReturnMedicationsTable({
    required this.lines,
    required this.selectedLineIds,
    required this.isSaving,
    required this.onSelectedLineIdsChanged,
    required this.onEditLine,
  });

  final List<_LineEditState> lines;
  final Set<String> selectedLineIds;
  final bool isSaving;
  final ValueChanged<Set<String>> onSelectedLineIdsChanged;
  final ValueChanged<_LineEditState> onEditLine;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: AppListTable<_LineEditState>(
        items: lines,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        displayMode: AppListTableDisplayMode.table,
        tableHorizontalMargin: theme.spacing.sm,
        itemKeyBuilder: (_LineEditState line) => ValueKey<String>(line.item.id),
        columns: _columns(context),
        emptyBuilder: (BuildContext context) {
          return Padding(
            padding: EdgeInsets.all(theme.spacing.lg),
            child: Center(
              child: Text(
                l10n.pharmacyNoMedicationBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
        mobileItemBuilder: (BuildContext context, _LineEditState line) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Checkbox(
                      value: selectedLineIds.contains(line.item.id),
                      onChanged: isSaving
                          ? null
                          : (bool? value) =>
                                _toggleLine(line.item.id, value ?? false),
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(child: _MedicationCell(item: line.item)),
                  ],
                ),
                SizedBox(height: theme.spacing.xs),
                Text(line.item.doseLine, style: theme.textTheme.bodySmall),
                SizedBox(height: theme.spacing.xs),
                Text(line.item.quantityLine, style: theme.textTheme.bodySmall),
                SizedBox(height: theme.spacing.xs),
                Text(
                  '${l10n.pharmacyReturnQuantityColumnLabel}: '
                  '${_returnQuantityLabel(line)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: theme.spacing.sm),
                AppButton.tertiary(
                  label: l10n.pharmacyReturnEditLineAction,
                  leadingIcon: Icons.edit_outlined,
                  enabled: !isSaving,
                  onPressed: () => onEditLine(line),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<AppListTableColumn<_LineEditState>> _columns(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return <AppListTableColumn<_LineEditState>>[
      _selectionColumn(),
      AppListTableColumn<_LineEditState>(
        id: _returnTableMedicationColumnKey,
        label: l10n.pharmacyMedicationColumnLabel,
        cellBuilder: (BuildContext context, _LineEditState line) {
          return Align(
            alignment: Alignment.topLeft,
            child: _MedicationCell(item: line.item),
          );
        },
      ),
      AppListTableColumn<_LineEditState>(
        id: _returnTableDoseColumnKey,
        label: l10n.pharmacyDoseColumnLabel,
        cellBuilder: (BuildContext context, _LineEditState line) {
          return Align(
            alignment: Alignment.topLeft,
            child: Text(line.item.doseLine),
          );
        },
      ),
      AppListTableColumn<_LineEditState>(
        id: _returnTableQuantityColumnKey,
        label: l10n.pharmacyQuantityColumnLabel,
        cellBuilder: (BuildContext context, _LineEditState line) {
          return Align(
            alignment: Alignment.topLeft,
            child: Text(line.item.quantityLine),
          );
        },
      ),
      AppListTableColumn<_LineEditState>(
        id: _returnTableReturnQuantityColumnKey,
        label: l10n.pharmacyReturnQuantityColumnLabel,
        cellBuilder: (BuildContext context, _LineEditState line) {
          return Align(
            alignment: Alignment.topLeft,
            child: Text(
              _returnQuantityLabel(line),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          );
        },
      ),
      AppListTableColumn<_LineEditState>(
        id: _returnTableActionsColumnKey,
        label: l10n.pharmacyLineActionsColumnLabel,
        alwaysVisible: true,
        cellBuilder: (BuildContext context, _LineEditState line) {
          return Align(
            alignment: Alignment.topLeft,
            child: AppButton.tertiary(
              label: l10n.pharmacyReturnEditLineAction,
              leadingIcon: Icons.edit_outlined,
              enabled: !isSaving,
              onPressed: () => onEditLine(line),
            ),
          );
        },
      ),
    ];
  }

  AppListTableColumn<_LineEditState> _selectionColumn() {
    return AppListTableColumn<_LineEditState>(
      id: _returnTableSelectColumnKey,
      label: '',
      alwaysVisible: true,
      headerBuilder: (BuildContext context) {
        final bool allSelected =
            lines.isNotEmpty &&
            lines.every(
              (_LineEditState line) => selectedLineIds.contains(line.item.id),
            );
        final bool someSelected = lines.any(
          (_LineEditState line) => selectedLineIds.contains(line.item.id),
        );
        return Checkbox(
          tristate: true,
          value: allSelected
              ? true
              : someSelected
              ? null
              : false,
          onChanged: isSaving || lines.isEmpty
              ? null
              : (bool? checked) => _toggleAll(checked ?? false),
          visualDensity: VisualDensity.compact,
        );
      },
      cellBuilder: (BuildContext context, _LineEditState line) {
        return Checkbox(
          value: selectedLineIds.contains(line.item.id),
          onChanged: isSaving
              ? null
              : (bool? value) => _toggleLine(line.item.id, value ?? false),
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }

  void _toggleLine(String lineId, bool selected) {
    final Set<String> next = Set<String>.from(selectedLineIds);
    if (selected) {
      next.add(lineId);
    } else {
      next.remove(lineId);
    }
    onSelectedLineIdsChanged(next);
  }

  void _toggleAll(bool selected) {
    if (!selected) {
      onSelectedLineIdsChanged(<String>{});
      return;
    }
    onSelectedLineIdsChanged(
      lines.map((_LineEditState line) => line.item.id).toSet(),
    );
  }
}

String _returnQuantityLabel(_LineEditState line) {
  final int quantity = int.tryParse(line.quantityController.text.trim()) ?? 0;
  if (quantity <= 0) {
    return '—';
  }
  return _wholeNumber(quantity);
}

class _ReturnLineEditDialog extends StatefulWidget {
  const _ReturnLineEditDialog({required this.line, required this.isSaving});

  final _LineEditState line;
  final bool isSaving;

  @override
  State<_ReturnLineEditDialog> createState() => _ReturnLineEditDialogState();
}

class _ReturnLineEditDialogState extends State<_ReturnLineEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.pharmacyReturnEditLineDialogTitle),
      icon: const Icon(Icons.edit_outlined),
      initialMaximized: false,
      scrollable: true,
      pinActionsToBottom: true,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !widget.isSaving,
        children: <Widget>[
          _LineEditTile(
            line: widget.line,
            mode: _LineEditMode.returned,
            isSaving: widget.isSaving,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          enabled: !widget.isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.commonSaveActionLabel,
          leadingIcon: Icons.check,
          enabled: !widget.isSaving,
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(true);
            }
          },
        ),
      ],
    );
  }
}

class _CancelOrderDialog extends ConsumerStatefulWidget {
  const _CancelOrderDialog();

  @override
  ConsumerState<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends ConsumerState<_CancelOrderDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _reasonController;
  late final TextEditingController _notesController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
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
      title: Text(l10n.pharmacyCancelDialogTitle),
      icon: const Icon(Icons.cancel_outlined),
      initialMaximized: false,
      scrollable: true,
      pinActionsToBottom: true,
      content: AppFormShell(
        formKey: _formKey,
        formStatus: appFormGuidanceAndFailureStatus(
          context,
          guidanceMessage: l10n.pharmacyCancelDialogBody,
          failure: _failure,
        ),
        enabled: !_isSaving,
        children: <Widget>[
          AppTextField(
            controller: _reasonController,
            labelText: l10n.pharmacyReasonLabel,
            enabled: !_isSaving,
            isRequired: true,
            validator: AppValidators.requiredText(l10n.validationRequired),
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.pharmacyNotesLabel,
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        l10n.pharmacyCancelOrderAction,
        _isSaving,
        _submit,
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
        .read(pharmacyWorkspaceControllerProvider.notifier)
        .cancelOrder(
          reason: _reasonController.text.trim(),
          notes: _notesController.text.trim(),
        );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
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

enum _LineEditMode { dispense, returned }

class _LineEditState {
  _LineEditState({
    required this.item,
    required this.quantityController,
    this.inventoryItemId,
  });

  factory _LineEditState.forDispense(PharmacyOrderItem item) {
    return _LineEditState(
      item: item,
      quantityController: TextEditingController(
        text: _wholeNumber(item.quantityRemaining),
      ),
      inventoryItemId: item.defaultStockMapping?.inventoryItemId,
    );
  }

  factory _LineEditState.forReturn(PharmacyOrderItem item) {
    return _LineEditState(
      item: item,
      quantityController: TextEditingController(),
      inventoryItemId: item.defaultStockMapping?.inventoryItemId,
    );
  }

  final PharmacyOrderItem item;
  final TextEditingController quantityController;
  String? inventoryItemId;

  void dispose() {
    quantityController.dispose();
  }

  PharmacyDispenseLineInput? toDispenseInput() {
    final int quantity = int.tryParse(quantityController.text.trim()) ?? 0;
    if (quantity <= 0) {
      return null;
    }
    return PharmacyDispenseLineInput(
      orderItemId: item.id,
      quantity: quantity,
      inventoryItemId: inventoryItemId,
    );
  }

  PharmacyReturnLineInput? toReturnInput() {
    final int quantity = int.tryParse(quantityController.text.trim()) ?? 0;
    if (quantity <= 0) {
      return null;
    }
    return PharmacyReturnLineInput(
      orderItemId: item.id,
      quantity: quantity,
      inventoryItemId: inventoryItemId,
    );
  }
}

class _LineEditTile extends StatefulWidget {
  const _LineEditTile({
    required this.line,
    required this.mode,
    required this.isSaving,
  });

  final _LineEditState line;
  final _LineEditMode mode;
  final bool isSaving;

  @override
  State<_LineEditTile> createState() => _LineEditTileState();
}

class _LineEditTileState extends State<_LineEditTile> {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyOrderItem item = widget.line.item;
    final num maxQuantity = switch (widget.mode) {
      _LineEditMode.dispense => item.quantityRemaining,
      _LineEditMode.returned => item.quantityDispensed,
    };
    final List<PharmacyStockMapping> mappings = item.stockMappings;

    return AppFormSection(
      title: item.medicationLabel,
      description: _joinDisplay(<String?>[item.doseLine, item.quantityLine]),
      density: AppFormSectionDensity.compact,
      children: <Widget>[
        AppTextField(
          controller: widget.line.quantityController,
          labelText: l10n.pharmacyQuantityFieldLabel,
          enabled: !widget.isSaving,
          keyboardType: TextInputType.number,
          inputFormatters: _integerFormatters,
          validator: (String? value) {
            final int quantity = int.tryParse((value ?? '').trim()) ?? 0;
            if (quantity < 0 || quantity > maxQuantity) {
              return l10n.pharmacyQuantityValidationLabel(
                _wholeNumber(maxQuantity),
              );
            }
            return null;
          },
        ),
        if (mappings.isNotEmpty)
          AppSelectField<String>(
            value: widget.line.inventoryItemId,
            labelText: l10n.pharmacyInventoryItemLabel,
            enabled: !widget.isSaving,
            options: <AppSelectOption<String>>[
              for (final PharmacyStockMapping mapping in mappings)
                AppSelectOption<String>(
                  value: mapping.inventoryItemId ?? mapping.id,
                  label: mapping.displayTitle,
                ),
            ],
            onChanged: (String? value) {
              setState(() => widget.line.inventoryItemId = value);
            },
          ),
      ],
    );
  }
}

List<Widget> _dialogActions(
  BuildContext context,
  String submitLabel,
  bool isSaving,
  VoidCallback onSubmit, {
  IconData? cancelLeadingIcon,
  IconData? submitLeadingIcon,
}) {
  final AppLocalizations l10n = context.l10n;
  return <Widget>[
    AppButton.tertiary(
      label: l10n.commonCancelActionLabel,
      leadingIcon: cancelLeadingIcon,
      enabled: !isSaving,
      onPressed: () => Navigator.of(context).pop(false),
    ),
    AppButton.primary(
      label: submitLabel,
      leadingIcon: submitLeadingIcon,
      isLoading: isSaving,
      onPressed: onSubmit,
    ),
  ];
}

Future<void> _openDispenseDialog(
  BuildContext context,
  PharmacyOrderWorkflow workflow,
) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DispenseDialog(workflow: workflow),
    ),
  );
}

Future<void> _openAttestDialog(
  BuildContext context,
  PharmacyOrderWorkflow workflow,
) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AttestDialog(workflow: workflow),
    ),
  );
}

Future<void> _openReturnDialog(
  BuildContext context,
  PharmacyOrderWorkflow workflow,
) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReturnDialog(workflow: workflow),
    ),
  );
}

Future<void> _openCancelDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CancelOrderDialog(),
    ),
  );
}

Future<void> _showActionResult(
  BuildContext context,
  Future<bool?> future,
) async {
  final bool? saved = await future;
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.pharmacySavedMessage)));
  }
}

const String _pharmacyStatusFilterKey = 'status';
const String _pharmacyLocationFilterKey = 'location';
const String _pharmacyPaymentFilterKey = 'pending_payment';
const String _pharmacyPriorityFilterKey = 'priority';
const String _pharmacyStockFilterKey = 'partial_stock';
const String _pharmacyUrgentFilterKey = 'urgent';

List<AppListTableColumn<PharmacyOrder>> _defaultPharmacyWorklistColumns(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppListTableColumn<PharmacyOrder>>[
    AppListTableColumn<PharmacyOrder>(
      label: l10n.pharmacyPatientColumnLabel,
      sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
          appListTableCompareText(left.displayTitle, right.displayTitle),
      cellBuilder: (BuildContext context, PharmacyOrder item) {
        return _PharmacyOrderPatientCell(order: item);
      },
    ),
    AppListTableColumn<PharmacyOrder>(
      label: l10n.pharmacyOrderColumnLabel,
      sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
          appListTableCompareText(left.displayId, right.displayId),
      cellBuilder: (BuildContext context, PharmacyOrder item) {
        return Text(item.displayId ?? '');
      },
    ),
    AppListTableColumn<PharmacyOrder>(
      label: l10n.pharmacyLocationFieldLabel,
      sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
          appListTableCompareText(
            _locationLabel(context, left),
            _locationLabel(context, right),
          ),
      cellBuilder: (BuildContext context, PharmacyOrder item) {
        return Text(_locationLabel(context, item));
      },
    ),
    AppListTableColumn<PharmacyOrder>(
      label: l10n.pharmacyItemsColumnLabel,
      numeric: true,
      sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
          appListTableCompareNumber(left.itemCount, right.itemCount),
      cellBuilder: (BuildContext context, PharmacyOrder item) {
        return Text(_numberLabel(item.itemCount));
      },
    ),
    AppListTableColumn<PharmacyOrder>(
      label: l10n.pharmacyDispenseColumnLabel,
      sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
          appListTableCompareNumber(
            left.quantityDispensedTotal,
            right.quantityDispensedTotal,
          ),
      cellBuilder: (BuildContext context, PharmacyOrder item) {
        return Text(_dispenseProgressLabel(context, item));
      },
    ),
    AppListTableColumn<PharmacyOrder>(
      label: l10n.pharmacyPaymentColumnLabel,
      id: 'billing',
      sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
          appListTableCompareText(
            left.effectivePaymentStatus,
            right.effectivePaymentStatus,
          ),
      cellBuilder: (BuildContext context, PharmacyOrder item) {
        return Text(_billingGateLabel(context, item));
      },
    ),
    AppListTableColumn<PharmacyOrder>(
      label: l10n.pharmacyStatusColumnLabel,
      sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
          appListTableCompareText(left.status, right.status),
      cellBuilder: (BuildContext context, PharmacyOrder item) {
        return AppWorkspaceStatusBadge(status: _orderStatus(context, item));
      },
    ),
  ];
}

List<AppListTableColumn<PharmacyOrder>> _optionalPharmacyWorklistColumns(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppListTableColumn<PharmacyOrder>>[
    AppListTableColumn<PharmacyOrder>(
      id: 'patient_id',
      label: l10n.labPatientIdColumnLabel,
      sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
          appListTableCompareText(left.patientId, right.patientId),
      cellBuilder: (BuildContext context, PharmacyOrder item) {
        return Text(item.patientId ?? '');
      },
    ),
    AppListTableColumn<PharmacyOrder>(
      id: 'encounter',
      label: l10n.pharmacyEncounterFieldLabel,
      sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
          appListTableCompareText(left.encounterId, right.encounterId),
      cellBuilder: (BuildContext context, PharmacyOrder item) {
        return AppCopyableIdentifier(
          value: item.encounterId,
          tooltip: context.l10n.opdCopyEncounterIdAction,
          copiedMessage: context.l10n.opdEncounterIdCopiedMessage,
        );
      },
    ),
    AppListTableColumn<PharmacyOrder>(
      id: 'ordered_at',
      label: l10n.pharmacyOrderedAtColumnLabel,
      sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
          appListTableCompareText(
            _dateTimeLabel(context, left.orderedAt),
            _dateTimeLabel(context, right.orderedAt),
          ),
      cellBuilder: (BuildContext context, PharmacyOrder item) {
        return Text(_dateTimeLabel(context, item.orderedAt));
      },
    ),
    AppListTableColumn<PharmacyOrder>(
      id: 'priority',
      label: l10n.pharmacyPriorityFieldLabel,
      sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
          appListTableCompareText(left.priority, right.priority),
      cellBuilder: (BuildContext context, PharmacyOrder item) {
        return Text(_priorityLabel(context, item));
      },
    ),
    AppListTableColumn<PharmacyOrder>(
      id: 'prescriber',
      label: l10n.pharmacyPrescriberFieldLabel,
      sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
          appListTableCompareText(
            left.prescriberDisplayName,
            right.prescriberDisplayName,
          ),
      cellBuilder: (BuildContext context, PharmacyOrder item) {
        return Text(item.prescriberDisplayName ?? '');
      },
    ),
    AppListTableColumn<PharmacyOrder>(
      id: 'order_source',
      label: l10n.pharmacyOrderSourceFieldLabel,
      sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
          appListTableCompareText(left.orderSource, right.orderSource),
      cellBuilder: (BuildContext context, PharmacyOrder item) {
        return Text(_orderSourceLabel(context, item));
      },
    ),
    AppListTableColumn<PharmacyOrder>(
      id: 'pending_attestation',
      label: l10n.pharmacyPendingBatchLabel,
      sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
          appListTableCompareNumber(
            left.pendingAttestationBatchCount,
            right.pendingAttestationBatchCount,
          ),
      cellBuilder: (BuildContext context, PharmacyOrder item) {
        return Text(
          item.hasPendingAttestation
              ? (item.firstPendingBatchRef ?? l10n.pharmacyPendingBatchLabel)
              : '',
        );
      },
    ),
    AppListTableColumn<PharmacyOrder>(
      id: 'remaining_qty',
      label: l10n.pharmacyRemainingQtyColumnLabel,
      numeric: true,
      sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
          appListTableCompareNumber(
            left.quantityRemainingTotal,
            right.quantityRemainingTotal,
          ),
      cellBuilder: (BuildContext context, PharmacyOrder item) {
        return Text(_numberLabel(item.quantityRemainingTotal));
      },
    ),
  ];
}

String _locationLabel(BuildContext context, PharmacyOrder order) {
  final AppLocalizations l10n = context.l10n;
  return switch ((order.location ?? '').toUpperCase()) {
    'INPATIENT' => l10n.pharmacyFilterWard,
    'DISCHARGE' => l10n.pharmacyFilterDischarge,
    'OUTPATIENT' => l10n.pharmacyFilterOutpatient,
    _ => l10n.pharmacyFilterOutpatient,
  };
}

String _priorityLabel(BuildContext context, PharmacyOrder order) {
  final AppLocalizations l10n = context.l10n;
  return switch ((order.priority ?? '').toUpperCase()) {
    'STAT' || 'URGENT' => l10n.pharmacyFilterUrgent,
    _ => l10n.pharmacyFilterReady,
  };
}

String _orderSourceLabel(BuildContext context, PharmacyOrder order) {
  final AppLocalizations l10n = context.l10n;
  return switch ((order.orderSource ?? '').toUpperCase()) {
    'CLINICAL' => l10n.pharmacyOrderSourceClinicalLabel,
    _ => l10n.pharmacyOrderSourcePharmacyLabel,
  };
}

AppSearchBarFilterValue _pharmacyFilterValue(PharmacyWorkbenchQuery query) {
  final Map<String, String> options = <String, String>{};
  if (query.status != null) {
    options[_pharmacyStatusFilterKey] = query.status!;
  }
  if (query.location != null) {
    options[_pharmacyLocationFilterKey] = query.location!;
  }
  if (query.pendingPayment == true) {
    options[_pharmacyPaymentFilterKey] = 'true';
  }
  if (query.priority != null) {
    options[_pharmacyPriorityFilterKey] = query.priority!;
  }
  if (query.partialStock == true) {
    options[_pharmacyStockFilterKey] = 'true';
  }
  if (query.urgent == true) {
    options[_pharmacyUrgentFilterKey] = 'true';
  }
  return AppSearchBarFilterValue(
    options: options,
    dateFrom: query.from,
    dateTo: query.to,
  );
}

PharmacyWorkbenchQuery _pharmacyQueryFromFilterValue(
  PharmacyWorkbenchQuery current,
  AppSearchBarFilterValue value,
) {
  final String? status = value.option(_pharmacyStatusFilterKey);
  final String? location = value.option(_pharmacyLocationFilterKey);
  final String? pendingPayment = value.option(_pharmacyPaymentFilterKey);
  final String? priority = value.option(_pharmacyPriorityFilterKey);
  final String? partialStock = value.option(_pharmacyStockFilterKey);
  final String? urgent = value.option(_pharmacyUrgentFilterKey);

  return current.copyWith(
    status: status,
    location: location,
    pendingPayment: pendingPayment == 'true' ? true : null,
    partialStock: partialStock == 'true' ? true : null,
    urgent: urgent == 'true' ? true : null,
    priority: priority,
    from: value.dateFrom,
    to: value.dateTo,
    pageRequest: current.pageRequest.first(),
    clearStatus: status == null,
    clearLocation: location == null,
    clearPendingPayment: pendingPayment != 'true',
    clearPartialStock: partialStock != 'true',
    clearUrgent: urgent != 'true',
    clearPriority: priority == null,
    clearFrom: value.dateFrom == null,
    clearTo: value.dateTo == null,
  );
}

List<AppSearchBarFilterChoice> _pharmacyStatusFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: 'ORDERED',
      label: l10n.pharmacyFilterReady,
      icon: Icons.medication_liquid_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'PARTIALLY_DISPENSED',
      label: l10n.pharmacyFilterPartial,
      icon: Icons.pending_actions_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'DISPENSED',
      label: l10n.pharmacyFilterCompleted,
      icon: Icons.done_all_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'CANCELLED',
      label: l10n.pharmacyFilterCancelled,
      icon: Icons.cancel_outlined,
    ),
  ];
}

List<AppSearchBarFilterChoice> _pharmacyLocationFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: 'OUTPATIENT',
      label: l10n.pharmacyFilterOutpatient,
      icon: Icons.person_outline,
    ),
    AppSearchBarFilterChoice(
      value: 'INPATIENT',
      label: l10n.pharmacyFilterWard,
      icon: Icons.bed_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'DISCHARGE',
      label: l10n.pharmacyFilterDischarge,
      icon: Icons.local_hospital_outlined,
    ),
  ];
}

List<AppSearchBarFilterChoice> _pharmacyPaymentFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: 'true',
      label: l10n.pharmacyFilterPendingPayment,
      icon: Icons.payments_outlined,
    ),
  ];
}

List<AppSearchBarFilterChoice> _pharmacyPriorityFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: 'STAT',
      label: l10n.pharmacyFilterUrgent,
      icon: Icons.priority_high,
    ),
    AppSearchBarFilterChoice(
      value: 'ROUTINE',
      label: l10n.pharmacyFilterReady,
      icon: Icons.schedule_outlined,
    ),
  ];
}

List<AppSearchBarFilterChoice> _pharmacyStockFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: 'true',
      label: l10n.pharmacyFilterPartialStock,
      icon: Icons.inventory_outlined,
    ),
  ];
}

List<AppSearchBarFilterChoice> _pharmacyUrgentFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: 'true',
      label: l10n.pharmacyFilterUrgent,
      icon: Icons.emergency_outlined,
    ),
  ];
}

const String _pharmacyDrugStockStatusFilterKey = 'stock_status';

AppSearchBarFilterValue _pharmacyDrugFilterValue(PharmacyDrugQuery query) {
  final String? stockStatus = query.stockStatus;
  if (stockStatus == null) {
    return AppSearchBarFilterValue.empty;
  }
  return AppSearchBarFilterValue(
    options: <String, String>{_pharmacyDrugStockStatusFilterKey: stockStatus},
  );
}

List<AppSearchBarFilterChoice> _stockStatusFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: 'IN_STOCK',
      label: l10n.pharmacyStockInStock,
      icon: Icons.check_circle_outline,
    ),
    AppSearchBarFilterChoice(
      value: 'ALMOST_OUT_OF_STOCK',
      label: l10n.pharmacyStockAlmostOut,
      icon: Icons.inventory_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'LOW_STOCK',
      label: l10n.pharmacyStockLow,
      icon: Icons.warning_amber_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'OUT_OF_STOCK',
      label: l10n.pharmacyStockOut,
      icon: Icons.remove_circle_outline,
    ),
  ];
}

List<AppWorkspacePatientContextField> _pharmacyDetailContextFields(
  BuildContext context,
  PharmacyOrder order,
) {
  final AppLocalizations l10n = context.l10n;
  final AppWorkspaceStatus status = _orderStatus(context, order);

  return <AppWorkspacePatientContextField>[
    AppWorkspacePatientContextField(
      label: l10n.clinicalRequestPatientNameLabel,
      value: order.displayTitle,
    ),
    if ((order.patientId ?? '').trim().isNotEmpty)
      AppWorkspacePatientContextField(
        label: l10n.opdPatientIdLabel,
        value: order.patientId!.trim(),
        copyable: true,
        copyTooltip: l10n.copyIdentifierAction,
        copiedMessage: l10n.identifierCopiedMessage,
      ),
    AppWorkspacePatientContextField(
      label: l10n.pharmacyStatusColumnLabel,
      value: status.label,
      tone: status.tone,
    ),
    if (order.hasPendingAttestation)
      AppWorkspacePatientContextField(
        label: l10n.pharmacyPendingBatchLabel,
        value: l10n.pharmacyReadinessAttestationRequired,
        tone: AppWorkspaceStatusTone.warning,
      ),
    AppWorkspacePatientContextField(
      label: l10n.pharmacyPaymentClearanceFieldLabel,
      value: order.hasBillingGate
          ? clinicalRequestPaymentStatusDisplayLabel(
              l10n,
              order.effectivePaymentStatus,
            )
          : l10n.pharmacyBillingGateUnavailableTitle,
      tone: order.hasBillingGate
          ? AppWorkspaceStatusTone.neutral
          : AppWorkspaceStatusTone.warning,
    ),
    AppWorkspacePatientContextField(
      label: l10n.pharmacyOrderFieldLabel,
      value: order.displayId ?? '',
      copyable: (order.displayId ?? '').isNotEmpty,
      copyTooltip: l10n.copyIdentifierAction,
      copiedMessage: l10n.identifierCopiedMessage,
    ),
    if ((order.encounterId ?? '').isNotEmpty)
      AppWorkspacePatientContextField(
        label: l10n.pharmacyEncounterFieldLabel,
        value: order.encounterId!,
        copyable: true,
        copyTooltip: l10n.opdCopyEncounterIdAction,
        copiedMessage: l10n.opdEncounterIdCopiedMessage,
      ),
    if (order.hasBillingGate)
      AppWorkspacePatientContextField(
        label: l10n.pharmacyPaymentLabel,
        value: clinicalRequestPaymentStatusDisplayLabel(
          l10n,
          order.effectivePaymentStatus,
        ),
      ),
    if (order.hasBillingGate && order.billingTotalAmount != null)
      AppWorkspacePatientContextField(
        label: l10n.pharmacyPaymentAmountLabel,
        value: clinicalRequestPriceLabel(
          context,
          order.billingTotalAmount!,
          order.billingCurrency,
        ),
      ),
    if ((order.orderSource ?? '').isNotEmpty)
      AppWorkspacePatientContextField(
        label: l10n.pharmacySourceFieldLabel,
        value: _apiLabel(order.orderSource ?? ''),
      ),
    if ((order.location ?? '').isNotEmpty)
      AppWorkspacePatientContextField(
        label: l10n.pharmacyLocationFieldLabel,
        value: order.isInpatientOrder
            ? l10n.pharmacyFilterWard
            : l10n.pharmacyFilterOutpatient,
      ),
    if ((order.priority ?? '').isNotEmpty)
      AppWorkspacePatientContextField(
        label: l10n.pharmacyPriorityFieldLabel,
        value: _apiLabel(order.priority ?? ''),
      ),
    AppWorkspacePatientContextField(
      label: l10n.pharmacyOrderedFieldLabel,
      value: _dateTimeLabel(context, order.orderedAt),
    ),
  ];
}

Future<void> _switchItemPriceSource(
  BuildContext context,
  WidgetRef ref,
  PharmacyOrder order,
  PharmacyOrderItem item,
  PharmacyItemPriceSource priceSource,
) async {
  final Map<String, Object?>? billing =
      buildPharmacyOrderBillingWithItemPriceSource(
        order: order,
        itemId: item.id,
        priceSource: priceSource,
      );
  if (billing == null || !context.mounted) {
    return;
  }

  final AppFailure? failure = await ref
      .read(pharmacyWorkspaceControllerProvider.notifier)
      .recordOrderBilling(billing);
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
    if (failure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pharmacySavedMessage)),
      );
    }
  }
}

AppWorkspaceStatus _orderStatus(BuildContext context, PharmacyOrder order) {
  final String value = order.status ?? '';
  return AppWorkspaceStatus(
    label: _apiLabel(value).isEmpty
        ? context.l10n.pharmacyUnknownStatusLabel
        : _apiLabel(value),
    tone: _orderStatusTone(value),
  );
}

AppWorkspaceStatus _stockStatus(BuildContext context, String? value) {
  final String normalized = value ?? '';
  return AppWorkspaceStatus(
    label: _apiLabel(normalized).isEmpty
        ? context.l10n.pharmacyStockUnknown
        : _apiLabel(normalized),
    tone: _stockStatusTone(normalized),
  );
}

AppWorkspaceStatusTone _orderStatusTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'ORDERED' => AppWorkspaceStatusTone.info,
    'PARTIALLY_DISPENSED' => AppWorkspaceStatusTone.warning,
    'DISPENSED' => AppWorkspaceStatusTone.success,
    'CANCELLED' => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatusTone _stockStatusTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'IN_STOCK' => AppWorkspaceStatusTone.success,
    'ALMOST_OUT_OF_STOCK' => AppWorkspaceStatusTone.warning,
    'LOW_STOCK' || 'OUT_OF_STOCK' => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

String _timelineLabel(BuildContext context, PharmacyTimelineItem item) {
  final String type = _apiLabel(item.type ?? '');
  final String? medication = item.labelParams['medication']?.toString();
  final String? status = item.labelParams['status']?.toString();
  final String? batch = item.labelParams['batch']?.toString();
  if ((medication ?? '').isNotEmpty) {
    return context.l10n.pharmacyTimelineMedicationEvent(
      medication!,
      _apiLabel(status ?? ''),
    );
  }
  if ((batch ?? '').isNotEmpty) {
    return context.l10n.pharmacyTimelineBatchEvent(type, batch!);
  }
  return type.isEmpty ? context.l10n.pharmacyTimelineOrderPlaced : type;
}

String _billingGateLabel(BuildContext context, PharmacyOrder order) {
  final AppLocalizations l10n = context.l10n;
  if (!order.hasBillingGate) {
    return l10n.pharmacyBillingGateUnavailableTitle;
  }
  return clinicalRequestPaymentStatusDisplayLabel(
    l10n,
    order.effectivePaymentStatus,
  );
}

String _dispenseProgressLabel(BuildContext context, PharmacyOrder order) {
  return context.l10n.pharmacyDispenseProgressLabel(
    _numberLabel(order.quantityDispensedTotal),
    _numberLabel(order.quantityPrescribedTotal),
  );
}

String _pageLabel<T>(BuildContext context, AppPage<T> page) {
  final int total = page.totalItemCount ?? page.items.length;
  if (total == 0) {
    return context.l10n.opdPageLabel(0, 0, 0);
  }
  final int from = page.request.pageIndex * page.request.pageSize + 1;
  final int to = (from + page.items.length - 1).clamp(from, total);
  return context.l10n.opdPageLabel(from, to, total);
}

String _dateTimeLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return '';
  }
  return AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String _apiLabel(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
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

String _numberLabel(num value) {
  if (value is int || value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

String _wholeNumber(num value) {
  return value.round().toString();
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

final List<TextInputFormatter> _integerFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
];
