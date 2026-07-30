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
import 'package:hosspi_hms/features/integrations/presentation/integrations_logs_billing_inventory.dart';
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

const IntegrationLogRecord _healthyLog = IntegrationLogRecord(
  id: 'log-1',
  integrationLabel: 'Lab HL7 Feed',
  integrationType: 'HL7',
  status: 'SUCCESS',
  message: 'Message accepted',
);

const IntegrationLogRecord _attentionLog = IntegrationLogRecord(
  id: 'log-2',
  integrationLabel: 'Failed Delivery',
  integrationType: 'FHIR',
  status: 'FAILED',
  message: 'Delivery timed out',
  requiresAttention: true,
);

const IntegrationLogRecord _replayedLog = IntegrationLogRecord(
  id: 'log-3',
  integrationLabel: 'Failed Delivery',
  integrationType: 'FHIR',
  status: 'FAILED',
  message: '[REPLAY] Delivery timed out',
  requiresAttention: true,
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
  List<IntegrationLogRecord> logs = const <IntegrationLogRecord>[_healthyLog],
}) {
  when(() => repository.listIntegrations()).thenAnswer(
    (_) async =>
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
    (_) async => Result<List<IntegrationLogRecord>>.success(logs),
  );
  when(() => repository.getLog(any())).thenAnswer((Invocation invocation) async {
    final String id = invocation.positionalArguments.first as String;
    final IntegrationLogRecord match = logs.firstWhere(
      (IntegrationLogRecord log) => log.id == id,
      orElse: () => logs.isEmpty ? _healthyLog : logs.first,
    );
    return Result<IntegrationLogRecord>.success(match);
  });
  when(
    () => repository.interopCapabilities(),
  ).thenReturn(const <InteropCapabilityStatus>[]);
}

Future<void> _pumpLogsTab(
  WidgetTester tester, {
  required _MockIntegrationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IntegrationLogRecord> logs = const <IntegrationLogRecord>[_healthyLog],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, logs: logs);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/integrations?section=logs',
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

  group('IntegrationsLogsBillingInventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(integrationsLogsTabHasNoBillableActions(), isTrue);
      expect(
        IntegrationsLogsBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(IntegrationsLogsBillingInventory.atoms, isNotEmpty);
      expect(
        IntegrationsLogsBillingInventory.billableClasses.every(
          (IntegrationsLogsFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(integrationsLogsBillingScopeNote, contains('NOT_BILLED'));
      expect(integrationsLogsBillingScopeNote, contains('Billing'));

      for (final IntegrationsLogsFinancialAtom atom
          in IntegrationsLogsBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<IntegrationsLogsFinancialClass>[
            IntegrationsLogsFinancialClass.notRequired,
            IntegrationsLogsFinancialClass.notBilled,
            IntegrationsLogsFinancialClass.noCharge,
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

    test('replay + sanitized log stay NOT_BILLED audit ops', () {
      for (final String id in <String>[
        'next_action_replay_or_escalate',
        'detail_sanitized_log_panel',
        'detail_replay_action',
      ]) {
        final IntegrationsLogsFinancialAtom atom =
            IntegrationsLogsBillingInventory.atoms.singleWhere(
              (IntegrationsLogsFinancialAtom item) => item.id == id,
            );
        expect(atom.auditCode, 'NOT_BILLED', reason: id);
        expect(
          atom.financialClass,
          IntegrationsLogsFinancialClass.notBilled,
          reason: id,
        );
      }
    });

    test('reserved billable atoms stay unmounted', () {
      expect(
        IntegrationsLogsBillingInventory.atoms
            .singleWhere(
              (IntegrationsLogsFinancialAtom atom) =>
                  atom.id == 'interop_order_payment_via_log_replay',
            )
            .mounted,
        isFalse,
      );
      expect(
        IntegrationsLogsBillingInventory.atoms
            .singleWhere(
              (IntegrationsLogsFinancialAtom atom) =>
                  atom.id == 'webhook_settlement_ack_without_ledger',
            )
            .mounted,
        isFalse,
      );
      expect(
        IntegrationsLogsBillingInventory.atoms
            .singleWhere(
              (IntegrationsLogsFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        IntegrationsLogsBillingInventory.atoms
            .singleWhere(
              (IntegrationsLogsFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
    });

    test('replay gate requires manage ∪ permission', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
        },
      );
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      );
      expect(IntegrationsLogsBillingInventory.canReplayLogs(writer), isTrue);
      expect(IntegrationsLogsBillingInventory.canReplayLogs(reader), isFalse);
    });
  });

  group('Logs billing bypass + authorization (AC2–AC4)', () {
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
      await _pumpLogsTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(_tab('Logs'), findsOneWidget);
      expect(find.text('Lab HL7 Feed'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets(
      'detail: sanitized log; no billing UX; flat sections',
      (WidgetTester tester) async {
        await _pumpLogsTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(find.text('Lab HL7 Feed').first);
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        expect(find.byType(AppMessagePanel), findsOneWidget);
        expect(find.textContaining('Message accepted'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expectFlatTitledSectionLayout(
          tester,
          contextLabel: 'log detail dialog',
        );
      },
    );

    testWidgets(
      'replay posts audit copy only — no Billing UX; list syncs',
      (WidgetTester tester) async {
        when(() => repository.replayLog(any(), any())).thenAnswer(
          (_) async => const Result<IntegrationActionResult>.success(
            IntegrationActionResult(
              id: 'log-3',
              status: 'FAILED',
              message: '[REPLAY] Delivery timed out',
            ),
          ),
        );
        when(() => repository.listLogs()).thenAnswer(
          (_) async => const Result<List<IntegrationLogRecord>>.success(
            <IntegrationLogRecord>[_attentionLog, _replayedLog],
          ),
        );

        await _pumpLogsTab(
          tester,
          repository: repository,
          accessPolicy: writer,
          logs: const <IntegrationLogRecord>[_attentionLog],
        );

        await tester.tap(find.text('Failed Delivery').first);
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Replay').first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(AppButton, 'Replay').last);
        await tester.pumpAndSettle();

        verify(() => repository.replayLog('log-2', any())).called(1);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Invoice'), findsNothing);
        expect(find.textContaining('Balance'), findsNothing);
      },
    );

    testWidgets(
      'unauthorized users cannot collect/adjust or replay logs',
      (WidgetTester tester) async {
        await _pumpLogsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.integrationRead},
          ),
          logs: const <IntegrationLogRecord>[_attentionLog],
        );

        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);

        await tester.tap(find.text('Failed Delivery').first);
        await tester.pumpAndSettle();

        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Adjust'), findsNothing);
        expect(find.textContaining('Write off'), findsNothing);
        expect(find.textContaining('Replay'), findsNothing);
        expectFlatTitledSectionLayout(tester);
      },
    );
  });

  group('Logs flat sections (AC5)', () {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.integrationRead,
        AppPermissions.integrationWrite,
      },
    );

    testWidgets('desktop worklist: flat titled sections', (
      WidgetTester tester,
    ) async {
      await _pumpLogsTab(
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
      await _pumpLogsTab(
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
      await _pumpLogsTab(
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
      await _pumpLogsTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        themeMode: ThemeMode.dark,
      );
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets(
      'detail tiles + sanitized message stay non-nested siblings',
      (WidgetTester tester) async {
        await _pumpLogsTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(find.text('Lab HL7 Feed').first);
        await tester.pumpAndSettle();

        expect(find.byType(AppMessagePanel), findsOneWidget);
        expect(find.byType(AppInfoTileGrid), findsOneWidget);
        expectFlatTitledSectionLayout(
          tester,
          contextLabel: 'log detail siblings',
        );
      },
    );
  });
}
