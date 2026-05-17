import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum PharmacyOrderFilter {
  all,
  ready,
  partial,
  completed,
  cancelled,
  pendingPayment,
  partialStock,
  urgent,
  discharge,
}

extension PharmacyOrderFilterX on PharmacyOrderFilter {
  String? get backendStatus {
    return switch (this) {
      PharmacyOrderFilter.ready => 'ORDERED',
      PharmacyOrderFilter.partial => 'PARTIALLY_DISPENSED',
      PharmacyOrderFilter.completed => 'DISPENSED',
      PharmacyOrderFilter.cancelled => 'CANCELLED',
      PharmacyOrderFilter.all ||
      PharmacyOrderFilter.pendingPayment ||
      PharmacyOrderFilter.partialStock ||
      PharmacyOrderFilter.urgent ||
      PharmacyOrderFilter.discharge => null,
    };
  }

  bool get isBackendBacked {
    return switch (this) {
      PharmacyOrderFilter.all ||
      PharmacyOrderFilter.ready ||
      PharmacyOrderFilter.partial ||
      PharmacyOrderFilter.completed ||
      PharmacyOrderFilter.cancelled => true,
      PharmacyOrderFilter.pendingPayment ||
      PharmacyOrderFilter.partialStock ||
      PharmacyOrderFilter.urgent ||
      PharmacyOrderFilter.discharge => false,
    };
  }
}

@immutable
final class PharmacyWorkbenchQuery {
  const PharmacyWorkbenchQuery({
    this.search = '',
    this.filter = PharmacyOrderFilter.ready,
    this.pageRequest = const AppPageRequest(),
  });

  final String search;
  final PharmacyOrderFilter filter;
  final AppPageRequest pageRequest;

  PharmacyWorkbenchQuery copyWith({
    String? search,
    PharmacyOrderFilter? filter,
    AppPageRequest? pageRequest,
  }) {
    return PharmacyWorkbenchQuery(
      search: search ?? this.search,
      filter: filter ?? this.filter,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class PharmacyDrugQuery {
  const PharmacyDrugQuery({
    this.search = '',
    this.stockStatus,
    this.pageRequest = const AppPageRequest(pageSize: 10),
  });

  final String search;
  final String? stockStatus;
  final AppPageRequest pageRequest;

  PharmacyDrugQuery copyWith({
    String? search,
    String? stockStatus,
    AppPageRequest? pageRequest,
    bool clearStockStatus = false,
  }) {
    return PharmacyDrugQuery(
      search: search ?? this.search,
      stockStatus: clearStockStatus ? null : stockStatus ?? this.stockStatus,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class PharmacyWorkbenchSummary {
  const PharmacyWorkbenchSummary({
    this.totalOrders = 0,
    this.orderedQueue = 0,
    this.partiallyDispensedQueue = 0,
    this.dispensedOrders = 0,
    this.cancelledOrders = 0,
    this.pendingAttestations = 0,
  });

  final int totalOrders;
  final int orderedQueue;
  final int partiallyDispensedQueue;
  final int dispensedOrders;
  final int cancelledOrders;
  final int pendingAttestations;
}

@immutable
final class PharmacyWorkbench {
  const PharmacyWorkbench({required this.summary, required this.orders});

  final PharmacyWorkbenchSummary summary;
  final AppPage<PharmacyOrder> orders;

  PharmacyWorkbench copyWith({
    PharmacyWorkbenchSummary? summary,
    AppPage<PharmacyOrder>? orders,
  }) {
    return PharmacyWorkbench(
      summary: summary ?? this.summary,
      orders: orders ?? this.orders,
    );
  }
}

@immutable
final class PharmacyOrder {
  const PharmacyOrder({
    required this.id,
    this.displayId,
    this.encounterId,
    this.patientId,
    this.patientDisplayName,
    this.orderSource,
    this.priority,
    this.status,
    this.orderedAt,
    this.createdAt,
    this.updatedAt,
    this.itemCount = 0,
    this.quantityPrescribedTotal = 0,
    this.quantityDispensedTotal = 0,
    this.quantityPendingTotal = 0,
    this.quantityReturnedTotal = 0,
    this.quantityRemainingTotal = 0,
    this.pendingAttestationBatchCount = 0,
    this.pendingAttestationBatches = const <PharmacyPendingBatch>[],
    this.items = const <PharmacyOrderItem>[],
    this.attestations = const <PharmacyAttestation>[],
  });

  final String id;
  final String? displayId;
  final String? encounterId;
  final String? patientId;
  final String? patientDisplayName;
  final String? orderSource;
  final String? priority;
  final String? status;
  final DateTime? orderedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int itemCount;
  final num quantityPrescribedTotal;
  final num quantityDispensedTotal;
  final num quantityPendingTotal;
  final num quantityReturnedTotal;
  final num quantityRemainingTotal;
  final int pendingAttestationBatchCount;
  final List<PharmacyPendingBatch> pendingAttestationBatches;
  final List<PharmacyOrderItem> items;
  final List<PharmacyAttestation> attestations;

  String get displayTitle {
    return _firstNonEmpty(<String?>[
          patientDisplayName,
          patientId,
          displayId,
          id,
        ]) ??
        id;
  }

  bool get hasPendingAttestation {
    return pendingAttestationBatchCount > 0 ||
        pendingAttestationBatches.isNotEmpty;
  }

  bool get canPrepareDispense {
    return <String>[
          'ORDERED',
          'PARTIALLY_DISPENSED',
        ].contains((status ?? '').toUpperCase()) &&
        !hasPendingAttestation &&
        items.any((PharmacyOrderItem item) => item.quantityRemaining > 0);
  }

  bool get canAttestDispense {
    return <String>[
          'ORDERED',
          'PARTIALLY_DISPENSED',
        ].contains((status ?? '').toUpperCase()) &&
        hasPendingAttestation;
  }

  bool get canCancel {
    return <String>[
      'ORDERED',
      'PARTIALLY_DISPENSED',
    ].contains((status ?? '').toUpperCase());
  }

  bool get canReturn {
    return <String>[
          'DISPENSED',
          'PARTIALLY_DISPENSED',
        ].contains((status ?? '').toUpperCase()) &&
        items.any((PharmacyOrderItem item) => item.quantityDispensed > 0);
  }

  String? get firstPendingBatchRef {
    for (final PharmacyPendingBatch batch in pendingAttestationBatches) {
      final String value = batch.dispenseBatchRef.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  PharmacyOrder copyWith({
    String? status,
    DateTime? updatedAt,
    int? itemCount,
    num? quantityPrescribedTotal,
    num? quantityDispensedTotal,
    num? quantityPendingTotal,
    num? quantityReturnedTotal,
    num? quantityRemainingTotal,
    int? pendingAttestationBatchCount,
    List<PharmacyPendingBatch>? pendingAttestationBatches,
    List<PharmacyOrderItem>? items,
    List<PharmacyAttestation>? attestations,
  }) {
    return PharmacyOrder(
      id: id,
      displayId: displayId,
      encounterId: encounterId,
      patientId: patientId,
      patientDisplayName: patientDisplayName,
      orderSource: orderSource,
      priority: priority,
      status: status ?? this.status,
      orderedAt: orderedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      itemCount: itemCount ?? this.itemCount,
      quantityPrescribedTotal:
          quantityPrescribedTotal ?? this.quantityPrescribedTotal,
      quantityDispensedTotal:
          quantityDispensedTotal ?? this.quantityDispensedTotal,
      quantityPendingTotal: quantityPendingTotal ?? this.quantityPendingTotal,
      quantityReturnedTotal:
          quantityReturnedTotal ?? this.quantityReturnedTotal,
      quantityRemainingTotal:
          quantityRemainingTotal ?? this.quantityRemainingTotal,
      pendingAttestationBatchCount:
          pendingAttestationBatchCount ?? this.pendingAttestationBatchCount,
      pendingAttestationBatches:
          pendingAttestationBatches ?? this.pendingAttestationBatches,
      items: items ?? this.items,
      attestations: attestations ?? this.attestations,
    );
  }
}

@immutable
final class PharmacyPendingBatch {
  const PharmacyPendingBatch({
    required this.dispenseBatchRef,
    this.preparedAt,
    this.preparedByRole,
  });

  final String dispenseBatchRef;
  final DateTime? preparedAt;
  final String? preparedByRole;
}

@immutable
final class PharmacyOrderItem {
  const PharmacyOrderItem({
    required this.id,
    this.displayId,
    this.pharmacyOrderId,
    this.drugId,
    this.drugDisplayName,
    this.drugCode,
    this.drugForm,
    this.drugStrength,
    this.dosage,
    this.doseAmount,
    this.doseUnit,
    this.frequency,
    this.route,
    this.durationValue,
    this.durationUnit,
    this.instructions,
    this.customPrescription,
    this.status,
    this.quantity = 0,
    this.quantityUnit,
    this.quantityPrescribed = 0,
    this.quantityDispensed = 0,
    this.quantityPending = 0,
    this.quantityReturned = 0,
    this.quantityRemaining = 0,
    this.dispenseLogs = const <PharmacyDispenseLog>[],
    this.stockMappings = const <PharmacyStockMapping>[],
    this.defaultStockMapping,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? pharmacyOrderId;
  final String? drugId;
  final String? drugDisplayName;
  final String? drugCode;
  final String? drugForm;
  final String? drugStrength;
  final String? dosage;
  final num? doseAmount;
  final String? doseUnit;
  final String? frequency;
  final String? route;
  final num? durationValue;
  final String? durationUnit;
  final String? instructions;
  final String? customPrescription;
  final String? status;
  final num quantity;
  final String? quantityUnit;
  final num quantityPrescribed;
  final num quantityDispensed;
  final num quantityPending;
  final num quantityReturned;
  final num quantityRemaining;
  final List<PharmacyDispenseLog> dispenseLogs;
  final List<PharmacyStockMapping> stockMappings;
  final PharmacyStockMapping? defaultStockMapping;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get medicationLabel {
    return _firstNonEmpty(<String?>[
          drugDisplayName,
          customPrescription,
          drugCode,
          displayId,
          id,
        ]) ??
        id;
  }

  String get doseLine {
    return _joinDisplay(<String?>[
      dosage,
      _doseDisplay(doseAmount, doseUnit),
      route,
      frequency,
      _durationDisplay(durationValue, durationUnit),
    ]);
  }

  String get quantityLine {
    return _joinDisplay(<String?>[
      _quantityDisplay(quantityPrescribed, quantityUnit),
      if (quantityDispensed > 0) '${_trimNumber(quantityDispensed)} dispensed',
      if (quantityPending > 0) '${_trimNumber(quantityPending)} pending',
      if (quantityReturned > 0) '${_trimNumber(quantityReturned)} returned',
      if (quantityRemaining > 0) '${_trimNumber(quantityRemaining)} remaining',
    ]);
  }
}

@immutable
final class PharmacyStockMapping {
  const PharmacyStockMapping({
    required this.id,
    this.displayId,
    this.drugId,
    this.inventoryItemId,
    this.isDefault = false,
    this.deductionFactor = 1,
    this.inventoryItem,
  });

  final String id;
  final String? displayId;
  final String? drugId;
  final String? inventoryItemId;
  final bool isDefault;
  final num deductionFactor;
  final PharmacyInventoryItem? inventoryItem;

  String get displayTitle {
    return _firstNonEmpty(<String?>[
          inventoryItem?.name,
          inventoryItem?.sku,
          inventoryItemId,
          displayId,
          id,
        ]) ??
        id;
  }
}

@immutable
final class PharmacyInventoryItem {
  const PharmacyInventoryItem({
    required this.id,
    this.displayId,
    this.tenantId,
    this.name,
    this.category,
    this.sku,
    this.unit,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? tenantId;
  final String? name;
  final String? category;
  final String? sku;
  final String? unit;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayTitle {
    return _joinDisplay(<String?>[name, sku, unit]).isNotEmpty
        ? _joinDisplay(<String?>[name, sku, unit])
        : id;
  }
}

@immutable
final class PharmacyDispenseLog {
  const PharmacyDispenseLog({
    required this.id,
    this.displayId,
    this.pharmacyOrderItemId,
    this.dispenseBatchRef,
    this.status,
    this.quantityDispensed = 0,
    this.dispensedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? pharmacyOrderItemId;
  final String? dispenseBatchRef;
  final String? status;
  final num quantityDispensed;
  final DateTime? dispensedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

@immutable
final class PharmacyAttestation {
  const PharmacyAttestation({
    required this.id,
    this.displayId,
    this.pharmacyOrderId,
    this.dispenseBatchRef,
    this.phase,
    this.attestedByUserId,
    this.attestedRole,
    this.statement,
    this.reason,
    this.attestedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? pharmacyOrderId;
  final String? dispenseBatchRef;
  final String? phase;
  final String? attestedByUserId;
  final String? attestedRole;
  final String? statement;
  final String? reason;
  final DateTime? attestedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

@immutable
final class PharmacyTimelineItem {
  const PharmacyTimelineItem({
    required this.id,
    this.type,
    this.labelKey,
    this.labelParams = const <String, Object?>{},
    this.at,
  });

  final String id;
  final String? type;
  final String? labelKey;
  final Map<String, Object?> labelParams;
  final DateTime? at;
}

@immutable
final class PharmacyNextActions {
  const PharmacyNextActions({
    this.canPrepareDispense = false,
    this.canAttestDispense = false,
    this.canCancel = false,
    this.canReturn = false,
    this.canAdjustInventory = false,
  });

  final bool canPrepareDispense;
  final bool canAttestDispense;
  final bool canCancel;
  final bool canReturn;
  final bool canAdjustInventory;
}

@immutable
final class PharmacyOrderWorkflow {
  const PharmacyOrderWorkflow({
    required this.order,
    this.items = const <PharmacyOrderItem>[],
    this.attestations = const <PharmacyAttestation>[],
    this.timeline = const <PharmacyTimelineItem>[],
    this.nextActions = const PharmacyNextActions(),
  });

  final PharmacyOrder order;
  final List<PharmacyOrderItem> items;
  final List<PharmacyAttestation> attestations;
  final List<PharmacyTimelineItem> timeline;
  final PharmacyNextActions nextActions;
}

@immutable
final class PharmacyDrug {
  const PharmacyDrug({
    required this.id,
    this.displayId,
    this.name,
    this.code,
    this.form,
    this.strength,
    this.quantityOnHand = 0,
    this.availableQuantity = 0,
    this.stockLevel = 0,
    this.stockStatus,
    this.lowStock = false,
    this.pendingStock = false,
    this.stockMappings = const <PharmacyDrugStockMapping>[],
    this.stockRows = const <PharmacyInventoryStock>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? name;
  final String? code;
  final String? form;
  final String? strength;
  final num quantityOnHand;
  final num availableQuantity;
  final num stockLevel;
  final String? stockStatus;
  final bool lowStock;
  final bool pendingStock;
  final List<PharmacyDrugStockMapping> stockMappings;
  final List<PharmacyInventoryStock> stockRows;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayTitle {
    return _joinDisplay(<String?>[name, strength, form]).isNotEmpty
        ? _joinDisplay(<String?>[name, strength, form])
        : id;
  }
}

@immutable
final class PharmacyDrugStockMapping {
  const PharmacyDrugStockMapping({
    required this.id,
    this.displayId,
    this.inventoryItemId,
    this.isDefault = false,
    this.deductionFactor = 1,
    this.inventoryItem,
    this.stocks = const <PharmacyInventoryStock>[],
  });

  final String id;
  final String? displayId;
  final String? inventoryItemId;
  final bool isDefault;
  final num deductionFactor;
  final PharmacyInventoryItem? inventoryItem;
  final List<PharmacyInventoryStock> stocks;
}

@immutable
final class PharmacyInventoryStock {
  const PharmacyInventoryStock({
    required this.id,
    this.displayId,
    this.inventoryItemId,
    this.inventoryItem,
    this.facilityId,
    this.facilityName,
    this.quantity = 0,
    this.reorderLevel = 0,
    this.pendingStock = false,
    this.stockStatus,
    this.lowStock = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? inventoryItemId;
  final PharmacyInventoryItem? inventoryItem;
  final String? facilityId;
  final String? facilityName;
  final num quantity;
  final num reorderLevel;
  final bool pendingStock;
  final String? stockStatus;
  final bool lowStock;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

@immutable
final class PharmacyMutationResult {
  const PharmacyMutationResult({
    required this.workflow,
    this.summary,
    this.dispenseBatchRef,
  });

  final PharmacyOrderWorkflow workflow;
  final PharmacyWorkbenchSummary? summary;
  final String? dispenseBatchRef;
}

@immutable
final class PharmacyDispenseLineInput {
  const PharmacyDispenseLineInput({
    required this.orderItemId,
    required this.quantity,
    this.inventoryItemId,
    this.notes,
  });

  final String orderItemId;
  final int quantity;
  final String? inventoryItemId;
  final String? notes;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'order_item_id': orderItemId,
      'quantity': quantity,
      'inventory_item_id': inventoryItemId,
      'notes': notes,
    };
  }
}

@immutable
final class PharmacyReturnLineInput {
  const PharmacyReturnLineInput({
    required this.orderItemId,
    required this.quantity,
    this.inventoryItemId,
  });

  final String orderItemId;
  final int quantity;
  final String? inventoryItemId;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'order_item_id': orderItemId,
      'quantity': quantity,
      'inventory_item_id': inventoryItemId,
    };
  }
}

@immutable
final class PharmacyWorkspaceState {
  const PharmacyWorkspaceState({
    required this.query,
    required this.workbench,
    required this.drugQuery,
    required this.drugs,
    this.selectedWorkflow,
    this.lastFailure,
    this.isRefreshingOrders = false,
    this.isRefreshingDetail = false,
    this.isRefreshingDrugs = false,
    this.isSaving = false,
  });

  final PharmacyWorkbenchQuery query;
  final PharmacyWorkbench workbench;
  final PharmacyDrugQuery drugQuery;
  final AppPage<PharmacyDrug> drugs;
  final PharmacyOrderWorkflow? selectedWorkflow;
  final Object? lastFailure;
  final bool isRefreshingOrders;
  final bool isRefreshingDetail;
  final bool isRefreshingDrugs;
  final bool isSaving;

  int get workloadCount {
    return workbench.summary.orderedQueue +
        workbench.summary.partiallyDispensedQueue +
        workbench.summary.pendingAttestations;
  }

  PharmacyWorkspaceState copyWith({
    PharmacyWorkbenchQuery? query,
    PharmacyWorkbench? workbench,
    PharmacyDrugQuery? drugQuery,
    AppPage<PharmacyDrug>? drugs,
    PharmacyOrderWorkflow? selectedWorkflow,
    Object? lastFailure,
    bool? isRefreshingOrders,
    bool? isRefreshingDetail,
    bool? isRefreshingDrugs,
    bool? isSaving,
    bool clearSelectedWorkflow = false,
    bool clearLastFailure = false,
  }) {
    return PharmacyWorkspaceState(
      query: query ?? this.query,
      workbench: workbench ?? this.workbench,
      drugQuery: drugQuery ?? this.drugQuery,
      drugs: drugs ?? this.drugs,
      selectedWorkflow: clearSelectedWorkflow
          ? null
          : selectedWorkflow ?? this.selectedWorkflow,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshingOrders: isRefreshingOrders ?? this.isRefreshingOrders,
      isRefreshingDetail: isRefreshingDetail ?? this.isRefreshingDetail,
      isRefreshingDrugs: isRefreshingDrugs ?? this.isRefreshingDrugs,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final String? value in values) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}

String _joinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

String? _doseDisplay(num? amount, String? unit) {
  if (amount == null && (unit ?? '').trim().isEmpty) {
    return null;
  }
  return _joinDisplay(<String?>[
    amount == null ? null : _trimNumber(amount),
    unit,
  ]);
}

String? _durationDisplay(num? value, String? unit) {
  if (value == null && (unit ?? '').trim().isEmpty) {
    return null;
  }
  return _joinDisplay(<String?>[
    value == null ? null : _trimNumber(value),
    unit,
  ]);
}

String? _quantityDisplay(num value, String? unit) {
  if (value <= 0) {
    return null;
  }
  return _joinDisplay(<String?>[_trimNumber(value), unit]);
}

String _trimNumber(num value) {
  if (value is int || value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}
