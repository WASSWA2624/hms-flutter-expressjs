import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_storage_shelf_similarity_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

void main() {
  Future<void> setLargeSurface(WidgetTester tester) async {
    final TestFlutterView view = tester.view;
    view.physicalSize = const Size(1400, 1800);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  }

  testWidgets('pharmacy shelf adapter blocks create anyway on exact match', (
    WidgetTester tester,
  ) async {
    await setLargeSurface(tester);
    const PharmacyStorageShelf existing = PharmacyStorageShelf(
      id: 'shelf-1',
      shelfCode: 'SH001',
      label: 'Shelf A',
    );
    PharmacyStorageShelfSimilarityDialogResult? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showPharmacyStorageShelfSimilarityDialog(
                    context,
                    proposed:
                        const PharmacyStorageShelfSimilarityProposedValues(
                          label: 'Shelf A',
                          shelfCode: 'SH001',
                        ),
                    check: const PharmacyStorageShelfSimilarityResult(
                      exactLabelConflict: true,
                      exactCodeConflict: true,
                      closestScore: 100,
                      matches: <PharmacyStorageShelfSimilarityMatch>[
                        PharmacyStorageShelfSimilarityMatch(
                          shelf: existing,
                          score: 100,
                          isExact: true,
                          exactLabelConflict: true,
                          exactCodeConflict: true,
                          fieldComparisons:
                              <PharmacyStorageShelfFieldComparison>[
                                PharmacyStorageShelfFieldComparison(
                                  field: 'label',
                                  inputValue: 'Shelf A',
                                  candidateValue: 'Shelf A',
                                  score: 100,
                                  status: 'MATCH',
                                ),
                                PharmacyStorageShelfFieldComparison(
                                  field: 'shelf_code',
                                  inputValue: 'SH001',
                                  candidateValue: 'SH001',
                                  score: 100,
                                  status: 'MATCH',
                                ),
                              ],
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Use this shelf'), findsOneWidget);
    expect(find.text('Create anyway'), findsNothing);
    expect(find.text('Check again'), findsOneWidget);

    final Finder useExisting = find.text('Use this shelf');
    await tester.ensureVisible(useExisting);
    await tester.pumpAndSettle();
    await tester.tap(useExisting);
    await tester.pumpAndSettle();

    expect(
      result?.action,
      PharmacyStorageShelfSimilarityAction.useExisting,
    );
    expect(result?.selectedShelf?.id, 'shelf-1');
  });

  testWidgets('pharmacy shelf adapter allows create anyway for near matches', (
    WidgetTester tester,
  ) async {
    await setLargeSurface(tester);
    const PharmacyStorageShelf existing = PharmacyStorageShelf(
      id: 'shelf-1',
      shelfCode: 'SH001',
      label: 'Shelf A',
    );
    PharmacyStorageShelfSimilarityDialogResult? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showPharmacyStorageShelfSimilarityDialog(
                    context,
                    proposed:
                        const PharmacyStorageShelfSimilarityProposedValues(
                          label: 'Shelf B',
                          shelfCode: 'SH002',
                        ),
                    check: const PharmacyStorageShelfSimilarityResult(
                      closestScore: 82,
                      matches: <PharmacyStorageShelfSimilarityMatch>[
                        PharmacyStorageShelfSimilarityMatch(
                          shelf: existing,
                          score: 82,
                          labelScore: 85,
                          codeScore: 70,
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Create anyway'), findsOneWidget);
    await tester.tap(find.text('Create anyway'));
    await tester.pumpAndSettle();

    expect(result?.action, PharmacyStorageShelfSimilarityAction.proceed);
  });
}
