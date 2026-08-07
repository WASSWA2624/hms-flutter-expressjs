import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final receptionFollowUpRepositoryProvider = Provider<ReceptionFollowUpRepository>(
  (Ref ref) {
    return ReceptionFollowUpRepository(apiClient: ref.watch(apiClientProvider));
  },
);

/// Lists and completes encounter follow-ups for Reception call worklists.
class ReceptionFollowUpRepository {
  const ReceptionFollowUpRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<Result<List<ReceptionFollowUpEntry>>> listScheduledFollowUps({
    String? encounterType,
  }) {
    return _apiClient.get<List<ReceptionFollowUpEntry>>(
      ApiEndpoints.collection(HmsApiResource.followUps),
      queryParameters: <String, Object?>{
        'status': 'SCHEDULED',
        'page': 1,
        'limit': AppPageRequest.maxPageSize,
        'sort_by': 'scheduled_at',
        'order': 'asc',
        if (encounterType != null && encounterType.trim().isNotEmpty)
          'encounter_type': encounterType.trim().toUpperCase(),
      },
      decoder: _decodeFollowUpList,
    );
  }

  /// Lists scheduled follow-ups and returns the authoritative pagination total.
  Future<Result<({List<ReceptionFollowUpEntry> entries, int total})>>
  listScheduledFollowUpsPage({String? encounterType}) {
    return _apiClient.get<({List<ReceptionFollowUpEntry> entries, int total})>(
      ApiEndpoints.collection(HmsApiResource.followUps),
      queryParameters: <String, Object?>{
        'status': 'SCHEDULED',
        'page': 1,
        'limit': AppPageRequest.maxPageSize,
        'sort_by': 'scheduled_at',
        'order': 'asc',
        if (encounterType != null && encounterType.trim().isNotEmpty)
          'encounter_type': encounterType.trim().toUpperCase(),
      },
      decoder: _decodeFollowUpPage,
    );
  }

  Future<Result<void>> completeFollowUp(
    String followUpId, {
    String? notes,
  }) {
    return _apiClient.post<void>(
      ApiEndpoints.nested(
        HmsApiResource.followUps,
        followUpId,
        const <String>['complete'],
      ),
      data: <String, Object?>{
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
      decoder: (_) {},
    );
  }

  Future<Result<void>> createFollowUp(Map<String, Object?> payload) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.followUps),
      data: <String, Object?>{
        for (final MapEntry<String, Object?> entry in payload.entries)
          if (entry.value != null &&
              !(entry.value is String && (entry.value as String).trim().isEmpty))
            entry.key: entry.value,
      },
      decoder: (_) {},
    );
  }

  Future<Result<void>> updateFollowUp(
    String followUpId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.followUps, followUpId),
      data: <String, Object?>{
        for (final MapEntry<String, Object?> entry in payload.entries)
          if (entry.value != null &&
              !(entry.value is String && (entry.value as String).trim().isEmpty))
            entry.key: entry.value,
      },
      decoder: (_) {},
    );
  }
}

List<ReceptionFollowUpEntry> _decodeFollowUpList(Object? responseData) {
  return _decodeFollowUpPage(responseData).entries;
}

({List<ReceptionFollowUpEntry> entries, int total}) _decodeFollowUpPage(
  Object? responseData,
) {
  final Map<String, Object?> response = _expectMap(responseData);
  final List<ReceptionFollowUpEntry> entries = _list(response['data'])
      .map(ReceptionFollowUpEntry.fromJson)
      .where((ReceptionFollowUpEntry item) => item.id.isNotEmpty)
      .toList(growable: false);
  final Map<String, Object?> pagination = _expectMap(response['pagination']);
  final int? reportedTotal = int.tryParse('${pagination['total'] ?? ''}');
  return (
    entries: entries,
    total: reportedTotal ?? entries.length,
  );
}

Map<String, Object?> _expectMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (Object? key, Object? entry) =>
          MapEntry<String, Object?>(key.toString(), entry),
    );
  }
  return const <String, Object?>{};
}

List<Map<String, Object?>> _list(Object? value) {
  if (value is! List<Object?>) {
    return const <Map<String, Object?>>[];
  }
  return <Map<String, Object?>>[
    for (final Object? item in value)
      if (item is Map<String, Object?>)
        item
      else if (item is Map)
        item.map(
          (Object? key, Object? entry) =>
              MapEntry<String, Object?>(key.toString(), entry),
        ),
  ];
}
