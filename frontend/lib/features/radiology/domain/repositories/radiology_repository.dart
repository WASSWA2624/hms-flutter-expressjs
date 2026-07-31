import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class RadiologyRepository {
  Future<Result<RadiologyWorkbench>> getWorkbench(
    RadiologyWorkspaceQuery query,
  );

  Future<Result<RadiologyReferenceData>> getReferenceData({
    String? search,
    String? patientId,
    int limit = 20,
  });

  Future<Result<List<RadiologyCatalogProcedure>>> listRadiologyCatalogProcedures({
    String? search,
    String? tenantId,
    bool includeStandardCatalog = true,
    bool includeDeleted = false,
    int limit = 100,
  });

  Future<Result<List<RadiologyCatalogProcedure>>> listFacilityRadiologyProcedures({
    String? tenantId,
    String? facilityId,
    String? search,
    int page = 1,
    int limit = 100,
    bool offeredOnly = false,
  });

  Future<Result<List<RadiologyCatalogProcedure>>> searchFacilityRadiologyCatalog({
    String? tenantId,
    String? facilityId,
    String? query,
    int limit = 25,
  });

  Future<Result<RadiologyCatalogProcedure>> upsertFacilityRadiologyProcedureOffering(
    String procedureId,
    Map<String, Object?> payload, {
    String? tenantId,
    String? facilityId,
  });

  Future<Result<void>> disableFacilityRadiologyProcedureOffering(
    String procedureId,
    String reason, {
    String? tenantId,
    String? facilityId,
  });

  Future<Result<RadiologyCatalogProcedure>> createRadiologyCatalogProcedure(
    Map<String, Object?> payload,
  );

  Future<Result<RadiologyCatalogProcedure>> updateRadiologyCatalogProcedure(
    String procedureId,
    Map<String, Object?> payload,
  );

  Future<Result<RadiologyCatalogProcedure>> deleteRadiologyCatalogProcedure(
    String procedureId,
  );

  Future<Result<RadiologyCatalogProcedure>> restoreRadiologyCatalogProcedure(
    String procedureId,
  );

  Future<Result<void>> permanentDeleteRadiologyCatalogProcedure(
    String procedureId,
  );

  Future<Result<List<RadiologyEquipmentRecord>>> listEquipmentRecords({
    String? search,
  });

  Future<Result<RadiologyWorkflow>> getWorkflow(String orderId);

  Future<Result<RadiologyWorkflow>> createOrder(Map<String, Object?> payload);

  Future<Result<RadiologyWorkflow>> updateOrderRequestDetails(
    String orderId,
    Map<String, Object?> payload,
  );

  Future<Result<RadiologyWorkflow>> assignOrder(
    String orderId,
    Map<String, Object?> payload,
  );

  Future<Result<RadiologyWorkflow>> startOrder(
    String orderId,
    Map<String, Object?> payload,
  );

  Future<Result<RadiologyWorkflow>> completeOrder(
    String orderId,
    Map<String, Object?> payload,
  );

  Future<Result<RadiologyWorkflow>> cancelOrder(
    String orderId,
    Map<String, Object?> payload,
  );

  Future<Result<RadiologyWorkflow>> createStudy(
    String orderId,
    Map<String, Object?> payload,
  );

  Future<Result<RadiologyWorkflow>> undoStudy(String studyId);

  Future<Result<RadiologyWorkflow>> undoDraftResult(String resultId);

  Future<Result<RadiologyWorkflow>> draftResult(
    String orderId,
    Map<String, Object?> payload,
  );

  Future<Result<RadiologyWorkflow>> finalizeResult(
    String resultId,
    Map<String, Object?> payload,
  );

  Future<Result<RadiologyWorkflow>> requestFinalization(
    String resultId,
    Map<String, Object?> payload,
  );

  Future<Result<RadiologyWorkflow>> attestFinalization(
    String resultId,
    Map<String, Object?> payload,
  );

  Future<Result<RadiologyWorkflow>> addendumResult(
    String resultId,
    Map<String, Object?> payload,
  );

  Future<Result<RadiologyWorkflow>> syncStudyToPacs(
    String studyId,
    Map<String, Object?> payload,
  );

  Future<Result<StudyAssetUploadSession>> initStudyAssetUpload(
    String studyId,
    Map<String, Object?> payload,
  );

  Future<Result<RadiologyWorkflow>> commitStudyAssetUpload(
    String studyId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deleteStudyAsset(String assetId);
}

@immutable
final class StudyAssetUploadSession {
  const StudyAssetUploadSession({
    required this.storageKey,
    required this.uploadToken,
    this.uploadUrl,
  });

  final String storageKey;
  final String uploadToken;
  final String? uploadUrl;
}

final class RadiologyWorkbench {
  const RadiologyWorkbench({required this.summary, required this.orders});

  final RadiologySummary summary;
  final AppPage<RadiologyOrder> orders;
}
