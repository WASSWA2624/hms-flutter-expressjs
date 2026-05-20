import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/housekeeping/domain/entities/housekeeping_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class HousekeepingRepository {
  Future<Result<HousekeepingWorkspaceLoad>> getWorkspace(
    HousekeepingWorkspaceQuery query,
  );

  Future<Result<void>> createTask(HousekeepingTaskDraft draft);

  Future<Result<void>> updateTask(
    String taskId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> createSchedule(HousekeepingScheduleDraft draft);

  Future<Result<void>> createMaintenanceRequest(
    HousekeepingMaintenanceRequestDraft draft,
  );

  Future<Result<void>> updateMaintenanceRequest(
    String requestId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> triageMaintenanceRequest(
    String requestId,
    HousekeepingMaintenanceTriageDraft draft,
  );
}

final class HousekeepingWorkspaceLoad {
  const HousekeepingWorkspaceLoad({
    required this.overview,
    required this.items,
  });

  final HousekeepingWorkspaceOverview overview;
  final AppPage<HousekeepingWorkItem> items;
}
