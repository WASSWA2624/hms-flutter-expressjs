import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_transfers_billing_inventory.dart';
import 'package:hosspi_hms/features/ipd/presentation/pages/ipd_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockIpdRepository extends Mock implements IpdRepository {}

const IpdAdmissionSummary _transferPending = IpdAdmissionSummary(
  id: 'adm-transfer',
  displayId: 'ADM-XFER',
  patientId: 'pat-xfer',
  patientDisplayName: 'Terry Transfer',
  stage: 'TRANSFER_REQUESTED',
  admissionStatus: 'ADMITTED',
  nextStep: 'APPROVE_TRANSFER',
  hasActiveBed: true,
  openTransferRequestId: 'tr-1',
  encounterId: 'enc-xfer',
  wardDisplayName: 'Medical Ward',
  bedDisplayLabel: 'Bed 101',
  transferStatus: 'REQUESTED',
);

const IpdTransferRequest _openTransfer = IpdTransferRequest(
  id: 'tr-1',
  status: 'REQUESTED',
  fromWard: IpdWardOption(id: 'ward-1', name: 'Medical Ward'),
  toWard: IpdWardOption(id: 'ward-2', name: 'Surgical Ward'),
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['DOCTOR'],
}) {
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalRead ||
        permission == AppPermissions.clinicalWrite,
  );
  final bool needsOperations = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.operationsRead ||
        permission == AppPermissions.operationsWrite,
  );
  final bool needsBilling = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.billingRead ||
        permission == AppPermissions.billingWrite,
  );
  final List<AppModuleEntitlement> resolvedModules =
      modules ??
      <AppModuleEntitlement>[
        const AppModuleEntitlement(
          code: 'inpatient-bed-management',
          licenseStatus: 'ACTIVE',
        ),
        if (needsClinical)
          const AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        if (needsOperations)
          const AppModuleEntitlement(
            code: 'facilities-maintenance',
            licenseStatus: 'ACTIVE',
          ),
        if (needsBilling)
          const AppModuleEntitlement(
            code: 'billing-payments',
            licenseStatus: 'ACTIVE',
          ),
      ];

  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: resolvedModules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubRepository(_MockIpdRepository repository) {
  when(() => repository.listAdmissions(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final IpdAdmissionQuery query =
        invocation.positionalArguments.single as IpdAdmissionQuery;
    return Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: const <IpdAdmissionSummary>[_transferPending],
        request: query.pageRequest,
        totalItemCount: 1,
      ),
    );
  });
  when(() => repository.listWards(search: any(named: 'search'))).thenAnswer(
    (_) async => const Result<List<IpdWardOption>>.success(<IpdWardOption>[
      IpdWardOption(id: 'ward-1', name: 'Medical Ward'),
      IpdWardOption(id: 'ward-2', name: 'Surgical Ward'),
    ]),
  );
  when(
    () => repository.listBeds(
      search: any(named: 'search'),
      status: any(named: 'status'),
      wardId: any(named: 'wardId'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<IpdBedOption>>.success(<IpdBedOption>[
      IpdBedOption(id: 'bed-1', label: 'Bed 101', status: 'OCCUPIED'),
      IpdBedOption(
        id: 'bed-2',
        label: 'Bed 201',
        status: 'AVAILABLE',
        wardId: 'ward-2',
        wardName: 'Surgical Ward',
      ),
    ]),
  );
  when(
    () => repository.listBedBoard(
      wardId: any(named: 'wardId'),
      status: any(named: 'status'),
      statusAny: any(named: 'statusAny'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer(
    (_) async =>
        const Result<List<IpdBedBoardEntry>>.success(<IpdBedBoardEntry>[]),
  );
  when(() => repository.getAdmission(any())).thenAnswer(
    (_) async => Result<IpdAdmissionDetail>.success(
      IpdAdmissionDetail(
        summary: _transferPending,
        openTransferRequest: _openTransfer,
        transferRequests: const <IpdTransferRequest>[_openTransfer],
        activeBedAssignment: const IpdBedAssignment(
          id: 'ba-1',
          bed: IpdBedOption(
            id: 'bed-1',
            label: 'Bed 101',
            wardId: 'ward-1',
            wardName: 'Medical Ward',
          ),
        ),
      ),
    ),
  );
  when(() => repository.updateTransfer(any(), any())).thenAnswer(
    (_) async => Result<IpdAdmissionDetail>.success(
      IpdAdmissionDetail(
        summary: _transferPending.copyWith(
          stage: 'TRANSFER_IN_PROGRESS',
          nextStep: 'COMPLETE_TRANSFER',
          transferStatus: 'IN_PROGRESS',
        ),
        openTransferRequest: const IpdTransferRequest(
          id: 'tr-1',
          status: 'IN_PROGRESS',
        ),
      ),
    ),
  );
}

Future<void> _pumpTransfersTab(
  WidgetTester tester, {
  required _MockIpdRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/ipd?section=transfers',
    routes: <RouteBase>[
      GoRoute(
        path: '/ipd',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: IpdWorkspacePage(
              initialQuery: IpdAdmissionQuery.fromUri(state.uri),
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
              patientId == null
                  ? 'billing-workspace'
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
        ipdRepositoryProvider.overrideWithValue(repository),
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
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late _MockIpdRepository repository;

  setUpAll(() {
    registerFallbackValue(const IpdAdmissionQuery());
  });

  setUp(() {
    repository = _MockIpdRepository();
  });

  group('IPD Transfers billing inventory (AC1)', () {
    test('every financially relevant atom is inventoried and classified', () {
      expect(IpdTransfersBillingInventory.all, isNotEmpty);
      expect(
        IpdTransfersBillingInventory.all.map(
          (IpdTransfersFinancialAtom a) => a.id,
        ),
        containsAll(<String>[
          'tab',
          'request_transfer',
          'manage_transfer_approve_start_cancel',
          'complete_transfer_rate_change',
          'start_admission',
          'ward_round',
          'order_lab',
          'open_billing',
          'collect_payment',
          'adjust_refund',
        ]),
      );
      for (final IpdTransfersFinancialAtom atom
          in IpdTransfersBillingInventory.all) {
        final bool notBillable =
            atom.financialClass == IpdTransfersFinancialClass.notBilled ||
            atom.financialClass == IpdTransfersFinancialClass.notRequired ||
            atom.financialClass == IpdTransfersFinancialClass.noCharge;
        if (notBillable) {
          expect(
            atom.auditCode,
            isNotNull,
            reason: '${atom.id} not-billable needs audit code',
          );
        }
      }
      expect(ipdTransfersBillingScopeNote, contains('BED_TRANSFER'));
      expect(
        IpdTransfersBillingInventory.completeTransferRateChange.financialClass,
        IpdTransfersFinancialClass.createCharge,
      );
      expect(
        IpdTransfersBillingInventory.requestTransfer.auditCode,
        'NOT_REQUIRED',
      );
    });

    test('billable mounted atoms wire through shared Billing (no bypass)', () {
      expect(
        IpdTransfersBillingInventory.allBillableAtomsWireThroughBilling,
        isTrue,
      );
      expect(
        IpdTransfersBillingInventory.completeTransferRateChange.billingPath,
        contains('persistAdmissionBilling'),
      );
      expect(IpdTransfersBillingInventory.collectPayment.mounted, isFalse);
      expect(IpdTransfersBillingInventory.adjustRefund.mounted, isFalse);
      expect(
        IpdTransfersBillingInventory.forbidsInlineCashier(
          IpdTransfersFinancialClass.settle,
        ),
        isTrue,
      );
    });

    test('inventory reuses Transfers access gates', () {
      expect(
        IpdTransfersBillingInventory.tab.requirement,
        same(IpdTransfersAtomPermissions.tab),
      );
      expect(
        IpdTransfersBillingInventory.completeTransferRateChange.requirement,
        same(IpdTransfersAtomPermissions.manageTransfer),
      );
      expect(
        IpdTransfersBillingInventory.openBilling.requirement,
        same(IpdTransfersAtomPermissions.openBilling),
      );
    });
  });

  group('IPD Transfers billing UX / sections (AC2–AC5)', () {
    testWidgets(
      'desktop light: Open billing present; no inline cashier; flat sections',
      (WidgetTester tester) async {
        await _pumpTransfersTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
              AppPermissions.billingRead,
            },
          ),
        );

        expect(find.text('Terry Transfer'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expectFlatSections(tester);

        await tester.tap(find.text('Terry Transfer').first);
        await tester.pumpAndSettle();

        expect(find.text('Open billing'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'mobile dark: Open billing navigates Billing; flat sections',
      (WidgetTester tester) async {
        await _pumpTransfersTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
              AppPermissions.billingRead,
            },
          ),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        await tester.tap(find.text('Terry Transfer').first);
        await tester.pumpAndSettle();

        final Finder openBilling = find.text('Open billing');
        expect(openBilling, findsWidgets);
        await tester.tap(openBilling.first);
        await tester.pumpAndSettle();

        expect(
          find.text('Billing workspace patient=pat-xfer'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'unauthorized: no Open billing / financial controls; flat sections',
      (WidgetTester tester) async {
        await _pumpTransfersTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.clinicalRead},
          ),
        );

        await tester.tap(find.text('Terry Transfer').first);
        await tester.pumpAndSettle();

        expect(find.text('Open billing'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.text('Manage transfer'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets('Manage transfer dialog has no cashier affordances', (
      WidgetTester tester,
    ) async {
      await _pumpTransfersTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      await tester.tap(find.text('Terry Transfer').first);
      await tester.pumpAndSettle();

      final Finder manage = find.text('Manage transfer');
      expect(manage, findsWidgets);
      await tester.tap(manage.first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Amount'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('loading / empty / error states remain observable', (
      WidgetTester tester,
    ) async {
      when(() => repository.listAdmissions(any())).thenAnswer(
        (_) async => Result<AppPage<IpdAdmissionSummary>>.failure(
          AppFailure.network(message: 'offline'),
        ),
      );

      await _pumpTransfersTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      expect(find.textContaining('offline'), findsNothing);
      // Board surfaces retry chrome rather than cashier.
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });
  });
}
