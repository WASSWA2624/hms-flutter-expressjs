import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class LabRepository {
  Future<Result<LabWorkbenchBundle>> loadWorkbench(LabWorkbenchQuery query);

  Future<Result<LabOrderWorkflow>> loadOrderWorkflow(String orderId);

  Future<Result<List<LabCatalogItem>>> listTests({String? search});

  Future<Result<List<LabCatalogItem>>> listPanels({String? search});

  Future<Result<List<LabQcLog>>> listQcLogs({String? search});

  Future<Result<void>> createOrder(Map<String, Object?> payload);

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
