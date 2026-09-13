import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_drug_import.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_drug_import_dialog.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_drug_import_formatting.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_en.dart';
import 'package:hosspi_hms/shared/components/components.dart';

final PharmacyDrugImportFile _file = PharmacyDrugImportFile(
  name: 'stock.xlsx',
  bytes: Uint8List(2048),
);

const String _newKey = 'amoxicillin|';
const String _similarKey = 'azithromycin 500mg tablet|swazi';
const String _existingKey = 'azithromycin 500mg tablet|zaha';

const PharmacyDrugImportDrug _zaha = PharmacyDrugImportDrug(
  id: 'DRG0000050',
  name: 'AZITHROMYCIN 500MG TABLET',
  brandName: 'ZAHA',
  form: 'Tablet',
  unitPrice: 6000,
  facilityQuantity: 10,
);

const PharmacyDrugImportProduct _newProduct = PharmacyDrugImportProduct(
  key: _newKey,
  name: 'AMOXICILLIN',
  form: 'Capsule',
  unitPrice: 5000,
  buyUnitPrice: 6000,
  status: PharmacyDrugImportStatus.newProduct,
  defaultAction: PharmacyDrugImportAction.create,
  allowedActions: <PharmacyDrugImportAction>[
    PharmacyDrugImportAction.create,
    PharmacyDrugImportAction.skip,
  ],
  totalQuantity: 5,
  rowNumbers: <int>[4],
  batches: <PharmacyDrugImportBatch>[
    PharmacyDrugImportBatch(
      key: 'AMX1',
      batchNumber: 'AMX1',
      quantity: 5,
      rowNumbers: <int>[4],
    ),
  ],
);

const PharmacyDrugImportPreview _preview = PharmacyDrugImportPreview(
  source: 'MEDIC_ERP',
  fileName: 'stock.xlsx',
  sheetName: 'Stock',
  facilityName: 'Fairbanks Medical Centre',
  template: PharmacyDrugImportTemplate(columns: <String>['product_name']),
  canWritePricing: true,
  canCommit: true,
  planHash: 'plan-hash-1',
  summary: PharmacyDrugImportSummary(
    totalRows: 3,
    products: 3,
    newProducts: 1,
    existingProducts: 1,
    similarProducts: 1,
    batches: 3,
    totalQuantity: 17,
    warnings: 1,
  ),
  products: <PharmacyDrugImportProduct>[
    _newProduct,
    PharmacyDrugImportProduct(
      key: _similarKey,
      name: 'AZITHROMYCIN 500MG TABLET',
      brandName: 'SWAZI',
      form: 'Tablet',
      status: PharmacyDrugImportStatus.similar,
      defaultAction: PharmacyDrugImportAction.create,
      allowedActions: <PharmacyDrugImportAction>[
        PharmacyDrugImportAction.create,
        PharmacyDrugImportAction.merge,
        PharmacyDrugImportAction.update,
        PharmacyDrugImportAction.skip,
      ],
      requiresReview: true,
      totalQuantity: 8,
      rowNumbers: <int>[3],
      batches: <PharmacyDrugImportBatch>[
        PharmacyDrugImportBatch(key: 'B1', batchNumber: 'B1', quantity: 8),
      ],
      candidates: <PharmacyDrugImportCandidate>[
        PharmacyDrugImportCandidate(drug: _zaha, score: 83),
      ],
    ),
    PharmacyDrugImportProduct(
      key: _existingKey,
      name: 'AZITHROMYCIN 500MG TABLET',
      brandName: 'ZAHA',
      form: 'Tablet',
      strength: '500 mg',
      unitPrice: 7000,
      buyUnitPrice: 4300,
      status: PharmacyDrugImportStatus.existing,
      defaultAction: PharmacyDrugImportAction.merge,
      defaultTargetDrugId: 'DRG0000050',
      allowedActions: <PharmacyDrugImportAction>[
        PharmacyDrugImportAction.merge,
        PharmacyDrugImportAction.update,
        PharmacyDrugImportAction.skip,
      ],
      totalQuantity: 4,
      rowNumbers: <int>[2],
      batches: <PharmacyDrugImportBatch>[
        PharmacyDrugImportBatch(key: 'PA1', batchNumber: 'PA1', quantity: 4),
      ],
      match: PharmacyDrugImportCandidate(drug: _zaha),
    ),
  ],
  issues: <PharmacyDrugImportIssue>[
    PharmacyDrugImportIssue(
      severity: PharmacyDrugImportIssueSeverity.warning,
      code: 'PRICE_BELOW_COST',
      rowNumber: 4,
      productKey: _newKey,
      field: 'retail_price',
      params: <String, Object?>{'retail_price': 5000, 'cost': 6000},
    ),
  ],
  stockedDrugs: <PharmacyDrugImportDrug>[
    PharmacyDrugImportDrug(
      id: 'DRG0000077',
      name: 'Old Syrup',
      facilityQuantity: 9,
    ),
  ],
);

const PharmacyDrugImportPreview _previewWithoutReview =
    PharmacyDrugImportPreview(
      source: 'MEDIC_ERP',
      fileName: 'stock.xlsx',
      sheetName: 'Stock',
      template: PharmacyDrugImportTemplate(columns: <String>['product_name']),
      canWritePricing: true,
      canCommit: true,
      planHash: 'plan-hash-2',
      summary: PharmacyDrugImportSummary(
        totalRows: 1,
        products: 1,
        newProducts: 1,
      ),
      products: <PharmacyDrugImportProduct>[_newProduct],
    );

Result<PharmacyDrugImportPreview> _previewResult(
  PharmacyDrugImportPreview preview,
) {
  return Result<PharmacyDrugImportPreview>.success(preview);
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required PharmacyDrugImportPreviewLoader onPreview,
  required PharmacyDrugImportCommitter onCommit,
  PharmacyDrugImportFilePicker? pickFile,
  ValueChanged<PharmacyDrugImportResult?>? onClosed,
}) async {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  final PharmacyDrugImportResult? result =
                      await showAppDialog<PharmacyDrugImportResult>(
                        context: context,
                        builder: (_) => PharmacyDrugImportDialog(
                          facilityName: 'Fairbanks Medical Centre',
                          onPreview: onPreview,
                          onCommit: onCommit,
                          pickFile: pickFile ?? () async => _file,
                        ),
                      );
                  onClosed?.call(result);
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

AppButton _button(WidgetTester tester, String label) {
  return tester.widget<AppButton>(
    find.ancestor(of: find.text(label), matching: find.byType(AppButton)),
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _chooseFile(WidgetTester tester) async {
  await _tapVisible(tester, find.text('Browse files'));
}

Future<void> _enterText(WidgetTester tester, String key, String text) async {
  final Finder field = find.descendant(
    of: find.byKey(ValueKey<String>(key)),
    matching: find.byType(EditableText),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> _analyzeDefaultPreview(WidgetTester tester) async {
  await _pumpDialog(
    tester,
    onPreview:
        ({
          required PharmacyDrugImportSource source,
          required PharmacyDrugImportFile file,
        }) async => _previewResult(_preview),
    onCommit: (_) async => fail('commit must not run'),
  );
  await _chooseFile(tester);
}

void main() {
  testWidgets('imports reviewed products with values edited in their forms', (
    WidgetTester tester,
  ) async {
    PharmacyDrugImportSource? previewedSource;
    PharmacyDrugImportCommitInput? committed;
    PharmacyDrugImportResult? closedWith;

    await _pumpDialog(
      tester,
      onPreview:
          ({
            required PharmacyDrugImportSource source,
            required PharmacyDrugImportFile file,
          }) async {
            previewedSource = source;
            return _previewResult(_preview);
          },
      onCommit: (PharmacyDrugImportCommitInput input) async {
        committed = input;
        return const Result<PharmacyDrugImportResult>.success(
          PharmacyDrugImportResult(
            facilityName: 'Fairbanks Medical Centre',
            created: 2,
            updated: 1,
            quantityImported: 19,
          ),
        );
      },
      onClosed: (PharmacyDrugImportResult? result) => closedWith = result,
    );

    // AppDialog renders titles uppercase.
    expect(find.text('IMPORT DRUGS'), findsOneWidget);
    expect(find.text('Medic-ERP template columns'), findsOneWidget);
    expect(find.text('Choose file'), findsNothing);
    expect(_button(tester, 'Review file').enabled, isFalse);

    await _chooseFile(tester);

    expect(previewedSource, PharmacyDrugImportSource.medicErp);
    expect(find.text('2 KB · Stock sheet · 3 rows'), findsOneWidget);
    expect(find.text('Units in 3 batches'), findsOneWidget);
    expect(
      find.textContaining('look like a drug already in your catalog'),
      findsNothing,
    );
    expect(find.text('1 issue'), findsOneWidget);
    expect(
      find.text('Links to AZITHROMYCIN 500MG TABLET · ZAHA'),
      findsOneWidget,
    );
    // Cards and settings start collapsed.
    expect(find.text('What should happen to this product?'), findsNothing);
    expect(find.text('Replace with file quantities'), findsNothing);
    expect(
      find.text(
        'Replaces stock with file quantities · Keeps stock for 1 item not in the file',
      ),
      findsOneWidget,
    );
    expect(_button(tester, 'Import 3 products').enabled, isTrue);

    await _tapVisible(tester, find.text('Import settings'));
    await _tapVisible(
      tester,
      find.text('Clear stock for items not in the file (1)'),
    );
    expect(
      find.text(
        'Replaces stock with file quantities · Clears stock for 1 item not in the file',
      ),
      findsOneWidget,
    );

    await _tapVisible(
      tester,
      find.text('AZITHROMYCIN 500MG TABLET  ·  ZAHA'),
    );
    expect(find.text('What should happen to this product?'), findsOneWidget);
    expect(find.text('In your catalog'), findsOneWidget);
    expect(find.text('Catalog drug to use'), findsOneWidget);
    expect(find.text('The catalog name is kept'), findsOneWidget);
    expect(find.text('Replaces the catalog value'), findsNothing);

    await _tapVisible(tester, find.text('Link and overwrite'));
    expect(find.text('Replaces the catalog value'), findsOneWidget);

    await _enterText(tester, 'pharmacy-drug-import-$_existingKey-unit_price', '6500');
    await _enterText(
      tester,
      'pharmacy-drug-import-$_existingKey-buy_unit_price',
      'abc',
    );
    expect(find.text('Enter a number, like 1500.'), findsOneWidget);
    expect(
      find.text('1 product has values that need fixing'),
      findsOneWidget,
    );
    expect(_button(tester, 'Import 3 products').enabled, isFalse);

    await _enterText(
      tester,
      'pharmacy-drug-import-$_existingKey-buy_unit_price',
      '4,400',
    );
    await _enterText(
      tester,
      'pharmacy-drug-import-$_existingKey-batch-PA1-quantity',
      '6',
    );
    expect(find.text('1 product has values that need fixing'), findsNothing);
    expect(find.text('Edited'), findsWidgets);
    expect(
      find.text('Stock at this facility: 10 now, 6 after import'),
      findsOneWidget,
    );

    await _tapVisible(tester, find.text('Import 3 products'));
    expect(
      find.textContaining('1 product looks like a drug already in your catalog'),
      findsOneWidget,
    );
    await _tapVisible(tester, find.text('Import now'));

    expect(committed?.planHash, 'plan-hash-1');
    expect(committed?.file.name, 'stock.xlsx');
    expect(committed?.stockMode, PharmacyDrugImportStockMode.replace);
    expect(committed?.clearMissingStock, isTrue);
    expect(committed?.confirmReview, isTrue);
    expect(
      committed?.decisions.map(
        (PharmacyDrugImportDecision decision) => decision.toJson(),
      ),
      <Map<String, Object?>>[
        <String, Object?>{'key': _newKey, 'action': 'CREATE'},
        <String, Object?>{'key': _similarKey, 'action': 'CREATE'},
        <String, Object?>{
          'key': _existingKey,
          'action': 'UPDATE',
          'target_drug_id': 'DRG0000050',
          'values': <String, Object?>{
            'unit_price': 6500,
            'buy_unit_price': 4400,
          },
          'batches': <Object?>[
            <String, Object?>{
              'key': 'PA1',
              'batch_number': 'PA1',
              'expiry_date': null,
              'quantity': 6,
            },
          ],
        },
      ],
    );

    expect(find.text('Import complete'), findsOneWidget);
    await _tapVisible(tester, find.text('Done'));
    expect(closedWith?.importedProducts, 3);
  });

  testWidgets('going back from the review prompt shows products to review', (
    WidgetTester tester,
  ) async {
    await _analyzeDefaultPreview(tester);

    await _tapVisible(tester, find.text('Import 3 products'));
    await _tapVisible(tester, find.text('Review them'));

    expect(find.text('Import now'), findsNothing);
    expect(find.text('Showing 1 of 3'), findsOneWidget);
  });

  testWidgets('blocks renamed duplicates and links similar products', (
    WidgetTester tester,
  ) async {
    await _analyzeDefaultPreview(tester);

    await _tapVisible(tester, find.text('AMOXICILLIN').first);
    expect(
      find.text('Row 4 · Retail price 5,000 is below cost 6,000.'),
      findsOneWidget,
    );
    await _enterText(
      tester,
      'pharmacy-drug-import-$_newKey-name',
      'Azithromycin 500mg Tablet',
    );
    await _enterText(tester, 'pharmacy-drug-import-$_newKey-brand_name', 'Swazi');
    expect(
      find.text('Another new drug in this import has this name and brand.'),
      findsNWidgets(2),
    );
    expect(_button(tester, 'Import 3 products').enabled, isFalse);

    await _tapVisible(
      tester,
      find.text('AZITHROMYCIN 500MG TABLET  ·  SWAZI'),
    );
    expect(find.text('Similar drugs already in your catalog'), findsOneWidget);
    await _tapVisible(
      tester,
      find.text('AZITHROMYCIN 500MG TABLET · ZAHA').first,
    );

    expect(find.text('Catalog drug to use'), findsOneWidget);
    expect(
      find.text('Another new drug in this import has this name and brand.'),
      findsNothing,
    );
    expect(_button(tester, 'Import 3 products').enabled, isTrue);
  });

  testWidgets('keeps setup open and lists missing template columns', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(
      tester,
      onPreview:
          ({
            required PharmacyDrugImportSource source,
            required PharmacyDrugImportFile file,
          }) async => _previewResult(
            const PharmacyDrugImportPreview(
              source: 'MEDIC_ERP',
              template: PharmacyDrugImportTemplate(
                missingColumns: <String>['cost', 'expiry_date'],
              ),
            ),
          ),
      onCommit: (_) async => fail('commit must not run'),
    );

    await _chooseFile(tester);

    expect(
      find.text('This file does not match the Medic-ERP template'),
      findsOneWidget,
    );
    expect(find.text('Missing columns: cost, expiry_date'), findsOneWidget);
    expect(find.text('Review file'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Import \d')), findsNothing);
  });

  testWidgets('rejects files that are not .xlsx without uploading them', (
    WidgetTester tester,
  ) async {
    int previews = 0;
    await _pumpDialog(
      tester,
      pickFile: () async =>
          PharmacyDrugImportFile(name: 'stock.csv', bytes: Uint8List(4)),
      onPreview:
          ({
            required PharmacyDrugImportSource source,
            required PharmacyDrugImportFile file,
          }) async {
            previews += 1;
            return _previewResult(_preview);
          },
      onCommit: (_) async => fail('commit must not run'),
    );

    await _chooseFile(tester);

    expect(
      find.text('Choose an Excel workbook saved as .xlsx.'),
      findsOneWidget,
    );
    expect(previews, 0);
    expect(find.text('Browse files'), findsOneWidget);
  });

  testWidgets('reports a file the picker could not read', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(
      tester,
      pickFile: () async => throw StateError('blob read failed'),
      onPreview:
          ({
            required PharmacyDrugImportSource source,
            required PharmacyDrugImportFile file,
          }) async => fail('preview must not run'),
      onCommit: (_) async => fail('commit must not run'),
    );

    await _chooseFile(tester);

    expect(
      find.text(
        'The file could not be opened. Choose it again, or export it from the source system again.',
      ),
      findsOneWidget,
    );
    expect(_button(tester, 'Browse files').enabled, isTrue);
  });

  testWidgets('offers another review when the reviewed plan is stale', (
    WidgetTester tester,
  ) async {
    int previews = 0;
    await _pumpDialog(
      tester,
      onPreview:
          ({
            required PharmacyDrugImportSource source,
            required PharmacyDrugImportFile file,
          }) async {
            previews += 1;
            return _previewResult(_previewWithoutReview);
          },
      onCommit: (_) async => Result<PharmacyDrugImportResult>.failure(
        AppFailure.conflict(
          statusCode: 409,
          detailMessage: 'The catalog or file changed since it was reviewed.',
        ),
      ),
    );

    await _chooseFile(tester);
    await _tapVisible(tester, find.text('Import 1 product'));

    expect(find.text('Review file again'), findsOneWidget);
    await _tapVisible(tester, find.text('Review file again'));
    expect(previews, 2);
    expect(find.text('Import 1 product'), findsOneWidget);
  });

  group('pharmacyDrugImportIssueMessage', () {
    final AppLocalizations l10n = AppLocalizationsEn();
    const Locale locale = Locale('en');

    test('formats numeric parameters', () {
      expect(
        pharmacyDrugImportIssueMessage(
          l10n,
          locale,
          const PharmacyDrugImportIssue(
            severity: PharmacyDrugImportIssueSeverity.warning,
            code: 'CONFLICTING_RETAIL_PRICE',
            params: <String, Object?>{'values': '7000, 7500', 'chosen': 7500},
          ),
        ),
        'Rows have different retail prices (7,000, 7,500); the latest, 7,500, is used.',
      );
    });

    test('names the source column and falls back for unknown codes', () {
      expect(
        pharmacyDrugImportIssueMessage(
          l10n,
          locale,
          const PharmacyDrugImportIssue(
            severity: PharmacyDrugImportIssueSeverity.error,
            code: 'INVALID_NUMBER',
            field: 'available_quantity',
            params: <String, Object?>{'value': 'lots'},
          ),
        ),
        'Available quantity is not a number: lots',
      );
      expect(
        pharmacyDrugImportIssueMessage(
          l10n,
          locale,
          const PharmacyDrugImportIssue(
            severity: PharmacyDrugImportIssueSeverity.info,
            code: 'NEW_CHECK',
          ),
        ),
        'Check this value (NEW_CHECK).',
      );
    });
  });
}
