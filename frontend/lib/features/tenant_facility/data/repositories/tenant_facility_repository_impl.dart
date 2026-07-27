import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/api_response.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/tenant_facility/data/dtos/tenant_facility_dtos.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/repositories/tenant_facility_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final tenantFacilityRepositoryProvider = Provider<TenantFacilityRepository>((
  ref,
) {
  return TenantFacilityRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class TenantFacilityRepositoryImpl implements TenantFacilityRepository {
  const TenantFacilityRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  static const String _setupListLimit = '100';

  final ApiClient _apiClient;

  @override
  Future<Result<FacilitySetupSnapshot>> loadSetup({
    String? facilityId,
    String? tenantId,
    bool includeDeleted = false,
  }) async {
    final workspaceResult = await _loadSetupFromWorkspace(
      facilityId: facilityId,
      tenantId: tenantId,
      includeDeleted: includeDeleted,
    );
    if (workspaceResult case ResultSuccess<FacilitySetupSnapshot>(
      :final value,
    )) {
      // Prefer workspace when it resolved a facility, or when no specific
      // facility was requested (caller is browsing setup context).
      if (value.facility != null || _normalizedOptional(facilityId) == null) {
        return Result<FacilitySetupSnapshot>.success(value);
      }
    }
    if (workspaceResult case ResultFailure<FacilitySetupSnapshot>(
      :final failure,
    )) {
      if (failure.category != AppFailureCategory.notFound &&
          failure.category != AppFailureCategory.forbidden) {
        return Result<FacilitySetupSnapshot>.failure(failure);
      }
    }

    return _loadSetupComposed(
      facilityId: facilityId,
      tenantId: tenantId,
      includeDeleted: includeDeleted,
    );
  }

  @override
  Future<Result<FacilityProfile>> getFacility(String id) {
    return _apiClient.get<FacilityProfile>(
      ApiEndpoints.byId(HmsApiResource.facilities, id),
      decoder: _decodeFacility,
    );
  }

  @override
  Future<Result<AppPage<TenantProfile>>> listTenants({
    required AppPageRequest request,
    String? search,
    bool? isActive,
    bool includeDeleted = false,
  }) {
    return _apiClient.get<AppPage<TenantProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.tenants,
        queryParameters: _withoutEmpty(<String, String?>{
          'page': '${request.pageIndex + 1}',
          'limit': '${request.pageSize}',
          'search': search,
          'is_active': isActive?.toString(),
          'include_deleted': includeDeleted ? 'true' : null,
          'sort_by': 'name',
          'order': 'asc',
        }),
      ),
      decoder: (Object? data) => _decodeTenantPage(data, request: request).page,
    );
  }

  @override
  Future<Result<AppPage<FacilityProfile>>> listFacilities({
    required AppPageRequest request,
    String? tenantId,
    String? search,
    FacilitySetupType? type,
    bool? isActive,
    bool includeDeleted = false,
  }) {
    return _apiClient.get<AppPage<FacilityProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.facilities,
        queryParameters: _withoutEmpty(<String, String?>{
          'page': '${request.pageIndex + 1}',
          'limit': '${request.pageSize}',
          'tenant_id': tenantId,
          'search': search,
          'facility_type': type?.apiValue,
          'is_active': isActive?.toString(),
          'include_deleted': includeDeleted ? 'true' : null,
          'sort_by': 'name',
          'order': 'asc',
        }),
      ),
      decoder: (Object? data) =>
          _decodeFacilityPage(data, request: request).page,
    );
  }

  @override
  Future<Result<AppPage<DepartmentProfile>>> listDepartments({
    required AppPageRequest request,
    String? tenantId,
    String? facilityId,
    String? search,
    bool? isActive,
    bool includeDeleted = false,
  }) {
    return _apiClient.get<AppPage<DepartmentProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.departments,
        queryParameters: _withoutEmpty(<String, String?>{
          'page': '${request.pageIndex + 1}',
          'limit': '${request.pageSize}',
          'tenant_id': tenantId,
          'facility_id': facilityId,
          'search': search,
          'is_active': isActive?.toString(),
          'include_deleted': includeDeleted ? 'true' : null,
          'sort_by': 'name',
          'order': 'asc',
        }),
      ),
      decoder: (Object? data) =>
          _decodeDepartmentPage(data, request: request).page,
    );
  }

  @override
  Future<Result<void>> deleteTenant(String id) {
    return _deleteResource(HmsApiResource.tenants, id);
  }

  @override
  Future<Result<TenantProfile>> restoreTenant(String id) {
    return _apiClient.post<TenantProfile>(
      ApiEndpoints.nested(HmsApiResource.tenants, id, const <String>[
        'restore',
      ]),
      decoder: _decodeTenant,
    );
  }

  @override
  Future<Result<void>> permanentDeleteTenant(String id) {
    return _apiClient.delete<void>(
      ApiEndpoints.nested(HmsApiResource.tenants, id, const <String>[
        'permanent',
      ]),
      decoder: _decodeVoid,
    );
  }

  @override
  Future<Result<void>> deleteFacility(String id) {
    return _deleteResource(HmsApiResource.facilities, id);
  }

  @override
  Future<Result<FacilityProfile>> restoreFacility(String id) {
    return _apiClient.post<FacilityProfile>(
      ApiEndpoints.nested(HmsApiResource.facilities, id, const <String>[
        'restore',
      ]),
      decoder: _decodeFacility,
    );
  }

  @override
  Future<Result<void>> permanentDeleteFacility(String id) {
    return _apiClient.delete<void>(
      ApiEndpoints.nested(HmsApiResource.facilities, id, const <String>[
        'permanent',
      ]),
      decoder: _decodeVoid,
    );
  }

  Future<Result<FacilitySetupSnapshot>> _loadSetupFromWorkspace({
    String? facilityId,
    String? tenantId,
    bool includeDeleted = false,
  }) {
    return _apiClient.get<FacilitySetupSnapshot>(
      ApiEndpoints.nested(
        HmsApiResource.tenantFacilityWorkspace,
        'setup',
        const <String>[],
      ),
      queryParameters: _withoutEmpty(<String, String?>{
        if (_normalizedOptional(tenantId) case final String selectedTenantId)
          'tenant_id': selectedTenantId,
        if (_normalizedOptional(facilityId)
            case final String selectedFacilityId)
          'facility_id': selectedFacilityId,
        'include_deleted': includeDeleted ? 'true' : null,
      }),
      decoder: (Object? data) {
        return FacilitySetupWorkspaceDto.fromResponse(data).toEntity();
      },
    );
  }

  Future<Result<FacilitySetupSnapshot>> _loadSetupComposed({
    String? facilityId,
    String? tenantId,
    bool includeDeleted = false,
  }) async {
    final tenantsResult = await _listTenants();
    return tenantsResult.when(
      success: (List<TenantProfile> tenants) async {
        final TenantProfile? tenant = _selectTenant(tenants, tenantId);
        if (tenant == null) {
          return const Result<FacilitySetupSnapshot>.success(
            FacilitySetupSnapshot(),
          );
        }

        final facilitiesResult = await _listFacilities(tenant.id);
        return facilitiesResult.when(
          success: (List<FacilityProfile> facilities) async {
            final FacilityProfile? selectedFacility = _selectFacility(
              facilities,
              facilityId,
            );
            if (selectedFacility == null) {
              return Result<FacilitySetupSnapshot>.success(
                FacilitySetupSnapshot(tenant: tenant, facilities: facilities),
              );
            }

            final results =
                await Future.wait<Result<Object>>(<Future<Result<Object>>>[
                  _listDepartments(
                    tenant.id,
                    selectedFacility.id,
                    includeDeleted: includeDeleted,
                  ).then((result) => result.map<Object>((value) => value)),
                  _listUnits(
                    tenant.id,
                    selectedFacility.id,
                    includeDeleted: includeDeleted,
                  ).then((result) => result.map<Object>((value) => value)),
                  _facilityContactAddress(
                    tenant.id,
                    selectedFacility.id,
                  ).then((result) => result.map<Object>((value) => value)),
                  _listWards(
                    tenant.id,
                    selectedFacility.id,
                    includeDeleted: includeDeleted,
                  ).then((result) => result.map<Object>((value) => value)),
                  _listRooms(
                    tenant.id,
                    selectedFacility.id,
                    includeDeleted: includeDeleted,
                  ).then((result) => result.map<Object>((value) => value)),
                  _listBeds(
                    tenant.id,
                    selectedFacility.id,
                    includeDeleted: includeDeleted,
                  ).then((result) => result.map<Object>((value) => value)),
                ]);

            final AppFailure? failure = _firstFailure(results);
            if (failure != null) {
              return Result<FacilitySetupSnapshot>.failure(failure);
            }

            return Result<FacilitySetupSnapshot>.success(
              FacilitySetupSnapshot(
                tenant: tenant,
                facility: selectedFacility,
                facilities: facilities,
                departments: _value<List<DepartmentProfile>>(results[0]),
                units: _value<List<UnitProfile>>(results[1]),
                contactAddress: _value<FacilityContactAddress>(results[2]),
                wards: _value<List<WardProfile>>(results[3]),
                rooms: _value<List<RoomProfile>>(results[4]),
                beds: _value<List<BedProfile>>(results[5]),
              ),
            );
          },
          failure: (AppFailure failure) {
            if (_isForbidden(failure)) {
              return Result<FacilitySetupSnapshot>.success(
                FacilitySetupSnapshot(tenant: tenant),
              );
            }

            return Result<FacilitySetupSnapshot>.failure(failure);
          },
        );
      },
      failure: (AppFailure failure) {
        if (_isForbidden(failure)) {
          return const Result<FacilitySetupSnapshot>.success(
            FacilitySetupSnapshot(),
          );
        }

        return Result<FacilitySetupSnapshot>.failure(failure);
      },
    );
  }

  @override
  Future<Result<TenantProfile>> saveTenant({
    String? id,
    required String name,
    String? slug,
    required bool isActive,
    String? currency,
    String? standardConsultationFee,
    bool clearStandardConsultationFee = false,
    String? contactName,
    String? contactEmail,
    String? contactPhone,
    bool confirmSimilar = false,
  }) {
    final String? normalizedCurrency = _normalizedOptional(
      currency,
    )?.toUpperCase();
    final String? normalizedFee = _normalizedOptional(standardConsultationFee);
    final String? normalizedContactName = _normalizedOptional(contactName);
    final String? normalizedContactEmail = _normalizedOptional(contactEmail);
    final String? normalizedContactPhone = _normalizedOptional(contactPhone);
    final bool writeContact =
        contactName != null || contactEmail != null || contactPhone != null;
    final bool writeExtension =
        normalizedCurrency != null ||
        normalizedFee != null ||
        clearStandardConsultationFee ||
        writeContact;
    final Map<String, Object?>? extensionJson = writeExtension
        ? <String, Object?>{
            'currency': ?normalizedCurrency,
            'billing': <String, Object?>{
              'standard_consultation_fee': clearStandardConsultationFee
                  ? null
                  : normalizedFee,
            },
            if (writeContact)
              'contact': <String, Object?>{
                'name': normalizedContactName,
                'email': normalizedContactEmail,
                'phone': normalizedContactPhone,
              },
          }
        : null;
    final payload = <String, Object?>{
      'name': name.trim(),
      'slug': _normalizedOptional(slug),
      'is_active': isActive,
      'extension_json': ?extensionJson,
      if (confirmSimilar) 'confirm_similar': true,
    };
    if (id == null) {
      return _apiClient.post<TenantProfile>(
        ApiEndpoints.collection(HmsApiResource.tenants),
        data: payload,
        decoder: _decodeTenant,
      );
    }

    return _apiClient.put<TenantProfile>(
      ApiEndpoints.byId(HmsApiResource.tenants, id),
      data: payload,
      decoder: _decodeTenant,
    );
  }

  @override
  Future<Result<FacilityProfile>> saveFacility({
    String? id,
    required String tenantId,
    required String name,
    required FacilitySetupType type,
    required bool isActive,
    String? logoUrl,
    bool removeLogo = false,
    String? currency,
    String? standardConsultationFee,
    bool clearStandardConsultationFee = false,
    String? phone,
    String? email,
    String? addressLine1,
    String? city,
    String? country,
    bool confirmSimilar = false,
  }) {
    final String? normalizedLogoUrl = _normalizedOptional(logoUrl);
    final String? normalizedCurrency = _normalizedOptional(
      currency,
    )?.toUpperCase();
    final String? normalizedFee = _normalizedOptional(standardConsultationFee);
    final bool writeBilling =
        normalizedFee != null || clearStandardConsultationFee;
    final bool writeExtension =
        normalizedLogoUrl != null ||
        removeLogo ||
        normalizedCurrency != null ||
        writeBilling;
    final Map<String, Object?>? extensionJson = writeExtension
        ? <String, Object?>{
            'logo_url': ?normalizedLogoUrl,
            if (removeLogo) 'logo_url': null,
            'currency': ?normalizedCurrency,
            if (writeBilling)
              'billing': <String, Object?>{
                'standard_consultation_fee': clearStandardConsultationFee
                    ? null
                    : normalizedFee,
              },
          }
        : null;
    final payload = <String, Object?>{
      if (id == null) 'tenant_id': tenantId,
      'name': name.trim(),
      'facility_type': type.apiValue,
      'is_active': isActive,
      'extension_json': ?extensionJson,
      if (confirmSimilar) 'confirm_similar': true,
      'phone': ?_normalizedOptional(phone),
      'email': ?_normalizedOptional(email),
      'address_line1': ?_normalizedOptional(addressLine1),
      'city': ?_normalizedOptional(city),
      'country': ?_normalizedOptional(country),
    };
    if (id == null) {
      return _apiClient.post<FacilityProfile>(
        ApiEndpoints.collection(HmsApiResource.facilities),
        data: payload,
        decoder: _decodeFacility,
      );
    }

    return _apiClient.put<FacilityProfile>(
      ApiEndpoints.byId(HmsApiResource.facilities, id),
      data: payload,
      decoder: _decodeFacility,
    );
  }

  @override
  Future<Result<String>> uploadFacilityLogo({
    required String facilityId,
    required List<int> bytes,
    required String fileName,
    String? mimeType,
  }) {
    final FormData formData = FormData();
    formData.files.add(
      MapEntry<String, MultipartFile>(
        'logo',
        MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: mimeType == null ? null : DioMediaType.parse(mimeType),
        ),
      ),
    );

    return _apiClient.post<String>(
      ApiEndpoints.nested(
        HmsApiResource.tenantFacilityWorkspace,
        'facilities',
        <String>[facilityId, 'logo'],
      ),
      data: formData,
      decoder: (Object? data) {
        return ApiResponseEnvelope.decodeData<String>(
          data,
          decoder: (Object? payload) {
            if (payload is! JsonMap) {
              throw const FormatException(
                'Expected logo upload response object.',
              );
            }

            final Object? logoUrlValue = payload['logo_url'];
            if (logoUrlValue is! String || logoUrlValue.trim().isEmpty) {
              throw const FormatException(
                'Expected logo_url in upload response.',
              );
            }

            return logoUrlValue.trim();
          },
        );
      },
    );
  }

  @override
  Future<Result<void>> deleteFacilityLogo(String facilityId) {
    return _apiClient.delete<void>(
      ApiEndpoints.nested(
        HmsApiResource.tenantFacilityWorkspace,
        'facilities',
        <String>[facilityId, 'logo'],
      ),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> saveFacilityContactAddress({
    required String tenantId,
    required String facilityId,
    String? phone,
    String? email,
    String? addressLine1,
    String? city,
    String? country,
  }) async {
    final results = await Future.wait<Result<void>>(<Future<Result<void>>>[
      _upsertContact(
        tenantId: tenantId,
        facilityId: facilityId,
        type: 'PHONE',
        value: phone,
      ),
      _upsertContact(
        tenantId: tenantId,
        facilityId: facilityId,
        type: 'EMAIL',
        value: email,
      ),
      _upsertAddress(
        tenantId: tenantId,
        facilityId: facilityId,
        line1: addressLine1,
        city: city,
        country: country,
      ),
    ]);

    final AppFailure? failure = _firstFailure(results);
    if (failure != null) {
      return Result<void>.failure(failure);
    }

    return const Result<void>.success(null);
  }

  @override
  Future<Result<DepartmentProfile>> saveDepartment({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    String? shortName,
    required DepartmentSetupType type,
    required bool isActive,
  }) {
    final String? normalizedShortName = _normalizedOptional(shortName);
    final payload = <String, Object?>{
      if (id == null) 'tenant_id': tenantId,
      'facility_id': facilityId,
      'name': name.trim(),
      'short_name': normalizedShortName,
      'department_type': type.apiValue,
      'is_active': isActive,
    };

    if (id == null) {
      return _apiClient.post<DepartmentProfile>(
        ApiEndpoints.collection(HmsApiResource.departments),
        data: payload,
        decoder: _decodeDepartment,
      );
    }

    return _apiClient.put<DepartmentProfile>(
      ApiEndpoints.byId(HmsApiResource.departments, id),
      data: payload,
      decoder: _decodeDepartment,
    );
  }

  @override
  Future<Result<void>> deleteDepartment(String id) {
    return _deleteResource(HmsApiResource.departments, id);
  }

  @override
  Future<Result<DepartmentProfile>> restoreDepartment(String id) {
    return _apiClient.post<DepartmentProfile>(
      ApiEndpoints.nested(HmsApiResource.departments, id, const <String>[
        'restore',
      ]),
      decoder: _decodeDepartment,
    );
  }

  @override
  Future<Result<void>> permanentDeleteDepartment(String id) {
    return _apiClient.delete<void>(
      ApiEndpoints.nested(HmsApiResource.departments, id, const <String>[
        'permanent',
      ]),
      decoder: _decodeVoid,
    );
  }

  @override
  Future<Result<UnitProfile>> saveUnit({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    String? departmentId,
    required bool isActive,
  }) {
    final String? normalizedDepartmentId = _normalizedOptional(departmentId);
    final payload = <String, Object?>{
      if (id == null) 'tenant_id': tenantId,
      'facility_id': facilityId,
      'department_id': normalizedDepartmentId,
      'name': name.trim(),
      'is_active': isActive,
    };

    if (id == null) {
      return _apiClient.post<UnitProfile>(
        ApiEndpoints.collection(HmsApiResource.units),
        data: payload,
        decoder: _decodeUnit,
      );
    }

    return _apiClient.put<UnitProfile>(
      ApiEndpoints.byId(HmsApiResource.units, id),
      data: payload,
      decoder: _decodeUnit,
    );
  }

  @override
  Future<Result<void>> deleteUnit(String id) {
    return _deleteResource(HmsApiResource.units, id);
  }

  @override
  Future<Result<UnitProfile>> restoreUnit(String id) {
    return _apiClient.post<UnitProfile>(
      ApiEndpoints.nested(HmsApiResource.units, id, const <String>['restore']),
      decoder: _decodeUnit,
    );
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
    final String? normalizedDepartmentId = _normalizedOptional(departmentId);
    final payload = <String, Object?>{
      if (id == null) 'tenant_id': tenantId,
      'facility_id': facilityId,
      'department_id': normalizedDepartmentId,
      'name': name.trim(),
      'ward_type': type.apiValue,
      'is_active': isActive,
    };

    if (id == null) {
      return _apiClient.post<WardProfile>(
        ApiEndpoints.collection(HmsApiResource.wards),
        data: payload,
        decoder: _decodeWard,
      );
    }

    return _apiClient.put<WardProfile>(
      ApiEndpoints.byId(HmsApiResource.wards, id),
      data: payload,
      decoder: _decodeWard,
    );
  }

  @override
  Future<Result<void>> deleteWard(String id) {
    return _deleteResource(HmsApiResource.wards, id);
  }

  @override
  Future<Result<WardProfile>> restoreWard(String id) {
    return _apiClient.post<WardProfile>(
      ApiEndpoints.nested(HmsApiResource.wards, id, const <String>['restore']),
      decoder: _decodeWard,
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
    final String? normalizedWardId = _normalizedOptional(wardId);
    final String? normalizedFloor = _normalizedOptional(floor);
    final payload = <String, Object?>{
      if (id == null) 'tenant_id': tenantId,
      'facility_id': facilityId,
      'ward_id': normalizedWardId,
      'name': name.trim(),
      'floor': normalizedFloor,
    };

    if (id == null) {
      return _apiClient.post<RoomProfile>(
        ApiEndpoints.collection(HmsApiResource.rooms),
        data: payload,
        decoder: _decodeRoom,
      );
    }

    return _apiClient.put<RoomProfile>(
      ApiEndpoints.byId(HmsApiResource.rooms, id),
      data: payload,
      decoder: _decodeRoom,
    );
  }

  @override
  Future<Result<void>> deleteRoom(String id) {
    return _deleteResource(HmsApiResource.rooms, id);
  }

  @override
  Future<Result<RoomProfile>> restoreRoom(String id) {
    return _apiClient.post<RoomProfile>(
      ApiEndpoints.nested(HmsApiResource.rooms, id, const <String>['restore']),
      decoder: _decodeRoom,
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
    final String? normalizedRoomId = _normalizedOptional(roomId);
    final payload = <String, Object?>{
      if (id == null) 'tenant_id': tenantId,
      'facility_id': facilityId,
      'ward_id': wardId,
      'room_id': normalizedRoomId,
      'label': label.trim(),
      'status': status.apiValue,
    };

    if (id == null) {
      return _apiClient.post<BedProfile>(
        ApiEndpoints.collection(HmsApiResource.beds),
        data: payload,
        decoder: _decodeBed,
      );
    }

    return _apiClient.put<BedProfile>(
      ApiEndpoints.byId(HmsApiResource.beds, id),
      data: payload,
      decoder: _decodeBed,
    );
  }

  @override
  Future<Result<void>> deleteBed(String id) {
    return _deleteResource(HmsApiResource.beds, id);
  }

  @override
  Future<Result<BedProfile>> restoreBed(String id) {
    return _apiClient.post<BedProfile>(
      ApiEndpoints.nested(HmsApiResource.beds, id, const <String>['restore']),
      decoder: _decodeBed,
    );
  }

  Future<Result<List<TenantProfile>>> _listTenants() {
    return _apiClient.get<List<TenantProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.tenants,
        queryParameters: const <String, String>{'limit': '25'},
      ),
      decoder: (data) => ApiResponseEnvelope.decodeData<List<TenantProfile>>(
        data,
        decoder: (payload) => decodeList<TenantProfileDto>(
          payload,
          TenantProfileDto.fromJson,
        ).map((dto) => dto.toEntity()).toList(growable: false),
      ),
    );
  }

  Future<Result<List<FacilityProfile>>> _listFacilities(String tenantId) {
    return _apiClient.get<List<FacilityProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.facilities,
        queryParameters: <String, String>{
          'tenant_id': tenantId,
          'limit': _setupListLimit,
          'sort_by': 'name',
          'order': 'asc',
        },
      ),
      decoder: (data) => ApiResponseEnvelope.decodeData<List<FacilityProfile>>(
        data,
        decoder: (payload) => decodeList<FacilityProfileDto>(
          payload,
          FacilityProfileDto.fromJson,
        ).map((dto) => dto.toEntity()).toList(growable: false),
      ),
    );
  }

  Future<Result<List<DepartmentProfile>>> _listDepartments(
    String tenantId,
    String facilityId, {
    bool includeDeleted = false,
  }) async {
    final result = await _apiClient.get<List<DepartmentProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.departments,
        queryParameters: _facilityQuery(
          tenantId,
          facilityId,
          includeDeleted: includeDeleted,
        ),
      ),
      decoder: (data) =>
          ApiResponseEnvelope.decodeData<List<DepartmentProfile>>(
            data,
            decoder: (payload) => decodeList<DepartmentProfileDto>(
              payload,
              DepartmentProfileDto.fromJson,
            ).map((dto) => dto.toEntity()).toList(growable: false),
          ),
    );

    return _emptyListOnForbidden(result);
  }

  Future<Result<List<UnitProfile>>> _listUnits(
    String tenantId,
    String facilityId, {
    bool includeDeleted = false,
  }) async {
    final result = await _apiClient.get<List<UnitProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.units,
        queryParameters: _facilityQuery(
          tenantId,
          facilityId,
          includeDeleted: includeDeleted,
        ),
      ),
      decoder: (data) => ApiResponseEnvelope.decodeData<List<UnitProfile>>(
        data,
        decoder: (payload) => decodeList<UnitProfileDto>(
          payload,
          UnitProfileDto.fromJson,
        ).map((dto) => dto.toEntity()).toList(growable: false),
      ),
    );

    return _emptyListOnForbidden(result);
  }

  Future<Result<List<WardProfile>>> _listWards(
    String tenantId,
    String facilityId, {
    bool includeDeleted = false,
  }) async {
    final result = await _apiClient.get<List<WardProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.wards,
        queryParameters: _facilityQuery(
          tenantId,
          facilityId,
          includeDeleted: includeDeleted,
        ),
      ),
      decoder: (data) => ApiResponseEnvelope.decodeData<List<WardProfile>>(
        data,
        decoder: (payload) => decodeList<WardProfileDto>(
          payload,
          WardProfileDto.fromJson,
        ).map((dto) => dto.toEntity()).toList(growable: false),
      ),
    );

    return _emptyListOnForbidden(result);
  }

  Future<Result<List<RoomProfile>>> _listRooms(
    String tenantId,
    String facilityId, {
    bool includeDeleted = false,
  }) async {
    final result = await _apiClient.get<List<RoomProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.rooms,
        queryParameters: _facilityQuery(
          tenantId,
          facilityId,
          includeDeleted: includeDeleted,
        ),
      ),
      decoder: (data) => ApiResponseEnvelope.decodeData<List<RoomProfile>>(
        data,
        decoder: (payload) => decodeList<RoomProfileDto>(
          payload,
          RoomProfileDto.fromJson,
        ).map((dto) => dto.toEntity()).toList(growable: false),
      ),
    );

    return _emptyListOnForbidden(result);
  }

  Future<Result<List<BedProfile>>> _listBeds(
    String tenantId,
    String facilityId, {
    bool includeDeleted = false,
  }) async {
    final result = await _apiClient.get<List<BedProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.beds,
        queryParameters: _facilityQuery(
          tenantId,
          facilityId,
          sortBy: 'label',
          includeDeleted: includeDeleted,
        ),
      ),
      decoder: (data) => ApiResponseEnvelope.decodeData<List<BedProfile>>(
        data,
        decoder: (payload) => decodeList<BedProfileDto>(
          payload,
          BedProfileDto.fromJson,
        ).map((dto) => dto.toEntity()).toList(growable: false),
      ),
    );

    return _emptyListOnForbidden(result);
  }

  Future<Result<FacilityContactAddress>> _facilityContactAddress(
    String tenantId,
    String facilityId,
  ) async {
    final contactsResult = await _listContacts(tenantId, facilityId);
    if (contactsResult case ResultFailure<List<ContactDto>>(:final failure)) {
      return Result<FacilityContactAddress>.failure(failure);
    }

    final addressResult = await _listAddresses(tenantId, facilityId);
    if (addressResult case ResultFailure<List<AddressDto>>(:final failure)) {
      return Result<FacilityContactAddress>.failure(failure);
    }

    final contacts = (contactsResult as ResultSuccess<List<ContactDto>>).value;
    final addresses = (addressResult as ResultSuccess<List<AddressDto>>).value;
    final ContactDto? phone = contacts
        .where((contact) => contact.type == 'PHONE')
        .firstOrNull;
    final ContactDto? email = contacts
        .where((contact) => contact.type == 'EMAIL')
        .firstOrNull;
    final AddressDto? address = addresses.firstOrNull;

    return Result<FacilityContactAddress>.success(
      FacilityContactAddress(
        phone: phone?.value,
        email: email?.value,
        addressLine1: address?.line1,
        city: address?.city,
        country: address?.country,
      ),
    );
  }

  Future<Result<List<ContactDto>>> _listContacts(
    String tenantId,
    String facilityId, {
    String? type,
  }) async {
    final result = await _apiClient.get<List<ContactDto>>(
      ApiEndpoints.collection(
        HmsApiResource.contacts,
        queryParameters: <String, String>{
          'tenant_id': tenantId,
          'facility_id': facilityId,
          if (type case final String contactType) 'contact_type': contactType,
          'limit': '10',
        },
      ),
      decoder: (data) => ApiResponseEnvelope.decodeData<List<ContactDto>>(
        data,
        decoder: (payload) =>
            decodeList<ContactDto>(payload, ContactDto.fromJson),
      ),
    );

    return _emptyListOnForbidden(result);
  }

  Future<Result<List<AddressDto>>> _listAddresses(
    String tenantId,
    String facilityId,
  ) async {
    final result = await _apiClient.get<List<AddressDto>>(
      ApiEndpoints.collection(
        HmsApiResource.addresses,
        queryParameters: <String, String>{
          'tenant_id': tenantId,
          'facility_id': facilityId,
          'limit': '1',
        },
      ),
      decoder: (data) => ApiResponseEnvelope.decodeData<List<AddressDto>>(
        data,
        decoder: (payload) =>
            decodeList<AddressDto>(payload, AddressDto.fromJson),
      ),
    );

    return _emptyListOnForbidden(result);
  }

  Future<Result<void>> _upsertContact({
    required String tenantId,
    required String facilityId,
    required String type,
    String? value,
  }) async {
    final String? normalizedValue = _normalizedOptional(value);
    if (normalizedValue == null) {
      return const Result<void>.success(null);
    }

    final existingResult = await _listContacts(
      tenantId,
      facilityId,
      type: type,
    );
    if (existingResult case ResultFailure<List<ContactDto>>(:final failure)) {
      return Result<void>.failure(failure);
    }

    final ContactDto? existing =
        (existingResult as ResultSuccess<List<ContactDto>>).value.firstOrNull;
    final Uri endpoint = existing == null
        ? ApiEndpoints.collection(HmsApiResource.contacts)
        : ApiEndpoints.byId(HmsApiResource.contacts, existing.id);
    final payload = <String, Object?>{
      if (existing == null) 'tenant_id': tenantId,
      'facility_id': facilityId,
      'contact_type': type,
      'value': normalizedValue,
      'is_primary': true,
    };
    final Future<Result<void>> Function(
      Uri, {
      required ApiResponseDecoder<void> decoder,
      Object? data,
    })
    method = existing == null ? _apiClient.post<void> : _apiClient.put;

    return method(endpoint, data: payload, decoder: _decodeVoid);
  }

  Future<Result<void>> _upsertAddress({
    required String tenantId,
    required String facilityId,
    String? line1,
    String? city,
    String? country,
  }) async {
    final String? normalizedLine1 = _normalizedOptional(line1);
    if (normalizedLine1 == null) {
      return const Result<void>.success(null);
    }

    final existingResult = await _listAddresses(tenantId, facilityId);
    if (existingResult case ResultFailure<List<AddressDto>>(:final failure)) {
      return Result<void>.failure(failure);
    }

    final AddressDto? existing =
        (existingResult as ResultSuccess<List<AddressDto>>).value.firstOrNull;
    final Uri endpoint = existing == null
        ? ApiEndpoints.collection(HmsApiResource.addresses)
        : ApiEndpoints.byId(HmsApiResource.addresses, existing.id);
    final payload = <String, Object?>{
      if (existing == null) 'tenant_id': tenantId,
      'facility_id': facilityId,
      'address_type': 'WORK',
      'line1': normalizedLine1,
      if (_normalizedOptional(city) case final String cityValue)
        'city': cityValue,
      if (_normalizedOptional(country) case final String countryValue)
        'country': countryValue,
    };
    final Future<Result<void>> Function(
      Uri, {
      required ApiResponseDecoder<void> decoder,
      Object? data,
    })
    method = existing == null ? _apiClient.post<void> : _apiClient.put;

    return method(endpoint, data: payload, decoder: _decodeVoid);
  }

  Future<Result<void>> _deleteResource(HmsApiResource resource, String id) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(resource, id),
      decoder: _decodeVoid,
    );
  }

  static Map<String, String> _facilityQuery(
    String tenantId,
    String facilityId, {
    String sortBy = 'name',
    bool includeDeleted = false,
  }) {
    return <String, String>{
      'tenant_id': tenantId,
      'facility_id': facilityId,
      'limit': _setupListLimit,
      'sort_by': sortBy,
      'order': 'asc',
      if (includeDeleted) 'include_deleted': 'true',
    };
  }

  static TenantProfile? _selectTenant(
    List<TenantProfile> tenants,
    String? tenantId,
  ) {
    final String? normalizedTenantId = _normalizedOptional(tenantId);
    if (normalizedTenantId == null) {
      return tenants.firstOrNull;
    }

    return tenants
            .where(
              (TenantProfile tenant) =>
                  tenant.id == normalizedTenantId ||
                  tenant.mutationId == normalizedTenantId,
            )
            .firstOrNull ??
        tenants.firstOrNull;
  }

  static FacilityProfile? _selectFacility(
    List<FacilityProfile> facilities,
    String? facilityId,
  ) {
    final String? normalizedFacilityId = _normalizedOptional(facilityId);
    if (normalizedFacilityId == null) {
      return facilities.firstOrNull;
    }

    return facilities
            .where(
              (FacilityProfile facility) =>
                  facility.id == normalizedFacilityId ||
                  facility.mutationId == normalizedFacilityId,
            )
            .firstOrNull ??
        facilities.firstOrNull;
  }

  static JsonMap _requireMap(Object? value) {
    if (value is! JsonMap) {
      throw const FormatException('Expected API object data.');
    }

    return value;
  }

  static TenantProfile _decodeTenant(Object? data) {
    return ApiResponseEnvelope.decodeData<TenantProfile>(
      data,
      decoder: (payload) =>
          TenantProfileDto.fromJson(_requireMap(payload)).toEntity(),
    );
  }

  static FacilityProfile _decodeFacility(Object? data) {
    return ApiResponseEnvelope.decodeData<FacilityProfile>(
      data,
      decoder: (payload) =>
          FacilityProfileDto.fromJson(_requireMap(payload)).toEntity(),
    );
  }

  static DepartmentProfile _decodeDepartment(Object? data) {
    return ApiResponseEnvelope.decodeData<DepartmentProfile>(
      data,
      decoder: (payload) =>
          DepartmentProfileDto.fromJson(_requireMap(payload)).toEntity(),
    );
  }

  static UnitProfile _decodeUnit(Object? data) {
    return ApiResponseEnvelope.decodeData<UnitProfile>(
      data,
      decoder: (payload) =>
          UnitProfileDto.fromJson(_requireMap(payload)).toEntity(),
    );
  }

  static WardProfile _decodeWard(Object? data) {
    return ApiResponseEnvelope.decodeData<WardProfile>(
      data,
      decoder: (payload) =>
          WardProfileDto.fromJson(_requireMap(payload)).toEntity(),
    );
  }

  static RoomProfile _decodeRoom(Object? data) {
    return ApiResponseEnvelope.decodeData<RoomProfile>(
      data,
      decoder: (payload) =>
          RoomProfileDto.fromJson(_requireMap(payload)).toEntity(),
    );
  }

  static BedProfile _decodeBed(Object? data) {
    return ApiResponseEnvelope.decodeData<BedProfile>(
      data,
      decoder: (payload) =>
          BedProfileDto.fromJson(_requireMap(payload)).toEntity(),
    );
  }

  static void _decodeVoid(Object? data) {
    if (data == null) {
      return;
    }

    ApiResponseEnvelope.decodeData<void>(data, decoder: (_) {});
  }

  static String? _normalizedOptional(String? value) {
    final String? normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static AppFailure? _firstFailure(Iterable<Result<Object?>> results) {
    for (final result in results) {
      if (result case ResultFailure<Object?>(:final failure)) {
        if (_isForbidden(failure)) {
          continue;
        }

        return failure;
      }
    }

    return null;
  }

  static T _value<T>(Result<Object> result) {
    return (result as ResultSuccess<Object>).value as T;
  }

  static Result<List<T>> _emptyListOnForbidden<T>(Result<List<T>> result) {
    return result.when(
      success: (List<T> value) => Result<List<T>>.success(value),
      failure: (AppFailure failure) {
        if (_isForbidden(failure)) {
          return Result<List<T>>.success(<T>[]);
        }

        return Result<List<T>>.failure(failure);
      },
    );
  }

  static bool _isForbidden(AppFailure failure) {
    return failure.category == AppFailureCategory.forbidden;
  }

  static Map<String, String> _withoutEmpty(Map<String, String?> values) {
    return <String, String>{
      for (final MapEntry<String, String?> entry in values.entries)
        if (entry.value != null && entry.value!.trim().isNotEmpty)
          entry.key: entry.value!.trim(),
    };
  }

  static _TenantPageDto _decodeTenantPage(
    Object? data, {
    required AppPageRequest request,
  }) {
    final JsonMap envelope = _requireMap(data);
    final List<TenantProfile> items = decodeList<TenantProfileDto>(
      envelope['data'],
      TenantProfileDto.fromJson,
    ).map((TenantProfileDto dto) => dto.toEntity()).toList(growable: false);
    final Object? paginationValue = envelope['pagination'];
    final JsonMap? pagination = paginationValue is JsonMap
        ? paginationValue
        : null;
    final int? total = pagination != null
        ? _optionalInt(pagination['total'])
        : null;
    return _TenantPageDto(
      page: AppPage<TenantProfile>(
        items: items,
        request: request,
        totalItemCount: total,
      ),
    );
  }

  static _FacilityPageDto _decodeFacilityPage(
    Object? data, {
    required AppPageRequest request,
  }) {
    final JsonMap envelope = _requireMap(data);
    final List<FacilityProfile> items = decodeList<FacilityProfileDto>(
      envelope['data'],
      FacilityProfileDto.fromJson,
    ).map((FacilityProfileDto dto) => dto.toEntity()).toList(growable: false);
    final Object? paginationValue = envelope['pagination'];
    final JsonMap? pagination = paginationValue is JsonMap
        ? paginationValue
        : null;
    final int? total = pagination != null
        ? _optionalInt(pagination['total'])
        : null;
    return _FacilityPageDto(
      page: AppPage<FacilityProfile>(
        items: items,
        request: request,
        totalItemCount: total,
      ),
    );
  }

  static _DepartmentPageDto _decodeDepartmentPage(
    Object? data, {
    required AppPageRequest request,
  }) {
    final JsonMap envelope = _requireMap(data);
    final List<DepartmentProfile> items = decodeList<DepartmentProfileDto>(
      envelope['data'],
      DepartmentProfileDto.fromJson,
    ).map((DepartmentProfileDto dto) => dto.toEntity()).toList(growable: false);
    final Object? paginationValue = envelope['pagination'];
    final JsonMap? pagination = paginationValue is JsonMap
        ? paginationValue
        : null;
    final int? total = pagination != null
        ? _optionalInt(pagination['total'])
        : null;
    return _DepartmentPageDto(
      page: AppPage<DepartmentProfile>(
        items: items,
        request: request,
        totalItemCount: total,
      ),
    );
  }

  static int? _optionalInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

final class _TenantPageDto {
  const _TenantPageDto({required this.page});

  final AppPage<TenantProfile> page;
}

final class _FacilityPageDto {
  const _FacilityPageDto({required this.page});

  final AppPage<FacilityProfile> page;
}

final class _DepartmentPageDto {
  const _DepartmentPageDto({required this.page});

  final AppPage<DepartmentProfile> page;
}
