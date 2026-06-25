import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/clinical/data/dtos/clinical_dtos.dart';
import 'package:hosspi_hms/features/emergency/data/dtos/emergency_dtos.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/lab/data/dtos/lab_dtos.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/theater/data/dtos/theater_dtos.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/features/theater/domain/repositories/theater_repository.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final theaterRepositoryProvider = Provider<TheaterRepository>((ref) {
  return TheaterRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class TheaterRepositoryImpl implements TheaterRepository {
  const TheaterRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<AppPage<TheaterCase>>> listCases(TheaterCaseQuery query) {
    final AppPageRequest request = query.pageRequest;
    final _DateRange? range = _dateRange(query.scheduledDate);
    return _apiClient.get<AppPage<TheaterCase>>(
      ApiEndpoints.collection(HmsApiResource.theatreFlows),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'queue_scope': query.queueScope,
        'search': query.search,
        'status': query.status,
        'stage': query.stage,
        'room_id': query.roomId,
        'surgeon_user_id': query.surgeonUserId,
        'anesthetist_user_id': query.anesthetistUserId,
        'scheduled_from': range?.from.toUtc().toIso8601String(),
        'scheduled_to': range?.to.toUtc().toIso8601String(),
        'sort_by': 'scheduled_at',
        'order': 'asc',
      }),
      decoder: (Object? data) =>
          TheaterCasePageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<TheaterCase>> getCase(String caseId) {
    return _apiClient.get<TheaterCase>(
      ApiEndpoints.byId(
        HmsApiResource.theatreFlows,
        caseId,
        queryParameters: <String, String>{'include_timeline': 'true'},
      ),
      decoder: (Object? data) => TheaterCaseDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<TheaterCase>> scheduleCase(Map<String, Object?> payload) {
    return _apiClient.post<TheaterCase>(
      ApiEndpoints.apiV1(<String>[HmsApiResource.theatreFlows.path, 'start']),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => TheaterCaseDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<TheaterCase>> updateCaseSchedule(
    String caseId,
    Map<String, Object?> payload,
  ) async {
    final Result<TheaterCase> updateResult = await _apiClient.put<TheaterCase>(
      ApiEndpoints.byId(HmsApiResource.theatreCases, caseId),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => TheaterCaseDto.fromResponse(data).toEntity(),
    );

    return updateResult.when(
      success: (_) => getCase(caseId),
      failure: (failure) => Result<TheaterCase>.failure(failure),
    );
  }

  @override
  Future<Result<TheaterCase>> updateStage(
    String caseId,
    Map<String, Object?> payload,
  ) {
    return _postCaseAction(caseId, 'update-stage', payload);
  }

  @override
  Future<Result<TheaterCase>> upsertAnesthesiaRecord(
    String caseId,
    Map<String, Object?> payload,
  ) {
    return _postCaseAction(caseId, 'upsert-anesthesia-record', payload);
  }

  @override
  Future<Result<TheaterCase>> addAnesthesiaObservation(
    String caseId,
    Map<String, Object?> payload,
  ) {
    return _postCaseAction(caseId, 'add-anesthesia-observation', payload);
  }

  @override
  Future<Result<TheaterCase>> upsertPostOpNote(
    String caseId,
    Map<String, Object?> payload,
  ) {
    return _postCaseAction(caseId, 'upsert-post-op-note', payload);
  }

  @override
  Future<Result<TheaterCase>> toggleChecklistItem(
    String caseId,
    Map<String, Object?> payload,
  ) {
    return _postCaseAction(caseId, 'toggle-checklist-item', payload);
  }

  @override
  Future<Result<TheaterCase>> assignResource(
    String caseId,
    Map<String, Object?> payload,
  ) {
    return _postCaseAction(caseId, 'assign-resource', payload);
  }

  @override
  Future<Result<TheaterCase>> releaseResource(
    String caseId,
    Map<String, Object?> payload,
  ) {
    return _postCaseAction(caseId, 'release-resource', payload);
  }

  @override
  Future<Result<TheaterCase>> finalizeRecord(
    String caseId,
    Map<String, Object?> payload,
  ) {
    return _postCaseAction(caseId, 'finalize-record', payload);
  }

  @override
  Future<Result<TheaterCase>> reopenRecord(
    String caseId,
    Map<String, Object?> payload,
  ) {
    return _postCaseAction(caseId, 'reopen-record', payload);
  }

  @override
  Future<Result<List<TheaterSchedulePatient>>> searchSchedulePatients(
    String query,
  ) {
    return _apiClient.get<List<TheaterSchedulePatient>>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.lab.path,
        'order-context',
        'patients',
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': 8,
        'search': query.trim(),
      }),
      decoder: (Object? data) => decodeLabOrderContextPatients(
        data,
      ).map(_mapSchedulePatient).toList(growable: false),
    );
  }

  @override
  Future<Result<TheaterSchedulePatientDetail>> loadSchedulePatientEncounters(
    String patientId,
  ) {
    return _apiClient.get<TheaterSchedulePatientDetail>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.lab.path,
        'order-context',
        'patients',
        patientId,
      ]),
      decoder: (Object? data) {
        final LabOrderPatientContextDetail detail =
            LabOrderPatientContextDetailDto.fromResponse(data).detail;
        return TheaterSchedulePatientDetail(
          patient: _mapSchedulePatient(detail.patient),
          encounters: detail.encounters
              .map(_mapScheduleEncounter)
              .toList(growable: false),
        );
      },
    );
  }

  @override
  Future<Result<List<TheaterScheduleEmergencyCase>>>
  searchScheduleEmergencyCases(String patientId) {
    return _apiClient.get<List<TheaterScheduleEmergencyCase>>(
      ApiEndpoints.collection(HmsApiResource.emergencyCases),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': 12,
        'patient_id': patientId.trim(),
        'sort_by': 'created_at',
        'order': 'desc',
      }),
      decoder: (Object? data) {
        final List<EmergencyCaseSummary> items =
            EmergencyCasePageDto.fromResponse(
              data,
              const AppPageRequest(),
            ).page.items;
        return items
            .where((EmergencyCaseSummary item) => item.isOpen)
            .map(_mapScheduleEmergencyCase)
            .toList(growable: false);
      },
    );
  }

  @override
  Future<Result<List<TheaterRoomOption>>> searchTheatreRooms(String query) {
    return _apiClient.get<List<TheaterRoomOption>>(
      ApiEndpoints.collection(HmsApiResource.rooms),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': 40,
        'search': query.trim(),
        'sort_by': 'name',
        'order': 'asc',
      }),
      decoder: (Object? data) {
        final List<TheaterRoomOption> rooms = decodeCatalogOptions(
          data,
        ).map(_mapRoomOption).toList(growable: false);
        rooms.sort((TheaterRoomOption left, TheaterRoomOption right) {
          final int leftScore = left.isLikelyTheatreRoom ? 0 : 1;
          final int rightScore = right.isLikelyTheatreRoom ? 0 : 1;
          if (leftScore != rightScore) {
            return leftScore.compareTo(rightScore);
          }
          return left.name.toLowerCase().compareTo(right.name.toLowerCase());
        });
        return rooms;
      },
    );
  }

  @override
  Future<Result<List<TheaterStaffOption>>> searchTheatreStaff(
    String query, {
    String? role,
  }) {
    return _apiClient.get<List<TheaterStaffOption>>(
      ApiEndpoints.collection(HmsApiResource.users),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': 20,
        'search': query.trim(),
        'status': 'ACTIVE',
        'sort_by': 'created_at',
        'order': 'asc',
      }),
      decoder: (Object? data) => _decodeStaffOptions(data, role: role),
    );
  }

  Future<Result<TheaterCase>> _postCaseAction(
    String caseId,
    String action,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<TheaterCase>(
      ApiEndpoints.nested(HmsApiResource.theatreFlows, caseId, <String>[
        action,
      ]),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => TheaterCaseDto.fromResponse(data).toEntity(),
    );
  }
}

final class _DateRange {
  const _DateRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;
}

_DateRange? _dateRange(DateTime? date) {
  if (date == null) {
    return null;
  }

  final DateTime from = DateTime(date.year, date.month, date.day);
  final DateTime to = from.add(const Duration(days: 1));
  return _DateRange(from: from, to: to);
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

TheaterSchedulePatient _mapSchedulePatient(LabOrderPatientContext patient) {
  return TheaterSchedulePatient(
    id: patient.id,
    displayId: patient.displayId,
    displayName: patient.displayName,
    identifier: patient.identifier,
    primaryPhone: patient.primaryPhone,
  );
}

TheaterScheduleEncounter _mapScheduleEncounter(
  LabOrderEncounterContext encounter,
) {
  return TheaterScheduleEncounter(
    id: encounter.id,
    displayId: encounter.displayId,
    title: encounter.title,
    status: encounter.status,
    type: encounter.type,
    startedAt: encounter.startedAt,
    endedAt: encounter.endedAt,
  );
}

TheaterScheduleEmergencyCase _mapScheduleEmergencyCase(
  EmergencyCaseSummary summary,
) {
  return TheaterScheduleEmergencyCase(
    id: summary.id,
    displayId: summary.displayId,
    severity: summary.severity,
    status: summary.status,
    createdAt: summary.createdAt,
  );
}

TheaterRoomOption _mapRoomOption(ClinicalActionCatalogOption option) {
  final Object? ward = option.metadata['ward_name'] ?? option.metadata['ward'];
  final Object? floor = option.metadata['floor'];
  return TheaterRoomOption(
    id: option.apiId,
    name: option.displayTitle,
    wardName: ward?.toString(),
    floor: floor?.toString(),
  );
}

List<TheaterStaffOption> _decodeStaffOptions(Object? data, {String? role}) {
  final List<TheaterStaffOption> users = <TheaterStaffOption>[];
  final Object? payload = data is Map<String, Object?> ? data['data'] : data;
  final Iterable<Object?> items = payload is List<Object?>
      ? payload
      : payload is Map<String, Object?> && payload['items'] is List<Object?>
      ? payload['items'] as List<Object?>
      : const <Object?>[];

  for (final Object? item in items) {
    if (item is! Map) {
      continue;
    }
    final Map<String, Object?> map = Map<String, Object?>.from(item);
    final Object? profileRaw =
        map['profile'] ?? map['user_profile'] ?? map['userProfile'];
    final Map<String, Object?> profile = profileRaw is Map
        ? Map<String, Object?>.from(profileRaw)
        : const <String, Object?>{};
    final String? id = _firstNonEmpty(<Object?>[
      map['id'],
      map['user_id'],
      map['userId'],
      profile['user_id'],
      profile['id'],
    ])?.toString();
    if (id == null || id.trim().isEmpty) {
      continue;
    }
    final String displayLabel =
        _firstNonEmpty(<Object?>[
          map['display_name'],
          map['displayName'],
          profile['display_name'],
          profile['displayName'],
          _joinNonEmpty(<Object?>[
            profile['first_name'],
            profile['middle_name'],
            profile['last_name'],
          ]),
          _joinNonEmpty(<Object?>[
            map['first_name'],
            map['middle_name'],
            map['last_name'],
          ]),
          map['name'],
          map['username'],
          map['email'],
          id,
        ])?.toString() ??
        id;
    final TheaterStaffOption option = TheaterStaffOption(
      id: id,
      displayLabel: displayLabel,
      email: _firstNonEmpty(<Object?>[
        map['email'],
        profile['email'],
        map['email_address'],
      ])?.toString(),
      phone: _firstNonEmpty(<Object?>[
        map['phone'],
        map['phone_number'],
        profile['phone'],
        profile['phone_number'],
      ])?.toString(),
      positionTitle: _firstNonEmpty(<Object?>[
        map['position_title'],
        map['positionTitle'],
        profile['position_title'],
        profile['positionTitle'],
      ])?.toString(),
    );
    if (option.matchesRole(role)) {
      users.add(option);
    }
  }
  return users;
}

Object? _firstNonEmpty(Iterable<Object?> values) {
  for (final Object? value in values) {
    final String trimmed = value?.toString().trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

String? _joinNonEmpty(Iterable<Object?> values) {
  final List<String> parts = <String>[];
  for (final Object? value in values) {
    final String trimmed = value?.toString().trim() ?? '';
    if (trimmed.isNotEmpty) {
      parts.add(trimmed);
    }
  }
  if (parts.isEmpty) {
    return null;
  }
  return parts.join(' ');
}
