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
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/domain/repositories/billing_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/controllers/reception_payment_gate_controller.dart';
import 'package:hosspi_hms/features/reception/presentation/pages/reception_workspace_page.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockBillingRepository extends Mock implements BillingRepository {}

BillingWorkItem _invoice({
  String id = 'invoice-lab',
  String displayId = 'INV-LAB',
  String source = 'LABORATORY',
  String description = 'Complete blood count',
  String patientName = 'Penny Payment',
  num balance = 40000,
}) {
  return BillingWorkItem(
    id: id,
    displayId: displayId,
    kind: BillingWorkItemKind.invoice,
    patientId: 'patient-payment',
    patientDisplayId: 'PAT-PAY',
    patientDisplayName: patientName,
    encounterId: 'encounter-payment',
    encounterDisplayId: 'ENC-PAYMENT',
    sourceModule: source,
    status: 'SENT',
    billingStatus: 'ISSUED',
    currency: 'UGX',
    items: <BillingInvoiceItem>[
      BillingInvoiceItem(
        id: 'line-$id',
        description: description,
        sourceModule: source,
        totalPrice: balance,
      ),
    ],
    financials: BillingFinancials(
      invoiceTotal: balance,
      effectiveTotal: balance,
      netPaidTotal: 0,
      balanceDue: balance,
    ),
  );
}

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['CUSTOM_READER'],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  final bool needsPatient = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.patientRead ||
        permission == AppPermissions.patientWrite ||
        permission == AppPermissions.patientDelete,
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
          code: 'scheduling-queue',
          licenseStatus: 'ACTIVE',
        ),
        if (needsPatient)
          const AppModuleEntitlement(
            code: 'patient-registry',
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
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: resolvedModules,
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _billingReaderPolicy() {
  return _policy(
    permissions: <AppPermission>{AppPermissions.billingRead},
  );
}

AppAccessPolicy _deskWriterPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.patientRead,
      AppPermissions.patientWrite,
      AppPermissions.billingRead,
      AppPermissions.billingWrite,
    },
    roles: const <String>['RECEPTIONIST'],
    modules: const <AppModuleEntitlement>[
      AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
    ],
  );
}

void _stubOpd(_MockOpdRepository repository, {bool failLists = false}) {
  when(() => repository.listAppointments(any())).thenAnswer((invocation) async {
    if (failLists) {
      return const Result<AppPage<OpdAppointment>>.failure(AppFailure.network());
    }
    return Result<AppPage<OpdAppointment>>.success(
      AppPage<OpdAppointment>(
        items: const <OpdAppointment>[],
        request: (invocation.positionalArguments.single as OpdAppointmentQuery)
            .pageRequest,
      ),
    );
  });
  when(() => repository.listVisitQueues(any())).thenAnswer((invocation) async {
    if (failLists) {
      return const Result<AppPage<OpdQueueEntry>>.failure(AppFailure.network());
    }
    return Result<AppPage<OpdQueueEntry>>.success(
      AppPage<OpdQueueEntry>(
        items: const <OpdQueueEntry>[],
        request: (invocation.positionalArguments.single as OpdQueueQuery)
            .pageRequest,
      ),
    );
  });
  when(() => repository.listOpdFlows(any())).thenAnswer((invocation) async {
    if (failLists) {
      return const Result<AppPage<OpdFlowSummary>>.failure(AppFailure.network());
    }
    return Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
      ),
    );
  });
  when(() => repository.listTriageQueue(any())).thenAnswer((invocation) async {
    if (failLists) {
      return const Result<AppPage<OpdFlowSummary>>.failure(AppFailure.network());
    }
    return Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request: (invocation.positionalArguments.single as OpdTriageQueueQuery)
            .pageRequest,
      ),
    );
  });
  when(() => repository.getOpdSummaryCounts()).thenAnswer((_) async {
    if (failLists) {
      return const Result<OpdFlowAggregateCounts>.failure(AppFailure.network());
    }
    return const Result<OpdFlowAggregateCounts>.success(OpdFlowAggregateCounts());
  });
  when(
    () => repository.listClinicalAlertThresholds(
      vitalType: any(named: 'vitalType'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<OpdClinicalAlertThreshold>>.success(
      <OpdClinicalAlertThreshold>[],
    ),
  );
  when(() => repository.listProviderSchedules()).thenAnswer(
    (_) async => const Result<List<OpdProviderSchedule>>.success(
      <OpdProviderSchedule>[],
    ),
  );
  when(() => repository.listProviders()).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
  when(
    () => repository.getBillingDefaults(
      facilityId: any(named: 'facilityId'),
      tenantId: any(named: 'tenantId'),
    ),
  ).thenAnswer(
    (_) async => const Result<OpdBillingDefaults>.success(OpdBillingDefaults()),
  );
}

void _stubBilling(
  _MockBillingRepository repository, {
  List<BillingWorkItem> invoices = const <BillingWorkItem>[],
  bool failLists = false,
}) {
  when(() => repository.listWorkItems(any())).thenAnswer((invocation) async {
    if (failLists) {
      return const Result<AppPage<BillingWorkItem>>.failure(
        AppFailure.network(),
      );
    }
    final BillingWorkspaceQuery query =
        invocation.positionalArguments.single as BillingWorkspaceQuery;
    return Result<AppPage<BillingWorkItem>>.success(
      AppPage<BillingWorkItem>(
        items: invoices,
        request: query.pageRequest,
        totalItemCount: invoices.length,
      ),
    );
  });
}

Future<GoRouter> _pumpPaymentGateTab(
  WidgetTester tester, {
  required _MockOpdRepository opdRepository,
  required _MockBillingRepository billingRepository,
  required AppAccessPolicy accessPolicy,
  List<BillingWorkItem>? invoices,
  bool failBilling = false,
  bool failOpd = false,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/reception?section=payment-gate',
}) async {
  _stubOpd(opdRepository, failLists: failOpd);
  _stubBilling(
    billingRepository,
    invoices: invoices ?? <BillingWorkItem>[_invoice()],
    failLists: failBilling,
  );
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/reception',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: ReceptionWorkspacePage(
              initialQuery: ReceptionWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        opdRepositoryProvider.overrideWithValue(opdRepository),
        billingRepositoryProvider.overrideWithValue(billingRepository),
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
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  late _MockOpdRepository opdRepository;
  late _MockBillingRepository billingRepository;

  setUpAll(() {
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdQueueQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(const BillingWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    opdRepository = _MockOpdRepository();
    billingRepository = _MockBillingRepository();
  });

  group('ReceptionPaymentGateAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          ReceptionPaymentGateAtomPermissions.tab,
          receptionPaymentGateRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionPaymentGateAtomPermissions.collect,
          receptionPaymentGateCollectRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionPaymentGateAtomPermissions.register,
          receptionPatientWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionPaymentGateAtomPermissions.schedule,
          receptionPatientWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionPaymentGateAtomPermissions.delete,
          receptionPatientDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionPaymentGateAtomPermissions.routeEntry,
          receptionWorkspaceRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionPaymentGateAtomPermissions.catalogEntry,
          RouteAccessCatalog.receptionEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          receptionDeskSectionRequirement(ReceptionDeskSection.paymentGate),
          ReceptionPaymentGateAtomPermissions.tab,
        ),
        isTrue,
      );
    });

    test(
      'mapping note: matrix ∩ patient:read+billing:read → source billing:read',
      () {
        expect(
          ReceptionPaymentGateAtomPermissions.tab.anyPermissions,
          <AppPermission>[AppPermissions.billingRead],
        );
        expect(
          ReceptionPaymentGateAtomPermissions.create.allPermissions,
          <AppPermission>[AppPermissions.billingWrite],
        );
        expect(
          ReceptionPaymentGateAtomPermissions.update.allPermissions,
          <AppPermission>[AppPermissions.billingWrite],
        );
        expect(
          ReceptionPaymentGateAtomPermissions.collect.allPermissions,
          <AppPermission>[AppPermissions.billingWrite],
        );
        expect(
          ReceptionPaymentGateAtomPermissions.delete.allPermissions,
          <AppPermission>[AppPermissions.patientDelete],
        );
        expect(
          ReceptionPaymentGateAtomPermissions.register.allPermissions,
          <AppPermission>[AppPermissions.patientWrite],
        );
      },
    );

    test('∩ denial: billing:read alone does not grant collect / Register', () {
      final AppAccessPolicy reader = _billingReaderPolicy();
      expect(ReceptionPaymentGateAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        ReceptionPaymentGateAtomPermissions.collect.isAllowed(reader),
        isFalse,
      );
      expect(
        ReceptionPaymentGateAtomPermissions.register.isAllowed(reader),
        isFalse,
      );
      expect(
        ReceptionPaymentGateAtomPermissions.schedule.isAllowed(reader),
        isFalse,
      );
      expect(canViewReceptionPaymentGate(reader), isTrue);
      expect(receptionPaymentGateShowsNextActionColumn(reader), isTrue);
    });

    test('full intersection set: billing:write allows collect requirement', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );
      expect(
        ReceptionPaymentGateAtomPermissions.collect.isAllowed(writer),
        isTrue,
      );
      expect(
        ReceptionPaymentGateAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
      expect(
        ReceptionPaymentGateAtomPermissions.update.isAllowed(writer),
        isTrue,
      );
    });

    test('∪ allowance: route entry accepts patient:read or last_office:read', () {
      final AppAccessPolicy patientOnly = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
      );
      final AppAccessPolicy lastOfficeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.lastOfficeRead},
        roles: const <String>['RECEPTIONIST'],
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'scheduling-queue',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        ReceptionPaymentGateAtomPermissions.routeEntryUnion.isAllowed(
          patientOnly,
        ),
        isTrue,
      );
      expect(
        ReceptionPaymentGateAtomPermissions.routeEntryUnion.isAllowed(
          lastOfficeOnly,
        ),
        isTrue,
      );
      // Payment gate tab itself stays source billing:read.
      expect(
        ReceptionPaymentGateAtomPermissions.tab.isAllowed(lastOfficeOnly),
        isFalse,
      );
      expect(
        ReceptionPaymentGateAtomPermissions.tab.isAllowed(patientOnly),
        isFalse,
      );
    });

    test('subscription strip: billing-payments required for Payment gate', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'scheduling-queue',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        ReceptionPaymentGateAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(canViewReceptionPaymentGate(noModule), isFalse);
      expect(
        ReceptionPaymentGateAtomPermissions.collect.isAllowed(noModule),
        isFalse,
      );
    });

    test(
      'ABAC: missing facility still allows Payment gate chrome '
      '(row/own scope remains backend-authoritative)',
      () {
        final AppAccessPolicy noFacility = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.billingRead,
          },
          facilityId: null,
        );
        expect(noFacility.hasFacilityContext, isFalse);
        expect(
          ReceptionPaymentGateAtomPermissions.tab.isAllowed(noFacility),
          isTrue,
        );
        expect(
          ReceptionPaymentGateAtomPermissions.routeEntryUnion.isAllowed(
            noFacility,
          ),
          isTrue,
        );
      },
    );

    test('nested cross-module matrix _(n/a)_ reuses tab / collect gates', () {
      expect(
        identical(
          ReceptionPaymentGateAtomPermissions.nestedRead,
          receptionPaymentGateRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionPaymentGateAtomPermissions.nestedWrite,
          receptionPaymentGateCollectRequirement,
        ),
        isTrue,
      );
    });
  });

  group('Reception Payment gate tab UI gates', () {
    testWidgets(
      'read-only: list visible; collect / Register / delete atoms absent',
      (WidgetTester tester) async {
        await _pumpPaymentGateTab(
          tester,
          opdRepository: opdRepository,
          billingRepository: billingRepository,
          accessPolicy: _billingReaderPolicy(),
        );

        expect(find.textContaining('Payment gate'), findsWidgets);
        expect(find.text('Penny Payment'), findsOneWidget);
        expect(find.text('Register patient'), findsNothing);
        expect(find.text('Schedule appointment'), findsNothing);
        expect(find.byType(AppTabToolbarPrimary), findsNothing);
        expect(find.text('Receive payment'), findsNothing);
        expect(find.text('Delete'), findsNothing);
        expect(find.byType(WorkflowActionButton), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'full write ∩: Register + Schedule present; Receive payment still absent',
      (WidgetTester tester) async {
        await _pumpPaymentGateTab(
          tester,
          opdRepository: opdRepository,
          billingRepository: billingRepository,
          accessPolicy: _deskWriterPolicy(),
        );

        expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
        expect(find.text('Register patient'), findsOneWidget);
        expect(find.text('Schedule appointment'), findsOneWidget);
        expect(find.text('Penny Payment'), findsOneWidget);
        expect(find.text('Billing guidance'), findsWidgets);
        expect(find.text('Receive payment'), findsNothing);
        expect(find.byType(WorkflowActionButton), findsNothing);
      },
    );

    testWidgets(
      '∩ denial: patient:read without billing:read hides Payment gate tab',
      (WidgetTester tester) async {
        await _pumpPaymentGateTab(
          tester,
          opdRepository: opdRepository,
          billingRepository: billingRepository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.patientRead},
          ),
          initialLocation: '/reception',
        );

        expect(find.textContaining('Payment gate'), findsNothing);
        expect(find.text('Penny Payment'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      '∪ allowance: route entry last_office:read keeps shell; tab stays hidden',
      (WidgetTester tester) async {
        await _pumpPaymentGateTab(
          tester,
          opdRepository: opdRepository,
          billingRepository: billingRepository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.lastOfficeRead},
            roles: const <String>['RECEPTIONIST'],
            modules: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: 'patient-registry',
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'scheduling-queue',
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
          initialLocation: '/reception',
        );

        expect(
          ReceptionPaymentGateAtomPermissions.routeEntryUnion.isAllowed(
            _policy(
              permissions: <AppPermission>{AppPermissions.lastOfficeRead},
              roles: const <String>['RECEPTIONIST'],
              modules: const <AppModuleEntitlement>[
                AppModuleEntitlement(
                  code: 'patient-registry',
                  licenseStatus: 'ACTIVE',
                ),
                AppModuleEntitlement(
                  code: 'scheduling-queue',
                  licenseStatus: 'ACTIVE',
                ),
              ],
            ),
          ),
          isTrue,
        );
        expect(find.textContaining('Payment gate'), findsNothing);
      },
    );

    testWidgets(
      'nested cross-module: collect UI absent even with billing:write',
      (WidgetTester tester) async {
        await _pumpPaymentGateTab(
          tester,
          opdRepository: opdRepository,
          billingRepository: billingRepository,
          accessPolicy: _deskWriterPolicy(),
        );

        await tester.tap(find.text('Penny Payment'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            const ValueKey<String>('receptionPaymentGateReadOnlyDetail'),
          ),
          findsOneWidget,
        );
        expect(find.text('Receive payment'), findsNothing);
        expect(find.text('Edit'), findsNothing);
        expect(find.text('Delete'), findsNothing);
        expect(find.byType(WorkflowActionButton), findsNothing);
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpPaymentGateTab(
        tester,
        opdRepository: opdRepository,
        billingRepository: billingRepository,
        accessPolicy: _billingReaderPolicy(),
        invoices: const <BillingWorkItem>[],
      );

      expect(find.text('No outstanding OPD charges'), findsOneWidget);
      expect(
        find.text('Patients with pending OPD charges will appear here.'),
        findsOneWidget,
      );
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpPaymentGateTab(
        tester,
        opdRepository: opdRepository,
        billingRepository: billingRepository,
        accessPolicy: _billingReaderPolicy(),
        failBilling: true,
      );

      expect(find.textContaining('Try again'), findsWidgets);
    });

    testWidgets(
      'post-mutation sync: refresh drops settled patients from the list',
      (WidgetTester tester) async {
        var calls = 0;
        when(() => billingRepository.listWorkItems(any())).thenAnswer((
          Invocation invocation,
        ) async {
          calls += 1;
          final BillingWorkspaceQuery query =
              invocation.positionalArguments.single as BillingWorkspaceQuery;
          return Result<AppPage<BillingWorkItem>>.success(
            AppPage<BillingWorkItem>(
              items: calls == 1
                  ? <BillingWorkItem>[_invoice()]
                  : const <BillingWorkItem>[],
              request: query.pageRequest,
              totalItemCount: calls == 1 ? 1 : 0,
            ),
          );
        });
        _stubOpd(opdRepository);
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences preferences =
            await SharedPreferences.getInstance();
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final GoRouter router = GoRouter(
          initialLocation: '/reception?section=payment-gate',
          routes: <RouteBase>[
            GoRoute(
              path: '/reception',
              builder: (BuildContext context, GoRouterState state) {
                return Scaffold(
                  body: ReceptionWorkspacePage(
                    initialQuery: ReceptionWorkspaceQuery.fromUri(state.uri),
                  ),
                );
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              opdRepositoryProvider.overrideWithValue(opdRepository),
              billingRepositoryProvider.overrideWithValue(billingRepository),
              sharedPreferencesProvider.overrideWithValue(preferences),
              initialSessionStateProvider.overrideWithValue(
                const SessionState.ready(),
              ),
              appAccessPolicyProvider.overrideWithValue(_billingReaderPolicy()),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Penny Payment'), findsOneWidget);

        final ProviderContainer container = ProviderScope.containerOf(
          tester.element(find.byType(ReceptionWorkspacePage)),
        );
        await container
            .read(receptionPaymentGateControllerProvider.notifier)
            .refresh();
        await tester.pumpAndSettle();

        expect(find.text('Penny Payment'), findsNothing);
        expect(find.text('No outstanding OPD charges'), findsOneWidget);
        expect(calls, 2);
      },
    );

    testWidgets('mobile viewport: read-only hides Schedule; guidance stays text', (
      WidgetTester tester,
    ) async {
      await _pumpPaymentGateTab(
        tester,
        opdRepository: opdRepository,
        billingRepository: billingRepository,
        accessPolicy: _billingReaderPolicy(),
        physicalSize: const Size(390, 844),
      );

      expect(find.textContaining('Penny Payment'), findsOneWidget);
      expect(find.text('Schedule appointment'), findsNothing);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
      expect(find.text('Receive payment'), findsNothing);
      expect(find.byType(WorkflowActionButton), findsNothing);
    });

    testWidgets('desktop dark theme: writer Schedule still mounts', (
      WidgetTester tester,
    ) async {
      await _pumpPaymentGateTab(
        tester,
        opdRepository: opdRepository,
        billingRepository: billingRepository,
        accessPolicy: _deskWriterPolicy(),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('Schedule appointment'), findsOneWidget);
      expect(find.text('Penny Payment'), findsOneWidget);
      expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
      expect(find.text('Receive payment'), findsNothing);
    });

    testWidgets('integration: section=payment-gate deep link selects tab', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpPaymentGateTab(
        tester,
        opdRepository: opdRepository,
        billingRepository: billingRepository,
        accessPolicy: _billingReaderPolicy(),
      );

      expect(router.state.uri.path, '/reception');
      expect(router.state.uri.queryParameters['section'], 'payment-gate');
      expect(find.text('Penny Payment'), findsOneWidget);
      final AppTabStrip tabs = tester.widget<AppTabStrip>(
        find.byType(AppTabStrip),
      );
      expect(
        tabs.tabs.any((AppTabItem tab) => tab.id == 'paymentGate'),
        isTrue,
      );
    });
  });
}
