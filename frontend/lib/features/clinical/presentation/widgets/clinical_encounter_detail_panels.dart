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
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';

export 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart'
    show clinicalEncounterWriteRequirement;

typedef ClinicalOrderAction =
    Future<void> Function(BuildContext context, ClinicalRelatedRecord order);

typedef ClinicalOrderBatchAction =
    Future<void> Function(
      BuildContext context,
      List<ClinicalRelatedRecord> orders,
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

class ClinicalWorkflowProgressStrip extends StatelessWidget {
  const ClinicalWorkflowProgressStrip({
    required this.handoff,
    this.onNextAction,
    super.key,
  });

  final ClinicalTriageHandoff handoff;
  final VoidCallback? onNextAction;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
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
        : opdWorkflowStagesAround(currentStage, lookAhead: 0);
    final int currentIndex = handoff.timeline.isNotEmpty
        ? stages.length - 1
        : opdFlowStageIndex(currentStage);
    final String currentLabel = opdStageDisplayLabel(l10n, currentStage);
    final String nextLabel = opdNextStepDisplayLabel(l10n, nextStep);
    final bool nextActionIsRecordVitals = _isRecordVitalsNextStep(nextStep);
    final List<AppWorkflowStepItem> steps = <AppWorkflowStepItem>[
      for (var index = 0; index < stages.length; index += 1)
        if (index < currentIndex &&
            opdStageDisplayLabel(l10n, stages[index]).isNotEmpty)
          AppWorkflowStepItem(
            id: 'completed-$index-${stages[index]}',
            label: opdStageDisplayLabel(l10n, stages[index]),
            state: AppWorkflowStepState.completed,
          ),
      if (currentLabel.isNotEmpty)
        AppWorkflowStepItem(
          id: 'current-$currentStage',
          label: currentLabel,
          description: l10n.clinicalCurrentStageLabel,
          state: AppWorkflowStepState.current,
        ),
      if (nextLabel.isNotEmpty && nextLabel != currentLabel)
        AppWorkflowStepItem(
          id: 'next-$nextStep',
          label: nextLabel,
          description: l10n.opdNextActionColumnLabel,
          state: AppWorkflowStepState.upcoming,
          onTap: nextActionIsRecordVitals ? onNextAction : null,
          helpText: nextActionIsRecordVitals && onNextAction != null
              ? l10n.opdRecordVitalsAction
              : null,
        ),
    ];

    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppWorkflowStepper(
      steps: steps,
      semanticLabel: l10n.clinicalWorkflowProgressLabel,
    );
  }
}

bool _isRecordVitalsNextStep(String? nextStep) {
  final String normalized = (nextStep ?? '').trim().toUpperCase();
  return normalized == 'RECORD_VITALS' ||
      normalized == 'WAITING_VITALS' ||
      normalized == 'VITALS_NEEDED' ||
      normalized == 'VITALS_PENDING' ||
      normalized == 'TRIAGE_PENDING';
}

class ClinicalLabOrdersTablePanel extends ConsumerStatefulWidget {
  const ClinicalLabOrdersTablePanel({
    required this.orders,
    required this.onEdit,
    required this.onCancel,
    required this.onDelete,
    this.onCancelSelected,
    this.onDeleteSelected,
    super.key,
  });

  final List<ClinicalRelatedRecord> orders;
  final ClinicalOrderAction onEdit;
  final ClinicalOrderAction onCancel;
  final ClinicalOrderAction onDelete;
  final ClinicalOrderBatchAction? onCancelSelected;
  final ClinicalOrderBatchAction? onDeleteSelected;

  @override
  ConsumerState<ClinicalLabOrdersTablePanel> createState() =>
      _ClinicalLabOrdersTablePanelState();
}

class _ClinicalLabOrdersTablePanelState
    extends ConsumerState<ClinicalLabOrdersTablePanel> {
  final Set<String> _expandedOrderIds = <String>{};
  final Set<String> _selectedIds = <String>{};

  @override
  void didUpdateWidget(covariant ClinicalLabOrdersTablePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Set<String> validIds = widget.orders
        .map((ClinicalRelatedRecord order) => order.id)
        .toSet();
    _selectedIds.removeWhere((String id) => !validIds.contains(id));
    _expandedOrderIds.removeWhere((String id) => !validIds.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
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

    return AppWorkspaceDetailPanel(
      title: l10n.clinicalLabOrdersTitle,
      description: l10n.clinicalLabOrdersBody,
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
              requirement: clinicalLabOrderWriteRequirement,
            )
          : const <Widget>[],
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 480;
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (canMutate)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Checkbox(
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
              for (final ClinicalRelatedRecord order in orders)
                _ClinicalLabOrderGroup(
                  order: order,
                  compact: compact,
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
                  onEdit: canMutate ? widget.onEdit : null,
                  onCancel: canMutate ? widget.onCancel : null,
                  onDelete: canMutate ? widget.onDelete : null,
                ),
            ],
          );
        },
      ),
    );
  }
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

    return AppWorkspaceDetailPanel(
      title: l10n.clinicalRadiologyOrdersTitle,
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

    return AppWorkspaceDetailPanel(
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
              dataRowMaxHeight: 72,
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
                        Text(
                          order.title ?? order.id,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(
                        _ClinicalStatusBadge(status: order.status ?? ''),
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
    required this.onDelete,
    this.onDeleteSelected,
    super.key,
  });

  final List<ClinicalRelatedRecord> diagnoses;
  final ClinicalOrderAction onDelete;
  final ClinicalOrderBatchAction? onDeleteSelected;

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

    return AppWorkspaceDetailPanel(
      title: l10n.clinicalPatientDiagnosesTitle,
      actions: canMutate
          ? _clinicalBatchHeaderActions(
              context: context,
              selectedCount: selectedDiagnoses.length,
              cancellableSelected: const <ClinicalRelatedRecord>[],
              deletableSelected: selectedDiagnoses,
              cancelLabel: l10n.clinicalCancelSelectedRadiologyOrdersAction,
              deleteLabel: l10n.clinicalDeleteSelectedDiagnosesAction,
              onCancelSelected: null,
              onDeleteSelected: widget.onDeleteSelected,
              onCleared: () => setState(_selectedIds.clear),
            )
          : const <Widget>[],
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool allSelected =
              canMutate &&
              diagnoses.isNotEmpty &&
              diagnoses.every(
                (ClinicalRelatedRecord diagnosis) =>
                    _selectedIds.contains(diagnosis.id),
              );
          final bool someSelected =
              canMutate &&
              diagnoses.any(
                (ClinicalRelatedRecord diagnosis) =>
                    _selectedIds.contains(diagnosis.id),
              );

          return _ClinicalDetailDataTableContainer(
            minWidth: constraints.maxWidth,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 40,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 72,
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
                                diagnoses.map(
                                  (ClinicalRelatedRecord diagnosis) =>
                                      diagnosis.id,
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
                DataColumn(label: Text(l10n.clinicalPatientDiagnosesTitle)),
                DataColumn(label: Text(l10n.opdStatusColumnLabel)),
                DataColumn(label: Text(l10n.opdTimeColumnLabel)),
                if (canMutate)
                  DataColumn(label: Text(l10n.opdActionsColumnLabel)),
              ],
              rows: <DataRow>[
                for (final ClinicalRelatedRecord diagnosis in diagnoses)
                  DataRow(
                    selected: canMutate && _selectedIds.contains(diagnosis.id),
                    onSelectChanged: canMutate
                        ? (bool? value) {
                            setState(() {
                              if (value ?? false) {
                                _selectedIds.add(diagnosis.id);
                              } else {
                                _selectedIds.remove(diagnosis.id);
                              }
                            });
                          }
                        : null,
                    cells: <DataCell>[
                      if (canMutate)
                        DataCell(
                          Checkbox(
                            value: _selectedIds.contains(diagnosis.id),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value ?? false) {
                                  _selectedIds.add(diagnosis.id);
                                } else {
                                  _selectedIds.remove(diagnosis.id);
                                }
                              });
                            },
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      DataCell(
                        Text(
                          _joinDisplay(<String?>[
                            diagnosis.title,
                            diagnosis.subtitle,
                          ]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(
                        _hasText(diagnosis.status)
                            ? _ClinicalStatusBadge(status: diagnosis.status!)
                            : Text(l10n.clinicalOrderEmptyValueLabel),
                      ),
                      DataCell(
                        Text(_dateTimeLabel(context, diagnosis.occurredAt)),
                      ),
                      if (canMutate)
                        DataCell(
                          AppAccessActionGate(
                            requirement: clinicalEncounterWriteRequirement,
                            builder: (BuildContext context, bool isAllowed) {
                              if (!isAllowed) {
                                return const SizedBox.shrink();
                              }
                              return AppButton.tertiary(
                                dense: true,
                                leadingIcon: Icons.delete_outline,
                                label: l10n.clinicalDeleteDiagnosisAction,
                                semanticLabel:
                                    l10n.clinicalDeleteDiagnosisAction,
                                tooltip: l10n.clinicalDeleteDiagnosisAction,
                                color: theme.colorScheme.error,
                                onPressed: () =>
                                    widget.onDelete(context, diagnosis),
                              );
                            },
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

class _ClinicalLabOrderGroup extends StatelessWidget {
  const _ClinicalLabOrderGroup({
    required this.order,
    required this.compact,
    required this.selected,
    required this.expanded,
    required this.onToggleExpanded,
    this.onSelectedChanged,
    this.onEdit,
    this.onCancel,
    this.onDelete,
  });

  final ClinicalRelatedRecord order;
  final bool compact;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ClinicalOrderAction? onEdit;
  final ClinicalOrderAction? onCancel;
  final ClinicalOrderAction? onDelete;

  bool get _canMutate =>
      onEdit != null || onCancel != null || onDelete != null;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool hasChildTests = order.labOrderItems.isNotEmpty;
    final bool showSelection = onSelectedChanged != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Divider(height: 1),
        if (compact)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (showSelection)
                Padding(
                  padding: EdgeInsets.only(top: theme.spacing.sm),
                  child: Checkbox(
                    value: selected,
                    onChanged: (bool? value) =>
                        onSelectedChanged!(value ?? false),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              Expanded(
                child: _ClinicalLabOrderMobileCard(
                  order: order,
                  expandable: hasChildTests,
                  expanded: expanded,
                  onToggleExpanded: onToggleExpanded,
                  onEdit: onEdit,
                  onCancel: onCancel,
                  onDelete: onDelete,
                ),
              ),
            ],
          )
        else
          _ClinicalDetailDataTableContainer(
            child: DataTable(
              showCheckboxColumn: false,
              columns: <DataColumn>[
                if (showSelection) const DataColumn(label: SizedBox.shrink()),
                DataColumn(label: Text(l10n.clinicalOrderTestColumnLabel)),
                DataColumn(label: Text(l10n.clinicalOrderValueColumnLabel)),
                DataColumn(label: Text(l10n.opdStatusColumnLabel)),
                DataColumn(label: Text(l10n.clinicalResultFlagColumnLabel)),
                DataColumn(label: Text(l10n.opdTimeColumnLabel)),
                if (_canMutate)
                  DataColumn(label: Text(l10n.opdActionsColumnLabel)),
              ],
              rows: <DataRow>[
                _clinicalLabOrderDataRow(
                  context: context,
                  l10n: l10n,
                  order: order,
                  selected: selected,
                  onSelectedChanged: onSelectedChanged,
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
                      for (final ClinicalLabOrderItem item
                          in order.labOrderItems)
                        _ClinicalLabOrderItemMobileCard(
                          item: item,
                          orderStatus: order.status,
                        ),
                    ],
                  )
                : _ClinicalDetailDataTableContainer(
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
  required bool selected,
  ValueChanged<bool>? onSelectedChanged,
  required bool expandable,
  required bool expanded,
  required VoidCallback onToggleExpanded,
  ClinicalOrderAction? onEdit,
  ClinicalOrderAction? onCancel,
  ClinicalOrderAction? onDelete,
}) {
  final ThemeData theme = Theme.of(context);
  final String status = order.status ?? '';
  final String title = order.title ?? order.id;
  final bool showSelection = onSelectedChanged != null;
  final bool showActions = onEdit != null || onCancel != null || onDelete != null;

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
                  fontWeight: FontWeight.w600,
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
      if (showActions)
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
      DataCell(_ClinicalStatusBadge(status: order.status ?? '')),
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

class _ClinicalLabOrderMobileCard extends StatelessWidget {
  const _ClinicalLabOrderMobileCard({
    required this.order,
    required this.expandable,
    required this.expanded,
    required this.onToggleExpanded,
    this.onEdit,
    this.onCancel,
    this.onDelete,
  });

  final ClinicalRelatedRecord order;
  final bool expandable;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ClinicalOrderAction? onEdit;
  final ClinicalOrderAction? onCancel;
  final ClinicalOrderAction? onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool showActions =
        onEdit != null || onCancel != null || onDelete != null;
    return _ClinicalOrderMobileCard(
      title: order.title ?? order.id,
      value: _labOrderAggregateValue(context, order),
      status: order.status,
      resultFlag: _labOrderAggregateResultFlag(order),
      occurredAt: order.occurredAt,
      expandable: expandable,
      expanded: expanded,
      onToggleExpanded: onToggleExpanded,
      actions: showActions
          ? _labOrderActions(
              context: context,
              l10n: l10n,
              order: order,
              onEdit: onEdit,
              onCancel: onCancel,
              onDelete: onDelete,
            )
          : null,
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
                          fontWeight: FontWeight.w600,
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
            fontWeight: FontWeight.w600,
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

Widget _labOrderActions({
  required BuildContext context,
  required AppLocalizations l10n,
  required ClinicalRelatedRecord order,
  ClinicalOrderAction? onEdit,
  ClinicalOrderAction? onCancel,
  ClinicalOrderAction? onDelete,
}) {
  final ThemeData theme = Theme.of(context);
  final String status = order.status ?? '';
  final bool canEdit = onEdit != null && _canEditLabOrder(status);
  final bool canCancel = onCancel != null && _canCancelLabOrder(status);
  final bool canDelete =
      onDelete != null && !canCancel && _canDeleteLabOrder(status);

  if (!canEdit && !canCancel && !canDelete) {
    return const SizedBox.shrink();
  }

  return AppAccessActionGate(
    requirement: clinicalLabOrderWriteRequirement,
    builder: (BuildContext context, bool isAllowed) {
      if (!isAllowed) {
        return const SizedBox.shrink();
      }
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: <Widget>[
          if (canEdit)
            AppButton.secondary(
              dense: true,
              leadingIcon: Icons.edit_outlined,
              label: l10n.clinicalEditLabOrderAction,
              semanticLabel: l10n.clinicalEditLabOrderAction,
              tooltip: l10n.clinicalEditLabOrderAction,
              onPressed: () => onEdit(context, order),
            ),
          if (canCancel)
            AppButton.tertiary(
              dense: true,
              leadingIcon: Icons.block_outlined,
              label: l10n.clinicalCancelLabOrderAction,
              semanticLabel: l10n.clinicalCancelLabOrderAction,
              tooltip: l10n.clinicalCancelLabOrderAction,
              color: theme.colorScheme.tertiary,
              onPressed: () => onCancel(context, order),
            ),
          if (canDelete)
            AppButton.tertiary(
              dense: true,
              leadingIcon: Icons.delete_outline,
              label: l10n.clinicalDeleteLabOrderAction,
              semanticLabel: l10n.clinicalDeleteLabOrderAction,
              tooltip: l10n.clinicalDeleteLabOrderAction,
              color: theme.colorScheme.error,
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
      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
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
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
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
