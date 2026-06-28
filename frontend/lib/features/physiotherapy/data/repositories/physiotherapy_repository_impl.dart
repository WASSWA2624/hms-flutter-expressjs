import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/physiotherapy/data/dtos/physiotherapy_dtos.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/entities/physiotherapy_entities.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/repositories/physiotherapy_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final physiotherapyRepositoryProvider = Provider<PhysiotherapyRepository>((
  ref,
) {
  return PhysiotherapyRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class PhysiotherapyRepositoryImpl implements PhysiotherapyRepository {
  const PhysiotherapyRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<AppPage<TherapyWorkItem>>> listWorkItems(
    PhysiotherapyWorklistQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<TherapyWorkItem>>(
      ApiEndpoints.collection(HmsApiResource.therapyFlows),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.databaseSearch,
        'queue_scope': serverQueueScopeForPhysiotherapy(query.scope),
        'source_kind': query.filters.source,
        'therapy_status': query.filters.status,
        'therapist_id': query.filters.therapist,
        if (query.filters.dateFrom != null)
          'scheduled_from': query.filters.dateFrom!.toUtc().toIso8601String(),
        if (query.filters.dateTo != null)
          'scheduled_to': query.filters.dateTo!.toUtc().toIso8601String(),
        'sort_by': 'updated_at',
        'order': 'desc',
      }),
      decoder: (Object? data) =>
          TherapyFlowPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<PhysiotherapyDetail>> loadDetail(TherapyWorkItem item) {
    return _loadDetailById(item.id);
  }

  @override
  Future<Result<PhysiotherapyDetail>> acceptReferral({
    required TherapyWorkItem item,
    required String note,
  }) {
    return _postAction(
      item.id,
      <String>['accept-referral'],
      <String, Object?>{'note': note},
    );
  }

  @override
  Future<Result<PhysiotherapyDetail>> scheduleSession({
    required TherapyWorkItem item,
    required DateTime startAt,
    required DateTime endAt,
    String? providerUserId,
    String? reason,
  }) {
    return _postAction(
      item.id,
      <String>['schedule-session'],
      <String, Object?>{
        'therapist_user_id': providerUserId,
        'scheduled_start_at': startAt.toUtc().toIso8601String(),
        'scheduled_end_at': endAt.toUtc().toIso8601String(),
        'reason': reason,
      },
    );
  }

  @override
  Future<Result<PhysiotherapyDetail>> recordAssessment({
    required TherapyWorkItem item,
    required String assessment,
    required String goals,
    required String plan,
    String? instructions,
  }) {
    return _postAction(
      item.id,
      <String>['record-assessment'],
      <String, Object?>{
        'assessment': assessment,
        'goals': goals,
        'plan': plan,
        'instructions': instructions,
      },
    );
  }

  @override
  Future<Result<PhysiotherapyDetail>> recordSession({
    required TherapyWorkItem item,
    required String note,
    String? attendanceStatus,
  }) {
    return _postAction(
      item.id,
      <String>['record-session'],
      <String, Object?>{
        'note': note,
        'attendance_status': attendanceStatus,
        'session_id': item.appointmentApiId,
      },
    );
  }

  @override
  Future<Result<PhysiotherapyDetail>> markAttendance({
    required TherapyWorkItem item,
    required String status,
    String? note,
  }) {
    final String? sessionId = item.appointmentApiId;
    if (sessionId == null || sessionId.isEmpty) {
      return Future<Result<PhysiotherapyDetail>>.value(
        Result<PhysiotherapyDetail>.failure(AppFailure.validation()),
      );
    }
    return _postAction(
      item.id,
      <String>['mark-attendance'],
      <String, Object?>{
        'session_id': sessionId,
        'attendance_status': status,
        'note': note,
      },
    );
  }

  @override
  Future<Result<PhysiotherapyDetail>> updatePlan({
    required TherapyWorkItem item,
    required String plan,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _postAction(
      item.id,
      <String>['update-plan'],
      <String, Object?>{
        'plan': plan,
        if (startDate != null)
          'plan_started_at': startDate.toUtc().toIso8601String(),
        if (endDate != null) 'plan_ends_at': endDate.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<Result<PhysiotherapyDetail>> addProgressNote({
    required TherapyWorkItem item,
    required String authorUserId,
    required String note,
  }) {
    return _postAction(
      item.id,
      <String>['add-progress-note'],
      <String, Object?>{'note': note},
    );
  }

  @override
  Future<Result<PhysiotherapyDetail>> scheduleFollowUp({
    required TherapyWorkItem item,
    required DateTime scheduledAt,
    String? notes,
  }) {
    return _postAction(
      item.id,
      <String>['schedule-follow-up'],
      <String, Object?>{
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'notes': notes,
      },
    );
  }

  @override
  Future<Result<PhysiotherapyDetail>> closeEpisode({
    required TherapyWorkItem item,
    required String summary,
  }) {
    return _postAction(
      item.id,
      <String>['close-episode'],
      <String, Object?>{'outcome_summary': summary},
    );
  }

  Future<Result<PhysiotherapyDetail>> _loadDetailById(String episodeId) {
    return _apiClient.get<PhysiotherapyDetail>(
      ApiEndpoints.nested(
        HmsApiResource.therapyFlows,
        episodeId,
        const <String>[],
        queryParameters: const <String, String>{'include_timeline': 'true'},
      ),
      decoder: (Object? data) => TherapyFlowDetailDto(data).toEntity(),
    );
  }

  Future<Result<PhysiotherapyDetail>> _postAction(
    String episodeId,
    List<String> segments,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<PhysiotherapyDetail>(
      ApiEndpoints.nested(HmsApiResource.therapyFlows, episodeId, segments),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => TherapyFlowDetailDto(data).toEntity(),
    );
  }

  Map<String, Object?> _withoutEmpty(Map<String, Object?> values) {
    return Map<String, Object?>.fromEntries(
      values.entries.where(
        (MapEntry<String, Object?> entry) =>
            entry.value != null && entry.value.toString().trim().isNotEmpty,
      ),
    );
  }
}
