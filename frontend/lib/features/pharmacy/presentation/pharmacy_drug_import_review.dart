import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_drug_import.dart';

/// Largest price the catalog stores (DECIMAL(12, 2)).
const double pharmacyDrugImportMaxPrice = 9999999999.99;

/// Largest quantity a batch or stock row stores.
const int pharmacyDrugImportMaxQuantity = 2147483647;

const int pharmacyDrugImportMaxBatchNumberLength = 80;

final RegExp _decimalPattern = RegExp(r'^[-+]?(\d+\.?\d*|\.\d+)$');
final RegExp _wholeNumberPattern = RegExp(r'^\d+$');
final RegExp _groupingPattern = RegExp(r'[\s,]');
final RegExp _nonWordPattern = RegExp(r'[^a-z0-9\s]');
final RegExp _whitespacePattern = RegExp(r'\s+');
final RegExp _trailingZerosPattern = RegExp(r'\.?0+$');

/// Why a reviewer-edited value cannot be imported.
enum PharmacyDrugImportValueProblem {
  required,
  tooLong,
  invalidNumber,
  negative,
  tooLarge,
  invalidQuantity,
  duplicateBatch,
  duplicateProduct,
}

/// What saving a value does to the linked catalog drug.
enum PharmacyDrugImportFieldOutcome { noChange, fillsBlank, replaces, clears }

typedef PharmacyDrugImportParsedPrice = ({
  num? value,
  PharmacyDrugImportValueProblem? problem,
});

/// Parses a typed price; empty text means no price.
PharmacyDrugImportParsedPrice parsePharmacyDrugImportPrice(String text) {
  final String normalized = text.replaceAll(_groupingPattern, '');
  if (normalized.isEmpty) {
    return (value: null, problem: null);
  }
  final num? value = _decimalPattern.hasMatch(normalized)
      ? num.tryParse(normalized)
      : null;
  if (value == null) {
    return (value: null, problem: PharmacyDrugImportValueProblem.invalidNumber);
  }
  if (value < 0) {
    return (value: null, problem: PharmacyDrugImportValueProblem.negative);
  }
  if (value > pharmacyDrugImportMaxPrice) {
    return (value: null, problem: PharmacyDrugImportValueProblem.tooLarge);
  }
  return (
    value: value is int ? value : (value * 100).round() / 100,
    problem: null,
  );
}

/// Parses a typed whole quantity; null when it is not a whole number in range.
int? parsePharmacyDrugImportQuantity(String text) {
  final String normalized = text.replaceAll(_groupingPattern, '');
  if (!_wholeNumberPattern.hasMatch(normalized)) {
    return null;
  }
  final int? value = int.tryParse(normalized);
  return value == null || value > pharmacyDrugImportMaxQuantity ? null : value;
}

/// Mirrors the server text normalization behind product keys.
String pharmacyDrugImportNormalizeText(String? value) => (value ?? '')
    .toLowerCase()
    .trim()
    .replaceAll(_nonWordPattern, '')
    .replaceAll(_whitespacePattern, ' ');

/// Editable text for a number, without grouping separators.
String pharmacyDrugImportPlainNumber(num? value) {
  if (value == null) {
    return '';
  }
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2).replaceFirst(_trailingZerosPattern, '');
}

String? _textOrNull(String text) {
  final String trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool _sameDay(DateTime? left, DateTime? right) {
  if (left == null || right == null) {
    return left == right;
  }
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

/// Reviewer values for one batch, kept as typed.
@immutable
final class PharmacyDrugImportBatchDraft {
  const PharmacyDrugImportBatchDraft({
    required this.batchNumber,
    required this.quantity,
    this.expiryDate,
  });

  factory PharmacyDrugImportBatchDraft.fromBatch(
    PharmacyDrugImportBatch batch,
  ) {
    return PharmacyDrugImportBatchDraft(
      batchNumber: batch.batchNumber ?? '',
      expiryDate: batch.expiryDate,
      quantity: '${batch.quantity}',
    );
  }

  final String batchNumber;
  final DateTime? expiryDate;
  final String quantity;

  PharmacyDrugImportBatchDraft copyWith({
    String? batchNumber,
    String? quantity,
    DateTime? Function()? expiryDate,
  }) {
    return PharmacyDrugImportBatchDraft(
      batchNumber: batchNumber ?? this.batchNumber,
      quantity: quantity ?? this.quantity,
      expiryDate: expiryDate == null ? this.expiryDate : expiryDate(),
    );
  }

  /// True when every value still matches [batch] as read from the file.
  bool matches(PharmacyDrugImportBatch batch) {
    return batchNumber.trim() == (batch.batchNumber ?? '') &&
        _sameDay(expiryDate, batch.expiryDate) &&
        parsePharmacyDrugImportQuantity(quantity) == batch.quantity;
  }
}

/// Reviewer edits for one import product.
///
/// Only changed values are stored; everything else follows the suggestion for
/// the chosen action (see [PharmacyDrugImportProductReview.suggestedText]).
@immutable
final class PharmacyDrugImportProductDraft {
  const PharmacyDrugImportProductDraft({
    this.fields = const <PharmacyDrugImportField, String>{},
    this.batches = const <String, PharmacyDrugImportBatchDraft>{},
  });

  static const PharmacyDrugImportProductDraft empty =
      PharmacyDrugImportProductDraft();

  /// Typed text per edited field.
  final Map<PharmacyDrugImportField, String> fields;

  /// Edited batches by [PharmacyDrugImportBatch.key].
  final Map<String, PharmacyDrugImportBatchDraft> batches;

  bool get isEmpty => fields.isEmpty && batches.isEmpty;

  /// Sets or, with null [text], forgets the edit for [field].
  PharmacyDrugImportProductDraft withField(
    PharmacyDrugImportField field,
    String? text,
  ) {
    final Map<PharmacyDrugImportField, String> next =
        Map<PharmacyDrugImportField, String>.of(fields);
    if (text == null) {
      next.remove(field);
    } else {
      next[field] = text;
    }
    return PharmacyDrugImportProductDraft(
      fields: Map<PharmacyDrugImportField, String>.unmodifiable(next),
      batches: batches,
    );
  }

  /// Sets or, with a null [draft], forgets the edit for batch [key].
  PharmacyDrugImportProductDraft withBatch(
    String key,
    PharmacyDrugImportBatchDraft? draft,
  ) {
    final Map<String, PharmacyDrugImportBatchDraft> next =
        Map<String, PharmacyDrugImportBatchDraft>.of(batches);
    if (draft == null) {
      next.remove(key);
    } else {
      next[key] = draft;
    }
    return PharmacyDrugImportProductDraft(
      fields: fields,
      batches: Map<String, PharmacyDrugImportBatchDraft>.unmodifiable(next),
    );
  }
}

/// Review state of one product for a chosen action, link target, and edits.
///
/// Suggestions mirror what the server saves when a value is left unchanged:
/// merging keeps catalog values and fills empty ones from the file, updating
/// takes file values and keeps catalog values the file leaves empty. Edited
/// values are sent as typed and always win.
@immutable
final class PharmacyDrugImportProductReview {
  PharmacyDrugImportProductReview({
    required this.product,
    required this.action,
    required this.draft,
    required this.canWritePricing,
    PharmacyDrugImportCandidate? target,
  }) : target = action.linksExistingDrug ? target : null;

  final PharmacyDrugImportProduct product;
  final PharmacyDrugImportAction action;
  final PharmacyDrugImportProductDraft draft;
  final bool canWritePricing;

  /// Catalog drug the product links to; null unless the action links.
  final PharmacyDrugImportCandidate? target;

  bool get isSkipped => action == PharmacyDrugImportAction.skip;

  bool get isLinked => target != null;

  /// Fields shown for review; prices need pricing permission.
  List<PharmacyDrugImportField> get fields => <PharmacyDrugImportField>[
    for (final PharmacyDrugImportField field in PharmacyDrugImportField.values)
      if (!field.isPrice || canWritePricing) field,
  ];

  /// Whether the reviewer can change [field] for the current action.
  ///
  /// Linking never renames a catalog drug, so the name is only editable for
  /// new drugs.
  bool isEditable(PharmacyDrugImportField field) {
    return !isSkipped &&
        (!field.isPrice || canWritePricing) &&
        (field != PharmacyDrugImportField.name ||
            action == PharmacyDrugImportAction.create);
  }

  String fileText(PharmacyDrugImportField field) {
    return switch (field) {
      PharmacyDrugImportField.name => product.name,
      PharmacyDrugImportField.brandName => product.brandName ?? '',
      PharmacyDrugImportField.form => product.form ?? '',
      PharmacyDrugImportField.strength => product.strength ?? '',
      PharmacyDrugImportField.unitPrice => pharmacyDrugImportPlainNumber(
        product.unitPrice,
      ),
      PharmacyDrugImportField.buyUnitPrice => pharmacyDrugImportPlainNumber(
        product.buyUnitPrice,
      ),
      PharmacyDrugImportField.supplierName => product.supplierName ?? '',
    };
  }

  /// Value of the linked catalog drug; null when the product is not linked.
  String? catalogText(PharmacyDrugImportField field) {
    final PharmacyDrugImportDrug? drug = target?.drug;
    if (drug == null) {
      return null;
    }
    return switch (field) {
      PharmacyDrugImportField.name => drug.genericName ?? drug.name ?? '',
      PharmacyDrugImportField.brandName => drug.brandName ?? '',
      PharmacyDrugImportField.form => drug.form ?? '',
      PharmacyDrugImportField.strength => drug.strength ?? '',
      PharmacyDrugImportField.unitPrice => pharmacyDrugImportPlainNumber(
        drug.unitPrice,
      ),
      PharmacyDrugImportField.buyUnitPrice => pharmacyDrugImportPlainNumber(
        drug.buyUnitPrice,
      ),
      PharmacyDrugImportField.supplierName => drug.supplierName ?? '',
    };
  }

  /// Value saved when the reviewer leaves [field] unchanged.
  String suggestedText(PharmacyDrugImportField field) {
    final String file = fileText(field);
    final String? catalog = catalogText(field);
    if (catalog == null) {
      return file;
    }
    if (field == PharmacyDrugImportField.name) {
      return catalog;
    }
    return action == PharmacyDrugImportAction.merge
        ? (catalog.trim().isEmpty ? file : catalog)
        : (file.trim().isEmpty ? catalog : file);
  }

  bool isEdited(PharmacyDrugImportField field) {
    return isEditable(field) && draft.fields.containsKey(field);
  }

  /// Value that will be saved for [field].
  String valueText(PharmacyDrugImportField field) {
    return isEdited(field) ? draft.fields[field]! : suggestedText(field);
  }

  PharmacyDrugImportValueProblem? fieldProblem(PharmacyDrugImportField field) {
    if (!isEdited(field)) {
      return null;
    }
    final String text = draft.fields[field]!;
    if (field.isPrice) {
      return parsePharmacyDrugImportPrice(text).problem;
    }
    final String trimmed = text.trim();
    if (field == PharmacyDrugImportField.name && trimmed.isEmpty) {
      return PharmacyDrugImportValueProblem.required;
    }
    final int? maxLength = field.maxLength;
    return maxLength != null && trimmed.length > maxLength
        ? PharmacyDrugImportValueProblem.tooLong
        : null;
  }

  /// Effect on the linked catalog drug; null when not linked or invalid.
  PharmacyDrugImportFieldOutcome? outcome(PharmacyDrugImportField field) {
    final String? current = catalogText(field);
    if (current == null || fieldProblem(field) != null) {
      return null;
    }
    final String next = valueText(field);
    final bool same = switch (field) {
      PharmacyDrugImportField.unitPrice ||
      PharmacyDrugImportField.buyUnitPrice =>
        parsePharmacyDrugImportPrice(current).value ==
            parsePharmacyDrugImportPrice(next).value,
      PharmacyDrugImportField.form || PharmacyDrugImportField.strength =>
        _compact(current) == _compact(next),
      _ =>
        pharmacyDrugImportNormalizeText(current) ==
            pharmacyDrugImportNormalizeText(next),
    };
    if (same) {
      return PharmacyDrugImportFieldOutcome.noChange;
    }
    if (current.trim().isEmpty) {
      return PharmacyDrugImportFieldOutcome.fillsBlank;
    }
    return next.trim().isEmpty
        ? PharmacyDrugImportFieldOutcome.clears
        : PharmacyDrugImportFieldOutcome.replaces;
  }

  PharmacyDrugImportBatchDraft batchValue(PharmacyDrugImportBatch batch) {
    return draft.batches[batch.key] ??
        PharmacyDrugImportBatchDraft.fromBatch(batch);
  }

  bool isBatchEdited(PharmacyDrugImportBatch batch) {
    return !isSkipped && draft.batches.containsKey(batch.key);
  }

  late final Set<String> _clashingBatchKeys = () {
    final Map<String, int> counts = <String, int>{};
    for (final PharmacyDrugImportBatch batch in product.batches) {
      final String key = PharmacyDrugImportBatch.keyFor(
        batchValue(batch).batchNumber,
      );
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return <String>{
      for (final MapEntry<String, int> entry in counts.entries)
        if (entry.value > 1) entry.key,
    };
  }();

  PharmacyDrugImportValueProblem? batchNumberProblem(
    PharmacyDrugImportBatch batch,
  ) {
    if (isSkipped) {
      return null;
    }
    final String batchNumber = batchValue(batch).batchNumber.trim();
    if (batchNumber.length > pharmacyDrugImportMaxBatchNumberLength) {
      return PharmacyDrugImportValueProblem.tooLong;
    }
    return _clashingBatchKeys.contains(
          PharmacyDrugImportBatch.keyFor(batchNumber),
        )
        ? PharmacyDrugImportValueProblem.duplicateBatch
        : null;
  }

  PharmacyDrugImportValueProblem? quantityProblem(
    PharmacyDrugImportBatch batch,
  ) {
    if (isSkipped) {
      return null;
    }
    return parsePharmacyDrugImportQuantity(batchValue(batch).quantity) == null
        ? PharmacyDrugImportValueProblem.invalidQuantity
        : null;
  }

  /// Units the product brings in, using edited batch quantities.
  int get totalQuantity {
    if (product.batches.isEmpty) {
      return product.totalQuantity;
    }
    return product.batches.fold<int>(
      0,
      (int total, PharmacyDrugImportBatch batch) =>
          total +
          (parsePharmacyDrugImportQuantity(batchValue(batch).quantity) ?? 0),
    );
  }

  bool get hasEdits {
    return !isSkipped &&
        (draft.fields.keys.any(isEditable) || draft.batches.isNotEmpty);
  }

  bool get hasProblems {
    return fields.any(
          (PharmacyDrugImportField field) => fieldProblem(field) != null,
        ) ||
        product.batches.any(
          (PharmacyDrugImportBatch batch) =>
              batchNumberProblem(batch) != null ||
              quantityProblem(batch) != null,
        );
  }

  /// Whether a new drug gets a different name or brand than the file.
  bool get renamesProduct {
    return action == PharmacyDrugImportAction.create &&
        (isEdited(PharmacyDrugImportField.name) ||
            isEdited(PharmacyDrugImportField.brandName));
  }

  /// Name and brand identity, normalized the way the server groups products.
  String get identityKey {
    if (!renamesProduct) {
      return product.key;
    }
    return '${pharmacyDrugImportNormalizeText(valueText(PharmacyDrugImportField.name))}'
        '|${pharmacyDrugImportNormalizeText(valueText(PharmacyDrugImportField.brandName))}';
  }

  PharmacyDrugImportDecision toDecision() {
    if (isSkipped) {
      return PharmacyDrugImportDecision(key: product.key, action: action);
    }
    return PharmacyDrugImportDecision(
      key: product.key,
      action: action,
      targetDrugId: target?.drug.id,
      values: <PharmacyDrugImportField, Object?>{
        for (final MapEntry<PharmacyDrugImportField, String> entry
            in draft.fields.entries)
          if (isEditable(entry.key))
            entry.key: entry.key.isPrice
                ? parsePharmacyDrugImportPrice(entry.value).value
                : _textOrNull(entry.value),
      },
      batches: <PharmacyDrugImportBatchEdit>[
        for (final PharmacyDrugImportBatch batch in product.batches)
          if (draft.batches[batch.key]
              case final PharmacyDrugImportBatchDraft edited)
            PharmacyDrugImportBatchEdit(
              key: batch.key,
              batchNumber: _textOrNull(edited.batchNumber),
              expiryDate: edited.expiryDate,
              quantity:
                  parsePharmacyDrugImportQuantity(edited.quantity) ??
                  batch.quantity,
            ),
      ],
    );
  }

  static String _compact(String value) =>
      pharmacyDrugImportNormalizeText(value).replaceAll(' ', '');
}
