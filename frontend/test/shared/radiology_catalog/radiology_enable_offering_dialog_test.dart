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

void main() {
  group('RadiologyEnableFacilityOfferingDialog', () {
    testWidgets('close action renders a close icon', (
      WidgetTester tester,
    ) async {
      await _pumpEnableDialog(tester);

      expect(find.widgetWithIcon(AppButton, Icons.close), findsWidgets);
      expect(find.text('Chest X-ray'), findsWidgets);
    });

    testWidgets('enable price dialog exposes the enable action icon', (
      WidgetTester tester,
    ) async {
      await _pumpEnableDialog(tester);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Enable selected').first);
      await tester.pumpAndSettle();

      expect(
        find.widgetWithIcon(AppButton, Icons.check_circle_outline),
        findsWidgets,
      );
      expect(find.text('Enable procedure'), findsWidgets);
    });

    testWidgets('supports multi-select enable without leaving the catalog', (
      WidgetTester tester,
    ) async {
      await _pumpEnableDialog(tester);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Enable selected'), findsWidgets);

      await tester.tap(find.textContaining('Enable selected').first);
      await tester.pumpAndSettle();

      expect(find.text('Enable procedure'), findsWidgets);
      expect(find.byType(AppCurrencyAmountField), findsOneWidget);

      await tester.tap(find.widgetWithIcon(AppButton, Icons.close).first);
      await tester.pumpAndSettle();

      // Parent enable catalog remains after dismissing the price step.
      expect(find.textContaining('Enable selected'), findsWidgets);
      expect(find.text('Chest X-ray'), findsWidgets);
    });
  });
}

Future<void> _pumpEnableDialog(WidgetTester tester) async {
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
            onSearchCatalog:
                ({
                  required RadiologyCatalogScope scope,
                  String? query,
                  int limit = 100,
                }) async {
                  return const Result<List<RadiologyCatalogTest>>.success(
                    <RadiologyCatalogTest>[_availableTest],
                  );
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
