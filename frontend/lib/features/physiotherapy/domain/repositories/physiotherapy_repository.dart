import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/entities/physiotherapy_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class PhysiotherapyRepository {
  Future<Result<AppPage<TherapyWorkItem>>> listWorkItems(
    PhysiotherapyWorklistQuery query,
  );

  Future<Result<PhysiotherapyDetail>> loadDetail(TherapyWorkItem item);

  Future<Result<PhysiotherapyDetail>> acceptReferral({
    required TherapyWorkItem item,
    required String note,
  });

  Future<Result<PhysiotherapyDetail>> scheduleSession({
    required TherapyWorkItem item,
    required DateTime startAt,
    required DateTime endAt,
    String? providerUserId,
    String? reason,
  });

  Future<Result<PhysiotherapyDetail>> recordAssessment({
    required TherapyWorkItem item,
    required String assessment,
    required String goals,
    required String plan,
    String? instructions,
  });

  Future<Result<PhysiotherapyDetail>> recordSession({
    required TherapyWorkItem item,
    required String note,
    String? attendanceStatus,
  });

  Future<Result<PhysiotherapyDetail>> markAttendance({
    required TherapyWorkItem item,
    required String status,
    String? note,
  });

  Future<Result<PhysiotherapyDetail>> updatePlan({
    required TherapyWorkItem item,
    required String plan,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<Result<PhysiotherapyDetail>> addProgressNote({
    required TherapyWorkItem item,
    required String authorUserId,
    required String note,
  });

  Future<Result<PhysiotherapyDetail>> scheduleFollowUp({
    required TherapyWorkItem item,
    required DateTime scheduledAt,
    String? notes,
  });

  Future<Result<PhysiotherapyDetail>> closeEpisode({
    required TherapyWorkItem item,
    required String summary,
  });
}
