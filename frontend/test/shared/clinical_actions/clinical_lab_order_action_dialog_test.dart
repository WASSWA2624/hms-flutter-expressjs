import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  test('orderClinicalLabRequestCatalogItems keeps selected rows first', () {
    final List<ClinicalActionCatalogOption> options = _sampleCatalogOptions();
    final List<ClinicalActionCatalogOption> ordered =
        orderClinicalLabRequestCatalogItems(
          options,
          includeOption: (_) => true,
          isSelected: (ClinicalActionCatalogOption option) =>
              option.apiId == 'LAB-LIPID',
        );

    expect(ordered.map((ClinicalActionCatalogOption option) => option.apiId), [
      'LAB-LIPID',
      'LAB-CBC',
    ]);
  });

  group('ClinicalLabOrderActionDialog', () {
    testWidgets('opens maximized without cancel and shows submit icon', (
      WidgetTester tester,
    ) async {
      await _pumpLabOrderDialog(tester);

      expect(find.text('Request lab'), findsWidgets);
      expect(find.text('Cancel'), findsNothing);
      expect(find.byIcon(Icons.fullscreen_exit), findsWidgets);
      expect(find.widgetWithIcon(AppButton, Icons.science_outlined), findsOneWidget);
    });

    testWidgets('catalog picker supports checkbox multi-select', (
      WidgetTester tester,
    ) async {
      await _pumpLabOrderDialog(
        tester,
        catalogOptions: _sampleCatalogOptions(),
      );

      await tester.tap(find.widgetWithText(AppButton, 'Add items'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('CHOOSE LAB TESTS'), findsOneWidget);
      expect(find.text('0 selected'), findsOneWidget);

      await _tapRowCheckbox(tester, 'Complete blood count');
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('1 item'), findsOneWidget);
    });

    testWidgets('loads facility catalog offerings only', (
      WidgetTester tester,
    ) async {
      String? capturedSource;
      final List<String> capturedTermTypes = <String>[];

      await _pumpLabOrderDialog(
        tester,
        catalogOptions: _sampleCatalogOptions(),
        onSearchLabTests:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'FACILITY',
            }) async {
              capturedSource = source;
              capturedTermTypes.add(termType);
              return Result.success(_sampleCatalogOptions());
            },
      );

      await tester.tap(find.widgetWithText(AppButton, 'Add items'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(capturedSource, 'FACILITY');
      expect(
        capturedTermTypes,
        contains(ClinicalCatalogTermType.labTest.apiValue),
      );
      expect(
        capturedTermTypes,
        contains(ClinicalCatalogTermType.labPanel.apiValue),
      );
    });
  });
}

Future<void> _tapRowCheckbox(WidgetTester tester, String rowLabel) async {
  expect(find.text(rowLabel), findsOneWidget);

  final List<String> rowLabels = <String>[
    'Complete blood count',
    'Lipid profile',
  ];
  rowLabels.sort((String left, String right) {
    return tester
        .getCenter(find.text(left))
        .dy
        .compareTo(tester.getCenter(find.text(right)).dy);
  });

  final int rowIndex = rowLabels.indexOf(rowLabel);
  expect(rowIndex, greaterThanOrEqualTo(0));
  await tester.tap(find.byType(Checkbox).at(rowIndex + 1));
}

List<ClinicalActionCatalogOption> _sampleCatalogOptions() {
  return <ClinicalActionCatalogOption>[
    const ClinicalActionCatalogOption(
      id: 'cbc',
      publicId: 'LAB-CBC',
      name: 'Complete blood count',
      code: 'CBC',
      category: 'Hematology',
      unitPrice: 25,
      currency: 'USD',
      searchText: 'complete blood count cbc hematology',
    ),
    const ClinicalActionCatalogOption(
      id: 'lipid',
      publicId: 'LAB-LIPID',
      name: 'Lipid profile',
      code: 'LIPID',
      category: 'Chemistry',
      unitPrice: 40,
      currency: 'USD',
      searchText: 'lipid profile chemistry',
    ),
  ];
}

Future<void> _pumpLabOrderDialog(
  WidgetTester tester, {
  List<ClinicalActionCatalogOption> catalogOptions =
      const <ClinicalActionCatalogOption>[],
  Future<Result<List<ClinicalActionCatalogOption>>> Function({
    required String termType,
    String? query,
    int? limit,
    String source,
  })?
  onSearchLabTests,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1400, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: ClinicalLabOrderActionDialog(
            referenceData: ClinicalActionReferenceData(
              labTests: catalogOptions,
            ),
            onSearchLabTests:
                onSearchLabTests ??
                ({
                  required String termType,
                  String? query,
                  int? limit,
                  String source = 'FACILITY',
                }) async {
                  return Result.success(catalogOptions);
                },
            onRequest:
                ({
                  required List<String> labTestIds,
                  required List<String> labPanelIds,
                  ClinicalRequestBillingSubmit? billing,
                }) async {
                  return null;
                },
            onUpdate:
                ({
                  required String labOrderId,
                  required List<String> labTestIds,
                  required List<String> labPanelIds,
                  ClinicalRequestBillingSubmit? billing,
                }) async {
                  return null;
                },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
