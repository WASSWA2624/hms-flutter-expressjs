import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

const String tenantFacilityNoneSelection = '__none__';

String? tenantFacilityOptionalSelection(String? value) {
  if (value == null || value == tenantFacilityNoneSelection) {
    return null;
  }

  return value;
}

FormFieldValidator<String> tenantFacilityRequiredSelection(
  AppLocalizations l10n,
) {
  return (String? value) =>
      tenantFacilityOptionalSelection(value) == null ? l10n.validationRequired : null;
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

String? tenantFacilityWardName(
  FacilitySetupSnapshot snapshot,
  String? wardId,
) {
  return snapshot.wards
      .where((WardProfile ward) => ward.id == wardId)
      .map((WardProfile ward) => ward.name)
      .firstOrNull;
}

String? tenantFacilityRoomName(
  FacilitySetupSnapshot snapshot,
  String? roomId,
) {
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
  facility,
  organization,
  careSpaces,
}

TenantFacilitySetupWizardStep? tenantFacilityNextIncompleteWizardStep(
  FacilitySetupSnapshot snapshot,
) {
  if (!snapshot.hasTenant) {
    return TenantFacilitySetupWizardStep.tenant;
  }
  if (!snapshot.hasFacilityIdentity) {
    return TenantFacilitySetupWizardStep.facility;
  }
  if (!snapshot.hasDepartmentsAndUnits) {
    return TenantFacilitySetupWizardStep.organization;
  }
  if (snapshot.wardsCount == 0 &&
      snapshot.roomsCount == 0 &&
      snapshot.bedsCount == 0) {
    return TenantFacilitySetupWizardStep.careSpaces;
  }

  return null;
}

String tenantFacilityWizardStepLabel(
  AppLocalizations l10n,
  TenantFacilitySetupWizardStep step,
) {
  return switch (step) {
    TenantFacilitySetupWizardStep.tenant => l10n.tenantFacilityWizardStepTenant,
    TenantFacilitySetupWizardStep.facility =>
      l10n.tenantFacilityWizardStepFacility,
    TenantFacilitySetupWizardStep.organization =>
      l10n.tenantFacilityWizardStepOrganization,
    TenantFacilitySetupWizardStep.careSpaces =>
      l10n.tenantFacilityWizardStepCareSpaces,
  };
}

bool tenantFacilityWizardStepCompleted(
  FacilitySetupSnapshot snapshot,
  TenantFacilitySetupWizardStep step,
) {
  return switch (step) {
    TenantFacilitySetupWizardStep.tenant => snapshot.hasTenant,
    TenantFacilitySetupWizardStep.facility => snapshot.hasFacilityIdentity,
    TenantFacilitySetupWizardStep.organization => snapshot.hasDepartmentsAndUnits,
    TenantFacilitySetupWizardStep.careSpaces =>
      snapshot.wardsCount > 0 ||
      snapshot.roomsCount > 0 ||
      snapshot.bedsCount > 0,
  };
}
