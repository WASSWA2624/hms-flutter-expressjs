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
import 'package:hosspi_hms/features/mortuary/data/repositories/mortuary_repository_impl.dart';
import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';
import 'package:hosspi_hms/features/mortuary/domain/repositories/mortuary_repository.dart';
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_access.dart';
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_intake_billing_inventory.dart';
import 'package:hosspi_hms/features/mortuary/presentation/pages/mortuary_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockMortuaryRepository extends Mock implements MortuaryRepository {}

const MortuaryBillableEvent _billingEvent = MortuaryBillableEvent(
  id: 'bill-intake-1',
  eventType: 'STORAGE',
  description: 'Cold storage day',
  amountText: '50.00',
  currency: 'USD',
  status: 'PENDING',
  billingReferenceId: 'inv-mort-1',
);

const MortuaryWorkspaceItem _caseItem = MortuaryWorkspaceItem(
  id: 'case-intake-1',
  displayId: 'MOR-INT-001',
  status: 'RECEIVED',
  identificationStatus: 'VERIFIED',
  billingStatus: 'PENDING',
  patientId: 'PAT-INT-1',
  patientLabel: 'Intake Billing Patient',
  deceasedProfileLabel: 'Intake Deceased',
  storageUnitLabel: 'Cold Unit A',
  storageSlotLabel: 'A-01',
  billableEvents: <MortuaryBillableEvent>[_billingEvent],
);

const AppModuleEntitlement _mortuaryModule = AppModuleEntitlement(
  code: mortuaryActiveModule,
  licenseStatus: 'ACTIVE',
);

const AppModuleEntitlement _billingModule = AppModuleEntitlement(
  code: 'billing-payments',
  licenseStatus: 'ACTIVE',
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
            _mortuaryModule,
            if (needsBilling) _billingModule,
          ],
      isAuthorizationHydrated: true,
    ),
  );
}

MortuaryWorkspacePayload _payload(
  MortuaryWorkspaceQuery query, {
  List<MortuaryWorkspaceItem> items = const <MortuaryWorkspaceItem>[_caseItem],
}) {
  return MortuaryWorkspacePayload(
    items: AppPage<MortuaryWorkspaceItem>(
      items: items,
      request: query.pageRequest,
      totalItemCount: items.length,
    ),
    lookups: const MortuaryLookupData(),
    summary: const <MortuarySummaryItem>[
      MortuarySummaryItem(id: 'total_cases', value: 1),
      MortuarySummaryItem(id: 'identification_pending', value: 1),
    ],
    queues: const <MortuaryQueueSummary>[
      MortuaryQueueSummary(
        queue: mortuaryQueueIdentificationPending,
        count: 1,
        panel: mortuaryPanelIntake,
        resource: mortuaryResourceCases,
      ),
    ],
    panels: const <MortuaryPanelSummary>[
      MortuaryPanelSummary(
        id: mortuaryPanelOverview,
        count: 1,
        defaultResource: mortuaryResourceCases,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelIntake,
        count: 1,
        defaultResource: mortuaryResourceCases,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelStorage,
        count: 0,
        defaultResource: mortuaryResourceStorageAssignments,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelCustody,
        count: 0,
        defaultResource: mortuaryResourceCustodyEvents,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelRelease,
        count: 0,
        defaultResource: mortuaryResourceReleaseAuthorisations,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelReporting,
        count: 0,
        defaultResource: mortuaryResourcePostMortemRequests,
      ),
    ],
    filters: query,
    lastUpdatedAt: DateTime.parse('2026-05-20T10:00:00.000Z'),
  );
}

void _stubRepository(
  _MockMortuaryRepository repository, {
  List<MortuaryWorkspaceItem> items = const <MortuaryWorkspaceItem>[_caseItem],
}) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final MortuaryWorkspaceQuery query =
        invocation.positionalArguments.single as MortuaryWorkspaceQuery;
    return Result<MortuaryWorkspacePayload>.success(
      _payload(query, items: items),
    );
  });
  when(
    () => repository.getItem(
      resource: any(named: 'resource'),
      id: any(named: 'id'),
      baseQuery: any(named: 'baseQuery'),
    ),
  ).thenAnswer(
    (_) async => Result<MortuaryWorkspaceItem>.success(
      items.isEmpty ? _caseItem : items.first,
    ),
  );
}

Future<void> _pumpIntake(
  WidgetTester tester, {
  required _MockMortuaryRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<MortuaryWorkspaceItem> items = const <MortuaryWorkspaceItem>[_caseItem],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, items: items);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/mortuary?panel=intake',
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
          return const Scaffold(body: Text('Billing workspace'));
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
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockMortuaryRepository repository;

  setUp(() {
    repository = _MockMortuaryRepository();
    registerFallbackValue(const MortuaryWorkspaceQuery());
  });

  group('Mortuary Intake billing inventory (AC1)', () {
    test('classifies every financially relevant atom', () {
      expect(MortuaryIntakeBillingInventory.all, isNotEmpty);
      for (final MortuaryIntakeFinancialAtom atom
          in MortuaryIntakeBillingInventory.all) {
        expect(atom.id, isNotEmpty);
        expect(atom.label, isNotEmpty);
        final bool billable =
            atom.financialClass == MortuaryIntakeFinancialClass.createCharge ||
            atom.financialClass == MortuaryIntakeFinancialClass.settle ||
            atom.financialClass == MortuaryIntakeFinancialClass.adjust ||
            atom.financialClass == MortuaryIntakeFinancialClass.reverse ||
            atom.financialClass == MortuaryIntakeFinancialClass.defer;
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
            reason: '${atom.id} must declare NOT_* audit code',
          );
        }
      }
    });

    test('billable mounted atoms reuse shared Billing paths', () {
      expect(
        MortuaryIntakeBillingInventory.allBillableAtomsWireThroughBilling,
        isTrue,
      );
      for (final MortuaryIntakeFinancialAtom atom
          in MortuaryIntakeBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotEmpty);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(
            contains('billing'),
            contains('persist'),
            contains('mortuary'),
            contains('approutes'),
          ),
        );
      }
    });

    test('inline cashier settle/adjust atoms are not mounted', () {
      expect(MortuaryIntakeBillingInventory.collectPayment.mounted, isFalse);
      expect(MortuaryIntakeBillingInventory.adjustRefund.mounted, isFalse);
      expect(MortuaryIntakeBillingInventory.absentInlineCollect.mounted, isFalse);
      expect(
        MortuaryIntakeBillingInventory.forbidsInlineCashier(
          MortuaryIntakeFinancialClass.settle,
        ),
        isTrue,
      );
    });

    test('create-charge fee atoms declare applyMortuaryBillableEventBilling', () {
      for (final MortuaryIntakeFinancialAtom atom in <MortuaryIntakeFinancialAtom>[
        MortuaryIntakeBillingInventory.storageFee,
        MortuaryIntakeBillingInventory.embalmingFee,
        MortuaryIntakeBillingInventory.viewingFee,
        MortuaryIntakeBillingInventory.releaseFee,
      ]) {
        expect(atom.mounted, isFalse);
        expect(atom.billingPath, contains('persistMortuaryBillableEventBilling'));
      }
    });
  });

  group('Mortuary Intake billing UX (AC2-AC4)', () {
    testWidgets(
      'authorized reader has no collect/adjust; Open billing requires billing:read',
      (WidgetTester tester) async {
        await _pumpIntake(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.mortuaryRead},
          ),
        );

        expect(find.text('Intake Deceased'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.text('Open billing'), findsNothing);
        expectFlatSections(tester);

        await tester.tap(find.text('Intake Deceased').first);
        await tester.pumpAndSettle();

        expect(find.text('Open billing'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'billing:read shows Open billing and pending status parity',
      (WidgetTester tester) async {
        await _pumpIntake(
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

        await tester.tap(find.text('Intake Deceased').first);
        await tester.pumpAndSettle();

        expect(find.text('Open billing'), findsWidgets);
        expect(find.textContaining('Pending'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(
          canOpenMortuaryBilling(
            _policy(
              permissions: <AppPermission>{
                AppPermissions.mortuaryRead,
                AppPermissions.billingRead,
              },
            ),
            mortuaryPanelIntake,
          ),
          isTrue,
        );
        expectFlatSections(tester);
      },
    );

    testWidgets('list chrome has no redundant cashier entry points', (
      WidgetTester tester,
    ) async {
      await _pumpIntake(
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

  group('Mortuary Intake section layout (AC5)', () {
    testWidgets('desktop Intake: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpIntake(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.mortuaryRead,
            AppPermissions.mortuaryBillingEvent,
            AppPermissions.billingRead,
          },
        ),
        physicalSize: const Size(1920, 1200),
      );
      expectFlatSections(tester);

      await tester.tap(find.text('Intake Deceased').first);
      await tester.pumpAndSettle();
      expectFlatSections(tester);
      expect(find.byType(AppWorkspaceDetailPanel), findsWidgets);
    });

    testWidgets('mobile Intake: flat sections', (WidgetTester tester) async {
      await _pumpIntake(
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
      await _pumpIntake(
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
      await tester.tap(find.text('Intake Deceased').first);
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpIntake(
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
      await tester.tap(find.text('Intake Deceased').first);
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });

  group('Mortuary Intake UI states (AC4, AC6)', () {
    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpIntake(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.mortuaryRead},
        ),
        items: const <MortuaryWorkspaceItem>[],
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });
  });
}
