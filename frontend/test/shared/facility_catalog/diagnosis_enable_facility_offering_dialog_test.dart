import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/facility_catalog/clinical_catalog_admin_dialogs.dart';
import 'package:hosspi_hms/shared/facility_catalog/facility_catalog_scope.dart';

const ClinicalCatalogOption _dxHypertension = ClinicalCatalogOption(
  id: 'DX0000001',
  name: 'Essential hypertension',
  code: 'I10',
  category: 'Circulatory',
);

const ClinicalCatalogOption _dxDiabetes = ClinicalCatalogOption(
  id: 'DX0000002',
  name: 'Type 2 diabetes mellitus',
  code: 'E11',
  category: 'Endocrine',
);

void main() {
  group('DiagnosisEnableFacilityOfferingDialog', () {
    testWidgets('stays open after enable and supports a second enable', (
      WidgetTester tester,
    ) async {
      final List<String> enabledIds = <String>[];
      bool? closedResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return Center(
                  child: AppButton.primary(
                    label: 'Open',
                    onPressed: () async {
                      closedResult = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => DiagnosisEnableFacilityOfferingDialog(
                          scope: const FacilityCatalogScope(
                            tenantId: 'TEN1',
                            facilityId: 'FAC1',
                          ),
                          onSearchCatalog: ({String? query, int limit = 100}) async {
                            return const Result<List<ClinicalCatalogOption>>.success(
                              <ClinicalCatalogOption>[
                                _dxHypertension,
                                _dxDiabetes,
                              ],
                            );
                          },
                          onEnable: (ClinicalCatalogOption item) async {
                            enabledIds.add(item.apiId);
                            return null;
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('ENABLE CLINICAL DIAGNOSES'), findsOneWidget);

      final Finder addButtons = find.widgetWithText(AppButton, 'Add diagnosis');
      expect(addButtons, findsNWidgets(2));

      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      expect(enabledIds, <String>[_dxHypertension.apiId]);
      expect(find.text('ENABLE CLINICAL DIAGNOSES'), findsOneWidget);
      expect(find.text('Configured'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Add diagnosis'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Add diagnosis'));
      await tester.pumpAndSettle();

      expect(enabledIds, <String>[
        _dxHypertension.apiId,
        _dxDiabetes.apiId,
      ]);
      expect(find.text('Configured'), findsNWidgets(2));
      expect(find.widgetWithText(AppButton, 'Add diagnosis'), findsNothing);

      await tester.tap(find.widgetWithText(AppButton, 'Close'));
      await tester.pumpAndSettle();

      expect(closedResult, isTrue);
    });

    testWidgets('Close without enables pops false', (WidgetTester tester) async {
      bool? closedResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return Center(
                  child: AppButton.primary(
                    label: 'Open',
                    onPressed: () async {
                      closedResult = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => DiagnosisEnableFacilityOfferingDialog(
                          scope: const FacilityCatalogScope(
                            tenantId: 'TEN1',
                            facilityId: 'FAC1',
                          ),
                          onSearchCatalog: ({String? query, int limit = 100}) async {
                            return const Result<List<ClinicalCatalogOption>>.success(
                              <ClinicalCatalogOption>[_dxHypertension],
                            );
                          },
                          onEnable: (_) async => null,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Close'));
      await tester.pumpAndSettle();

      expect(closedResult, isFalse);
    });

    testWidgets('failed enable keeps Add diagnosis and shows banner', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return Center(
                  child: AppButton.primary(
                    label: 'Open',
                    onPressed: () {
                      showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => DiagnosisEnableFacilityOfferingDialog(
                          scope: const FacilityCatalogScope(
                            tenantId: 'TEN1',
                            facilityId: 'FAC1',
                          ),
                          onSearchCatalog: ({String? query, int limit = 100}) async {
                            return const Result<List<ClinicalCatalogOption>>.success(
                              <ClinicalCatalogOption>[_dxHypertension],
                            );
                          },
                          onEnable: (_) async => const AppFailure.forbidden(),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Add diagnosis'));
      await tester.pumpAndSettle();

      expect(find.text('ENABLE CLINICAL DIAGNOSES'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Add diagnosis'), findsOneWidget);
      expect(find.text('You do not have permission.'), findsOneWidget);
    });
  });
}
