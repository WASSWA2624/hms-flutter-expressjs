import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/opd/data/dtos/opd_dtos.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final opdRepositoryProvider = Provider<OpdRepository>((ref) {
  return OpdRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class OpdRepositoryImpl implements OpdRepository {
  const OpdRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<AppPage<OpdAppointment>>> listAppointments(
    OpdAppointmentQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<OpdAppointment>>(
      ApiEndpoints.collection(HmsApiResource.appointments),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'status': query.status,
        'sort_by': 'scheduled_start',
        'order': 'asc',
      }),
      decoder: (Object? data) =>
          OpdAppointmentPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<OpdAppointment>> updateAppointment(
    String appointmentId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<OpdAppointment>(
      ApiEndpoints.byId(HmsApiResource.appointments, appointmentId),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          OpdAppointmentDto(decodeDataMap(data)).toEntity(),
    );
  }

  @override
  Future<Result<OpdAppointment>> cancelAppointment(
    String appointmentId,
    String? reason,
  ) {
    return _apiClient.post<OpdAppointment>(
      ApiEndpoints.nested(HmsApiResource.appointments, appointmentId, <String>[
        'cancel',
      ]),
      data: _withoutEmpty(<String, Object?>{'reason': reason}),
      decoder: (Object? data) =>
          OpdAppointmentDto(decodeDataMap(data)).toEntity(),
    );
  }

  @override
  Future<Result<AppPage<OpdQueueEntry>>> listVisitQueues(OpdQueueQuery query) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<OpdQueueEntry>>(
      ApiEndpoints.collection(HmsApiResource.visitQueues),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'status': query.status,
        'sort_by': 'queued_at',
        'order': 'asc',
      }),
      decoder: (Object? data) =>
          OpdQueuePageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<OpdQueueEntry>> createVisitQueue(Map<String, Object?> payload) {
    return _apiClient.post<OpdQueueEntry>(
      ApiEndpoints.collection(HmsApiResource.visitQueues),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          OpdQueueEntryDto(decodeDataMap(data)).toEntity(),
    );
  }

  @override
  Future<Result<OpdQueueEntry>> updateVisitQueue(
    String queueId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<OpdQueueEntry>(
      ApiEndpoints.byId(HmsApiResource.visitQueues, queueId),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          OpdQueueEntryDto(decodeDataMap(data)).toEntity(),
    );
  }

  @override
  Future<Result<OpdQueueEntry>> prioritizeVisitQueue(
    String queueId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<OpdQueueEntry>(
      ApiEndpoints.nested(HmsApiResource.visitQueues, queueId, <String>[
        'prioritize',
      ]),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          OpdQueueEntryDto(decodeDataMap(data)).toEntity(),
    );
  }

  @override
  Future<Result<void>> deleteVisitQueue(String queueId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.visitQueues, queueId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<AppPage<OpdFlowSummary>>> listOpdFlows(OpdFlowQuery query) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<OpdFlowSummary>>(
      ApiEndpoints.collection(HmsApiResource.opdFlows),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'stage': query.stage,
        'queue_scope': query.queueScope,
        'sort_by': 'started_at',
        'order': 'desc',
      }),
      decoder: (Object? data) =>
          OpdFlowPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<OpdFlowDetail>> getOpdFlow(String flowId) {
    return _apiClient.get<OpdFlowDetail>(
      ApiEndpoints.byId(HmsApiResource.opdFlows, flowId),
      decoder: (Object? data) => OpdFlowDetailDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<OpdFlowDetail>> startOpdFlow(Map<String, Object?> payload) {
    return _apiClient.post<OpdFlowDetail>(
      ApiEndpoints.apiV1(<String>[HmsApiResource.opdFlows.path, 'start']),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => OpdFlowDetailDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<OpdFlowDetail>> payConsultation(
    String flowId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<OpdFlowDetail>(
      ApiEndpoints.nested(HmsApiResource.opdFlows, flowId, <String>[
        'pay-consultation',
      ]),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => OpdFlowDetailDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<OpdFlowDetail>> recordVitals(
    String flowId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<OpdFlowDetail>(
      ApiEndpoints.nested(HmsApiResource.opdFlows, flowId, <String>[
        'record-vitals',
      ]),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => OpdFlowDetailDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<OpdFlowDetail>> assignDoctor(
    String flowId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<OpdFlowDetail>(
      ApiEndpoints.nested(HmsApiResource.opdFlows, flowId, <String>[
        'assign-doctor',
      ]),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => OpdFlowDetailDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<OpdFlowDetail>> doctorReview(
    String flowId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<OpdFlowDetail>(
      ApiEndpoints.nested(HmsApiResource.opdFlows, flowId, <String>[
        'doctor-review',
      ]),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => OpdFlowDetailDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<OpdFlowDetail>> correctStage(
    String flowId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<OpdFlowDetail>(
      ApiEndpoints.nested(HmsApiResource.opdFlows, flowId, <String>[
        'correct-stage',
      ]),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => OpdFlowDetailDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<OpdFlowDetail>> disposition(
    String flowId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<OpdFlowDetail>(
      ApiEndpoints.nested(HmsApiResource.opdFlows, flowId, <String>[
        'disposition',
      ]),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => OpdFlowDetailDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<void>> createReferral(Map<String, Object?> payload) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.referrals),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> createFollowUp(Map<String, Object?> payload) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.followUps),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<List<OpdProviderSchedule>>> listProviderSchedules() {
    final int dayOfWeek = DateTime.now().weekday % 7;
    return _apiClient.get<List<OpdProviderSchedule>>(
      ApiEndpoints.collection(HmsApiResource.providerSchedules),
      queryParameters: <String, Object?>{
        'page': 1,
        'limit': 12,
        'day_of_week': dayOfWeek,
        'sort_by': 'start_time',
        'order': 'asc',
      },
      decoder: decodeProviderSchedules,
    );
  }

  @override
  Future<Result<List<OpdAvailabilitySlot>>> listAvailabilitySlots(
    String scheduleId,
  ) {
    return _apiClient.get<List<OpdAvailabilitySlot>>(
      ApiEndpoints.collection(HmsApiResource.availabilitySlots),
      queryParameters: <String, Object?>{
        'page': 1,
        'limit': 12,
        'schedule_id': scheduleId,
        'is_available': 'true',
        'sort_by': 'start_time',
        'order': 'asc',
      },
      decoder: decodeAvailabilitySlots,
    );
  }

  @override
  Future<Result<List<OpdDrugOption>>> listAvailableDrugs({String? search}) {
    return _apiClient.get<List<OpdDrugOption>>(
      ApiEndpoints.collection(HmsApiResource.drugs),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': 20,
        'search': search,
        'sort_by': 'name',
        'order': 'asc',
      }),
      decoder: decodeOpdDrugOptions,
    );
  }

  Map<String, Object?> _withoutEmpty(Map<String, Object?> payload) {
    return <String, Object?>{
      for (final MapEntry<String, Object?> entry in payload.entries)
        if (!_isEmpty(entry.value)) entry.key: entry.value,
    };
  }

  bool _isEmpty(Object? value) {
    if (value == null) {
      return true;
    }
    if (value is String) {
      return value.trim().isEmpty;
    }
    if (value is Iterable<Object?>) {
      return value.isEmpty;
    }
    return false;
  }
}
