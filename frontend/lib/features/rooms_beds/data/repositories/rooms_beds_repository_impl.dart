import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/rooms_beds/data/dtos/rooms_beds_dtos.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/repositories/rooms_beds_repository.dart';
import 'package:hosspi_hms/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/repositories/tenant_facility_repository.dart';

final roomsBedsRepositoryProvider = Provider<RoomsBedsRepository>((ref) {
  return RoomsBedsRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
    setupRepository: ref.watch(tenantFacilityRepositoryProvider),
  );
});

final class RoomsBedsRepositoryImpl implements RoomsBedsRepository {
  const RoomsBedsRepositoryImpl({
    required ApiClient apiClient,
    required TenantFacilityRepository setupRepository,
  }) : _apiClient = apiClient,
       _setupRepository = setupRepository;

  final ApiClient _apiClient;
  final TenantFacilityRepository _setupRepository;

  @override
  Future<Result<FacilitySetupSnapshot>> loadSetup({String? facilityId}) {
    return _setupRepository.loadSetup(facilityId: facilityId);
  }

  @override
  Future<Result<WardProfile>> saveWard({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    required WardSetupType type,
    String? departmentId,
    required bool isActive,
  }) {
    return _setupRepository.saveWard(
      id: id,
      tenantId: tenantId,
      facilityId: facilityId,
      name: name,
      type: type,
      departmentId: departmentId,
      isActive: isActive,
    );
  }

  @override
  Future<Result<RoomProfile>> saveRoom({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    String? wardId,
    String? floor,
  }) {
    return _setupRepository.saveRoom(
      id: id,
      tenantId: tenantId,
      facilityId: facilityId,
      name: name,
      wardId: wardId,
      floor: floor,
    );
  }

  @override
  Future<Result<BedProfile>> saveBed({
    String? id,
    required String tenantId,
    required String facilityId,
    required String wardId,
    required String label,
    required BedSetupStatus status,
    String? roomId,
  }) {
    return _setupRepository.saveBed(
      id: id,
      tenantId: tenantId,
      facilityId: facilityId,
      wardId: wardId,
      label: label,
      status: status,
      roomId: roomId,
    );
  }

  @override
  Future<Result<List<BedAssignmentRecord>>> listBedAssignmentsForBed(
    String bedId,
  ) {
    return _apiClient.get<List<BedAssignmentRecord>>(
      ApiEndpoints.collection(HmsApiResource.bedAssignments),
      queryParameters: <String, Object?>{
        'bed_id': bedId,
        'page': 1,
        'limit': 25,
        'sort_by': 'assigned_at',
        'order': 'desc',
      },
      decoder: decodeBedAssignmentRecords,
    );
  }

  @override
  Future<Result<void>> assignBed({
    required String admissionId,
    required String bedId,
  }) {
    return _postIpdAction(
      admissionId,
      <String>['assign-bed'],
      <String, Object?>{
        'bed_id': bedId,
        'assigned_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<Result<void>> releaseBed({required String admissionId}) {
    return _postIpdAction(
      admissionId,
      <String>['release-bed'],
      <String, Object?>{
        'released_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<Result<void>> requestTransfer({
    required String admissionId,
    String? fromWardId,
    required String toWardId,
  }) {
    return _postIpdAction(
      admissionId,
      <String>['request-transfer'],
      <String, Object?>{
        'from_ward_id': _normalizedOptional(fromWardId),
        'to_ward_id': toWardId,
        'requested_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<Result<void>> _postIpdAction(
    String admissionId,
    List<String> pathSegments,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<void>(
      ApiEndpoints.nested(HmsApiResource.ipdFlows, admissionId, pathSegments),
      data: _withoutEmpty(payload),
      decoder: decodeSuccessfulVoid,
    );
  }
}

Map<String, Object?> _withoutEmpty(Map<String, Object?> payload) {
  return <String, Object?>{
    for (final MapEntry<String, Object?> entry in payload.entries)
      if (!_isEmptyPayloadValue(entry.value)) entry.key: entry.value,
  };
}

bool _isEmptyPayloadValue(Object? value) {
  if (value == null) {
    return true;
  }
  if (value is String) {
    return value.trim().isEmpty;
  }
  if (value is Iterable) {
    return value.isEmpty;
  }
  if (value is Map) {
    return value.isEmpty;
  }
  return false;
}

String? _normalizedOptional(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
