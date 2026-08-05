import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/pharmacy_most_sold_charts.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

void main() {
  group('PharmacyMostSoldCharts', () {
    testWidgets(
      'shows qty and amount toggle when money allowed; hides profit without cost',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appAccessPolicyProvider.overrideWithValue(
                _policy(<AppPermission>{
                  AppPermissions.pharmacyRead,
                  AppPermissions.billingRead,
                }),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (BuildContext context) {
                  return Scaffold(
                    body: PharmacyMostSoldCharts(
                      dashboard: _dashboard(
                        mostSold: HomeMostSoldSeries(
                          qty: <HomeTrendPoint>[
                            HomeTrendPoint(
                              id: 'para',
                              date: null,
                              value: 12,
                              label: 'Para',
                            ),
                          ],
                          amount: <HomeTrendPoint>[
                            HomeTrendPoint(
                              id: 'para',
                              date: null,
                              value: 120,
                              label: 'Para',
                            ),
                          ],
                        ),
                      ),
                      l10n: AppLocalizations.of(context)!,
                    ),
                  );
                },
              ),
            ),
          ),
        );

        expect(find.text('Qty'), findsOneWidget);
        expect(find.text('Amount'), findsOneWidget);
        expect(find.text('Profit'), findsNothing);

        await tester.tap(find.text('Amount'));
        await tester.pumpAndSettle();
        expect(find.text('Amount'), findsOneWidget);
      },
    );

    testWidgets('shows profit toggle when profit series has data', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appAccessPolicyProvider.overrideWithValue(
              _policy(<AppPermission>{
                AppPermissions.pharmacyRead,
                AppPermissions.reportsRead,
              }),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (BuildContext context) {
                return Scaffold(
                  body: PharmacyMostSoldCharts(
                    dashboard: _dashboard(
                      mostSold: HomeMostSoldSeries(
                        qty: <HomeTrendPoint>[
                          HomeTrendPoint(
                            id: 'para',
                            date: null,
                            value: 12,
                            label: 'Para',
                          ),
                        ],
                        amount: <HomeTrendPoint>[
                          HomeTrendPoint(
                            id: 'para',
                            date: null,
                            value: 120,
                            label: 'Para',
                          ),
                        ],
                        profit: <HomeTrendPoint>[
                          HomeTrendPoint(
                            id: 'para',
                            date: null,
                            value: 40,
                            label: 'Para',
                          ),
                        ],
                      ),
                    ),
                    l10n: AppLocalizations.of(context)!,
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Profit'), findsOneWidget);
      await tester.tap(find.text('Profit'));
      await tester.pumpAndSettle();
    });
  });
}

AppAccessPolicy _policy(Set<AppPermission> permissions) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(
        roles: <String>['PHARMACIST'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'pharmacy-dispensing',
          licenseStatus: 'ACTIVE',
        ),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

HomeDashboard _dashboard({required HomeMostSoldSeries mostSold}) {
  final HomeDashboardProfile profile = homeProfileForRole(AppRole.pharmacist);
  return HomeDashboard(
    state: HomeDashboardLoadState.ready,
    profile: profile,
    context: HomeDashboardContext(roleValue: profile.role.value),
    statusCards: const <HomeStatusCard>[],
    trend: const HomeDashboardTrend(
      title: 'Most sold drugs (last month)',
      subtitle: '',
      points: <HomeTrendPoint>[],
    ),
    distribution: HomeDashboardDistribution.empty,
    quickActionIds: const <String>[],
    shortcutIds: const <String>[],
    queuePreview: const <HomeQueueItem>[],
    alerts: const <HomeAlertItem>[],
    activity: const <HomeActivityItem>[],
    tenantOptions: const <HomeTenantOption>[],
    mostSold: mostSold,
  );
}
