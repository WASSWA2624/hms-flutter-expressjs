import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_drug_similarity_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

void main() {
  Future<void> setLargeSurface(WidgetTester tester) async {
    final TestFlutterView view = tester.view;
    view.physicalSize = const Size(1400, 1800);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  }

  testWidgets('drug adapter allows create anyway on exact match', (
    WidgetTester tester,
  ) async {
    await setLargeSurface(tester);
    const PharmacyDrug existing = PharmacyDrug(
      id: 'drug-1',
      name: 'Amoxicillin',
      genericName: 'Amoxicillin',
      brandName: 'Amoxil',
      code: 'AMX-500',
      form: 'Capsule',
      strength: '500mg',
    );
    PharmacyDrugSimilarityDialogResult? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showPharmacyDrugSimilarityDialog(
                    context,
                    proposed: const PharmacyDrugSimilarityProposedValues(
                      genericName: 'Amoxicillin',
                      brandName: 'Amoxil',
                      code: 'AMX-500',
                      form: 'Capsule',
                      strength: '500mg',
                    ),
                    check: const PharmacyDrugSimilarityResult(
                      exactIdentityConflict: true,
                      exactCodeConflict: true,
                      closestScore: 100,
                      matches: <PharmacyDrugSimilarityMatch>[
                        PharmacyDrugSimilarityMatch(
                          drug: existing,
                          score: 100,
                          isExact: true,
                          exactIdentityConflict: true,
                          exactCodeConflict: true,
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
    expect(find.text('Use this drug'), findsOneWidget);
    expect(find.text('Replace this drug'), findsOneWidget);

    await tester.tap(find.text('Create anyway'));
    await tester.pumpAndSettle();

    expect(result?.action, PharmacyDrugSimilarityAction.proceed);
  });

  testWidgets('drug adapter replace existing returns proposed values', (
    WidgetTester tester,
  ) async {
    await setLargeSurface(tester);
    const PharmacyDrug existing = PharmacyDrug(
      id: 'drug-1',
      name: 'Amoxicillin',
      genericName: 'Amoxicillin',
      brandName: 'Amoxil',
      code: 'AMX-500',
      form: 'Capsule',
      strength: '500mg',
    );
    PharmacyDrugSimilarityDialogResult? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showPharmacyDrugSimilarityDialog(
                    context,
                    proposed: const PharmacyDrugSimilarityProposedValues(
                      genericName: 'Amoxicillin Trihydrate',
                      brandName: 'Amoxil Forte',
                      code: 'AMX-500',
                      form: 'Capsule',
                      strength: '500mg',
                    ),
                    check: const PharmacyDrugSimilarityResult(
                      exactIdentityConflict: true,
                      exactCodeConflict: true,
                      closestScore: 100,
                      matches: <PharmacyDrugSimilarityMatch>[
                        PharmacyDrugSimilarityMatch(
                          drug: existing,
                          score: 100,
                          isExact: true,
                          exactIdentityConflict: true,
                          exactCodeConflict: true,
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
    expect(find.text('Replace this drug'), findsOneWidget);

    await tester.tap(find.text('Replace this drug'));
    await tester.pumpAndSettle();

    expect(result?.action, PharmacyDrugSimilarityAction.replaceExisting);
    expect(result?.selectedDrug?.id, 'drug-1');
    expect(result?.proposed?.genericName, 'Amoxicillin Trihydrate');
    expect(result?.proposed?.brandName, 'Amoxil Forte');
  });

  testWidgets('drug adapter hides replace when editing', (
    WidgetTester tester,
  ) async {
    await setLargeSurface(tester);
    const PharmacyDrug existing = PharmacyDrug(
      id: 'drug-1',
      name: 'Amoxicillin',
      genericName: 'Amoxicillin',
      code: 'AMX-500',
    );
    PharmacyDrugSimilarityDialogResult? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showPharmacyDrugSimilarityDialog(
                    context,
                    isEdit: true,
                    proposed: const PharmacyDrugSimilarityProposedValues(
                      genericName: 'Amoxicillin',
                      code: 'AMX-500',
                    ),
                    check: const PharmacyDrugSimilarityResult(
                      exactIdentityConflict: true,
                      closestScore: 100,
                      matches: <PharmacyDrugSimilarityMatch>[
                        PharmacyDrugSimilarityMatch(
                          drug: existing,
                          score: 100,
                          isExact: true,
                          exactIdentityConflict: true,
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

    expect(find.text('Replace this drug'), findsNothing);
    expect(find.text('Use this drug'), findsOneWidget);
    expect(find.text('Create anyway'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('drug adapter allows create anyway on near match', (
    WidgetTester tester,
  ) async {
    await setLargeSurface(tester);
    const PharmacyDrug existing = PharmacyDrug(
      id: 'drug-2',
      name: 'Amoxicillin',
      genericName: 'Amoxicillin',
      code: 'AMX-501',
      form: 'Capsule',
      strength: '500mg',
    );
    PharmacyDrugSimilarityDialogResult? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showPharmacyDrugSimilarityDialog(
                    context,
                    proposed: const PharmacyDrugSimilarityProposedValues(
                      genericName: 'Amoxicilin',
                      code: 'AMX-502',
                      form: 'Capsule',
                      strength: '500mg',
                    ),
                    check: const PharmacyDrugSimilarityResult(
                      closestScore: 86,
                      matches: <PharmacyDrugSimilarityMatch>[
                        PharmacyDrugSimilarityMatch(
                          drug: existing,
                          score: 86,
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

    expect(result?.action, PharmacyDrugSimilarityAction.proceed);
  });
}
