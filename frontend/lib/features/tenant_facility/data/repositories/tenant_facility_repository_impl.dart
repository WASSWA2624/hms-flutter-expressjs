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

  final ApiClient _apiClient;

  @override
  Future<Result<FacilitySetupSnapshot>> loadSetup() async {
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
            final FacilityProfile? facility = facilities.firstOrNull;
            if (facility == null) {
              return Result<FacilitySetupSnapshot>.success(
                FacilitySetupSnapshot(tenant: tenant),
              );
            }

            final results =
                await Future.wait<Result<Object>>(<Future<Result<Object>>>[
                  _listBranches(
                    tenant.id,
                    facility.id,
                  ).then((result) => result.map<Object>((value) => value)),
                  _listDepartments(
                    tenant.id,
                    facility.id,
                  ).then((result) => result.map<Object>((value) => value)),
                  _listUnits(
                    tenant.id,
                    facility.id,
                  ).then((result) => result.map<Object>((value) => value)),
                  _facilityContactAddress(
                    tenant.id,
                    facility.id,
                  ).then((result) => result.map<Object>((value) => value)),
                  _countResource(
                    HmsApiResource.rooms,
                    tenant.id,
                    facility.id,
                  ).then((result) => result.map<Object>((value) => value)),
                  _countResource(
                    HmsApiResource.wards,
                    tenant.id,
                    facility.id,
                  ).then((result) => result.map<Object>((value) => value)),
                  _countResource(
                    HmsApiResource.beds,
                    tenant.id,
                    facility.id,
                  ).then((result) => result.map<Object>((value) => value)),
                ]);

            final AppFailure? failure = _firstFailure(results);
            if (failure != null) {
              return Result<FacilitySetupSnapshot>.failure(failure);
            }

            return Result<FacilitySetupSnapshot>.success(
              FacilitySetupSnapshot(
                tenant: tenant,
                facility: facility,
                branches: _value<List<BranchProfile>>(results[0]),
                departments: _value<List<DepartmentProfile>>(results[1]),
                units: _value<List<UnitProfile>>(results[2]),
                contactAddress: _value<FacilityContactAddress>(results[3]),
                roomsCount: _value<int>(results[4]),
                wardsCount: _value<int>(results[5]),
                bedsCount: _value<int>(results[6]),
              ),
            );
          },
          failure: (AppFailure failure) =>
              Result<FacilitySetupSnapshot>.failure(failure),
        );
      },
      failure: (AppFailure failure) =>
          Result<FacilitySetupSnapshot>.failure(failure),
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
    final payload = <String, Object?>{
      if (id == null) 'tenant_id': tenantId,
      'name': name.trim(),
      'facility_type': type.apiValue,
      'is_active': isActive,
      'extension_json': <String, Object?>{
        if (_normalizedOptional(logoUrl) != null)
          'logo_url': _normalizedOptional(logoUrl),
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
  Future<Result<BranchProfile>> createBranch({
    required String tenantId,
    required String facilityId,
    required String name,
    required bool isActive,
  }) {
    return _apiClient.post<BranchProfile>(
      ApiEndpoints.collection(HmsApiResource.branches),
      data: <String, Object?>{
        'tenant_id': tenantId,
        'facility_id': facilityId,
        'name': name.trim(),
        'is_active': isActive,
      },
      decoder: (data) => ApiResponseEnvelope.decodeData<BranchProfile>(
        data,
        decoder: (payload) =>
            BranchProfileDto.fromJson(_requireMap(payload)).toEntity(),
      ),
    );
  }

  @override
  Future<Result<DepartmentProfile>> createDepartment({
    required String tenantId,
    required String facilityId,
    required String name,
    String? shortName,
    required DepartmentSetupType type,
    required bool isActive,
  }) {
    return _apiClient.post<DepartmentProfile>(
      ApiEndpoints.collection(HmsApiResource.departments),
      data: <String, Object?>{
        'tenant_id': tenantId,
        'facility_id': facilityId,
        'name': name.trim(),
        if (_normalizedOptional(shortName) != null)
          'short_name': _normalizedOptional(shortName),
        'department_type': type.apiValue,
        'is_active': isActive,
      },
      decoder: (data) => ApiResponseEnvelope.decodeData<DepartmentProfile>(
        data,
        decoder: (payload) =>
            DepartmentProfileDto.fromJson(_requireMap(payload)).toEntity(),
      ),
    );
  }

  @override
  Future<Result<UnitProfile>> createUnit({
    required String tenantId,
    required String facilityId,
    required String name,
    String? departmentId,
    required bool isActive,
  }) {
    return _apiClient.post<UnitProfile>(
      ApiEndpoints.collection(HmsApiResource.units),
      data: <String, Object?>{
        'tenant_id': tenantId,
        'facility_id': facilityId,
        if (_normalizedOptional(departmentId) != null)
          'department_id': _normalizedOptional(departmentId),
        'name': name.trim(),
        'is_active': isActive,
      },
      decoder: (data) => ApiResponseEnvelope.decodeData<UnitProfile>(
        data,
        decoder: (payload) =>
            UnitProfileDto.fromJson(_requireMap(payload)).toEntity(),
      ),
    );
  }

  Future<Result<List<TenantProfile>>> _listTenants() {
    return _apiClient.get<List<TenantProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.tenants,
        queryParameters: const <String, String>{'limit': '1'},
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
        queryParameters: <String, String>{'tenant_id': tenantId, 'limit': '1'},
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
  ) {
    return _apiClient.get<List<BranchProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.branches,
        queryParameters: <String, String>{
          'tenant_id': tenantId,
          'facility_id': facilityId,
          'limit': '10',
        },
      ),
      decoder: (data) => ApiResponseEnvelope.decodeData<List<BranchProfile>>(
        data,
        decoder: (payload) => decodeList<BranchProfileDto>(
          payload,
          BranchProfileDto.fromJson,
        ).map((dto) => dto.toEntity()).toList(growable: false),
      ),
    );
  }

  Future<Result<List<DepartmentProfile>>> _listDepartments(
    String tenantId,
    String facilityId,
  ) {
    return _apiClient.get<List<DepartmentProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.departments,
        queryParameters: <String, String>{
          'tenant_id': tenantId,
          'facility_id': facilityId,
          'limit': '10',
        },
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
  }

  Future<Result<List<UnitProfile>>> _listUnits(
    String tenantId,
    String facilityId,
  ) {
    return _apiClient.get<List<UnitProfile>>(
      ApiEndpoints.collection(
        HmsApiResource.units,
        queryParameters: <String, String>{
          'tenant_id': tenantId,
          'facility_id': facilityId,
          'limit': '10',
        },
      ),
      decoder: (data) => ApiResponseEnvelope.decodeData<List<UnitProfile>>(
        data,
        decoder: (payload) => decodeList<UnitProfileDto>(
          payload,
          UnitProfileDto.fromJson,
        ).map((dto) => dto.toEntity()).toList(growable: false),
      ),
    );
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
  }) {
    return _apiClient.get<List<ContactDto>>(
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
  }

  Future<Result<List<AddressDto>>> _listAddresses(
    String tenantId,
    String facilityId,
  ) {
    return _apiClient.get<List<AddressDto>>(
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

    return method(
      endpoint,
      data: payload,
      decoder: (data) =>
          ApiResponseEnvelope.decodeData<void>(data, decoder: (_) {}),
    );
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

    return method(
      endpoint,
      data: payload,
      decoder: (data) =>
          ApiResponseEnvelope.decodeData<void>(data, decoder: (_) {}),
    );
  }

  Future<Result<int>> _countResource(
    HmsApiResource resource,
    String tenantId,
    String facilityId,
  ) {
    return _apiClient.get<int>(
      ApiEndpoints.collection(
        resource,
        queryParameters: <String, String>{
          'tenant_id': tenantId,
          'facility_id': facilityId,
          'limit': '1',
        },
      ),
      decoder: (data) {
        if (data is! JsonMap) {
          throw const FormatException('Expected an API response object.');
        }

        final pagination = data['pagination'];
        if (pagination is JsonMap) {
          final total = pagination['total'];
          if (total is int) {
            return total;
          }
        }

        return ApiResponseEnvelope.decodeData<List<Object?>>(
          data,
          decoder: (payload) => payload is Iterable<Object?>
              ? payload.toList(growable: false)
              : const <Object?>[],
        ).length;
      },
    );
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

  static String? _normalizedOptional(String? value) {
    final String? normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static AppFailure? _firstFailure(Iterable<Result<Object?>> results) {
    for (final result in results) {
      if (result case ResultFailure<Object?>(:final failure)) {
        return failure;
      }
    }

    return null;
  }

  static T _value<T>(Result<Object> result) {
    return (result as ResultSuccess<Object>).value as T;
  }
}
