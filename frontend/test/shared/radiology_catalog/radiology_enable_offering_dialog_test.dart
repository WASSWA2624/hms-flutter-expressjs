import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/radiology_catalog/radiology_catalog_dialogs.dart';

const RadiologyCatalogProcedure _availableTest = RadiologyCatalogProcedure(
  id: 'RT0000001',
  name: 'Chest X-ray',
  code: 'RAD-00001',
  modality: 'XRAY',
);

const RadiologyCatalogProcedure _availableTestTwo = RadiologyCatalogProcedure(
  id: 'RT0000002',
  name: 'Brain MRI',
  code: 'RAD-00002',
  modality: 'MRI',
);

const RadiologyCatalogProcedure _alreadyOfferedTest = RadiologyCatalogProcedure(
  id: 'RT0000003',
  name: 'Spine CT',
  code: 'RAD-00003',
  modality: 'CT',
  isOfferedAtFacility: true,
);

void main() {
  group('RadiologyEnableFacilityOfferingDialog', () {
    testWidgets('catalog footer is Back, Next, Close with disabled Next', (
      WidgetTester tester,
    ) async {
      await _pumpEnableDialog(tester, showBackAction: true);

      expect(find.text('ENABLE RADIOLOGY PROCEDURES'), findsOneWidget);

      final Finder nextButton = find.widgetWithText(AppButton, 'Next');
      expect(nextButton, findsOneWidget);
      expect(find.widgetWithIcon(AppButton, Icons.arrow_back_outlined), findsWidgets);
      expect(find.widgetWithIcon(AppButton, Icons.close), findsWidgets);
      expect(find.byTooltip('Select at least one imaging test.'), findsOneWidget);

      final AppButton next = tester.widget<AppButton>(nextButton);
      expect(next.enabled, isFalse);
      expect(next.onPressed, isNull);
    });

    testWidgets('hides already offered procedures from catalog', (
      WidgetTester tester,
    ) async {
      await _pumpEnableDialog(
        tester,
        items: const <RadiologyCatalogProcedure>[
          _availableTest,
          _alreadyOfferedTest,
        ],
      );

      expect(find.text('Chest X-ray'), findsWidgets);
      expect(find.text('Spine CT'), findsNothing);
    });

    testWidgets('selection goes to batch price then preview then enable', (
      WidgetTester tester,
    ) async {
      final List<Map<String, Object?>> enables = <Map<String, Object?>>[];
      await _pumpEnableDialog(
        tester,
        items: const <RadiologyCatalogProcedure>[_availableTest, _availableTestTwo],
        onEnable: (String id, Map<String, Object?> payload) async {
          enables.add(payload);
          return null;
        },
      );

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next').first);
      await tester.pumpAndSettle();

      expect(find.text('SET FACILITY PRICES'), findsOneWidget);
      expect(find.byType(AppCurrencyAmountField), findsNWidgets(2));

      final Finder amountFields = find.descendant(
        of: find.byType(AppCurrencyAmountField),
        matching: find.byType(EditableText),
      );
      expect(amountFields, findsNWidgets(2));
      await tester.enterText(amountFields.at(0), '1000');
      await tester.enterText(amountFields.at(1), '2500');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next').first);
      await tester.pumpAndSettle();

      expect(find.text('REVIEW SELECTION'), findsOneWidget);
      expect(find.text('Chest X-ray'), findsWidgets);
      expect(find.text('Brain MRI'), findsWidgets);
      expect(find.textContaining('1,000'), findsWidgets);
      expect(find.textContaining('2,500'), findsWidgets);

      await tester.tap(find.text('Enable selected').first);
      await tester.pumpAndSettle();

      expect(enables, hasLength(2));
      expect(enables.first['unit_price'], 1000);
      expect(enables.last['unit_price'], 2500);
    });

    testWidgets('preview allows deselect and back to batch price', (
      WidgetTester tester,
    ) async {
      await _pumpEnableDialog(
        tester,
        items: const <RadiologyCatalogProcedure>[_availableTest, _availableTestTwo],
      );

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next').first);
      await tester.pumpAndSettle();

      final Finder amountFields = find.descendant(
        of: find.byType(AppCurrencyAmountField),
        matching: find.byType(EditableText),
      );
      await tester.enterText(amountFields.at(0), '1000');
      await tester.enterText(amountFields.at(1), '2500');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next').first);
      await tester.pumpAndSettle();

      expect(find.text('REVIEW SELECTION'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithIcon(AppButton, Icons.arrow_back_outlined));
      await tester.pumpAndSettle();

      expect(find.text('SET FACILITY PRICES'), findsOneWidget);
    });
  });
}

Future<void> _pumpEnableDialog(
  WidgetTester tester, {
  bool showBackAction = false,
  List<RadiologyCatalogProcedure> items = const <RadiologyCatalogProcedure>[
    _availableTest,
  ],
  Future<AppFailure?> Function(String id, Map<String, Object?> payload)?
      onEnable,
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
                  return Result<List<RadiologyCatalogProcedure>>.success(items);
                },
            onEnable: onEnable ??
                (String id, Map<String, Object?> payload) async {
                  return null;
                },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
