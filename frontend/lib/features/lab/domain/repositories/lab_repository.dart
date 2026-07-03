import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class LabRepository {
  Future<Result<LabWorkbenchBundle>> loadWorkbench(LabWorkbenchQuery query);

  Future<Result<LabOrderWorkflow>> loadOrderWorkflow(String orderId);

  Future<Result<List<LabOrderPatientContext>>> searchOrderContextPatients({
    String? search,
    int limit = 8,
  });

  Future<Result<LabOrderPatientContextDetail>> loadOrderPatientContext(
    String patientId,
  );

  Future<Result<List<LabCatalogItem>>> listTests({String? search});

  Future<Result<List<LabCatalogItem>>> listPanels({String? search});

  Future<Result<List<LabCatalogItem>>> listFacilityLabTests({
    String? search,
    int page = 1,
    int limit = 100,
    bool offeredOnly = false,
  });

  Future<Result<List<LabCatalogItem>>> listFacilityLabPanels({
    String? search,
    int page = 1,
    int limit = 100,
    bool offeredOnly = false,
  });

  Future<Result<List<LabCatalogItem>>> searchFacilityLabCatalog({
    required String termType,
    String? query,
    int limit = 25,
  });

  Future<Result<LabCatalogItem>> upsertFacilityLabTestOffering(
    String testId,
    Map<String, Object?> payload,
  );

  Future<Result<LabCatalogItem>> upsertFacilityLabPanelOffering(
    String panelId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> disableFacilityLabTestOffering(
    String testId,
    String reason,
  );

  Future<Result<void>> disableFacilityLabPanelOffering(
    String panelId,
    String reason,
  );

  Future<Result<List<LabQcLog>>> listQcLogs({String? search});

  Future<Result<void>> createOrder(Map<String, Object?> payload);

  Future<Result<void>> updateOrder(
    String orderId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deleteOrder(String orderId, String reason);

  Future<Result<LabCatalogItem>> createLabTest(Map<String, Object?> payload);

  Future<Result<LabCatalogItem>> createLabPanel(Map<String, Object?> payload);

  Future<Result<LabOrderWorkflow>> collectOrder(
    String orderId,
    Map<String, Object?> payload,
  );

  Future<Result<LabOrderWorkflow>> receiveSample(
    String sampleId,
    Map<String, Object?> payload,
  );

  Future<Result<LabOrderWorkflow>> rejectSample(
    String sampleId,
    Map<String, Object?> payload,
  );

  Future<Result<LabOrderWorkflow>> releaseOrderItem(
    String itemId,
    Map<String, Object?> payload,
  );

  Future<Result<LabOrderWorkflow>> verifyOrderItem(
    String itemId,
    Map<String, Object?> payload,
  );

  Future<Result<LabOrderWorkflow>> verifyOrderResults(
    String orderId,
    List<Map<String, Object?>> results,
  );

  Future<Result<void>> createLabResult(Map<String, Object?> payload);

  Future<Result<void>> updateLabResult(
    String resultId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deleteLabResult(String resultId);

  Future<Result<LabOrderWorkflow>> rejectOrderItem(
    String itemId,
    Map<String, Object?> payload,
  );

  Future<Result<LabOrderWorkflow>> reopenOrderItemResult(
    String itemId,
    Map<String, Object?> payload,
  );

  Future<Result<LabOrderWorkflow>> restoreOrderItem(
    String itemId,
    Map<String, Object?> payload,
  );

  Future<Result<LabOrderWorkflow>> deleteOrderItems(
    String orderId,
    Map<String, Object?> payload,
  );

  Future<Result<LabCatalogItem>> updateLabTest(
    String testId,
    Map<String, Object?> payload,
  );

  Future<Result<LabCatalogItem>> updateLabPanel(
    String panelId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deleteLabTest(String testId, String reason);

  Future<Result<void>> deleteLabPanel(String panelId, String reason);

  Future<Result<LabOrderWorkflow>> reverseWorkflow(
    String orderId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> createQcLog(Map<String, Object?> payload);
}

final class LabWorkbenchBundle {
  const LabWorkbenchBundle({required this.summary, required this.worklist});

  final LabWorkbenchSummary summary;
  final AppPage<LabOrderSummary> worklist;
}
