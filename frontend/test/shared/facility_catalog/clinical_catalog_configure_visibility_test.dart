import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/facility_catalog/clinical_catalog_configure_visibility.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

void main() {
  group('clinicalCatalogConfigureVisible', () {
    test('requires both panel enabled and mutate permission', () {
      expect(
        clinicalCatalogConfigureVisible(
          panelEnabled: true,
          canMutateClinicalCatalog: true,
        ),
        isTrue,
      );
      expect(
        clinicalCatalogConfigureVisible(
          panelEnabled: false,
          canMutateClinicalCatalog: true,
        ),
        isFalse,
      );
      expect(
        clinicalCatalogConfigureVisible(
          panelEnabled: true,
          canMutateClinicalCatalog: false,
        ),
        isFalse,
      );
    });

    test('receptionist policy cannot configure clinical catalog', () {
      final AppAccessPolicy receptionist = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
        ),
      );
      expect(
        clinicalCatalogConfigureVisible(
          panelEnabled: true,
          canMutateClinicalCatalog: receptionist.canMutateClinicalCatalog(),
        ),
        isFalse,
      );
    });
  });

  group('Diagnoses Configure UI gating', () {
    testWidgets('unauthorized Configure does not render', (
      WidgetTester tester,
    ) async {
      await _pumpDiagnosesCatalogSurface(
        tester,
        canConfigure: false,
      );

      expect(find.byTooltip('Configure'), findsNothing);
      expect(find.byTooltip('Create diagnosis'), findsOneWidget);
    });

    testWidgets('authorized Configure renders', (WidgetTester tester) async {
      await _pumpDiagnosesCatalogSurface(
        tester,
        canConfigure: true,
      );

      expect(find.byTooltip('Configure'), findsOneWidget);
      expect(find.byTooltip('Create diagnosis'), findsOneWidget);
    });
  });
}

Future<void> _pumpDiagnosesCatalogSurface(
  WidgetTester tester, {
  required bool canConfigure,
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
            final bool showConfigure = clinicalCatalogConfigureVisible(
              panelEnabled: true,
              canMutateClinicalCatalog: canConfigure,
            );
            return AppListTable<ClinicalCatalogOption>(
              items: const <ClinicalCatalogOption>[
                ClinicalCatalogOption(
                  id: 'DX1',
                  name: 'Hypertension',
                  code: 'I10',
                ),
              ],
              maxVisibleItems: 40,
              search: AppListTableSearch<ClinicalCatalogOption>(
                controller: TextEditingController(),
                semanticLabel: l10n.tenantFacilityCatalogTabDiagnoses,
                hintText: l10n.tenantFacilityCatalogSearchHint,
                matcher: (_, _) => true,
                trailingActions: <AppSearchBarAction>[
                  if (showConfigure)
                    AppSearchBarAction(
                      icon: Icons.settings_suggest_outlined,
                      label: l10n.tenantFacilityCatalogConfigureAction,
                      onPressed: () {},
                    ),
                  AppSearchBarAction(
                    icon: Icons.add_circle_outline,
                    label: l10n.clinicalCreateDiagnosisAction,
                    onPressed: () {},
                  ),
                ],
              ),
              emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
                title: l10n.tenantFacilityCatalogTabDiagnoses,
                body: l10n.tenantFacilityCatalogEmptyCatalog,
              ),
              columns: <AppListTableColumn<ClinicalCatalogOption>>[
                AppListTableColumn<ClinicalCatalogOption>(
                  id: 'name',
                  label: l10n.accessAdminColumnName,
                  cellBuilder: (_, ClinicalCatalogOption item) =>
                      Text(item.displayTitle),
                ),
              ],
              mobileItemBuilder:
                  (BuildContext context, ClinicalCatalogOption item) =>
                      AppListTableMobileItem(title: item.displayTitle),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
