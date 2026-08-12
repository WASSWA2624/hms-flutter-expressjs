import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_workspace_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Bed action descriptor for the bed board next-action menu.
class _BedAction {
  const _BedAction({
    required this.label,
    required this.icon,
    required this.status,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;

  /// Target bed status (`null` means open the occupant admission).
  final String? status;
  final bool isPrimary;
}

/// Live ward bed occupancy board with bed operations (flow §14.2).
class IpdBedBoardPanel extends ConsumerStatefulWidget {
  const IpdBedBoardPanel({
    required this.state,
    required this.canManageBeds,
    required this.onOpenAdmission,
    this.onStartAdmission,
    super.key,
  });

  final IpdWorkspaceState state;
  final bool canManageBeds;
  final ValueChanged<IpdBedBoardEntry> onOpenAdmission;
  final VoidCallback? onStartAdmission;

  @override
  ConsumerState<IpdBedBoardPanel> createState() => _IpdBedBoardPanelState();
}

class _IpdBedBoardPanelState extends ConsumerState<IpdBedBoardPanel> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<IpdBedBoardEntry>
  _columnVisibilityController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _columnVisibilityController =
        AppListTableColumnVisibilityController<IpdBedBoardEntry>();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _columnVisibilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final IpdWorkspaceState state = widget.state;
    final IpdWorkspaceController controller = ref.read(
      ipdWorkspaceControllerProvider.notifier,
    );

    final ({
      List<AppListTableColumn<IpdBedBoardEntry>> defaults,
      List<AppListTableColumn<IpdBedBoardEntry>> choices,
    }) columns = _ipdBedBoardColumns(
      context,
      canManageBeds: widget.canManageBeds,
      enabled: !state.isSaving,
      onAction: (_BedAction action, IpdBedBoardEntry bed) =>
          _runAction(context, controller, bed, action),
    );
    return AppListTable<IpdBedBoardEntry>(
      items: state.bedBoard,
      isLoading: state.isLoadingBedBoard,
      itemKeyBuilder: (IpdBedBoardEntry bed) => ValueKey<String>(bed.id),
      columnVisibilityController: _columnVisibilityController,
      columnVisibilityStorageKey: 'ipd_bed_board',
      columnWidthStorageKey: 'ipd_bed_board_cw',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columnVisibilityApplyLabel: l10n.receptionApplyColumnsAction,
      columnVisibilityResetLabel: l10n.receptionResetColumnsAction,
      columnVisibilityCloseLabel: l10n.commonCloseActionLabel,
      columns: columns.defaults,
      columnChoices: columns.choices,
      onRowSelected: (IpdBedBoardEntry bed) {
        if (bed.occupantAdmissionId != null) {
          widget.onOpenAdmission(bed);
        }
      },
      search: AppListTableSearch<IpdBedBoardEntry>(
        controller: _searchController,
        semanticLabel: l10n.ipdBedBoardSearchLabel,
        hintText: l10n.ipdBedBoardSearchHint,
        matcher: (IpdBedBoardEntry bed, String query) =>
            bed.matchesSearch(query),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        advancedFilterCloseLabel: l10n.commonCloseActionLabel,
        enableDateFilter: false,
        allFieldsLabel: l10n.ipdAllWardsOption,
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _wardFilterKey,
            label: l10n.ipdWardFilterLabel,
            allLabel: l10n.ipdAllWardsOption,
            choices: <AppSearchBarFilterChoice>[
              for (final IpdWardOption ward in state.referenceData.wards)
                AppSearchBarFilterChoice(
                  value: ward.id,
                  label: ward.displayTitle,
                  icon: Icons.local_hospital_outlined,
                ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _statusFilterKey,
            label: l10n.ipdBedStatusFilterLabel,
            allLabel: l10n.ipdScopeAll,
            choices: <AppSearchBarFilterChoice>[
              for (final String status in _bedStatuses)
                AppSearchBarFilterChoice(
                  value: status,
                  label: bedStatusLabel(context, status),
                  icon: Icons.filter_list,
                ),
            ],
          ),
        ],
        filterValue: AppSearchBarFilterValue(
          options: <String, String>{
            if (state.bedBoardWardId != null)
              _wardFilterKey: state.bedBoardWardId!,
            if (state.bedBoardStatus != null)
              _statusFilterKey: state.bedBoardStatus!,
          },
        ),
        hasActiveFilters:
            state.bedBoardWardId != null || state.bedBoardStatus != null,
        onFilterChanged: (AppSearchBarFilterValue value) async {
          final String? nextWard = value.option(_wardFilterKey);
          final String? nextStatus = value.option(_statusFilterKey);
          AppFailure? failure;
          if (nextWard != state.bedBoardWardId) {
            failure = await controller.applyBedBoardWard(nextWard);
          }
          if (nextStatus != state.bedBoardStatus) {
            failure ??= await controller.applyBedBoardStatus(nextStatus);
          }
          if (context.mounted) {
            _showFailure(context, failure);
          }
        },
        // Filters → Settings → Export → Print → Start admission.
        trailingActions: <AppSearchBarAction>[
          if (widget.onStartAdmission != null)
            AppSearchBarAction(
              icon: Icons.person_add_alt_1_outlined,
              label: l10n.ipdStartAdmissionAction,
              tooltip: l10n.ipdStartAdmissionAction,
              enabled: !state.isSaving,
              onPressed: widget.onStartAdmission!,
            ),
        ],
      ),
      enableExport: true,
      canExport: canExportIpdWorkspace(policy),
      exportLabel: l10n.commonTableExportActionLabel,
      exportDialogTitle: l10n.commonTableExportDialogTitle,
      exportCancelLabel: l10n.commonCancelActionLabel,
      exportColumnsSectionLabel: l10n.commonTableExportColumnsSectionLabel,
      exportFiltersSectionLabel: l10n.commonTableExportFiltersSectionLabel,
      exportEmptyColumnsMessage: l10n.commonTableExportEmptyColumnsMessage,
      exportEmptyRowsMessage: l10n.commonTableExportEmptyRowsMessage,
      exportSuccessMessage: l10n.commonTableExportSuccessMessage,
      exportFailureMessage: l10n.commonTableExportFailureMessage,
      enablePrint: true,
      canPrint: canPrintIpdWorkspace(policy),
      printLabel: l10n.commonPrintActionLabel,
      onPrint: () => _printIpdBedBoardList(
        context,
        ref,
        state: state,
        canManageBeds: widget.canManageBeds,
        l10n: l10n,
      ),
      goToTopLabel: l10n.commonGoToTopActionLabel,
      loadingMoreLabel: l10n.commonLoadingMoreLabel,
      allRowsLoadedLabel: l10n.commonAllRowsLoadedLabel,
      exportConfig: AppListTableExportConfig<IpdBedBoardEntry>(
        fileNameStem: 'ipd_bed_board',
        sheetName: l10n.ipdBedBoardTab,
        dateFromLabel: l10n.commonTableExportDateFromLabel,
        dateToLabel: l10n.commonTableExportDateToLabel,
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.ipdBedBoardEmptyTitle,
        body: l10n.ipdBedBoardEmptyBody,
        icon: Icons.bed_outlined,
      ),
      mobileItemBuilder: (BuildContext context, IpdBedBoardEntry bed) {
        final String locationDetail = <String?>[
          bed.wardDisplayName,
          bed.roomDisplayName,
        ]
            .where((String? v) => v != null && v.trim().isNotEmpty)
            .join(' • ');
        return AppListTableMobileItem(
          title: bed.bedLabel,
          caption: bed.occupantPatientName,
          meta: <AppListTableMobileMeta>[
            if (locationDetail.isNotEmpty)
              AppListTableMobileMeta(label: locationDetail),
            AppListTableMobileMeta(
              label: bedStatusLabel(context, bed.status),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runAction(
    BuildContext context,
    IpdWorkspaceController controller,
    IpdBedBoardEntry bed,
    _BedAction action,
  ) async {
    if (action.status == null) {
      widget.onOpenAdmission(bed);
      return;
    }
    final AppFailure? failure = await controller.updateBedStatus(
      bed,
      action.status!,
    );
    if (context.mounted) {
      _showFailure(context, failure);
    }
  }
}

class _BedOccupantCell extends StatelessWidget {
  const _BedOccupantCell({required this.bed});

  final IpdBedBoardEntry bed;

  @override
  Widget build(BuildContext context) {
    return Text(
      bed.occupantPatientName ?? context.l10n.profileUnknownValue,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _BedActionMenu extends StatelessWidget {
  const _BedActionMenu({
    required this.bed,
    required this.canManageBeds,
    required this.enabled,
    required this.onAction,
  });

  final IpdBedBoardEntry bed;
  final bool canManageBeds;
  final bool enabled;
  final ValueChanged<_BedAction> onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_BedAction> actions = _bedActionsFor(
      context,
      bed,
      canManageBeds,
    );
    if (actions.isEmpty) {
      return Text(
        context.l10n.ipdBedNoActionLabel,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    if (actions.length == 1) {
      final _BedAction action = actions.first;
      return Semantics(
        button: true,
        enabled: enabled,
        label: action.label,
        child: Tooltip(
          message: action.label,
          child: InkWell(
            onTap: enabled ? () => onAction(action) : null,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(action.icon, size: 16, color: theme.colorScheme.primary),
                  SizedBox(width: theme.spacing.xs),
                  Flexible(
                    child: Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return PopupMenuButton<_BedAction>(
      enabled: enabled,
      tooltip: context.l10n.ipdNextActionColumnLabel,
      onSelected: onAction,
      itemBuilder: (BuildContext context) {
        return <PopupMenuEntry<_BedAction>>[
          for (final _BedAction action in actions)
            PopupMenuItem<_BedAction>(
              value: action,
              child: Row(
                children: <Widget>[
                  Icon(action.icon, size: 18),
                  SizedBox(width: theme.spacing.sm),
                  Text(action.label),
                ],
              ),
            ),
        ];
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              actions.first.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );
  }
}

const String _wardFilterKey = 'ward';
const String _statusFilterKey = 'status';

({
  List<AppListTableColumn<IpdBedBoardEntry>> defaults,
  List<AppListTableColumn<IpdBedBoardEntry>> choices,
})
_ipdBedBoardColumns(
  BuildContext context, {
  required bool canManageBeds,
  required bool enabled,
  required void Function(_BedAction action, IpdBedBoardEntry bed) onAction,
}) {
  final AppListTableColumn<IpdBedBoardEntry> bed =
      _ipdBedBoardColumn(context, 'bed');
  final AppListTableColumn<IpdBedBoardEntry> ward =
      _ipdBedBoardColumn(context, 'ward');
  final AppListTableColumn<IpdBedBoardEntry> room =
      _ipdBedBoardColumn(context, 'room');
  final AppListTableColumn<IpdBedBoardEntry> patient =
      _ipdBedBoardColumn(context, 'current_patient');
  final AppListTableColumn<IpdBedBoardEntry> status =
      _ipdBedBoardColumn(context, 'status');
  final AppListTableColumn<IpdBedBoardEntry> admissionId =
      _ipdBedBoardColumn(context, 'admission_id');
  final AppListTableColumn<IpdBedBoardEntry>? nextAction = canManageBeds
      ? _ipdBedBoardColumn(
          context,
          'next_action',
          canManageBeds: canManageBeds,
          enabled: enabled,
          onAction: onAction,
        )
      : null;

  // Prefer ~5 defaults: when next-action is present, Room moves to optional.
  final List<AppListTableColumn<IpdBedBoardEntry>> defaults =
      <AppListTableColumn<IpdBedBoardEntry>>[
        bed,
        ward,
        if (nextAction == null) room,
        patient,
        status,
        if (nextAction != null) nextAction,
      ];
  final Set<String> defaultIds = defaults
      .map((AppListTableColumn<IpdBedBoardEntry> column) => column.key)
      .toSet();
  final List<AppListTableColumn<IpdBedBoardEntry>> choices =
      <AppListTableColumn<IpdBedBoardEntry>>[
        if (!defaultIds.contains(room.key)) room,
        if (!defaultIds.contains(admissionId.key)) admissionId,
      ];
  return (defaults: defaults, choices: choices);
}

AppListTableColumn<IpdBedBoardEntry> _ipdBedBoardColumn(
  BuildContext context,
  String id, {
  bool canManageBeds = false,
  bool enabled = true,
  void Function(_BedAction action, IpdBedBoardEntry bed)? onAction,
}) {
  final AppLocalizations l10n = context.l10n;
  return switch (id) {
    'bed' => AppListTableColumn<IpdBedBoardEntry>(
      id: 'bed',
      label: l10n.ipdBedColumnLabel,
      sortComparator: (IpdBedBoardEntry a, IpdBedBoardEntry b) =>
          appListTableCompareText(a.bedLabel, b.bedLabel),
      exportValue: (IpdBedBoardEntry bed) =>
          _ipdBedBoardPrintCellValue(context, bed, 'bed'),
      cellBuilder: (BuildContext context, IpdBedBoardEntry bed) {
        return Text(
          bed.bedLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    ),
    'ward' => AppListTableColumn<IpdBedBoardEntry>(
      id: 'ward',
      label: l10n.ipdWardColumnLabel,
      sortComparator: (IpdBedBoardEntry a, IpdBedBoardEntry b) =>
          appListTableCompareText(a.wardDisplayName, b.wardDisplayName),
      exportValue: (IpdBedBoardEntry bed) =>
          _ipdBedBoardPrintCellValue(context, bed, 'ward'),
      cellBuilder: (BuildContext context, IpdBedBoardEntry bed) {
        return Text(bed.wardDisplayName ?? context.l10n.profileUnknownValue);
      },
    ),
    'room' => AppListTableColumn<IpdBedBoardEntry>(
      id: 'room',
      label: l10n.ipdRoomColumnLabel,
      exportValue: (IpdBedBoardEntry bed) =>
          _ipdBedBoardPrintCellValue(context, bed, 'room'),
      cellBuilder: (BuildContext context, IpdBedBoardEntry bed) {
        return Text(bed.roomDisplayName ?? context.l10n.profileUnknownValue);
      },
    ),
    'current_patient' => AppListTableColumn<IpdBedBoardEntry>(
      id: 'current_patient',
      label: l10n.ipdCurrentPatientColumnLabel,
      exportValue: (IpdBedBoardEntry bed) =>
          _ipdBedBoardPrintCellValue(context, bed, 'current_patient'),
      cellBuilder: (BuildContext context, IpdBedBoardEntry bed) {
        return _BedOccupantCell(bed: bed);
      },
    ),
    'admission_id' => AppListTableColumn<IpdBedBoardEntry>(
      id: 'admission_id',
      label: l10n.ipdAdmissionIdLabel,
      exportValue: (IpdBedBoardEntry bed) =>
          _ipdBedBoardPrintCellValue(context, bed, 'admission_id'),
      cellBuilder: (BuildContext context, IpdBedBoardEntry bed) {
        return Text(
          bed.occupantAdmissionDisplayId ??
              context.l10n.profileUnknownValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    ),
    'status' => AppListTableColumn<IpdBedBoardEntry>(
      id: 'status',
      label: l10n.opdStatusColumnLabel,
      alwaysVisible: true,
      sortComparator: (IpdBedBoardEntry a, IpdBedBoardEntry b) =>
          appListTableCompareText(a.status, b.status),
      exportValue: (IpdBedBoardEntry bed) =>
          _ipdBedBoardPrintCellValue(context, bed, 'status'),
      cellBuilder: (BuildContext context, IpdBedBoardEntry bed) {
        return AppWorkspaceStatusBadge(
          status: AppWorkspaceStatus(
            label: bedStatusLabel(context, bed.status),
            tone: _bedStatusTone(bed.status),
          ),
        );
      },
    ),
    'next_action' => AppListTableColumn<IpdBedBoardEntry>(
      id: 'next_action',
      label: l10n.ipdNextActionColumnLabel,
      alwaysVisible: true,
      exportValue: (IpdBedBoardEntry bed) {
        final List<_BedAction> actions = _bedActionsFor(
          context,
          bed,
          canManageBeds,
        );
        return actions.isEmpty
            ? l10n.ipdBedNoActionLabel
            : actions.first.label;
      },
      cellBuilder: (BuildContext context, IpdBedBoardEntry bed) {
        return _BedActionMenu(
          bed: bed,
          canManageBeds: canManageBeds,
          enabled: enabled,
          onAction: (_BedAction action) => onAction!(action, bed),
        );
      },
    ),
    _ => throw ArgumentError.value(id, 'id', 'Unknown IPD bed board column'),
  };
}

Future<void> _printIpdBedBoardList(
  BuildContext context,
  WidgetRef ref, {
  required IpdWorkspaceState state,
  required bool canManageBeds,
  required AppLocalizations l10n,
}) async {
  final ({
    List<AppListTableColumn<IpdBedBoardEntry>> defaults,
    List<AppListTableColumn<IpdBedBoardEntry>> choices,
  }) resolved = _ipdBedBoardColumns(
    context,
    canManageBeds: canManageBeds,
    enabled: false,
    onAction: (_BedAction action, IpdBedBoardEntry bed) {},
  );
  final List<AppListTableColumn<IpdBedBoardEntry>> columns =
      <AppListTableColumn<IpdBedBoardEntry>>[
        ...resolved.defaults,
        ...resolved.choices,
      ].where(
        (AppListTableColumn<IpdBedBoardEntry> column) =>
            column.includesInExport,
      ).toList(growable: false);
  final List<IpdWorkspacePrintColumn> printColumns =
      <IpdWorkspacePrintColumn>[
        for (final AppListTableColumn<IpdBedBoardEntry> column in columns)
          IpdWorkspacePrintColumn(id: column.key, label: column.label),
      ];
  final List<Map<String, String>> printRows = <Map<String, String>>[
    for (final IpdBedBoardEntry bed in state.bedBoard)
      <String, String>{
        for (final AppListTableColumn<IpdBedBoardEntry> column in columns)
          column.key: _ipdBedBoardPrintCellValue(context, bed, column.key),
      },
  ];
  await printIpdWorkspaceList(
    ref: ref,
    context: context,
    title: l10n.ipdBedBoardTab,
    columns: printColumns,
    rows: printRows,
    emptyText: l10n.ipdBedBoardEmptyTitle,
  );
}

String _ipdBedBoardPrintCellValue(
  BuildContext context,
  IpdBedBoardEntry bed,
  String columnId,
) {
  final AppLocalizations l10n = context.l10n;
  return switch (columnId) {
    'bed' => bed.bedLabel,
    'ward' => bed.wardDisplayName ?? l10n.profileUnknownValue,
    'current_patient' =>
      bed.occupantPatientName ?? l10n.profileUnknownValue,
    'admission_id' =>
      bed.occupantAdmissionDisplayId ?? l10n.profileUnknownValue,
    'status' => bedStatusLabel(context, bed.status),
    'room' => bed.roomDisplayName ?? l10n.profileUnknownValue,
    _ => '',
  };
}

const List<String> _bedStatuses = <String>[
  'AVAILABLE',
  'OCCUPIED',
  'RESERVED',
  'CLEANING',
  'MAINTENANCE',
  'BLOCKED',
  'OUT_OF_SERVICE',
];

List<_BedAction> _bedActionsFor(
  BuildContext context,
  IpdBedBoardEntry bed,
  bool canManageBeds,
) {
  final AppLocalizations l10n = context.l10n;
  if (!canManageBeds) {
    return const <_BedAction>[];
  }

  final List<_BedAction> actions = <_BedAction>[];

  switch ((bed.status ?? '').toUpperCase()) {
    case 'AVAILABLE':
      actions.addAll(<_BedAction>[
        _BedAction(
          label: l10n.ipdBedActionReserve,
          icon: Icons.event_available_outlined,
          status: 'RESERVED',
          isPrimary: true,
        ),
        _BedAction(
          label: l10n.ipdBedActionBlock,
          icon: Icons.block,
          status: 'BLOCKED',
        ),
        _BedAction(
          label: l10n.ipdBedActionMaintenance,
          icon: Icons.build_outlined,
          status: 'MAINTENANCE',
        ),
      ]);
      break;
    case 'OCCUPIED':
      // Bed release for occupied beds is performed through the admission
      // discharge / release-bed flow. Open the admission via row select.
      break;
    case 'RESERVED':
      actions.add(
        _BedAction(
          label: l10n.ipdBedActionMarkAvailable,
          icon: Icons.check_circle_outline,
          status: 'AVAILABLE',
          isPrimary: true,
        ),
      );
      break;
    case 'CLEANING':
      actions.add(
        _BedAction(
          label: l10n.ipdBedActionMarkAvailable,
          icon: Icons.check_circle_outline,
          status: 'AVAILABLE',
          isPrimary: true,
        ),
      );
      break;
    case 'MAINTENANCE':
    case 'BLOCKED':
    case 'OUT_OF_SERVICE':
      actions.add(
        _BedAction(
          label: l10n.ipdBedActionReturnToService,
          icon: Icons.restart_alt,
          status: 'AVAILABLE',
          isPrimary: true,
        ),
      );
      break;
    default:
      break;
  }

  return actions;
}

AppWorkspaceStatusTone _bedStatusTone(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'AVAILABLE' => AppWorkspaceStatusTone.success,
    'OCCUPIED' => AppWorkspaceStatusTone.info,
    'RESERVED' => AppWorkspaceStatusTone.warning,
    'CLEANING' => AppWorkspaceStatusTone.warning,
    'MAINTENANCE' => AppWorkspaceStatusTone.neutral,
    'BLOCKED' => AppWorkspaceStatusTone.error,
    'OUT_OF_SERVICE' => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

/// Public so the workspace page can reuse the same labels.
String bedStatusLabel(BuildContext context, String? status) {
  final AppLocalizations l10n = context.l10n;
  return switch ((status ?? '').toUpperCase()) {
    'AVAILABLE' => l10n.ipdBedStatusAvailable,
    'OCCUPIED' => l10n.ipdBedStatusOccupied,
    'RESERVED' => l10n.ipdBedStatusReserved,
    'CLEANING' => l10n.ipdBedStatusCleaning,
    'MAINTENANCE' => l10n.ipdBedStatusMaintenance,
    'BLOCKED' => l10n.ipdBedStatusBlocked,
    'OUT_OF_SERVICE' => l10n.ipdBedStatusOutOfService,
    _ => l10n.profileUnknownValue,
  };
}

void _showFailure(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}
