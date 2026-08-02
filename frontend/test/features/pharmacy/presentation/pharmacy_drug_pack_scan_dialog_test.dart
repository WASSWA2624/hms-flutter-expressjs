import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_drug_pack_scan_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/scan/scan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setLargeSurface(WidgetTester tester) async {
    final TestFlutterView view = tester.view;
    view.physicalSize = const Size(1400, 1800);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  }

  Future<void> pumpScan(
    WidgetTester tester, {
    required void Function(DrugPackFieldCandidates? result) onClosed,
    DrugPackAiMapper? aiMapper,
  }) async {
    await setLargeSurface(tester);
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
                    final DrugPackFieldCandidates? result =
                        await showPharmacyDrugPackScanDialog(
                          context,
                          ocrService: const AppNoOpOcrService(),
                          barcodeDecoder: const AppHeuristicBarcodeDecoder(),
                          parser: const DrugPackFieldParser(),
                          aiMapper: aiMapper,
                        );
                    onClosed(result);
                  },
                  child: const Text('Open scan'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open scan'));
    await tester.pumpAndSettle();
  }

  testWidgets('toolbar and raw text layout without photos', (
    WidgetTester tester,
  ) async {
    DrugPackFieldCandidates? closedWith;
    await pumpScan(tester, onClosed: (DrugPackFieldCandidates? r) {
      closedWith = r;
    });

    expect(find.text('SCAN PACK OR USE AI CAPTURE'), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Upload photos'), findsOneWidget);
    expect(find.text('Scan barcode'), findsOneWidget);
    expect(find.text('Process with OCR'), findsNothing);
    expect(find.text('Process with AI'), findsWidgets);
    expect(find.text('Raw pack text'), findsWidgets);
    expect(find.text('Parse text'), findsOneWidget);
    expect(find.text('Clear photos'), findsNothing);

    await tester.tap(find.text('Skip scan'));
    await tester.pumpAndSettle();
    expect(closedWith, isNull);
  });

  testWidgets('parse text seeds editable suggested values for prefill', (
    WidgetTester tester,
  ) async {
    DrugPackFieldCandidates? closedWith;
    await pumpScan(tester, onClosed: (DrugPackFieldCandidates? r) {
      closedWith = r;
    });

    await tester.enterText(
      find.byType(TextField).at(1),
      'Amoxil\nAmoxicillin\nCapsule 500mg\nBatch: LOT-1\n',
    );
    await tester.tap(find.text('Parse text'));
    await tester.pumpAndSettle();

    expect(find.text('Suggested values'), findsOneWidget);
    expect(find.text('Generic name'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Generic name'), '');
    // Find generic field by label and set a clear value via last matching editable.
    final Finder genericField = find.ancestor(
      of: find.text('Generic name'),
      matching: find.byType(TextField),
    );
    if (tester.any(genericField)) {
      await tester.enterText(genericField.first, 'Amoxicillin');
    }

    await tester.tap(find.text('Prefill form'));
    await tester.pumpAndSettle();

    expect(closedWith, isNotNull);
    expect(closedWith!.hasAnyIdentityField, isTrue);
    expect(closedWith!.form, 'Capsule');
  });

  testWidgets('barcode use maps into suggested code field', (
    WidgetTester tester,
  ) async {
    await pumpScan(tester, onClosed: (_) {});

    expect(
      find.textContaining('Type or paste the barcode number'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).first, '8901234567890');
    await tester.tap(find.byTooltip('Use barcode'));
    await tester.pumpAndSettle();

    expect(find.text('Suggested values'), findsOneWidget);
    expect(find.text('Prefill form'), findsOneWidget);
  });
}
