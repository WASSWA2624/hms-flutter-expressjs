import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';

const List<ClinicalActionCatalogOption> _radiologyCatalogFixtures =
    <ClinicalActionCatalogOption>[
      ClinicalActionCatalogOption(
        id: 'ct-chest',
        publicId: 'RAD-CT-CHEST',
        name: 'CT chest',
        code: 'CT-CHEST',
        category: 'CT',
        searchText: 'ct chest thorax',
        metadata: <String, Object?>{
          'modality': 'CT',
          'body_region': 'Chest',
        },
      ),
    ];

Future<Result<List<ClinicalActionCatalogOption>>>
_mockSearchRadiologyTests({
  required String termType,
  String? query,
  int? limit,
  String source = 'ALL',
}) async {
  final String normalized = (query ?? '').trim().toLowerCase();
  if (normalized.isEmpty) {
    return const Result<List<ClinicalActionCatalogOption>>.success(
      _radiologyCatalogFixtures,
    );
  }
  final List<ClinicalActionCatalogOption> matches = _radiologyCatalogFixtures
      .where(
        (ClinicalActionCatalogOption option) => (option.name ?? '')
            .toLowerCase()
            .contains(normalized),
      )
      .toList(growable: false);
  return Result<List<ClinicalActionCatalogOption>>.success(matches);
}

void main() {
  testWidgets('radiology order dialog shows patient context and selected table', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(
      tester,
      ClinicalRadiologyOrderActionDialog(
        referenceData: const ClinicalActionReferenceData(
          radiologyTests: _radiologyCatalogFixtures,
        ),
        patientContext: const ClinicalRequestPatientContext(
          patientName: 'Jane Doe',
          patientId: 'PAT-001',
          encounterId: 'ENC-42',
        ),
        onSearchRadiologyTests: _mockSearchRadiologyTests,
        onSubmit:
            ({
              required List<ClinicalActionRadiologyRequest> requests,
              ClinicalRequestBillingSubmit? billing,
            }) async {
              return null;
            },
      ),
    );

    expect(find.textContaining('Patient name:'), findsOneWidget);
    expect(find.textContaining('Jane Doe'), findsOneWidget);
    expect(find.textContaining('PAT-001'), findsOneWidget);
    expect(find.textContaining('ENC-42'), findsOneWidget);
    expect(find.text('Add study'), findsOneWidget);
    expect(find.text('Review billing'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets(
    'radiology catalog search remains editable when a query has no matches',
    (WidgetTester tester) async {
      await _pumpDialog(
        tester,
        ClinicalRadiologyOrderActionDialog(
          referenceData: const ClinicalActionReferenceData(
            radiologyTests: _radiologyCatalogFixtures,
          ),
          onSearchRadiologyTests: _mockSearchRadiologyTests,
          onSubmit:
              ({
                required List<ClinicalActionRadiologyRequest> requests,
                ClinicalRequestBillingSubmit? billing,
              }) async {
                return null;
              },
        ),
      );

      await tester.tap(find.text('Add study'));
      await tester.pumpAndSettle();

      final Finder searchField = find.byWidgetPredicate(
        (Widget widget) =>
            widget is TextField &&
            widget.decoration?.hintText ==
                'Search by test, intervention, modality, region, code, or priority',
      );

      await tester.tap(searchField);
      await tester.enterText(searchField, 'not in catalog');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      TextField textField = tester.widget<TextField>(searchField);
      expect(textField.enabled, isTrue);
      expect(find.text('No matching radiology catalog items'), findsOneWidget);

      await tester.enterText(searchField, 'ct chest');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      textField = tester.widget<TextField>(searchField);
      expect(textField.enabled, isTrue);
      expect(textField.controller?.text, 'ct chest');
      expect(find.text('No matching radiology catalog items'), findsNothing);
      expect(find.text('CT chest'), findsOneWidget);
    },
  );

  testWidgets('radiology catalog picker confirms without cancel action', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(
      tester,
      ClinicalRadiologyOrderActionDialog(
        referenceData: const ClinicalActionReferenceData(
          radiologyTests: _radiologyCatalogFixtures,
        ),
        onSearchRadiologyTests: _mockSearchRadiologyTests,
        onSubmit:
            ({
              required List<ClinicalActionRadiologyRequest> requests,
              ClinicalRequestBillingSubmit? billing,
            }) async {
              return null;
            },
      ),
    );

    await tester.tap(find.text('Add study'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Confirm selected studies'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm selected studies'));
    await tester.pumpAndSettle();

    expect(find.text('CT chest'), findsOneWidget);
    expect(find.text('Choose imaging study'), findsNothing);
  });
}

Future<void> _pumpDialog(WidgetTester tester, Widget dialog) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: dialog),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
