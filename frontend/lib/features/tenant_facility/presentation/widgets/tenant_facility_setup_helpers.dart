import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_slug.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

const String tenantFacilityNoneSelection = '__none__';

/// Builds a short, OS-safe facility logo basename (≤ 32 chars incl. extension).
///
/// Example: `logo-4869585d.png`
String buildFacilityLogoFileName(String facilityName, {String extension = 'png'}) {
  const int maxBasename = 32;
  final String normalizedExt = extension.startsWith('.')
      ? extension.toLowerCase()
      : '.${extension.toLowerCase()}';
  final String slug = slugify(facilityName).replaceAll(RegExp(r'[^a-z0-9]'), '');
  final String suffix = (slug.isEmpty ? 'facility' : slug)
      .substring(0, math.min(8, (slug.isEmpty ? 'facility' : slug).length));
  final String candidate = 'logo-$suffix$normalizedExt';
  if (candidate.length <= maxBasename) {
    return candidate;
  }
  final int maxStem = maxBasename - normalizedExt.length;
  return '${candidate.substring(0, maxStem)}$normalizedExt';
}
String? tenantFacilityOptionalSelection(String? value) {
  if (value == null || value == tenantFacilityNoneSelection) {
    return null;
  }

  return value;
}

FormFieldValidator<String> tenantFacilityRequiredSelection(
  AppLocalizations l10n,
) {
  return (String? value) => tenantFacilityOptionalSelection(value) == null
      ? l10n.validationRequired
      : null;
}

FormFieldValidator<String> tenantFacilityValidReferenceSelection({
  required List<String> validIds,
  required String invalidMessage,
}) {
  return (String? value) {
    final String? selected = tenantFacilityOptionalSelection(value);
    if (selected == null) {
      return null;
    }

    return validIds.contains(selected) ? null : invalidMessage;
  };
}

String tenantFacilityJoinParts(Iterable<String?> parts) {
  return parts
      .map((String? part) => part?.trim())
      .whereType<String>()
      .where((String part) => part.isNotEmpty)
      .join(' · ');
}

String? tenantFacilityFieldSummary(String label, String? value) {
  final String? trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  return '$label: $trimmed';
}

String tenantFacilityActiveStatusLabel(AppLocalizations l10n, bool isActive) {
  return isActive
      ? l10n.tenantFacilityStatusActive
      : l10n.tenantFacilityStatusInactive;
}

String tenantFacilityFacilityTypeLabel(
  AppLocalizations l10n,
  FacilitySetupType type,
) {
  return switch (type) {
    FacilitySetupType.hospital => l10n.authFacilityTypeHospital,
    FacilitySetupType.clinic => l10n.authFacilityTypeClinic,
    FacilitySetupType.lab => l10n.authFacilityTypeLab,
    FacilitySetupType.pharmacy => l10n.authFacilityTypePharmacy,
    FacilitySetupType.other => l10n.authFacilityTypeOther,
  };
}

IconData tenantFacilityFacilityTypeIcon(FacilitySetupType type) {
  return switch (type) {
    FacilitySetupType.hospital => Icons.local_hospital_outlined,
    FacilitySetupType.clinic => Icons.medical_services_outlined,
    FacilitySetupType.lab => Icons.biotech_outlined,
    FacilitySetupType.pharmacy => Icons.medication_outlined,
    FacilitySetupType.other => Icons.domain_outlined,
  };
}

String tenantFacilityDepartmentTypeLabel(
  AppLocalizations l10n,
  DepartmentSetupType type,
) {
  return switch (type) {
    DepartmentSetupType.clinical => l10n.tenantFacilityDepartmentTypeClinical,
    DepartmentSetupType.administrative =>
      l10n.tenantFacilityDepartmentTypeAdministrative,
    DepartmentSetupType.support => l10n.tenantFacilityDepartmentTypeSupport,
    DepartmentSetupType.diagnostics =>
      l10n.tenantFacilityDepartmentTypeDiagnostics,
    DepartmentSetupType.other => l10n.tenantFacilityDepartmentTypeOther,
  };
}

String tenantFacilityWardTypeLabel(AppLocalizations l10n, WardSetupType type) {
  return switch (type) {
    WardSetupType.general => l10n.tenantFacilityWardTypeGeneral,
    WardSetupType.icu => l10n.tenantFacilityWardTypeIcu,
    WardSetupType.maternity => l10n.tenantFacilityWardTypeMaternity,
    WardSetupType.pediatric => l10n.tenantFacilityWardTypePediatric,
    WardSetupType.surgical => l10n.tenantFacilityWardTypeSurgical,
    WardSetupType.other => l10n.tenantFacilityWardTypeOther,
  };
}

String tenantFacilityBedStatusLabel(
  AppLocalizations l10n,
  BedSetupStatus status,
) {
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

String? tenantFacilityBranchName(
  FacilitySetupSnapshot snapshot,
  String? branchId,
) {
  return snapshot.branches
      .where((BranchProfile branch) => branch.id == branchId)
      .map((BranchProfile branch) => branch.name)
      .firstOrNull;
}

String? tenantFacilityDepartmentName(
  FacilitySetupSnapshot snapshot,
  String? departmentId,
) {
  return snapshot.departments
      .where((DepartmentProfile department) => department.id == departmentId)
      .map((DepartmentProfile department) => department.name)
      .firstOrNull;
}

String? tenantFacilityWardName(FacilitySetupSnapshot snapshot, String? wardId) {
  return snapshot.wards
      .where((WardProfile ward) => ward.id == wardId)
      .map((WardProfile ward) => ward.name)
      .firstOrNull;
}

String? tenantFacilityRoomName(FacilitySetupSnapshot snapshot, String? roomId) {
  return snapshot.rooms
      .where((RoomProfile room) => room.id == roomId)
      .map((RoomProfile room) => room.name)
      .firstOrNull;
}

String tenantFacilityRecordPreview<T>({
  required List<T> records,
  required String emptyLabel,
  required String Function(T record) labelFor,
}) {
  if (records.isEmpty) {
    return emptyLabel;
  }

  final List<String> labels = records
      .take(2)
      .map(labelFor)
      .map((String label) => label.trim())
      .where((String label) => label.isNotEmpty)
      .toList(growable: false);

  return labels.isEmpty ? emptyLabel : labels.join('; ');
}

enum TenantFacilitySetupWizardStep {
  tenant,
  branches,
  facility,
  departments,
  units,
  wards,
  rooms,
  beds,
}

bool tenantFacilityWizardStepOptional(TenantFacilitySetupWizardStep step) {
  return switch (step) {
    TenantFacilitySetupWizardStep.branches ||
    TenantFacilitySetupWizardStep.units ||
    TenantFacilitySetupWizardStep.wards => true,
    TenantFacilitySetupWizardStep.tenant ||
    TenantFacilitySetupWizardStep.facility ||
    TenantFacilitySetupWizardStep.departments ||
    TenantFacilitySetupWizardStep.rooms ||
    TenantFacilitySetupWizardStep.beds => false,
  };
}

bool tenantFacilityWizardStepVisible({
  required TenantFacilitySetupWizardStep step,
  required bool canManageTenant,
  required bool canManageFacility,
}) {
  return switch (step) {
    TenantFacilitySetupWizardStep.tenant ||
    TenantFacilitySetupWizardStep.branches => canManageTenant,
    TenantFacilitySetupWizardStep.facility ||
    TenantFacilitySetupWizardStep.departments ||
    TenantFacilitySetupWizardStep.units ||
    TenantFacilitySetupWizardStep.wards ||
    TenantFacilitySetupWizardStep.rooms ||
    TenantFacilitySetupWizardStep.beds => canManageFacility || canManageTenant,
  };
}

List<TenantFacilitySetupWizardStep> tenantFacilityVisibleWizardSteps({
  required bool canManageTenant,
  required bool canManageFacility,
}) {
  return TenantFacilitySetupWizardStep.values
      .where(
        (TenantFacilitySetupWizardStep step) => tenantFacilityWizardStepVisible(
          step: step,
          canManageTenant: canManageTenant,
          canManageFacility: canManageFacility,
        ),
      )
      .toList(growable: false);
}

bool tenantFacilityWizardStepCompleted(
  FacilitySetupSnapshot snapshot,
  TenantFacilitySetupWizardStep step,
) {
  return switch (step) {
    TenantFacilitySetupWizardStep.tenant => snapshot.hasTenant,
    TenantFacilitySetupWizardStep.branches => snapshot.hasBranchesConfigured,
    TenantFacilitySetupWizardStep.facility => snapshot.hasFacilityIdentity,
    TenantFacilitySetupWizardStep.departments => snapshot.hasDepartments,
    TenantFacilitySetupWizardStep.units => snapshot.hasUnitsConfigured,
    TenantFacilitySetupWizardStep.wards => snapshot.hasWardsConfigured,
    TenantFacilitySetupWizardStep.rooms => snapshot.hasRoomsConfigured,
    TenantFacilitySetupWizardStep.beds => snapshot.hasBedsConfigured,
  };
}

/// Required steps block progress; optional steps never block the next required step.
bool tenantFacilityWizardStepBlocksProgress(
  FacilitySetupSnapshot snapshot,
  TenantFacilitySetupWizardStep step,
) {
  if (tenantFacilityWizardStepOptional(step)) {
    return false;
  }
  return !tenantFacilityWizardStepCompleted(snapshot, step);
}

TenantFacilitySetupWizardStep? tenantFacilityNextIncompleteWizardStep(
  FacilitySetupSnapshot snapshot, {
  List<TenantFacilitySetupWizardStep>? steps,
}) {
  final List<TenantFacilitySetupWizardStep> visible =
      steps ?? TenantFacilitySetupWizardStep.values;
  for (final TenantFacilitySetupWizardStep step in visible) {
    if (tenantFacilityWizardStepBlocksProgress(snapshot, step)) {
      return step;
    }
  }
  for (final TenantFacilitySetupWizardStep step in visible) {
    if (!tenantFacilityWizardStepCompleted(snapshot, step)) {
      return step;
    }
  }
  return null;
}

/// Furthest step index (in [steps]) the user may open.
int tenantFacilityFurthestReachableWizardIndex(
  FacilitySetupSnapshot snapshot,
  List<TenantFacilitySetupWizardStep> steps,
) {
  if (steps.isEmpty) {
    return -1;
  }

  for (int index = 0; index < steps.length; index += 1) {
    if (tenantFacilityWizardStepBlocksProgress(snapshot, steps[index])) {
      return index;
    }
  }
  return steps.length - 1;
}

bool tenantFacilityWizardStepReachable(
  FacilitySetupSnapshot snapshot,
  List<TenantFacilitySetupWizardStep> steps,
  TenantFacilitySetupWizardStep step,
) {
  final int index = steps.indexOf(step);
  if (index < 0) {
    return false;
  }
  if (tenantFacilityWizardStepCompleted(snapshot, step)) {
    return true;
  }
  return index <= tenantFacilityFurthestReachableWizardIndex(snapshot, steps);
}

String tenantFacilityWizardStepLabel(
  AppLocalizations l10n,
  TenantFacilitySetupWizardStep step,
) {
  return switch (step) {
    TenantFacilitySetupWizardStep.tenant => l10n.tenantFacilityWizardStepTenant,
    TenantFacilitySetupWizardStep.branches =>
      l10n.tenantFacilityWizardStepBranches,
    TenantFacilitySetupWizardStep.facility =>
      l10n.tenantFacilityWizardStepFacility,
    TenantFacilitySetupWizardStep.departments =>
      l10n.tenantFacilityWizardStepDepartments,
    TenantFacilitySetupWizardStep.units => l10n.tenantFacilityWizardStepUnits,
    TenantFacilitySetupWizardStep.wards => l10n.tenantFacilityWizardStepWards,
    TenantFacilitySetupWizardStep.rooms => l10n.tenantFacilityWizardStepRooms,
    TenantFacilitySetupWizardStep.beds => l10n.tenantFacilityWizardStepBeds,
  };
}

IconData tenantFacilityWizardStepIcon(TenantFacilitySetupWizardStep step) {
  return switch (step) {
    TenantFacilitySetupWizardStep.tenant => Icons.apartment_outlined,
    TenantFacilitySetupWizardStep.branches => Icons.account_tree_outlined,
    TenantFacilitySetupWizardStep.facility => Icons.local_hospital_outlined,
    TenantFacilitySetupWizardStep.departments => Icons.groups_2_outlined,
    TenantFacilitySetupWizardStep.units => Icons.hub_outlined,
    TenantFacilitySetupWizardStep.wards => Icons.local_hotel_outlined,
    TenantFacilitySetupWizardStep.rooms => Icons.meeting_room_outlined,
    TenantFacilitySetupWizardStep.beds => Icons.bed_outlined,
  };
}

String tenantFacilityWizardStepSummary(
  AppLocalizations l10n,
  FacilitySetupSnapshot snapshot,
  TenantFacilitySetupWizardStep step,
) {
  return switch (step) {
    TenantFacilitySetupWizardStep.tenant =>
      snapshot.tenant?.name.trim().isNotEmpty == true
          ? snapshot.tenant!.name
          : l10n.tenantFacilityChecklistTenant,
    TenantFacilitySetupWizardStep.branches =>
      l10n.tenantFacilitySummaryRecordCount(snapshot.branches.length),
    TenantFacilitySetupWizardStep.facility =>
      snapshot.facility?.name.trim().isNotEmpty == true
          ? snapshot.facility!.name
          : l10n.tenantFacilityChecklistIdentity,
    TenantFacilitySetupWizardStep.departments =>
      l10n.tenantFacilitySummaryRecordCount(snapshot.departments.length),
    TenantFacilitySetupWizardStep.units =>
      l10n.tenantFacilitySummaryRecordCount(snapshot.units.length),
    TenantFacilitySetupWizardStep.wards =>
      l10n.tenantFacilitySummaryRecordCount(snapshot.wards.length),
    TenantFacilitySetupWizardStep.rooms =>
      l10n.tenantFacilitySummaryRecordCount(snapshot.rooms.length),
    TenantFacilitySetupWizardStep.beds =>
      l10n.tenantFacilitySummaryRecordCount(snapshot.beds.length),
  };
}

bool tenantFacilityWizardStepHasRecords(
  FacilitySetupSnapshot snapshot,
  TenantFacilitySetupWizardStep step,
) {
  return switch (step) {
    TenantFacilitySetupWizardStep.tenant => snapshot.hasTenant,
    TenantFacilitySetupWizardStep.branches => snapshot.branches.isNotEmpty,
    TenantFacilitySetupWizardStep.facility => snapshot.hasFacility,
    TenantFacilitySetupWizardStep.departments => snapshot.departments.isNotEmpty,
    TenantFacilitySetupWizardStep.units => snapshot.units.isNotEmpty,
    TenantFacilitySetupWizardStep.wards => snapshot.wards.isNotEmpty,
    TenantFacilitySetupWizardStep.rooms => snapshot.rooms.isNotEmpty,
    TenantFacilitySetupWizardStep.beds => snapshot.beds.isNotEmpty,
  };
}

String tenantFacilityWizardStepEmptyMessage(
  AppLocalizations l10n,
  TenantFacilitySetupWizardStep step,
) {
  return switch (step) {
    TenantFacilitySetupWizardStep.tenant => l10n.tenantFacilityChecklistTenant,
    TenantFacilitySetupWizardStep.branches => l10n.tenantFacilityNoBranches,
    TenantFacilitySetupWizardStep.facility => l10n.tenantFacilityNoFacilities,
    TenantFacilitySetupWizardStep.departments => l10n.tenantFacilityNoDepartments,
    TenantFacilitySetupWizardStep.units => l10n.tenantFacilityNoUnits,
    TenantFacilitySetupWizardStep.wards => l10n.tenantFacilityNoWards,
    TenantFacilitySetupWizardStep.rooms => l10n.tenantFacilityNoRooms,
    TenantFacilitySetupWizardStep.beds => l10n.tenantFacilityNoBeds,
  };
}

String tenantFacilityWizardPrimaryActionLabel(
  AppLocalizations l10n, {
  required TenantFacilitySetupWizardStep step,
  required FacilitySetupSnapshot snapshot,
  required bool canCreateTenant,
}) {
  final bool hasRecords = tenantFacilityWizardStepHasRecords(snapshot, step);
  return switch (step) {
    TenantFacilitySetupWizardStep.tenant => hasRecords
        ? l10n.tenantFacilityEditTenantAction
        : (canCreateTenant
              ? l10n.tenantFacilityCreateTenantAction
              : l10n.tenantFacilityEditTenantAction),
    TenantFacilitySetupWizardStep.branches => hasRecords
        ? l10n.tenantFacilityManageBranchesAction
        : l10n.tenantFacilityCreateBranchAction,
    TenantFacilitySetupWizardStep.facility => hasRecords
        ? l10n.tenantFacilityEditFacilityAction
        : l10n.tenantFacilityCreateFacilityTitle,
    TenantFacilitySetupWizardStep.departments => hasRecords
        ? l10n.tenantFacilityManageDepartmentsAction
        : l10n.tenantFacilityCreateDepartmentAction,
    TenantFacilitySetupWizardStep.units => hasRecords
        ? l10n.tenantFacilityManageUnitsAction
        : l10n.tenantFacilityCreateUnitAction,
    TenantFacilitySetupWizardStep.wards => hasRecords
        ? l10n.tenantFacilityManageWardsAction
        : l10n.tenantFacilityCreateWardAction,
    TenantFacilitySetupWizardStep.rooms => hasRecords
        ? l10n.tenantFacilityManageRoomsAction
        : l10n.tenantFacilityCreateRoomAction,
    TenantFacilitySetupWizardStep.beds => hasRecords
        ? l10n.tenantFacilityManageBedsAction
        : l10n.tenantFacilityCreateBedAction,
  };
}

IconData tenantFacilityWizardPrimaryActionIcon({
  required TenantFacilitySetupWizardStep step,
  required FacilitySetupSnapshot snapshot,
}) {
  final bool hasRecords = tenantFacilityWizardStepHasRecords(snapshot, step);
  if (hasRecords) {
    return switch (step) {
      TenantFacilitySetupWizardStep.tenant ||
      TenantFacilitySetupWizardStep.facility => Icons.edit_outlined,
      _ => Icons.list_alt_outlined,
    };
  }
  return Icons.add_circle_outline;
}

String tenantFacilityWizardContinueToStepLabel(
  AppLocalizations l10n,
  TenantFacilitySetupWizardStep step,
) {
  return l10n.tenantFacilityContinueToStepAction(
    tenantFacilityWizardStepLabel(l10n, step),
  );
}

String tenantFacilityWizardProgressCaption({
  required int currentIndex,
  required int totalSteps,
  required String stepLabel,
  required bool optional,
}) {
  final String base = 'Step ${currentIndex + 1} of $totalSteps · $stepLabel';
  return optional ? '$base · Optional' : base;
}
