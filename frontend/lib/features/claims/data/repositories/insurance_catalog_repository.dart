import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/claims/data/dtos/claims_dtos.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
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

  Future<Result<List<Map<String, Object?>>>> listEnrollments({
    String? patientId,
    String? status,
    int limit = 20,
  }) {
    return _apiClient.get<List<Map<String, Object?>>>(
      ApiEndpoints.collection(HmsApiResource.patientInsuranceEnrollments),
      queryParameters: <String, Object?>{
        if (patientId != null && patientId.trim().isNotEmpty)
          'patient_id': patientId.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        'limit': limit,
      },
      decoder: (Object? data) {
        if (data is! Map) {
          return const <Map<String, Object?>>[];
        }
        final Object? rows = data['data'] ?? data['enrollments'];
        if (rows is List) {
          return <Map<String, Object?>>[
            for (final Object? row in rows)
              if (row is Map) Map<String, Object?>.from(row),
          ];
        }
        if (data['data'] is Map) {
          final Object? nested = (data['data'] as Map)['enrollments'];
          if (nested is List) {
            return <Map<String, Object?>>[
              for (final Object? row in nested)
                if (row is Map) Map<String, Object?>.from(row),
            ];
          }
        }
        return const <Map<String, Object?>>[];
      },
    );
  }

  /// Active/primary enrollment → payer context for charge-time resolve.
  Future<ClinicalRequestPayerContext?> resolvePayerContextForPatient(
    String? patientId,
  ) async {
    if (patientId == null || patientId.trim().isEmpty) {
      return null;
    }
    final Result<List<Map<String, Object?>>> result = await listEnrollments(
      patientId: patientId,
      status: 'ACTIVE',
    );
    return result.when(
      success: (List<Map<String, Object?>> rows) {
        if (rows.isEmpty) {
          return null;
        }
        Map<String, Object?> selected = rows.first;
        for (final Map<String, Object?> row in rows) {
          if (row['is_primary'] == true) {
            selected = row;
            break;
          }
        }
        final Map<String, Object?> plan = selected['coverage_plan'] is Map
            ? Map<String, Object?>.from(selected['coverage_plan'] as Map)
            : <String, Object?>{};
        final Map<String, Object?> company = plan['insurance_company'] is Map
            ? Map<String, Object?>.from(plan['insurance_company'] as Map)
            : <String, Object?>{};
        final String? schemeId =
            plan['display_id']?.toString() ??
            plan['human_friendly_id']?.toString() ??
            plan['id']?.toString() ??
            selected['coverage_plan_id']?.toString();
        if (schemeId == null || schemeId.isEmpty) {
          return null;
        }
        return ClinicalRequestPayerContext(
          insured: true,
          insuranceCompanyId:
              company['display_id']?.toString() ??
              company['id']?.toString() ??
              plan['insurance_company_id']?.toString(),
          insuranceCompanyName:
              company['name']?.toString() ?? plan['provider_name']?.toString(),
          coveragePlanId: schemeId,
          coveragePlanName: plan['name']?.toString(),
          coveragePercentage: plan['coverage_percentage'] is num
              ? (plan['coverage_percentage'] as num).toInt()
              : int.tryParse('${plan['coverage_percentage'] ?? ''}'),
          copayType: plan['default_copay_type']?.toString(),
          copayValue: plan['default_copay_value'] is num
              ? plan['default_copay_value'] as num
              : num.tryParse('${plan['default_copay_value'] ?? ''}'),
          memberId: selected['member_id']?.toString(),
        );
      },
      failure: (_) => null,
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
