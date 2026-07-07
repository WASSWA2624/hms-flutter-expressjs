import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';

const AccessRequirement clinicalEncounterWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.systemAdmin,
  ],
  activeModules: <String>['encounters-vitals'],
);

typedef ClinicalOrderAction = Future<void> Function(
  BuildContext context,
  ClinicalRelatedRecord order,
);

List<ClinicalRelatedRecord> sortClinicalRecordsNewestFirst(
  List<ClinicalRelatedRecord> records,
) {
  final List<ClinicalRelatedRecord> sorted =
      List<ClinicalRelatedRecord>.from(records);
  sorted.sort((ClinicalRelatedRecord left, ClinicalRelatedRecord right) {
    final DateTime leftAt =
        left.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final DateTime rightAt =
        right.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return rightAt.compareTo(leftAt);
  });
  return sorted;
}

class ClinicalWorkflowProgressStrip extends StatelessWidget {
  const ClinicalWorkflowProgressStrip({
    required this.handoff,
    super.key,
  });

  final ClinicalTriageHandoff handoff;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String currentStage = handoff.stage ?? '';
    final String nextStep = handoff.nextStep ?? '';
    final List<String> stages = handoff.timeline.isNotEmpty
        ? handoff.timeline
            .map(
              (ClinicalWorkflowTimelineItem item) =>
                  item.stage ?? item.action,
            )
            .where((String value) => value.trim().isNotEmpty)
            .toList(growable: false)
        : opdWorkflowStagesAround(currentStage);
    final int currentIndex = handoff.timeline.isNotEmpty
        ? stages.length - 1
        : opdFlowStageIndex(currentStage);

    if (currentStage.isEmpty && nextStep.isEmpty && stages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (currentStage.isNotEmpty) ...<Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(theme.radius.sm),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.md),
              child: Row(
                children: <Widget>[
                  Icon(Icons.flag_circle_outlined, color: colorScheme.primary),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.clinicalCurrentStageLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          opdStageDisplayLabel(l10n, currentStage),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: theme.spacing.md),
        ],
        if (stages.isNotEmpty) ...<Widget>[
          Text(
            l10n.clinicalWorkflowProgressLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: theme.spacing.sm),
          _ClinicalWorkflowStepper(
            stages: stages,
            currentIndex: currentIndex.clamp(0, stages.length - 1),
          ),
          SizedBox(height: theme.spacing.md),
        ],
        if (nextStep.isNotEmpty)
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(theme.radius.sm),
              border: Border.all(
                color: colorScheme.secondary.withValues(alpha: 0.35),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.md),
              child: Row(
                children: <Widget>[
                  Icon(Icons.trending_flat, color: colorScheme.secondary),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.opdNextStepColumnLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          opdNextStepDisplayLabel(l10n, nextStep),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ClinicalLabOrdersTablePanel extends ConsumerStatefulWidget {
  const ClinicalLabOrdersTablePanel({
    required this.orders,
    required this.onEdit,
    required this.onCancel,
    required this.onDelete,
    super.key,
  });

  final List<ClinicalRelatedRecord> orders;
  final ClinicalOrderAction onEdit;
  final ClinicalOrderAction onCancel;
  final ClinicalOrderAction onDelete;

  @override
  ConsumerState<ClinicalLabOrdersTablePanel> createState() =>
      _ClinicalLabOrdersTablePanelState();
}

class _ClinicalLabOrdersTablePanelState
    extends ConsumerState<ClinicalLabOrdersTablePanel> {
  final Set<String> _expandedOrderIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<ClinicalRelatedRecord> orders = sortClinicalRecordsNewestFirst(
      widget.orders,
    );
    if (orders.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppWorkspaceDetailPanel(
      title: l10n.clinicalLabOrdersTitle,
      description: l10n.clinicalLabOrdersBody,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 480;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final ClinicalRelatedRecord order in orders)
                _ClinicalLabOrderGroup(
                  order: order,
                  compact: compact,
                  expanded: _expandedOrderIds.contains(order.id),
                  onToggleExpanded: () {
                    setState(() {
                      if (_expandedOrderIds.contains(order.id)) {
                        _expandedOrderIds.remove(order.id);
                      } else {
                        _expandedOrderIds.add(order.id);
                      }
                    });
                  },
                  onEdit: widget.onEdit,
                  onCancel: widget.onCancel,
                  onDelete: widget.onDelete,
                ),
            ],
          );
        },
      ),
    );
  }
}

class ClinicalRadiologyOrdersTablePanel extends ConsumerWidget {
  const ClinicalRadiologyOrdersTablePanel({
    required this.orders,
    required this.onCancel,
    required this.onDelete,
    super.key,
  });

  final List<ClinicalRelatedRecord> orders;
  final ClinicalOrderAction onCancel;
  final ClinicalOrderAction onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final List<ClinicalRelatedRecord> orders = sortClinicalRecordsNewestFirst(
      this.orders,
    );
    if (orders.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppWorkspaceDetailPanel(
      title: l10n.clinicalRadiologyOrdersTitle,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 480;
          if (compact) {
            return Column(
              children: <Widget>[
                for (final ClinicalRelatedRecord order in orders)
                  _ClinicalRadiologyOrderMobileCard(
                    order: order,
                    onCancel: onCancel,
                    onDelete: onDelete,
                  ),
              ],
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columns: <DataColumn>[
                DataColumn(label: Text(l10n.clinicalOrderStudyColumnLabel)),
                DataColumn(label: Text(l10n.radiologyModalityLabel)),
                DataColumn(label: Text(l10n.clinicalRadiologyBodyRegionLabel)),
                DataColumn(label: Text(l10n.opdStatusColumnLabel)),
                DataColumn(label: Text(l10n.opdTimeColumnLabel)),
                DataColumn(label: Text(l10n.opdActionsColumnLabel)),
              ],
              rows: <DataRow>[
                for (final ClinicalRelatedRecord order in orders)
                  _clinicalRadiologyDataRow(
                    context: context,
                    l10n: l10n,
                    order: order,
                    onCancel: onCancel,
                    onDelete: onDelete,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ClinicalWorkflowStepper extends StatelessWidget {
  const _ClinicalWorkflowStepper({
    required this.stages,
    required this.currentIndex,
  });

  final List<String> stages;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (var index = 0; index < stages.length; index += 1) ...<Widget>[
            if (index > 0)
              Container(
                width: 24,
                height: 2,
                color: index <= currentIndex
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircleAvatar(
                  radius: 12,
                  backgroundColor: index < currentIndex
                      ? colorScheme.primary
                      : index == currentIndex
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  child: Icon(
                    index < currentIndex
                        ? Icons.check
                        : index == currentIndex
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 14,
                    color: index <= currentIndex
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: theme.spacing.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    opdStageDisplayLabel(l10n, stages[index]),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: index == currentIndex
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: index == currentIndex
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ClinicalLabOrderGroup extends StatelessWidget {
  const _ClinicalLabOrderGroup({
    required this.order,
    required this.compact,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onEdit,
    required this.onCancel,
    required this.onDelete,
  });

  final ClinicalRelatedRecord order;
  final bool compact;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ClinicalOrderAction onEdit;
  final ClinicalOrderAction onCancel;
  final ClinicalOrderAction onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool hasChildTests = order.labOrderItems.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Divider(height: 1),
        if (compact)
          _ClinicalLabOrderMobileCard(
            order: order,
            expandable: hasChildTests,
            expanded: expanded,
            onToggleExpanded: onToggleExpanded,
            onEdit: onEdit,
            onCancel: onCancel,
            onDelete: onDelete,
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columns: <DataColumn>[
                DataColumn(label: Text(l10n.clinicalOrderTestColumnLabel)),
                DataColumn(label: Text(l10n.clinicalOrderValueColumnLabel)),
                DataColumn(label: Text(l10n.opdStatusColumnLabel)),
                DataColumn(label: Text(l10n.clinicalResultFlagColumnLabel)),
                DataColumn(label: Text(l10n.opdTimeColumnLabel)),
                DataColumn(label: Text(l10n.opdActionsColumnLabel)),
              ],
              rows: <DataRow>[
                _clinicalLabOrderDataRow(
                  context: context,
                  l10n: l10n,
                  order: order,
                  expandable: hasChildTests,
                  expanded: expanded,
                  onToggleExpanded: onToggleExpanded,
                  onEdit: onEdit,
                  onCancel: onCancel,
                  onDelete: onDelete,
                ),
              ],
            ),
          ),
        if (expanded && hasChildTests)
          Padding(
            padding: EdgeInsets.only(
              left: compact ? 0 : theme.spacing.md,
              bottom: theme.spacing.sm,
            ),
            child: compact
                ? Column(
                    children: <Widget>[
                      for (final ClinicalLabOrderItem item in order.labOrderItems)
                        _ClinicalLabOrderItemMobileCard(
                          item: item,
                          orderStatus: order.status,
                        ),
                    ],
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      showCheckboxColumn: false,
                      columns: <DataColumn>[
                        DataColumn(
                          label: Text(l10n.clinicalOrderTestColumnLabel),
                        ),
                        DataColumn(
                          label: Text(l10n.clinicalOrderCategoryColumnLabel),
                        ),
                        DataColumn(
                          label: Text(l10n.clinicalOrderValueColumnLabel),
                        ),
                        DataColumn(label: Text(l10n.opdStatusColumnLabel)),
                        DataColumn(
                          label: Text(l10n.clinicalResultFlagColumnLabel),
                        ),
                      ],
                      rows: <DataRow>[
                        for (final ClinicalLabOrderItem item
                            in order.labOrderItems)
                          _clinicalLabItemDataRow(
                            context: context,
                            l10n: l10n,
                            item: item,
                            orderStatus: order.status,
                          ),
                      ],
                    ),
                  ),
          ),
      ],
    );
  }
}

DataRow _clinicalLabOrderDataRow({
  required BuildContext context,
  required AppLocalizations l10n,
  required ClinicalRelatedRecord order,
  required bool expandable,
  required bool expanded,
  required VoidCallback onToggleExpanded,
  required ClinicalOrderAction onEdit,
  required ClinicalOrderAction onCancel,
  required ClinicalOrderAction onDelete,
}) {
  final ThemeData theme = Theme.of(context);
  final String status = order.status ?? '';
  final String title = order.title ?? order.id;

  return DataRow(
    cells: <DataCell>[
      DataCell(
        Row(
          children: <Widget>[
            if (expandable)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onToggleExpanded,
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      DataCell(Text(_labOrderAggregateValue(context, order))),
      DataCell(_ClinicalStatusBadge(status: status)),
      DataCell(
        _labOrderAggregateResultFlag(order) == null
            ? Text(l10n.clinicalOrderEmptyValueLabel)
            : _ClinicalStatusBadge(
                status: _labOrderAggregateResultFlag(order)!,
              ),
      ),
      DataCell(Text(_dateTimeLabel(context, order.occurredAt))),
      DataCell(
        _labOrderActions(
          context: context,
          l10n: l10n,
          order: order,
          onEdit: onEdit,
          onCancel: onCancel,
          onDelete: onDelete,
        ),
      ),
    ],
  );
}

DataRow _clinicalLabItemDataRow({
  required BuildContext context,
  required AppLocalizations l10n,
  required ClinicalLabOrderItem item,
  required String? orderStatus,
}) {
  final ThemeData theme = Theme.of(context);
  final String status = _effectiveLabOrderItemStatus(item, orderStatus);

  return DataRow(
    cells: <DataCell>[
      DataCell(
        Padding(
          padding: EdgeInsets.only(left: theme.spacing.lg),
          child: Text(item.displayTitle),
        ),
      ),
      DataCell(Text(_joinDisplay(<String?>[item.category, item.specimenType]))),
      DataCell(Text(_labItemValue(context, item))),
      DataCell(_ClinicalStatusBadge(status: status)),
      DataCell(
        item.resultStatus == null
            ? Text(l10n.clinicalOrderEmptyValueLabel)
            : _ClinicalStatusBadge(status: item.resultStatus!),
      ),
    ],
  );
}

DataRow _clinicalRadiologyDataRow({
  required BuildContext context,
  required AppLocalizations l10n,
  required ClinicalRelatedRecord order,
  required ClinicalOrderAction onCancel,
  required ClinicalOrderAction onDelete,
}) {
  final ClinicalRadiologyOrderItem item = order.radiologyOrderItems.isNotEmpty
      ? order.radiologyOrderItems.first
      : ClinicalRadiologyOrderItem(id: order.id);
  final String study = item.displayTitle.isNotEmpty
      ? item.displayTitle
      : (order.title ?? order.id);

  return DataRow(
    cells: <DataCell>[
      DataCell(Text(study)),
      DataCell(Text(AppDisplay.apiLabel(item.modality ?? ''))),
      DataCell(Text(AppDisplay.apiLabel(item.bodyRegion ?? ''))),
      DataCell(_ClinicalStatusBadge(status: order.status ?? '')),
      DataCell(Text(_dateTimeLabel(context, order.occurredAt))),
      DataCell(
        _radiologyOrderActions(
          context: context,
          l10n: l10n,
          order: order,
          onCancel: onCancel,
          onDelete: onDelete,
        ),
      ),
    ],
  );
}

class _ClinicalLabOrderMobileCard extends StatelessWidget {
  const _ClinicalLabOrderMobileCard({
    required this.order,
    required this.expandable,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onEdit,
    required this.onCancel,
    required this.onDelete,
  });

  final ClinicalRelatedRecord order;
  final bool expandable;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ClinicalOrderAction onEdit;
  final ClinicalOrderAction onCancel;
  final ClinicalOrderAction onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return _ClinicalOrderMobileCard(
      title: order.title ?? order.id,
      value: _labOrderAggregateValue(context, order),
      status: order.status,
      resultFlag: _labOrderAggregateResultFlag(order),
      occurredAt: order.occurredAt,
      expandable: expandable,
      expanded: expanded,
      onToggleExpanded: onToggleExpanded,
      actions: _labOrderActions(
        context: context,
        l10n: l10n,
        order: order,
        onEdit: onEdit,
        onCancel: onCancel,
        onDelete: onDelete,
      ),
    );
  }
}

class _ClinicalLabOrderItemMobileCard extends StatelessWidget {
  const _ClinicalLabOrderItemMobileCard({
    required this.item,
    required this.orderStatus,
  });

  final ClinicalLabOrderItem item;
  final String? orderStatus;

  @override
  Widget build(BuildContext context) {
    return _ClinicalOrderMobileCard(
      title: item.displayTitle,
      subtitle: _joinDisplay(<String?>[item.category, item.specimenType]),
      value: _labItemValue(context, item),
      status: _effectiveLabOrderItemStatus(item, orderStatus),
      resultFlag: item.resultStatus,
    );
  }
}

class _ClinicalRadiologyOrderMobileCard extends StatelessWidget {
  const _ClinicalRadiologyOrderMobileCard({
    required this.order,
    required this.onCancel,
    required this.onDelete,
  });

  final ClinicalRelatedRecord order;
  final ClinicalOrderAction onCancel;
  final ClinicalOrderAction onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ClinicalRadiologyOrderItem item = order.radiologyOrderItems.isNotEmpty
        ? order.radiologyOrderItems.first
        : ClinicalRadiologyOrderItem(id: order.id);

    return _ClinicalOrderMobileCard(
      title: item.displayTitle.isNotEmpty
          ? item.displayTitle
          : (order.title ?? order.id),
      subtitle: _joinDisplay(<String?>[item.modality, item.bodyRegion]),
      status: order.status,
      occurredAt: order.occurredAt,
      actions: _radiologyOrderActions(
        context: context,
        l10n: l10n,
        order: order,
        onCancel: onCancel,
        onDelete: onDelete,
      ),
    );
  }
}

class _ClinicalOrderMobileCard extends StatelessWidget {
  const _ClinicalOrderMobileCard({
    required this.title,
    this.subtitle,
    this.value,
    this.status,
    this.resultFlag,
    this.occurredAt,
    this.expandable = false,
    this.expanded = false,
    this.onToggleExpanded,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final String? status;
  final String? resultFlag;
  final DateTime? occurredAt;
  final bool expandable;
  final bool expanded;
  final VoidCallback? onToggleExpanded;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(theme.radius.sm),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (expandable)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onToggleExpanded,
                    icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_hasText(subtitle))
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (actions case final Widget value) value,
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.xs,
              children: <Widget>[
                if (_hasText(value))
                  _ClinicalLabeledChip(
                    label: l10n.clinicalOrderValueColumnLabel,
                    value: value!,
                  ),
                if (_hasText(status))
                  _ClinicalLabeledChip(
                    label: l10n.opdStatusColumnLabel,
                    child: _ClinicalStatusBadge(status: status!),
                  ),
                if (_hasText(resultFlag))
                  _ClinicalLabeledChip(
                    label: l10n.clinicalResultFlagColumnLabel,
                    child: _ClinicalStatusBadge(status: resultFlag!),
                  ),
                if (occurredAt != null)
                  _ClinicalLabeledChip(
                    label: l10n.opdTimeColumnLabel,
                    value: _dateTimeLabel(context, occurredAt),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClinicalLabeledChip extends StatelessWidget {
  const _ClinicalLabeledChip({
    required this.label,
    this.value,
    this.child,
  });

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        child ?? Text(value ?? ''),
      ],
    );
  }
}

class _ClinicalStatusBadge extends StatelessWidget {
  const _ClinicalStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(
        label: AppDisplay.apiLabel(status),
        tone: _statusTone(status),
      ),
    );
  }
}

Widget _labOrderActions({
  required BuildContext context,
  required AppLocalizations l10n,
  required ClinicalRelatedRecord order,
  required ClinicalOrderAction onEdit,
  required ClinicalOrderAction onCancel,
  required ClinicalOrderAction onDelete,
}) {
  final String status = order.status ?? '';
  final bool canEdit = _canEditLabOrder(status);
  final bool canCancel = _canCancelLabOrder(status);
  final bool canDelete = _canDeleteLabOrder(status);

  return AppAccessActionGate(
    requirement: clinicalEncounterWriteRequirement,
    builder: (BuildContext context, bool isAllowed) {
      return Wrap(
        spacing: 4,
        children: <Widget>[
          AppButton(
            iconOnly: true,
            leadingIcon: Icons.edit_outlined,
            label: l10n.clinicalEditLabOrderAction,
            semanticLabel: l10n.clinicalEditLabOrderAction,
            tooltip: l10n.clinicalEditLabOrderAction,
            enabled: isAllowed && canEdit,
            onPressed: () => onEdit(context, order),
          ),
          AppButton(
            iconOnly: true,
            leadingIcon: Icons.block_outlined,
            label: l10n.clinicalCancelLabOrderAction,
            semanticLabel: l10n.clinicalCancelLabOrderAction,
            tooltip: l10n.clinicalCancelLabOrderAction,
            enabled: isAllowed && canCancel,
            onPressed: () => onCancel(context, order),
          ),
          AppButton(
            iconOnly: true,
            leadingIcon: Icons.delete_outline,
            label: l10n.clinicalDeleteLabOrderAction,
            semanticLabel: l10n.clinicalDeleteLabOrderAction,
            tooltip: l10n.clinicalDeleteLabOrderAction,
            enabled: isAllowed && canDelete,
            onPressed: () => onDelete(context, order),
          ),
        ],
      );
    },
  );
}

Widget _radiologyOrderActions({
  required BuildContext context,
  required AppLocalizations l10n,
  required ClinicalRelatedRecord order,
  required ClinicalOrderAction onCancel,
  required ClinicalOrderAction onDelete,
}) {
  final String status = order.status ?? '';
  final bool canCancel = _canCancelRadiologyOrder(status);
  final bool canDelete = _canDeleteRadiologyOrder(status);

  return AppAccessActionGate(
    requirement: clinicalEncounterWriteRequirement,
    builder: (BuildContext context, bool isAllowed) {
      return Wrap(
        spacing: 4,
        children: <Widget>[
          AppButton(
            iconOnly: true,
            leadingIcon: Icons.block_outlined,
            label: l10n.clinicalCancelRadiologyOrderAction,
            semanticLabel: l10n.clinicalCancelRadiologyOrderAction,
            tooltip: l10n.clinicalCancelRadiologyOrderAction,
            enabled: isAllowed && canCancel,
            onPressed: () => onCancel(context, order),
          ),
          AppButton(
            iconOnly: true,
            leadingIcon: Icons.delete_outline,
            label: l10n.clinicalDeleteRadiologyOrderAction,
            semanticLabel: l10n.clinicalDeleteRadiologyOrderAction,
            tooltip: l10n.clinicalDeleteRadiologyOrderAction,
            enabled: isAllowed && canDelete,
            onPressed: () => onDelete(context, order),
          ),
        ],
      );
    },
  );
}

String _labItemValue(BuildContext context, ClinicalLabOrderItem item) {
  final String? value = _firstNonEmpty(<String?>[
    item.resultValue,
    item.resultText,
  ]);
  return value ?? context.l10n.clinicalOrderEmptyValueLabel;
}

String _labOrderAggregateValue(
  BuildContext context,
  ClinicalRelatedRecord order,
) {
  final String emptyLabel = context.l10n.clinicalOrderEmptyValueLabel;
  final List<String> values = order.labOrderItems
      .map((ClinicalLabOrderItem item) => _labItemValue(context, item))
      .where((String value) => value.trim().isNotEmpty && value != emptyLabel)
      .toList(growable: false);
  if (values.isEmpty) {
    return emptyLabel;
  }
  return values.join(' · ');
}

String? _labOrderAggregateResultFlag(ClinicalRelatedRecord order) {
  for (final ClinicalLabOrderItem item in order.labOrderItems) {
    if (_hasText(item.resultStatus)) {
      return item.resultStatus;
    }
  }
  return null;
}

String _effectiveLabOrderItemStatus(
  ClinicalLabOrderItem item,
  String? orderStatus,
) {
  final String itemStatus = (item.status ?? '').trim();
  final String normalizedOrderStatus = (orderStatus ?? '').toUpperCase();
  if (normalizedOrderStatus == 'CANCELLED' &&
      itemStatus.toUpperCase() != 'COMPLETED') {
    return 'CANCELLED';
  }
  if (itemStatus.isNotEmpty) {
    return itemStatus;
  }
  return (orderStatus ?? '').trim().isEmpty ? 'ORDERED' : orderStatus!.trim();
}

bool _canEditLabOrder(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'ORDERED' || 'PENDING' || 'IN_PROCESS' => true,
    _ => false,
  };
}

bool _canCancelLabOrder(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'ORDERED' || 'PENDING' || 'IN_PROCESS' => true,
    _ => false,
  };
}

bool _canDeleteLabOrder(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'ORDERED' || 'PENDING' || 'CANCELLED' => true,
    _ => false,
  };
}

bool _canCancelRadiologyOrder(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'ORDERED' || 'PENDING' || 'IN_PROCESS' => true,
    _ => false,
  };
}

bool _canDeleteRadiologyOrder(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'ORDERED' || 'PENDING' || 'CANCELLED' => true,
    _ => false,
  };
}

AppWorkspaceStatusTone _statusTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'COMPLETED' ||
    'DISCHARGED' ||
    'CLOSED' ||
    'NORMAL' => AppWorkspaceStatusTone.success,
    'CANCELLED' || 'CRITICAL' => AppWorkspaceStatusTone.error,
    'URGENT' ||
    'ABNORMAL' ||
    'WAITING' ||
    'WAITING_REVIEW' ||
    'WAITING_DOCTOR_REVIEW' ||
    'WAITING_DISPOSITION' ||
    'ADMITTED' => AppWorkspaceStatusTone.warning,
    'IN_PROGRESS' ||
    'ORDERED' ||
    'COLLECTED' ||
    'IN_PROCESS' ||
    'RESULTS_READY' ||
    'OPEN' => AppWorkspaceStatusTone.info,
    'PENDING' => AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

String _dateTimeLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return context.l10n.profileUnknownValue;
  }
  return AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String _joinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' · ');
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String? _firstNonEmpty(Iterable<String?> values) {
  for (final String? value in values) {
    if (_hasText(value)) {
      return value!.trim();
    }
  }
  return null;
}
