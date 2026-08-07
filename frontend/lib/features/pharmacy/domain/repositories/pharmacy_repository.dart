import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class PharmacyRepository {
  Future<Result<PharmacyWorkbench>> loadWorkbench(PharmacyWorkbenchQuery query);

  Future<Result<PharmacyOrderWorkflow>> loadOrderWorkflow(String orderId);

  /// Creates a pharmacy order (walk-in or clinical) via pharmacy-workspace.
  Future<Result<PharmacyMutationResult>> createPharmacyOrder(
    Map<String, Object?> payload,
  );

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

  Future<Result<PharmacyMutationResult>> cancelOrderItem({
    required String orderId,
    required String itemId,
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
    bool includeDeleted = false,
    String? facilityId,
  });

  Future<Result<PharmacyStorageRoomSimilarityResult>>
  checkStorageRoomSimilarity({
    required String name,
    String? code,
    String? facilityId,
    String? excludeRoomId,
  });

  Future<Result<PharmacyStorageShelfSimilarityResult>>
  checkStorageShelfSimilarity({
    required String roomId,
    required String label,
    String? shelfCode,
    String? excludeShelfId,
  });

  Future<Result<PharmacyDrugSimilarityResult>> checkDrugSimilarity({
    required String genericName,
    String? name,
    String? brandName,
    String? code,
    String? form,
    String? strength,
    String? tenantId,
    String? excludeDrugId,
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

  Future<Result<PharmacyStorageRoom>> restoreStorageRoom(String roomId);

  Future<Result<void>> permanentDeleteStorageRoom(String roomId);

  Future<Result<void>> deleteStorageShelf(String shelfId);

  Future<Result<AppPage<PharmacySupplier>>> listSuppliers(
    PharmacySupplierQuery query,
  );

  Future<Result<PharmacySupplierSimilarityResult>> checkSupplierSimilarity({
    required String name,
    String? contactEmail,
    String? phone,
    String? location,
    String? tenantId,
    String? excludeSupplierId,
  });

  Future<Result<PharmacySupplier>> createSupplier(PharmacySupplierInput input);

  Future<Result<PharmacySupplier>> updateSupplier(
    String supplierId,
    PharmacySupplierUpdateInput input,
  );

  Future<Result<void>> deleteSupplier(String supplierId);
}
