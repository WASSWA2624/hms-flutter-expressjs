import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/facility_catalog/lab_catalog_mutate_visibility.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_details_dialog.dart';

void main() {
  group('showLabCatalogItemDetailsDialog', () {
    testWidgets('opens test details title without mutate actions', (
      WidgetTester tester,
    ) async {
      await _pumpDetailsHost(
        tester,
        item: const LabCatalogItem(
          id: 'LBT1',
          type: LabCatalogItemType.test,
          name: 'Glucose',
          code: 'GLU',
        ),
        showMutateActions: false,
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('LAB TEST DETAILS'), findsOneWidget);
      expect(find.textContaining('Glucose'), findsWidgets);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('opens panel details title', (WidgetTester tester) async {
      await _pumpDetailsHost(
        tester,
        item: const LabCatalogItem(
          id: 'LBP1',
          type: LabCatalogItemType.panel,
          name: 'Metabolic Panel',
          code: 'MP',
        ),
        showMutateActions: false,
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('LAB PANEL DETAILS'), findsOneWidget);
      expect(find.textContaining('Metabolic Panel'), findsWidgets);
    });

    testWidgets('shows Edit and Delete when mutate actions allowed', (
      WidgetTester tester,
    ) async {
      LabCatalogItemDetailsAction? action;
      await _pumpDetailsHost(
        tester,
        item: const LabCatalogItem(
          id: 'LBT1',
          type: LabCatalogItemType.test,
          name: 'Glucose',
          code: 'GLU',
        ),
        showMutateActions: true,
        onClosed: (LabCatalogItemDetailsAction? value) => action = value,
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(action, LabCatalogItemDetailsAction.edit);
    });

    testWidgets('Delete returns delete action', (WidgetTester tester) async {
      LabCatalogItemDetailsAction? action;
      await _pumpDetailsHost(
        tester,
        item: const LabCatalogItem(
          id: 'LBT1',
          type: LabCatalogItemType.test,
          name: 'Glucose',
          code: 'GLU',
        ),
        showMutateActions: true,
        onClosed: (LabCatalogItemDetailsAction? value) => action = value,
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(action, LabCatalogItemDetailsAction.delete);
    });

    testWidgets('Close returns null', (WidgetTester tester) async {
      LabCatalogItemDetailsAction? action = LabCatalogItemDetailsAction.edit;
      var closed = false;
      await _pumpDetailsHost(
        tester,
        item: const LabCatalogItem(
          id: 'LBT1',
          type: LabCatalogItemType.test,
          name: 'Glucose',
          code: 'GLU',
        ),
        showMutateActions: true,
        onClosed: (LabCatalogItemDetailsAction? value) {
          action = value;
          closed = true;
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(action, isNull);
    });
  });

  group('Lab table row select vs edit', () {
    testWidgets('row select opens details, not mutation dialog', (
      WidgetTester tester,
    ) async {
      var detailsOpened = false;
      var editOpened = false;
      const LabCatalogItem item = LabCatalogItem(
        id: 'LBT1',
        type: LabCatalogItemType.test,
        name: 'Glucose',
        code: 'GLU',
      );

      await _pumpLabRowSurface(
        tester,
        canMutateLab: true,
        items: const <LabCatalogItem>[item],
        onRowSelected: (_) => detailsOpened = true,
        onEdit: () => editOpened = true,
      );

      expect(find.text(item.displayTitle), findsOneWidget);
      await tester.tap(find.text(item.displayTitle));
      await tester.pumpAndSettle();
      expect(detailsOpened, isTrue);
      expect(editOpened, isFalse);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(editOpened, isTrue);
    });

    test('standard mutable gating omits details mutate actions', () {
      final bool canMutate = labCatalogMutateControlsVisible(
        panelEnabled: true,
        canMutateLabCatalog: true,
      );
      expect(
        labCatalogItemMutateActionsVisible(
          canMutateLabCatalog: canMutate,
          isStandard: true,
        ),
        isFalse,
      );
    });
  });
}

Future<void> _pumpDetailsHost(
  WidgetTester tester, {
  required LabCatalogItem item,
  required bool showMutateActions,
  ValueChanged<LabCatalogItemDetailsAction?>? onClosed,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
                  final LabCatalogItemDetailsAction? result =
                      await showLabCatalogItemDetailsDialog(
                        context,
                        item: item,
                        showMutateActions: showMutateActions,
                      );
                  onClosed?.call(result);
                },
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpLabRowSurface(
  WidgetTester tester, {
  required bool canMutateLab,
  required List<LabCatalogItem> items,
  required ValueChanged<LabCatalogItem> onRowSelected,
  required VoidCallback onEdit,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            final AppLocalizations l10n = AppLocalizations.of(context);
            final bool showMutate = labCatalogMutateControlsVisible(
              panelEnabled: true,
              canMutateLabCatalog: canMutateLab,
            );
            return AppListTable<LabCatalogItem>(
              items: items,
              maxVisibleItems: 40,
              onRowSelected: onRowSelected,
              search: AppListTableSearch<LabCatalogItem>(
                controller: TextEditingController(),
                semanticLabel: l10n.tenantFacilityCatalogTabLab,
                hintText: l10n.tenantFacilityCatalogSearchHint,
                matcher: (_, _) => true,
              ),
              columns: <AppListTableColumn<LabCatalogItem>>[
                AppListTableColumn<LabCatalogItem>(
                  id: 'name',
                  label: l10n.accessAdminColumnName,
                  cellBuilder: (_, LabCatalogItem item) =>
                      Text(item.displayTitle),
                ),
                if (showMutate)
                  AppListTableColumn<LabCatalogItem>(
                    id: 'actions',
                    label: l10n.accessAdminColumnActions,
                    alwaysVisible: true,
                    cellBuilder: (_, LabCatalogItem item) => Row(
                      children: <Widget>[
                        AppButton.tertiary(
                          label: l10n.clinicalLabRequestEditSelectionAction,
                          onPressed: item.isStandard ? null : onEdit,
                        ),
                      ],
                    ),
                  ),
              ],
              mobileItemBuilder: (BuildContext context, LabCatalogItem item) =>
                  AppListTableMobileItem(title: item.displayTitle),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
