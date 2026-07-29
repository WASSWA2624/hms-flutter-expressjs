import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/theater/data/repositories/theater_repository_impl.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/features/theater/domain/repositories/theater_repository.dart';
import 'package:hosspi_hms/features/theater/presentation/pages/theater_workspace_page.dart';
import 'package:hosspi_hms/features/theater/presentation/theater_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockTheaterRepository extends Mock implements TheaterRepository {}

const TheaterCase _case = TheaterCase(
  id: 'TC-1',
  displayId: 'TC-1',
  patientDisplayName: 'P One',
  status: 'SCHEDULED',
  workflowStage: 'PRE_OP',
);

AppAccessPolicy _billingOnly() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'a'),
      user: AuthUserProfile(
        roles: const <String>['BILLING'],
        tenantId: 't1',
        facilityId: 'f1',
      ),
      permissions: <AppPermission>{AppPermissions.billingRead},
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: theaterTheatreAnesthesiaModule,
          licenseStatus: 'ACTIVE',
        ),
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const TheaterCaseQuery());
  });

  test('recovery requirement allowed for billing-only', () {
    final AppAccessPolicy p = _billingOnly();
    // ignore: avoid_print
    print('recovery allowed: '
        '${theaterBoardTabRequirement(TheaterSection.recovery).isAllowed(p)}');
    // ignore: avoid_print
    print('allowed sections: ${theaterAllowedSections(p)}');
    // ignore: avoid_print
    print('empty req allowed: ${const AccessRequirement().isAllowed(p)}');
  });

  for (final String section in <String>['scheduled', 'in-theater']) {
    testWidgets('diag $section', (WidgetTester tester) async {
      final _MockTheaterRepository repo = _MockTheaterRepository();
      when(() => repo.listCases(any())).thenAnswer(
        (_) async => const Result<AppPage<TheaterCase>>.success(
          AppPage<TheaterCase>(
            items: <TheaterCase>[_case],
            request: AppPageRequest(pageSize: 12),
            totalItemCount: 1,
          ),
        ),
      );
      when(() => repo.getCase(any())).thenAnswer(
        (_) async => const Result<TheaterCase>.success(_case),
      );
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/theater?section=$section',
        routes: <RouteBase>[
          GoRoute(
            path: '/theater',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: TheaterWorkspacePage(
                  initialQuery: TheaterBoardQuery.fromUri(state.uri),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            theaterRepositoryProvider.overrideWithValue(repo),
            followUpTabCountProvider.overrideWith(
              (Ref ref, FollowUpWorklistScope scope) => null,
            ),
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(_billingOnly()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));

      // ignore: avoid_print
      print('[$section] strips: '
          '${find.byType(AppTabStrip).evaluate().length} '
          'texts: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).where((d) => d != null && d.isNotEmpty).toList()}');
    });
  }
}
