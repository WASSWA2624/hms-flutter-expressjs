import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_similarity.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  Future<void> setLargeSurface(WidgetTester tester) async {
    final TestFlutterView view = tester.view;
    view.physicalSize = const Size(1400, 1800);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  }

  testWidgets('exact conflict hides Save anyway and supports Use this', (
    WidgetTester tester,
  ) async {
    await setLargeSurface(tester);
    AppSimilarityReviewResult<String>? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showAppSimilarityReviewDialog<String>(
                    context,
                    title: 'Duplicate',
                    bannerTitle: 'Exact match found',
                    bannerMessage: 'An exact match already exists.',
                    bannerVariant: AppFormInformationVariant.error,
                    proposedFields: const <AppSimilarityProposedField>[
                      AppSimilarityProposedField(
                        key: 'name',
                        label: 'Name',
                        initialValue: 'Room 1',
                        isRequired: true,
                      ),
                    ],
                    matches: const <AppSimilarityMatch<String>>[
                      AppSimilarityMatch<String>(
                        item: 'room-1',
                        title: 'Room 1',
                        subtitle: 'RM001',
                        overallScore: 100,
                        isExact: true,
                        fields: <AppSimilarityFieldRow>[
                          AppSimilarityFieldRow(
                            key: 'name',
                            label: 'Name',
                            proposedValue: 'Room 1',
                            existingValue: 'Room 1',
                            score: 100,
                          ),
                        ],
                      ),
                    ],
                    overallScore: 100,
                    blockProceed: true,
                    useThisLabel: 'Use this room',
                    proceedLabel: 'Save anyway',
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

    expect(find.text('Save anyway'), findsNothing);
    expect(find.text('Use this room'), findsOneWidget);
    expect(find.text('Replace existing'), findsNothing);
    expect(find.text('Check again'), findsOneWidget);

    final Finder useThis = find.text('Use this room');
    await tester.ensureVisible(useThis);
    await tester.pumpAndSettle();
    await tester.tap(useThis);
    await tester.pumpAndSettle();

    expect(result?.action, AppSimilarityReviewAction.useExisting);
    expect(result?.selected, 'room-1');
  });

  testWidgets('near match allows Save anyway and Retry returns edited values', (
    WidgetTester tester,
  ) async {
    await setLargeSurface(tester);
    AppSimilarityReviewResult<String>? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showAppSimilarityReviewDialog<String>(
                    context,
                    title: 'Similar',
                    bannerTitle: 'Review similar',
                    bannerMessage: 'Closest match 85%.',
                    bannerVariant: AppFormInformationVariant.warning,
                    proposedFields: const <AppSimilarityProposedField>[
                      AppSimilarityProposedField(
                        key: 'name',
                        label: 'Name',
                        initialValue: 'Room 01',
                        isRequired: true,
                      ),
                    ],
                    matches: const <AppSimilarityMatch<String>>[
                      AppSimilarityMatch<String>(
                        item: 'room-1',
                        title: 'Room 1',
                        overallScore: 85,
                        fields: <AppSimilarityFieldRow>[
                          AppSimilarityFieldRow(
                            key: 'name',
                            label: 'Name',
                            proposedValue: 'Room 01',
                            existingValue: 'Room 1',
                            score: 85,
                          ),
                        ],
                      ),
                    ],
                    overallScore: 85,
                    proceedLabel: 'Save anyway',
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

    expect(find.text('Save anyway'), findsOneWidget);
    expect(find.text('Near match'), findsOneWidget);

    // Proposed section is collapsed by default — expand before editing.
    await tester.tap(find.text('Proposed values'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Room Alpha');
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();

    expect(result?.action, AppSimilarityReviewAction.retry);
    expect(result?.proposedValues['name'], 'Room Alpha');
  });

  testWidgets('read-only mode hides Check again and text fields', (
    WidgetTester tester,
  ) async {
    await setLargeSurface(tester);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  await showAppSimilarityReviewDialog<String>(
                    context,
                    title: 'Similar',
                    bannerTitle: 'Review similar',
                    bannerMessage: 'Closest match 80%.',
                    bannerVariant: AppFormInformationVariant.warning,
                    proposedFields: const <AppSimilarityProposedField>[
                      AppSimilarityProposedField(
                        key: 'name',
                        label: 'Name',
                        initialValue: 'Room 01',
                        isRequired: true,
                      ),
                    ],
                    matches: const <AppSimilarityMatch<String>>[
                      AppSimilarityMatch<String>(
                        item: 'room-1',
                        title: 'Room 1',
                        overallScore: 80,
                        fields: <AppSimilarityFieldRow>[
                          AppSimilarityFieldRow(
                            key: 'name',
                            label: 'Name',
                            proposedValue: 'Room 01',
                            existingValue: 'Room 1',
                            score: 80,
                          ),
                        ],
                      ),
                    ],
                    overallScore: 80,
                    enableRetry: false,
                    proposedReadOnly: true,
                    proceedLabel: 'Save anyway',
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

    expect(find.text('Check again'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('Closest match: 80%'), findsOneWidget);
    expect(find.text('Save anyway'), findsOneWidget);
  });

  testWidgets('proposed section is collapsed and shows closest match in title', (
    WidgetTester tester,
  ) async {
    await setLargeSurface(tester);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  await showAppSimilarityReviewDialog<String>(
                    context,
                    title: 'Similar',
                    bannerTitle: 'Review similar',
                    bannerMessage: 'Closest match 91%.',
                    bannerVariant: AppFormInformationVariant.warning,
                    proposedFields: const <AppSimilarityProposedField>[
                      AppSimilarityProposedField(
                        key: 'name',
                        label: 'Name',
                        initialValue: 'Room 10',
                        isRequired: true,
                      ),
                      AppSimilarityProposedField(
                        key: 'code',
                        label: 'Code',
                        initialValue: 'RM003',
                      ),
                    ],
                    matches: const <AppSimilarityMatch<String>>[
                      AppSimilarityMatch<String>(
                        item: 'room-1',
                        title: 'Room 1',
                        overallScore: 91,
                        fields: <AppSimilarityFieldRow>[
                          AppSimilarityFieldRow(
                            key: 'name',
                            label: 'Name',
                            proposedValue: 'Room 10',
                            existingValue: 'Room 1',
                            score: 96,
                          ),
                        ],
                      ),
                    ],
                    overallScore: 91,
                    proposedHeading: 'Proposed room',
                    proceedLabel: 'Save anyway',
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

    expect(find.text('Proposed room'), findsOneWidget);
    expect(find.textContaining('Closest match: 91%'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Proposed room'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets(
    'replace existing returns selected item and edited proposed values',
    (WidgetTester tester) async {
      await setLargeSurface(tester);
      AppSimilarityReviewResult<String>? result;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showAppSimilarityReviewDialog<String>(
                      context,
                      title: 'Duplicate',
                      bannerTitle: 'Exact match found',
                      bannerMessage: 'An exact match already exists.',
                      bannerVariant: AppFormInformationVariant.error,
                      proposedFields: const <AppSimilarityProposedField>[
                        AppSimilarityProposedField(
                          key: 'name',
                          label: 'Name',
                          initialValue: 'Room 1',
                          isRequired: true,
                        ),
                      ],
                      matches: const <AppSimilarityMatch<String>>[
                        AppSimilarityMatch<String>(
                          item: 'room-1',
                          title: 'Room 1',
                          subtitle: 'RM001',
                          overallScore: 100,
                          isExact: true,
                          fields: <AppSimilarityFieldRow>[
                            AppSimilarityFieldRow(
                              key: 'name',
                              label: 'Name',
                              proposedValue: 'Room 1',
                              existingValue: 'Room 1',
                              score: 100,
                            ),
                          ],
                        ),
                      ],
                      overallScore: 100,
                      blockProceed: true,
                      enableReplaceExisting: true,
                      useThisLabel: 'Use this room',
                      replaceExistingLabel: 'Replace this room',
                      proceedLabel: 'Save anyway',
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

      expect(find.text('Save anyway'), findsNothing);
      expect(find.text('Use this room'), findsOneWidget);
      expect(find.text('Replace this room'), findsOneWidget);

      await tester.tap(find.text('Proposed values'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Room Beta');

      final Finder replace = find.text('Replace this room');
      await tester.ensureVisible(replace);
      await tester.pumpAndSettle();
      await tester.tap(replace);
      await tester.pumpAndSettle();

      expect(result?.action, AppSimilarityReviewAction.replaceExisting);
      expect(result?.selected, 'room-1');
      expect(result?.proposedValues['name'], 'Room Beta');
    },
  );
}
