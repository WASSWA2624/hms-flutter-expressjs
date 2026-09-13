import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_drug_import.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_drug_import_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_en.dart';
import 'package:hosspi_hms/shared/components/components.dart';

final PharmacyDrugImportFile _file = PharmacyDrugImportFile(
  name: 'stock.xlsx',
  bytes: Uint8List(2048),
);

const PharmacyDrugImportDrug _zaha = PharmacyDrugImportDrug(
  id: 'DRG0000050',
  name: 'AZITHROMYCIN 500MG TABLET',
  brandName: 'ZAHA',
  facilityQuantity: 10,
);

const PharmacyDrugImportProduct _newProduct = PharmacyDrugImportProduct(
  key: 'amoxicillin|',
  name: 'AMOXICILLIN',
  status: PharmacyDrugImportStatus.newProduct,
  defaultAction: PharmacyDrugImportAction.create,
  allowedActions: <PharmacyDrugImportAction>[
    PharmacyDrugImportAction.create,
    PharmacyDrugImportAction.skip,
  ],
  totalQuantity: 5,
  rowNumbers: <int>[4],
  batches: <PharmacyDrugImportBatch>[
    PharmacyDrugImportBatch(batchNumber: 'AMX1', quantity: 5),
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
      key: 'azithromycin 500mg tablet|swazi',
      name: 'AZITHROMYCIN 500MG TABLET',
      brandName: 'SWAZI',
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
      candidates: <PharmacyDrugImportCandidate>[
        PharmacyDrugImportCandidate(drug: _zaha, score: 83),
      ],
    ),
    PharmacyDrugImportProduct(
      key: 'azithromycin 500mg tablet|zaha',
      name: 'AZITHROMYCIN 500MG TABLET',
      brandName: 'ZAHA',
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
      match: PharmacyDrugImportCandidate(
        drug: _zaha,
        changes: <PharmacyDrugImportChange>[
          PharmacyDrugImportChange(
            field: 'buy_unit_price',
            incomingValue: 4300,
            fillsBlank: true,
          ),
        ],
      ),
    ),
  ],
  issues: <PharmacyDrugImportIssue>[
    PharmacyDrugImportIssue(
      severity: PharmacyDrugImportIssueSeverity.warning,
      code: 'PRICE_BELOW_COST',
      rowNumber: 4,
      productKey: 'amoxicillin|',
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

void main() {
  testWidgets('choosing a file analyzes it and imports the reviewed plan', (
    WidgetTester tester,
  ) async {
    PharmacyDrugImportSource? previewedSource;
    PharmacyDrugImportFile? previewedFile;
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
            previewedFile = file;
            return const Result<PharmacyDrugImportPreview>.success(_preview);
          },
      onCommit: (PharmacyDrugImportCommitInput input) async {
        committed = input;
        return const Result<PharmacyDrugImportResult>.success(
          PharmacyDrugImportResult(
            facilityName: 'Fairbanks Medical Centre',
            created: 2,
            merged: 1,
            quantityImported: 17,
          ),
        );
      },
      onClosed: (PharmacyDrugImportResult? result) => closedWith = result,
    );

    // AppDialog renders titles uppercase.
    expect(find.text('IMPORT DRUGS'), findsOneWidget);
    expect(
      find.text('Destination: Fairbanks Medical Centre'),
      findsOneWidget,
    );
    expect(find.text('Medic-ERP template columns'), findsOneWidget);
    expect(_button(tester, 'Review file').enabled, isFalse);

    await _chooseFile(tester);

    expect(previewedSource, PharmacyDrugImportSource.medicErp);
    expect(previewedFile?.name, 'stock.xlsx');
    expect(find.text('stock.xlsx'), findsOneWidget);
    expect(find.text('2 KB · Stock sheet · 3 rows'), findsOneWidget);
    expect(
      find.text('1 product looks like a drug already in your catalog'),
      findsOneWidget,
    );
    expect(find.text('Units in 3 batches'), findsOneWidget);
    expect(find.text('Needs review'), findsWidgets);
    expect(find.text('1 issue'), findsOneWidget);
    expect(_button(tester, 'Import 3 products').enabled, isFalse);

    await _tapVisible(tester, find.text('Show details').last);
    expect(find.text('Cost: 4,300 (currently empty)'), findsOneWidget);

    await _tapVisible(tester, find.text('I have reviewed these products'));
    expect(_button(tester, 'Import 3 products').enabled, isTrue);

    await _tapVisible(
      tester,
      find.text('Clear stock for items not in the file (1)'),
    );
    await _tapVisible(tester, find.text('Import 3 products'));

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
        <String, Object?>{'key': 'amoxicillin|', 'action': 'CREATE'},
        <String, Object?>{
          'key': 'azithromycin 500mg tablet|swazi',
          'action': 'CREATE',
        },
        <String, Object?>{
          'key': 'azithromycin 500mg tablet|zaha',
          'action': 'MERGE',
          'target_drug_id': 'DRG0000050',
        },
      ],
    );

    expect(find.text('Import complete'), findsOneWidget);
    expect(find.text('Drugs created'), findsOneWidget);

    await _tapVisible(tester, find.text('Done'));
    expect(closedWith?.importedProducts, 3);
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
          }) async => const Result<PharmacyDrugImportPreview>.success(
            PharmacyDrugImportPreview(
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
            return const Result<PharmacyDrugImportPreview>.success(_preview);
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
            return const Result<PharmacyDrugImportPreview>.success(
              _previewWithoutReview,
            );
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
