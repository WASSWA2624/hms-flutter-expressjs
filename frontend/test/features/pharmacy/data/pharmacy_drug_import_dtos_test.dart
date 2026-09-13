import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/data/dtos/pharmacy_drug_import_dtos.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_drug_import.dart';

/// Round-trips through JSON so maps match what Dio decodes.
Object? _response(Map<String, Object?> data) {
  return jsonDecode(jsonEncode(<String, Object?>{'success': true, 'data': data}));
}

const Map<String, Object?> _previewData = <String, Object?>{
  'source': 'MEDIC_ERP',
  'source_label': 'Medic-ERP',
  'file_name': 'stock.xlsx',
  'sheet_name': 'Stock',
  'facility': <String, Object?>{
    'id': 'FAC0000001',
    'name': 'Fairbanks Medical Centre',
  },
  'template': <String, Object?>{
    'columns': <String>['product_name', 'available_quantity'],
    'missing_columns': <String>[],
    'unexpected_columns': <String>['notes'],
    'is_valid': true,
  },
  'can_write_pricing': true,
  'can_commit': true,
  'plan_hash': 'abc123',
  'summary': <String, Object?>{
    'total_rows': 3,
    'products': 2,
    'new_products': 0,
    'existing_products': 1,
    'similar_products': 1,
    'batches': 2,
    'total_quantity': 12,
    'warnings': 1,
  },
  'products': <Object?>[
    <String, Object?>{
      'key': 'azithromycin 500mg tablet|swazi',
      'name': 'AZITHROMYCIN 500MG TABLET',
      'brand_name': 'SWAZI',
      'form': 'Tablet',
      'strength': '500 mg',
      'unit_price': 6000,
      'buy_unit_price': '2100.50',
      'row_numbers': <int>[2],
      'total_quantity': 8,
      'batches': <Object?>[
        <String, Object?>{
          'key': 'BG10425',
          'batch_number': 'BG10425',
          'expiry_date': '2028-04-30',
          'quantity': 8,
          'row_numbers': <int>[2],
        },
      ],
      'status': 'SIMILAR',
      'allowed_actions': <String>['CREATE', 'MERGE', 'UPDATE', 'SKIP', 'BOGUS'],
      'default_action': 'CREATE',
      'default_target_drug_id': null,
      'requires_review': true,
      'match': null,
      'candidates': <Object?>[
        <String, Object?>{
          'drug': <String, Object?>{
            'id': 'DRG0000050',
            'name': 'AZITHROMYCIN 500MG TABLET',
            'brand_name': 'ZAHA',
            'facility_quantity': 10,
          },
          'score': 83,
          'reasons': <String>['generic_name'],
          'changes': <Object?>[
            <String, Object?>{
              'field': 'brand_name',
              'current_value': 'ZAHA',
              'incoming_value': 'SWAZI',
              'fills_blank': false,
            },
          ],
        },
      ],
      'issues': <Object?>[
        <String, Object?>{
          'row_number': null,
          'product_key': 'azithromycin 500mg tablet|swazi',
          'severity': 'warning',
          'code': 'SIMILAR_PRODUCT_IN_FILE',
          'field': null,
          'params': <String, Object?>{'name': 'X', 'brand_name': 'Y', 'rows': '3'},
        },
      ],
    },
    <String, Object?>{
      'key': 'paracetamol|',
      'name': 'Paracetamol',
      'status': 'EXISTING',
      'allowed_actions': <String>['MERGE', 'UPDATE', 'SKIP'],
      'default_action': 'MERGE',
      'default_target_drug_id': 'DRG0000007',
      'requires_review': false,
      'match': <String, Object?>{
        'drug': <String, Object?>{
          'id': 'DRG0000007',
          'generic_name': 'Paracetamol',
          'facility_quantity': 4,
        },
        'changes': <Object?>[
          <String, Object?>{
            'field': 'unit_price',
            'current_value': 50,
            'incoming_value': 60,
            'fills_blank': false,
          },
        ],
      },
      'candidates': <Object?>[],
      'issues': <Object?>[],
    },
  ],
  'issues': <Object?>[
    <String, Object?>{
      'row_number': 4,
      'product_key': 'paracetamol|',
      'severity': 'error',
      'code': 'INVALID_NUMBER',
      'field': 'available_quantity',
      'params': <String, Object?>{'value': 'lots'},
    },
  ],
  'stocked_drugs': <Object?>[
    <String, Object?>{'id': 'DRG0000077', 'name': 'Old Syrup', 'facility_quantity': 9},
  ],
};

void main() {
  group('PharmacyDrugImportPreviewDto', () {
    test('maps the server plan into review entities', () {
      final PharmacyDrugImportPreview preview =
          PharmacyDrugImportPreviewDto.fromResponse(
            _response(_previewData),
          ).toEntity();

      expect(preview.source, 'MEDIC_ERP');
      expect(preview.facilityName, 'Fairbanks Medical Centre');
      expect(preview.template.isValid, isTrue);
      expect(preview.template.unexpectedColumns, <String>['notes']);
      expect(preview.canCommit, isTrue);
      expect(preview.planHash, 'abc123');
      expect(preview.summary.totalRows, 3);
      expect(preview.summary.similarProducts, 1);

      final PharmacyDrugImportProduct similar = preview.products.first;
      expect(similar.key, 'azithromycin 500mg tablet|swazi');
      expect(similar.displayName, 'AZITHROMYCIN 500MG TABLET · SWAZI');
      expect(similar.status, PharmacyDrugImportStatus.similar);
      expect(similar.allowedActions, <PharmacyDrugImportAction>[
        PharmacyDrugImportAction.create,
        PharmacyDrugImportAction.merge,
        PharmacyDrugImportAction.update,
        PharmacyDrugImportAction.skip,
      ]);
      expect(similar.defaultAction, PharmacyDrugImportAction.create);
      expect(similar.requiresReview, isTrue);
      expect(similar.buyUnitPrice, 2100.5);
      expect(similar.batches.single.expiryDate, DateTime(2028, 4, 30));
      expect(similar.batches.single.key, 'BG10425');
      expect(const PharmacyDrugImportBatch(batchNumber: ' ab1 ').key, 'AB1');
      expect(const PharmacyDrugImportBatch().key, 'UNLABELED');
      expect(similar.linkOptions.single.drug.id, 'DRG0000050');
      expect(similar.linkOptions.single.score, 83);
      expect(similar.issues.single.code, 'SIMILAR_PRODUCT_IN_FILE');

      final PharmacyDrugImportProduct existing = preview.products.last;
      expect(existing.key, 'paracetamol|');
      expect(existing.match?.score, isNull);
      expect(
        existing.linkOptionFor('DRG0000007')?.changes.single.incomingValue,
        60,
      );

      expect(
        preview.issues.single.severity,
        PharmacyDrugImportIssueSeverity.error,
      );
      expect(preview.issues.single.rowNumber, 4);
      expect(preview.issues.single.productKey, 'paracetamol|');
      expect(preview.stockedDrugs.single.facilityQuantity, 9);
    });

    test('rejects responses that are not objects', () {
      expect(
        () => PharmacyDrugImportPreviewDto.fromResponse('oops'),
        throwsFormatException,
      );
    });
  });

  test('PharmacyDrugImportResultDto maps import counts', () {
    final PharmacyDrugImportResult result =
        PharmacyDrugImportResultDto.fromResponse(
          _response(<String, Object?>{
            'import_id': 'import-1',
            'stock_mode': 'ADD',
            'facility': <String, Object?>{'id': 'FAC0000001', 'name': 'Fairbanks'},
            'summary': <String, Object?>{
              'created': 2,
              'merged': 1,
              'updated': 1,
              'skipped': 3,
              'batches_created': 4,
              'stock_cleared': 1,
              'quantity_imported': 40,
            },
          }),
        ).toEntity();

    expect(result.importId, 'import-1');
    expect(result.facilityName, 'Fairbanks');
    expect(result.stockMode, PharmacyDrugImportStockMode.add);
    expect(result.importedProducts, 4);
    expect(result.skipped, 3);
    expect(result.batchesCreated, 4);
    expect(result.stockCleared, 1);
    expect(result.quantityImported, 40);
  });

  test('PharmacyDrugImportCommitInput sends decisions and flags as form fields', () {
    final PharmacyDrugImportCommitInput input = PharmacyDrugImportCommitInput(
      source: PharmacyDrugImportSource.medicErp,
      file: PharmacyDrugImportFile(name: 'stock.xlsx', bytes: Uint8List(0)),
      planHash: 'abc123',
      decisions: <PharmacyDrugImportDecision>[
        PharmacyDrugImportDecision(
          key: 'a|b',
          action: PharmacyDrugImportAction.merge,
          targetDrugId: 'DRG0000050',
          values: const <PharmacyDrugImportField, Object?>{
            PharmacyDrugImportField.form: 'Tablet',
            PharmacyDrugImportField.unitPrice: 1500,
            PharmacyDrugImportField.brandName: null,
          },
          batches: <PharmacyDrugImportBatchEdit>[
            PharmacyDrugImportBatchEdit(
              key: 'B1',
              batchNumber: 'B-1',
              expiryDate: DateTime(2029, 1, 5),
              quantity: 7,
            ),
          ],
        ),
        const PharmacyDrugImportDecision(
          key: 'c|',
          action: PharmacyDrugImportAction.skip,
          targetDrugId: 'DRG0000009',
          values: <PharmacyDrugImportField, Object?>{
            PharmacyDrugImportField.form: 'Syrup',
          },
        ),
      ],
      clearMissingStock: true,
      confirmReview: true,
      currency: ' UGX ',
    );

    final Map<String, Object?> fields = input.toFormFields();

    expect(fields['source'], 'MEDIC_ERP');
    expect(fields['plan_hash'], 'abc123');
    expect(fields['stock_mode'], 'REPLACE');
    expect(fields['clear_missing_stock'], 'true');
    expect(fields['confirm_review'], 'true');
    expect(fields['currency'], 'UGX');
    expect(jsonDecode(fields['decisions']! as String), <Object?>[
      <String, Object?>{
        'key': 'a|b',
        'action': 'MERGE',
        'target_drug_id': 'DRG0000050',
        'values': <String, Object?>{
          'form': 'Tablet',
          'unit_price': 1500,
          'brand_name': null,
        },
        'batches': <Object?>[
          <String, Object?>{
            'key': 'B1',
            'batch_number': 'B-1',
            'expiry_date': '2029-01-05',
            'quantity': 7,
          },
        ],
      },
      <String, Object?>{'key': 'c|', 'action': 'SKIP'},
    ]);
  });
}
