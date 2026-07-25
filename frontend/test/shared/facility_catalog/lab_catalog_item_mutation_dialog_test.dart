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
      expect(find.text('Adult'), findsWidgets);
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
      final double adultY = tester.getTopLeft(find.text('Adult').first).dy;
      expect(addY, lessThan(adultY));
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

    testWidgets('save confirms no-similar then submits full test payload', (
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

      // Dialog title is normalized to uppercase; banner copy stays sentence case.
      expect(find.text('Match status: No similar found'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Continue save'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Continue save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(submitted, isNotNull);
      expect(submitted!['name'], 'Glucose');
      expect(submitted!['code'], 'GLU');
      expect(submitted!['tenant_id'], 'tenant-1');
      expect(submitted!['result_kind'], 'NUMERIC');
      expect(submitted!['specimen_type'], isA<String>());
      expect(submitted!['unit_options'], isA<List<Object?>>());
      expect(submitted!['result_options'], isA<List<Object?>>());
      expect(submitted!['reference_ranges'], isA<List<Object?>>());
      final List<Object?> ranges =
          submitted!['reference_ranges']! as List<Object?>;
      expect(ranges, isNotEmpty);
      final Map<String, Object?> firstRange =
          Map<String, Object?>.from(ranges.first! as Map<dynamic, dynamic>);
      expect(firstRange['label'], 'Adult');
      expect(firstRange['age_min_value'], isNull);
      expect(firstRange['notes'], isNull);
    });

    testWidgets('exact duplicate name blocks save without submit', (
      WidgetTester tester,
    ) async {
      var submitCount = 0;
      await _pumpMutationDialog(
        tester,
        onSubmit: (Map<String, Object?> payload) async {
          submitCount += 1;
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

      expect(submitCount, 0);
      expect(
        find.text('A lab test with this name already exists.'),
        findsOneWidget,
      );
      expect(find.text('Match status: No similar found'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Continue save'), findsNothing);
    });

    testWidgets('exact duplicate code blocks save without submit', (
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

      await tester.enterText(find.byType(TextFormField).at(0), 'Other Test');
      await tester.enterText(find.byType(TextFormField).at(1), 'HB');
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Save'));
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(submitCount, 0);
      expect(
        find.text('A lab test with this code already exists.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppButton, 'Create anyway'), findsNothing);
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

      // Rename to a unique value — clears prior similarity acceptance.
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

      expect(find.widgetWithText(AppButton, 'Continue save'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Continue save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(submissions, hasLength(2));
      expect(submissions.last.containsKey('confirm_similar'), isFalse);
      expect(submissions.last['name'], 'Unique Serum Zinc Assay');
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

    testWidgets('duplicate reference range blocks save', (
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

      final Finder rangeLabelFields = find.byWidgetPredicate(
        (Widget widget) =>
            widget is AppSelectField<String> &&
            widget.labelText == 'Reference range',
      );
      expect(rangeLabelFields, findsNWidgets(2));
      final AppSelectField<String> secondLabel = tester.widget(
        rangeLabelFields.at(1),
      );
      secondLabel.onChanged?.call('Adult');
      await tester.pump();

      await tester.ensureVisible(find.widgetWithText(AppButton, 'Save'));
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(submitCount, 0);
      expect(
        find.text(
          'A reference range with the same label already covers this gender and age (including All genders / All ages).',
        ),
        findsOneWidget,
      );
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
                    kind: LabCatalogItemType.test,
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
