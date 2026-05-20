import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';
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

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<PharmacyOrder>();
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
      compactSummaryCards: true,
      status: AppWorkspaceStatus(
        label: state.isSaving
            ? l10n.pharmacyStatusSaving
            : l10n.pharmacyStatusLiveSync,
        tone: state.isSaving
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
      ),
      secondaryActions: <Widget>[
        AppButton.secondary(
          label: l10n.pharmacyDrugPanelTitle,
          leadingIcon: Icons.inventory_2_outlined,
          onPressed: () {
            unawaited(_openFormularyStockDialog(context, state));
          },
        ),
        AppIconButton(
          icon: Icons.refresh,
          semanticLabel: l10n.commonRefreshActionLabel,
          tooltip: l10n.commonRefreshActionLabel,
          isLoading: state.isRefreshingOrders,
          onPressed: () async {
            final AppFailure? failure = await controller.refresh();
            if (context.mounted) {
              _showFailureIfNeeded(context, failure);
            }
          },
        ),
      ],
      summaryCards: <Widget>[
        AppWorkspaceSummaryCard(
          label: l10n.pharmacySummaryReadyLabel,
          value: _countLabel(context, state.workbench.summary.orderedQueue),
          icon: Icons.medication_liquid_outlined,
          tone: AppWorkspaceStatusTone.info,
          compact: true,
          onPressed: () => controller.applyFilter(PharmacyOrderFilter.ready),
        ),
        AppWorkspaceSummaryCard(
          label: l10n.pharmacySummaryPartialLabel,
          value: _countLabel(
            context,
            state.workbench.summary.partiallyDispensedQueue,
          ),
          icon: Icons.pending_actions_outlined,
          tone: AppWorkspaceStatusTone.warning,
          compact: true,
          onPressed: () => controller.applyFilter(PharmacyOrderFilter.partial),
        ),
        AppWorkspaceSummaryCard(
          label: l10n.pharmacySummaryAttestationLabel,
          value: _countLabel(
            context,
            state.workbench.summary.pendingAttestations,
          ),
          icon: Icons.verified_outlined,
          tone: AppWorkspaceStatusTone.warning,
          compact: true,
        ),
        AppWorkspaceSummaryCard(
          label: l10n.pharmacySummaryCompletedLabel,
          value: _countLabel(context, state.workbench.summary.dispensedOrders),
          icon: Icons.done_all_outlined,
          tone: AppWorkspaceStatusTone.success,
          compact: true,
          onPressed: () =>
              controller.applyFilter(PharmacyOrderFilter.completed),
        ),
      ],
      filters: AppWorkspaceFilterBar(
        semanticLabel: l10n.pharmacyFiltersSemanticLabel,
        expandSearch: true,
        search: AppSearchBar(
          controller: _searchController,
          semanticLabel: l10n.pharmacySearchLabel,
          hintText: l10n.pharmacySearchHint,
          onSubmitted: (String value) {
            controller.applySearch(value);
          },
          trailingActions: <AppSearchBarAction>[
            _tableColumnController.settingsAction(
              context,
              label: 'Table settings',
            ),
          ],
        ),
        filters: <Widget>[
          AppSelectField<PharmacyOrderFilter>(
            value: state.query.filter,
            labelText: l10n.pharmacyQueueFilterLabel,
            options: _orderFilterOptions(l10n),
            onChanged: (PharmacyOrderFilter? value) {
              if (value != null) {
                controller.applyFilter(value);
              }
            },
          ),
        ],
      ),
      body: _PharmacyQueuePanel(
        state: state,
        writeRequirement: _writeRequirement,
        columnVisibilityController: _tableColumnController,
      ),
    );
  }
}

class _PharmacyQueuePanel extends ConsumerWidget {
  const _PharmacyQueuePanel({
    required this.state,
    required this.writeRequirement,
    required this.columnVisibilityController,
  });

  final PharmacyWorkspaceState state;
  final AccessRequirement writeRequirement;
  final AppListTableColumnVisibilityController<PharmacyOrder>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.pharmacyQueuePanelTitle,
      description: l10n.pharmacyQueuePanelDescription,
      child: AppListTable<PharmacyOrder>(
        page: state.workbench.orders,
        isLoading: state.isRefreshingOrders,
        columnVisibilityController: columnVisibilityController,
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
        columns: <AppListTableColumn<PharmacyOrder>>[
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
                appListTableCompareText(
                  left.displayId ?? left.id,
                  right.displayId ?? right.id,
                ),
            cellBuilder: (BuildContext context, PharmacyOrder item) {
              return Text(item.displayId ?? item.id);
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
            label: l10n.pharmacyStatusColumnLabel,
            sortComparator: (PharmacyOrder left, PharmacyOrder right) =>
                appListTableCompareText(left.status, right.status),
            cellBuilder: (BuildContext context, PharmacyOrder item) {
              return AppWorkspaceStatusBadge(
                status: _orderStatus(context, item),
              );
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, PharmacyOrder item) {
          final ThemeData theme = Theme.of(context);
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.sm,
              vertical: theme.spacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _PharmacyOrderPatientCell(order: item),
                SizedBox(height: theme.spacing.sm),
                Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    AppWorkspaceStatusBadge(
                      status: _orderStatus(context, item),
                    ),
                    if (item.hasPendingAttestation)
                      AppWorkspaceStatusBadge(
                        status: AppWorkspaceStatus(
                          label: l10n.pharmacyPendingBatchLabel,
                          tone: AppWorkspaceStatusTone.warning,
                        ),
                      ),
                    Text(
                      _dispenseProgressLabel(context, item),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
          _joinDisplay(<String?>[
            order.patientId,
            order.encounterId,
            _dateTimeLabel(context, order.orderedAt),
          ]),
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
          patientName: order.displayTitle,
          patientNumber: order.patientId ?? order.displayId ?? order.id,
          status: _orderStatus(context, order),
          alerts: <AppWorkspaceStatus>[
            if (order.hasPendingAttestation)
              AppWorkspaceStatus(
                label: l10n.pharmacyPendingBatchLabel,
                tone: AppWorkspaceStatusTone.warning,
              ),
            AppWorkspaceStatus(
              label: l10n.pharmacyBillingGateUnavailableTitle,
              tone: AppWorkspaceStatusTone.info,
            ),
          ],
          fields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: l10n.pharmacyOrderFieldLabel,
              value: order.displayId ?? order.id,
              icon: Icons.tag_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.pharmacyEncounterFieldLabel,
              value: order.encounterId ?? '',
              icon: Icons.assignment_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.pharmacySourceFieldLabel,
              value: _apiLabel(order.orderSource ?? ''),
              icon: Icons.account_tree_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.pharmacyOrderedFieldLabel,
              value: _dateTimeLabel(context, order.orderedAt),
              icon: Icons.event_available_outlined,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        _PharmacyActionPanel(
          workflow: workflow,
          writeRequirement: writeRequirement,
        ),
        SizedBox(height: theme.spacing.md),
        _MedicationItemsPanel(workflow: workflow),
        SizedBox(height: theme.spacing.md),
        const _BillingGapPanel(),
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
      title: const Text('Prescription detail'),
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

Future<void> _openFormularyStockDialog(
  BuildContext context,
  PharmacyWorkspaceState state,
) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(context.l10n.pharmacyDrugPanelTitle),
      icon: const Icon(Icons.inventory_2_outlined),
      scrollable: true,
      maxWidth: 980,
      content: _DrugStockPanel(state: state),
    ),
  );
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
    final PharmacyOrder order = workflow.order;
    final bool canPrepare =
        workflow.nextActions.canPrepareDispense || order.canPrepareDispense;
    final bool canAttest =
        workflow.nextActions.canAttestDispense || order.canAttestDispense;
    final bool canCancel = workflow.nextActions.canCancel || order.canCancel;
    final bool canReturn = workflow.nextActions.canReturn || order.canReturn;

    return AppWorkspaceDetailPanel(
      title: l10n.pharmacyActionsPanelTitle,
      child: AppAccessActionGate(
        requirement: writeRequirement,
        builder: (BuildContext context, bool isAllowed) {
          return AppActionList(
            actions: <AppActionItem>[
              AppActionItem(
                label: l10n.pharmacyDispenseAction,
                leadingIcon: Icons.medication_liquid_outlined,
                enabled: isAllowed && canPrepare,
                onPressed: () => _openDispenseDialog(context, workflow),
              ),
              AppActionItem(
                label: l10n.pharmacyAttestAction,
                leadingIcon: Icons.verified_outlined,
                enabled: isAllowed && canAttest,
                onPressed: () => _openAttestDialog(context, workflow),
              ),
              AppActionItem(
                label: l10n.pharmacyReturnAction,
                leadingIcon: Icons.keyboard_return_outlined,
                enabled: isAllowed && canReturn,
                onPressed: () => _openReturnDialog(context, workflow),
              ),
              AppActionItem(
                label: l10n.pharmacyCancelOrderAction,
                leadingIcon: Icons.cancel_outlined,
                enabled: isAllowed && canCancel,
                onPressed: () => _openCancelDialog(context),
              ),
            ],
            extraActions: <Widget>[
              AppReportActionButton.print(
                label: l10n.pharmacyPrintInstructionsAction,
                variant: AppButtonVariant.secondary,
                onPressed: () async {
                  await printFormTemplateDocument(
                    ref: ref,
                    context: context,
                    title: l10n.pharmacyReportTitle,
                    subtitle: workflow.order.displayTitle,
                    metadata: <PrintFormMetadataItem>[
                      PrintFormMetadataItem(
                        label: l10n.pharmacyReportOrderLabel,
                        value: workflow.order.displayId ?? workflow.order.id,
                      ),
                      PrintFormMetadataItem(
                        label: l10n.claimsStatusColumnLabel,
                        value: _apiLabel(workflow.order.status ?? ''),
                      ),
                    ],
                    bodyHtml: _pharmacyInstructionsHtml(context, workflow),
                    footerNote: l10n.pharmacyReportFooter,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MedicationItemsPanel extends StatelessWidget {
  const _MedicationItemsPanel({required this.workflow});

  final PharmacyOrderWorkflow workflow;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppWorkspaceDetailPanel(
      title: l10n.pharmacyMedicationPanelTitle,
      description: l10n.pharmacyMedicationPanelDescription,
      child: AppListTable<PharmacyOrderItem>(
        items: workflow.items.isEmpty ? workflow.order.items : workflow.items,
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
              return _MedicationCell(item: item);
            },
          ),
          AppListTableColumn<PharmacyOrderItem>(
            label: l10n.pharmacyDoseColumnLabel,
            cellBuilder: (BuildContext context, PharmacyOrderItem item) {
              return Text(item.doseLine);
            },
          ),
          AppListTableColumn<PharmacyOrderItem>(
            label: l10n.pharmacyQuantityColumnLabel,
            cellBuilder: (BuildContext context, PharmacyOrderItem item) {
              return Text(item.quantityLine);
            },
          ),
          AppListTableColumn<PharmacyOrderItem>(
            label: l10n.pharmacyStockColumnLabel,
            cellBuilder: (BuildContext context, PharmacyOrderItem item) {
              return Text(_stockMappingLabel(context, item));
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
                Text(
                  _stockMappingLabel(context, item),
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

class _BillingGapPanel extends StatelessWidget {
  const _BillingGapPanel();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return AppWorkspaceDetailPanel(
      title: l10n.pharmacyBackendGapsTitle,
      description: l10n.pharmacyBackendGapsBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _GapLine(text: l10n.pharmacyGapPaymentAuthorization),
          SizedBox(height: theme.spacing.xs),
          _GapLine(text: l10n.pharmacyGapBatchAvailability),
          SizedBox(height: theme.spacing.xs),
          _GapLine(text: l10n.pharmacyGapHoldSubstitution),
          SizedBox(height: theme.spacing.xs),
          _GapLine(text: l10n.pharmacyGapReportTemplates),
        ],
      ),
    );
  }
}

class _GapLine extends StatelessWidget {
  const _GapLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          Icons.info_outline,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppWorkspaceFilterBar(
            semanticLabel: l10n.pharmacyDrugFiltersSemanticLabel,
            expandSearch: true,
            search: AppSearchBar(
              controller: _searchController,
              semanticLabel: l10n.pharmacyDrugSearchLabel,
              hintText: l10n.pharmacyDrugSearchHint,
              onSubmitted: controller.applyDrugSearch,
            ),
            filters: <Widget>[
              AppSelectField<String>(
                value: state.drugQuery.stockStatus,
                labelText: l10n.pharmacyStockStatusFilterLabel,
                options: _stockStatusOptions(l10n),
                onChanged: controller.applyDrugStockStatus,
              ),
            ],
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          AppListTable<PharmacyDrug>(
            page: state.drugs,
            isLoading: state.isRefreshingDrugs,
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
        ],
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
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        formStatus: _failure == null
            ? _FormInfo(text: l10n.pharmacyBillingGateUnavailableBody)
            : AppFailureStateView(failure: _failure!),
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
      content: AppFormShell(
        formKey: _formKey,
        formStatus: _failure == null
            ? _FormInfo(text: l10n.pharmacyAttestDialogBody)
            : AppFailureStateView(failure: _failure!),
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
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
    _notesController = TextEditingController();
    _lines = widget.workflow.items
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
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        formStatus: _failure == null
            ? _FormInfo(text: l10n.pharmacyReturnDialogBody)
            : AppFailureStateView(failure: _failure!),
        enabled: !_isSaving,
        children: <Widget>[
          AppTextField(
            controller: _reasonController,
            labelText: l10n.pharmacyReasonLabel,
            enabled: !_isSaving,
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.pharmacyNotesLabel,
            enabled: !_isSaving,
            maxLines: 3,
          ),
          for (final _LineEditState line in _lines)
            _LineEditTile(
              line: line,
              mode: _LineEditMode.returned,
              isSaving: _isSaving,
            ),
        ],
      ),
      actions: _dialogActions(
        context,
        l10n.pharmacyReturnAction,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final List<PharmacyReturnLineInput> selected = _lines
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
      content: AppFormShell(
        formKey: _formKey,
        formStatus: _failure == null
            ? _FormInfo(text: l10n.pharmacyCancelDialogBody)
            : AppFailureStateView(failure: _failure!),
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

class _FormInfo extends StatelessWidget {
  const _FormInfo({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Text(text, style: theme.textTheme.bodyMedium),
      ),
    );
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
  VoidCallback onSubmit,
) {
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

List<AppSelectOption<PharmacyOrderFilter>> _orderFilterOptions(
  AppLocalizations l10n,
) {
  return <AppSelectOption<PharmacyOrderFilter>>[
    AppSelectOption<PharmacyOrderFilter>(
      value: PharmacyOrderFilter.all,
      label: l10n.pharmacyFilterAll,
    ),
    AppSelectOption<PharmacyOrderFilter>(
      value: PharmacyOrderFilter.ready,
      label: l10n.pharmacyFilterReady,
    ),
    AppSelectOption<PharmacyOrderFilter>(
      value: PharmacyOrderFilter.partial,
      label: l10n.pharmacyFilterPartial,
    ),
    AppSelectOption<PharmacyOrderFilter>(
      value: PharmacyOrderFilter.completed,
      label: l10n.pharmacyFilterCompleted,
    ),
    AppSelectOption<PharmacyOrderFilter>(
      value: PharmacyOrderFilter.cancelled,
      label: l10n.pharmacyFilterCancelled,
    ),
    AppSelectOption<PharmacyOrderFilter>(
      value: PharmacyOrderFilter.pendingPayment,
      label: l10n.pharmacyFilterPendingPayment,
      enabled: false,
    ),
    AppSelectOption<PharmacyOrderFilter>(
      value: PharmacyOrderFilter.partialStock,
      label: l10n.pharmacyFilterPartialStock,
      enabled: false,
    ),
    AppSelectOption<PharmacyOrderFilter>(
      value: PharmacyOrderFilter.urgent,
      label: l10n.pharmacyFilterUrgent,
      enabled: false,
    ),
    AppSelectOption<PharmacyOrderFilter>(
      value: PharmacyOrderFilter.discharge,
      label: l10n.pharmacyFilterDischarge,
      enabled: false,
    ),
  ];
}

List<AppSelectOption<String>> _stockStatusOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: 'IN_STOCK',
      label: l10n.pharmacyStockInStock,
    ),
    AppSelectOption<String>(
      value: 'ALMOST_OUT_OF_STOCK',
      label: l10n.pharmacyStockAlmostOut,
    ),
    AppSelectOption<String>(value: 'LOW_STOCK', label: l10n.pharmacyStockLow),
    AppSelectOption<String>(
      value: 'OUT_OF_STOCK',
      label: l10n.pharmacyStockOut,
    ),
  ];
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

String _stockMappingLabel(BuildContext context, PharmacyOrderItem item) {
  final PharmacyStockMapping? mapping = item.defaultStockMapping;
  if (mapping == null) {
    return context.l10n.pharmacyStockMappingUnavailable;
  }
  return mapping.displayTitle;
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

String _dispenseProgressLabel(BuildContext context, PharmacyOrder order) {
  return context.l10n.pharmacyDispenseProgressLabel(
    _numberLabel(order.quantityDispensedTotal),
    _numberLabel(order.quantityPrescribedTotal),
  );
}

String _countLabel(BuildContext context, int value) {
  return AppFormatters.compactNumber(value, Localizations.localeOf(context));
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

String _pharmacyInstructionsHtml(
  BuildContext context,
  PharmacyOrderWorkflow workflow,
) {
  final AppLocalizations l10n = context.l10n;
  final PharmacyOrder order = workflow.order;
  final StringBuffer buffer = StringBuffer()
    ..write(
      PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
        PrintFormMetadataItem(
          label: l10n.pharmacyReportPatientLabel,
          value: order.displayTitle,
        ),
        PrintFormMetadataItem(
          label: l10n.pharmacyReportOrderLabel,
          value: order.displayId ?? order.id,
        ),
      ]),
    )
    ..write(
      PrintFormTemplate.section(
        title: l10n.pharmacyMedicationPanelTitle,
        bodyHtml: PrintFormTemplate.unorderedList(<String>[
          for (final PharmacyOrderItem item in workflow.items)
            _joinDisplay(<String?>[
              item.medicationLabel,
              item.doseLine,
              item.instructions,
            ]),
        ], emptyText: l10n.pharmacyNoMedicationBody),
      ),
    );
  return buffer.toString();
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
