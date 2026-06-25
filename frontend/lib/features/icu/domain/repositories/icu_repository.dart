import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class IcuRepository {
  Future<Result<AppPage<IcuPatientSummary>>> listIcuBoard(IcuBoardQuery query);

  Future<Result<IcuPatientDetail>> loadIcuDetail(IcuPatientSummary summary);

  Future<Result<IcuReferenceData>> loadReferenceData();

  Future<Result<IcuBedBoard>> loadBedBoard();

  Future<Result<IcuPatientDetail>> startIcuStay({
    required IcuPatientDetail detail,
    DateTime? startedAt,
  });

  Future<Result<IcuPatientDetail>> assignBed({
    required IcuPatientDetail detail,
    required String bedId,
  });

  Future<Result<IcuPatientDetail>> updateTransfer({
    required IcuPatientDetail detail,
    required String transferRequestId,
    required IcuTransferAction action,
    String? toBedId,
  });

  Future<Result<IcuPatientDetail>> recordObservation({
    required IcuPatientDetail detail,
    required String observation,
    DateTime? observedAt,
  });

  Future<Result<IcuPatientDetail>> recordVitals({
    required IcuPatientDetail detail,
    required IcuVitalsInput input,
  });

  Future<Result<IcuPatientDetail>> addCriticalAlert({
    required IcuPatientDetail detail,
    required String severity,
    required String message,
  });

  Future<Result<IcuPatientDetail>> acknowledgeAlert({
    required IcuPatientDetail detail,
    required String alertId,
  });

  Future<Result<IcuPatientDetail>> addRoundNote({
    required IcuPatientDetail detail,
    required String notes,
    DateTime? roundAt,
  });

  Future<Result<IcuPatientDetail>> requestTransfer({
    required IcuPatientDetail detail,
    required String toWardId,
    String? fromWardId,
  });

  Future<Result<IcuPatientDetail>> markDischargeReady({
    required IcuPatientDetail detail,
    required String summary,
    DateTime? dischargedAt,
  });

  Future<Result<IcuPatientDetail>> transferOut({
    required IcuPatientDetail detail,
    DateTime? endedAt,
  });
}
