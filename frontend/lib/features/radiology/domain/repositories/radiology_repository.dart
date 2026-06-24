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

  Future<Result<List<RadiologyCatalogTest>>> listRadiologyCatalogTests({
    String? search,
    bool includeStandardCatalog = true,
  });

  Future<Result<RadiologyCatalogTest>> createRadiologyCatalogTest(
    Map<String, Object?> payload,
  );

  Future<Result<RadiologyCatalogTest>> updateRadiologyCatalogTest(
    String testId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deleteRadiologyCatalogTest(String testId);

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
