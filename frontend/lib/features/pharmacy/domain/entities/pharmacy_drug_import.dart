import 'dart:convert';

import 'package:flutter/foundation.dart';

/// External systems whose drug stock exports can be imported into the catalog.
enum PharmacyDrugImportSource {
  medicErp('MEDIC_ERP', <String>[
    'product_name',
    'product_brand',
    'quantity',
    'available_quantity',
    'internal_quantity',
    'retail_price',
    'retail_price_max',
    'wholesale_price',
    'wholesale_price_max',
    'batch_number',
    'expiry_date',
    'cost',
    'invoice_number',
    'employee',
    'created_on',
    'updated_on',
    'supplier',
  ]);

  const PharmacyDrugImportSource(this.apiValue, this.templateColumns);

  final String apiValue;

  /// Header names the first sheet row of the export must contain.
  final List<String> templateColumns;
}

/// How an imported product relates to the tenant catalog.
enum PharmacyDrugImportStatus {
  newProduct('NEW'),
  existing('EXISTING'),
  similar('SIMILAR');

  const PharmacyDrugImportStatus(this.apiValue);

  final String apiValue;

  static PharmacyDrugImportStatus fromApi(String? value) {
    return PharmacyDrugImportStatus.values.firstWhere(
      (PharmacyDrugImportStatus status) => status.apiValue == value,
      orElse: () => PharmacyDrugImportStatus.newProduct,
    );
  }
}

enum PharmacyDrugImportAction {
  create('CREATE'),
  merge('MERGE'),
  update('UPDATE'),
  skip('SKIP');

  const PharmacyDrugImportAction(this.apiValue);

  final String apiValue;

  /// Merge and update link the product to an existing catalog drug.
  bool get linksExistingDrug =>
      this == PharmacyDrugImportAction.merge ||
      this == PharmacyDrugImportAction.update;

  static PharmacyDrugImportAction? fromApi(String? value) {
    for (final PharmacyDrugImportAction action in PharmacyDrugImportAction.values) {
      if (action.apiValue == value) {
        return action;
      }
    }
    return null;
  }
}

enum PharmacyDrugImportStockMode {
  /// Facility stock and matching batches become the file quantities.
  replace('REPLACE'),

  /// File quantities are added to current facility stock.
  add('ADD');

  const PharmacyDrugImportStockMode(this.apiValue);

  final String apiValue;

  static PharmacyDrugImportStockMode fromApi(String? value) {
    return value == PharmacyDrugImportStockMode.add.apiValue
        ? PharmacyDrugImportStockMode.add
        : PharmacyDrugImportStockMode.replace;
  }
}

enum PharmacyDrugImportIssueSeverity {
  error,
  warning,
  info;

  static PharmacyDrugImportIssueSeverity fromApi(String? value) {
    return switch (value) {
      'error' => PharmacyDrugImportIssueSeverity.error,
      'warning' => PharmacyDrugImportIssueSeverity.warning,
      _ => PharmacyDrugImportIssueSeverity.info,
    };
  }
}

@immutable
final class PharmacyDrugImportIssue {
  const PharmacyDrugImportIssue({
    required this.severity,
    required this.code,
    this.rowNumber,
    this.productKey,
    this.field,
    this.params = const <String, Object?>{},
  });

  final PharmacyDrugImportIssueSeverity severity;

  /// Stable issue code, e.g. `PRICE_BELOW_COST`.
  final String code;

  /// Spreadsheet row; null for product-level issues.
  final int? rowNumber;
  final String? productKey;

  /// Source column (row issues) or catalog field (product issues).
  final String? field;
  final Map<String, Object?> params;
}

/// Catalog drug as shown in an import review.
@immutable
final class PharmacyDrugImportDrug {
  const PharmacyDrugImportDrug({
    required this.id,
    this.name,
    this.genericName,
    this.brandName,
    this.code,
    this.form,
    this.strength,
    this.unitPrice,
    this.buyUnitPrice,
    this.supplierName,
    this.facilityQuantity = 0,
  });

  final String id;
  final String? name;
  final String? genericName;
  final String? brandName;
  final String? code;
  final String? form;
  final String? strength;
  final num? unitPrice;
  final num? buyUnitPrice;
  final String? supplierName;

  /// On-hand quantity at the importing facility.
  final int facilityQuantity;

  String get displayName {
    final String base = (genericName ?? name ?? id).trim();
    final String brand = (brandName ?? '').trim();
    return brand.isEmpty ? base : '$base · $brand';
  }
}

@immutable
final class PharmacyDrugImportChange {
  const PharmacyDrugImportChange({
    required this.field,
    this.currentValue,
    this.incomingValue,
    this.fillsBlank = false,
  });

  /// Catalog field: brand_name, form, strength, unit_price, buy_unit_price, supplier_name.
  final String field;
  final Object? currentValue;
  final Object? incomingValue;

  /// True when the catalog value is empty, so a merge would also apply it.
  final bool fillsBlank;
}

@immutable
final class PharmacyDrugImportCandidate {
  const PharmacyDrugImportCandidate({
    required this.drug,
    this.score,
    this.reasons = const <String>[],
    this.changes = const <PharmacyDrugImportChange>[],
  });

  final PharmacyDrugImportDrug drug;

  /// Similarity score (0-100); null for the exact catalog match.
  final int? score;
  final List<String> reasons;
  final List<PharmacyDrugImportChange> changes;
}

@immutable
final class PharmacyDrugImportBatch {
  const PharmacyDrugImportBatch({
    this.batchNumber,
    this.expiryDate,
    this.quantity = 0,
    this.rowNumbers = const <int>[],
  });

  final String? batchNumber;
  final DateTime? expiryDate;
  final int quantity;
  final List<int> rowNumbers;
}

/// One catalog product built from one or more file rows (same name and brand).
@immutable
final class PharmacyDrugImportProduct {
  const PharmacyDrugImportProduct({
    required this.key,
    required this.name,
    required this.status,
    required this.defaultAction,
    this.brandName,
    this.form,
    this.strength,
    this.unitPrice,
    this.buyUnitPrice,
    this.supplierName,
    this.rowNumbers = const <int>[],
    this.totalQuantity = 0,
    this.batches = const <PharmacyDrugImportBatch>[],
    this.allowedActions = const <PharmacyDrugImportAction>[],
    this.defaultTargetDrugId,
    this.requiresReview = false,
    this.match,
    this.candidates = const <PharmacyDrugImportCandidate>[],
    this.issues = const <PharmacyDrugImportIssue>[],
  });

  /// Server grouping key; decisions must echo it unchanged.
  final String key;
  final String name;
  final String? brandName;
  final String? form;
  final String? strength;
  final num? unitPrice;
  final num? buyUnitPrice;
  final String? supplierName;
  final List<int> rowNumbers;
  final int totalQuantity;
  final List<PharmacyDrugImportBatch> batches;
  final PharmacyDrugImportStatus status;
  final List<PharmacyDrugImportAction> allowedActions;
  final PharmacyDrugImportAction defaultAction;
  final String? defaultTargetDrugId;
  final bool requiresReview;

  /// Exact catalog match (status [PharmacyDrugImportStatus.existing]).
  final PharmacyDrugImportCandidate? match;

  /// Similar catalog drugs (status [PharmacyDrugImportStatus.similar]).
  final List<PharmacyDrugImportCandidate> candidates;
  final List<PharmacyDrugImportIssue> issues;

  String get displayName {
    final String brand = (brandName ?? '').trim();
    return brand.isEmpty ? name : '$name · $brand';
  }

  /// Catalog drugs a merge or update decision may link to.
  List<PharmacyDrugImportCandidate> get linkOptions =>
      match != null ? <PharmacyDrugImportCandidate>[match!] : candidates;

  PharmacyDrugImportCandidate? linkOptionFor(String? drugId) {
    for (final PharmacyDrugImportCandidate option in linkOptions) {
      if (option.drug.id == drugId) {
        return option;
      }
    }
    return null;
  }
}

@immutable
final class PharmacyDrugImportSummary {
  const PharmacyDrugImportSummary({
    this.totalRows = 0,
    this.validRows = 0,
    this.errorRows = 0,
    this.duplicateRows = 0,
    this.products = 0,
    this.newProducts = 0,
    this.existingProducts = 0,
    this.similarProducts = 0,
    this.batches = 0,
    this.totalQuantity = 0,
    this.errors = 0,
    this.warnings = 0,
    this.stockedNotInFile = 0,
  });

  final int totalRows;
  final int validRows;
  final int errorRows;
  final int duplicateRows;
  final int products;
  final int newProducts;
  final int existingProducts;
  final int similarProducts;
  final int batches;
  final int totalQuantity;
  final int errors;
  final int warnings;
  final int stockedNotInFile;
}

@immutable
final class PharmacyDrugImportTemplate {
  const PharmacyDrugImportTemplate({
    this.columns = const <String>[],
    this.missingColumns = const <String>[],
    this.unexpectedColumns = const <String>[],
  });

  final List<String> columns;
  final List<String> missingColumns;
  final List<String> unexpectedColumns;

  bool get isValid => missingColumns.isEmpty;
}

/// Server analysis of an import file; nothing has been saved yet.
@immutable
final class PharmacyDrugImportPreview {
  const PharmacyDrugImportPreview({
    required this.source,
    this.sourceLabel,
    this.fileName,
    this.sheetName,
    this.facilityId,
    this.facilityName,
    this.template = const PharmacyDrugImportTemplate(),
    this.canWritePricing = false,
    this.canCommit = false,
    this.planHash,
    this.summary = const PharmacyDrugImportSummary(),
    this.products = const <PharmacyDrugImportProduct>[],
    this.issues = const <PharmacyDrugImportIssue>[],
    this.stockedDrugs = const <PharmacyDrugImportDrug>[],
  });

  final String source;
  final String? sourceLabel;
  final String? fileName;
  final String? sheetName;
  final String? facilityId;
  final String? facilityName;
  final PharmacyDrugImportTemplate template;
  final bool canWritePricing;
  final bool canCommit;

  /// Commit must send this back; the server rejects it if the catalog changed.
  final String? planHash;
  final PharmacyDrugImportSummary summary;
  final List<PharmacyDrugImportProduct> products;

  /// Row-level issues (product-level issues live on each product).
  final List<PharmacyDrugImportIssue> issues;

  /// Drugs stocked at the facility that no product matched exactly.
  final List<PharmacyDrugImportDrug> stockedDrugs;
}

@immutable
final class PharmacyDrugImportFile {
  const PharmacyDrugImportFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

@immutable
final class PharmacyDrugImportDecision {
  const PharmacyDrugImportDecision({
    required this.key,
    required this.action,
    this.targetDrugId,
  });

  final String key;
  final PharmacyDrugImportAction action;
  final String? targetDrugId;

  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'action': action.apiValue,
    if (action.linksExistingDrug && targetDrugId != null)
      'target_drug_id': targetDrugId,
  };
}

@immutable
final class PharmacyDrugImportCommitInput {
  const PharmacyDrugImportCommitInput({
    required this.source,
    required this.file,
    required this.planHash,
    required this.decisions,
    this.stockMode = PharmacyDrugImportStockMode.replace,
    this.clearMissingStock = false,
    this.confirmReview = false,
    this.currency,
  });

  final PharmacyDrugImportSource source;

  /// The same file that was previewed; the server re-analyzes it.
  final PharmacyDrugImportFile file;
  final String planHash;
  final List<PharmacyDrugImportDecision> decisions;
  final PharmacyDrugImportStockMode stockMode;
  final bool clearMissingStock;
  final bool confirmReview;
  final String? currency;

  /// Multipart form fields; the file is attached separately.
  Map<String, Object?> toFormFields() => <String, Object?>{
    'source': source.apiValue,
    'plan_hash': planHash,
    'decisions': jsonEncode(
      decisions
          .map((PharmacyDrugImportDecision decision) => decision.toJson())
          .toList(growable: false),
    ),
    'stock_mode': stockMode.apiValue,
    'clear_missing_stock': clearMissingStock.toString(),
    'confirm_review': confirmReview.toString(),
    if (currency != null && currency!.trim().isNotEmpty)
      'currency': currency!.trim(),
  };
}

@immutable
final class PharmacyDrugImportResult {
  const PharmacyDrugImportResult({
    this.importId,
    this.facilityName,
    this.stockMode = PharmacyDrugImportStockMode.replace,
    this.created = 0,
    this.merged = 0,
    this.updated = 0,
    this.skipped = 0,
    this.suppliersCreated = 0,
    this.batchesCreated = 0,
    this.batchesUpdated = 0,
    this.batchesCleared = 0,
    this.stockRowsCreated = 0,
    this.stockRowsAdjusted = 0,
    this.stockCleared = 0,
    this.quantityImported = 0,
  });

  final String? importId;
  final String? facilityName;
  final PharmacyDrugImportStockMode stockMode;
  final int created;
  final int merged;
  final int updated;
  final int skipped;
  final int suppliersCreated;
  final int batchesCreated;
  final int batchesUpdated;
  final int batchesCleared;
  final int stockRowsCreated;
  final int stockRowsAdjusted;
  final int stockCleared;
  final int quantityImported;

  int get importedProducts => created + merged + updated;
}
