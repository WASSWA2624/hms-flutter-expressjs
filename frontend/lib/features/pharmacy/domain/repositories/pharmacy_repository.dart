import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class PharmacyRepository {
  Future<Result<PharmacyWorkbench>> loadWorkbench(PharmacyWorkbenchQuery query);

  Future<Result<PharmacyOrderWorkflow>> loadOrderWorkflow(String orderId);

  Future<Result<AppPage<PharmacyDrug>>> searchDrugs(PharmacyDrugQuery query);

  Future<Result<PharmacyInventoryWorkbench>> getInventoryStock(
    PharmacyInventoryStockQuery query,
  );

  Future<Result<PharmacyInventoryWorkbench>> adjustInventoryStock(
    PharmacyInventoryAdjustInput input,
  );

  Future<Result<PharmacyDrug>> createDrug(PharmacyDrugInput input);

  Future<Result<PharmacyDrug>> setupDrug(PharmacyDrugInput input);

  Future<Result<PharmacyDrug>> updateDrug(
    String drugId,
    PharmacyDrugUpdateInput input,
  );

  Future<Result<PharmacyDrug>> upsertFacilityOffering(
    String drugId,
    PharmacyFacilityOfferingInput input,
  );

  Future<Result<void>> deleteDrug(String drugId);

  Future<Result<AppPage<PharmacyFormularyItem>>> listFormularyItems(
    PharmacyFormularyQuery query,
  );

  Future<Result<PharmacyFormularyItem>> createFormularyItem(
    PharmacyFormularyItemInput input,
  );

  Future<Result<PharmacyFormularyItem>> updateFormularyItem(
    String formularyItemId, {
    bool? isActive,
  });

  Future<Result<void>> deleteFormularyItem(String formularyItemId);

  Future<Result<PharmacyOrderWorkflow>> recordOrderBilling(
    String orderId,
    Map<String, Object?> billing,
  );

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

  Future<Result<PharmacyStorageLayout>> loadStorageLayout({
    bool includeInactive = false,
    String? facilityId,
  });

  Future<Result<PharmacyStorageRoom>> createStorageRoom(
    PharmacyStorageRoomInput input,
  );

  Future<Result<PharmacyStorageRoom>> updateStorageRoom(
    String roomId,
    PharmacyStorageRoomUpdateInput input,
  );

  Future<Result<PharmacyStorageShelf>> createStorageShelf(
    String roomId,
    PharmacyStorageShelfInput input,
  );

  Future<Result<PharmacyStorageShelf>> updateStorageShelf(
    String shelfId,
    PharmacyStorageShelfUpdateInput input,
  );

  Future<Result<void>> deleteStorageRoom(String roomId);

  Future<Result<void>> deleteStorageShelf(String shelfId);
}
