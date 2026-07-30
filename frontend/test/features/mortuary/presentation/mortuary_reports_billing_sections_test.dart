import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
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
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_reports_billing_inventory.dart';
import 'package:hosspi_hms/features/mortuary/presentation/pages/mortuary_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockMortuaryRepository extends Mock implements MortuaryRepository {}

const MortuaryBillableEvent _billableEvent = MortuaryBillableEvent(
  id: 'bill-1',
  eventType: 'STORAGE_FEE',
  description: 'Cold storage day 1',
  amountText: '50.00',
  currency: 'UGX',
  status: 'OPEN',
  billingReferenceId: 'inv-mort-1',
);

const MortuaryWorkspaceItem _reportsItem = MortuaryWorkspaceItem(
  id: 'pm-1',
  displayId: 'MOR-PM-1',
  resource: mortuaryResourcePostMortemRequests,
  status: 'SCHEDULED',
  identificationStatus: 'VERIFIED',
  billingStatus: 'UNSETTLED',
  patientId: 'PAT-REPORTS-1',
  deceasedProfileLabel: 'Reports Patient',
  requestReason: 'Coroner request',
  diagnosticsReferenceId: 'DX-9',
  requestedByName: 'Dr. A',
  scheduledAt: null,
  billableEvents: <MortuaryBillableEvent>[_billableEvent],
  mortuaryCase: MortuaryCaseSummary(
    id: 'MOR-001',
    status: 'IN_STORAGE',
    identificationStatus: 'VERIFIED',
    billingStatus: 'UNSETTLED',
    patientId: 'PAT-REPORTS-1',
    deceasedProfileLabel: 'Reports Patient',
  ),
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
}) {
  final bool needsBilling = permissions.contains(AppPermissions.billingRead);
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

MortuaryWorkspacePayload _payload(MortuaryWorkspaceQuery query) {
  return MortuaryWorkspacePayload(
    items: AppPage<MortuaryWorkspaceItem>(
      items: const <MortuaryWorkspaceItem>[_reportsItem],
      request: query.pageRequest,
      totalItemCount: 1,
    ),
    lookups: const MortuaryLookupData(),
    summary: const <MortuarySummaryItem>[
      MortuarySummaryItem(id: 'total_cases', value: 1),
    ],
    queues: const <MortuaryQueueSummary>[],
    panels: const <MortuaryPanelSummary>[
      MortuaryPanelSummary(
        id: mortuaryPanelOverview,
        count: 1,
        defaultResource: mortuaryResourceCases,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelReporting,
        count: 1,
        defaultResource: mortuaryResourcePostMortemRequests,
      ),
    ],
    filters: query,
    lastUpdatedAt: DateTime.parse('2026-05-20T10:00:00.000Z'),
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
    (_) async => const Result<MortuaryWorkspaceItem>.success(_reportsItem),
  );
}

Future<void> _pumpReportsTab(
  WidgetTester tester, {
  required _MockMortuaryRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/mortuary?panel=reporting',
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
          final String? patientId = state.uri.queryParameters['patient_id'];
          return Scaffold(
            body: Text(
              patientId == null || patientId.isEmpty
                  ? 'Billing workspace'
                  : 'Billing workspace patient=$patientId',
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
        appAccessPolicyProvider.overrideWithValue(accessPolicy),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

AppListTable<MortuaryWorkspaceItem> _table(WidgetTester tester) {
  return tester.widget<AppListTable<MortuaryWorkspaceItem>>(
    find.byType(AppListTable<MortuaryWorkspaceItem>),
  );
}

Future<void> _openDetail(WidgetTester tester) async {
  final AppListTable<MortuaryWorkspaceItem> table = _table(tester);
  expect(table.onRowSelected, isNotNull);
  table.onRowSelected!(_reportsItem);
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

  group('Mortuary Reports financial inventory (AC1)', () {
    test('classifies every financially relevant atom', () {
      expect(MortuaryReportsBillingInventory.all, isNotEmpty);
      for (final MortuaryReportsFinancialAtom atom
          in MortuaryReportsBillingInventory.all) {
        expect(atom.id, isNotEmpty);
        expect(atom.label, isNotEmpty);
        final bool billable =
            atom.financialClass == MortuaryReportsFinancialClass.createCharge ||
            atom.financialClass == MortuaryReportsFinancialClass.settle ||
            atom.financialClass == MortuaryReportsFinancialClass.adjust ||
            atom.financialClass == MortuaryReportsFinancialClass.reverse ||
            atom.financialClass == MortuaryReportsFinancialClass.defer;
        if (billable && atom.mounted) {
          expect(
            atom.billingPath,
            isNotNull,
            reason: '${atom.id} must declare billingPath',
          );
        }
        if (!billable) {
          expect(
            atom.auditCode,
            isNotNull,
            reason: '${atom.id} must declare NOT_* / NO_CHARGE audit code',
          );
        }
      }
      expect(mortuaryReportsBillingScopeNote, contains('persistMortuary'));
    });

    test('billable mounted atoms reuse shared Billing paths', () {
      expect(
        MortuaryReportsBillingInventory.allBillableAtomsWireThroughBilling,
        isTrue,
      );
      for (final MortuaryReportsFinancialAtom atom
          in MortuaryReportsBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotEmpty);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(<Matcher>[
            contains('billing'),
            contains('persist'),
            contains('mortuary'),
            contains('invoice'),
          ]),
        );
      }
    });

    test('inline cashier settle/adjust atoms are not mounted', () {
      expect(MortuaryReportsBillingInventory.collectPayment.mounted, isFalse);
      expect(MortuaryReportsBillingInventory.adjustRefund.mounted, isFalse);
      expect(
        MortuaryReportsBillingInventory.forbidsInlineCashier(
          MortuaryReportsFinancialClass.settle,
        ),
        isTrue,
      );
    });

    test('Open billing gate reuses billing:read', () {
      expect(
        identical(
          MortuaryReportsAtomPermissions.openBilling,
          billingReadRequirement,
        ),
        isTrue,
      );
    });

    test('related-row billing status falls back to flattened mirror', () {
      const MortuaryWorkspaceItem flattenedOnly = MortuaryWorkspaceItem(
        id: 'pm-flat',
        resource: mortuaryResourcePostMortemRequests,
        billingStatus: 'UNSETTLED',
      );
      expect(flattenedOnly.caseBillingStatus, 'UNSETTLED');
    });
  });

  group('Mortuary Reports billing UX (AC2-AC4)', () {
    testWidgets(
      'authorized reader has no collect/adjust; Open billing requires billing:read',
      (WidgetTester tester) async {
        await _pumpReportsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.mortuaryRead},
          ),
        );

        expect(find.text('Reports Patient'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.text('Open billing'), findsNothing);
        expectFlatSections(tester);

        await _openDetail(tester);

        expect(find.text('Open billing'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'billing:read shows Open billing (patient-scoped) without cashier',
      (WidgetTester tester) async {
        await _pumpReportsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.mortuaryRead,
              AppPermissions.billingRead,
            },
          ),
        );

        await _openDetail(tester);

        expect(find.text('Open billing'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expectFlatSections(tester);

        await tester.tap(find.text('Open billing'));
        await tester.pumpAndSettle();
        expect(
          find.text('Billing workspace patient=PAT-REPORTS-1'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'billing ∩ shows events panel with Billing reference parity',
      (WidgetTester tester) async {
        await _pumpReportsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.mortuaryRead,
              AppPermissions.mortuaryBillingEvent,
              AppPermissions.billingRead,
            },
          ),
        );

        await _openDetail(tester);

        expect(find.text('Billing'), findsOneWidget);
        expect(find.textContaining('Cold storage day 1'), findsOneWidget);
        expect(find.textContaining('inv-mort-1'), findsWidgets);
        expectFlatSections(tester);
      },
    );

    testWidgets('list chrome has no redundant cashier entry points', (
      WidgetTester tester,
    ) async {
      await _pumpReportsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.mortuaryRead,
            AppPermissions.mortuaryWrite,
          },
        ),
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });
  });

  group('Mortuary Reports section layout (AC5)', () {
    testWidgets('desktop Reports: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpReportsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.mortuaryRead,
            AppPermissions.billingRead,
            AppPermissions.mortuaryBillingEvent,
          },
        ),
        physicalSize: const Size(1920, 1200),
      );
      expectFlatSections(tester);

      await _openDetail(tester);
      expectFlatSections(tester);
    });

    testWidgets('mobile Reports: flat sections', (WidgetTester tester) async {
      await _pumpReportsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.mortuaryRead},
        ),
        physicalSize: const Size(390, 844),
      );
      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpReportsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.mortuaryRead,
            AppPermissions.billingRead,
          },
        ),
        themeMode: ThemeMode.light,
      );
      await _openDetail(tester);
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpReportsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.mortuaryRead,
            AppPermissions.billingRead,
          },
        ),
        themeMode: ThemeMode.dark,
      );
      await _openDetail(tester);
      expectFlatSections(tester);
    });
  });
}
