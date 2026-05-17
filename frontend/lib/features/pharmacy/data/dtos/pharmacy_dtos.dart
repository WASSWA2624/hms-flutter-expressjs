import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef PharmacyJsonMap = Map<String, Object?>;

final class PharmacyWorkbenchDto {
  const PharmacyWorkbenchDto({required this.workbench});

  final PharmacyWorkbench workbench;

  factory PharmacyWorkbenchDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final PharmacyJsonMap response = _expectMap(responseData);
    final PharmacyJsonMap data = _map(response['data']);
    final List<PharmacyOrder> orders = _list(data['worklist'])
        .map(PharmacyOrderDto.new)
        .map((PharmacyOrderDto dto) => dto.toEntity())
        .where((PharmacyOrder item) => item.id.isNotEmpty)
        .toList(growable: false);

    return PharmacyWorkbenchDto(
      workbench: PharmacyWorkbench(
        summary: PharmacyWorkbenchSummaryDto(_map(data['summary'])).toEntity(),
        orders: AppPage<PharmacyOrder>(
          items: orders,
          request: request,
          totalItemCount: _int(_map(data['pagination'])['total']),
        ),
      ),
    );
  }
}

final class PharmacyWorkbenchSummaryDto {
  const PharmacyWorkbenchSummaryDto(this.json);

  final PharmacyJsonMap json;

  PharmacyWorkbenchSummary toEntity() {
    return PharmacyWorkbenchSummary(
      totalOrders: _int(json['total_orders']) ?? 0,
      orderedQueue: _int(json['ordered_queue']) ?? 0,
      partiallyDispensedQueue: _int(json['partially_dispensed_queue']) ?? 0,
      dispensedOrders: _int(json['dispensed_orders']) ?? 0,
      cancelledOrders: _int(json['cancelled_orders']) ?? 0,
      pendingAttestations: _int(json['pending_attestations']) ?? 0,
    );
  }
}

final class PharmacyOrderWorkflowDto {
  const PharmacyOrderWorkflowDto(this.json);

  final PharmacyJsonMap json;

  factory PharmacyOrderWorkflowDto.fromResponse(Object? responseData) {
    final PharmacyJsonMap response = _expectMap(responseData);
    return PharmacyOrderWorkflowDto(_map(response['data']));
  }

  PharmacyOrderWorkflow toEntity() {
    final PharmacyOrder order = PharmacyOrderDto(
      _map(json['order']),
    ).toEntity();
    final List<PharmacyOrderItem> items = _list(json['items'])
        .map(PharmacyOrderItemDto.new)
        .map((PharmacyOrderItemDto dto) => dto.toEntity())
        .where((PharmacyOrderItem item) => item.id.isNotEmpty)
        .toList(growable: false);
    final List<PharmacyAttestation> attestations = _list(json['attestations'])
        .map(PharmacyAttestationDto.new)
        .map((PharmacyAttestationDto dto) => dto.toEntity())
        .where((PharmacyAttestation item) => item.id.isNotEmpty)
        .toList(growable: false);

    return PharmacyOrderWorkflow(
      order: order.copyWith(
        items: items,
        attestations: attestations,
        itemCount: items.isEmpty ? order.itemCount : items.length,
      ),
      items: items,
      attestations: attestations,
      timeline: _list(json['timeline'])
          .map(PharmacyTimelineItemDto.new)
          .map((PharmacyTimelineItemDto dto) => dto.toEntity())
          .where((PharmacyTimelineItem item) => item.id.isNotEmpty)
          .toList(growable: false),
      nextActions: PharmacyNextActionsDto(
        _map(json['next_actions']),
      ).toEntity(),
    );
  }
}

final class PharmacyMutationResultDto {
  const PharmacyMutationResultDto(this.json);

  final PharmacyJsonMap json;

  factory PharmacyMutationResultDto.fromResponse(Object? responseData) {
    final PharmacyJsonMap response = _expectMap(responseData);
    return PharmacyMutationResultDto(_map(response['data']));
  }

  PharmacyMutationResult toEntity() {
    return PharmacyMutationResult(
      workflow: PharmacyOrderWorkflowDto(_map(json['workflow'])).toEntity(),
      summary: _map(json['order_summary']).isEmpty
          ? null
          : PharmacyWorkbenchSummaryDto(_map(json['order_summary'])).toEntity(),
      dispenseBatchRef: _string(json['dispense_batch_ref']),
    );
  }
}

final class PharmacyOrderDto {
  const PharmacyOrderDto(this.json);

  final PharmacyJsonMap json;

  PharmacyOrder toEntity() {
    final List<PharmacyOrderItem> items = _list(json['items'])
        .map(PharmacyOrderItemDto.new)
        .map((PharmacyOrderItemDto dto) => dto.toEntity())
        .where((PharmacyOrderItem item) => item.id.isNotEmpty)
        .toList(growable: false);
    final List<PharmacyAttestation> attestations =
        _list(json['dispense_attestations'])
            .map(PharmacyAttestationDto.new)
            .map((PharmacyAttestationDto dto) => dto.toEntity())
            .where((PharmacyAttestation item) => item.id.isNotEmpty)
            .toList(growable: false);

    return PharmacyOrder(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId: _string(json['display_id']),
      encounterId: _string(json['encounter_id']),
      patientId: _string(json['patient_id']),
      patientDisplayName: _string(json['patient_display_name']),
      orderSource: _string(json['order_source']),
      priority: _string(json['priority']),
      status: _string(json['status']),
      orderedAt: _date(json['ordered_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      itemCount: _int(json['item_count']) ?? items.length,
      quantityPrescribedTotal: _number(json['quantity_prescribed_total']) ?? 0,
      quantityDispensedTotal: _number(json['quantity_dispensed_total']) ?? 0,
      quantityPendingTotal: _number(json['quantity_pending_total']) ?? 0,
      quantityReturnedTotal: _number(json['quantity_returned_total']) ?? 0,
      quantityRemainingTotal: _number(json['quantity_remaining_total']) ?? 0,
      pendingAttestationBatchCount:
          _int(json['pending_attestation_batch_count']) ?? 0,
      pendingAttestationBatches: _list(json['pending_attestation_batches'])
          .map(PharmacyPendingBatchDto.new)
          .map((PharmacyPendingBatchDto dto) => dto.toEntity())
          .where((PharmacyPendingBatch item) {
            return item.dispenseBatchRef.isNotEmpty;
          })
          .toList(growable: false),
      items: items,
      attestations: attestations,
    );
  }
}

final class PharmacyPendingBatchDto {
  const PharmacyPendingBatchDto(this.json);

  final PharmacyJsonMap json;

  PharmacyPendingBatch toEntity() {
    return PharmacyPendingBatch(
      dispenseBatchRef: _string(json['dispense_batch_ref']) ?? '',
      preparedAt: _date(json['prepared_at']),
      preparedByRole: _string(json['prepared_by_role']),
    );
  }
}

final class PharmacyOrderItemDto {
  const PharmacyOrderItemDto(this.json);

  final PharmacyJsonMap json;

  PharmacyOrderItem toEntity() {
    final List<PharmacyStockMapping> mappings = _list(json['stock_mappings'])
        .map(PharmacyStockMappingDto.new)
        .map((PharmacyStockMappingDto dto) => dto.toEntity())
        .where((PharmacyStockMapping item) => item.id.isNotEmpty)
        .toList(growable: false);

    return PharmacyOrderItem(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId: _string(json['display_id']),
      pharmacyOrderId: _string(json['pharmacy_order_id']),
      drugId: _string(json['drug_id']),
      drugDisplayName: _string(json['drug_display_name']),
      drugCode: _string(json['drug_code']),
      drugForm: _string(json['drug_form']),
      drugStrength: _string(json['drug_strength']),
      dosage: _string(json['dosage']),
      doseAmount: _number(json['dose_amount']),
      doseUnit: _string(json['dose_unit']),
      frequency: _string(json['frequency']),
      route: _string(json['route']),
      durationValue: _number(json['duration_value']),
      durationUnit: _string(json['duration_unit']),
      instructions: _string(json['instructions']),
      customPrescription: _string(json['custom_prescription']),
      status: _string(json['status']),
      quantity: _number(json['quantity']) ?? 0,
      quantityUnit: _string(json['quantity_unit']),
      quantityPrescribed: _number(json['quantity_prescribed']) ?? 0,
      quantityDispensed: _number(json['quantity_dispensed']) ?? 0,
      quantityPending: _number(json['quantity_pending']) ?? 0,
      quantityReturned: _number(json['quantity_returned']) ?? 0,
      quantityRemaining: _number(json['quantity_remaining']) ?? 0,
      dispenseLogs: _list(json['dispense_logs'])
          .map(PharmacyDispenseLogDto.new)
          .map((PharmacyDispenseLogDto dto) => dto.toEntity())
          .where((PharmacyDispenseLog item) => item.id.isNotEmpty)
          .toList(growable: false),
      stockMappings: mappings,
      defaultStockMapping: _map(json['default_stock_mapping']).isEmpty
          ? mappings
                .where((PharmacyStockMapping item) => item.isDefault)
                .firstOrNull
          : PharmacyStockMappingDto(
              _map(json['default_stock_mapping']),
            ).toEntity(),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class PharmacyStockMappingDto {
  const PharmacyStockMappingDto(this.json);

  final PharmacyJsonMap json;

  PharmacyStockMapping toEntity() {
    return PharmacyStockMapping(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId: _string(json['display_id']),
      drugId: _string(json['drug_id']),
      inventoryItemId: _string(json['inventory_item_id']),
      isDefault: _bool(json['is_default']),
      deductionFactor: _number(json['deduction_factor']) ?? 1,
      inventoryItem: _map(json['inventory_item']).isEmpty
          ? null
          : PharmacyInventoryItemDto(_map(json['inventory_item'])).toEntity(),
    );
  }
}

final class PharmacyInventoryItemDto {
  const PharmacyInventoryItemDto(this.json);

  final PharmacyJsonMap json;

  PharmacyInventoryItem toEntity() {
    return PharmacyInventoryItem(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId: _string(json['display_id']),
      tenantId: _string(json['tenant_id']),
      name: _string(json['name']),
      category: _string(json['category']),
      sku: _string(json['sku']),
      unit: _string(json['unit']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class PharmacyDispenseLogDto {
  const PharmacyDispenseLogDto(this.json);

  final PharmacyJsonMap json;

  PharmacyDispenseLog toEntity() {
    return PharmacyDispenseLog(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId: _string(json['display_id']),
      pharmacyOrderItemId: _string(json['pharmacy_order_item_id']),
      dispenseBatchRef: _string(json['dispense_batch_ref']),
      status: _string(json['status']),
      quantityDispensed: _number(json['quantity_dispensed']) ?? 0,
      dispensedAt: _date(json['dispensed_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class PharmacyAttestationDto {
  const PharmacyAttestationDto(this.json);

  final PharmacyJsonMap json;

  PharmacyAttestation toEntity() {
    return PharmacyAttestation(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId: _string(json['display_id']),
      pharmacyOrderId: _string(json['pharmacy_order_id']),
      dispenseBatchRef: _string(json['dispense_batch_ref']),
      phase: _string(json['phase']),
      attestedByUserId: _string(json['attested_by_user_id']),
      attestedRole: _string(json['attested_role']),
      statement: _string(json['statement']),
      reason: _string(json['reason']),
      attestedAt: _date(json['attested_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class PharmacyTimelineItemDto {
  const PharmacyTimelineItemDto(this.json);

  final PharmacyJsonMap json;

  PharmacyTimelineItem toEntity() {
    return PharmacyTimelineItem(
      id: _string(json['id']) ?? '',
      type: _string(json['type']),
      labelKey: _string(json['label_key']),
      labelParams: _map(json['label_params']),
      at: _date(json['at']),
    );
  }
}

final class PharmacyNextActionsDto {
  const PharmacyNextActionsDto(this.json);

  final PharmacyJsonMap json;

  PharmacyNextActions toEntity() {
    return PharmacyNextActions(
      canPrepareDispense: _bool(json['can_prepare_dispense']),
      canAttestDispense: _bool(json['can_attest_dispense']),
      canCancel: _bool(json['can_cancel']),
      canReturn: _bool(json['can_return']),
      canAdjustInventory: _bool(json['can_adjust_inventory']),
    );
  }
}

final class PharmacyDrugPageDto {
  const PharmacyDrugPageDto({required this.page});

  final AppPage<PharmacyDrug> page;

  factory PharmacyDrugPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final PharmacyJsonMap response = _expectMap(responseData);
    final PharmacyJsonMap data = _map(response['data']);
    final List<PharmacyDrug> drugs = _list(data['drugs'])
        .map(PharmacyDrugDto.new)
        .map((PharmacyDrugDto dto) => dto.toEntity())
        .where((PharmacyDrug item) => item.id.isNotEmpty)
        .toList(growable: false);

    return PharmacyDrugPageDto(
      page: AppPage<PharmacyDrug>(
        items: drugs,
        request: request,
        totalItemCount: _int(_map(data['pagination'])['total']),
      ),
    );
  }
}

final class PharmacyDrugDto {
  const PharmacyDrugDto(this.json);

  final PharmacyJsonMap json;

  PharmacyDrug toEntity() {
    return PharmacyDrug(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId: _string(json['display_id']),
      name: _string(json['name']),
      code: _string(json['code']),
      form: _string(json['form']),
      strength: _string(json['strength']),
      quantityOnHand: _number(json['quantity_on_hand']) ?? 0,
      availableQuantity: _number(json['available_quantity']) ?? 0,
      stockLevel: _number(json['stock_level']) ?? 0,
      stockStatus: _string(json['stock_status']),
      lowStock: _bool(json['low_stock']),
      pendingStock: _bool(json['pending_stock']),
      stockMappings: _list(json['stock_mappings'])
          .map(PharmacyDrugStockMappingDto.new)
          .map((PharmacyDrugStockMappingDto dto) => dto.toEntity())
          .where((PharmacyDrugStockMapping item) => item.id.isNotEmpty)
          .toList(growable: false),
      stockRows: _list(json['stock_rows'])
          .map(PharmacyInventoryStockDto.new)
          .map((PharmacyInventoryStockDto dto) => dto.toEntity())
          .where((PharmacyInventoryStock item) => item.id.isNotEmpty)
          .toList(growable: false),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class PharmacyDrugStockMappingDto {
  const PharmacyDrugStockMappingDto(this.json);

  final PharmacyJsonMap json;

  PharmacyDrugStockMapping toEntity() {
    return PharmacyDrugStockMapping(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId: _string(json['display_id']),
      inventoryItemId: _string(json['inventory_item_id']),
      isDefault: _bool(json['is_default']),
      deductionFactor: _number(json['deduction_factor']) ?? 1,
      inventoryItem: _map(json['inventory_item']).isEmpty
          ? null
          : PharmacyInventoryItemDto(_map(json['inventory_item'])).toEntity(),
      stocks: _list(json['stocks'])
          .map(PharmacyInventoryStockDto.new)
          .map((PharmacyInventoryStockDto dto) => dto.toEntity())
          .where((PharmacyInventoryStock item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final class PharmacyInventoryStockDto {
  const PharmacyInventoryStockDto(this.json);

  final PharmacyJsonMap json;

  PharmacyInventoryStock toEntity() {
    return PharmacyInventoryStock(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId: _string(json['display_id']),
      inventoryItemId: _string(json['inventory_item_id']),
      inventoryItem: _map(json['inventory_item']).isEmpty
          ? null
          : PharmacyInventoryItemDto(_map(json['inventory_item'])).toEntity(),
      facilityId: _string(json['facility_id']),
      facilityName: _string(json['facility_name']),
      quantity: _number(json['quantity']) ?? 0,
      reorderLevel: _number(json['reorder_level']) ?? 0,
      pendingStock: _bool(json['pending_stock']),
      stockStatus: _string(json['stock_status']),
      lowStock: _bool(json['low_stock']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

PharmacyJsonMap _expectMap(Object? value) {
  if (value is PharmacyJsonMap) {
    return value;
  }
  throw const FormatException('Expected pharmacy response object.');
}

PharmacyJsonMap _map(Object? value) {
  return value is PharmacyJsonMap ? value : <String, Object?>{};
}

List<PharmacyJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <PharmacyJsonMap>[];
  }
  return value.whereType<PharmacyJsonMap>().toList(growable: false);
}

String? _string(Object? value) {
  if (value == null) {
    return null;
  }
  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime? _date(Object? value) {
  final String? normalized = _string(value);
  if (normalized == null) {
    return null;
  }
  return DateTime.tryParse(normalized);
}

num? _number(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value);
  }
  return null;
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

bool _bool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    if (<String>['true', '1', 'yes', 'on'].contains(normalized)) {
      return true;
    }
    if (<String>['false', '0', 'no', 'off'].contains(normalized)) {
      return false;
    }
  }
  if (value is num) {
    return value != 0;
  }
  return fallback;
}
