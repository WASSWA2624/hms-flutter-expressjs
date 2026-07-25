import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
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

void main() {
  group('LabEnableFacilityOfferingDialog', () {
    testWidgets('close action renders a close icon', (
      WidgetTester tester,
    ) async {
      await _pumpEnableDialog(tester);

      expect(find.widgetWithIcon(AppButton, Icons.close), findsWidgets);
    });

    testWidgets('shows enable lab tests and panels title', (
      WidgetTester tester,
    ) async {
      await _pumpEnableDialog(tester);

      expect(find.text('ENABLE LAB TESTS AND PANELS'), findsOneWidget);
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

    testWidgets('enable price dialog exposes cancel and enable action icons', (
      WidgetTester tester,
    ) async {
      await _pumpEnableDialog(tester);

      await tester.tap(find.text('Complete blood count').first);
      await tester.pumpAndSettle();

      expect(
        find.widgetWithIcon(AppButton, Icons.check_circle_outline),
        findsOneWidget,
      );
      expect(find.widgetWithIcon(AppButton, Icons.close), findsWidgets);
    });

    testWidgets('all kind opens panel enable action for panel rows', (
      WidgetTester tester,
    ) async {
      await _pumpEnableDialog(
        tester,
        kind: LabEnableOfferingKind.all,
        items: const <LabCatalogItem>[_availableTest, _availablePanel],
      );

      await tester.tap(find.text('Metabolic panel').first);
      await tester.pumpAndSettle();

      expect(find.text('ENABLE PANEL'), findsWidgets);
    });
  });
}

Future<void> _pumpEnableDialog(
  WidgetTester tester, {
  LabEnableOfferingKind kind = LabEnableOfferingKind.test,
  List<LabCatalogItem> items = const <LabCatalogItem>[_availableTest],
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
            onEnable: (LabCatalogItem item, Map<String, Object?> payload) async {
              return null;
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
