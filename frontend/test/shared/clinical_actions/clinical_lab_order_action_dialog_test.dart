import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  test(
    'buildPendingClinicalRequestBillingSubmit always defers to billing office',
    () {
      final ClinicalRequestBillingSubmit billing =
          buildPendingClinicalRequestBillingSubmit(
            options: <ClinicalActionCatalogOption>[
              const ClinicalActionCatalogOption(
                id: 'LAB-CBC',
                name: 'Complete blood count',
                unitPrice: 25,
                currency: 'USD',
              ),
            ],
          );

      expect(billing.mode, ClinicalRequestPaymentMode.billLater);
      expect(billing.paymentStatus, ClinicalRequestPaymentStatus.unpaid);
      expect(billing.totalAmount, 25);
      expect(billing.toPayloadMap()['payment_status'], 'PENDING');
    },
  );

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
      expect(
        find.text(
          'Review your selection below. Use Add items to browse the catalog, then review billing before submitting.',
        ),
        findsNothing,
      );
      expect(find.text('No items'), findsNothing);
      expect(find.text('Selected lab requests'), findsNothing);
      expect(find.byIcon(Icons.fullscreen_exit), findsWidgets);
      expect(
        find.widgetWithIcon(AppButton, Icons.science_outlined),
        findsOneWidget,
      );
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

      expect(find.text('CHOOSE LAB TESTS OR PANELS'), findsOneWidget);
      expect(find.text('0 selected'), findsOneWidget);
      expect(
        find.byType(RadioListTile<ClinicalLabRequestCatalogKind>),
        findsNWidgets(2),
      );

      await _tapRowCheckbox(tester, 'Complete blood count');
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(AppButton, 'Confirm selected tests or panels'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Complete blood count'), findsWidgets);
      expect(find.text('Test'), findsOneWidget);
      expect(find.text('\$25.00'), findsWidgets);
      expect(find.text('Total'), findsOneWidget);
    });

    testWidgets('supports removing a selected lab request from the table', (
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
      await _tapRowCheckbox(tester, 'Complete blood count');
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(AppButton, 'Confirm selected tests or panels'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Complete blood count'), findsWidgets);

      await tester.tap(find.text('Remove item').first);
      await tester.pumpAndSettle();

      expect(find.text('REMOVE LAB REQUEST?'), findsOneWidget);
      expect(find.text('Complete blood count'), findsWidgets);
      expect(find.text('Test'), findsWidgets);

      await tester.tap(find.widgetWithText(AppButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Complete blood count'), findsNothing);
      expect(
        find.text(
          'No lab requests selected. Use Add items to choose tests or panels.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'cancel keeps lab request when remove confirmation is dismissed',
      (WidgetTester tester) async {
        await _pumpLabOrderDialog(
          tester,
          catalogOptions: _sampleCatalogOptions(),
        );

        await tester.tap(find.widgetWithText(AppButton, 'Add items'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        await _tapRowCheckbox(tester, 'Complete blood count');
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(AppButton, 'Confirm selected tests or panels'),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Remove item').first);
        await tester.pumpAndSettle();

        expect(find.text('REMOVE LAB REQUEST?'), findsOneWidget);

        await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('REMOVE LAB REQUEST?'), findsNothing);
        expect(find.text('Complete blood count'), findsWidgets);
      },
    );

    testWidgets('shows patient context strip and toolbar remove selected', (
      WidgetTester tester,
    ) async {
      await _pumpLabOrderDialog(
        tester,
        catalogOptions: _sampleCatalogOptions(),
        patientContext: const ClinicalRequestPatientContext(
          patientName: 'Jane Doe',
          patientId: 'P-1001',
          encounterId: 'ENC-42',
        ),
      );

      expect(
        find.text('Name: Jane Doe   Patient ID: P-1001   Encounter ID: ENC-42'),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppButton, 'Remove selected'), findsNothing);

      await tester.tap(find.widgetWithText(AppButton, 'Add items'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await _tapRowCheckbox(tester, 'Complete blood count');
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(AppButton, 'Confirm selected tests or panels'),
      );
      await tester.pumpAndSettle();

      await _tapTableRowCheckbox(tester, 'Complete blood count');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppButton, 'Remove selected'), findsOneWidget);
      expect(find.text('Test name'), findsOneWidget);
      expect(find.text('Remove item'), findsOneWidget);
    });

    testWidgets('catalog picker cancel discards staged selections', (
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

      await _tapRowCheckbox(tester, 'Complete blood count');
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Complete blood count'), findsNothing);
      expect(
        find.text(
          'No lab requests selected. Use Add items to choose tests or panels.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('catalog picker close discards staged selections', (
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

      await _tapRowCheckbox(tester, 'Complete blood count');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();

      expect(find.text('Complete blood count'), findsNothing);
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

Future<void> _tapTableRowCheckbox(WidgetTester tester, String rowLabel) async {
  expect(find.text(rowLabel), findsOneWidget);
  await tester.tap(find.byType(Checkbox).at(1));
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
  ClinicalRequestPatientContext patientContext =
      const ClinicalRequestPatientContext(),
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
            patientContext: patientContext,
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
