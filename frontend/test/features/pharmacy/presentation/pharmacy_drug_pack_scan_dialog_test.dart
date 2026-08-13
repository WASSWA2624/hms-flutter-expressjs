import 'dart:typed_data';

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
    DrugPackBarcodeLookup? barcodeLookup,
    List<Uint8List>? seedPhotos,
    AppOcrService? ocrService,
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
                          ocrService: ocrService ?? const AppNoOpOcrService(),
                          barcodeDecoder: const AppHeuristicBarcodeDecoder(),
                          parser: const DrugPackFieldParser(),
                          aiMapper: aiMapper,
                          barcodeLookup:
                              barcodeLookup ?? const DrugPackNoOpBarcodeLookup(),
                          seedPhotos: seedPhotos,
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
    expect(find.text('Process barcode'), findsOneWidget);

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

  testWidgets('process barcode maps into suggested code field', (
    WidgetTester tester,
  ) async {
    await pumpScan(tester, onClosed: (_) {});

    expect(
      find.textContaining('Process barcode to map fields'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).first, '8901234567890');
    await tester.tap(find.byTooltip('Process barcode'));
    await tester.pumpAndSettle();

    expect(find.text('Suggested values'), findsOneWidget);
    expect(find.text('Prefill form'), findsOneWidget);
  });

  testWidgets('process OCR stays enabled after first successful run', (
    WidgetTester tester,
  ) async {
    // 1x1 PNG so Image.memory can decode the seeded thumb.
    final Uint8List tinyPng = Uint8List.fromList(<int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);
    await pumpScan(
      tester,
      onClosed: (_) {},
      ocrService: const AppFixedOcrService(
        'AGOMO\nParacetamol Tablets B.P. 500mg\n',
      ),
      seedPhotos: <Uint8List>[tinyPng],
    );

    expect(find.text('Process with OCR'), findsOneWidget);
    await tester.tap(find.text('Process with OCR'));
    await tester.pumpAndSettle();

    expect(find.text('Suggested values'), findsOneWidget);
    expect(find.text('Process with OCR'), findsOneWidget);
    expect(find.text('Process with AI'), findsWidgets);

    // Second run must remain possible.
    await tester.tap(find.text('Process with OCR'));
    await tester.pumpAndSettle();
    expect(find.text('Suggested values'), findsOneWidget);
    expect(find.text('Process with OCR'), findsOneWidget);
  });

  testWidgets('process with AI sends photos and prefers AI fields over OCR', (
    WidgetTester tester,
  ) async {
    final Uint8List tinyPng = Uint8List.fromList(<int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);
    final _RecordingAiMapper aiMapper = _RecordingAiMapper(
      candidates: const DrugPackFieldCandidates(
        genericName: 'Paracetamol',
        brandName: 'AGOMO',
        form: 'Tablet',
        strength: '500 mg',
        rawText: 'AGOMO\nParacetamol Tablets 500 mg',
      ),
    );
    DrugPackFieldCandidates? closedWith;
    await pumpScan(
      tester,
      onClosed: (DrugPackFieldCandidates? r) {
        closedWith = r;
      },
      ocrService: const AppFixedOcrService('GARBAGE OCR LINE\nzzz 00s'),
      aiMapper: aiMapper,
      seedPhotos: <Uint8List>[tinyPng],
    );

    await tester.tap(find.text('Process with AI').first);
    await tester.pumpAndSettle();

    expect(aiMapper.lastImages, isNotEmpty);
    expect(find.text('Suggested values'), findsOneWidget);
    expect(find.text('AGOMO'), findsWidgets);
    expect(find.text('Paracetamol'), findsWidgets);

    await tester.tap(find.text('Prefill form'));
    await tester.pumpAndSettle();
    expect(closedWith, isNotNull);
    expect(closedWith!.genericName, 'Paracetamol');
    expect(closedWith!.brandName, 'AGOMO');
    expect(closedWith!.form, 'Tablet');
    expect(closedWith!.strength, '500 mg');
  });
}

class _RecordingAiMapper implements DrugPackAiMapper {
  _RecordingAiMapper({required this.candidates});

  final DrugPackFieldCandidates candidates;
  List<DrugPackAiImage> lastImages = const <DrugPackAiImage>[];

  @override
  Future<DrugPackAiMapResult> map({
    required String rawText,
    String? barcode,
    List<String> ocrLines = const <String>[],
    List<DrugPackAiImage> images = const <DrugPackAiImage>[],
  }) async {
    lastImages = images;
    return DrugPackAiMapResult(candidates: candidates);
  }
}
