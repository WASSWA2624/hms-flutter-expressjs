import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/radiology_catalog/radiology_catalog_dialogs.dart';

const RadiologyCatalogTest _availableTest = RadiologyCatalogTest(
  id: 'RT0000001',
  name: 'Chest X-ray',
  code: 'RAD-00001',
  modality: 'XRAY',
);

const RadiologyCatalogTest _availableTestTwo = RadiologyCatalogTest(
  id: 'RT0000002',
  name: 'Brain MRI',
  code: 'RAD-00002',
  modality: 'MRI',
);

void main() {
  group('RadiologyEnableFacilityOfferingDialog', () {
    testWidgets('close and back actions render on enable catalog step', (
      WidgetTester tester,
    ) async {
      await _pumpEnableDialog(tester, showBackAction: true);

      expect(find.widgetWithIcon(AppButton, Icons.close), findsWidgets);
      expect(find.widgetWithIcon(AppButton, Icons.arrow_back_outlined), findsWidgets);
      expect(find.text('Chest X-ray'), findsWidgets);
    });

    testWidgets('selection goes to preview then individual price step', (
      WidgetTester tester,
    ) async {
      await _pumpEnableDialog(tester);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next').first);
      await tester.pumpAndSettle();

      expect(find.text('REVIEW SELECTION'), findsOneWidget);
      expect(find.text('Chest X-ray'), findsWidgets);

      await tester.tap(find.text('Next').first);
      await tester.pumpAndSettle();

      expect(find.text('ENABLE PROCEDURE'), findsWidgets);
      expect(find.byType(AppCurrencyAmountField), findsOneWidget);
      expect(
        find.widgetWithIcon(AppButton, Icons.arrow_back_outlined),
        findsWidgets,
      );
    });

    testWidgets('preview allows deselect and back to catalog', (
      WidgetTester tester,
    ) async {
      await _pumpEnableDialog(
        tester,
        items: const <RadiologyCatalogTest>[_availableTest, _availableTestTwo],
      );

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next').first);
      await tester.pumpAndSettle();

      expect(find.text('REVIEW SELECTION'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithIcon(AppButton, Icons.arrow_back_outlined));
      await tester.pumpAndSettle();

      expect(find.text('ENABLE RADIOLOGY OFFERING'), findsOneWidget);
    });
  });
}

Future<void> _pumpEnableDialog(
  WidgetTester tester, {
  bool showBackAction = false,
  List<RadiologyCatalogTest> items = const <RadiologyCatalogTest>[
    _availableTest,
  ],
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
          body: RadiologyEnableFacilityOfferingDialog(
            scope: const RadiologyCatalogScope(
              tenantId: 'TEN0000001',
              facilityId: 'FAC0000001',
            ),
            showBackAction: showBackAction,
            onSearchCatalog:
                ({
                  required RadiologyCatalogScope scope,
                  String? query,
                  int limit = 100,
                }) async {
                  return Result<List<RadiologyCatalogTest>>.success(items);
                },
            onEnable: (String id, Map<String, Object?> payload) async {
              return null;
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
