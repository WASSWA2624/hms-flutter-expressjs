import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';

const Object _facilitySetupSnapshotUnset = Object();

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

enum WardSetupType { general, icu, maternity, pediatric, surgical, other }

enum BedSetupStatus { available, occupied, reserved, outOfService }

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

final class WardProfile {
  const WardProfile({
    required this.id,
    required this.tenantId,
    required this.facilityId,
    required this.name,
    required this.type,
    this.departmentId,
    this.isActive = true,
  });

  final String id;
  final String tenantId;
  final String facilityId;
  final String name;
  final WardSetupType type;
  final String? departmentId;
  final bool isActive;
}

final class RoomProfile {
  const RoomProfile({
    required this.id,
    required this.tenantId,
    required this.facilityId,
    required this.name,
    this.wardId,
    this.floor,
  });

  final String id;
  final String tenantId;
  final String facilityId;
  final String name;
  final String? wardId;
  final String? floor;
}

final class BedProfile {
  const BedProfile({
    required this.id,
    required this.tenantId,
    required this.facilityId,
    required this.wardId,
    required this.label,
    required this.status,
    this.roomId,
  });

  final String id;
  final String tenantId;
  final String facilityId;
  final String wardId;
  final String label;
  final BedSetupStatus status;
  final String? roomId;
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
    this.facilities = const <FacilityProfile>[],
    this.contactAddress = const FacilityContactAddress(),
    this.branches = const <BranchProfile>[],
    this.departments = const <DepartmentProfile>[],
    this.units = const <UnitProfile>[],
    this.wards = const <WardProfile>[],
    this.rooms = const <RoomProfile>[],
    this.beds = const <BedProfile>[],
  });

  final TenantProfile? tenant;
  final FacilityProfile? facility;
  final List<FacilityProfile> facilities;
  final FacilityContactAddress contactAddress;
  final List<BranchProfile> branches;
  final List<DepartmentProfile> departments;
  final List<UnitProfile> units;
  final List<WardProfile> wards;
  final List<RoomProfile> rooms;
  final List<BedProfile> beds;

  FacilitySetupSnapshot copyWith({
    Object? tenant = _facilitySetupSnapshotUnset,
    Object? facility = _facilitySetupSnapshotUnset,
    List<FacilityProfile>? facilities,
    FacilityContactAddress? contactAddress,
    List<BranchProfile>? branches,
    List<DepartmentProfile>? departments,
    List<UnitProfile>? units,
    List<WardProfile>? wards,
    List<RoomProfile>? rooms,
    List<BedProfile>? beds,
  }) {
    return FacilitySetupSnapshot(
      tenant: identical(tenant, _facilitySetupSnapshotUnset)
          ? this.tenant
          : tenant as TenantProfile?,
      facility: identical(facility, _facilitySetupSnapshotUnset)
          ? this.facility
          : facility as FacilityProfile?,
      facilities: facilities ?? this.facilities,
      contactAddress: contactAddress ?? this.contactAddress,
      branches: branches ?? this.branches,
      departments: departments ?? this.departments,
      units: units ?? this.units,
      wards: wards ?? this.wards,
      rooms: rooms ?? this.rooms,
      beds: beds ?? this.beds,
    );
  }

  bool get hasTenant => tenant != null;
  bool get hasFacility => facility != null;
  bool get hasDepartmentsAndUnits => departments.isNotEmpty && units.isNotEmpty;
  int get roomsCount => rooms.length;
  int get wardsCount => wards.length;
  int get bedsCount => beds.length;
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
      wards.isNotEmpty || rooms.isNotEmpty || beds.isNotEmpty,
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

extension WardSetupTypeX on WardSetupType {
  String get apiValue {
    return switch (this) {
      WardSetupType.general => 'GENERAL',
      WardSetupType.icu => 'ICU',
      WardSetupType.maternity => 'MATERNITY',
      WardSetupType.pediatric => 'PEDIATRIC',
      WardSetupType.surgical => 'SURGICAL',
      WardSetupType.other => 'OTHER',
    };
  }

  static WardSetupType fromApiValue(String? value) {
    return switch (value?.trim().toUpperCase()) {
      'ICU' => WardSetupType.icu,
      'MATERNITY' => WardSetupType.maternity,
      'PEDIATRIC' => WardSetupType.pediatric,
      'SURGICAL' => WardSetupType.surgical,
      'OTHER' => WardSetupType.other,
      _ => WardSetupType.general,
    };
  }
}

extension BedSetupStatusX on BedSetupStatus {
  String get apiValue {
    return switch (this) {
      BedSetupStatus.available => 'AVAILABLE',
      BedSetupStatus.occupied => 'OCCUPIED',
      BedSetupStatus.reserved => 'RESERVED',
      BedSetupStatus.outOfService => 'OUT_OF_SERVICE',
    };
  }

  static BedSetupStatus fromApiValue(String? value) {
    return switch (value?.trim().toUpperCase()) {
      'OCCUPIED' => BedSetupStatus.occupied,
      'RESERVED' => BedSetupStatus.reserved,
      'OUT_OF_SERVICE' => BedSetupStatus.outOfService,
      _ => BedSetupStatus.available,
    };
  }
}
