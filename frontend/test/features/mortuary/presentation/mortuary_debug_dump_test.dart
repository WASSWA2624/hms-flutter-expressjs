import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/mortuary/data/repositories/mortuary_repository_impl.dart';
import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';
import 'package:hosspi_hms/features/mortuary/domain/repositories/mortuary_repository.dart';
import 'package:hosspi_hms/features/mortuary/presentation/pages/mortuary_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockMortuaryRepository extends Mock implements MortuaryRepository {}

void main() {
  testWidgets('debug dump mortuary surface', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final _MockMortuaryRepository repository = _MockMortuaryRepository();
    registerFallbackValue(const MortuaryWorkspaceQuery());
    when(() => repository.getWorkspace(any())).thenAnswer((invocation) async {
      final MortuaryWorkspaceQuery query =
          invocation.positionalArguments.single as MortuaryWorkspaceQuery;
      return Result<MortuaryWorkspacePayload>.success(
        MortuaryWorkspacePayload(
          items: AppPage<MortuaryWorkspaceItem>(
            items: const <MortuaryWorkspaceItem>[
              MortuaryWorkspaceItem(
                id: 'case-1',
                displayId: 'MOR-001',
                status: 'IN_STORAGE',
                identificationStatus: 'VERIFIED',
                billingStatus: 'SETTLED',
                deceasedProfileLabel: 'Amina K.',
              ),
            ],
            request: query.pageRequest,
            totalItemCount: 1,
          ),
          lookups: const MortuaryLookupData(),
          summary: const <MortuarySummaryItem>[],
          queues: const <MortuaryQueueSummary>[],
          panels: const <MortuaryPanelSummary>[],
          filters: query,
        ),
      );
    });
    when(
      () => repository.getItem(
        resource: any(named: 'resource'),
        id: any(named: 'id'),
        baseQuery: any(named: 'baseQuery'),
      ),
    ).thenAnswer(
      (_) async => const Result<MortuaryWorkspaceItem>.success(
        MortuaryWorkspaceItem(
          id: 'case-1',
          displayId: 'MOR-001',
          deceasedProfileLabel: 'Amina K.',
        ),
      ),
    );

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/mortuary',
      routes: <RouteBase>[
        GoRoute(
          path: '/mortuary',
          builder: (BuildContext context, GoRouterState state) {
            return const Scaffold(body: MortuaryWorkspacePage());
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mortuaryRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(preferences),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.ready(),
          ),
          appAccessPolicyProvider.overrideWithValue(
            AppAccessPolicy.fromSession(
              AuthSession(
                tokens: SessionTokens(accessToken: 'access-token'),
                user: const AuthUserProfile(
                  roles: <String>['MORTUARY_STAFF'],
                  facilityId: 'facility-1',
                ),
                permissions: <AppPermission>{
                  AppPermissions.mortuaryRead,
                  AppPermissions.mortuaryWrite,
                },
                moduleEntitlements: const <AppModuleEntitlement>[
                  AppModuleEntitlement(
                    code: 'mortuary',
                    licenseStatus: 'ACTIVE',
                  ),
                ],
              ),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final Size size = tester.getSize(find.byType(MaterialApp).first);
    final AppListTable<MortuaryWorkspaceItem> table =
        tester.widget<AppListTable<MortuaryWorkspaceItem>>(
          find.byType(AppListTable<MortuaryWorkspaceItem>),
        );
    debugPrint('MEDIA_SIZE=$size');
    debugPrint('HAS_TABLE=${find.byType(AppListTable<MortuaryWorkspaceItem>).evaluate().length}');
    debugPrint('SEARCH_SHOW_ADV=${table.search?.showAdvancedFilterButton}');
    debugPrint('SEARCH_FILTER_GROUPS=${table.search?.filterGroups.length}');
    debugPrint('SEARCH_ON_FILTER=${table.search?.onFilterChanged != null}');
    debugPrint('SEARCH_LABEL=${table.search?.advancedFilterButtonLabel}');
    debugPrint('HAS_FILTERS_TEXT=${find.text('Filters').evaluate().length}');
    debugPrint('HAS_SETTINGS_TEXT=${find.text('Settings').evaluate().length}');
    debugPrint('HAS_AMINA=${find.text('Amina K.').evaluate().length}');
    debugPrint('HAS_ASSIGN=${find.text('Assign storage').evaluate().length}');
    debugPrint('HAS_SEARCH=${find.byType(AppSearchBar).evaluate().length}');
    debugPrint('HAS_ICON_FILTER_OUT=${find.byIcon(Icons.filter_alt_outlined).evaluate().length}');
    debugPrint('HAS_ICON_FILTER=${find.byIcon(Icons.filter_alt).evaluate().length}');
    debugPrint('FILTER_ACTIVE_COUNT=${table.search?.filterValue.activeCount}');
    debugPrint('FILTER_IS_ACTIVE=${table.search?.filterValue.isActive}');
    debugPrint('FILTER_OPTIONS=${table.search?.filterValue.options}');
    for (final String text in <String>['Filters', 'Filters (1)', 'Filter', 'Settings']) {
      debugPrint('TEXT_$text=${find.text(text).evaluate().length}');
    }
    debugPrint('SEM_FILTERS=${find.bySemanticsLabel(RegExp(r'Filter')).evaluate().length}');

    expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
  });
}
