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
import 'package:hosspi_hms/features/integrations/presentation/integrations_integrations_billing_inventory.dart';
import 'package:hosspi_hms/features/integrations/presentation/pages/integrations_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockIntegrationsRepository extends Mock
    implements IntegrationsRepository {}

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

const IntegrationRecord _integration = IntegrationRecord(
  id: 'integration-1',
  name: 'Lab HL7 Feed',
  integrationType: 'HL7',
  status: 'ACTIVE',
  tenantLabel: 'Main Hospital',
  hasConfig: true,
  webhookSubscriptionCount: 1,
  logCount: 2,
  configSummary: <String, Object?>{'endpoint': 'https://hl7.example.test'},
);

const IntegrationRecord _failedIntegration = IntegrationRecord(
  id: 'integration-3',
  name: 'Failed Sync',
  integrationType: 'LAB',
  status: 'FAILED',
  tenantLabel: 'Main Hospital',
  requiresAttention: true,
);

const ApiKeyRecord _apiKey = ApiKeyRecord(
  id: 'api-key-1',
  name: 'Billing Export Key',
  userId: 'user-1',
  isActive: true,
  humanFriendlyId: 'key_billing',
);

const WebhookSubscriptionRecord _webhook = WebhookSubscriptionRecord(
  id: 'webhook-1',
  event: 'payment.completed',
  integrationLabel: 'Lab HL7 Feed',
  targetHost: 'hooks.example.com',
  integrationStatus: 'ACTIVE',
  isActive: true,
);

const IntegrationLogRecord _log = IntegrationLogRecord(
  id: 'log-1',
  integrationLabel: 'Lab HL7 Feed',
  integrationType: 'HL7',
  status: 'SUCCESS',
  message: 'Message accepted',
);

const InteropCapabilityStatus _interop = InteropCapabilityStatus(
  id: 'fhir',
  title: 'FHIR_EXCHANGE',
  scope: 'FHIR_EXPORT_IMPORT',
  status: 'READY',
  nextAction: 'RUN_AVAILABLE_ACTION',
);

AppAccessPolicy _policy({
  Set<AppPermission>? permissions,
  bool includeModule = true,
  String? facilityId = 'facility-1',
  String? tenantId = 'tenant-1',
  List<String> roles = const <String>['INTEGRATION_ADMIN'],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        tenantId: tenantId,
        facilityId: facilityId,
        roles: roles,
      ),
      permissions: permissions ??
          <AppPermission>{
            AppPermissions.integrationRead,
            AppPermissions.integrationWrite,
            AppPermissions.integrationDelete,
          },
      moduleEntitlements: includeModule
          ? const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: integrationsCoreModule,
                licenseStatus: 'ACTIVE',
              ),
            ]
          : const <AppModuleEntitlement>[],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(
  _MockIntegrationsRepository repository, {
  Result<List<IntegrationRecord>>? integrationsOverride,
}) {
  when(() => repository.listIntegrations()).thenAnswer(
    (_) async =>
        integrationsOverride ??
        const Result<List<IntegrationRecord>>.success(<IntegrationRecord>[
          _integration,
          _failedIntegration,
        ]),
  );
  when(() => repository.listApiKeys()).thenAnswer(
    (_) async =>
        const Result<List<ApiKeyRecord>>.success(<ApiKeyRecord>[_apiKey]),
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
      <WebhookSubscriptionRecord>[_webhook],
    ),
  );
  when(() => repository.listLogs()).thenAnswer(
    (_) async => const Result<List<IntegrationLogRecord>>.success(
      <IntegrationLogRecord>[_log],
    ),
  );
  when(
    () => repository.interopCapabilities(),
  ).thenReturn(const <InteropCapabilityStatus>[_interop]);
  when(() => repository.syncNow(any(), any())).thenAnswer(
    (_) async => const Result<IntegrationActionResult>.success(
      IntegrationActionResult(title: 'Sync', status: 'QUEUED'),
    ),
  );
  when(() => repository.testConnection(any(), any())).thenAnswer(
    (_) async => const Result<IntegrationActionResult>.success(
      IntegrationActionResult(title: 'Test', status: 'OK'),
    ),
  );
  when(() => repository.updateIntegration(any(), any())).thenAnswer(
    (_) async => const Result<IntegrationRecord>.success(_integration),
  );
  when(() => repository.createIntegration(any())).thenAnswer(
    (_) async => const Result<IntegrationRecord>.success(_integration),
  );
}

Future<void> _pumpIntegrationsTab(
  WidgetTester tester, {
  required _MockIntegrationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/integrations?section=integrations',
  bool emptyIntegrations = false,
  Result<List<IntegrationRecord>>? integrationsOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    integrationsOverride: emptyIntegrations
        ? const Result<List<IntegrationRecord>>.success(<IntegrationRecord>[])
        : integrationsOverride,
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

  setUp(() {
    repository = _MockIntegrationsRepository();
    registerFallbackValue(<String, Object?>{});
  });

  group('Integrations Integrations financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        IntegrationsIntegrationsBillingInventory.integrationsTabHasNoBillableActions,
        isTrue,
      );
      expect(
        IntegrationsIntegrationsBillingInventory
            .allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(IntegrationsIntegrationsBillingInventory.atoms, isNotEmpty);
      expect(
        IntegrationsIntegrationsBillingInventory.billableClasses.every(
          (IntegrationsIntegrationsFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(integrationsIntegrationsBillingScopeNote, contains('NOT_BILLED'));
      expect(
        IntegrationsIntegrationsBillingInventory.summary(),
        contains('NOT_BILLED'),
      );

      for (final IntegrationsIntegrationsFinancialAtom atom
          in IntegrationsIntegrationsBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<IntegrationsIntegrationsFinancialClass>[
            IntegrationsIntegrationsFinancialClass.notRequired,
            IntegrationsIntegrationsFinancialClass.notBilled,
            IntegrationsIntegrationsFinancialClass.noCharge,
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

    test('Create integration primary stays NOT_BILLED connector CRUD', () {
      final IntegrationsIntegrationsFinancialAtom primary =
          IntegrationsIntegrationsBillingInventory.atoms.singleWhere(
            (IntegrationsIntegrationsFinancialAtom atom) =>
                atom.id == 'create_integration_primary',
          );
      expect(
        primary.financialClass,
        IntegrationsIntegrationsFinancialClass.notBilled,
      );
      expect(primary.auditCode, 'NOT_BILLED');
      expect(primary.mounted, isTrue);
    });

    test('test / sync / enable next-actions stay NOT_BILLED', () {
      for (final String id in <String>[
        'next_action_review_failure',
        'next_action_enable',
        'next_action_monitor',
        'detail_test_connection',
        'detail_sync_now',
        'detail_enable_disable',
      ]) {
        final IntegrationsIntegrationsFinancialAtom atom =
            IntegrationsIntegrationsBillingInventory.atoms.singleWhere(
              (IntegrationsIntegrationsFinancialAtom a) => a.id == id,
            );
        expect(atom.auditCode, 'NOT_BILLED', reason: id);
        expect(atom.mounted, isTrue, reason: id);
      }
    });

    test('unmounted billable atoms document Billing SoR', () {
      expect(
        IntegrationsIntegrationsBillingInventory.atoms
            .singleWhere(
              (IntegrationsIntegrationsFinancialAtom atom) =>
                  atom.id == 'interop_order_payment_payload',
            )
            .mounted,
        isFalse,
      );
      expect(
        IntegrationsIntegrationsBillingInventory.atoms
            .singleWhere(
              (IntegrationsIntegrationsFinancialAtom atom) =>
                  atom.id == 'webhook_settlement_ack_without_ledger',
            )
            .mounted,
        isFalse,
      );
      expect(
        IntegrationsIntegrationsBillingInventory.atoms
            .singleWhere(
              (IntegrationsIntegrationsFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        IntegrationsIntegrationsBillingInventory.atoms
            .singleWhere(
              (IntegrationsIntegrationsFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
      expect(
        IntegrationsIntegrationsBillingInventory.atoms
            .singleWhere(
              (IntegrationsIntegrationsFinancialAtom atom) =>
                  atom.id == 'delete_integration',
            )
            .mounted,
        isFalse,
      );
      expect(integrationsIntegrationsBillingScopeNote, contains('Billing'));
    });
  });

  group('Integrations Integrations billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpIntegrationsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.integrationRead,
            AppPermissions.integrationWrite,
            AppPermissions.billingWrite,
          },
        ),
      );

      expect(_tab('Integrations'), findsOneWidget);
      expect(find.text('Lab HL7 Feed'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.textContaining('Write off'), findsNothing);
      expect(find.byTooltip('Create integration'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets(
      'detail dialog: no financial controls; flat sibling sections',
      (WidgetTester tester) async {
        await _pumpIntegrationsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.integrationRead,
              AppPermissions.integrationWrite,
              AppPermissions.billingWrite,
            },
          ),
        );

        await tester.tap(find.text('Lab HL7 Feed'));
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        expect(find.text('Configuration'), findsOneWidget);
        expect(find.text('Related webhooks'), findsOneWidget);
        expect(find.text('Related logs'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.textContaining('Adjust'), findsNothing);
        // payment.completed is outbound webhook event label, not settlement UX.
        expect(find.text('payment.completed'), findsWidgets);
        expect(find.byType(AppWorkspaceDetailPanel), findsAtLeastNWidgets(3));
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'unauthorized users cannot collect or adjust from Integrations',
      (WidgetTester tester) async {
        await _pumpIntegrationsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.integrationRead},
          ),
        );

        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.byTooltip('Create integration'), findsNothing);

        await tester.tap(find.text('Lab HL7 Feed'));
        await tester.pumpAndSettle();

        expect(find.text('Configure'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Adjust'), findsNothing);
        expect(find.textContaining('Write off'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'Monitor sync mutates connector status without billing gate',
      (WidgetTester tester) async {
        await _pumpIntegrationsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.integrationRead,
              AppPermissions.integrationWrite,
            },
          ),
        );

        clearInteractions(repository);
        final Finder monitor = find.widgetWithText(AppButton, 'Monitor');
        expect(monitor, findsWidgets);
        await tester.ensureVisible(monitor.first);
        await tester.pumpAndSettle();
        await tester.tap(monitor.first);
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(AppButton, 'Sync now').last);
        await tester.pumpAndSettle();

        verify(() => repository.syncNow(any(), any())).called(1);
        verifyNever(() => repository.createIntegration(any()));
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Invoice'), findsNothing);
        expectFlatSections(tester);
      },
    );
  });

  group('Integrations Integrations section layout (AC5)', () {
    testWidgets('desktop Integrations: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpIntegrationsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.integrationRead,
            AppPermissions.integrationWrite,
          },
        ),
        physicalSize: const Size(1920, 1200),
      );

      expectFlatSections(tester);

      await tester.tap(find.text('Lab HL7 Feed'));
      await tester.pumpAndSettle();
      expect(find.text('Configuration'), findsOneWidget);
      expect(find.text('Related webhooks'), findsOneWidget);
      expect(find.text('Related logs'), findsOneWidget);
      expect(find.byType(AppWorkspaceDetailPanel), findsAtLeastNWidgets(3));
      expectFlatSections(tester);
    });

    testWidgets('mobile Integrations: flat sections', (WidgetTester tester) async {
      await _pumpIntegrationsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.integrationRead},
        ),
        physicalSize: const Size(390, 844),
      );
      expectFlatSections(tester);

      await tester.tap(find.textContaining('Lab HL7').first);
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpIntegrationsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.integrationRead,
            AppPermissions.integrationWrite,
          },
        ),
        themeMode: ThemeMode.light,
      );
      await tester.tap(find.text('Lab HL7 Feed'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpIntegrationsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.integrationRead,
            AppPermissions.integrationWrite,
          },
        ),
        themeMode: ThemeMode.dark,
      );
      await tester.tap(find.text('Lab HL7 Feed'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });

  group('Integrations Integrations sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('authorized empty state remains without billing UX', (
      WidgetTester tester,
    ) async {
      await _pumpIntegrationsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.integrationRead},
        ),
        emptyIntegrations: true,
      );

      expect(find.text('No integration items'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('error/retry remains for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpIntegrationsTab(
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
    });

    test('inventory reuses shared financial class vocabulary + permissions', () {
      expect(
        IntegrationsIntegrationsBillingInventory.atoms.any(
          (IntegrationsIntegrationsFinancialAtom atom) =>
              atom.financialClass ==
              IntegrationsIntegrationsFinancialClass.createCharge,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsIntegrationsAtomPermissions.tab,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsIntegrationsAtomPermissions.create,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsIntegrationsAtomPermissions.delete,
          integrationsWorkspaceDeleteRequirement,
        ),
        isTrue,
      );
    });
  });
}
