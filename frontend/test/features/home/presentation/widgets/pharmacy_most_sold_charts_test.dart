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
  group('pharmacyOrderStatusSection', () {
    test('maps order status ids and labels to pharmacy desk sections', () {
      expect(
        pharmacyOrderStatusSection(segmentId: 'ordered'),
        'queue',
      );
      expect(
        pharmacyOrderStatusSection(segmentId: 'partially_dispensed'),
        'in-progress',
      );
      expect(
        pharmacyOrderStatusSection(label: 'Dispensed'),
        'completed',
      );
      expect(
        pharmacyOrderStatusSection(label: 'Cancelled'),
        'cancelled',
      );
      expect(pharmacyOrderStatusSection(segmentId: 'unknown'), isNull);
    });
  });

  group('PharmacyMostSoldCharts', () {
    testWidgets(
      'shows header controls and qty/amount toggle when money allowed; hides profit without cost',
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
                    body: SingleChildScrollView(
                      child: PharmacyMostSoldCharts(
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
        expect(find.text('Today'), findsWidgets);
        expect(find.text('Top 5'), findsWidgets);
        expect(find.text('Bar'), findsWidgets);
        expect(find.text('Sold drugs'), findsOneWidget);
        expect(find.text('Para'), findsWidgets);
        expect(find.text('Period'), findsNothing);
        expect(find.text('Chart'), findsNothing);

        // Controls sit above the chart; sold-drugs list stays under the chart.
        final Finder chart = find.byKey(const ValueKey<String>('dashboard-trend-chart'));
        expect(chart, findsOneWidget);
        final double todayBottom =
            tester.getBottomLeft(find.text('Today').first).dy;
        final double chartTop = tester.getTopLeft(chart).dy;
        expect(chartTop, greaterThan(todayBottom));

        final double listTop = tester.getTopLeft(find.text('Sold drugs')).dy;
        expect(listTop, greaterThan(chartTop));

        // Controls share one horizontal band (period / top / chart / metric).
        final double todayY = tester.getCenter(find.text('Today').first).dy;
        final double topY = tester.getCenter(find.text('Top 5').first).dy;
        final double lineY = tester.getCenter(find.text('Bar').first).dy;
        final double qtyY = tester.getCenter(find.text('Qty')).dy;
        expect((todayY - topY).abs(), lessThan(12));
        expect((todayY - lineY).abs(), lessThan(12));
        expect((todayY - qtyY).abs(), lessThan(12));

        await tester.tap(find.text('Amount'));
        await tester.pumpAndSettle();
        expect(find.text('Amount'), findsOneWidget);
      },
    );

    testWidgets(
      'always renders a zero chart when most-sold series is empty',
      (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appAccessPolicyProvider.overrideWithValue(
              _policy(<AppPermission>{AppPermissions.pharmacyRead}),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (BuildContext context) {
                return Scaffold(
                  body: SingleChildScrollView(
                    child: PharmacyMostSoldCharts(
                      dashboard: _dashboard(
                        mostSold: HomeMostSoldSeries.empty,
                        trendPoints: <HomeTrendPoint>[
                          HomeTrendPoint(
                            id: 'd1',
                            date: DateTime(2026, 8, 1),
                            value: 0,
                            label: 'Aug 1',
                          ),
                        ],
                      ),
                      l10n: AppLocalizations.of(context)!,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(
        find.text('No dispensed drug sales in the selected period.'),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('dashboard-trend-chart')),
        findsOneWidget,
      );
      expect(find.text('Sold drugs'), findsNothing);
      expect(find.text('#1'), findsWidgets);

      await tester.tap(find.text('Bar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pie').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('dashboard-pie-chart')),
        findsOneWidget,
      );
    });

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
                  body: SingleChildScrollView(
                    child: PharmacyMostSoldCharts(
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

HomeDashboard _dashboard({
  required HomeMostSoldSeries mostSold,
  List<HomeTrendPoint> trendPoints = const <HomeTrendPoint>[],
}) {
  final HomeDashboardProfile profile = homeProfileForRole(AppRole.pharmacist);
  return HomeDashboard(
    state: HomeDashboardLoadState.ready,
    profile: profile,
    context: HomeDashboardContext(roleValue: profile.role.value),
    statusCards: const <HomeStatusCard>[],
    trend: HomeDashboardTrend(
      title: 'Most sold drugs',
      subtitle: '',
      points: trendPoints,
    ),
    distribution: const HomeDashboardDistribution(
      title: 'Order status mix',
      subtitle: '',
      total: 4,
      segments: <HomeDistributionSegment>[
        HomeDistributionSegment(
          id: 'ordered',
          label: 'Ordered',
          value: 1,
        ),
        HomeDistributionSegment(
          id: 'partially_dispensed',
          label: 'Partially dispensed',
          value: 1,
        ),
        HomeDistributionSegment(
          id: 'dispensed',
          label: 'Dispensed',
          value: 1,
        ),
        HomeDistributionSegment(
          id: 'cancelled',
          label: 'Cancelled',
          value: 1,
        ),
      ],
    ),
    quickActionIds: const <String>[],
    shortcutIds: const <String>[],
    queuePreview: const <HomeQueueItem>[],
    alerts: const <HomeAlertItem>[],
    activity: const <HomeActivityItem>[],
    tenantOptions: const <HomeTenantOption>[],
    mostSold: mostSold,
  );
}
