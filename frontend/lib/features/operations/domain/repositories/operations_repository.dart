import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/operations/domain/entities/operations_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class OperationsRepository {
  Future<Result<AppPage<OperationsWorkItem>>> listRequests(
    OperationsWorkItemQuery query,
  );

  Future<Result<OperationsWorkItem>> getRequest(String requestId);

  Future<Result<AppPage<OperationsAsset>>> listAssets(
    OperationsAssetQuery query,
  );

  Future<Result<AppPage<OperationsServiceLog>>> listServiceLogs(
    OperationsServiceLogQuery query,
  );

  Future<Result<OperationsWorkItem>> createRequest(
    OperationsRequestDraft draft,
  );

  Future<Result<OperationsWorkItem>> triageRequest(
    String requestId,
    OperationsTriageDraft draft,
  );

  Future<Result<OperationsWorkItem>> updateRequestStatus(
    OperationsWorkItem request,
    OperationsStatusUpdateDraft draft,
  );

  Future<Result<OperationsWorkItem>> appendRequestNote(
    OperationsWorkItem request,
    OperationsRequestNoteDraft draft,
  );

  Future<Result<OperationsServiceLog>> addServiceLog(
    OperationsServiceLogDraft draft,
  );
}
