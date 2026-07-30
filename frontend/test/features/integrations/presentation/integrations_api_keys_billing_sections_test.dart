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
import 'package:hosspi_hms/features/integrations/presentation/integrations_api_keys_billing_inventory.dart';
import 'package:hosspi_hms/features/integrations/presentation/pages/integrations_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/layout/flat_section_layout_test_helpers.dart';

class _MockIntegrationsRepository extends Mock
    implements IntegrationsRepository {}

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

const ApiKeyRecord _apiKey = ApiKeyRecord(
  id: 'api-key-1',
  name: 'Billing Export Key',
  userId: 'user-1',
  isActive: true,
  humanFriendlyId: 'key_billing',
);

const ApiKeyRecord _createdApiKey = ApiKeyRecord(
  id: 'api-key-new',
  name: 'New Export Key',
  userId: 'user-1',
  isActive: true,
  humanFriendlyId: 'key_new',
  oneTimeSecret: 'key_new.secret-once-only',
);

const ApiKeyPermissionRecord _apiKeyPermission = ApiKeyPermissionRecord(
  id: 'grant-1',
  apiKeyId: 'api-key-1',
  permissionId: 'perm-billing-read',
);

const IntegrationPermissionOption _permissionOption =
    IntegrationPermissionOption(
      id: 'perm-billing-read',
      name: 'billing:read',
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
  List<ApiKeyRecord> apiKeys = const <ApiKeyRecord>[_apiKey],
  List<ApiKeyPermissionRecord> permissions =
      const <ApiKeyPermissionRecord>[_apiKeyPermission],
}) {
  when(() => repository.listIntegrations()).thenAnswer(
    (_) async => const Result<List<IntegrationRecord>>.success(
      <IntegrationRecord>[],
    ),
  );
  when(() => repository.listApiKeys()).thenAnswer(
    (_) async => Result<List<ApiKeyRecord>>.success(apiKeys),
  );
  when(() => repository.listApiKeyPermissions()).thenAnswer(
    (_) async => Result<List<ApiKeyPermissionRecord>>.success(permissions),
  );
  when(() => repository.listPermissionOptions()).thenAnswer(
    (_) async => const Result<List<IntegrationPermissionOption>>.success(
      <IntegrationPermissionOption>[_permissionOption],
    ),
  );
  when(() => repository.listWebhooks()).thenAnswer(
    (_) async => const Result<List<WebhookSubscriptionRecord>>.success(
      <WebhookSubscriptionRecord>[],
    ),
  );
  when(() => repository.listLogs()).thenAnswer(
    (_) async => const Result<List<IntegrationLogRecord>>.success(
      <IntegrationLogRecord>[],
    ),
  );
  when(
    () => repository.interopCapabilities(),
  ).thenReturn(const <InteropCapabilityStatus>[]);
}

Future<void> _pumpApiKeysTab(
  WidgetTester tester, {
  required _MockIntegrationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<ApiKeyRecord> apiKeys = const <ApiKeyRecord>[_apiKey],
  List<ApiKeyPermissionRecord> permissions =
      const <ApiKeyPermissionRecord>[_apiKeyPermission],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, apiKeys: apiKeys, permissions: permissions);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/integrations?section=api-keys',
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

  group('IntegrationsApiKeysBillingInventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(integrationsApiKeysTabHasNoBillableActions(), isTrue);
      expect(
        IntegrationsApiKeysBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(IntegrationsApiKeysBillingInventory.atoms, isNotEmpty);
      expect(
        IntegrationsApiKeysBillingInventory.billableClasses.every(
          (IntegrationsApiKeysFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(integrationsApiKeysBillingScopeNote, contains('NOT_BILLED'));
      expect(integrationsApiKeysBillingScopeNote, contains('Billing'));

      for (final IntegrationsApiKeysFinancialAtom atom
          in IntegrationsApiKeysBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<IntegrationsApiKeysFinancialClass>[
            IntegrationsApiKeysFinancialClass.notRequired,
            IntegrationsApiKeysFinancialClass.notBilled,
            IntegrationsApiKeysFinancialClass.noCharge,
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

    test('create / secret reveal / permission grants stay NOT_BILLED', () {
      for (final String id in <String>[
        'create_api_key',
        'secret_reveal_write_only',
        'manage_permissions_add',
        'billing_permission_grant_metadata',
        'enable_disable_api_key',
        'revoke_api_key',
      ]) {
        final IntegrationsApiKeysFinancialAtom atom =
            IntegrationsApiKeysBillingInventory.atoms.singleWhere(
              (IntegrationsApiKeysFinancialAtom item) => item.id == id,
            );
        expect(atom.auditCode, 'NOT_BILLED', reason: id);
        expect(
          atom.financialClass,
          IntegrationsApiKeysFinancialClass.notBilled,
          reason: id,
        );
      }
    });

    test('reserved billable atoms stay unmounted', () {
      expect(
        IntegrationsApiKeysBillingInventory.atoms
            .singleWhere(
              (IntegrationsApiKeysFinancialAtom atom) =>
                  atom.id == 'interop_order_payment_via_api_key',
            )
            .mounted,
        isFalse,
      );
      expect(
        IntegrationsApiKeysBillingInventory.atoms
            .singleWhere(
              (IntegrationsApiKeysFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        IntegrationsApiKeysBillingInventory.atoms
            .singleWhere(
              (IntegrationsApiKeysFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
    });

    test('mutate gate requires create/update/delete helpers', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
        },
      );
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      );
      expect(IntegrationsApiKeysBillingInventory.canMutateApiKeys(writer), isTrue);
      expect(
        IntegrationsApiKeysBillingInventory.canMutateApiKeys(reader),
        isFalse,
      );
    });
  });

  group('API keys billing bypass + authorization (AC2–AC4)', () {
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
      await _pumpApiKeysTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(_tab('API keys'), findsOneWidget);
      expect(find.text('Billing Export Key'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets(
      'detail: sibling sections; billing:* grant is metadata only',
      (WidgetTester tester) async {
        await _pumpApiKeysTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(find.text('Billing Export Key').first);
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        expect(find.byType(AppCollapsibleSection), findsAtLeastNWidgets(3));
        expect(find.textContaining('key_billing'), findsWidgets);
        expect(find.text('billing:read'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expectFlatTitledSectionLayout(
          tester,
          contextLabel: 'api key detail dialog',
        );
      },
    );

    testWidgets(
      'create + secret reveal posts no Billing UX; secret is write-only',
      (WidgetTester tester) async {
        when(() => repository.createApiKey(any())).thenAnswer(
          (_) async => const Result<ApiKeyRecord>.success(_createdApiKey),
        );
        when(() => repository.listApiKeys()).thenAnswer(
          (_) async => const Result<List<ApiKeyRecord>>.success(<ApiKeyRecord>[
            _apiKey,
            _createdApiKey,
          ]),
        );

        await _pumpApiKeysTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(find.byTooltip('Create API key'));
        await tester.pumpAndSettle();

        final Finder createDialog = find.byType(AppDialog).last;
        expect(createDialog, findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);

        await tester.enterText(
          find
              .descendant(
                of: createDialog,
                matching: find.byType(TextFormField),
              )
              .first,
          'New Export Key',
        );
        await tester.tap(
          find.descendant(
            of: createDialog,
            matching: find.widgetWithText(AppButton, 'Create API key'),
          ),
        );
        await tester.pumpAndSettle();

        verify(() => repository.createApiKey(any())).called(1);
        expect(find.textContaining('key_new.secret-once-only'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Invoice'), findsNothing);
        // Secret reveal uses dialog chrome only — no titled section nesting.
        expect(
          find.descendant(
            of: find.byType(AppDialog).last,
            matching: find.byType(AppCollapsibleSection),
          ),
          findsNothing,
        );
        expectFlatTitledSectionLayout(
          tester,
          contextLabel: 'secret reveal dialog',
        );
      },
    );

    testWidgets(
      'unauthorized users cannot collect/adjust or mutate keys',
      (WidgetTester tester) async {
        await _pumpApiKeysTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.integrationRead},
          ),
        );

        expect(find.byTooltip('Create API key'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);

        await tester.tap(find.text('Billing Export Key').first);
        await tester.pumpAndSettle();

        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Adjust'), findsNothing);
        expect(find.textContaining('Write off'), findsNothing);
        expect(find.text('Manage permissions'), findsNothing);
        expect(find.text('Disable'), findsNothing);
        expect(find.text('Revoke'), findsNothing);
        expectFlatTitledSectionLayout(tester);
      },
    );

    testWidgets(
      'enable/disable syncs list without billing gate or payment UX',
      (WidgetTester tester) async {
        const ApiKeyRecord disabled = ApiKeyRecord(
          id: 'api-key-1',
          name: 'Billing Export Key',
          userId: 'user-1',
          humanFriendlyId: 'key_billing',
        );
        when(() => repository.updateApiKey(any(), any())).thenAnswer(
          (_) async => const Result<ApiKeyRecord>.success(disabled),
        );

        await _pumpApiKeysTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(find.text('Billing Export Key').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Disable'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(AppButton, 'Disable').last);
        await tester.pumpAndSettle();

        verify(() => repository.updateApiKey('api-key-1', any())).called(1);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Invoice'), findsNothing);
      },
    );
  });

  group('API keys flat sections (AC5)', () {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.integrationRead,
        AppPermissions.integrationWrite,
      },
    );

    testWidgets('desktop worklist: flat titled sections', (
      WidgetTester tester,
    ) async {
      await _pumpApiKeysTab(
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
      await _pumpApiKeysTab(
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
      await _pumpApiKeysTab(
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
      await _pumpApiKeysTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        themeMode: ThemeMode.dark,
      );
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets(
      'detail masked secret / rotation / permissions stay siblings',
      (WidgetTester tester) async {
        await _pumpApiKeysTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(find.text('Billing Export Key').first);
        await tester.pumpAndSettle();

        expect(find.byType(AppCollapsibleSection), findsNWidgets(3));
        expectFlatTitledSectionLayout(
          tester,
          contextLabel: 'api key detail siblings',
        );
      },
    );
  });
}
