import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';

final ipdRepositoryProvider = Provider<IpdRepository>((ref) {
  return IpdRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class IpdRepositoryImpl implements IpdRepository {
  const IpdRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<void>> assignBed(
    String admissionId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<void>(
      ApiEndpoints.nested(HmsApiResource.ipdFlows, admissionId, <String>[
        'assign-bed',
      ]),
      data: _withoutEmpty(payload),
      decoder: (_) {},
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
