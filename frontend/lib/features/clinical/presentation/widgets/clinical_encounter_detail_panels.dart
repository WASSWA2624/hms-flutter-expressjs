import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_prescription_display.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_edit_diagnosis_action_dialog.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

export 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart'
    show clinicalEncounterWriteRequirement;

typedef ClinicalOrderAction =
    Future<void> Function(BuildContext context, ClinicalRelatedRecord order);

typedef ClinicalOrderBatchAction =
    Future<void> Function(
      BuildContext context,
      List<ClinicalRelatedRecord> orders,
    );

typedef ClinicalLabOrderItemAction =
    Future<void> Function(
      BuildContext context,
      ClinicalRelatedRecord order,
      ClinicalLabOrderItem item,
    );

List<ClinicalRelatedRecord> sortClinicalRecordsNewestFirst(
  List<ClinicalRelatedRecord> records,
) {
  final List<ClinicalRelatedRecord> sorted = List<ClinicalRelatedRecord>.from(
    records,
  );
  sorted.sort((ClinicalRelatedRecord left, ClinicalRelatedRecord right) {
    final DateTime leftAt =
        left.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final DateTime rightAt =
        right.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return rightAt.compareTo(leftAt);
  });
  return sorted;
}

class ClinicalLabOrdersTablePanel extends ConsumerStatefulWidget {
  const ClinicalLabOrdersTablePanel({
    required this.orders,
    required this.onEdit,
    required this.onCancel,
    required this.onDelete,
    this.onCancelItem,
    this.onCancelSelected,
    this.onDeleteSelected,
    super.key,
  });

  final List<ClinicalRelatedRecord> orders;
  final ClinicalOrderAction onEdit;
  final ClinicalOrderAction onCancel;
  final ClinicalOrderAction onDelete;
  final ClinicalLabOrderItemAction? onCancelItem;
  final ClinicalOrderBatchAction? onCancelSelected;
  final ClinicalOrderBatchAction? onDeleteSelected;

  @override
  ConsumerState<ClinicalLabOrdersTablePanel> createState() =>
      _ClinicalLabOrdersTablePanelState();
}

class _ClinicalLabOrdersTablePanelState
    extends ConsumerState<ClinicalLabOrdersTablePanel> {
  final Set<String> _selectedIds = <String>{};

  @override
  void didUpdateWidget(covariant ClinicalLabOrdersTablePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Set<String> validIds = widget.orders
        .map((ClinicalRelatedRecord order) => order.id)
        .toSet();
    _selectedIds.removeWhere((String id) => !validIds.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool canMutate = canWriteClinicalLabOrder(
      ref.watch(appAccessPolicyProvider),
    );
    final List<ClinicalRelatedRecord> orders = sortClinicalRecordsNewestFirst(
      widget.orders,
    );
    if (orders.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<ClinicalRelatedRecord> selectedOrders = canMutate
        ? orders
              .where(
                (ClinicalRelatedRecord order) =>
                    _selectedIds.contains(order.id),
              )
              .toList(growable: false)
        : const <ClinicalRelatedRecord>[];
    final List<ClinicalRelatedRecord> cancellableSelected = selectedOrders
        .where(
          (ClinicalRelatedRecord order) => _canCancelLabOrder(order.status),
        )
        .toList(growable: false);
    final List<ClinicalRelatedRecord> deletableSelected = selectedOrders
        .where(
          (ClinicalRelatedRecord order) =>
              !_canCancelLabOrder(order.status) &&
              _canDeleteLabOrder(order.status),
        )
        .toList(growable: false);
    final bool hasSelection = selectedOrders.isNotEmpty;

    return AppCollapsibleSection(
      title: l10n.clinicalLabOrdersTitle,
      description: l10n.clinicalLabOrdersBody,
      headerActions: canMutate
          ? <Widget>[
              AppAccessActionGate(
                requirement: clinicalLabOrderWriteRequirement,
                builder: (BuildContext context, bool isAllowed) {
                  if (!isAllowed) {
                    return const SizedBox.shrink();
                  }
                  return Wrap(
                    alignment: WrapAlignment.end,
                    spacing: theme.spacing.xs,
                    runSpacing: theme.spacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      if (hasSelection)
                        Text(
                          l10n.clinicalLabRequestSelectedCount(
                            selectedOrders.length,
                          ),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: AppFontWeight.emphasis,
                          ),
                        ),
                      if (cancellableSelected.isNotEmpty &&
                          widget.onCancelSelected != null)
                        AppButton.tertiary(
                          dense: true,
                          label: l10n.clinicalCancelSelectedLabOrdersAction,
                          leadingIcon: Icons.block_outlined,
                          color: theme.colorScheme.tertiary,
                          onPressed: () async {
                            await widget.onCancelSelected!(
                              context,
                              cancellableSelected,
                            );
                            if (mounted) {
                              setState(_selectedIds.clear);
                            }
                          },
                        ),
                      if (deletableSelected.isNotEmpty &&
                          widget.onDeleteSelected != null)
                        AppButton.tertiary(
                          dense: true,
                          label: l10n.clinicalDeleteSelectedLabOrdersAction,
                          leadingIcon: Icons.delete_outline,
                          color: theme.colorScheme.error,
                          onPressed: () async {
                            await widget.onDeleteSelected!(
                              context,
                              deletableSelected,
                            );
                            if (mounted) {
                              setState(_selectedIds.clear);
                            }
                          },
                        ),
                    ],
                  );
                },
              ),
            ]
          : const <Widget>[],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final ClinicalRelatedRecord order in orders) ...<Widget>[
            for (final _ClinicalLabPanelGroup group
                in _clinicalLabPanelGroups(order)) ...<Widget>[
              _ClinicalLabPanelSection(
                order: order,
                group: group,
                selected: canMutate && _selectedIds.contains(order.id),
                onSelectedChanged: canMutate
                    ? (bool selected) {
                        setState(() {
                          if (selected) {
                            _selectedIds.add(order.id);
                          } else {
                            _selectedIds.remove(order.id);
                          }
                        });
                      }
                    : null,
                onEdit: canMutate ? widget.onEdit : null,
                onCancel: canMutate ? widget.onCancel : null,
                onDelete: canMutate ? widget.onDelete : null,
                onCancelItem: canMutate ? widget.onCancelItem : null,
              ),
              SizedBox(height: theme.spacing.sm),
            ],
          ],
        ],
      ),
    );
  }
}

final class _ClinicalLabPanelGroup {
  const _ClinicalLabPanelGroup({
    required this.title,
    required this.items,
    required this.isPanel,
  });

  final String title;
  final List<ClinicalLabOrderItem> items;
  final bool isPanel;
}

List<_ClinicalLabPanelGroup> _clinicalLabPanelGroups(
  ClinicalRelatedRecord order,
) {
  final List<ClinicalLabOrderItem> items = order.labOrderItems;
  if (items.isEmpty) {
    return <_ClinicalLabPanelGroup>[
      _ClinicalLabPanelGroup(
        title: order.title ?? order.id,
        items: const <ClinicalLabOrderItem>[],
        isPanel: false,
      ),
    ];
  }

  final Map<String, List<ClinicalLabOrderItem>> byPanel =
      <String, List<ClinicalLabOrderItem>>{};
  final List<ClinicalLabOrderItem> ungrouped = <ClinicalLabOrderItem>[];
  for (final ClinicalLabOrderItem item in items) {
    final String? panelKey = item.panelKey;
    if (panelKey == null || panelKey.isEmpty) {
      ungrouped.add(item);
      continue;
    }
    byPanel.putIfAbsent(panelKey, () => <ClinicalLabOrderItem>[]).add(item);
  }

  final List<_ClinicalLabPanelGroup> groups = <_ClinicalLabPanelGroup>[];
  for (final MapEntry<String, List<ClinicalLabOrderItem>> entry
      in byPanel.entries) {
    final ClinicalLabOrderItem first = entry.value.first;
    groups.add(
      _ClinicalLabPanelGroup(
        title: first.panelTitle ?? order.title ?? order.id,
        items: entry.value,
        isPanel: true,
      ),
    );
  }
  for (final ClinicalLabOrderItem item in ungrouped) {
    groups.add(
      _ClinicalLabPanelGroup(
        title: item.displayTitle,
        items: <ClinicalLabOrderItem>[item],
        isPanel: false,
      ),
    );
  }
  if (groups.isEmpty) {
    groups.add(
      _ClinicalLabPanelGroup(
        title: order.title ?? order.id,
        items: items,
        isPanel: false,
      ),
    );
  }
  return groups;
}

class _ClinicalLabPanelSection extends StatelessWidget {
  const _ClinicalLabPanelSection({
    required this.order,
    required this.group,
    required this.selected,
    this.onSelectedChanged,
    this.onEdit,
    this.onCancel,
    this.onDelete,
    this.onCancelItem,
  });

  final ClinicalRelatedRecord order;
  final _ClinicalLabPanelGroup group;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;
  final ClinicalOrderAction? onEdit;
  final ClinicalOrderAction? onCancel;
  final ClinicalOrderAction? onDelete;
  final ClinicalLabOrderItemAction? onCancelItem;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool canEdit =
        onEdit != null && _canEditLabOrder(order.status);
    final bool canCancel =
        onCancel != null && _canCancelLabOrder(order.status);
    final bool canDelete =
        onDelete != null &&
        !canCancel &&
        _canDeleteLabOrder(order.status);
    final bool showSelection = onSelectedChanged != null;

    return AppCollapsibleSection(
      title: group.title,
      titleIcon: group.isPanel
          ? Icons.inventory_2_outlined
          : Icons.science_outlined,
      contentPadding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      headerActions: <Widget>[
        if (showSelection)
          Checkbox(
            value: selected,
            onChanged: (bool? value) =>
                onSelectedChanged!(value ?? false),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        if (canEdit || canCancel || canDelete)
          AppAccessActionGate(
            requirement: clinicalLabOrderWriteRequirement,
            builder: (BuildContext context, bool isAllowed) {
              if (!isAllowed) {
                return const SizedBox.shrink();
              }
              return Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: <Widget>[
                  if (canEdit)
                    AppButton.secondary(
                      dense: true,
                      leadingIcon: Icons.edit_outlined,
                      label: l10n.clinicalEditLabOrderAction,
                      semanticLabel: l10n.clinicalEditLabOrderAction,
                      tooltip: l10n.clinicalEditLabOrderAction,
                      onPressed: () => onEdit!(context, order),
                    ),
                  if (canCancel)
                    AppButton.tertiary(
                      dense: true,
                      leadingIcon: Icons.block_outlined,
                      label: l10n.clinicalCancelLabOrderAction,
                      semanticLabel: l10n.clinicalCancelLabOrderAction,
                      tooltip: l10n.clinicalCancelLabOrderAction,
                      color: theme.colorScheme.tertiary,
                      onPressed: () => onCancel!(context, order),
                    ),
                  if (canDelete)
                    AppButton.tertiary(
                      dense: true,
                      leadingIcon: Icons.delete_outline,
                      label: l10n.clinicalDeleteLabOrderAction,
                      semanticLabel: l10n.clinicalDeleteLabOrderAction,
                      tooltip: l10n.clinicalDeleteLabOrderAction,
                      color: theme.colorScheme.error,
                      onPressed: () => onDelete!(context, order),
                    ),
                ],
              );
            },
          ),
      ],
      child: _ClinicalLabResultRowsTable(
        order: order,
        items: group.items.isEmpty
            ? <ClinicalLabOrderItem>[
                ClinicalLabOrderItem(
                  id: order.id,
                  testDisplayName: order.title,
                  status: order.status,
                ),
              ]
            : group.items,
        onCancelItem: onCancelItem,
      ),
    );
  }
}

class _ClinicalLabResultRowsTable extends StatelessWidget {
  const _ClinicalLabResultRowsTable({
    required this.order,
    required this.items,
    this.onCancelItem,
  });

  final ClinicalRelatedRecord order;
  final List<ClinicalLabOrderItem> items;
  final ClinicalLabOrderItemAction? onCancelItem;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;
    final bool showActions = onCancelItem != null;
    final Color borderColor = theme.borders.faint;
    final TableBorder tableBorder = TableBorder(
      horizontalInside: theme.borders.side(color: borderColor),
      verticalInside: theme.borders.side(color: borderColor),
    );

    return Table(
      border: tableBorder,
      columnWidths: <int, TableColumnWidth>{
        0: const FlexColumnWidth(2.2),
        1: const FlexColumnWidth(2.2),
        2: const FlexColumnWidth(2.0),
        3: const FlexColumnWidth(1.4),
        if (showActions) 4: const FlexColumnWidth(1.2),
      },
      children: <TableRow>[
        TableRow(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.72),
          ),
          children: <Widget>[
            _ClinicalLabResultTableCell.header(
              label: l10n.labTestsColumnLabel,
            ),
            _ClinicalLabResultTableCell.header(
              label: l10n.labReferenceRangeLabel,
            ),
            _ClinicalLabResultTableCell.header(
              label: l10n.labReportResultLabel,
            ),
            _ClinicalLabResultTableCell.header(
              label: l10n.labResultFlagLabel,
            ),
            if (showActions)
              _ClinicalLabResultTableCell.header(
                label: l10n.labResultActionsColumnLabel,
              ),
          ],
        ),
        for (final ClinicalLabOrderItem item in items)
          _clinicalLabResultTableRow(
            context,
            order: order,
            item: item,
            showActions: showActions,
            onCancelItem: onCancelItem,
          ),
      ],
    );
  }
}

class _ClinicalLabResultTableCell extends StatelessWidget {
  const _ClinicalLabResultTableCell({required this.child});

  factory _ClinicalLabResultTableCell.header({required String label}) {
    return _ClinicalLabResultTableCell(
      child: Builder(
        builder: (BuildContext context) {
          final ThemeData theme = Theme.of(context);
          return Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: AppFontWeight.emphasis,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.1,
            ),
          );
        },
      ),
    );
  }

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(Theme.of(context).spacing.sm),
      child: Align(alignment: Alignment.topLeft, child: child),
    );
  }
}

TableRow _clinicalLabResultTableRow(
  BuildContext context, {
  required ClinicalRelatedRecord order,
  required ClinicalLabOrderItem item,
  required bool showActions,
  ClinicalLabOrderItemAction? onCancelItem,
}) {
  final ThemeData theme = Theme.of(context);
  final AppLocalizations l10n = context.l10n;
  final String pending = l10n.labStatusPending;
  final String? range = item.displayReferenceRange;
  final String? result = item.displayResultValue;
  final String? flagToken = item.effectiveResultFlag;
  final bool cancelled =
      (item.status ?? order.status ?? '').toUpperCase() == 'CANCELLED';
  final bool canCancelItem =
      onCancelItem != null &&
      _canCancelLabOrderItem(item, order.status);
  final AppClinicalResultFlag flag = _clinicalLabResultFlagForToken(flagToken);
  final AppClinicalResultFlagDisplay? flagDisplay =
      flagToken == null || flagToken.trim().isEmpty
      ? null
      : AppClinicalResultFlagDisplay.resolve(
          l10n,
          flag,
          customLabel: AppDisplay.apiLabel(flagToken),
        );
  final bool abnormalResult =
      flag == AppClinicalResultFlag.abnormal ||
      flag == AppClinicalResultFlag.critical;

  return TableRow(
    decoration: BoxDecoration(
      color: cancelled
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.22)
          : theme.colorScheme.surfaceContainerLowest,
    ),
    children: <Widget>[
      _ClinicalLabResultTableCell(
        child: Text(
          item.displayTitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
      ),
      _ClinicalLabResultTableCell(
        child: Text(range?.trim().isNotEmpty == true ? range! : pending),
      ),
      _ClinicalLabResultTableCell(
        child: Text(
          result?.trim().isNotEmpty == true ? result! : pending,
          style: abnormalResult && result?.trim().isNotEmpty == true
              ? theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: AppFontWeight.emphasis,
                )
              : null,
        ),
      ),
      _ClinicalLabResultTableCell(
        child: flagDisplay == null
            ? Text(pending)
            : AppStatusBadge(
                label: flagDisplay.label,
                tone: flagDisplay.tone,
                icon: flagDisplay.icon,
              ),
      ),
      if (showActions)
        _ClinicalLabResultTableCell(
          child: canCancelItem
              ? AppAccessActionGate(
                  requirement: clinicalLabOrderWriteRequirement,
                  builder: (BuildContext context, bool isAllowed) {
                    if (!isAllowed) {
                      return const SizedBox.shrink();
                    }
                    return AppButton.tertiary(
                      dense: true,
                      leadingIcon: Icons.block_outlined,
                      label: l10n.clinicalCancelLabTestAction,
                      semanticLabel: l10n.clinicalCancelLabTestAction,
                      tooltip: l10n.clinicalCancelLabTestAction,
                      color: theme.colorScheme.tertiary,
                      onPressed: () => onCancelItem!(context, order, item),
                    );
                  },
                )
              : const SizedBox.shrink(),
        ),
    ],
  );
}

AppClinicalResultFlag _clinicalLabResultFlagForToken(String? rawToken) {
  final String token = (rawToken ?? '').trim().toUpperCase();
  return switch (token) {
    'CRITICAL' || 'CRITICAL_LOW' || 'CRITICAL_HIGH' =>
      AppClinicalResultFlag.critical,
    'ABNORMAL' ||
    'HIGH' ||
    'LOW' ||
    'POSITIVE' ||
    'REACTIVE' ||
    'INVALID' => AppClinicalResultFlag.abnormal,
    'NORMAL' ||
    'NEGATIVE' ||
    'NON_REACTIVE' ||
    'NOT_DETECTED' => AppClinicalResultFlag.normal,
    _ => AppClinicalResultFlag.unknown,
  };
}

class ClinicalRadiologyOrdersTablePanel extends ConsumerStatefulWidget {
  const ClinicalRadiologyOrdersTablePanel({
    required this.orders,
    required this.onCancel,
    required this.onDelete,
    this.onCancelSelected,
    this.onDeleteSelected,
    super.key,
  });

  final List<ClinicalRelatedRecord> orders;
  final ClinicalOrderAction onCancel;
  final ClinicalOrderAction onDelete;
  final ClinicalOrderBatchAction? onCancelSelected;
  final ClinicalOrderBatchAction? onDeleteSelected;

  @override
  ConsumerState<ClinicalRadiologyOrdersTablePanel> createState() =>
      _ClinicalRadiologyOrdersTablePanelState();
}

class _ClinicalRadiologyOrdersTablePanelState
    extends ConsumerState<ClinicalRadiologyOrdersTablePanel> {
  final Set<String> _selectedIds = <String>{};

  @override
  void didUpdateWidget(covariant ClinicalRadiologyOrdersTablePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Set<String> validIds = widget.orders
        .map((ClinicalRelatedRecord order) => order.id)
        .toSet();
    _selectedIds.removeWhere((String id) => !validIds.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool canMutate = canWriteClinicalRadiologyOrder(
      ref.watch(appAccessPolicyProvider),
    );
    final List<ClinicalRelatedRecord> orders = sortClinicalRecordsNewestFirst(
      widget.orders,
    );
    if (orders.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<ClinicalRelatedRecord> selectedOrders = canMutate
        ? orders
              .where(
                (ClinicalRelatedRecord order) =>
                    _selectedIds.contains(order.id),
              )
              .toList(growable: false)
        : const <ClinicalRelatedRecord>[];
    final List<ClinicalRelatedRecord> cancellableSelected = selectedOrders
        .where(
          (ClinicalRelatedRecord order) =>
              _canCancelRadiologyOrder(order.status),
        )
        .toList(growable: false);
    final List<ClinicalRelatedRecord> deletableSelected = selectedOrders
        .where(
          (ClinicalRelatedRecord order) =>
              !_canCancelRadiologyOrder(order.status) &&
              _canDeleteRadiologyOrder(order.status),
        )
        .toList(growable: false);

    return AppCollapsibleSection(
      title: l10n.clinicalRadiologyOrdersTitle,
      headerActions: canMutate
          ? _clinicalBatchHeaderActions(
              context: context,
              selectedCount: selectedOrders.length,
              cancellableSelected: cancellableSelected,
              deletableSelected: deletableSelected,
              cancelLabel: l10n.clinicalCancelSelectedRadiologyOrdersAction,
              deleteLabel: l10n.clinicalDeleteSelectedRadiologyOrdersAction,
              onCancelSelected: widget.onCancelSelected,
              onDeleteSelected: widget.onDeleteSelected,
              onCleared: () => setState(_selectedIds.clear),
              requirement: clinicalRadiologyOrderWriteRequirement,
            )
          : const <Widget>[],
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 480;
          if (compact) {
            return Column(
              children: <Widget>[
                for (final ClinicalRelatedRecord order in orders)
                  _ClinicalRadiologyOrderMobileCard(
                    order: order,
                    selected: canMutate && _selectedIds.contains(order.id),
                    onSelectedChanged: canMutate
                        ? (bool selected) {
                            setState(() {
                              if (selected) {
                                _selectedIds.add(order.id);
                              } else {
                                _selectedIds.remove(order.id);
                              }
                            });
                          }
                        : null,
                    onCancel: canMutate ? widget.onCancel : null,
                    onDelete: canMutate ? widget.onDelete : null,
                  ),
              ],
            );
          }

          final bool allSelected =
              canMutate &&
              orders.isNotEmpty &&
              orders.every(
                (ClinicalRelatedRecord order) =>
                    _selectedIds.contains(order.id),
              );
          final bool someSelected =
              canMutate &&
              orders.any(
                (ClinicalRelatedRecord order) =>
                    _selectedIds.contains(order.id),
              );

          return _ClinicalDetailDataTableContainer(
            minWidth: constraints.maxWidth,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 40,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 64,
              columnSpacing: theme.spacing.md,
              horizontalMargin: theme.spacing.sm,
              columns: <DataColumn>[
                if (canMutate)
                  DataColumn(
                    label: Checkbox(
                      tristate: true,
                      value: allSelected
                          ? true
                          : someSelected
                          ? null
                          : false,
                      onChanged: (bool? checked) {
                        setState(() {
                          if (checked ?? false) {
                            _selectedIds
                              ..clear()
                              ..addAll(
                                orders.map(
                                  (ClinicalRelatedRecord order) => order.id,
                                ),
                              );
                          } else {
                            _selectedIds.clear();
                          }
                        });
                      },
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                DataColumn(label: Text(l10n.clinicalOrderStudyColumnLabel)),
                DataColumn(label: Text(l10n.radiologyModalityLabel)),
                DataColumn(
                  label: Text(l10n.clinicalRadiologyBodyRegionLabel),
                ),
                DataColumn(label: Text(l10n.opdStatusColumnLabel)),
                DataColumn(label: Text(l10n.opdTimeColumnLabel)),
                if (canMutate)
                  DataColumn(label: Text(l10n.opdActionsColumnLabel)),
              ],
              rows: <DataRow>[
                for (final ClinicalRelatedRecord order in orders)
                  _clinicalRadiologyDataRow(
                    context: context,
                    l10n: l10n,
                    order: order,
                    selected: canMutate && _selectedIds.contains(order.id),
                    onSelectedChanged: canMutate
                        ? (bool selected) {
                            setState(() {
                              if (selected) {
                                _selectedIds.add(order.id);
                              } else {
                                _selectedIds.remove(order.id);
                              }
                            });
                          }
                        : null,
                    onCancel: canMutate ? widget.onCancel : null,
                    onDelete: canMutate ? widget.onDelete : null,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ClinicalPharmacyOrdersTablePanel extends ConsumerStatefulWidget {
  const ClinicalPharmacyOrdersTablePanel({
    required this.orders,
    required this.onCancel,
    required this.onDelete,
    this.onCancelSelected,
    this.onDeleteSelected,
    super.key,
  });

  final List<ClinicalRelatedRecord> orders;
  final ClinicalOrderAction onCancel;
  final ClinicalOrderAction onDelete;
  final ClinicalOrderBatchAction? onCancelSelected;
  final ClinicalOrderBatchAction? onDeleteSelected;

  @override
  ConsumerState<ClinicalPharmacyOrdersTablePanel> createState() =>
      _ClinicalPharmacyOrdersTablePanelState();
}

class _ClinicalPharmacyOrdersTablePanelState
    extends ConsumerState<ClinicalPharmacyOrdersTablePanel> {
  final Set<String> _selectedIds = <String>{};

  @override
  void didUpdateWidget(covariant ClinicalPharmacyOrdersTablePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Set<String> validIds = widget.orders
        .map((ClinicalRelatedRecord order) => order.id)
        .toSet();
    _selectedIds.removeWhere((String id) => !validIds.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool canMutate = canWriteClinicalPharmacyOrder(
      ref.watch(appAccessPolicyProvider),
    );
    final List<ClinicalRelatedRecord> orders = sortClinicalRecordsNewestFirst(
      widget.orders,
    );
    if (orders.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<ClinicalRelatedRecord> selectedOrders = canMutate
        ? orders
              .where(
                (ClinicalRelatedRecord order) =>
                    _selectedIds.contains(order.id),
              )
              .toList(growable: false)
        : const <ClinicalRelatedRecord>[];
    final List<ClinicalRelatedRecord> cancellableSelected = selectedOrders
        .where(
          (ClinicalRelatedRecord order) =>
              _canCancelPharmacyOrder(order.status),
        )
        .toList(growable: false);
    final List<ClinicalRelatedRecord> deletableSelected = selectedOrders
        .where(
          (ClinicalRelatedRecord order) =>
              !_canCancelPharmacyOrder(order.status) &&
              _canDeletePharmacyOrder(order.status),
        )
        .toList(growable: false);

    return AppCollapsibleSection(
      title: l10n.clinicalPharmacyOrdersTitle,
      actions: canMutate
          ? _clinicalBatchHeaderActions(
              context: context,
              selectedCount: selectedOrders.length,
              cancellableSelected: cancellableSelected,
              deletableSelected: deletableSelected,
              cancelLabel: l10n.clinicalCancelSelectedRadiologyOrdersAction,
              deleteLabel: l10n.clinicalDeleteSelectedRadiologyOrdersAction,
              onCancelSelected: widget.onCancelSelected,
              onDeleteSelected: widget.onDeleteSelected,
              onCleared: () => setState(_selectedIds.clear),
              requirement: clinicalPharmacyOrderWriteRequirement,
            )
          : const <Widget>[],
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool allSelected =
              canMutate &&
              orders.isNotEmpty &&
              orders.every(
                (ClinicalRelatedRecord order) =>
                    _selectedIds.contains(order.id),
              );
          final bool someSelected =
              canMutate &&
              orders.any(
                (ClinicalRelatedRecord order) =>
                    _selectedIds.contains(order.id),
              );

          return _ClinicalDetailDataTableContainer(
            minWidth: constraints.maxWidth,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 40,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 120,
              columnSpacing: theme.spacing.md,
              horizontalMargin: theme.spacing.sm,
              columns: <DataColumn>[
                if (canMutate)
                  DataColumn(
                    label: Checkbox(
                      tristate: true,
                      value: allSelected
                          ? true
                          : someSelected
                          ? null
                          : false,
                      onChanged: (bool? checked) {
                        setState(() {
                          if (checked ?? false) {
                            _selectedIds
                              ..clear()
                              ..addAll(
                                orders.map(
                                  (ClinicalRelatedRecord order) => order.id,
                                ),
                              );
                          } else {
                            _selectedIds.clear();
                          }
                        });
                      },
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                DataColumn(label: Text(l10n.pharmacyMedicationColumnLabel)),
                DataColumn(label: Text(l10n.opdStatusColumnLabel)),
                DataColumn(label: Text(l10n.opdTimeColumnLabel)),
                if (canMutate)
                  DataColumn(label: Text(l10n.opdActionsColumnLabel)),
              ],
              rows: <DataRow>[
                for (final ClinicalRelatedRecord order in orders)
                  DataRow(
                    selected: canMutate && _selectedIds.contains(order.id),
                    onSelectChanged: canMutate
                        ? (bool? value) {
                            setState(() {
                              if (value ?? false) {
                                _selectedIds.add(order.id);
                              } else {
                                _selectedIds.remove(order.id);
                              }
                            });
                          }
                        : null,
                    cells: <DataCell>[
                      if (canMutate)
                        DataCell(
                          Checkbox(
                            value: _selectedIds.contains(order.id),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value ?? false) {
                                  _selectedIds.add(order.id);
                                } else {
                                  _selectedIds.remove(order.id);
                                }
                              });
                            },
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: order.pharmacyOrderItems.isEmpty
                              ? Text(
                                  order.title ?? order.id,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    for (final ClinicalPharmacyOrderItem item
                                        in order.pharmacyOrderItems)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          bottom: theme.spacing.xs / 2,
                                        ),
                                        child: Text(
                                          clinicalPrescriptionItemPaperLine(
                                            item,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                      DataCell(
                        _ClinicalOrderStatusWithPayment(
                          status: order.status,
                          paymentStatus: order.paymentStatus,
                        ),
                      ),
                      DataCell(Text(_dateTimeLabel(context, order.occurredAt))),
                      if (canMutate)
                        DataCell(
                          _pharmacyOrderActions(
                            context: context,
                            l10n: l10n,
                            order: order,
                            onCancel: widget.onCancel,
                            onDelete: widget.onDelete,
                          ),
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

class ClinicalDiagnosesTablePanel extends ConsumerStatefulWidget {
  const ClinicalDiagnosesTablePanel({
    required this.diagnoses,
    required this.onRemove,
    this.onRemoveSelected,
    this.onEditSelected,
    this.onAdd,
    super.key,
  });

  final List<ClinicalRelatedRecord> diagnoses;
  final ClinicalOrderAction onRemove;
  final ClinicalOrderBatchAction? onRemoveSelected;
  final ClinicalOrderBatchAction? onEditSelected;
  final VoidCallback? onAdd;

  @override
  ConsumerState<ClinicalDiagnosesTablePanel> createState() =>
      _ClinicalDiagnosesTablePanelState();
}

class _ClinicalDiagnosesTablePanelState
    extends ConsumerState<ClinicalDiagnosesTablePanel> {
  final Set<String> _selectedIds = <String>{};

  @override
  void didUpdateWidget(covariant ClinicalDiagnosesTablePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Set<String> validIds = widget.diagnoses
        .map((ClinicalRelatedRecord diagnosis) => diagnosis.id)
        .toSet();
    _selectedIds.removeWhere((String id) => !validIds.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool canMutate = canWriteClinical(ref.watch(appAccessPolicyProvider));
    final List<ClinicalRelatedRecord> diagnoses =
        sortClinicalRecordsNewestFirst(widget.diagnoses);
    if (diagnoses.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<ClinicalRelatedRecord> selectedDiagnoses = canMutate
        ? diagnoses
              .where(
                (ClinicalRelatedRecord diagnosis) =>
                    _selectedIds.contains(diagnosis.id),
              )
              .toList(growable: false)
        : const <ClinicalRelatedRecord>[];
    final bool hasSelection = selectedDiagnoses.isNotEmpty;

    return AppCollapsibleSection(
      title: l10n.clinicalPatientDiagnosesTitle,
      headerActions: canMutate
          ? <Widget>[
              AppAccessActionGate(
                requirement: clinicalEncounterWriteRequirement,
                builder: (BuildContext context, bool isAllowed) {
                  if (!isAllowed) {
                    return const SizedBox.shrink();
                  }
                  return Wrap(
                    alignment: WrapAlignment.end,
                    spacing: theme.spacing.xs,
                    runSpacing: theme.spacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      if (hasSelection)
                        Text(
                          l10n.clinicalLabRequestSelectedCount(
                            selectedDiagnoses.length,
                          ),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: AppFontWeight.emphasis,
                          ),
                        ),
                      if (hasSelection && widget.onRemoveSelected != null)
                        AppButton.tertiary(
                          dense: true,
                          label: l10n.clinicalRemoveSelectedDiagnosesAction,
                          leadingIcon: AppActionIcons.delete,
                          color: theme.colorScheme.error,
                          onPressed: () async {
                            await widget.onRemoveSelected!(
                              context,
                              selectedDiagnoses,
                            );
                            if (mounted) {
                              setState(_selectedIds.clear);
                            }
                          },
                        ),
                      if (widget.onAdd != null)
                        AppButton.secondary(
                          label: l10n.commonAddActionLabel,
                          leadingIcon: AppActionIcons.add,
                          dense: true,
                          onPressed: widget.onAdd,
                        ),
                      if (widget.onEditSelected != null)
                        AppButton.secondary(
                          label: l10n.commonEditActionLabel,
                          leadingIcon: AppActionIcons.edit,
                          dense: true,
                          enabled: hasSelection,
                          onPressed: hasSelection
                              ? () async {
                                  await widget.onEditSelected!(
                                    context,
                                    selectedDiagnoses,
                                  );
                                }
                              : null,
                        ),
                    ],
                  );
                },
              ),
            ]
          : const <Widget>[],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var index = 0; index < diagnoses.length; index += 1) ...<Widget>[
            if (index > 0) const Divider(height: 1),
            _ClinicalDiagnosisRow(
              diagnosis: diagnoses[index],
              canMutate: canMutate,
              selected: canMutate && _selectedIds.contains(diagnoses[index].id),
              onSelectedChanged: canMutate
                  ? (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedIds.add(diagnoses[index].id);
                        } else {
                          _selectedIds.remove(diagnoses[index].id);
                        }
                      });
                    }
                  : null,
              onRemove: canMutate
                  ? () => widget.onRemove(context, diagnoses[index])
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _ClinicalDiagnosisRow extends StatelessWidget {
  const _ClinicalDiagnosisRow({
    required this.diagnosis,
    required this.canMutate,
    required this.selected,
    this.onSelectedChanged,
    this.onRemove,
  });

  final ClinicalRelatedRecord diagnosis;
  final bool canMutate;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onSelectedChanged == null
            ? null
            : () => onSelectedChanged!(!selected),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.sm,
          ),
          child: Row(
            children: <Widget>[
              if (canMutate)
                Checkbox(
                  value: selected,
                  onChanged: onSelectedChanged == null
                      ? null
                      : (bool? value) => onSelectedChanged!(value ?? false),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              Expanded(
                child: Text(
                  formatClinicalDiagnosisDisplay(diagnosis),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              if (canMutate && onRemove != null)
                AppAccessActionGate(
                  requirement: clinicalEncounterWriteRequirement,
                  builder: (BuildContext context, bool isAllowed) {
                    if (!isAllowed) {
                      return const SizedBox.shrink();
                    }
                    return AppButton.tertiary(
                      dense: true,
                      leadingIcon: AppActionIcons.delete,
                      label: l10n.clinicalRemoveDiagnosisAction,
                      semanticLabel: l10n.clinicalRemoveDiagnosisAction,
                      tooltip: l10n.clinicalRemoveDiagnosisAction,
                      color: theme.colorScheme.error,
                      onPressed: onRemove,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

DataRow _clinicalRadiologyDataRow({
  required BuildContext context,
  required AppLocalizations l10n,
  required ClinicalRelatedRecord order,
  required bool selected,
  ValueChanged<bool>? onSelectedChanged,
  ClinicalOrderAction? onCancel,
  ClinicalOrderAction? onDelete,
}) {
  final ClinicalRadiologyOrderItem item = order.radiologyOrderItems.isNotEmpty
      ? order.radiologyOrderItems.first
      : ClinicalRadiologyOrderItem(id: order.id);
  final String study = item.displayTitle.isNotEmpty
      ? item.displayTitle
      : (order.title ?? order.id);
  final bool showSelection = onSelectedChanged != null;
  final bool showActions = onCancel != null || onDelete != null;

  return DataRow(
    selected: showSelection && selected,
    onSelectChanged: showSelection
        ? (bool? value) => onSelectedChanged(value ?? false)
        : null,
    cells: <DataCell>[
      if (showSelection)
        DataCell(
          Checkbox(
            value: selected,
            onChanged: (bool? value) => onSelectedChanged(value ?? false),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      DataCell(
        Text(study, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
      DataCell(Text(AppDisplay.apiLabel(item.modality ?? ''))),
      DataCell(Text(AppDisplay.apiLabel(item.bodyRegion ?? ''))),
      DataCell(
        _ClinicalOrderStatusWithPayment(
          status: order.status,
          paymentStatus: order.paymentStatus,
        ),
      ),
      DataCell(Text(_dateTimeLabel(context, order.occurredAt))),
      if (showActions)
        DataCell(
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _radiologyOrderActions(
              context: context,
              l10n: l10n,
              order: order,
              onCancel: onCancel,
              onDelete: onDelete,
            ),
          ),
        ),
    ],
  );
}

class _ClinicalRadiologyOrderMobileCard extends StatelessWidget {
  const _ClinicalRadiologyOrderMobileCard({
    required this.order,
    required this.selected,
    this.onSelectedChanged,
    this.onCancel,
    this.onDelete,
  });

  final ClinicalRelatedRecord order;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;
  final ClinicalOrderAction? onCancel;
  final ClinicalOrderAction? onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ClinicalRadiologyOrderItem item = order.radiologyOrderItems.isNotEmpty
        ? order.radiologyOrderItems.first
        : ClinicalRadiologyOrderItem(id: order.id);
    final bool showSelection = onSelectedChanged != null;
    final bool showActions = onCancel != null || onDelete != null;
    final ValueChanged<bool>? selectionChanged = onSelectedChanged;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showSelection && selectionChanged != null)
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.sm),
            child: Checkbox(
              value: selected,
              onChanged: (bool? value) => selectionChanged(value ?? false),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        Expanded(
          child: _ClinicalOrderMobileCard(
            title: item.displayTitle.isNotEmpty
                ? item.displayTitle
                : (order.title ?? order.id),
            subtitle: _joinDisplay(<String?>[item.modality, item.bodyRegion]),
            status: order.status,
            paymentStatus: order.paymentStatus,
            occurredAt: order.occurredAt,
            actions: showActions
                ? _radiologyOrderActions(
                    context: context,
                    l10n: l10n,
                    order: order,
                    onCancel: onCancel,
                    onDelete: onDelete,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _ClinicalOrderMobileCard extends StatelessWidget {
  const _ClinicalOrderMobileCard({
    required this.title,
    this.subtitle,
    this.value,
    this.status,
    this.paymentStatus,
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
  final String? paymentStatus;
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
        border: theme.borders.all(),
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
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: AppFontWeight.emphasis,
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
                if (_hasText(status) || _hasText(paymentStatus))
                  _ClinicalLabeledChip(
                    label: l10n.opdStatusColumnLabel,
                    child: _ClinicalOrderStatusWithPayment(
                      status: status,
                      paymentStatus: paymentStatus,
                    ),
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
  const _ClinicalLabeledChip({required this.label, this.value, this.child});

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
            fontWeight: AppFontWeight.emphasis,
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
    return AppStatusBadge(
      label: AppDisplay.apiLabel(status),
      tone: _statusTone(status),
    );
  }
}

/// Order workflow status plus optional Billing payment_status chip (parity).
class _ClinicalOrderStatusWithPayment extends StatelessWidget {
  const _ClinicalOrderStatusWithPayment({
    required this.status,
    this.paymentStatus,
  });

  final String? status;
  final String? paymentStatus;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String normalizedStatus = (status ?? '').trim();
    final String normalizedPayment = (paymentStatus ?? '').trim();
    return Wrap(
      spacing: theme.spacing.xs,
      runSpacing: theme.spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (normalizedStatus.isNotEmpty)
          _ClinicalStatusBadge(status: normalizedStatus),
        if (normalizedPayment.isNotEmpty)
          AppStatusBadge(
            label: clinicalRequestPaymentStatusDisplayLabel(
              l10n,
              normalizedPayment,
            ),
            tone: _paymentStatusTone(normalizedPayment),
          ),
      ],
    );
  }
}

AppWorkspaceStatusTone _paymentStatusTone(String? rawStatus) {
  return switch (clinicalRequestPaymentStatusFromValue(rawStatus)) {
    ClinicalRequestPaymentStatus.paid => AppWorkspaceStatusTone.success,
    ClinicalRequestPaymentStatus.partial => AppWorkspaceStatusTone.warning,
    ClinicalRequestPaymentStatus.unpaid => AppWorkspaceStatusTone.warning,
    ClinicalRequestPaymentStatus.notBilled => AppWorkspaceStatusTone.neutral,
  };
}

Widget _radiologyOrderActions({
  required BuildContext context,
  required AppLocalizations l10n,
  required ClinicalRelatedRecord order,
  ClinicalOrderAction? onCancel,
  ClinicalOrderAction? onDelete,
}) {
  final ThemeData theme = Theme.of(context);
  final String status = order.status ?? '';
  final bool canCancel = onCancel != null && _canCancelRadiologyOrder(status);
  final bool canDelete =
      onDelete != null && !canCancel && _canDeleteRadiologyOrder(status);
  final ClinicalOrderAction? cancelAction = onCancel;
  final ClinicalOrderAction? deleteAction = onDelete;

  if (!canCancel && !canDelete) {
    return const SizedBox.shrink();
  }

  return AppAccessActionGate(
    requirement: clinicalRadiologyOrderWriteRequirement,
    builder: (BuildContext context, bool isAllowed) {
      if (!isAllowed) {
        return const SizedBox.shrink();
      }
      if (canCancel && cancelAction != null) {
        return AppButton.tertiary(
          dense: true,
          leadingIcon: Icons.block_outlined,
          label: l10n.clinicalCancelRadiologyOrderAction,
          semanticLabel: l10n.clinicalCancelRadiologyOrderAction,
          tooltip: l10n.clinicalCancelRadiologyOrderAction,
          color: theme.colorScheme.tertiary,
          onPressed: () => cancelAction(context, order),
        );
      }
      if (deleteAction == null) {
        return const SizedBox.shrink();
      }
      return AppButton.tertiary(
        dense: true,
        leadingIcon: Icons.delete_outline,
        label: l10n.clinicalDeleteRadiologyOrderAction,
        semanticLabel: l10n.clinicalDeleteRadiologyOrderAction,
        tooltip: l10n.clinicalDeleteRadiologyOrderAction,
        color: theme.colorScheme.error,
        onPressed: () => deleteAction(context, order),
      );
    },
  );
}

List<Widget> _clinicalBatchHeaderActions({
  required BuildContext context,
  required int selectedCount,
  required List<ClinicalRelatedRecord> cancellableSelected,
  required List<ClinicalRelatedRecord> deletableSelected,
  required String cancelLabel,
  required String deleteLabel,
  required ClinicalOrderBatchAction? onCancelSelected,
  required ClinicalOrderBatchAction? onDeleteSelected,
  required VoidCallback onCleared,
  AccessRequirement requirement = clinicalEncounterWriteRequirement,
}) {
  if (selectedCount <= 0) {
    return const <Widget>[];
  }

  final AppLocalizations l10n = context.l10n;
  final ThemeData theme = Theme.of(context);

  return <Widget>[
    Text(
      l10n.clinicalLabRequestSelectedCount(selectedCount),
      style: theme.textTheme.labelLarge?.copyWith(fontWeight: AppFontWeight.emphasis),
    ),
    AppAccessActionGate(
      requirement: requirement,
      builder: (BuildContext context, bool isAllowed) {
        if (!isAllowed) {
          return const SizedBox.shrink();
        }
        return Wrap(
          spacing: theme.spacing.xs,
          runSpacing: theme.spacing.xs,
          children: <Widget>[
            if (cancellableSelected.isNotEmpty)
              AppButton.tertiary(
                dense: true,
                label: cancelLabel,
                leadingIcon: Icons.block_outlined,
                color: theme.colorScheme.tertiary,
                enabled: onCancelSelected != null,
                onPressed: onCancelSelected == null
                    ? null
                    : () async {
                        await onCancelSelected(context, cancellableSelected);
                        onCleared();
                      },
              ),
            if (deletableSelected.isNotEmpty)
              AppButton.tertiary(
                dense: true,
                label: deleteLabel,
                leadingIcon: Icons.delete_outline,
                color: theme.colorScheme.error,
                enabled: onDeleteSelected != null,
                onPressed: onDeleteSelected == null
                    ? null
                    : () async {
                        await onDeleteSelected(context, deletableSelected);
                        onCleared();
                      },
              ),
          ],
        );
      },
    ),
  ];
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
    'ORDERED' || 'PENDING' => true,
    _ => false,
  };
}

bool _canCancelLabOrder(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'ORDERED' || 'PENDING' => true,
    _ => false,
  };
}

bool _canCancelLabOrderItem(ClinicalLabOrderItem item, String? orderStatus) {
  if (item.hasResult) {
    return false;
  }
  final String status = _effectiveLabOrderItemStatus(item, orderStatus).toUpperCase();
  return switch (status) {
    'ORDERED' || 'PENDING' => true,
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
    'ORDERED' || 'PENDING' || 'IN_PROCESS' || 'AWAITING_REPORT' => true,
    _ => false,
  };
}

bool _canDeleteRadiologyOrder(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'ORDERED' || 'PENDING' || 'CANCELLED' => true,
    _ => false,
  };
}

bool _canCancelPharmacyOrder(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'ORDERED' || 'PARTIALLY_DISPENSED' => true,
    _ => false,
  };
}

bool _canDeletePharmacyOrder(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'ORDERED' || 'CANCELLED' => true,
    _ => false,
  };
}

Widget _pharmacyOrderActions({
  required BuildContext context,
  required AppLocalizations l10n,
  required ClinicalRelatedRecord order,
  ClinicalOrderAction? onCancel,
  ClinicalOrderAction? onDelete,
}) {
  final ThemeData theme = Theme.of(context);
  final String status = order.status ?? '';
  final bool canCancel = onCancel != null && _canCancelPharmacyOrder(status);
  final bool canDelete =
      onDelete != null && !canCancel && _canDeletePharmacyOrder(status);
  final ClinicalOrderAction? cancelAction = onCancel;
  final ClinicalOrderAction? deleteAction = onDelete;

  if (!canCancel && !canDelete) {
    return const SizedBox.shrink();
  }

  return AppAccessActionGate(
    requirement: clinicalPharmacyOrderWriteRequirement,
    builder: (BuildContext context, bool isAllowed) {
      if (!isAllowed) {
        return const SizedBox.shrink();
      }
      if (canCancel && cancelAction != null) {
        return AppButton.tertiary(
          dense: true,
          leadingIcon: Icons.block_outlined,
          label: l10n.clinicalCancelPharmacyOrderAction,
          semanticLabel: l10n.clinicalCancelPharmacyOrderAction,
          tooltip: l10n.clinicalCancelPharmacyOrderAction,
          color: theme.colorScheme.tertiary,
          onPressed: () => cancelAction(context, order),
        );
      }
      if (deleteAction == null) {
        return const SizedBox.shrink();
      }
      return AppButton.tertiary(
        dense: true,
        leadingIcon: Icons.delete_outline,
        label: l10n.clinicalDeletePharmacyOrderAction,
        semanticLabel: l10n.clinicalDeletePharmacyOrderAction,
        tooltip: l10n.clinicalDeletePharmacyOrderAction,
        color: theme.colorScheme.error,
        onPressed: () => deleteAction(context, order),
      );
    },
  );
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
    'AWAITING_REPORT' ||
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

class _ClinicalDetailDataTableContainer extends StatelessWidget {
  const _ClinicalDetailDataTableContainer({
    required this.child,
    this.minWidth,
  });

  final Widget child;
  final double? minWidth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: theme.borders.side(),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = math.max(
            minWidth ?? 0,
            constraints.maxWidth.isFinite ? constraints.maxWidth : 0,
          );
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: width > 0 ? width : 0),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
