import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';

abstract final class TenantFacilityPermissions {
  static const AppPermission tenantAdmin = AppPermissions.tenantAdmin;
  static const AppPermission facilityAdmin = AppPermissions.facilityAdmin;
  static const AppPermission systemAdmin = AppPermissions.systemAdmin;

  static final Set<AppPermission> setupAccess = <AppPermission>{
    tenantAdmin,
    facilityAdmin,
    systemAdmin,
  };
}

enum FacilitySetupType { hospital, clinic, lab, pharmacy, other }

enum DepartmentSetupType {
  clinical,
  administrative,
  support,
  diagnostics,
  other,
}

final class TenantProfile {
  const TenantProfile({
    required this.id,
    required this.name,
    this.slug,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? slug;
  final bool isActive;
}

final class FacilityProfile {
  const FacilityProfile({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.type,
    this.isActive = true,
    this.logoUrl,
  });

  final String id;
  final String tenantId;
  final String name;
  final FacilitySetupType type;
  final bool isActive;
  final String? logoUrl;
}

final class BranchProfile {
  const BranchProfile({
    required this.id,
    required this.tenantId,
    required this.name,
    this.facilityId,
    this.isActive = true,
  });

  final String id;
  final String tenantId;
  final String name;
  final String? facilityId;
  final bool isActive;
}

final class DepartmentProfile {
  const DepartmentProfile({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.type,
    this.shortName,
    this.facilityId,
    this.branchId,
    this.isActive = true,
  });

  final String id;
  final String tenantId;
  final String name;
  final DepartmentSetupType type;
  final String? shortName;
  final String? facilityId;
  final String? branchId;
  final bool isActive;
}

final class UnitProfile {
  const UnitProfile({
    required this.id,
    required this.tenantId,
    required this.name,
    this.facilityId,
    this.departmentId,
    this.isActive = true,
  });

  final String id;
  final String tenantId;
  final String name;
  final String? facilityId;
  final String? departmentId;
  final bool isActive;
}

final class FacilityContactAddress {
  const FacilityContactAddress({
    this.phone,
    this.email,
    this.addressLine1,
    this.city,
    this.country,
  });

  final String? phone;
  final String? email;
  final String? addressLine1;
  final String? city;
  final String? country;
}

final class FacilitySetupSnapshot {
  const FacilitySetupSnapshot({
    this.tenant,
    this.facility,
    this.contactAddress = const FacilityContactAddress(),
    this.branches = const <BranchProfile>[],
    this.departments = const <DepartmentProfile>[],
    this.units = const <UnitProfile>[],
    this.roomsCount = 0,
    this.wardsCount = 0,
    this.bedsCount = 0,
  });

  final TenantProfile? tenant;
  final FacilityProfile? facility;
  final FacilityContactAddress contactAddress;
  final List<BranchProfile> branches;
  final List<DepartmentProfile> departments;
  final List<UnitProfile> units;
  final int roomsCount;
  final int wardsCount;
  final int bedsCount;

  bool get hasTenant => tenant != null;
  bool get hasFacility => facility != null;
  bool get hasDepartmentsAndUnits => departments.isNotEmpty && units.isNotEmpty;
  bool get hasFacilityIdentity {
    final FacilityProfile? currentFacility = facility;
    if (currentFacility == null) {
      return false;
    }

    return currentFacility.name.trim().isNotEmpty &&
        contactAddress.phone?.trim().isNotEmpty == true;
  }

  int get completedChecklistItems {
    return <bool>[
      hasTenant,
      hasFacilityIdentity,
      hasDepartmentsAndUnits,
      roomsCount > 0 || wardsCount > 0 || bedsCount > 0,
    ].where((bool completed) => completed).length;
  }
}

extension FacilitySetupTypeX on FacilitySetupType {
  String get apiValue {
    return switch (this) {
      FacilitySetupType.hospital => 'HOSPITAL',
      FacilitySetupType.clinic => 'CLINIC',
      FacilitySetupType.lab => 'LAB',
      FacilitySetupType.pharmacy => 'PHARMACY',
      FacilitySetupType.other => 'OTHER',
    };
  }

  static FacilitySetupType fromApiValue(String? value) {
    return switch (value?.trim().toUpperCase()) {
      'CLINIC' => FacilitySetupType.clinic,
      'LAB' => FacilitySetupType.lab,
      'PHARMACY' => FacilitySetupType.pharmacy,
      'OTHER' => FacilitySetupType.other,
      _ => FacilitySetupType.hospital,
    };
  }
}

extension DepartmentSetupTypeX on DepartmentSetupType {
  String get apiValue {
    return switch (this) {
      DepartmentSetupType.clinical => 'CLINICAL',
      DepartmentSetupType.administrative => 'ADMINISTRATIVE',
      DepartmentSetupType.support => 'SUPPORT',
      DepartmentSetupType.diagnostics => 'DIAGNOSTICS',
      DepartmentSetupType.other => 'OTHER',
    };
  }

  static DepartmentSetupType fromApiValue(String? value) {
    return switch (value?.trim().toUpperCase()) {
      'ADMINISTRATIVE' => DepartmentSetupType.administrative,
      'SUPPORT' => DepartmentSetupType.support,
      'DIAGNOSTICS' => DepartmentSetupType.diagnostics,
      'OTHER' => DepartmentSetupType.other,
      _ => DepartmentSetupType.clinical,
    };
  }
}
