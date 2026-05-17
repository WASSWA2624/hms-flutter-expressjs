import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class EmergencyRepository {
  Future<Result<AppPage<EmergencyCaseSummary>>> listEmergencyBoard(
    EmergencyBoardQuery query,
  );

  Future<Result<EmergencyReferenceData>> loadReferenceData();

  Future<Result<EmergencyCaseDetail>> loadEmergencyDetail(
    EmergencyCaseSummary summary,
  );

  Future<Result<EmergencyCaseDetail>> createQuickArrival(
    EmergencyQuickArrivalInput input,
  );

  Future<Result<EmergencyCaseDetail>> updateCasePriority({
    required EmergencyCaseDetail detail,
    required String severity,
  });

  Future<Result<EmergencyCaseDetail>> recordTriage({
    required EmergencyCaseDetail detail,
    required String triageLevel,
    String? notes,
  });

  Future<Result<EmergencyCaseDetail>> markResponse({
    required EmergencyCaseDetail detail,
    required String notes,
    DateTime? responseAt,
  });

  Future<Result<EmergencyCaseDetail>> dispatchAmbulance({
    required EmergencyCaseDetail detail,
    required String ambulanceId,
    String status,
    DateTime? dispatchedAt,
  });

  Future<Result<EmergencyCaseDetail>> updateDispatchStatus({
    required EmergencyCaseDetail detail,
    required String dispatchId,
    required String status,
  });

  Future<Result<EmergencyCaseDetail>> startAmbulanceTrip({
    required EmergencyCaseDetail detail,
    required String ambulanceId,
    DateTime? startedAt,
  });

  Future<Result<EmergencyCaseDetail>> completeAmbulanceTrip({
    required EmergencyCaseDetail detail,
    required String tripId,
    DateTime? endedAt,
  });

  Future<Result<EmergencyCaseDetail>> recordHandoff({
    required EmergencyCaseDetail detail,
    required String destination,
    String? notes,
    bool closeCase,
  });
}
