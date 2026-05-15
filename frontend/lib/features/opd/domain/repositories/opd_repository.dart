import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class OpdRepository {
  Future<Result<AppPage<OpdAppointment>>> listAppointments(
    OpdAppointmentQuery query,
  );

  Future<Result<OpdAppointment>> updateAppointment(
    String appointmentId,
    Map<String, Object?> payload,
  );

  Future<Result<OpdAppointment>> cancelAppointment(
    String appointmentId,
    String? reason,
  );

  Future<Result<AppPage<OpdQueueEntry>>> listVisitQueues(OpdQueueQuery query);

  Future<Result<OpdQueueEntry>> createVisitQueue(Map<String, Object?> payload);

  Future<Result<OpdQueueEntry>> updateVisitQueue(
    String queueId,
    Map<String, Object?> payload,
  );

  Future<Result<OpdQueueEntry>> prioritizeVisitQueue(
    String queueId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deleteVisitQueue(String queueId);

  Future<Result<AppPage<OpdFlowSummary>>> listOpdFlows(OpdFlowQuery query);

  Future<Result<OpdFlowDetail>> getOpdFlow(String flowId);

  Future<Result<OpdFlowDetail>> startOpdFlow(Map<String, Object?> payload);

  Future<Result<OpdFlowDetail>> payConsultation(
    String flowId,
    Map<String, Object?> payload,
  );

  Future<Result<OpdFlowDetail>> recordVitals(
    String flowId,
    Map<String, Object?> payload,
  );

  Future<Result<OpdFlowDetail>> assignDoctor(
    String flowId,
    Map<String, Object?> payload,
  );

  Future<Result<OpdFlowDetail>> doctorReview(
    String flowId,
    Map<String, Object?> payload,
  );

  Future<Result<OpdFlowDetail>> correctStage(
    String flowId,
    Map<String, Object?> payload,
  );

  Future<Result<OpdFlowDetail>> disposition(
    String flowId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> createReferral(Map<String, Object?> payload);

  Future<Result<void>> createFollowUp(Map<String, Object?> payload);

  Future<Result<List<OpdProviderSchedule>>> listProviderSchedules();

  Future<Result<List<OpdAvailabilitySlot>>> listAvailabilitySlots(
    String scheduleId,
  );

  Future<Result<List<OpdDrugOption>>> listAvailableDrugs({String? search});
}
