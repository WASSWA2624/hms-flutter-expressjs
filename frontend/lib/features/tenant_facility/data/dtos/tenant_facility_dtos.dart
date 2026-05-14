import 'package:hosspi_hms/core/network/api_response.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';

final class TenantProfileDto {
  const TenantProfileDto({
    required this.id,
    required this.name,
    this.slug,
    required this.isActive,
  });

  factory TenantProfileDto.fromJson(JsonMap json) {
    return TenantProfileDto(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      slug: _optionalString(json, 'slug'),
      isActive: _optionalBool(json, 'is_active') ?? true,
    );
  }

  final String id;
  final String name;
  final String? slug;
  final bool isActive;

  TenantProfile toEntity() {
    return TenantProfile(id: id, name: name, slug: slug, isActive: isActive);
  }
}

final class FacilityProfileDto {
  const FacilityProfileDto({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.type,
    required this.isActive,
    this.logoUrl,
  });

  factory FacilityProfileDto.fromJson(JsonMap json) {
    final JsonMap extensionJson = _map(json['extension_json']);

    return FacilityProfileDto(
      id: _requiredString(json, 'id'),
      tenantId: _requiredString(json, 'tenant_id'),
      name: _requiredString(json, 'name'),
      type: FacilitySetupTypeX.fromApiValue(
        _optionalString(json, 'facility_type'),
      ),
      isActive: _optionalBool(json, 'is_active') ?? true,
      logoUrl: _optionalString(extensionJson, 'logo_url'),
    );
  }

  final String id;
  final String tenantId;
  final String name;
  final FacilitySetupType type;
  final bool isActive;
  final String? logoUrl;

  FacilityProfile toEntity() {
    return FacilityProfile(
      id: id,
      tenantId: tenantId,
      name: name,
      type: type,
      isActive: isActive,
      logoUrl: logoUrl,
    );
  }
}

final class BranchProfileDto {
  const BranchProfileDto({
    required this.id,
    required this.tenantId,
    required this.name,
    this.facilityId,
    required this.isActive,
  });

  factory BranchProfileDto.fromJson(JsonMap json) {
    return BranchProfileDto(
      id: _requiredString(json, 'id'),
      tenantId: _requiredString(json, 'tenant_id'),
      name: _requiredString(json, 'name'),
      facilityId: _optionalString(json, 'facility_id'),
      isActive: _optionalBool(json, 'is_active') ?? true,
    );
  }

  final String id;
  final String tenantId;
  final String name;
  final String? facilityId;
  final bool isActive;

  BranchProfile toEntity() {
    return BranchProfile(
      id: id,
      tenantId: tenantId,
      name: name,
      facilityId: facilityId,
      isActive: isActive,
    );
  }
}

final class DepartmentProfileDto {
  const DepartmentProfileDto({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.type,
    this.shortName,
    this.facilityId,
    this.branchId,
    required this.isActive,
  });

  factory DepartmentProfileDto.fromJson(JsonMap json) {
    return DepartmentProfileDto(
      id: _requiredString(json, 'id'),
      tenantId: _requiredString(json, 'tenant_id'),
      name: _requiredString(json, 'name'),
      type: DepartmentSetupTypeX.fromApiValue(
        _optionalString(json, 'department_type'),
      ),
      shortName: _optionalString(json, 'short_name'),
      facilityId: _optionalString(json, 'facility_id'),
      branchId: _optionalString(json, 'branch_id'),
      isActive: _optionalBool(json, 'is_active') ?? true,
    );
  }

  final String id;
  final String tenantId;
  final String name;
  final DepartmentSetupType type;
  final String? shortName;
  final String? facilityId;
  final String? branchId;
  final bool isActive;

  DepartmentProfile toEntity() {
    return DepartmentProfile(
      id: id,
      tenantId: tenantId,
      name: name,
      type: type,
      shortName: shortName,
      facilityId: facilityId,
      branchId: branchId,
      isActive: isActive,
    );
  }
}

final class UnitProfileDto {
  const UnitProfileDto({
    required this.id,
    required this.tenantId,
    required this.name,
    this.facilityId,
    this.departmentId,
    required this.isActive,
  });

  factory UnitProfileDto.fromJson(JsonMap json) {
    return UnitProfileDto(
      id: _requiredString(json, 'id'),
      tenantId: _requiredString(json, 'tenant_id'),
      name: _requiredString(json, 'name'),
      facilityId: _optionalString(json, 'facility_id'),
      departmentId: _optionalString(json, 'department_id'),
      isActive: _optionalBool(json, 'is_active') ?? true,
    );
  }

  final String id;
  final String tenantId;
  final String name;
  final String? facilityId;
  final String? departmentId;
  final bool isActive;

  UnitProfile toEntity() {
    return UnitProfile(
      id: id,
      tenantId: tenantId,
      name: name,
      facilityId: facilityId,
      departmentId: departmentId,
      isActive: isActive,
    );
  }
}

final class ContactDto {
  const ContactDto({required this.id, required this.type, required this.value});

  factory ContactDto.fromJson(JsonMap json) {
    return ContactDto(
      id: _requiredString(json, 'id'),
      type: _requiredString(json, 'contact_type'),
      value: _requiredString(json, 'value'),
    );
  }

  final String id;
  final String type;
  final String value;
}

final class AddressDto {
  const AddressDto({
    required this.id,
    required this.line1,
    this.city,
    this.country,
  });

  factory AddressDto.fromJson(JsonMap json) {
    return AddressDto(
      id: _requiredString(json, 'id'),
      line1: _requiredString(json, 'line1'),
      city: _optionalString(json, 'city'),
      country: _optionalString(json, 'country'),
    );
  }

  final String id;
  final String line1;
  final String? city;
  final String? country;
}

List<T> decodeList<T>(Object? data, T Function(JsonMap json) decoder) {
  if (data is! Iterable<Object?>) {
    throw const FormatException('Expected API list data.');
  }

  return data.whereType<JsonMap>().map(decoder).toList(growable: false);
}

String _requiredString(JsonMap json, String key) {
  final String? value = _optionalString(json, key);
  if (value == null) {
    throw FormatException('Expected $key.');
  }

  return value;
}

String? _optionalString(JsonMap json, String key) {
  final Object? value = json[key];
  if (value is! String || value.trim().isEmpty) {
    return null;
  }

  return value.trim();
}

bool? _optionalBool(JsonMap json, String key) {
  final Object? value = json[key];
  return value is bool ? value : null;
}

JsonMap _map(Object? value) {
  return value is JsonMap ? value : const <String, Object?>{};
}
