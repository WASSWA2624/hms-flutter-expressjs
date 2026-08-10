import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

@immutable
final class HrStaffPosition {
  const HrStaffPosition({
    required this.id,
    this.displayId,
    this.tenantId,
    this.facilityId,
    this.departmentId,
    required this.name,
    this.description,
    this.isActive = true,
    this.deletedAt,
  });

  final String id;
  final String? displayId;
  final String? tenantId;
  final String? facilityId;
  final String? departmentId;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime? deletedAt;

  String get effectiveId =>
      (displayId ?? '').trim().isNotEmpty ? displayId!.trim() : id;

  bool get isDeleted => deletedAt != null;

  HrStaffPosition copyWith({
    String? id,
    String? displayId,
    String? tenantId,
    String? facilityId,
    String? departmentId,
    String? name,
    String? description,
    bool? isActive,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return HrStaffPosition(
      id: id ?? this.id,
      displayId: displayId ?? this.displayId,
      tenantId: tenantId ?? this.tenantId,
      facilityId: facilityId ?? this.facilityId,
      departmentId: departmentId ?? this.departmentId,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    );
  }
}

@immutable
final class HrStaffPositionQuery {
  const HrStaffPositionQuery({
    this.search = '',
    this.tenantId,
    this.facilityId,
    this.departmentId,
    this.isActive,
    this.includeDeleted = false,
    this.pageRequest = const AppPageRequest(),
  });

  final String search;
  final String? tenantId;
  final String? facilityId;
  final String? departmentId;
  final bool? isActive;
  final bool includeDeleted;
  final AppPageRequest pageRequest;

  HrStaffPositionQuery copyWith({
    String? search,
    String? tenantId,
    String? facilityId,
    String? departmentId,
    bool? isActive,
    bool? includeDeleted,
    AppPageRequest? pageRequest,
    bool clearTenantId = false,
    bool clearFacilityId = false,
    bool clearDepartmentId = false,
    bool clearIsActive = false,
  }) {
    return HrStaffPositionQuery(
      search: search ?? this.search,
      tenantId: clearTenantId ? null : tenantId ?? this.tenantId,
      facilityId: clearFacilityId ? null : facilityId ?? this.facilityId,
      departmentId: clearDepartmentId
          ? null
          : departmentId ?? this.departmentId,
      isActive: clearIsActive ? null : isActive ?? this.isActive,
      includeDeleted: includeDeleted ?? this.includeDeleted,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}
