import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/claims/data/repositories/insurance_catalog_repository.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_billing_helpers.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_catalog_dialog.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_instructions_print_helpers.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_order_item_pricing_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_resolve.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

class PharmacyWorkspacePage extends ConsumerWidget {
  const PharmacyWorkspacePage({this.initialQuery, super.key});

  final PharmacyWorkspaceQuery? initialQuery;

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
        return _PharmacyWorkspaceContent(
          state: data,
          initialQuery: initialQuery,
        );
      },
    );
  }
}

class _PharmacyWorkspaceContent extends ConsumerStatefulWidget {
  const _PharmacyWorkspaceContent({required this.state, this.initialQuery});

  final PharmacyWorkspaceState state;
  final PharmacyWorkspaceQuery? initialQuery;

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
  late PharmacyDeskSection _section;
  bool _handledSectionDeepLink = false;
  String? _appliedRouteSignature;

  @override
  void initState() {
    super.initState();
    _section =
        _sectionFromQuery(widget.initialQuery?.section ?? '') ??
        PharmacyDeskSection.queue;
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<PharmacyOrder>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _handleSectionDeepLink();
      await _ensureDefaultSectionFilter();
    });
    _scheduleRouteQuery(widget.initialQuery);
  }

  Future<void> _handleSectionDeepLink() async {
    if (_handledSectionDeepLink || !mounted) {
      return;
    }
    final String section =
        GoRouterState.of(
          context,
        ).uri.queryParameters['section']?.trim().toLowerCase() ??
        '';
    if (section == 'inventory' || section == 'stock') {
      _handledSectionDeepLink = true;
      // Defer dialog open so prepareCatalogTab does not run mid-build.
      await Future<void>.delayed(Duration.zero);
      if (!mounted) {
        return;
      }
      await openPharmacyCatalogDialog(
        context,
        ref,
        initialTab: PharmacyCatalogTab.inventory,
      );
      return;
    }
    final PharmacyDeskSection? parsed = _sectionFromQuery(section);
    if (parsed != null) {
      _handledSectionDeepLink = true;
      if (parsed != _section) {
        setState(() => _section = parsed);
      }
      final PharmacyWorkspaceController controller = ref.read(
        pharmacyWorkspaceControllerProvider.notifier,
      );
      await controller.applyFilter(_filterForSection(parsed));
    }
  }

  void _scheduleRouteQuery(PharmacyWorkspaceQuery? query) {
    if (query == null || !query.hasRouteTargeting) return;
    if (_appliedRouteSignature == query.signature) return;
    _appliedRouteSignature = query.signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_applyRouteQuery(query));
    });
  }

  Future<void> _applyRouteQuery(PharmacyWorkspaceQuery query) async {
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
    if (query.section.isNotEmpty) {
      final PharmacyDeskSection? parsed = _sectionFromQuery(query.section);
      if (parsed != null) {
        if (parsed != _section) {
          setState(() => _section = parsed);
        }
        // Skip if deep-link handler already synced this desk section.
        if (!_handledSectionDeepLink) {
          unawaited(controller.applyFilter(_filterForSection(parsed)));
        }
      }
    }
    if (query.search.isNotEmpty) {
      _searchController.text = query.search;
      unawaited(controller.applySearch(query.search));
    }
    if (query.encounterId.isNotEmpty || query.orderId.isNotEmpty) {
      final PharmacyOrder? order = _findOrderByQuery(query);
      if (order != null) {
        await _openPharmacyDetailDialog(
          context,
          ref,
          widget.state,
          order,
          _writeRequirement,
        );
      }
    }
  }

  /// Ensures the default Queue tab applies its server-side filter on landing.
  Future<void> _ensureDefaultSectionFilter() async {
    if (!mounted || _handledSectionDeepLink) {
      return;
    }
    final PharmacyWorkspaceQuery? query = widget.initialQuery;
    if (query != null &&
        query.section.isNotEmpty &&
        _sectionFromQuery(query.section) != null) {
      return;
    }
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
    await controller.applyFilter(_filterForSection(_section));
  }

  PharmacyOrder? _findOrderByQuery(PharmacyWorkspaceQuery query) {
    for (final PharmacyOrder order in widget.state.workbench.orders.items) {
      if (query.orderId.isNotEmpty &&
          (order.id == query.orderId || order.displayId == query.orderId)) {
        return order;
      }
      if (query.encounterId.isNotEmpty &&
          order.encounterId == query.encounterId) {
        return order;
      }
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant _PharmacyWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
    if (oldWidget.initialQuery?.signature != widget.initialQuery?.signature) {
      _scheduleRouteQuery(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableColumnController.dispose();
    super.dispose();
  }

  // ─── Tab-to-section mapping helpers ──────────────────────────────────

  void _updateUrlForSection(PharmacyDeskSection section) {
    if (!mounted) return;
    final String tab = _sectionToQueryValue(section);
    final String location = AppRoutes.pharmacy.location(
      queryParameters: <String, String>{if (tab.isNotEmpty) 'section': tab},
    );
    GoRouter.of(context).replace<void>(location);
  }

  static String _sectionToQueryValue(PharmacyDeskSection section) {
    return switch (section) {
      PharmacyDeskSection.queue => 'queue',
      PharmacyDeskSection.inProgress => 'in-progress',
      PharmacyDeskSection.pendingPayment => 'pending-payment',
      PharmacyDeskSection.completed => 'completed',
      PharmacyDeskSection.allOrders => 'all',
    };
  }

  static PharmacyDeskSection? _sectionFromQuery(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'queue':
      case 'ready':
      case 'dispense':
        return PharmacyDeskSection.queue;
      case 'in-progress':
      case 'partial':
      case 'in_progress':
        return PharmacyDeskSection.inProgress;
      case 'pending-payment':
      case 'payment':
      case 'pending_payment':
        return PharmacyDeskSection.pendingPayment;
      case 'completed':
      case 'dispensed':
        return PharmacyDeskSection.completed;
      case 'all':
      case 'all-orders':
        return PharmacyDeskSection.allOrders;
      default:
        return null;
    }
  }

  static PharmacyOrderFilter _filterForSection(PharmacyDeskSection section) {
    return switch (section) {
      PharmacyDeskSection.queue => PharmacyOrderFilter.ready,
      PharmacyDeskSection.inProgress => PharmacyOrderFilter.partial,
      PharmacyDeskSection.pendingPayment => PharmacyOrderFilter.pendingPayment,
      PharmacyDeskSection.completed => PharmacyOrderFilter.completed,
      PharmacyDeskSection.allOrders => PharmacyOrderFilter.all,
    };
  }

  static int _sectionCount(
    PharmacyWorkbenchSummary summary,
    PharmacyDeskSection section,
  ) {
    return switch (section) {
      PharmacyDeskSection.queue => summary.orderedQueue,
      PharmacyDeskSection.inProgress => summary.partiallyDispensedQueue,
      PharmacyDeskSection.pendingPayment => summary.pendingPaymentQueue,
      PharmacyDeskSection.completed => summary.dispensedOrders,
      PharmacyDeskSection.allOrders => summary.totalOrders,
    };
  }

  static AppTabCountTone _sectionCountTone(PharmacyDeskSection section) {
    return switch (section) {
      PharmacyDeskSection.queue ||
      PharmacyDeskSection.inProgress ||
      PharmacyDeskSection.pendingPayment => AppTabCountTone.warning,
      PharmacyDeskSection.completed ||
      PharmacyDeskSection.allOrders => AppTabCountTone.info,
    };
  }

  static IconData _sectionIcon(PharmacyDeskSection section) {
    return switch (section) {
      PharmacyDeskSection.queue => Icons.medication_liquid_outlined,
      PharmacyDeskSection.inProgress => Icons.pending_actions_outlined,
      PharmacyDeskSection.pendingPayment => Icons.payments_outlined,
      PharmacyDeskSection.completed => Icons.done_all_outlined,
      PharmacyDeskSection.allOrders => Icons.inventory_2_outlined,
    };
  }

  static String _sectionLabel(
    AppLocalizations l10n,
    PharmacyDeskSection section,
  ) {
    return switch (section) {
      PharmacyDeskSection.queue => l10n.pharmacySummaryReadyLabel,
      PharmacyDeskSection.inProgress => l10n.pharmacySummaryPartialLabel,
      PharmacyDeskSection.pendingPayment => l10n.pharmacyFilterPendingPayment,
      PharmacyDeskSection.completed => l10n.pharmacySummaryCompletedLabel,
      PharmacyDeskSection.allOrders => l10n.pharmacyFilterAll,
    };
  }

  Widget _catalogPrimaryAction(AppLocalizations l10n) {
    return AppTabToolbarPrimary(
      label: l10n.pharmacyCatalogPanelTitle,
      icon: Icons.inventory_2_outlined,
      onPressed: () => unawaited(openPharmacyCatalogDialog(context, ref)),
    );
  }

  // ─── End tab helpers ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyWorkspaceState state = widget.state;
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
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
                for (final PharmacyDeskSection section
                    in PharmacyDeskSection.values)
                  AppTabItem(
                    id: section.name,
                    icon: _sectionIcon(section),
                    label: _sectionLabel(l10n, section),
                    count: _sectionCount(state.workbench.summary, section),
                    countTone: _sectionCountTone(section),
                  ),
              ],
              selectedId: _section.name,
              onTabTapped: (String tabId) {
                for (final PharmacyDeskSection section
                    in PharmacyDeskSection.values) {
                  if (section.name == tabId) {
                    setState(() => _section = section);
                    _updateUrlForSection(section);
                    unawaited(
                      controller.applyFilter(_filterForSection(section)),
                    );
                    break;
                  }
                }
              },
              primaryAction: _catalogPrimaryAction(l10n),
            ),
            SizedBox(height: theme.spacing.sm),
            _PharmacyQueuePanel(
              state: state,
              section: _section,
              writeRequirement: _writeRequirement,
              searchController: _searchController,
              columnVisibilityController: _tableColumnController,
            ),
          ],
        ),
      ),
    );
  }
}

class _PharmacyQueuePanel extends ConsumerWidget {
  const _PharmacyQueuePanel({
    required this.state,
    required this.section,
    required this.writeRequirement,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final PharmacyWorkspaceState state;
  final PharmacyDeskSection section;
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
      columnVisibilityStorageKey: 'pharmacy_${section.name}',
      columnWidthStorageKey: 'pharmacy_cw_${section.name}',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      search: AppListTableSearch<PharmacyOrder>(
        controller: searchController,
        semanticLabel: l10n.pharmacySearchLabel,
        hintText: l10n.pharmacySearchHint,
        matcher: (PharmacyOrder item, String query) =>
            pharmacyOrderSearchMatcher(context, item, query),
        onSubmitted: controller.applySearch,
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.pharmacyQueueFilterLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
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
            key: _pharmacyLocationFilterKey,
            label: l10n.pharmacyLocationFieldLabel,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: _pharmacyLocationFilterChoices(l10n),
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
        hasActiveFilters: _pharmacyHasActiveAdvancedFilters(state.query),
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
      columns: _columnsForSection(
        context,
        section,
        state: state,
        writeRequirement: writeRequirement,
      ),
      columnChoices: _optionalPharmacyWorklistColumns(context),
      mobileItemBuilder: (BuildContext context, PharmacyOrder item) {
        final AppWorkspaceStatus status = _orderStatus(context, item);
        return AppListTableMobileItem(
          title: item.displayTitle,
          caption: item.displayId,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(label: status.label, icon: status.icon),
            AppListTableMobileMeta(
              label: _locationLabel(context, item),
              icon: Icons.location_on_outlined,
            ),
            AppListTableMobileMeta(
              label: _dispenseProgressLabel(context, item),
              icon: Icons.medication_outlined,
            ),
          ],
        );
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
        AppPatientDetails(
          patientName: order.displayTitle,
          patientNumber: (order.patientId ?? '').trim(),
          patientNumberLabel: l10n.opdPatientIdLabel,
          showAvatar: false,
          status: _orderStatus(context, order),
          copyPatientNumberTooltip: l10n.copyIdentifierAction,
          copyPatientNumberMessage: l10n.identifierCopiedMessage,
          expandedFields: _pharmacyDetailExpandedFields(context, order),
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
  final ClinicalRequestPayerContext? payerContext = await ref
      .read(insuranceCatalogRepositoryProvider)
      .resolvePayerContextForPatient(order.patientId);
  if (!context.mounted) {
    return;
  }
  final List<ClinicalRequestBillingLineItem> fallback =
      pharmacyOrderBillingLineItems(order)
          .map(
            (ClinicalRequestBillingLineItem item) => item.copyWith(
              catalogType: item.catalogType ?? 'DRUG',
              billingEntity:
                  item.billingEntity ?? item.priceSource ?? 'PHARMACY',
            ),
          )
          .toList(growable: false);
  final List<ClinicalRequestBillingLineItem> resolved =
      await resolveClinicalRequestBillingLineItems(
        context: context,
        catalogFallbackItems: fallback,
        billingEntity: 'PHARMACY',
        payerContext: payerContext,
      );
  if (!context.mounted) {
    return;
  }
  final ClinicalRequestBillingSubmit? billing =
      await showClinicalRequestBillingDialog(
        context: context,
        lineItems: resolved,
        initialPaymentStatus: clinicalRequestPaymentStatusFromValue(
          order.effectivePaymentStatus,
        ),
        initialPaidAmount: order.billing['paid_amount'] is num
            ? order.billing['paid_amount'] as num
            : num.tryParse(order.billing['paid_amount']?.toString() ?? ''),
        initialCurrency: order.billingCurrency,
        billingEntity: 'PHARMACY',
        payerContext: payerContext,
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
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = writeRequirement.isAllowed(policy);
    final bool canBill = policy.grants(AppPermissions.billingWrite);
    final bool canPrepare =
        workflow.nextActions.canPrepareDispense || order.canPrepareDispense;
    final bool canAttest =
        workflow.nextActions.canAttestDispense || order.canAttestDispense;
    final bool canCancel = workflow.nextActions.canCancel || order.canCancel;
    final bool canReturn = workflow.nextActions.canReturn || order.canReturn;
    final bool paymentBlocksDispense =
        order.requiresPaymentBeforeDispense && canPrepare;

    // Only eligible, authorized writes — no disabled no-op chrome.
    // Print stays outside the write gate so browse/print remains available.
    final List<AppActionItem> actions = <AppActionItem>[
      if (order.requiresPaymentBeforeDispense && canBill)
        AppActionItem(
          label: l10n.pharmacyRecordPaymentAction,
          leadingIcon: Icons.payments_outlined,
          onPressed: () => _openRecordPaymentDialog(context, ref, order),
        ),
      if (canWrite && canPrepare && !paymentBlocksDispense)
        AppActionItem(
          label: l10n.pharmacyDispenseAction,
          leadingIcon: Icons.medication_liquid_outlined,
          onPressed: () => _openDispenseDialog(context, workflow),
        ),
      if (canWrite && canAttest)
        AppActionItem(
          label: l10n.pharmacyAttestAction,
          leadingIcon: Icons.verified_outlined,
          onPressed: () => _openAttestDialog(context, workflow),
        ),
      if (canWrite && canReturn)
        AppActionItem(
          label: l10n.pharmacyReturnAction,
          leadingIcon: Icons.keyboard_return_outlined,
          onPressed: () => _openReturnDialog(context, workflow),
        ),
      if (canWrite && canCancel)
        AppActionItem(
          label: l10n.pharmacyCancelOrderAction,
          leadingIcon: Icons.cancel_outlined,
          onPressed: () => _openCancelDialog(context),
        ),
    ];

    return AppQuickActions(
      title: l10n.pharmacyActionsPanelTitle,
      presentation: AppQuickActionsPresentation.detailPanel,
      leadingIcon: Icons.touch_app_outlined,
      spacing: theme.spacing.xs,
      runSpacing: theme.spacing.xs,
      actions: actions,
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
    );
  }
}

class _MedicationItemsPanel extends ConsumerStatefulWidget {
  const _MedicationItemsPanel({
    required this.workflow,
    required this.writeRequirement,
  });

  final PharmacyOrderWorkflow workflow;
  final AccessRequirement writeRequirement;

  @override
  ConsumerState<_MedicationItemsPanel> createState() =>
      _MedicationItemsPanelState();
}

class _MedicationItemsPanelState extends ConsumerState<_MedicationItemsPanel> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<PharmacyOrderItem>
  _columnVisibilityController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _columnVisibilityController =
        AppListTableColumnVisibilityController<PharmacyOrderItem>();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyOrderWorkflow workflow = widget.workflow;
    final PharmacyOrder order = workflow.order;
    final List<PharmacyOrderItem> items = workflow.items.isEmpty
        ? workflow.order.items
        : workflow.items;

    return AppWorkspaceDetailPanel(
      child: AppListTable<PharmacyOrderItem>(
        items: items,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        columnVisibilityController: _columnVisibilityController,
        columnVisibilityStorageKey: 'pharmacy_order_items',
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        columnVisibilityTitle: l10n.commonTableSettingsTitle,
        search: AppListTableSearch<PharmacyOrderItem>(
          controller: _searchController,
          semanticLabel: l10n.pharmacyMedicationColumnLabel,
          hintText: l10n.pharmacySearchHint,
          matcher: (PharmacyOrderItem item, String query) =>
              _medicationItemSearchMatcher(context, order, item, query),
        ),
        emptyBuilder: (_) => AppWorkspaceStatePanel.state(
          variant: AppStateViewVariant.empty,
          title: l10n.pharmacyNoMedicationTitle,
          body: l10n.pharmacyNoMedicationBody,
          icon: Icons.medication_outlined,
          minHeight: 180,
        ),
        columns: <AppListTableColumn<PharmacyOrderItem>>[
          AppListTableColumn<PharmacyOrderItem>(
            id: 'medication',
            label: l10n.pharmacyMedicationColumnLabel,
            cellBuilder: (BuildContext context, PharmacyOrderItem item) {
              return Align(
                alignment: Alignment.topLeft,
                child: _MedicationCell(item: item),
              );
            },
          ),
          AppListTableColumn<PharmacyOrderItem>(
            id: 'dose',
            label: l10n.pharmacyDoseColumnLabel,
            cellBuilder: (BuildContext context, PharmacyOrderItem item) {
              return Align(
                alignment: Alignment.topLeft,
                child: Text(item.doseLine),
              );
            },
          ),
          AppListTableColumn<PharmacyOrderItem>(
            id: 'quantity',
            label: l10n.pharmacyQuantityColumnLabel,
            cellBuilder: (BuildContext context, PharmacyOrderItem item) {
              return Align(
                alignment: Alignment.topLeft,
                child: Text(item.quantityLine),
              );
            },
          ),
          AppListTableColumn<PharmacyOrderItem>(
            id: 'line_price',
            label: l10n.pharmacyLinePriceColumnLabel,
            cellBuilder: (BuildContext context, PharmacyOrderItem item) {
              return Align(
                alignment: Alignment.topLeft,
                child: _MedicationPriceCell(order: order, item: item),
              );
            },
          ),
          AppListTableColumn<PharmacyOrderItem>(
            id: 'line_action',
            label: l10n.pharmacyLineActionsColumnLabel,
            alwaysVisible: true,
            cellBuilder: (BuildContext context, PharmacyOrderItem item) {
              return Align(
                alignment: Alignment.topLeft,
                child: _MedicationPrimaryLineAction(
                  workflow: workflow,
                  item: item,
                  writeRequirement: widget.writeRequirement,
                ),
              );
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, PharmacyOrderItem item) {
          final ThemeData theme = Theme.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppListTableMobileItem(
                title: item.medicationLabel,
                caption: (item.instructions ?? '').trim().isNotEmpty
                    ? item.instructions!.trim()
                    : null,
                meta: <AppListTableMobileMeta>[
                  AppListTableMobileMeta(label: item.doseLine),
                  AppListTableMobileMeta(label: item.quantityLine),
                ],
                showAvatar: false,
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: theme.spacing.sm,
                  right: theme.spacing.sm,
                  bottom: theme.spacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _MedicationPriceCell(order: order, item: item),
                    SizedBox(height: theme.spacing.xs),
                    _MedicationPrimaryLineAction(
                      workflow: workflow,
                      item: item,
                      writeRequirement: widget.writeRequirement,
                    ),
                  ],
                ),
              ),
            ],
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

class _ReturnLineMedicationCell extends StatelessWidget {
  const _ReturnLineMedicationCell({required this.item});

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
        if (item.doseLine.trim().isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            item.doseLine,
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

class _MedicationPrimaryLineAction extends ConsumerWidget {
  const _MedicationPrimaryLineAction({
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
    final bool canWrite = writeRequirement.isAllowed(
      ref.watch(appAccessPolicyProvider),
    );

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
      if (!canWrite) {
        return const SizedBox.shrink();
      }
      return AppButton.tertiary(
        label: l10n.pharmacyMapStockAction,
        leadingIcon: Icons.inventory_2_outlined,
        onPressed: () => openPharmacyCatalogDialog(context, ref),
      );
    }

    final PharmacyItemPriceSource activeSource = resolvePharmacyItemPriceSource(
      order: order,
      item: item,
    );
    if (pharmacyItemHasSelectablePrices(item) && canWrite) {
      if (activeSource != PharmacyItemPriceSource.pharmacy) {
        return AppButton.tertiary(
          label: l10n.pharmacyUsePharmacyPriceAction,
          leadingIcon: Icons.local_pharmacy_outlined,
          onPressed: () => _switchItemPriceSource(
            context,
            ref,
            order,
            item,
            PharmacyItemPriceSource.pharmacy,
          ),
        );
      }
      if (activeSource != PharmacyItemPriceSource.facility) {
        return AppButton.tertiary(
          label: l10n.pharmacyUseFacilityPriceAction,
          leadingIcon: Icons.account_balance_outlined,
          onPressed: () => _switchItemPriceSource(
            context,
            ref,
            order,
            item,
            PharmacyItemPriceSource.facility,
          ),
        );
      }
    }

    return const SizedBox.shrink();
  }
}

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({required this.workflow});

  final PharmacyOrderWorkflow workflow;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppWorkspaceDetailPanel(
      title: l10n.pharmacyTimelinePanelTitle,
      description: l10n.pharmacyTimelinePanelDescription,
      child: AppTimeline(
        emptyTitle: l10n.pharmacyNoTimelineBody,
        emptyBody: '',
        items: <AppTimelineItem>[
          for (final PharmacyTimelineItem item in workflow.timeline)
            AppTimelineItem(
              title: _timelineLabel(context, item),
              occurredAt: item.at,
              icon: Icons.local_pharmacy_outlined,
            ),
        ],
      ),
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
const String _returnTableQuantityColumnKey = 'quantity';
const String _returnTableReturnQuantityColumnKey = 'return_quantity';
const String _returnTableEditLineColumnKey = 'edit_line';

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

    // Search omitted: return dialog lines are typically short (≤8 rows).
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: AppListTable<_LineEditState>(
        items: lines,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppListTableMobileItem(
                leading: Checkbox(
                  value: selectedLineIds.contains(line.item.id),
                  onChanged: isSaving
                      ? null
                      : (bool? value) =>
                            _toggleLine(line.item.id, value ?? false),
                  visualDensity: VisualDensity.compact,
                ),
                title: line.item.medicationLabel,
                meta: <AppListTableMobileMeta>[
                  AppListTableMobileMeta(label: line.item.quantityLine),
                  AppListTableMobileMeta(
                    label:
                        '${l10n.pharmacyReturnQuantityColumnLabel}: ${_returnQuantityLabel(line)}',
                  ),
                ],
                showAvatar: false,
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: theme.spacing.sm,
                  right: theme.spacing.sm,
                  bottom: theme.spacing.sm,
                ),
                child: AppButton.tertiary(
                  label: l10n.pharmacyReturnEditLineAction,
                  leadingIcon: AppActionIcons.edit,
                  enabled: !isSaving,
                  onPressed: () => onEditLine(line),
                ),
              ),
            ],
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
            child: _ReturnLineMedicationCell(item: line.item),
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
        id: _returnTableEditLineColumnKey,
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

const String _pharmacyLocationFilterKey = 'location';
const String _pharmacyPriorityFilterKey = 'priority';
const String _pharmacyStockFilterKey = 'partial_stock';
const String _pharmacyUrgentFilterKey = 'urgent';

List<AppListTableColumn<PharmacyOrder>> _columnsForSection(
  BuildContext context,
  PharmacyDeskSection section, {
  required PharmacyWorkspaceState state,
  required AccessRequirement writeRequirement,
}) {
  return switch (section) {
    PharmacyDeskSection.pendingPayment => <AppListTableColumn<PharmacyOrder>>[
      _pharmacyPatientColumn(context),
      _pharmacyBillingColumn(context),
      _pharmacyOrderedAtColumn(context),
      _pharmacyStatusColumn(context),
      _pharmacyNextActionColumn(
        context,
        state: state,
        writeRequirement: writeRequirement,
      ),
    ],
    PharmacyDeskSection.allOrders => <AppListTableColumn<PharmacyOrder>>[
      _pharmacyPatientColumn(context),
      _pharmacyLocationColumn(context),
      _pharmacyItemsColumn(context),
      _pharmacyStatusColumn(context),
      _pharmacyNextActionColumn(
        context,
        state: state,
        writeRequirement: writeRequirement,
      ),
    ],
    PharmacyDeskSection.queue ||
    PharmacyDeskSection.inProgress ||
    PharmacyDeskSection.completed => <AppListTableColumn<PharmacyOrder>>[
      _pharmacyPatientColumn(context),
      _pharmacyLocationColumn(context),
      _pharmacyDispenseProgressColumn(context),
      _pharmacyStatusColumn(context),
      _pharmacyNextActionColumn(
        context,
        state: state,
        writeRequirement: writeRequirement,
      ),
    ],
  };
}

AppListTableColumn<PharmacyOrder> _pharmacyPatientColumn(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<PharmacyOrder>(
    id: 'patient',
    label: l10n.pharmacyPatientColumnLabel,
    sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
        appListTableCompareText(left.displayTitle, right.displayTitle),
    cellBuilder: (BuildContext context, PharmacyOrder item) {
      return AppListItemText(
        title: item.displayTitle,
        subtitle: item.displayId,
      );
    },
  );
}

AppListTableColumn<PharmacyOrder> _pharmacyLocationColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<PharmacyOrder>(
    id: 'location',
    label: l10n.pharmacyLocationFieldLabel,
    sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
        appListTableCompareText(
          _locationLabel(context, left),
          _locationLabel(context, right),
        ),
    cellBuilder: (BuildContext context, PharmacyOrder item) {
      return Text(_locationLabel(context, item));
    },
  );
}

AppListTableColumn<PharmacyOrder> _pharmacyDispenseProgressColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<PharmacyOrder>(
    id: 'dispense_progress',
    label: l10n.pharmacyDispenseColumnLabel,
    sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
        appListTableCompareNumber(
          left.quantityDispensedTotal,
          right.quantityDispensedTotal,
        ),
    cellBuilder: (BuildContext context, PharmacyOrder item) {
      return Text(_dispenseProgressLabel(context, item));
    },
  );
}

AppListTableColumn<PharmacyOrder> _pharmacyItemsColumn(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<PharmacyOrder>(
    id: 'items',
    label: l10n.pharmacyItemsColumnLabel,
    numeric: true,
    sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
        appListTableCompareNumber(left.itemCount, right.itemCount),
    cellBuilder: (BuildContext context, PharmacyOrder item) {
      return Text(_numberLabel(item.itemCount));
    },
  );
}

AppListTableColumn<PharmacyOrder> _pharmacyBillingColumn(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<PharmacyOrder>(
    id: 'billing',
    label: l10n.pharmacyPaymentColumnLabel,
    sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
        appListTableCompareText(
          left.effectivePaymentStatus,
          right.effectivePaymentStatus,
        ),
    cellBuilder: (BuildContext context, PharmacyOrder item) {
      return Text(_billingGateLabel(context, item));
    },
  );
}

AppListTableColumn<PharmacyOrder> _pharmacyOrderedAtColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<PharmacyOrder>(
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
  );
}

AppListTableColumn<PharmacyOrder> _pharmacyStatusColumn(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<PharmacyOrder>(
    id: 'status',
    label: l10n.pharmacyStatusColumnLabel,
    sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
        appListTableCompareText(left.status, right.status),
    cellBuilder: (BuildContext context, PharmacyOrder item) {
      return AppWorkspaceStatusBadge(status: _orderStatus(context, item));
    },
  );
}

AppListTableColumn<PharmacyOrder> _pharmacyNextActionColumn(
  BuildContext context, {
  required PharmacyWorkspaceState state,
  required AccessRequirement writeRequirement,
}) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<PharmacyOrder>(
    id: 'next_action',
    label: l10n.pharmacyNextActionColumnLabel,
    alwaysVisible: true,
    sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
        appListTableCompareText(
          pharmacyOrderNextActionLabel(context, left),
          pharmacyOrderNextActionLabel(context, right),
        ),
    cellBuilder: (BuildContext context, PharmacyOrder item) {
      return _PharmacyOrderNextActionButton(
        order: item,
        state: state,
        writeRequirement: writeRequirement,
      );
    },
  );
}

enum _PharmacyResolvedAction {
  recordPayment,
  attest,
  dispense,
  returnItems,
  cancel,
  confirmBilling,
  viewDetails,
}

String pharmacyOrderNextActionLabel(BuildContext context, PharmacyOrder order) {
  final AppLocalizations l10n = context.l10n;
  return switch (_resolvePharmacyNextAction(order)) {
    _PharmacyResolvedAction.recordPayment => l10n.pharmacyRecordPaymentAction,
    _PharmacyResolvedAction.attest => l10n.pharmacyAttestAction,
    _PharmacyResolvedAction.dispense => l10n.pharmacyDispenseAction,
    _PharmacyResolvedAction.returnItems => l10n.pharmacyReturnAction,
    _PharmacyResolvedAction.cancel => l10n.pharmacyCancelOrderAction,
    _PharmacyResolvedAction.confirmBilling =>
      l10n.pharmacyNextActionConfirmBilling,
    _PharmacyResolvedAction.viewDetails => l10n.housekeepingNextActionView,
  };
}

_PharmacyResolvedAction _resolvePharmacyNextAction(PharmacyOrder order) {
  final bool paymentBlocksDispense =
      order.requiresPaymentBeforeDispense && order.canPrepareDispense;

  if (order.requiresPaymentBeforeDispense) {
    return _PharmacyResolvedAction.recordPayment;
  }
  if (order.canAttestDispense) {
    return _PharmacyResolvedAction.attest;
  }
  if (order.canPrepareDispense && !paymentBlocksDispense) {
    return _PharmacyResolvedAction.dispense;
  }
  if (order.canReturn) {
    return _PharmacyResolvedAction.returnItems;
  }
  if (order.canCancel) {
    return _PharmacyResolvedAction.cancel;
  }
  if (!order.hasBillingGate) {
    return _PharmacyResolvedAction.confirmBilling;
  }
  return _PharmacyResolvedAction.viewDetails;
}

class _PharmacyOrderNextActionButton extends ConsumerWidget {
  const _PharmacyOrderNextActionButton({
    required this.order,
    required this.state,
    required this.writeRequirement,
  });

  final PharmacyOrder order;
  final PharmacyWorkspaceState state;
  final AccessRequirement writeRequirement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _PharmacyResolvedAction action = _resolvePharmacyNextAction(order);
    final String label = pharmacyOrderNextActionLabel(context, order);
    final bool requiresBillingWrite =
        action == _PharmacyResolvedAction.recordPayment ||
        action == _PharmacyResolvedAction.confirmBilling;
    final bool canBill = ref
        .watch(appAccessPolicyProvider)
        .grants(AppPermissions.billingWrite);
    final bool requiresWrite = action != _PharmacyResolvedAction.viewDetails;

    return AppAccessActionGate(
      requirement: writeRequirement,
      hideWhenDenied: requiresWrite,
      builder: (BuildContext context, bool isAllowed) {
        final bool enabled =
            (!requiresWrite || isAllowed) && (!requiresBillingWrite || canBill);
        if (!enabled) {
          return const SizedBox.shrink();
        }
        return AppButton.tertiary(
          label: label,
          onPressed: () => unawaited(_handlePressed(context, ref, action)),
        );
      },
    );
  }

  Future<void> _handlePressed(
    BuildContext context,
    WidgetRef ref,
    _PharmacyResolvedAction action,
  ) async {
    switch (action) {
      case _PharmacyResolvedAction.recordPayment:
      case _PharmacyResolvedAction.confirmBilling:
        await _openRecordPaymentDialog(context, ref, order);
      case _PharmacyResolvedAction.attest:
        await _ensureWorkflowAnd(
          context,
          ref,
          order,
          (PharmacyOrderWorkflow workflow) =>
              _openAttestDialog(context, workflow),
        );
      case _PharmacyResolvedAction.dispense:
        await _ensureWorkflowAnd(
          context,
          ref,
          order,
          (PharmacyOrderWorkflow workflow) =>
              _openDispenseDialog(context, workflow),
        );
      case _PharmacyResolvedAction.returnItems:
        await _ensureWorkflowAnd(
          context,
          ref,
          order,
          (PharmacyOrderWorkflow workflow) =>
              _openReturnDialog(context, workflow),
        );
      case _PharmacyResolvedAction.cancel:
        await _ensureWorkflowAnd(
          context,
          ref,
          order,
          (_) => _openCancelDialog(context),
        );
      case _PharmacyResolvedAction.viewDetails:
        await _openPharmacyDetailDialog(
          context,
          ref,
          state,
          order,
          writeRequirement,
        );
    }
  }
}

Future<void> _ensureWorkflowAnd(
  BuildContext context,
  WidgetRef ref,
  PharmacyOrder order,
  Future<void> Function(PharmacyOrderWorkflow workflow) action,
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
  final PharmacyOrderWorkflow? workflow = _readPharmacyState(
    ref,
  )?.selectedWorkflow;
  if (workflow == null) {
    return;
  }
  await action(workflow);
}

bool pharmacyOrderSearchMatcher(
  BuildContext context,
  PharmacyOrder order,
  String query,
) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }

  final AppLocalizations l10n = context.l10n;
  final Iterable<String?> values = <String?>[
    order.displayTitle,
    order.displayId,
    order.patientId,
    order.encounterId,
    order.status,
    order.location,
    order.priority,
    order.prescriberDisplayName,
    order.orderSource,
    order.effectivePaymentStatus,
    order.firstPendingBatchRef,
    _locationLabel(context, order),
    _priorityLabel(context, order),
    _orderSourceLabel(context, order),
    _billingGateLabel(context, order),
    _dispenseProgressLabel(context, order),
    _orderStatus(context, order).label,
    pharmacyOrderNextActionLabel(context, order),
    clinicalRequestPaymentStatusDisplayLabel(
      l10n,
      order.effectivePaymentStatus,
    ),
    _dateTimeLabel(context, order.orderedAt),
    _numberLabel(order.itemCount),
    _numberLabel(order.quantityDispensedTotal),
    _numberLabel(order.quantityPrescribedTotal),
    _numberLabel(order.quantityRemainingTotal),
    order.hasPendingAttestation ? l10n.pharmacyPendingBatchLabel : null,
  ];

  return values
      .whereType<String>()
      .map((String value) => value.toLowerCase())
      .any((String value) => value.contains(needle));
}

bool _medicationItemSearchMatcher(
  BuildContext context,
  PharmacyOrder order,
  PharmacyOrderItem item,
  String query,
) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }

  final num? unitPrice = resolvePharmacyItemUnitPrice(order: order, item: item);
  final String? currency = resolvePharmacyItemCurrency(
    order: order,
    item: item,
  );
  final String? priceText = unitPrice == null || unitPrice <= 0
      ? null
      : clinicalRequestPriceLabel(context, unitPrice, currency);

  return <String?>[
    item.medicationLabel,
    item.instructions,
    item.doseLine,
    item.quantityLine,
    priceText,
  ].whereType<String>().any(
    (String value) => value.toLowerCase().contains(needle),
  );
}

List<AppListTableColumn<PharmacyOrder>> _optionalPharmacyWorklistColumns(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppListTableColumn<PharmacyOrder>>[
    AppListTableColumn<PharmacyOrder>(
      id: 'order',
      label: l10n.pharmacyOrderColumnLabel,
      sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
          appListTableCompareText(left.displayId, right.displayId),
      cellBuilder: (BuildContext context, PharmacyOrder item) {
        return Text(item.displayId ?? '');
      },
    ),
    _pharmacyItemsColumn(context),
    _pharmacyDispenseProgressColumn(context),
    _pharmacyBillingColumn(context),
    _pharmacyOrderedAtColumn(context),
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
  // Queue status / pending payment stay with the tab strip — advanced filters
  // must not restate them.
  final Map<String, String> options = <String, String>{};
  if (query.location != null) {
    options[_pharmacyLocationFilterKey] = query.location!;
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

bool _pharmacyHasActiveAdvancedFilters(PharmacyWorkbenchQuery query) {
  return query.location != null ||
      query.partialStock == true ||
      query.urgent == true ||
      query.priority != null ||
      query.from != null ||
      query.to != null;
}

PharmacyWorkbenchQuery _pharmacyQueryFromFilterValue(
  PharmacyWorkbenchQuery current,
  AppSearchBarFilterValue value,
) {
  final String? location = value.option(_pharmacyLocationFilterKey);
  final String? priority = value.option(_pharmacyPriorityFilterKey);
  final String? partialStock = value.option(_pharmacyStockFilterKey);
  final String? urgent = value.option(_pharmacyUrgentFilterKey);

  return current.copyWith(
    location: location,
    partialStock: partialStock == 'true' ? true : null,
    urgent: urgent == 'true' ? true : null,
    priority: priority,
    from: value.dateFrom,
    to: value.dateTo,
    pageRequest: current.pageRequest.first(),
    clearLocation: location == null,
    clearPartialStock: partialStock != 'true',
    clearUrgent: urgent != 'true',
    clearPriority: priority == null,
    clearFrom: value.dateFrom == null,
    clearTo: value.dateTo == null,
  );
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

List<AppWorkspacePatientContextField> _pharmacyDetailExpandedFields(
  BuildContext context,
  PharmacyOrder order,
) {
  final AppLocalizations l10n = context.l10n;

  return <AppWorkspacePatientContextField>[
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

AppWorkspaceStatusTone _orderStatusTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'ORDERED' => AppWorkspaceStatusTone.info,
    'PARTIALLY_DISPENSED' => AppWorkspaceStatusTone.warning,
    'DISPENSED' => AppWorkspaceStatusTone.success,
    'CANCELLED' => AppWorkspaceStatusTone.error,
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
  showAppFailureSnackBar(context, failure);
}

final List<TextInputFormatter> _integerFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
];
