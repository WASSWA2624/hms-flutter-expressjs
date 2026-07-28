import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

enum RoomsBedsNextActionKind {
  assign,
  release,
  completeTransfer,
  markAvailable,
  openHousekeeping,
  openOperations,
  viewDetail,
}

String roomsBedsStatusLabel(AppLocalizations l10n, BedSetupStatus status) {
  return switch (status) {
    BedSetupStatus.available => l10n.tenantFacilityBedStatusAvailable,
    BedSetupStatus.occupied => l10n.tenantFacilityBedStatusOccupied,
    BedSetupStatus.reserved => l10n.tenantFacilityBedStatusReserved,
    BedSetupStatus.cleaning => l10n.tenantFacilityBedStatusCleaning,
    BedSetupStatus.maintenance => l10n.tenantFacilityBedStatusMaintenance,
    BedSetupStatus.blocked => l10n.tenantFacilityBedStatusBlocked,
    BedSetupStatus.outOfService => l10n.tenantFacilityBedStatusOutOfService,
  };
}

AppWorkspaceStatusTone roomsBedsStatusTone(BedSetupStatus status) {
  return switch (status) {
    BedSetupStatus.available => AppWorkspaceStatusTone.success,
    BedSetupStatus.occupied => AppWorkspaceStatusTone.info,
    BedSetupStatus.reserved => AppWorkspaceStatusTone.warning,
    BedSetupStatus.cleaning => AppWorkspaceStatusTone.warning,
    BedSetupStatus.maintenance => AppWorkspaceStatusTone.error,
    BedSetupStatus.blocked => AppWorkspaceStatusTone.error,
    BedSetupStatus.outOfService => AppWorkspaceStatusTone.error,
  };
}

IconData roomsBedsStatusIcon(BedSetupStatus status) {
  return switch (status) {
    BedSetupStatus.available => Icons.check_circle_outline,
    BedSetupStatus.occupied => Icons.person_pin_circle_outlined,
    BedSetupStatus.reserved => Icons.event_available_outlined,
    BedSetupStatus.cleaning => Icons.cleaning_services_outlined,
    BedSetupStatus.maintenance => Icons.build_outlined,
    BedSetupStatus.blocked => Icons.block_outlined,
    BedSetupStatus.outOfService => Icons.block_outlined,
  };
}

AppWorkspaceStatus roomsBedsStatusBadge(
  AppLocalizations l10n,
  BedSetupStatus status,
) {
  return AppWorkspaceStatus(
    label: roomsBedsStatusLabel(l10n, status),
    tone: roomsBedsStatusTone(status),
    icon: roomsBedsStatusIcon(status),
  );
}

String roomsBedsNextActionLabel(AppLocalizations l10n, BedBoardItem item) {
  return switch (item.status) {
    BedSetupStatus.available => l10n.roomsBedsNextActionAssign,
    BedSetupStatus.occupied =>
      item.hasOpenTransfer
          ? l10n.roomsBedsNextActionCompleteTransfer
          : l10n.roomsBedsNextActionReleaseOrTransfer,
    BedSetupStatus.reserved => l10n.roomsBedsNextActionAssignOrReleaseHold,
    BedSetupStatus.cleaning => l10n.roomsBedsNextActionMarkAvailable,
    BedSetupStatus.maintenance => l10n.roomsBedsNextActionResolveMaintenance,
    BedSetupStatus.blocked => l10n.roomsBedsNextActionResolveBlock,
    BedSetupStatus.outOfService => l10n.roomsBedsNextActionResolveBlock,
  };
}

String roomsBedsReadinessLabel(AppLocalizations l10n, BedBoardItem item) {
  return switch (item.status) {
    BedSetupStatus.available => l10n.roomsBedsReadyLabel,
    BedSetupStatus.cleaning => l10n.roomsBedsCleaningReadinessLabel,
    BedSetupStatus.maintenance => l10n.roomsBedsMaintenanceReadinessLabel,
    BedSetupStatus.blocked => l10n.roomsBedsBlockedReadinessLabel,
    BedSetupStatus.outOfService => l10n.roomsBedsUnavailableLabel,
    BedSetupStatus.occupied => l10n.roomsBedsOccupiedReadinessLabel,
    BedSetupStatus.reserved => l10n.roomsBedsReservedReadinessLabel,
  };
}

List<AppSearchBarFilterChoice> roomsBedsStatusFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    for (final BedSetupStatus status in BedSetupStatus.values)
      AppSearchBarFilterChoice(
        value: status.apiValue,
        label: roomsBedsStatusLabel(l10n, status),
        icon: roomsBedsStatusIcon(status),
      ),
  ];
}

BedSetupStatus? roomsBedsStatusFromFilter(String? value) {
  if (value == null) {
    return null;
  }
  for (final BedSetupStatus status in BedSetupStatus.values) {
    if (status.apiValue == value) {
      return status;
    }
  }
  return null;
}

bool roomsBedsSectionMatchesStatus(
  RoomsBedsSection section,
  BedSetupStatus status,
) {
  return switch (section) {
    RoomsBedsSection.all => true,
    RoomsBedsSection.available => status == BedSetupStatus.available,
    RoomsBedsSection.occupied => status == BedSetupStatus.occupied,
    RoomsBedsSection.turnover =>
      status == BedSetupStatus.reserved ||
          status == BedSetupStatus.cleaning ||
          status == BedSetupStatus.maintenance,
    RoomsBedsSection.outOfService =>
      status == BedSetupStatus.blocked || status == BedSetupStatus.outOfService,
  };
}

int roomsBedsSectionCount(
  RoomsBedsWorkspaceState state,
  RoomsBedsSection section,
) {
  return switch (section) {
    RoomsBedsSection.all => state.totalBedCount,
    RoomsBedsSection.available => state.availableCount,
    RoomsBedsSection.occupied => state.occupiedCount,
    RoomsBedsSection.turnover =>
      state.reservedCount + state.cleaningCount + state.maintenanceCount,
    RoomsBedsSection.outOfService => state.blockedCount,
  };
}

AppPage<BedBoardItem> roomsBedsSectionFilteredPage(
  AppPage<BedBoardItem> page,
  RoomsBedsSection section,
) {
  if (section == RoomsBedsSection.all) {
    return page;
  }
  final List<BedBoardItem> filtered = page.items
      .where(
        (BedBoardItem item) =>
            roomsBedsSectionMatchesStatus(section, item.status),
      )
      .toList(growable: false);
  return AppPage<BedBoardItem>(
    items: filtered,
    request: page.request,
    totalItemCount: filtered.length,
  );
}

RoomsBedsNextActionKind roomsBedsPrimaryNextActionKind(BedBoardItem item) {
  return switch (item.status) {
    BedSetupStatus.available => RoomsBedsNextActionKind.assign,
    BedSetupStatus.occupied =>
      item.hasOpenTransfer
          ? RoomsBedsNextActionKind.completeTransfer
          : RoomsBedsNextActionKind.release,
    BedSetupStatus.reserved => RoomsBedsNextActionKind.markAvailable,
    BedSetupStatus.cleaning => RoomsBedsNextActionKind.markAvailable,
    BedSetupStatus.maintenance => RoomsBedsNextActionKind.openOperations,
    BedSetupStatus.blocked => RoomsBedsNextActionKind.markAvailable,
    BedSetupStatus.outOfService => RoomsBedsNextActionKind.openOperations,
  };
}

bool roomsBedsNextActionIsAuthorized({
  required RoomsBedsNextActionKind kind,
  required bool canAdminBeds,
  required bool canIpdWrite,
}) {
  return switch (kind) {
    RoomsBedsNextActionKind.assign ||
    RoomsBedsNextActionKind.release ||
    RoomsBedsNextActionKind.completeTransfer => canIpdWrite,
    RoomsBedsNextActionKind.markAvailable ||
    RoomsBedsNextActionKind.openHousekeeping ||
    RoomsBedsNextActionKind.openOperations => canAdminBeds,
    RoomsBedsNextActionKind.viewDetail => true,
  };
}

/// Authorized board primary; falls back to view-detail when the stage write is
/// unauthorized so disabled lock chrome never appears for missing permissions.
RoomsBedsNextActionKind roomsBedsResolvedNextActionKind({
  required BedBoardItem item,
  required bool canAdminBeds,
  required bool canIpdWrite,
}) {
  final RoomsBedsNextActionKind kind = roomsBedsPrimaryNextActionKind(item);
  if (roomsBedsNextActionIsAuthorized(
    kind: kind,
    canAdminBeds: canAdminBeds,
    canIpdWrite: canIpdWrite,
  )) {
    return kind;
  }
  return RoomsBedsNextActionKind.viewDetail;
}

String roomsBedsNextActionKindLabel(
  AppLocalizations l10n,
  RoomsBedsNextActionKind kind,
) {
  return switch (kind) {
    RoomsBedsNextActionKind.assign => l10n.roomsBedsAssignAction,
    RoomsBedsNextActionKind.release => l10n.roomsBedsReleaseAction,
    RoomsBedsNextActionKind.completeTransfer =>
      l10n.roomsBedsManageTransferAction,
    RoomsBedsNextActionKind.markAvailable => l10n.roomsBedsMarkAvailableAction,
    RoomsBedsNextActionKind.openHousekeeping =>
      l10n.roomsBedsOpenHousekeepingAction,
    RoomsBedsNextActionKind.openOperations =>
      l10n.roomsBedsOpenOperationsAction,
    RoomsBedsNextActionKind.viewDetail => l10n.roomsBedsDetailTitle,
  };
}

String roomsBedsPrimaryNextActionLabel(
  AppLocalizations l10n,
  BedBoardItem item, {
  bool canAdminBeds = true,
  bool canIpdWrite = true,
}) {
  return roomsBedsNextActionKindLabel(
    l10n,
    roomsBedsResolvedNextActionKind(
      item: item,
      canAdminBeds: canAdminBeds,
      canIpdWrite: canIpdWrite,
    ),
  );
}

String roomsBedsLocationLabel(AppLocalizations l10n, BedBoardItem item) {
  final String joined = _roomsBedsJoinDisplay(<String?>[
    item.ward?.name,
    item.room?.name,
    item.room?.floor,
  ]);
  return joined.isEmpty ? l10n.profileUnknownValue : joined;
}

String roomsBedsAssignmentLabel(AppLocalizations l10n, BedBoardItem item) {
  final String? admissionId = _roomsBedsReadableDisplayText(
    item.currentAdmissionDisplayId,
  );
  if (admissionId != null) {
    return l10n.roomsBedsAdmissionAssignment(admissionId);
  }
  if (item.currentAdmissionId != null) {
    return l10n.roomsBedsCurrentAssignmentLabel;
  }
  if (item.isOccupied || item.isReserved) {
    return l10n.roomsBedsAssignmentNotLinked;
  }
  return l10n.profileUnknownValue;
}

bool Function(BedBoardItem, String) roomsBedsBedBoardSearchMatcher(
  AppLocalizations l10n,
) {
  return (BedBoardItem item, String query) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }
    return <String?>[
      item.id,
      item.label,
      item.facility?.name,
      item.ward?.name,
      item.room?.name,
      item.room?.floor,
      item.currentAdmissionDisplayId,
      item.currentAdmissionId,
      item.status.apiValue,
      roomsBedsStatusLabel(l10n, item.status),
      roomsBedsReadinessLabel(l10n, item),
      roomsBedsPrimaryNextActionLabel(l10n, item),
      roomsBedsAssignmentLabel(l10n, item),
      roomsBedsLocationLabel(l10n, item),
    ].whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  };
}

typedef RoomsBedsNextActionCellBuilder =
    Widget Function(BuildContext context, BedBoardItem item);

List<AppListTableColumn<BedBoardItem>> roomsBedsBedBoardColumns({
  required AppLocalizations l10n,
  required RoomsBedsNextActionCellBuilder nextActionCellBuilder,
}) {
  return <AppListTableColumn<BedBoardItem>>[
    AppListTableColumn<BedBoardItem>(
      id: 'bed',
      label: l10n.roomsBedsBedColumnLabel,
      sortComparator: (BedBoardItem left, BedBoardItem right) {
        return appListTableCompareText(left.label, right.label);
      },
      cellBuilder: (BuildContext context, BedBoardItem item) {
        return AppListItemText(title: item.label);
      },
    ),
    AppListTableColumn<BedBoardItem>(
      id: 'location',
      label: l10n.roomsBedsLocationColumnLabel,
      sortComparator: (BedBoardItem left, BedBoardItem right) {
        return appListTableCompareText(
          roomsBedsLocationLabel(l10n, left),
          roomsBedsLocationLabel(l10n, right),
        );
      },
      cellBuilder: (BuildContext context, BedBoardItem item) {
        return Text(roomsBedsLocationLabel(l10n, item));
      },
    ),
    AppListTableColumn<BedBoardItem>(
      id: 'assignment',
      label: l10n.roomsBedsAssignmentColumnLabel,
      sortComparator: (BedBoardItem left, BedBoardItem right) {
        return appListTableCompareText(
          roomsBedsAssignmentLabel(l10n, left),
          roomsBedsAssignmentLabel(l10n, right),
        );
      },
      cellBuilder: (BuildContext context, BedBoardItem item) {
        return Text(roomsBedsAssignmentLabel(l10n, item));
      },
    ),
    AppListTableColumn<BedBoardItem>(
      id: 'status',
      label: l10n.roomsBedsStatusColumnLabel,
      sortComparator: (BedBoardItem left, BedBoardItem right) {
        return appListTableCompareText(
          left.status.apiValue,
          right.status.apiValue,
        );
      },
      cellBuilder: (BuildContext context, BedBoardItem item) {
        return AppWorkspaceStatusBadge(
          status: roomsBedsStatusBadge(l10n, item.status),
        );
      },
    ),
    AppListTableColumn<BedBoardItem>(
      id: 'next_action',
      label: l10n.roomsBedsNextActionColumnLabel,
      alwaysVisible: true,
      sortComparator: (BedBoardItem left, BedBoardItem right) {
        return appListTableCompareText(
          roomsBedsPrimaryNextActionLabel(l10n, left),
          roomsBedsPrimaryNextActionLabel(l10n, right),
        );
      },
      cellBuilder: nextActionCellBuilder,
    ),
  ];
}

List<AppListTableColumn<BedBoardItem>> roomsBedsBedBoardColumnChoices(
  AppLocalizations l10n,
) {
  return <AppListTableColumn<BedBoardItem>>[
    AppListTableColumn<BedBoardItem>(
      id: 'facility',
      label: l10n.roomsBedsFacilityFilterLabel,
      sortComparator: (BedBoardItem left, BedBoardItem right) {
        return appListTableCompareText(
          left.facility?.name,
          right.facility?.name,
        );
      },
      cellBuilder: (BuildContext context, BedBoardItem item) {
        return Text(item.facility?.name ?? l10n.profileUnknownValue);
      },
    ),
    AppListTableColumn<BedBoardItem>(
      id: 'readiness',
      label: l10n.roomsBedsReadinessLabel,
      sortComparator: (BedBoardItem left, BedBoardItem right) {
        return appListTableCompareText(
          roomsBedsReadinessLabel(l10n, left),
          roomsBedsReadinessLabel(l10n, right),
        );
      },
      cellBuilder: (BuildContext context, BedBoardItem item) {
        return Text(roomsBedsReadinessLabel(l10n, item));
      },
    ),
    AppListTableColumn<BedBoardItem>(
      id: 'room_floor',
      label: l10n.roomsBedsFloorColumnLabel,
      sortComparator: (BedBoardItem left, BedBoardItem right) {
        return appListTableCompareText(left.room?.floor, right.room?.floor);
      },
      cellBuilder: (BuildContext context, BedBoardItem item) {
        return Text(item.room?.floor ?? l10n.profileUnknownValue);
      },
    ),
  ];
}

String _roomsBedsJoinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

String? _roomsBedsReadableDisplayText(String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty || _roomsBedsIsNonHumanReadableId(normalized)) {
    return null;
  }
  return normalized;
}

bool _roomsBedsIsNonHumanReadableId(String value) {
  return _roomsBedsUuidPattern.hasMatch(value) ||
      _roomsBedsLongHexPattern.hasMatch(value);
}

final RegExp _roomsBedsUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final RegExp _roomsBedsLongHexPattern = RegExp(r'^[0-9a-fA-F]{24,}$');
