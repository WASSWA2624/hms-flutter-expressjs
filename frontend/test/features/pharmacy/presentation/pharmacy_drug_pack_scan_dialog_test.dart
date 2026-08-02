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

  testWidgets('skip closes scan without candidates and keeps host route', (
    WidgetTester tester,
  ) async {
    DrugPackFieldCandidates? closedWith;
    await pumpScan(tester, onClosed: (DrugPackFieldCandidates? r) {
      closedWith = r;
    });

    expect(
      find.text('SCAN PACK OR USE AI CAPTURE'),
      findsOneWidget,
    );
    expect(find.textContaining('Enter or decode a barcode first'), findsNothing);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Upload photo'), findsOneWidget);
    expect(find.text('Have pack text?'), findsOneWidget);
    expect(find.text('Prefill form'), findsOneWidget);

    await tester.tap(find.text('Skip scan'));
    await tester.pumpAndSettle();

    expect(closedWith, isNull);
    expect(find.text('Open scan'), findsOneWidget);
  });

  testWidgets('parser text produces candidates and enables prefill', (
    WidgetTester tester,
  ) async {
    DrugPackFieldCandidates? closedWith;
    await pumpScan(tester, onClosed: (DrugPackFieldCandidates? r) {
      closedWith = r;
    });

    await tester.tap(find.text('Have pack text?'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'Amoxil\nAmoxicillin\nCapsule 500mg\nBatch: LOT-1\n',
    );
    await tester.tap(find.text('Parse pack text'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Capsule'), findsWidgets);

    await tester.tap(find.text('Prefill form'));
    await tester.pumpAndSettle();

    expect(closedWith, isNotNull);
    expect(closedWith!.hasAnyIdentityField, isTrue);
    expect(closedWith!.form, 'Capsule');
  });

  testWidgets('barcode apply merges into field preview', (WidgetTester tester) async {
    await pumpScan(tester, onClosed: (_) {});

    await tester.enterText(find.byType(TextField).first, '8901234567890');
    await tester.tap(find.byTooltip('Use barcode'));
    await tester.pumpAndSettle();

    expect(find.text('Prefill form'), findsOneWidget);
  });
}
