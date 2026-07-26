import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/facility_catalog/clinical_catalog_admin_dialogs.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog.dart';

void main() {
  tearDown(() {
    debugLabCatalogSimilarityPaintDelay = Duration.zero;
  });

  group('LabCatalogItemMutationDialog', () {
    testWidgets('create test shows ordered comprehensive fields', (
      WidgetTester tester,
    ) async {
      await _pumpMutationDialog(tester);

      expect(find.text('CREATE LAB TEST'), findsOneWidget);
      expect(find.text('Test identity'), findsOneWidget);
      expect(find.text('Result configuration'), findsOneWidget);
      expect(find.text('Reference ranges'), findsOneWidget);
      expect(find.text('Add reference range'), findsOneWidget);
      expect(find.text('All ages'), findsWidgets);
      expect(find.widgetWithText(AppButton, 'Save'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Cancel'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is AppSelectField<String> &&
              widget.labelText == 'Result kind',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is AppSelectField<String> &&
              widget.labelText == 'Category',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is AppSelectField<String> &&
              widget.labelText == 'Specimen type',
        ),
        findsOneWidget,
      );
      expect(find.byType(LabEditableValueListField), findsOneWidget);
      expect(find.byType(LabReferenceRangeListField), findsOneWidget);
      expect(find.byType(LabTestDefinitionForm), findsOneWidget);

      // Add control sits above range cards (top of reference-range block).
      final double addY = tester.getTopLeft(find.text('Add reference range')).dy;
      final double allAgesY =
          tester.getTopLeft(find.text('All ages').first).dy;
      expect(addY, lessThan(allAgesY));
    });

    testWidgets('qualitative kind shows result options and hides unit options', (
      WidgetTester tester,
    ) async {
      await _pumpMutationDialog(tester);

      await _selectResultKind(tester, 'QUALITATIVE');

      expect(find.byType(LabEditableValueListField), findsOneWidget);
      final LabEditableValueListField optionsField = tester
          .widget<LabEditableValueListField>(
            find.byType(LabEditableValueListField),
          );
      expect(optionsField.labelText, 'Qualitative result options');
    });

    testWidgets('save with no similar matches submits without review modal', (
      WidgetTester tester,
    ) async {
      Map<String, Object?>? submitted;
      await _pumpMutationDialog(
        tester,
        onSubmit: (Map<String, Object?> payload) async {
          submitted = payload;
          return null;
        },
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'Glucose');
      await tester.enterText(find.byType(TextFormField).at(1), 'GLU');
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Save'));
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // No matches → skip the similarity modal and save directly.
      expect(find.text('SIMILAR LAB TEST FOUND'), findsNothing);
      expect(find.text('NO SIMILAR LAB TEST FOUND'), findsNothing);
      expect(submitted, isNotNull);
      expect(submitted!['name'], 'Glucose');
      expect(submitted!['code'], 'GLU');
      expect(submitted!['tenant_id'], 'tenant-1');
      expect(submitted!['result_kind'], 'NUMERIC');
      expect(submitted!['specimen_type'], isA<String>());
      expect(submitted!['unit_options'], isA<List<Object?>>());
      expect(submitted!['result_options'], isA<List<Object?>>());
      expect(submitted!['reference_ranges'], isA<List<Object?>>());
      expect(submitted!.containsKey('confirm_similar'), isFalse);
      final List<Object?> ranges =
          submitted!['reference_ranges']! as List<Object?>;
      expect(ranges, isNotEmpty);
      final Map<String, Object?> firstRange =
          Map<String, Object?>.from(ranges.first! as Map<dynamic, dynamic>);
      expect(firstRange['label'], 'All ages');
      expect(firstRange['age_min_value'], isNull);
      expect(firstRange['notes'], isNull);
    });

    testWidgets('exact duplicate name opens similarity modal with create anyway', (
      WidgetTester tester,
    ) async {
      Map<String, Object?>? submitted;
      await _pumpMutationDialog(
        tester,
        onSubmit: (Map<String, Object?> payload) async {
          submitted = payload;
          return null;
        },
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Hemoglobin',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'HB-NEW');
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Save'));
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SIMILAR LAB TEST FOUND'), findsOneWidget);
      expect(find.text('Match status: Exact duplicate'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Use this test'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Create anyway'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Create anyway'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(submitted, isNotNull);
      expect(submitted!['confirm_similar'], isTrue);
    });

    testWidgets('exact duplicate name opens modal even when category differs', (
      WidgetTester tester,
    ) async {
      Map<String, Object?>? submitted;
      await _pumpMutationDialog(
        tester,
        catalogItems: const <LabCatalogItem>[
          LabCatalogItem(
            id: 'LBT1',
            type: LabCatalogItemType.test,
            name: 'test',
            code: 'OTHER',
            category: 'Chemistry',
          ),
        ],
        onSubmit: (Map<String, Object?> payload) async {
          submitted = payload;
          return null;
        },
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'test');
      await tester.enterText(find.byType(TextFormField).at(1), 'test');
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Save'));
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SIMILAR LAB TEST FOUND'), findsOneWidget);
      expect(find.text('Match status: Exact duplicate'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Use this test'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Create anyway'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Create anyway'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(submitted!['confirm_similar'], isTrue);
    });

    testWidgets('exact duplicate code opens similarity modal with create anyway', (
      WidgetTester tester,
    ) async {
      Map<String, Object?>? submitted;
      await _pumpMutationDialog(
        tester,
        onSubmit: (Map<String, Object?> payload) async {
          submitted = payload;
          return null;
        },
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'Other Test');
      await tester.enterText(find.byType(TextFormField).at(1), 'HB');
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Save'));
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SIMILAR LAB TEST FOUND'), findsOneWidget);
      expect(find.text('Match status: Exact duplicate'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Use this test'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Create anyway'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Create anyway'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(submitted!['confirm_similar'], isTrue);
    });

    testWidgets('edit excludes current test id and still offers save anyway', (
      WidgetTester tester,
    ) async {
      Map<String, Object?>? submitted;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return AppButton.primary(
                  label: 'Open',
                  onPressed: () {
                    showAppDialog<Object>(
                      context: context,
                      builder: (_) => LabCatalogItemMutationDialog(
                        kind: LabCatalogItemType.test,
                        tenantId: 'tenant-1',
                        item: const LabCatalogItem(
                          id: 'lab-uuid-1',
                          displayId: 'LAB0000001',
                          type: LabCatalogItemType.test,
                          name: 'Hemoglobin',
                          code: 'HB',
                          category: 'Hematology',
                          resultKind: 'NUMERIC',
                        ),
                        catalogItems: const <LabCatalogItem>[
                          LabCatalogItem(
                            id: 'lab-uuid-1',
                            displayId: 'LAB0000001',
                            type: LabCatalogItemType.test,
                            name: 'Hemoglobin',
                            code: 'HB',
                            category: 'Hematology',
                          ),
                          LabCatalogItem(
                            id: 'lab-uuid-2',
                            displayId: 'LAB0000002',
                            type: LabCatalogItemType.test,
                            name: 'Complete Blood Count',
                            code: 'CBC-001',
                            category: 'Hematology',
                          ),
                        ],
                        onSubmit: (Map<String, Object?> payload) async {
                          submitted = payload;
                          return null;
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Unchanged exact self identity should not count as a conflict.
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Save'));
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SIMILAR LAB TEST FOUND'), findsNothing);
      expect(submitted, isNotNull);
      expect(submitted!.containsKey('confirm_similar'), isFalse);
      expect(submitted!['name'], 'Hemoglobin');
    });

    testWidgets('near-match proceed sends confirm_similar', (
      WidgetTester tester,
    ) async {
      Map<String, Object?>? submitted;
      await _pumpMutationDialog(
        tester,
        catalogItems: const <LabCatalogItem>[
          LabCatalogItem(
            id: 'LBT1',
            type: LabCatalogItemType.test,
            name: 'Complete Blood Count',
            code: 'CBC-001',
            category: 'Hematology',
          ),
        ],
        onSubmit: (Map<String, Object?> payload) async {
          submitted = payload;
          return null;
        },
      );

      // Typo near-match against existing CBC (domain threshold fixture).
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Complete Blood Countt',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'CBC-NEW');
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Save'));
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.widgetWithText(AppButton, 'Create anyway'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Create anyway'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(submitted, isNotNull);
      expect(submitted!['confirm_similar'], isTrue);
      expect(submitted!['name'], 'Complete Blood Countt');
    });

    testWidgets('clearing name after proceed resets confirm_similar', (
      WidgetTester tester,
    ) async {
      final List<Map<String, Object?>> submissions = <Map<String, Object?>>[];
      await _pumpMutationDialog(
        tester,
        catalogItems: const <LabCatalogItem>[
          LabCatalogItem(
            id: 'LBT1',
            type: LabCatalogItemType.test,
            name: 'Complete Blood Count',
            code: 'CBC-001',
            category: 'Hematology',
          ),
        ],
        onSubmit: (Map<String, Object?> payload) async {
          submissions.add(payload);
          // Keep dialog open so acceptance state can be cleared.
          return AppFailure.validation();
        },
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Complete Blood Countt',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'CBC-NEW');
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Save'));
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.widgetWithText(AppButton, 'Create anyway'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(submissions, hasLength(1));
      expect(submissions.first['confirm_similar'], isTrue);

      // Rename to a unique value — clears prior similarity acceptance and
      // saves directly when the scan finds no matches.
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Unique Serum Zinc Assay',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'ZN-UNIQUE');
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Save'));
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.widgetWithText(AppButton, 'Continue save'), findsNothing);
      expect(submissions, hasLength(2));
      expect(submissions.last.containsKey('confirm_similar'), isFalse);
      expect(submissions.last['name'], 'Unique Serum Zinc Assay');
    });

    testWidgets('near-match use existing returns selected catalog item', (
      WidgetTester tester,
    ) async {
      Object? dialogResult;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: Center(
                  child: AppButton.primary(
                    label: 'Open',
                    onPressed: () async {
                      dialogResult = await showAppDialog<Object>(
                        context: context,
                        builder: (_) => LabCatalogItemMutationDialog(
                          kind: LabCatalogItemType.test,
                          tenantId: 'tenant-1',
                          catalogItems: const <LabCatalogItem>[
                            LabCatalogItem(
                              id: 'LBT1',
                              type: LabCatalogItemType.test,
                              name: 'Complete Blood Count',
                              code: 'CBC-001',
                              category: 'Hematology',
                            ),
                          ],
                          onSubmit: (_) async => null,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Complete Blood Countt',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'CBC-NEW');
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Save'));
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.widgetWithText(AppButton, 'Use this test'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Use this test'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Use this test'));
      await tester.pumpAndSettle();

      expect(dialogResult, isA<LabCatalogItem>());
      final LabCatalogItem selected = dialogResult! as LabCatalogItem;
      expect(selected.id, 'LBT1');
      expect(selected.name, 'Complete Blood Count');
    });

    testWidgets('Cancel stays enabled during similarity scan', (
      WidgetTester tester,
    ) async {
      debugLabCatalogSimilarityPaintDelay = const Duration(seconds: 2);
      await _pumpMutationDialog(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'Glucose');
      await tester.enterText(find.byType(TextFormField).at(1), 'GLU');
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Save'));
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump(); // start scan; delay keeps checking state

      expect(find.text('Checking similarity'), findsWidgets);
      final AppButton cancel = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Cancel'),
      );
      expect(cancel.onPressed, isNotNull);
      expect(cancel.enabled, isTrue);

      await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
      await tester.pump();
      // Flush the similarity paint delay so no pending timers remain.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('CREATE LAB TEST'), findsNothing);
    });

    testWidgets('duplicate reference range blocks add when All ages defaults collide', (
      WidgetTester tester,
    ) async {
      var submitCount = 0;
      await _pumpMutationDialog(
        tester,
        onSubmit: (_) async {
          submitCount += 1;
          return null;
        },
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'Glucose');
      await tester.enterText(find.byType(TextFormField).at(1), 'GLU');
      await tester.ensureVisible(find.text('Add reference range'));
      await tester.tap(find.text('Add reference range'));
      await tester.pumpAndSettle();

      // First range already defaults to All ages / All genders — a second
      // identical range is rejected at add time.
      expect(find.byType(LabReferenceRangeListField), findsOneWidget);
      expect(find.text('All ages'), findsWidgets);
      expect(
        find.text(
          'A reference range with the same label already covers this gender and age (including All genders / All ages).',
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(find.widgetWithText(AppButton, 'Save'));
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Duplicate add was blocked, so the form still has one valid range and
      // a unique name — save proceeds without opening a similarity modal.
      expect(submitCount, 1);
      expect(find.text('SIMILAR LAB TEST FOUND'), findsNothing);
    });

    testWidgets('create panel requires member tests and submits panel_items after similarity', (
      WidgetTester tester,
    ) async {
      Map<String, Object?>? submitted;
      await _pumpMutationDialog(
        tester,
        kind: LabCatalogItemType.panel,
        onSubmit: (Map<String, Object?> payload) async {
          submitted = payload;
          return null;
        },
        catalogItems: const <LabCatalogItem>[
          LabCatalogItem(
            id: 'LBT1',
            type: LabCatalogItemType.test,
            name: 'Hemoglobin',
            code: 'HB',
            category: 'Hematology',
          ),
          LabCatalogItem(
            id: 'LBT2',
            type: LabCatalogItemType.test,
            name: 'White Blood Cell Count',
            code: 'WBC',
            category: 'Hematology',
          ),
          LabCatalogItem(
            id: 'LBP1',
            type: LabCatalogItemType.panel,
            name: 'Existing Panel',
            code: 'EP-1',
            category: 'Hematology',
            panelItems: <LabPanelItem>[
              LabPanelItem(id: 'pi1', labTestId: 'LBT1', testCode: 'HB'),
            ],
          ),
        ],
      );

      // Step 1: panel details with Next (no Save yet).
      expect(find.text('CREATE LAB PANEL'), findsOneWidget);
      expect(find.text('Panel details'), findsWidgets);
      expect(find.widgetWithText(AppButton, 'Next'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Save'), findsNothing);

      // Next without a name stays on the details step.
      await tester.tap(find.widgetWithText(AppButton, 'Next'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppButton, 'Save'), findsNothing);

      await tester.enterText(find.byType(TextFormField).at(0), 'New CBC Panel');
      await tester.enterText(find.byType(TextFormField).at(1), 'CBC-NEW');
      await tester.tap(find.widgetWithText(AppButton, 'Next'));
      await tester.pumpAndSettle();

      // Step 2: searchable multi-select member-test table.
      expect(find.byType(LabPanelTestSelectionTable), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Back'), findsOneWidget);
      expect(find.text('Hemoglobin'), findsWidgets);

      await tester.ensureVisible(find.widgetWithText(AppButton, 'Save'));
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Select at least one lab test for this panel.'),
        findsOneWidget,
      );
      expect(submitted, isNull);

      // Drive membership through the selection-table toggle (avoids footer
      // overlay hit-test misses on the first checkbox).
      final LabPanelTestSelectionTable table = tester
          .widget<LabPanelTestSelectionTable>(
            find.byType(LabPanelTestSelectionTable),
          );
      table.onToggle(table.tests.first);
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(AppButton, 'Save'));
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SIMILAR LAB PANEL FOUND'), findsOneWidget);
      // Selected HB overlaps Existing Panel membership, so composition surfaces
      // a near match rather than a 0% empty review.
      expect(find.widgetWithText(AppButton, 'Create anyway'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Create anyway'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(submitted, isNotNull);
      expect(submitted!['name'], 'New CBC Panel');
      expect(submitted!['code'], 'CBC-NEW');
      expect(submitted!['tenant_id'], 'tenant-1');
      expect(submitted!['confirm_similar'], isTrue);
      final List<Object?> items =
          submitted!['panel_items']! as List<Object?>;
      expect(items, hasLength(1));
      final Map<String, Object?> first =
          Map<String, Object?>.from(items.first! as Map<dynamic, dynamic>);
      expect(first['lab_test_id'], 'LBT1');
      expect(first['test_code'], 'HB');
      expect(first['sort_order'], 0);
    });

    testWidgets('panel create with unique membership saves without review modal', (
      WidgetTester tester,
    ) async {
      Map<String, Object?>? submitted;
      await _pumpMutationDialog(
        tester,
        kind: LabCatalogItemType.panel,
        onSubmit: (Map<String, Object?> payload) async {
          submitted = payload;
          return null;
        },
        catalogItems: const <LabCatalogItem>[
          LabCatalogItem(
            id: 'LBT9',
            type: LabCatalogItemType.test,
            name: 'Zinc',
            code: 'ZN',
            category: 'Chemistry',
          ),
        ],
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'Zinc Panel');
      await tester.enterText(find.byType(TextFormField).at(1), 'ZN-P');
      await tester.tap(find.widgetWithText(AppButton, 'Next'));
      await tester.pumpAndSettle();

      final LabPanelTestSelectionTable table = tester
          .widget<LabPanelTestSelectionTable>(
            find.byType(LabPanelTestSelectionTable),
          );
      table.onToggle(table.tests.first);
      await tester.pump();

      await tester.ensureVisible(find.widgetWithText(AppButton, 'Save'));
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SIMILAR LAB PANEL FOUND'), findsNothing);
      expect(submitted, isNotNull);
      expect(submitted!.containsKey('confirm_similar'), isFalse);
      expect(submitted!['panel_items'], isA<List<Object?>>());
    });

    testWidgets('panel exact duplicate opens similarity modal with create anyway', (
      WidgetTester tester,
    ) async {
      Map<String, Object?>? submitted;
      await _pumpMutationDialog(
        tester,
        kind: LabCatalogItemType.panel,
        onSubmit: (Map<String, Object?> payload) async {
          submitted = payload;
          return null;
        },
        catalogItems: const <LabCatalogItem>[
          LabCatalogItem(
            id: 'LBT1',
            type: LabCatalogItemType.test,
            name: 'Hemoglobin',
            code: 'HB',
            category: 'Hematology',
          ),
          LabCatalogItem(
            id: 'LBP1',
            type: LabCatalogItemType.panel,
            name: 'CBC Panel',
            code: 'CBC-P',
            category: 'Hematology',
            panelItems: <LabPanelItem>[
              LabPanelItem(id: 'pi1', labTestId: 'LBT1', testCode: 'HB'),
            ],
          ),
        ],
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'CBC Panel');
      await tester.enterText(find.byType(TextFormField).at(1), 'CBC-NEW');
      await tester.tap(find.widgetWithText(AppButton, 'Next'));
      await tester.pumpAndSettle();

      final LabPanelTestSelectionTable table = tester
          .widget<LabPanelTestSelectionTable>(
            find.byType(LabPanelTestSelectionTable),
          );
      table.onToggle(table.tests.first);
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(AppButton, 'Save'));
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SIMILAR LAB PANEL FOUND'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Create anyway'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Create anyway'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(submitted, isNotNull);
      expect(submitted!['confirm_similar'], isTrue);
    });

    testWidgets('text kind hides unit and qualitative options', (
      WidgetTester tester,
    ) async {
      await _pumpMutationDialog(tester);

      await _selectResultKind(tester, 'TEXT');

      expect(find.byType(LabEditableValueListField), findsNothing);
      expect(find.byType(LabReferenceRangeListField), findsOneWidget);
      expect(find.text('Add reference range'), findsOneWidget);
    });
  });
}

Future<void> _selectResultKind(WidgetTester tester, String value) async {
  final Finder resultKindField = find.byWidgetPredicate(
    (Widget widget) =>
        widget is AppSelectField<String> && widget.labelText == 'Result kind',
  );
  expect(resultKindField, findsOneWidget);
  final AppSelectField<String> field = tester.widget(resultKindField);
  field.onChanged?.call(value);
  await tester.pumpAndSettle();
}

Future<void> _pumpMutationDialog(
  WidgetTester tester, {
  Future<AppFailure?> Function(Map<String, Object?> payload)? onSubmit,
  LabCatalogItemType kind = LabCatalogItemType.test,
  List<LabCatalogItem> catalogItems = const <LabCatalogItem>[
    LabCatalogItem(
      id: 'LBT1',
      type: LabCatalogItemType.test,
      name: 'Hemoglobin',
      code: 'HB',
      category: 'Hematology',
      specimenType: 'Whole blood',
      unit: 'g/dL',
    ),
  ],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return AppButton.primary(
              label: 'Open',
              onPressed: () {
                showAppDialog<Object>(
                  context: context,
                  builder: (_) => LabCatalogItemMutationDialog(
                    kind: kind,
                    tenantId: 'tenant-1',
                    catalogItems: catalogItems,
                    onSubmit: onSubmit ?? (_) async => null,
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}
