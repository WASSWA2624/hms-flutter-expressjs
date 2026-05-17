import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class PharmacyRepository {
  Future<Result<PharmacyWorkbench>> loadWorkbench(PharmacyWorkbenchQuery query);

  Future<Result<PharmacyOrderWorkflow>> loadOrderWorkflow(String orderId);

  Future<Result<AppPage<PharmacyDrug>>> searchDrugs(PharmacyDrugQuery query);

  Future<Result<PharmacyMutationResult>> prepareDispense({
    required String orderId,
    required List<PharmacyDispenseLineInput> items,
    String? dispenseBatchRef,
    String? statement,
    String? reason,
  });

  Future<Result<PharmacyMutationResult>> attestDispense({
    required String orderId,
    required String dispenseBatchRef,
    String? statement,
    String? reason,
    DateTime? attestedAt,
  });

  Future<Result<PharmacyMutationResult>> cancelOrder({
    required String orderId,
    required String reason,
    String? notes,
  });

  Future<Result<PharmacyMutationResult>> returnDispense({
    required String orderId,
    required List<PharmacyReturnLineInput> items,
    String? reason,
    String? notes,
  });
}
