import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

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
    BedSetupStatus.occupied => item.hasOpenTransfer
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

String roomsBedsTransferActionForStatus(String? transferStatus) {
  return switch ((transferStatus ?? '').trim().toUpperCase()) {
    'APPROVED' => 'START',
    'IN_PROGRESS' => 'COMPLETE',
    _ => 'APPROVE',
  };
}

bool roomsBedsTransferRequiresDestinationBed(String action) {
  return action.trim().toUpperCase() == 'COMPLETE';
}
