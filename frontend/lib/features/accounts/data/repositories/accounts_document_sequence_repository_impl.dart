import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/accounts/data/dtos/accounts_document_sequence_dtos.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_document_sequence.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_document_sequence_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Canonical section slug shared by the route, the tab, and the API.
const String accountsDocumentNumberingSectionSlug = 'document-numbering';

final accountsDocumentSequenceRepositoryProvider =
    Provider<AccountsDocumentSequenceRepository>((Ref ref) {
      return AccountsDocumentSequenceRepositoryImpl(
        apiClient: ref.watch(apiClientProvider),
      );
    });

final class AccountsDocumentSequenceRepositoryImpl
    implements AccountsDocumentSequenceRepository {
  const AccountsDocumentSequenceRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  static Uri _collection() => ApiEndpoints.apiV1(<String>[
    HmsApiResource.accounts.path,
    accountsDocumentNumberingSectionSlug,
  ]);

  static Uri _byReference(String humanFriendlyId, [String? action]) {
    return ApiEndpoints.apiV1(<String>[
      HmsApiResource.accounts.path,
      accountsDocumentNumberingSectionSlug,
      humanFriendlyId,
      ?action,
    ]);
  }

  @override
  Future<Result<AppPage<AccountsDocumentSequence>>> listDocumentSequences(
    AccountsDocumentSequenceQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<AccountsDocumentSequence>>(
      _collection(),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search.trim(),
        'status': query.statuses
            .map((AccountsDocumentSequenceStatus status) => status.wireValue)
            .join(','),
        'document_type': query.documentTypes
            .map((AccountsDocumentType type) => type.wireValue)
            .join(','),
        'reset_frequency': query.resetFrequencies
            .map(
              (AccountsDocumentSequenceResetFrequency frequency) =>
                  frequency.wireValue,
            )
            .join(','),
        'gap_policy': query.gapPolicies
            .map(
              (AccountsDocumentSequenceGapPolicy policy) => policy.wireValue,
            )
            .join(','),
        'module': query.module.trim(),
        'sequence_code': query.sequenceCode.trim(),
        'prefix': query.prefix.trim(),
        'facility_id': query.facilityId.trim(),
        'from': query.from?.toUtc().toIso8601String(),
        'to': query.to?.toUtc().toIso8601String(),
        'sort_by': query.sortBy,
        'order': query.ascending ? 'asc' : 'desc',
      }),
      decoder: (Object? data) =>
          AccountsDocumentSequencePageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<AccountsDocumentSequence>> getDocumentSequence(
    String humanFriendlyId,
  ) {
    return _apiClient.get<AccountsDocumentSequence>(
      _byReference(humanFriendlyId),
      decoder: _decodeOne,
    );
  }

  @override
  Future<Result<AccountsDocumentSequence>> createDocumentSequence(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<AccountsDocumentSequence>(
      _collection(),
      data: _withoutEmpty(payload),
      decoder: _decodeOne,
    );
  }

  @override
  Future<Result<AccountsDocumentSequence>> updateDocumentSequence(
    String humanFriendlyId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<AccountsDocumentSequence>(
      _byReference(humanFriendlyId),
      data: _withoutEmpty(payload),
      decoder: _decodeOne,
    );
  }

  @override
  Future<Result<AccountsDocumentSequence>> applyAction(
    String humanFriendlyId,
    AccountsDocumentSequenceAction action, {
    String? reason,
    int? version,
  }) {
    return _apiClient.post<AccountsDocumentSequence>(
      _byReference(humanFriendlyId, action.wireValue),
      data: _withoutEmpty(<String, Object?>{
        'reason': reason,
        'version': version,
      }),
      decoder: _decodeOne,
    );
  }

  static AccountsDocumentSequence _decodeOne(Object? data) {
    final AccountsDocumentSequence? entity =
        AccountsDocumentSequenceDto.fromResponse(data).toEntity();
    if (entity == null) {
      throw const FormatException(
        'Document numbering sequence response is incomplete.',
      );
    }
    return entity;
  }

  Map<String, Object?> _withoutEmpty(Map<String, Object?> source) {
    return <String, Object?>{
      for (final MapEntry<String, Object?> entry in source.entries)
        if (entry.value != null &&
            !(entry.value is String && (entry.value! as String).trim().isEmpty))
          entry.key: entry.value,
    };
  }
}
