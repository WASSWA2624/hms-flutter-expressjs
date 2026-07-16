import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
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
    super.key,
  });

  final IpdWorkspaceState state;
  final bool canManageBeds;
  final ValueChanged<IpdBedBoardEntry> onOpenAdmission;

  @override
  ConsumerState<IpdBedBoardPanel> createState() => _IpdBedBoardPanelState();
}

class _IpdBedBoardPanelState extends ConsumerState<IpdBedBoardPanel> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<IpdBedBoardEntry>
  _columnVisibilityController;
  String _search = '';

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
    final IpdWorkspaceState state = widget.state;
    final IpdWorkspaceController controller = ref.read(
      ipdWorkspaceControllerProvider.notifier,
    );

    final List<IpdBedBoardEntry> beds = state.bedBoard
        .where((IpdBedBoardEntry bed) => bed.matchesSearch(_search))
        .toList(growable: false);

    return AppListTable<IpdBedBoardEntry>(
      items: beds,
      isLoading: state.isLoadingBedBoard,
      itemKeyBuilder: (IpdBedBoardEntry bed) => ValueKey<String>(bed.id),
      columnVisibilityController: _columnVisibilityController,
      columnVisibilityStorageKey: 'ipd_bed_board',
      columnWidthStorageKey: 'ipd_bed_board_cw',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      search: AppListTableSearch<IpdBedBoardEntry>(
        controller: _searchController,
        semanticLabel: l10n.ipdBedBoardSearchLabel,
        hintText: l10n.ipdBedBoardSearchHint,
        matcher: (_, _) => true,
        onSubmitted: (String value) => setState(() => _search = value),
        onChanged: (String value) => setState(() => _search = value),
        onClear: () => setState(() => _search = ''),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.ipdFiltersLabel,
        advancedFilterTitle: l10n.ipdFiltersLabel,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
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
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.ipdBedBoardEmptyTitle,
        body: l10n.ipdBedBoardEmptyBody,
        icon: Icons.bed_outlined,
      ),
      columns: <AppListTableColumn<IpdBedBoardEntry>>[
        AppListTableColumn<IpdBedBoardEntry>(
          label: l10n.ipdBedColumnLabel,
          sortComparator: (IpdBedBoardEntry a, IpdBedBoardEntry b) =>
              appListTableCompareText(a.bedLabel, b.bedLabel),
          cellBuilder: (BuildContext context, IpdBedBoardEntry bed) {
            return Text(
              bed.bedLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            );
          },
        ),
        AppListTableColumn<IpdBedBoardEntry>(
          label: l10n.ipdWardColumnLabel,
          sortComparator: (IpdBedBoardEntry a, IpdBedBoardEntry b) =>
              appListTableCompareText(a.wardDisplayName, b.wardDisplayName),
          cellBuilder: (BuildContext context, IpdBedBoardEntry bed) {
            return Text(
              bed.wardDisplayName ?? context.l10n.profileUnknownValue,
            );
          },
        ),
        AppListTableColumn<IpdBedBoardEntry>(
          label: l10n.ipdRoomColumnLabel,
          cellBuilder: (BuildContext context, IpdBedBoardEntry bed) {
            return Text(
              bed.roomDisplayName ?? context.l10n.profileUnknownValue,
            );
          },
        ),
        AppListTableColumn<IpdBedBoardEntry>(
          label: l10n.opdStatusColumnLabel,
          sortComparator: (IpdBedBoardEntry a, IpdBedBoardEntry b) =>
              appListTableCompareText(a.status, b.status),
          cellBuilder: (BuildContext context, IpdBedBoardEntry bed) {
            return AppWorkspaceStatusBadge(
              status: AppWorkspaceStatus(
                label: bedStatusLabel(context, bed.status),
                tone: _bedStatusTone(bed.status),
              ),
            );
          },
        ),
        AppListTableColumn<IpdBedBoardEntry>(
          label: l10n.ipdCurrentPatientColumnLabel,
          cellBuilder: (BuildContext context, IpdBedBoardEntry bed) {
            if (bed.occupantPatientName == null &&
                bed.occupantAdmissionDisplayId == null) {
              return const Text('—');
            }
            return _BedOccupantCell(bed: bed);
          },
        ),
        AppListTableColumn<IpdBedBoardEntry>(
          label: l10n.ipdNextActionColumnLabel,
          cellBuilder: (BuildContext context, IpdBedBoardEntry bed) {
            return _BedActionMenu(
              bed: bed,
              canManageBeds: widget.canManageBeds,
              enabled: !state.isSaving,
              onAction: (_BedAction action) =>
                  _runAction(context, controller, bed, action),
            );
          },
        ),
      ],
      mobileItemBuilder: (BuildContext context, IpdBedBoardEntry bed) {
        return _BedBoardMobileRow(
          bed: bed,
          canManageBeds: widget.canManageBeds,
          enabled: !state.isSaving,
          onAction: (_BedAction action) =>
              _runAction(context, controller, bed, action),
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
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          bed.occupantPatientName ?? context.l10n.profileUnknownValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (bed.occupantAdmissionDisplayId != null)
          Text(
            bed.occupantAdmissionDisplayId!,
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
    final List<_BedAction> actions = _bedActionsFor(
      context,
      bed,
      canManageBeds,
    );
    if (actions.isEmpty) {
      return Text(
        context.l10n.ipdBedNoActionLabel,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  const SizedBox(width: 8),
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );
  }
}

class _BedBoardMobileRow extends StatelessWidget {
  const _BedBoardMobileRow({
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
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  bed.bedLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              AppWorkspaceStatusBadge(
                status: AppWorkspaceStatus(
                  label: bedStatusLabel(context, bed.status),
                  tone: _bedStatusTone(bed.status),
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            <String?>[
                  bed.wardDisplayName,
                  bed.roomDisplayName,
                  bed.occupantPatientName,
                ]
                .where(
                  (String? value) => value != null && value.trim().isNotEmpty,
                )
                .join(' • '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: _BedActionMenu(
              bed: bed,
              canManageBeds: canManageBeds,
              enabled: enabled,
              onAction: onAction,
            ),
          ),
        ],
      ),
    );
  }
}

const String _wardFilterKey = 'ward';
const String _statusFilterKey = 'status';

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
  final List<_BedAction> actions = <_BedAction>[];

  if (bed.occupantAdmissionId != null) {
    actions.add(
      _BedAction(
        label: l10n.ipdBedActionOpenAdmission,
        icon: Icons.open_in_new,
        status: null,
        isPrimary: true,
      ),
    );
  }

  if (!canManageBeds) {
    return actions;
  }

  switch ((bed.status ?? '').toUpperCase()) {
    case 'AVAILABLE':
      actions.addAll(<_BedAction>[
        _BedAction(
          label: l10n.ipdBedActionReserve,
          icon: Icons.event_available_outlined,
          status: 'RESERVED',
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
      // discharge / release-bed flow, surfaced via "Open admission".
      break;
    case 'RESERVED':
      actions.add(
        _BedAction(
          label: l10n.ipdBedActionMarkAvailable,
          icon: Icons.check_circle_outline,
          status: 'AVAILABLE',
        ),
      );
      break;
    case 'CLEANING':
      actions.add(
        _BedAction(
          label: l10n.ipdBedActionMarkAvailable,
          icon: Icons.check_circle_outline,
          status: 'AVAILABLE',
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
