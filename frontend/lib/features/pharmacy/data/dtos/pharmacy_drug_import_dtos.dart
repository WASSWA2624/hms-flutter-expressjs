import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_drug_import.dart';

typedef _Json = Map<String, Object?>;

final class PharmacyDrugImportPreviewDto {
  const PharmacyDrugImportPreviewDto(this.json);

  factory PharmacyDrugImportPreviewDto.fromResponse(Object? response) {
    return PharmacyDrugImportPreviewDto(_responseData(response));
  }

  final Map<String, Object?> json;

  PharmacyDrugImportPreview toEntity() {
    final _Json facility = _map(json['facility']);
    final _Json template = _map(json['template']);
    final _Json summary = _map(json['summary']);
    return PharmacyDrugImportPreview(
      source: _string(json['source']) ?? '',
      sourceLabel: _string(json['source_label']),
      fileName: _string(json['file_name']),
      sheetName: _string(json['sheet_name']),
      facilityId: _string(facility['id']),
      facilityName: _string(facility['name']),
      template: PharmacyDrugImportTemplate(
        columns: _strings(template['columns']),
        missingColumns: _strings(template['missing_columns']),
        unexpectedColumns: _strings(template['unexpected_columns']),
      ),
      canWritePricing: json['can_write_pricing'] == true,
      canCommit: json['can_commit'] == true,
      planHash: _string(json['plan_hash']),
      summary: PharmacyDrugImportSummary(
        totalRows: _int(summary['total_rows']),
        validRows: _int(summary['valid_rows']),
        errorRows: _int(summary['error_rows']),
        duplicateRows: _int(summary['duplicate_rows']),
        products: _int(summary['products']),
        newProducts: _int(summary['new_products']),
        existingProducts: _int(summary['existing_products']),
        similarProducts: _int(summary['similar_products']),
        batches: _int(summary['batches']),
        totalQuantity: _int(summary['total_quantity']),
        errors: _int(summary['errors']),
        warnings: _int(summary['warnings']),
        stockedNotInFile: _int(summary['stocked_not_in_file']),
      ),
      products: _list(json['products']).map(_product).toList(growable: false),
      issues: _list(json['issues']).map(_issue).toList(growable: false),
      stockedDrugs: _list(json['stocked_drugs']).map(_drug).toList(growable: false),
    );
  }
}

final class PharmacyDrugImportResultDto {
  const PharmacyDrugImportResultDto(this.json);

  factory PharmacyDrugImportResultDto.fromResponse(Object? response) {
    return PharmacyDrugImportResultDto(_responseData(response));
  }

  final Map<String, Object?> json;

  PharmacyDrugImportResult toEntity() {
    final _Json summary = _map(json['summary']);
    return PharmacyDrugImportResult(
      importId: _string(json['import_id']),
      facilityName: _string(_map(json['facility'])['name']),
      stockMode: PharmacyDrugImportStockMode.fromApi(_string(json['stock_mode'])),
      created: _int(summary['created']),
      merged: _int(summary['merged']),
      updated: _int(summary['updated']),
      skipped: _int(summary['skipped']),
      suppliersCreated: _int(summary['suppliers_created']),
      batchesCreated: _int(summary['batches_created']),
      batchesUpdated: _int(summary['batches_updated']),
      batchesCleared: _int(summary['batches_cleared']),
      stockRowsCreated: _int(summary['stock_rows_created']),
      stockRowsAdjusted: _int(summary['stock_rows_adjusted']),
      stockCleared: _int(summary['stock_cleared']),
      quantityImported: _int(summary['quantity_imported']),
    );
  }
}

PharmacyDrugImportProduct _product(_Json json) {
  final _Json match = _map(json['match']);
  final List<PharmacyDrugImportAction> allowedActions = _strings(
    json['allowed_actions'],
  ).map(PharmacyDrugImportAction.fromApi).whereType<PharmacyDrugImportAction>().toList(
    growable: false,
  );
  return PharmacyDrugImportProduct(
    key: _rawString(json['key']) ?? '',
    name: _string(json['name']) ?? '',
    brandName: _string(json['brand_name']),
    form: _string(json['form']),
    strength: _string(json['strength']),
    unitPrice: _number(json['unit_price']),
    buyUnitPrice: _number(json['buy_unit_price']),
    supplierName: _string(json['supplier_name']),
    rowNumbers: _ints(json['row_numbers']),
    totalQuantity: _int(json['total_quantity']),
    batches: _list(json['batches'])
        .map(
          (_Json batch) => PharmacyDrugImportBatch(
            key: _rawString(batch['key']),
            batchNumber: _string(batch['batch_number']),
            expiryDate: _date(batch['expiry_date']),
            quantity: _int(batch['quantity']),
            rowNumbers: _ints(batch['row_numbers']),
          ),
        )
        .toList(growable: false),
    status: PharmacyDrugImportStatus.fromApi(_string(json['status'])),
    allowedActions: allowedActions,
    defaultAction:
        PharmacyDrugImportAction.fromApi(_string(json['default_action'])) ??
        (allowedActions.isEmpty ? PharmacyDrugImportAction.skip : allowedActions.first),
    defaultTargetDrugId: _string(json['default_target_drug_id']),
    requiresReview: json['requires_review'] == true,
    match: match.isEmpty
        ? null
        : PharmacyDrugImportCandidate(
            drug: _drug(_map(match['drug'])),
            changes: _list(match['changes']).map(_change).toList(growable: false),
          ),
    candidates: _list(json['candidates'])
        .map(
          (_Json candidate) => PharmacyDrugImportCandidate(
            drug: _drug(_map(candidate['drug'])),
            score: _intOrNull(candidate['score']),
            reasons: _strings(candidate['reasons']),
            changes: _list(candidate['changes']).map(_change).toList(growable: false),
          ),
        )
        .toList(growable: false),
    issues: _list(json['issues']).map(_issue).toList(growable: false),
  );
}

PharmacyDrugImportDrug _drug(_Json json) {
  return PharmacyDrugImportDrug(
    id: _string(json['id']) ?? '',
    name: _string(json['name']),
    genericName: _string(json['generic_name']),
    brandName: _string(json['brand_name']),
    code: _string(json['code']),
    form: _string(json['form']),
    strength: _string(json['strength']),
    unitPrice: _number(json['unit_price']),
    buyUnitPrice: _number(json['buy_unit_price']),
    supplierName: _string(json['supplier_name']),
    facilityQuantity: _int(json['facility_quantity']),
  );
}

PharmacyDrugImportChange _change(_Json json) {
  return PharmacyDrugImportChange(
    field: _string(json['field']) ?? '',
    currentValue: json['current_value'],
    incomingValue: json['incoming_value'],
    fillsBlank: json['fills_blank'] == true,
  );
}

PharmacyDrugImportIssue _issue(_Json json) {
  return PharmacyDrugImportIssue(
    severity: PharmacyDrugImportIssueSeverity.fromApi(_string(json['severity'])),
    code: _string(json['code']) ?? '',
    rowNumber: _intOrNull(json['row_number']),
    productKey: _rawString(json['product_key']),
    field: _string(json['field']),
    params: _map(json['params']),
  );
}

_Json _responseData(Object? response) {
  if (response is! _Json) {
    throw const FormatException('Expected drug import response object.');
  }
  return _map(response['data']);
}

_Json _map(Object? value) => value is _Json ? value : const <String, Object?>{};

List<_Json> _list(Object? value) {
  if (value is! List) {
    return const <_Json>[];
  }
  return value.whereType<_Json>().toList(growable: false);
}

/// Keeps the exact server value; product keys must round-trip unchanged.
String? _rawString(Object? value) => value is String ? value : null;

String? _string(Object? value) {
  if (value == null) {
    return null;
  }
  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

num? _number(Object? value) {
  if (value is num) {
    return value;
  }
  return value is String ? num.tryParse(value) : null;
}

int? _intOrNull(Object? value) => _number(value)?.toInt();

int _int(Object? value) => _intOrNull(value) ?? 0;

DateTime? _date(Object? value) {
  final String? normalized = _string(value);
  return normalized == null ? null : DateTime.tryParse(normalized);
}

List<String> _strings(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.map(_string).whereType<String>().toList(growable: false);
}

List<int> _ints(Object? value) {
  if (value is! List) {
    return const <int>[];
  }
  return value.map(_intOrNull).whereType<int>().toList(growable: false);
}
