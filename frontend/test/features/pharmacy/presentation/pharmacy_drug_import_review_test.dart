import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_drug_import.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_drug_import_review.dart';

const PharmacyDrugImportDrug _catalogDrug = PharmacyDrugImportDrug(
  id: 'DRG0000050',
  name: 'AZITHROMYCIN 500MG TABLET',
  brandName: 'ZAHA',
  form: 'Tablet',
  unitPrice: 6000,
  facilityQuantity: 10,
);

final PharmacyDrugImportProduct _existing = PharmacyDrugImportProduct(
  key: 'azithromycin 500mg tablet|zaha',
  name: 'AZITHROMYCIN 500MG TABLET',
  brandName: 'Zaha',
  form: 'Capsule',
  strength: '500 mg',
  unitPrice: 7000,
  buyUnitPrice: 4300,
  status: PharmacyDrugImportStatus.existing,
  defaultAction: PharmacyDrugImportAction.merge,
  allowedActions: const <PharmacyDrugImportAction>[
    PharmacyDrugImportAction.merge,
    PharmacyDrugImportAction.update,
    PharmacyDrugImportAction.skip,
  ],
  totalQuantity: 9,
  batches: <PharmacyDrugImportBatch>[
    const PharmacyDrugImportBatch(key: 'PA1', batchNumber: 'PA1', quantity: 4),
    PharmacyDrugImportBatch(
      key: 'PA2',
      batchNumber: 'PA2',
      expiryDate: DateTime(2028, 5, 31),
      quantity: 5,
    ),
  ],
  match: const PharmacyDrugImportCandidate(drug: _catalogDrug),
);

const PharmacyDrugImportProduct _new = PharmacyDrugImportProduct(
  key: 'amoxicillin|',
  name: 'AMOXICILLIN',
  status: PharmacyDrugImportStatus.newProduct,
  defaultAction: PharmacyDrugImportAction.create,
  allowedActions: <PharmacyDrugImportAction>[
    PharmacyDrugImportAction.create,
    PharmacyDrugImportAction.skip,
  ],
);

PharmacyDrugImportProductReview _review(
  PharmacyDrugImportAction action, {
  PharmacyDrugImportProduct? product,
  PharmacyDrugImportProductDraft draft = PharmacyDrugImportProductDraft.empty,
  bool canWritePricing = true,
}) {
  final PharmacyDrugImportProduct reviewed = product ?? _existing;
  return PharmacyDrugImportProductReview(
    product: reviewed,
    action: action,
    target: reviewed.match,
    draft: draft,
    canWritePricing: canWritePricing,
  );
}

void main() {
  test('merging keeps catalog values and fills empty ones from the file', () {
    final PharmacyDrugImportProductReview review = _review(
      PharmacyDrugImportAction.merge,
    );

    expect(review.valueText(PharmacyDrugImportField.form), 'Tablet');
    expect(
      review.outcome(PharmacyDrugImportField.form),
      PharmacyDrugImportFieldOutcome.noChange,
    );
    expect(review.valueText(PharmacyDrugImportField.strength), '500 mg');
    expect(
      review.outcome(PharmacyDrugImportField.strength),
      PharmacyDrugImportFieldOutcome.fillsBlank,
    );
    expect(review.valueText(PharmacyDrugImportField.buyUnitPrice), '4300');
    expect(review.isEditable(PharmacyDrugImportField.name), isFalse);
    expect(
      review.valueText(PharmacyDrugImportField.name),
      'AZITHROMYCIN 500MG TABLET',
    );
  });

  test('updating takes file values and flags what they replace', () {
    final PharmacyDrugImportProductReview review = _review(
      PharmacyDrugImportAction.update,
    );

    expect(review.valueText(PharmacyDrugImportField.form), 'Capsule');
    expect(
      review.outcome(PharmacyDrugImportField.form),
      PharmacyDrugImportFieldOutcome.replaces,
    );
    expect(
      review.outcome(PharmacyDrugImportField.brandName),
      PharmacyDrugImportFieldOutcome.noChange,
    );
    expect(
      review.outcome(PharmacyDrugImportField.unitPrice),
      PharmacyDrugImportFieldOutcome.replaces,
    );
    expect(review.hasEdits, isFalse);
    expect(review.totalQuantity, 9);
  });

  test('edited values win and are sent with the decision', () {
    final PharmacyDrugImportProductReview review = _review(
      PharmacyDrugImportAction.update,
      draft: PharmacyDrugImportProductDraft.empty
          .withField(PharmacyDrugImportField.unitPrice, '6,000')
          .withField(PharmacyDrugImportField.form, '  ')
          .withField(PharmacyDrugImportField.name, 'Renamed')
          .withBatch(
            'PA2',
            PharmacyDrugImportBatchDraft(
              batchNumber: ' PA2-B ',
              expiryDate: DateTime(2029, 1, 31),
              quantity: '8',
            ),
          ),
    );

    expect(
      review.outcome(PharmacyDrugImportField.unitPrice),
      PharmacyDrugImportFieldOutcome.noChange,
    );
    expect(
      review.outcome(PharmacyDrugImportField.form),
      PharmacyDrugImportFieldOutcome.clears,
    );
    expect(review.hasEdits, isTrue);
    expect(review.hasProblems, isFalse);
    expect(review.totalQuantity, 12);
    expect(review.toDecision().toJson(), <String, Object?>{
      'key': 'azithromycin 500mg tablet|zaha',
      'action': 'UPDATE',
      'target_drug_id': 'DRG0000050',
      'values': <String, Object?>{'unit_price': 6000, 'form': null},
      'batches': <Object?>[
        <String, Object?>{
          'key': 'PA2',
          'batch_number': 'PA2-B',
          'expiry_date': '2029-01-31',
          'quantity': 8,
        },
      ],
    });
  });

  test('flags values that cannot be imported', () {
    final PharmacyDrugImportProductReview review = _review(
      PharmacyDrugImportAction.update,
      draft: PharmacyDrugImportProductDraft.empty
          .withField(PharmacyDrugImportField.unitPrice, '12abc')
          .withField(PharmacyDrugImportField.form, 'x' * 81)
          .withBatch(
            'PA1',
            const PharmacyDrugImportBatchDraft(
              batchNumber: 'pa2',
              quantity: '1.5',
            ),
          ),
    );
    final PharmacyDrugImportBatch first = _existing.batches.first;

    expect(
      review.fieldProblem(PharmacyDrugImportField.unitPrice),
      PharmacyDrugImportValueProblem.invalidNumber,
    );
    expect(
      review.fieldProblem(PharmacyDrugImportField.form),
      PharmacyDrugImportValueProblem.tooLong,
    );
    expect(
      review.batchNumberProblem(first),
      PharmacyDrugImportValueProblem.duplicateBatch,
    );
    expect(
      review.batchNumberProblem(_existing.batches.last),
      PharmacyDrugImportValueProblem.duplicateBatch,
    );
    expect(
      review.quantityProblem(first),
      PharmacyDrugImportValueProblem.invalidQuantity,
    );
    expect(review.hasProblems, isTrue);
    expect(
      parsePharmacyDrugImportPrice('-5').problem,
      PharmacyDrugImportValueProblem.negative,
    );
  });

  test('new drugs can be renamed and skipped products send no edits', () {
    final PharmacyDrugImportProductDraft draft = PharmacyDrugImportProductDraft
        .empty
        .withField(PharmacyDrugImportField.name, ' Amoxil ')
        .withField(PharmacyDrugImportField.brandName, 'G.S.K');
    final PharmacyDrugImportProductReview created = _review(
      PharmacyDrugImportAction.create,
      product: _new,
      draft: draft,
      canWritePricing: false,
    );

    expect(created.renamesProduct, isTrue);
    expect(created.identityKey, 'amoxil|gsk');
    expect(created.fields, isNot(contains(PharmacyDrugImportField.unitPrice)));
    expect(
      _review(
        PharmacyDrugImportAction.create,
        product: _new,
        draft: PharmacyDrugImportProductDraft.empty.withField(
          PharmacyDrugImportField.name,
          '',
        ),
      ).fieldProblem(PharmacyDrugImportField.name),
      PharmacyDrugImportValueProblem.required,
    );

    final PharmacyDrugImportProductReview skipped = _review(
      PharmacyDrugImportAction.skip,
      product: _new,
      draft: draft,
    );
    expect(skipped.hasEdits, isFalse);
    expect(skipped.toDecision().toJson(), <String, Object?>{
      'key': 'amoxicillin|',
      'action': 'SKIP',
    });
  });

  test('formats and parses typed numbers', () {
    expect(pharmacyDrugImportPlainNumber(4300), '4300');
    expect(pharmacyDrugImportPlainNumber(12.5), '12.5');
    expect(pharmacyDrugImportPlainNumber(null), '');
    expect(parsePharmacyDrugImportQuantity('1,200'), 1200);
    expect(parsePharmacyDrugImportQuantity('-1'), isNull);
    expect(const PharmacyDrugImportBatchDraft(
      batchNumber: 'PA1',
      quantity: '4',
    ).matches(_existing.batches.first), isTrue);
  });
}
