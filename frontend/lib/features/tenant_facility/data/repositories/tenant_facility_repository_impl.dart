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
  Future<Result<FacilitySetupSnapshot>> loadSetup({String? facilityId}) async {
    final tenantsResult = await _listTenants();
    return tenantsResult.when(
      success: (List<TenantProfile> tenants) async {
        final TenantProfile? tenant = tenants.firstOrNull;
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
                  _listBranches(
                    tenant.id,
                    selectedFacility.id,
                  ).then((result) => result.map<Object>((value) => value)),
                  _listDepartments(
                    tenant.id,
                    selectedFacility.id,
                  ).then((result) => result.map<Object>((value) => value)),
                  _listUnits(
                    tenant.id,
                    selectedFacility.id,
                  ).then((result) => result.map<Object>((value) => value)),
                  _facilityContactAddress(
                    tenant.id,
                    selectedFacility.id,
                  ).then((result) => result.map<Object>((value) => value)),
                  _listWards(
                    tenant.id,
                    selectedFacility.id,
                  ).then((result) => result.map<Object>((value) => value)),
                  _listRooms(
                    tenant.id,
                    selectedFacility.id,
                  ).then((result) => result.map<Object>((value) => value)),
                  _listBeds(
                    tenant.id,
                    selectedFacility.id,
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
                branches: _value<List<BranchProfile>>(results[0]),
                departments: _value<List<DepartmentProfile>>(results[1]),
                units: _value<List<UnitProfile>>(results[2]),
                contactAddress: _value<FacilityContactAddress>(results[3]),
                wards: _value<List<WardProfile>>(results[4]),
                rooms: _value<List<RoomProfile>>(results[5]),
                beds: _value<List<BedProfile>>(results[6]),
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
  }) {
    final payload = <String, Object?>{
      'name': name.trim(),
      'slug': _normalizedOptional(slug),
      'is_active': isActive,
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
  }) {
    final String? normalizedLogoUrl = _normalizedOptional(logoUrl);
    final payload = <String, Object?>{
      if (id == null) 'tenant_id': tenantId,
      'name': name.trim(),
      'facility_type': type.apiValue,
      'is_active': isActive,
      'extension_json': <String, Object?>{
        if (normalizedLogoUrl case final String logoUrl) 'logo_url': logoUrl,
      },
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
  Future<Result<BranchProfile>> saveBranch({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    required bool isActive,
  }) {
    final payload = <String, Object?>{
      if (id == null) 'tenant_id': tenantId,
      'facility_id': facilityId,
      'name': name.trim(),
      'is_active': isActive,
    };

    if (id == null) {
      return _apiClient.post<BranchProfile>(
        ApiEndpoints.collection(HmsApiResource.branches),
        data: payload,
        decoder: _decodeBranch,
      );
    }

    return _apiClient.put<BranchProfile>(
      ApiEndpoints.byId(HmsApiResource.branches, id),
      data: payload,
      decoder: _decodeBranch,
    );
  }

  @override
  Future<Result<void>> deleteBranch(String id) {
    return _deleteResource(HmsApiResource.branches, id);
  }

  @override
  Future<Result<DepartmentProfile>> saveDepartment({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    String? shortName,
    String? branchId,
    required DepartmentSetupType type,
    required bool isActive,
  }) {
    final String? normalizedShortName = _normalizedOptional(shortName);
    final String? normalizedBranchId = _normalizedOptional(branchId);
    final payload = <String, Object?>{
      if (id == null) 'tenant_id': tenantId,
      'facility_id': facilityId,
      'branch_id': normalizedBranchId,
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

  Future<Result<List<BranchProfile>>> _listBranches(
    String tenantId,
    String facilityId,
  ) async {
    final result = await _apiClient.get<List<BranchProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.branches,
        queryParameters: _facilityQuery(tenantId, facilityId),
      ),
      decoder: (data) => ApiResponseEnvelope.decodeData<List<BranchProfile>>(
        data,
        decoder: (payload) => decodeList<BranchProfileDto>(
          payload,
          BranchProfileDto.fromJson,
        ).map((dto) => dto.toEntity()).toList(growable: false),
      ),
    );

    return _emptyListOnForbidden(result);
  }

  Future<Result<List<DepartmentProfile>>> _listDepartments(
    String tenantId,
    String facilityId,
  ) async {
    final result = await _apiClient.get<List<DepartmentProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.departments,
        queryParameters: _facilityQuery(tenantId, facilityId),
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
    String facilityId,
  ) async {
    final result = await _apiClient.get<List<UnitProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.units,
        queryParameters: _facilityQuery(tenantId, facilityId),
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
    String facilityId,
  ) async {
    final result = await _apiClient.get<List<WardProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.wards,
        queryParameters: _facilityQuery(tenantId, facilityId),
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
    String facilityId,
  ) async {
    final result = await _apiClient.get<List<RoomProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.rooms,
        queryParameters: _facilityQuery(tenantId, facilityId),
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
    String facilityId,
  ) async {
    final result = await _apiClient.get<List<BedProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.beds,
        queryParameters: _facilityQuery(tenantId, facilityId, sortBy: 'label'),
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
  }) {
    return <String, String>{
      'tenant_id': tenantId,
      'facility_id': facilityId,
      'limit': _setupListLimit,
      'sort_by': sortBy,
      'order': 'asc',
    };
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
            .where((facility) => facility.id == normalizedFacilityId)
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

  static BranchProfile _decodeBranch(Object? data) {
    return ApiResponseEnvelope.decodeData<BranchProfile>(
      data,
      decoder: (payload) =>
          BranchProfileDto.fromJson(_requireMap(payload)).toEntity(),
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
}
