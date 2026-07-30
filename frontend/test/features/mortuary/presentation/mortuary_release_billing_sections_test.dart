import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/mortuary/data/repositories/mortuary_repository_impl.dart';
import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';
import 'package:hosspi_hms/features/mortuary/domain/repositories/mortuary_repository.dart';
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_access.dart';
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_release_billing_inventory.dart';
import 'package:hosspi_hms/features/mortuary/presentation/pages/mortuary_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockMortuaryRepository extends Mock implements MortuaryRepository {}

const MortuaryBillableEvent _billableEvent = MortuaryBillableEvent(
  id: 'bill-rel-1',
  eventType: 'RELEASE_FEE',
  description: 'Release preparation',
  amountText: '75.00',
  currency: 'UGX',
  status: 'PENDING',
  billingReferenceId: 'inv-mort-rel-1',
);

const MortuaryWorkspaceItem _releaseItem = MortuaryWorkspaceItem(
  id: 'release-bill-1',
  displayId: 'MOR-REL-B1',
  resource: mortuaryResourceReleaseAuthorisations,
  status: 'READY_FOR_RELEASE',
  identificationStatus: 'VERIFIED',
  billingStatus: 'UNSETTLED',
  patientId: 'patient-uuid-rel',
  deceasedProfileLabel: 'Release Billing Patient',
  recipientName: 'Next of Kin',
  recipientRelationship: 'Spouse',
  storageUnitLabel: 'Cold Bay A-1',
  billableEvents: <MortuaryBillableEvent>[_billableEvent],
  releaseAuthorisations: <MortuaryReleaseAuthorisation>[
    MortuaryReleaseAuthorisation(
      id: 'auth-rel-1',
      status: 'PENDING_APPROVAL',
      recipientName: 'Next of Kin',
      recipientRelationship: 'Spouse',
    ),
  ],
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
}) {
  final bool needsBilling =
      permissions.contains(AppPermissions.billingRead) ||
      permissions.contains(AppPermissions.billingWrite) ||
      permissions.contains(AppPermissions.mortuaryBillingEvent);
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['MORTUARY_STAFF'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements:
          modules ??
          <AppModuleEntitlement>[
            const AppModuleEntitlement(
              code: mortuaryActiveModule,
              licenseStatus: 'ACTIVE',
            ),
            if (needsBilling)
              const AppModuleEntitlement(
                code: 'billing-payments',
                licenseStatus: 'ACTIVE',
              ),
          ],
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _readPolicy() {
  return _policy(permissions: <AppPermission>{AppPermissions.mortuaryRead});
}

AppAccessPolicy _openBillingPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.mortuaryRead,
      AppPermissions.billingRead,
    },
  );
}

AppAccessPolicy _billingPanelPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.mortuaryRead,
      AppPermissions.mortuaryBillingEvent,
      AppPermissions.billingRead,
    },
  );
}

MortuaryWorkspacePayload _payload(MortuaryWorkspaceQuery query) {
  return MortuaryWorkspacePayload(
    items: AppPage<MortuaryWorkspaceItem>(
      items: const <MortuaryWorkspaceItem>[_releaseItem],
      request: query.pageRequest,
      totalItemCount: 1,
    ),
    lookups: const MortuaryLookupData(),
    summary: const <MortuarySummaryItem>[
      MortuarySummaryItem(id: 'unsettled_billing', value: 1),
    ],
    queues: const <MortuaryQueueSummary>[
      MortuaryQueueSummary(
        queue: mortuaryQueueUnsettledBilling,
        count: 1,
        panel: mortuaryPanelRelease,
      ),
    ],
    panels: const <MortuaryPanelSummary>[
      MortuaryPanelSummary(
        id: mortuaryPanelRelease,
        count: 1,
        defaultResource: mortuaryResourceReleaseAuthorisations,
      ),
    ],
    filters: query,
    lastUpdatedAt: DateTime.parse('2026-07-30T10:00:00.000Z'),
  );
}

void _stubWorkspace(_MockMortuaryRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final MortuaryWorkspaceQuery query =
        invocation.positionalArguments.single as MortuaryWorkspaceQuery;
    return Result<MortuaryWorkspacePayload>.success(_payload(query));
  });
  when(
    () => repository.getItem(
      resource: any(named: 'resource'),
      id: any(named: 'id'),
      baseQuery: any(named: 'baseQuery'),
    ),
  ).thenAnswer(
    (_) async => const Result<MortuaryWorkspaceItem>.success(_releaseItem),
  );
}

Future<GoRouter> _pumpReleaseTab(
  WidgetTester tester, {
  required _MockMortuaryRepository repository,
  required AppAccessPolicy policy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  _stubWorkspace(repository);

  String? navigatedLocation;
  final GoRouter router = GoRouter(
    initialLocation: '/mortuary?panel=release',
    routes: <RouteBase>[
      GoRoute(
        path: '/mortuary',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: MortuaryWorkspacePage(
              initialQuery: MortuaryRouteQuery.fromUri(state.uri),
            ),
          );
        },
      ),
      GoRoute(
        path: '/billing',
        builder: (BuildContext context, GoRouterState state) {
          navigatedLocation = state.uri.toString();
          return Scaffold(
            body: Text(
              'Billing workspace ${state.uri.queryParameters['patient_id'] == null ? '' : 'patient_id=${state.uri.queryParameters['patient_id']}'}',
            ),
          );
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
        appAccessPolicyProvider.overrideWithValue(policy),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();

  addTearDown(() {
    expect(
      navigatedLocation,
      anyOf(isNull, contains('/billing')),
      reason: 'navigation should only go to Billing when Open billing tapped',
    );
  });

  return router;
}

AppListTable<MortuaryWorkspaceItem> _table(WidgetTester tester) {
  return tester.widget<AppListTable<MortuaryWorkspaceItem>>(
    find.byType(AppListTable<MortuaryWorkspaceItem>),
  );
}

Future<void> _openDetail(WidgetTester tester) async {
  final AppListTable<MortuaryWorkspaceItem> table = _table(tester);
  expect(table.onRowSelected, isNotNull);
  table.onRowSelected!(_releaseItem);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockMortuaryRepository repository;

  setUpAll(() {
    registerFallbackValue(const MortuaryWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockMortuaryRepository();
  });

  group('Mortuary Release billing inventory (AC1)', () {
    test('every atom is classified billable or explicit not-billable', () {
      expect(MortuaryReleaseBillingInventory.all, isNotEmpty);
      for (final MortuaryReleaseFinancialAtom atom
          in MortuaryReleaseBillingInventory.all) {
        expect(atom.id, isNotEmpty);
        expect(atom.label, isNotEmpty);
        if (atom.financialClass == MortuaryReleaseFinancialClass.notBilled ||
            atom.financialClass == MortuaryReleaseFinancialClass.notRequired ||
            atom.financialClass == MortuaryReleaseFinancialClass.noCharge) {
          expect(atom.auditCode, isNotNull);
        }
      }
    });

    test('billable mounted atoms reuse shared Billing paths', () {
      expect(
        MortuaryReleaseBillingInventory.allBillableAtomsWireThroughBilling,
        isTrue,
      );
      for (final MortuaryReleaseFinancialAtom atom
          in MortuaryReleaseBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotNull);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(
            contains('billing'),
            contains('persist'),
            contains('mortuary'),
            contains('invoice'),
          ),
        );
      }
      expect(
        MortuaryReleaseBillingInventory.releaseFee.billingPath,
        contains('MORTUARY_RELEASE'),
      );
      expect(
        MortuaryReleaseBillingInventory.openBilling.billingPath,
        contains('AppRoutes.billing'),
      );
    });

    test('settle/adjust never use inline collection on this tab', () {
      expect(
        MortuaryReleaseBillingInventory.forbidsInlineCashier(
          MortuaryReleaseFinancialClass.settle,
        ),
        isTrue,
      );
      expect(MortuaryReleaseBillingInventory.collectPayment.mounted, isFalse);
      expect(MortuaryReleaseBillingInventory.adjustRefund.mounted, isFalse);
      expect(
        MortuaryReleaseBillingInventory.openBilling.requirement,
        same(MortuaryReleaseAtomPermissions.openBilling),
      );
      expect(
        MortuaryReleaseAtomPermissions.openBilling,
        same(billingReadRequirement),
      );
      expect(mortuaryReleaseBillingScopeNote, contains('Billing owns'));
    });
  });

  group('Mortuary Release billing wiring (AC2-AC4)', () {
    test('mortuary realtime includes billing for status parity', () {
      expect(
        RealtimeEventGroups.mortuary,
        containsAll(RealtimeEventGroups.billing),
      );
    });

    testWidgets(
      'unauthorized cannot Open billing or collect (no bypass) — mobile dark',
      (WidgetTester tester) async {
        await _pumpReleaseTab(
          tester,
          repository: repository,
          policy: _readPolicy(),
          viewport: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        expect(find.text('Release Billing Patient'), findsWidgets);
        expect(
          _table(tester).columns.map(
            (AppListTableColumn<MortuaryWorkspaceItem> column) => column.id,
          ),
          contains('billing_status'),
        );

        await _openDetail(tester);

        expect(find.text('Open billing'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.text('Billing'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'Open billing navigates to Billing (reuse, no fork) — desktop light',
      (WidgetTester tester) async {
        await _pumpReleaseTab(
          tester,
          repository: repository,
          policy: _openBillingPolicy(),
          themeMode: ThemeMode.light,
        );

        await _openDetail(tester);

        expect(find.text('Open billing'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);

        await tester.tap(find.text('Open billing').first);
        await tester.pumpAndSettle();

        expect(find.textContaining('Billing workspace'), findsOneWidget);
        expect(
          find.textContaining('patient_id='),
          findsOneWidget,
          reason: 'Open billing must deep-link patient into Billing workspace',
        );
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'billing panel shows ledger events with Billing reference — desktop dark',
      (WidgetTester tester) async {
        await _pumpReleaseTab(
          tester,
          repository: repository,
          policy: _billingPanelPolicy(),
          themeMode: ThemeMode.dark,
        );

        await _openDetail(tester);

        expect(find.text('Billing'), findsOneWidget);
        expect(find.textContaining('Release preparation'), findsOneWidget);
        expect(find.textContaining('inv-mort-rel-1'), findsOneWidget);
        expect(find.text('Open billing'), findsWidgets);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'list chrome has no cashier entry points — mobile light',
      (WidgetTester tester) async {
        await _pumpReleaseTab(
          tester,
          repository: repository,
          policy: _openBillingPolicy(),
          viewport: const Size(390, 844),
          themeMode: ThemeMode.light,
        );

        expect(find.text('Release Billing Patient'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Approve release'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets('unsettled status parity tile on detail', (
      WidgetTester tester,
    ) async {
      await _pumpReleaseTab(
        tester,
        repository: repository,
        policy: _openBillingPolicy(),
      );
      await _openDetail(tester);

      expect(find.textContaining('Unsettl'), findsWidgets);
      expect(find.text('Clear billing'), findsWidgets);
      expectFlatSections(tester);
    });
  });

  group('Mortuary Release flat sections (AC5)', () {
    testWidgets('detail sections are siblings — no section-in-section', (
      WidgetTester tester,
    ) async {
      await _pumpReleaseTab(
        tester,
        repository: repository,
        policy: _billingPanelPolicy(),
      );
      await _openDetail(tester);

      expect(find.text('Identity and source'), findsOneWidget);
      expect(find.text('Release'), findsWidgets);
      expect(find.text('Billing'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expectFlatSections(tester);
    });
  });
}
