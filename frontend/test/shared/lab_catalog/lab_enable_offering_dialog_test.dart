import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_dialogs.dart';

const LabCatalogItem _availableTest = LabCatalogItem(
  id: 'LBT0000001',
  type: LabCatalogItemType.test,
  name: 'Complete blood count',
  code: 'CBC',
  category: 'Hematology',
);

const LabCatalogItem _availablePanel = LabCatalogItem(
  id: 'LBP0000001',
  type: LabCatalogItemType.panel,
  name: 'Metabolic panel',
  code: 'CMP',
  category: 'Chemistry',
);

const LabCatalogItem _alreadyOfferedTest = LabCatalogItem(
  id: 'LBT0000002',
  type: LabCatalogItemType.test,
  name: 'Lipid panel',
  code: 'LIP',
  category: 'Chemistry',
  isOfferedAtFacility: true,
);

void main() {
  group('LabEnableFacilityOfferingDialog', () {
    testWidgets('catalog footer is Back, Next, Close with disabled Next', (
      WidgetTester tester,
    ) async {
      await _pumpEnableDialog(tester, showBackAction: true);

      expect(find.text('ENABLE LAB TESTS AND PANELS'), findsOneWidget);

      final Finder nextButton = find.widgetWithText(AppButton, 'Next');
      expect(nextButton, findsOneWidget);
      expect(
        find.widgetWithIcon(AppButton, Icons.arrow_back_outlined),
        findsWidgets,
      );
      expect(find.widgetWithIcon(AppButton, Icons.close), findsWidgets);
      expect(
        find.byTooltip('Select at least one test or panel.'),
        findsOneWidget,
      );

      final AppButton next = tester.widget<AppButton>(nextButton);
      expect(next.enabled, isFalse);
      expect(next.onPressed, isNull);
    });

    testWidgets('hides already offered items from catalog', (
      WidgetTester tester,
    ) async {
      await _pumpEnableDialog(
        tester,
        kind: LabEnableOfferingKind.all,
        items: const <LabCatalogItem>[
          _availableTest,
          _alreadyOfferedTest,
          _availablePanel,
        ],
      );

      expect(find.text('Complete blood count'), findsWidgets);
      expect(find.text('Metabolic panel'), findsWidgets);
      expect(find.text('Lipid panel'), findsNothing);
    });

    testWidgets('all kind lists tests and panels', (WidgetTester tester) async {
      await _pumpEnableDialog(
        tester,
        kind: LabEnableOfferingKind.all,
        items: const <LabCatalogItem>[_availableTest, _availablePanel],
      );

      expect(find.text('Complete blood count'), findsWidgets);
      expect(find.text('Metabolic panel'), findsWidgets);
      expect(find.text('ENABLE LAB TESTS AND PANELS'), findsOneWidget);
    });

    testWidgets('selection goes to batch price then preview then enable', (
      WidgetTester tester,
    ) async {
      final List<Map<String, Object?>> enables = <Map<String, Object?>>[];
      await _pumpEnableDialog(
        tester,
        kind: LabEnableOfferingKind.all,
        items: const <LabCatalogItem>[_availableTest, _availablePanel],
        onEnable: (LabCatalogItem item, Map<String, Object?> payload) async {
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
      expect(find.text('Complete blood count'), findsWidgets);
      expect(find.text('Metabolic panel'), findsWidgets);

      await tester.tap(find.text('Enable selected').first);
      await tester.pumpAndSettle();

      expect(enables, hasLength(2));
      expect(enables.map((Map<String, Object?> p) => p['unit_price']),
          containsAll(<Object?>[1000, 2500]));
    });

    testWidgets('preview allows deselect and back to batch price', (
      WidgetTester tester,
    ) async {
      await _pumpEnableDialog(
        tester,
        kind: LabEnableOfferingKind.all,
        items: const <LabCatalogItem>[_availableTest, _availablePanel],
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
  LabEnableOfferingKind kind = LabEnableOfferingKind.test,
  bool showBackAction = false,
  List<LabCatalogItem> items = const <LabCatalogItem>[_availableTest],
  Future<AppFailure?> Function(
    LabCatalogItem item,
    Map<String, Object?> payload,
  )?
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
          body: LabEnableFacilityOfferingDialog(
            kind: kind,
            showBackAction: showBackAction,
            scope: const LabCatalogScope(
              tenantId: 'TEN0000001',
              facilityId: 'FAC0000001',
            ),
            onSearchCatalog:
                ({
                  required LabEnableOfferingKind kind,
                  required LabCatalogScope scope,
                  String? query,
                  int limit = 100,
                }) async {
                  return Result<List<LabCatalogItem>>.success(items);
                },
            onEnable:
                onEnable ??
                (LabCatalogItem item, Map<String, Object?> payload) async {
                  return null;
                },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
