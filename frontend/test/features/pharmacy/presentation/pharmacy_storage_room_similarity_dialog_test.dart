import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_storage_room_similarity_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

void main() {
  Future<void> setLargeSurface(WidgetTester tester) async {
    final TestFlutterView view = tester.view;
    view.physicalSize = const Size(1400, 1800);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  }

  testWidgets('pharmacy adapter allows create anyway on exact match', (
    WidgetTester tester,
  ) async {
    await setLargeSurface(tester);
    const PharmacyStorageRoom existing = PharmacyStorageRoom(
      id: 'room-1',
      name: 'Room 1',
      code: 'RM001',
    );
    PharmacyStorageRoomSimilarityDialogResult? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showPharmacyStorageRoomSimilarityDialog(
                    context,
                    proposed:
                        const PharmacyStorageRoomSimilarityProposedValues(
                          name: 'Room 1',
                          code: 'RM001',
                        ),
                    check: const PharmacyStorageRoomSimilarityResult(
                      exactNameConflict: true,
                      exactCodeConflict: true,
                      closestScore: 100,
                      matches: <PharmacyStorageRoomSimilarityMatch>[
                        PharmacyStorageRoomSimilarityMatch(
                          room: existing,
                          score: 100,
                          isExact: true,
                          exactNameConflict: true,
                          exactCodeConflict: true,
                          fieldComparisons: <PharmacyStorageRoomFieldComparison>[
                            PharmacyStorageRoomFieldComparison(
                              field: 'name',
                              inputValue: 'Room 1',
                              candidateValue: 'Room 1',
                              score: 100,
                              status: 'MATCH',
                            ),
                            PharmacyStorageRoomFieldComparison(
                              field: 'code',
                              inputValue: 'RM001',
                              candidateValue: 'RM001',
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

    expect(find.text('Use this room'), findsOneWidget);
    expect(find.text('Create anyway'), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);

    final Finder createAnyway = find.text('Create anyway');
    await tester.ensureVisible(createAnyway);
    await tester.pumpAndSettle();
    await tester.tap(createAnyway);
    await tester.pumpAndSettle();

    expect(
      result?.action,
      PharmacyStorageRoomSimilarityAction.proceed,
    );
  });

  testWidgets('pharmacy adapter allows create anyway for near matches', (
    WidgetTester tester,
  ) async {
    await setLargeSurface(tester);
    const PharmacyStorageRoom existing = PharmacyStorageRoom(
      id: 'room-1',
      name: 'Room 1',
      code: 'RM001',
    );
    PharmacyStorageRoomSimilarityDialogResult? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showPharmacyStorageRoomSimilarityDialog(
                    context,
                    proposed:
                        const PharmacyStorageRoomSimilarityProposedValues(
                          name: 'Room 01',
                          code: 'RM0001',
                        ),
                    check: const PharmacyStorageRoomSimilarityResult(
                      closestScore: 85,
                      matches: <PharmacyStorageRoomSimilarityMatch>[
                        PharmacyStorageRoomSimilarityMatch(
                          room: existing,
                          score: 85,
                          nameScore: 85,
                          codeScore: 80,
                          fieldComparisons: <PharmacyStorageRoomFieldComparison>[
                            PharmacyStorageRoomFieldComparison(
                              field: 'name',
                              inputValue: 'Room 01',
                              candidateValue: 'Room 1',
                              score: 85,
                              status: 'SIMILAR',
                            ),
                            PharmacyStorageRoomFieldComparison(
                              field: 'code',
                              inputValue: 'RM0001',
                              candidateValue: 'RM001',
                              score: 80,
                              status: 'SIMILAR',
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

    expect(find.text('Create anyway'), findsOneWidget);
    expect(find.text('Near match'), findsOneWidget);

    await tester.tap(find.text('Create anyway'));
    await tester.pumpAndSettle();

    expect(result?.action, PharmacyStorageRoomSimilarityAction.proceed);
  });
}
