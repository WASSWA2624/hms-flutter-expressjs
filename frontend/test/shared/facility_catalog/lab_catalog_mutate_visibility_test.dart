import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/facility_catalog/lab_catalog_mutate_visibility.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

void main() {
  group('labCatalogMutateControlsVisible', () {
    test('requires both panel enabled and mutate permission', () {
      expect(
        labCatalogMutateControlsVisible(
          panelEnabled: true,
          canMutateLabCatalog: true,
        ),
        isTrue,
      );
      expect(
        labCatalogMutateControlsVisible(
          panelEnabled: false,
          canMutateLabCatalog: true,
        ),
        isFalse,
      );
      expect(
        labCatalogMutateControlsVisible(
          panelEnabled: true,
          canMutateLabCatalog: false,
        ),
        isFalse,
      );
    });

    test('nurse policy cannot mutate lab catalog', () {
      final AppAccessPolicy nurse = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['NURSE']),
        ),
      );
      expect(
        labCatalogMutateControlsVisible(
          panelEnabled: true,
          canMutateLabCatalog: nurse.canMutateLabCatalog(),
        ),
        isFalse,
      );
    });
  });

  group('labCatalogItemMutateActionsVisible', () {
    test('requires mutate permission and non-standard item', () {
      expect(
        labCatalogItemMutateActionsVisible(
          canMutateLabCatalog: true,
          isStandard: false,
        ),
        isTrue,
      );
      expect(
        labCatalogItemMutateActionsVisible(
          canMutateLabCatalog: false,
          isStandard: false,
        ),
        isFalse,
      );
      expect(
        labCatalogItemMutateActionsVisible(
          canMutateLabCatalog: true,
          isStandard: true,
        ),
        isFalse,
      );
    });
  });

  group('Lab catalog mutate UI gating', () {
    testWidgets('unauthorized mutate controls do not render', (
      WidgetTester tester,
    ) async {
      await _pumpLabCatalogSurface(
        tester,
        canMutateLab: false,
        items: const <LabCatalogItem>[
          LabCatalogItem(
            id: 'LBT1',
            type: LabCatalogItemType.test,
            name: 'Glucose',
            code: 'GLU',
          ),
        ],
      );

      expect(find.byTooltip('Create test'), findsNothing);
      expect(find.byTooltip('Create panel'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      // Configure remains available for facility offerings.
      expect(find.byTooltip('Configure'), findsOneWidget);
    });

    testWidgets('authorized mutate controls render', (
      WidgetTester tester,
    ) async {
      await _pumpLabCatalogSurface(
        tester,
        canMutateLab: true,
        items: const <LabCatalogItem>[
          LabCatalogItem(
            id: 'LBT1',
            type: LabCatalogItemType.test,
            name: 'Glucose',
            code: 'GLU',
          ),
        ],
      );

      expect(find.byTooltip('Create test'), findsOneWidget);
      expect(find.byTooltip('Create panel'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.byTooltip('Configure'), findsOneWidget);
    });

    testWidgets('unauthorized empty state omits create action', (
      WidgetTester tester,
    ) async {
      await _pumpLabCatalogSurface(
        tester,
        canMutateLab: false,
        items: const <LabCatalogItem>[],
      );

      expect(find.byTooltip('Create test'), findsNothing);
      expect(find.text('Create test'), findsNothing);
      expect(find.byTooltip('Configure'), findsOneWidget);
    });
  });
}

Future<void> _pumpLabCatalogSurface(
  WidgetTester tester, {
  required bool canMutateLab,
  required List<LabCatalogItem> items,
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
              search: AppListTableSearch<LabCatalogItem>(
                controller: TextEditingController(),
                semanticLabel: l10n.tenantFacilityCatalogTabLab,
                hintText: l10n.tenantFacilityCatalogSearchHint,
                matcher: (_, _) => true,
                trailingActions: <AppSearchBarAction>[
                  AppSearchBarAction(
                    icon: Icons.settings_suggest_outlined,
                    label: l10n.tenantFacilityCatalogConfigureAction,
                    onPressed: () {},
                  ),
                  if (showMutate) ...<AppSearchBarAction>[
                    AppSearchBarAction(
                      icon: Icons.add_circle_outline,
                      label: l10n.labCreateTestAction,
                      onPressed: () {},
                    ),
                    AppSearchBarAction(
                      icon: Icons.add_box_outlined,
                      label: l10n.labCreatePanelAction,
                      onPressed: () {},
                    ),
                  ],
                ],
              ),
              emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
                title: l10n.tenantFacilityCatalogTabLab,
                body: l10n.tenantFacilityCatalogEmptyCatalog,
                action: showMutate
                    ? AppButton.primary(
                        label: l10n.labCreateTestAction,
                        leadingIcon: Icons.add_circle_outline,
                        onPressed: () {},
                      )
                    : null,
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
                    cellBuilder: (_, _) => Row(
                      children: <Widget>[
                        AppButton.tertiary(
                          label: l10n.clinicalLabRequestEditSelectionAction,
                          onPressed: () {},
                        ),
                        AppButton.tertiary(
                          label: l10n.tenantFacilityDeleteAction,
                          onPressed: () {},
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
