import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class TheaterRepository {
  Future<Result<AppPage<TheaterCase>>> listCases(TheaterCaseQuery query);

  Future<Result<TheaterCase>> getCase(String caseId);

  Future<Result<TheaterCase>> scheduleCase(Map<String, Object?> payload);

  Future<Result<TheaterCase>> updateCaseSchedule(
    String caseId,
    Map<String, Object?> payload,
  );

  Future<Result<TheaterCase>> updateStage(
    String caseId,
    Map<String, Object?> payload,
  );

  Future<Result<TheaterCase>> upsertAnesthesiaRecord(
    String caseId,
    Map<String, Object?> payload,
  );

  Future<Result<TheaterCase>> addAnesthesiaObservation(
    String caseId,
    Map<String, Object?> payload,
  );

  Future<Result<TheaterCase>> upsertPostOpNote(
    String caseId,
    Map<String, Object?> payload,
  );

  Future<Result<TheaterCase>> toggleChecklistItem(
    String caseId,
    Map<String, Object?> payload,
  );

  Future<Result<TheaterCase>> assignResource(
    String caseId,
    Map<String, Object?> payload,
  );

  Future<Result<TheaterCase>> releaseResource(
    String caseId,
    Map<String, Object?> payload,
  );

  Future<Result<TheaterCase>> finalizeRecord(
    String caseId,
    Map<String, Object?> payload,
  );

  Future<Result<TheaterCase>> reopenRecord(
    String caseId,
    Map<String, Object?> payload,
  );
}
