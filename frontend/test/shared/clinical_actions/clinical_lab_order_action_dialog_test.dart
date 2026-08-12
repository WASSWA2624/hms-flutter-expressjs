import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
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
      expect(find.text('Close'), findsNothing);
      expect(
        find.text(
          'Review your selection below. Use Add Lab Orders to browse the catalog, then review billing before submitting.',
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

    testWidgets('submit sends catalog api ids instead of internal ids', (
      WidgetTester tester,
    ) async {
      final List<String> submittedTestIds = <String>[];
      await _pumpLabOrderDialog(
        tester,
        catalogOptions: <ClinicalActionCatalogOption>[
          const ClinicalActionCatalogOption(
            id: '4e73222f-7b32-4a31-a1c1-9c1b59889479',
            publicId: 'LBT0000001',
            name: 'Complete blood count',
            unitPrice: 25,
            currency: 'USD',
          ),
        ],
        onRequest:
            ({
              required List<String> labTestIds,
              required List<String> labPanelIds,
              ClinicalRequestBillingSubmit? billing,
            }) async {
              submittedTestIds.addAll(labTestIds);
              return null;
            },
      );

      await tester.tap(find.widgetWithText(AppButton, 'Add Lab Orders'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await _tapTableRowCheckbox(tester, 'Complete blood count');
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(AppButton, 'Confirm selected tests or panels'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithIcon(AppButton, Icons.science_outlined));
      await tester.pumpAndSettle();

      expect(submittedTestIds, <String>['LBT0000001']);
    });

    testWidgets('shows human-friendly patient id in request context', (
      WidgetTester tester,
    ) async {
      await _pumpLabOrderDialog(
        tester,
        patientContext: const ClinicalRequestPatientContext(
          patientName: 'Amina Demo-Alpha',
          patientId: 'PAT0000001',
          encounterId: 'ENC0000003',
        ),
      );

      expect(find.text('PAT0000001'), findsOneWidget);
      expect(find.text('ENC0000003'), findsOneWidget);
    });

    testWidgets('confirmed catalog items appear in selected table', (
      WidgetTester tester,
    ) async {
      await _pumpLabOrderDialog(
        tester,
        catalogOptions: <ClinicalActionCatalogOption>[
          const ClinicalActionCatalogOption(
            id: '4e73222f-7b32-4a31-a1c1-9c1b59889479',
            publicId: 'LBT0000001',
            name: 'Complete blood count',
            unitPrice: 25000,
            currency: 'UGX',
          ),
          const ClinicalActionCatalogOption(
            id: 'lipid-id',
            publicId: 'LBT0000002',
            name: 'Lipid profile',
            unitPrice: 40000,
            currency: 'UGX',
          ),
        ],
      );

      await tester.tap(find.widgetWithText(AppButton, 'Add Lab Orders'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Complete blood count'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lipid profile'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(AppButton, 'Confirm selected tests or panels'),
      );
      await tester.pumpAndSettle();

      expect(find.text('No lab requests selected. Use Add Lab Orders.'), findsNothing);
      expect(find.text('Complete blood count'), findsOneWidget);
      expect(find.text('Lipid profile'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Remove item'), findsNWidgets(2));

      // Row click marks a line for bulk remove.
      await tester.tap(find.text('Lipid profile'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppButton, 'Remove selected'), findsOneWidget);

      await tester.tap(find.text('Remove item').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Complete blood count'), findsNothing);
    });

    testWidgets('catalog picker supports checkbox multi-select', (
      WidgetTester tester,
    ) async {
      await _pumpLabOrderDialog(
        tester,
        catalogOptions: <ClinicalActionCatalogOption>[
          const ClinicalActionCatalogOption(
            id: '4e73222f-7b32-4a31-a1c1-9c1b59889479',
            publicId: 'LBT0000001',
            name: 'Complete blood count',
            unitPrice: 25,
            currency: 'USD',
          ),
        ],
      );

      await tester.tap(find.widgetWithText(AppButton, 'Add Lab Orders'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('CHOOSE LAB TESTS OR PANELS'), findsOneWidget);
      expect(find.text('0 selected'), findsOneWidget);
      expect(
        find.byType(RadioListTile<ClinicalLabRequestCatalogKind>),
        findsNWidgets(2),
      );

      await _tapTableRowCheckbox(tester, 'Complete blood count');
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);

      // Clicking the row again deselects the item.
      await tester.tap(find.text('Complete blood count'));
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);

      await tester.tap(find.text('Complete blood count'));
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
        catalogOptions: <ClinicalActionCatalogOption>[
          _sampleCatalogOptions().first,
        ],
      );

      await tester.tap(find.widgetWithText(AppButton, 'Add Lab Orders'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await _tapTableRowCheckbox(tester, 'Complete blood count');
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
        find.text('No lab requests selected. Use Add Lab Orders.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'cancel keeps lab request when remove confirmation is dismissed',
      (WidgetTester tester) async {
        await _pumpLabOrderDialog(
          tester,
          catalogOptions: <ClinicalActionCatalogOption>[
            _sampleCatalogOptions().first,
          ],
        );

        await tester.tap(find.widgetWithText(AppButton, 'Add Lab Orders'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        await _tapTableRowCheckbox(tester, 'Complete blood count');
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(AppButton, 'Confirm selected tests or panels'),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Remove item').first);
        await tester.pumpAndSettle();

        expect(find.text('REMOVE LAB REQUEST?'), findsOneWidget);

        await tester.tap(find.widgetWithText(AppButton, 'Close'));
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
        catalogOptions: <ClinicalActionCatalogOption>[
          _sampleCatalogOptions().first,
        ],
        patientContext: const ClinicalRequestPatientContext(
          patientName: 'Jane Doe',
          patientId: 'P-1001',
          encounterId: 'ENC-42',
        ),
      );

      expect(find.textContaining('Patient name:'), findsOneWidget);
      expect(find.textContaining('Jane Doe'), findsOneWidget);
      expect(find.textContaining('P-1001'), findsOneWidget);
      expect(find.textContaining('ENC-42'), findsOneWidget);
      expect(find.byType(AppCopyableIdentifier), findsNWidgets(2));
      expect(find.widgetWithText(AppButton, 'Remove selected'), findsNothing);

      await tester.tap(find.widgetWithText(AppButton, 'Add Lab Orders'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await _tapTableRowCheckbox(tester, 'Complete blood count');
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
        catalogOptions: <ClinicalActionCatalogOption>[
          _sampleCatalogOptions().first,
        ],
      );

      await tester.tap(find.widgetWithText(AppButton, 'Add Lab Orders'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await _tapTableRowCheckbox(tester, 'Complete blood count');
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Close'));
      await tester.pumpAndSettle();

      expect(find.text('Complete blood count'), findsNothing);
      expect(
        find.text('No lab requests selected. Use Add Lab Orders.'),
        findsOneWidget,
      );
    });

    testWidgets('catalog picker close discards staged selections', (
      WidgetTester tester,
    ) async {
      await _pumpLabOrderDialog(
        tester,
        catalogOptions: <ClinicalActionCatalogOption>[
          _sampleCatalogOptions().first,
        ],
      );

      await tester.tap(find.widgetWithText(AppButton, 'Add Lab Orders'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await _tapTableRowCheckbox(tester, 'Complete blood count');
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

      await tester.tap(find.widgetWithText(AppButton, 'Add Lab Orders'));
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
  // Row cells toggle selection via onRowSelected; checkbox is display-only.
  await tester.tap(find.text(rowLabel));
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
  Future<AppFailure?> Function({
    required List<String> labTestIds,
    required List<String> labPanelIds,
    ClinicalRequestBillingSubmit? billing,
  })?
  onRequest,
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
                onRequest ??
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
