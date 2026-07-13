import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/claims/data/dtos/claims_dtos.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final insuranceCatalogRepositoryProvider =
    Provider<InsuranceCatalogRepository>((Ref ref) {
      return InsuranceCatalogRepository(
        apiClient: ref.watch(apiClientProvider),
      );
    });

/// CRUD client for insurance companies, schemes, offers, and enrollments.
final class InsuranceCatalogRepository {
  const InsuranceCatalogRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<Result<InsuranceCompanyOption>> createCompany(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<InsuranceCompanyOption>(
      ApiEndpoints.collection(HmsApiResource.insuranceCompanies),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          InsuranceCompanyDto(_mapData(data)).toEntity(),
    );
  }

  Future<Result<CoveragePlanOption>> createScheme(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<CoveragePlanOption>(
      ApiEndpoints.collection(HmsApiResource.coveragePlans),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => CoveragePlanDto(_mapData(data)).toEntity(),
    );
  }

  Future<Result<Map<String, Object?>>> createSchemeOffer(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<Map<String, Object?>>(
      ApiEndpoints.collection(HmsApiResource.schemeOffers),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => _mapData(data),
    );
  }

  Future<Result<Map<String, Object?>>> createEnrollment(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<Map<String, Object?>>(
      ApiEndpoints.collection(HmsApiResource.patientInsuranceEnrollments),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => _mapData(data),
    );
  }

  Future<Result<Map<String, Object?>>> verifyEnrollment(
    String enrollmentId, {
    bool manual = true,
    bool eligible = true,
    String? notes,
  }) {
    return _apiClient.post<Map<String, Object?>>(
      ApiEndpoints.nested(
        HmsApiResource.patientInsuranceEnrollments,
        enrollmentId,
        <String>['verify'],
      ),
      data: _withoutEmpty(<String, Object?>{
        'manual': manual,
        'eligible': eligible,
        'notes': notes,
      }),
      decoder: (Object? data) => _mapData(data),
    );
  }
}

Map<String, Object?> _mapData(Object? responseData) {
  if (responseData is! Map) {
    return <String, Object?>{};
  }
  final Map<String, Object?> response = Map<String, Object?>.from(responseData);
  final Object? data = response['data'];
  if (data is Map) {
    return Map<String, Object?>.from(data);
  }
  return response;
}

Map<String, Object?> _withoutEmpty(Map<String, Object?> payload) {
  return <String, Object?>{
    for (final MapEntry<String, Object?> entry in payload.entries)
      if (entry.value != null &&
          (!(entry.value is String) ||
              (entry.value as String).trim().isNotEmpty))
        entry.key: entry.value is String
            ? (entry.value as String).trim()
            : entry.value,
  };
}
