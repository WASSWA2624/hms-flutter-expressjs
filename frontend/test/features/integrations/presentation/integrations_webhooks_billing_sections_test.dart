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
import 'package:hosspi_hms/features/integrations/data/repositories/integrations_repository_impl.dart';
import 'package:hosspi_hms/features/integrations/domain/entities/integration_entities.dart';
import 'package:hosspi_hms/features/integrations/domain/repositories/integrations_repository.dart';
import 'package:hosspi_hms/features/integrations/presentation/integrations_access.dart';
import 'package:hosspi_hms/features/integrations/presentation/integrations_webhooks_billing_inventory.dart';
import 'package:hosspi_hms/features/integrations/presentation/pages/integrations_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/layout/flat_section_layout_test_helpers.dart';

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
);

const WebhookSubscriptionRecord _activeWebhook = WebhookSubscriptionRecord(
  id: 'webhook-1',
  event: 'payment.completed',
  integrationLabel: 'Lab HL7 Feed',
  targetHost: 'hooks.example.com',
  targetUrl: 'https://hooks.example.com/payment',
  integrationStatus: 'ACTIVE',
  isActive: true,
);

const WebhookSubscriptionRecord _inactiveWebhook = WebhookSubscriptionRecord(
  id: 'webhook-2',
  event: 'claim.submitted',
  integrationLabel: 'Lab HL7 Feed',
  targetHost: 'hooks.example.com',
  targetUrl: 'https://hooks.example.com/claim',
  integrationStatus: 'INACTIVE',
  isActive: false,
);

const WebhookSubscriptionRecord _enabledWebhook = WebhookSubscriptionRecord(
  id: 'webhook-2',
  event: 'claim.submitted',
  integrationLabel: 'Lab HL7 Feed',
  targetHost: 'hooks.example.com',
  targetUrl: 'https://hooks.example.com/claim',
  integrationStatus: 'ACTIVE',
  isActive: true,
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
  List<WebhookSubscriptionRecord> webhooks =
      const <WebhookSubscriptionRecord>[_activeWebhook],
}) {
  when(() => repository.listIntegrations()).thenAnswer(
    (_) async => const Result<List<IntegrationRecord>>.success(
      <IntegrationRecord>[_integration],
    ),
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
    (_) async => Result<List<WebhookSubscriptionRecord>>.success(webhooks),
  );
  when(() => repository.listLogs()).thenAnswer(
    (_) async =>
        const Result<List<IntegrationLogRecord>>.success(<IntegrationLogRecord>[]),
  );
  when(
    () => repository.interopCapabilities(),
  ).thenReturn(const <InteropCapabilityStatus>[]);
}

Future<void> _pumpWebhooksTab(
  WidgetTester tester, {
  required _MockIntegrationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<WebhookSubscriptionRecord> webhooks =
      const <WebhookSubscriptionRecord>[_activeWebhook],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, webhooks: webhooks);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/integrations?section=webhooks',
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

  group('IntegrationsWebhooksBillingInventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(integrationsWebhooksTabHasNoBillableActions(), isTrue);
      expect(
        IntegrationsWebhooksBillingInventory
            .allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(IntegrationsWebhooksBillingInventory.atoms, isNotEmpty);
      expect(
        IntegrationsWebhooksBillingInventory.billableClasses.every(
          (IntegrationsWebhooksFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(integrationsWebhooksBillingScopeNote, contains('NOT_BILLED'));
      expect(integrationsWebhooksBillingScopeNote, contains('Billing'));

      for (final IntegrationsWebhooksFinancialAtom atom
          in IntegrationsWebhooksBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<IntegrationsWebhooksFinancialClass>[
            IntegrationsWebhooksFinancialClass.notRequired,
            IntegrationsWebhooksFinancialClass.notBilled,
            IntegrationsWebhooksFinancialClass.noCharge,
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

    test('create / replay / enable stay NOT_BILLED audit ops', () {
      for (final String id in <String>[
        'create_webhook',
        'detail_edit_webhook',
        'detail_replay_webhook',
        'detail_enable_disable',
        'next_action_enable_webhook',
        'payment_event_name_metadata',
      ]) {
        final IntegrationsWebhooksFinancialAtom atom =
            IntegrationsWebhooksBillingInventory.atoms.singleWhere(
              (IntegrationsWebhooksFinancialAtom item) => item.id == id,
            );
        expect(atom.auditCode, 'NOT_BILLED', reason: id);
        expect(
          atom.financialClass,
          IntegrationsWebhooksFinancialClass.notBilled,
          reason: id,
        );
      }
    });

    test('reserved billable atoms stay unmounted', () {
      expect(
        IntegrationsWebhooksBillingInventory.atoms
            .singleWhere(
              (IntegrationsWebhooksFinancialAtom atom) =>
                  atom.id == 'interop_order_payment_via_webhook_payload',
            )
            .mounted,
        isFalse,
      );
      expect(
        IntegrationsWebhooksBillingInventory.atoms
            .singleWhere(
              (IntegrationsWebhooksFinancialAtom atom) =>
                  atom.id == 'webhook_settlement_ack_without_ledger',
            )
            .mounted,
        isFalse,
      );
      expect(
        IntegrationsWebhooksBillingInventory.atoms
            .singleWhere(
              (IntegrationsWebhooksFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        IntegrationsWebhooksBillingInventory.atoms
            .singleWhere(
              (IntegrationsWebhooksFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
    });

    test('mutate gate requires manage ∪ permission', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
        },
      );
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      );
      expect(
        IntegrationsWebhooksBillingInventory.canMutateWebhooks(writer),
        isTrue,
      );
      expect(
        IntegrationsWebhooksBillingInventory.canMutateWebhooks(reader),
        isFalse,
      );
    });
  });

  group('Webhooks billing bypass + authorization (AC2–AC4)', () {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.integrationRead,
        AppPermissions.integrationWrite,
        AppPermissions.billingWrite,
      },
    );

    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(_tab('Webhooks'), findsOneWidget);
      expect(find.text('payment.completed'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets(
      'detail: event tiles; payment.completed is metadata only; flat sections',
      (WidgetTester tester) async {
        await _pumpWebhooksTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(find.text('payment.completed').first);
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        expect(find.textContaining('payment.completed'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.textContaining('Acknowledge settlement'), findsNothing);
        expectFlatTitledSectionLayout(
          tester,
          contextLabel: 'webhook detail dialog',
        );
      },
    );

    testWidgets(
      'replay posts delivery only — no Billing UX; list stays synced',
      (WidgetTester tester) async {
        when(() => repository.replayWebhook(any(), any())).thenAnswer(
          (_) async => const Result<IntegrationActionResult>.success(
            IntegrationActionResult(
              title: 'Replay',
              status: 'DELIVERED',
              message: 'Webhook replay delivered',
            ),
          ),
        );

        await _pumpWebhooksTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(find.text('payment.completed').first);
        await tester.pumpAndSettle();

        expect(find.text('Replay webhook'), findsOneWidget);
        await tester.tap(find.text('Replay webhook'));
        await tester.pumpAndSettle();

        final Finder confirm = find.widgetWithText(AppButton, 'Replay webhook');
        expect(confirm, findsWidgets);
        await tester.tap(confirm.last);
        await tester.pumpAndSettle();

        verify(() => repository.replayWebhook('webhook-1', any())).called(1);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Invoice'), findsNothing);
        expect(find.textContaining('Balance due'), findsNothing);
      },
    );

    testWidgets(
      'enable syncs list without Billing mutation',
      (WidgetTester tester) async {
        when(() => repository.updateWebhook(any(), any())).thenAnswer(
          (_) async => const Result<WebhookSubscriptionRecord>.success(
            _enabledWebhook,
          ),
        );

        await _pumpWebhooksTab(
          tester,
          repository: repository,
          accessPolicy: writer,
          webhooks: const <WebhookSubscriptionRecord>[_inactiveWebhook],
        );

        expect(find.text('Enable webhook'), findsWidgets);
        await tester.ensureVisible(find.text('Enable webhook').first);
        await tester.tap(find.text('Enable webhook').first);
        await tester.pumpAndSettle();

        final Finder confirm = find.widgetWithText(AppButton, 'Enable');
        expect(confirm, findsWidgets);
        await tester.tap(confirm.last);
        await tester.pumpAndSettle();

        verify(() => repository.updateWebhook('webhook-2', any())).called(1);
        expect(find.text('Monitor delivery'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Balance due'), findsNothing);
      },
    );

    testWidgets(
      'unauthorized users cannot collect/adjust or mutate webhooks',
      (WidgetTester tester) async {
        await _pumpWebhooksTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.integrationRead},
          ),
          webhooks: const <WebhookSubscriptionRecord>[
            _activeWebhook,
            _inactiveWebhook,
          ],
        );

        expect(find.byTooltip('Create webhook'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);

        await tester.tap(find.text('payment.completed').first);
        await tester.pumpAndSettle();

        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Adjust'), findsNothing);
        expect(find.textContaining('Write off'), findsNothing);
        expect(find.textContaining('Replay'), findsNothing);
        expect(find.textContaining('Edit'), findsNothing);
        expectFlatTitledSectionLayout(tester);
      },
    );
  });

  group('Webhooks flat sections (AC5)', () {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.integrationRead,
        AppPermissions.integrationWrite,
      },
    );

    testWidgets('desktop worklist: flat titled sections', (
      WidgetTester tester,
    ) async {
      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        physicalSize: const Size(1440, 900),
      );
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('mobile worklist: flat titled sections', (
      WidgetTester tester,
    ) async {
      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        physicalSize: const Size(720, 900),
      );
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        themeMode: ThemeMode.light,
      );
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        themeMode: ThemeMode.dark,
      );
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets(
      'create dialog form fields stay non-nested under dialog body',
      (WidgetTester tester) async {
        await _pumpWebhooksTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(find.byTooltip('Create webhook'));
        await tester.pumpAndSettle();

        expect(find.text('Create webhook'), findsWidgets);
        expect(find.byType(AppFormShell), findsOneWidget);
        expectFlatTitledSectionLayout(
          tester,
          contextLabel: 'create webhook dialog',
        );
      },
    );

    testWidgets(
      'detail tiles stay non-nested siblings under Column',
      (WidgetTester tester) async {
        await _pumpWebhooksTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(find.text('payment.completed').first);
        await tester.pumpAndSettle();

        expect(find.byType(AppInfoTileGrid), findsAtLeastNWidgets(1));
        expectFlatTitledSectionLayout(
          tester,
          contextLabel: 'webhook detail siblings',
        );
      },
    );
  });
}
