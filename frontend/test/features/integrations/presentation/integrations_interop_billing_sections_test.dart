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
import 'package:hosspi_hms/features/integrations/data/repositories/integrations_repository_impl.dart';
import 'package:hosspi_hms/features/integrations/domain/entities/integration_entities.dart';
import 'package:hosspi_hms/features/integrations/domain/repositories/integrations_repository.dart';
import 'package:hosspi_hms/features/integrations/presentation/integrations_access.dart';
import 'package:hosspi_hms/features/integrations/presentation/integrations_interop_billing_inventory.dart';
import 'package:hosspi_hms/features/integrations/presentation/pages/integrations_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockIntegrationsRepository extends Mock
    implements IntegrationsRepository {}

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

Finder _tableRowInkWell() => find.byWidgetPredicate(
  (Widget widget) => widget.runtimeType.toString() == 'AppListTableRowInkWell',
);

const InteropCapabilityStatus _fhirReady = InteropCapabilityStatus(
  id: 'fhir',
  title: 'FHIR_EXCHANGE',
  scope: 'FHIR_EXPORT_IMPORT',
  status: 'READY',
  nextAction: 'RUN_AVAILABLE_ACTION',
);

const InteropCapabilityStatus _readinessGap = InteropCapabilityStatus(
  id: 'readiness',
  title: 'EXTERNAL_READINESS_STATUS',
  scope: 'INTEROP_STATUS',
  status: 'UNAVAILABLE',
  nextAction: 'USE_INTEGRATION_STATUS_AND_LOGS',
  unavailableReason: 'INTEROP_READINESS_SIGNAL_UNAVAILABLE',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: integrationsActiveModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: const <String>['NURSE'],
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(
  _MockIntegrationsRepository repository, {
  List<InteropCapabilityStatus> interop = const <InteropCapabilityStatus>[
    _fhirReady,
  ],
  Result<List<IntegrationRecord>>? integrationsOverride,
}) {
  when(() => repository.listIntegrations()).thenAnswer(
    (_) async =>
        integrationsOverride ??
        const Result<List<IntegrationRecord>>.success(<IntegrationRecord>[]),
  );
  when(() => repository.listApiKeys()).thenAnswer(
    (_) async => const Result<List<ApiKeyRecord>>.success(<ApiKeyRecord>[]),
  );
  when(() => repository.listApiKeyPermissions()).thenAnswer(
    (_) async => const Result<List<ApiKeyPermissionRecord>>.success(
      <ApiKeyPermissionRecord>[],
    ),
  );
  when(() => repository.listPermissionOptions()).thenAnswer(
    (_) async => const Result<List<IntegrationPermissionOption>>.success(
      <IntegrationPermissionOption>[],
    ),
  );
  when(() => repository.listWebhooks()).thenAnswer(
    (_) async => const Result<List<WebhookSubscriptionRecord>>.success(
      <WebhookSubscriptionRecord>[],
    ),
  );
  when(() => repository.listLogs()).thenAnswer(
    (_) async =>
        const Result<List<IntegrationLogRecord>>.success(<IntegrationLogRecord>[]),
  );
  when(() => repository.interopCapabilities()).thenReturn(interop);
}

Future<void> _pumpInteropTab(
  WidgetTester tester, {
  required _MockIntegrationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<InteropCapabilityStatus> interop = const <InteropCapabilityStatus>[
    _fhirReady,
  ],
  Result<List<IntegrationRecord>>? integrationsOverride,
  String initialLocation = '/integrations?section=interop',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    interop: interop,
    integrationsOverride: integrationsOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/integrations',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: IntegrationsWorkspacePage(
              initialQuery: IntegrationWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        integrationsRepositoryProvider.overrideWithValue(repository),
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
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  late _MockIntegrationsRepository repository;

  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockIntegrationsRepository();
  });

  group('Integrations Interop financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        IntegrationsInteropBillingInventory.interopTabHasNoBillableActions,
        isTrue,
      );
      expect(
        IntegrationsInteropBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(integrationsInteropTabHasNoBillableActions(), isTrue);
      expect(IntegrationsInteropBillingInventory.atoms, isNotEmpty);
      expect(
        IntegrationsInteropBillingInventory.billableClasses.every(
          (IntegrationsInteropFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(integrationsInteropBillingScopeNote, contains('NOT_BILLED'));

      for (final IntegrationsInteropFinancialAtom atom
          in IntegrationsInteropBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<IntegrationsInteropFinancialClass>[
            IntegrationsInteropFinancialClass.notRequired,
            IntegrationsInteropFinancialClass.notBilled,
            IntegrationsInteropFinancialClass.noCharge,
          ]),
          reason: atom.id,
        );
        expect(
          atom.auditCode,
          isIn(<String>['NOT_REQUIRED', 'NOT_BILLED', 'NO_CHARGE']),
          reason: atom.id,
        );
      }
    });

    test('Run action / Use status logs stay NOT_REQUIRED navigate-only', () {
      final IntegrationsInteropFinancialAtom runAction =
          IntegrationsInteropBillingInventory.atoms.singleWhere(
            (IntegrationsInteropFinancialAtom atom) =>
                atom.id == 'next_action_run_available',
          );
      expect(
        runAction.financialClass,
        IntegrationsInteropFinancialClass.notRequired,
      );
      expect(runAction.auditCode, 'NOT_REQUIRED');

      final IntegrationsInteropFinancialAtom useLogs =
          IntegrationsInteropBillingInventory.atoms.singleWhere(
            (IntegrationsInteropFinancialAtom atom) =>
                atom.id == 'next_action_use_status_logs',
          );
      expect(
        useLogs.financialClass,
        IntegrationsInteropFinancialClass.notRequired,
      );
      expect(useLogs.auditCode, 'NOT_REQUIRED');
    });

    test('readiness detail stays NOT_BILLED ops telemetry', () {
      final IntegrationsInteropFinancialAtom readiness =
          IntegrationsInteropBillingInventory.atoms.singleWhere(
            (IntegrationsInteropFinancialAtom atom) =>
                atom.id == 'detail_readiness_panel',
          );
      expect(
        readiness.financialClass,
        IntegrationsInteropFinancialClass.notBilled,
      );
      expect(readiness.auditCode, 'NOT_BILLED');
    });

    test('unmounted billable atoms document Billing SoR / no bypass', () {
      expect(
        IntegrationsInteropBillingInventory.atoms
            .singleWhere(
              (IntegrationsInteropFinancialAtom atom) =>
                  atom.id == 'fhir_hl7_order_or_payment_payload',
            )
            .mounted,
        isFalse,
      );
      expect(
        IntegrationsInteropBillingInventory.atoms
            .singleWhere(
              (IntegrationsInteropFinancialAtom atom) =>
                  atom.id == 'webhook_settlement_ack_without_ledger',
            )
            .mounted,
        isFalse,
      );
      expect(
        IntegrationsInteropBillingInventory.atoms
            .singleWhere(
              (IntegrationsInteropFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        IntegrationsInteropBillingInventory.atoms
            .singleWhere(
              (IntegrationsInteropFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
      expect(integrationsInteropBillingScopeNote, contains('Billing'));
      expect(integrationsInteropBillingScopeNote, contains('idempotency'));
    });
  });

  group('Integrations Interop billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.integrationRead,
            AppPermissions.integrationWrite,
            AppPermissions.billingWrite,
          },
        ),
        interop: const <InteropCapabilityStatus>[_fhirReady, _readinessGap],
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.text('FHIR exchange'), findsWidgets);
      expect(find.byTooltip('Create integration'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('detail dialog: flat layout; no financial controls', (
      WidgetTester tester,
    ) async {
      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.integrationRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      await tester.tap(_tableRowInkWell().first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Interoperability actions are available.'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.text('Test connection'), findsNothing);
      expect(find.text('Sync now'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets(
      'unauthorized users cannot collect or adjust from Interop',
      (WidgetTester tester) async {
        await _pumpInteropTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.integrationRead},
          ),
        );

        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(
          IntegrationsInteropBillingInventory.canMutateInterop(
            _policy(
              permissions: <AppPermission>{AppPermissions.integrationRead},
            ),
          ),
          isFalse,
        );

        await tester.tap(_tableRowInkWell().first);
        await tester.pumpAndSettle();

        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Adjust'), findsNothing);
        expect(find.textContaining('Write off'), findsNothing);
        expect(find.text('Delete'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'detail open/close syncs list without billing gate or payment UX',
      (WidgetTester tester) async {
        await _pumpInteropTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.integrationRead,
              AppPermissions.integrationWrite,
            },
          ),
          interop: const <InteropCapabilityStatus>[_fhirReady, _readinessGap],
        );

        expect(find.text('FHIR exchange'), findsWidgets);
        await tester.tap(find.text('Run action').first);
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        expect(find.text('Interoperability actions are available.'), findsWidgets);
        expect(find.textContaining('Invoice'), findsNothing);

        await tester.tap(find.widgetWithText(AppButton, 'Close').last);
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsNothing);
        expect(find.text('FHIR exchange'), findsWidgets);
        expect(find.text('Run action'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expectFlatSections(tester);
      },
    );
  });

  group('Integrations Interop section layout (AC5)', () {
    testWidgets('desktop Interop: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.integrationRead},
        ),
        physicalSize: const Size(1920, 1200),
        interop: const <InteropCapabilityStatus>[_fhirReady, _readinessGap],
      );

      expectFlatSections(tester);
      expect(_tab('Interop'), findsOneWidget);

      await tester.tap(find.text('FHIR exchange').first);
      await tester.pumpAndSettle();
      expect(find.text('Interoperability actions are available.'), findsWidgets);
      expectFlatSections(tester);
    });

    testWidgets('mobile Interop: flat sections', (WidgetTester tester) async {
      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.integrationRead},
        ),
        physicalSize: const Size(390, 844),
      );
      expectFlatSections(tester);

      await tester.tap(find.text('FHIR exchange').first);
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.integrationRead},
        ),
        themeMode: ThemeMode.light,
      );
      await tester.tap(_tableRowInkWell().first);
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.integrationRead},
        ),
        themeMode: ThemeMode.dark,
      );
      await tester.tap(_tableRowInkWell().first);
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });

  group('Integrations Interop sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('authorized empty state remains without billing UX', (
      WidgetTester tester,
    ) async {
      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.integrationRead},
        ),
        interop: const <InteropCapabilityStatus>[],
      );

      expect(_tab('Interop'), findsOneWidget);
      expect(find.text('No integration items'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('authorized error/retry remains without billing UX', (
      WidgetTester tester,
    ) async {
      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.integrationRead},
        ),
        integrationsOverride: const Result<List<IntegrationRecord>>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets(
      'status parity: readiness copy is ops telemetry, not ledger balance',
      (WidgetTester tester) async {
        await _pumpInteropTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.integrationRead},
          ),
          interop: const <InteropCapabilityStatus>[_fhirReady, _readinessGap],
        );

        expect(find.text('FHIR exchange'), findsWidgets);
        expect(find.textContaining('Balance'), findsNothing);
        expect(find.textContaining('Amount due'), findsNothing);
        expect(find.textContaining('Paid'), findsNothing);

        await tester.tap(find.text('Use status logs').first);
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Invoice'), findsNothing);
        expectFlatSections(tester);
      },
    );

    test('helper: Interop tab has no billable actions', () {
      expect(integrationsInteropTabHasNoBillableActions(), isTrue);
      expect(integrationsInteropBillingScopeNote, contains('NOT_BILLED'));
      expect(integrationsInteropBillingScopeNote, contains('NOT_REQUIRED'));
    });
  });
}
