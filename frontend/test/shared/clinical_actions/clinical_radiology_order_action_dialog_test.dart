import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';

void main() {
  testWidgets(
    'radiology catalog search remains editable when a query has no matches',
    (WidgetTester tester) async {
      await _pumpDialog(
        tester,
        ClinicalRadiologyOrderActionDialog(
          referenceData: const ClinicalActionReferenceData(
            radiologyTests: <ClinicalActionCatalogOption>[
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
            ],
          ),
          onSubmit:
              ({
                required List<ClinicalActionRadiologyRequest> requests,
                ClinicalRequestBillingSubmit? billing,
              }) async {
                return null;
              },
        ),
      );

      final Finder catalogField = find.byType(TextField).last;

      await tester.tap(catalogField);
      await tester.enterText(catalogField, 'not in catalog');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      TextField textField = tester.widget<TextField>(catalogField);
      expect(textField.enabled, isTrue);
      expect(find.text('No matching radiology catalog items'), findsOneWidget);

      await tester.enterText(catalogField, 'ct chest');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      textField = tester.widget<TextField>(catalogField);
      expect(textField.enabled, isTrue);
      expect(textField.controller?.text, 'ct chest');
      expect(find.text('No matching radiology catalog items'), findsNothing);
    },
  );
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
