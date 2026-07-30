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
import 'package:hosspi_hms/features/communications/data/repositories/communications_repository_impl.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/domain/repositories/communications_repository.dart';
import 'package:hosspi_hms/features/communications/presentation/communications_access.dart';
import 'package:hosspi_hms/features/communications/presentation/communications_templates_billing_inventory.dart';
import 'package:hosspi_hms/features/communications/presentation/pages/communications_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockCommunicationsRepository extends Mock
    implements CommunicationsRepository {}

const CommunicationTemplate _template = CommunicationTemplate(
  id: 'template-1',
  name: 'Discharge summary',
  channel: 'EMAIL',
  subject: 'Your discharge summary',
  description: 'Patient discharge template',
  body: 'Hello {{patientName}}, your discharge is ready.',
  previewSubject: 'Your discharge summary',
  previewBody: 'Hello Jane Doe, your discharge is ready.',
  variableCount: 3,
  isActive: true,
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: communicationsActiveModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['NURSE'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(
  _MockCommunicationsRepository repository, {
  List<CommunicationTemplate> templates = const <CommunicationTemplate>[
    _template,
  ],
  Result<CommunicationsWorkspaceState>? workspaceOverride,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (workspaceOverride != null) {
      return workspaceOverride;
    }
    final CommunicationsWorkspaceQuery query =
        invocation.positionalArguments.single as CommunicationsWorkspaceQuery;
    return Result<CommunicationsWorkspaceState>.success(
      CommunicationsWorkspaceState(
        query: query,
        summary: CommunicationsSummary(
          unreadThreads: 0,
          notifications: 0,
          failedDeliveries: 0,
          templates: templates.length,
        ),
        metrics: const NotificationMetrics(
          total: 0,
          unread: 0,
          attentionRequired: 0,
          failedDeliveries: 0,
        ),
        conversations: AppPage<CommunicationsConversation>(
          items: const <CommunicationsConversation>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
        notifications: AppPage<NotificationItem>(
          items: const <NotificationItem>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
        deliveries: AppPage<NotificationDelivery>(
          items: const <NotificationDelivery>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
        templates: AppPage<CommunicationTemplate>(
          items: templates,
          request: query.pageRequest,
          totalItemCount: templates.length,
        ),
        selectedTemplate: query.panel == CommunicationsPanel.templates
            ? templates.firstOrNull
            : null,
      ),
    );
  });
}

Future<void> _pumpTemplates(
  WidgetTester tester, {
  required _MockCommunicationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<CommunicationTemplate> templates = const <CommunicationTemplate>[
    _template,
  ],
  Result<CommunicationsWorkspaceState>? workspaceOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    templates: templates,
    workspaceOverride: workspaceOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/communications?panel=templates',
    routes: <RouteBase>[
      GoRoute(
        path: '/communications',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: CommunicationsWorkspacePage(
              initialQuery: CommunicationsWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        communicationsRepositoryProvider.overrideWithValue(repository),
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
  late _MockCommunicationsRepository repository;

  setUpAll(() {
    registerFallbackValue(const CommunicationsWorkspaceQuery());
  });

  setUp(() {
    repository = _MockCommunicationsRepository();
  });

  group('Communications Templates financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        CommunicationsTemplatesBillingInventory.templatesTabHasNoBillableActions,
        isTrue,
      );
      expect(
        CommunicationsTemplatesBillingInventory
            .allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(CommunicationsTemplatesBillingInventory.atoms, isNotEmpty);
      expect(
        CommunicationsTemplatesBillingInventory.billableClasses.every(
          (CommunicationsTemplatesFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(communicationsTemplatesBillingScopeNote, contains('NOT_BILLED'));

      for (final CommunicationsTemplatesFinancialAtom atom
          in CommunicationsTemplatesBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<CommunicationsTemplatesFinancialClass>[
            CommunicationsTemplatesFinancialClass.notRequired,
            CommunicationsTemplatesFinancialClass.notBilled,
            CommunicationsTemplatesFinancialClass.noCharge,
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

    test('template status display stays NOT_BILLED ops catalog', () {
      final CommunicationsTemplatesFinancialAtom status =
          CommunicationsTemplatesBillingInventory.atoms.singleWhere(
            (CommunicationsTemplatesFinancialAtom atom) =>
                atom.id == 'template_status_display',
          );
      expect(
        status.financialClass,
        CommunicationsTemplatesFinancialClass.notBilled,
      );
      expect(status.auditCode, 'NOT_BILLED');
    });

    test('detail preview stays NOT_BILLED', () {
      final CommunicationsTemplatesFinancialAtom preview =
          CommunicationsTemplatesBillingInventory.atoms.singleWhere(
            (CommunicationsTemplatesFinancialAtom atom) =>
                atom.id == 'detail_preview_panel',
          );
      expect(
        preview.financialClass,
        CommunicationsTemplatesFinancialClass.notBilled,
      );
      expect(preview.auditCode, 'NOT_BILLED');
    });

    test('unmounted billable atoms document Billing / subscriptions SoR', () {
      expect(
        CommunicationsTemplatesBillingInventory.atoms
            .singleWhere(
              (CommunicationsTemplatesFinancialAtom atom) =>
                  atom.id == 'sms_notification_commercial_package',
            )
            .mounted,
        isFalse,
      );
      expect(
        CommunicationsTemplatesBillingInventory.atoms
            .singleWhere(
              (CommunicationsTemplatesFinancialAtom atom) =>
                  atom.id == 'patient_clinical_charge_via_message',
            )
            .mounted,
        isFalse,
      );
      expect(
        CommunicationsTemplatesBillingInventory.atoms
            .singleWhere(
              (CommunicationsTemplatesFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        CommunicationsTemplatesBillingInventory.atoms
            .singleWhere(
              (CommunicationsTemplatesFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
      expect(
        CommunicationsTemplatesBillingInventory.atoms
            .singleWhere(
              (CommunicationsTemplatesFinancialAtom atom) =>
                  atom.id == 'create_update_template',
            )
            .mounted,
        isFalse,
      );
      expect(
        CommunicationsTemplatesBillingInventory.atoms
            .singleWhere(
              (CommunicationsTemplatesFinancialAtom atom) =>
                  atom.id == 'delete_template',
            )
            .mounted,
        isFalse,
      );
      expect(communicationsTemplatesBillingScopeNote, contains('Billing'));
      expect(
        communicationsTemplatesBillingScopeNote,
        contains('subscriptions'),
      );
    });
  });

  group('Communications Templates billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpTemplates(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.communicationsRead,
            AppPermissions.communicationsWrite,
            AppPermissions.billingWrite,
          },
        ),
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.text('Discharge summary'), findsWidgets);
      expect(find.byTooltip('New message'), findsNothing);
      expect(find.text('Create'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('detail dialog: no financial controls; flat sibling sections', (
      WidgetTester tester,
    ) async {
      await _pumpTemplates(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.communicationsRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      await tester.tap(find.text('Discharge summary').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('TEMPLATE DETAIL'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.text('Create'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.byType(AppWorkspaceDetailPanel), findsAtLeastNWidgets(2));
      expectFlatSections(tester);
    });

    testWidgets('unauthorized users cannot collect or adjust from Templates', (
      WidgetTester tester,
    ) async {
      await _pumpTemplates(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.byTooltip('New message'), findsNothing);

      await tester.tap(find.text('Discharge summary').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Adjust'), findsNothing);
      expect(find.textContaining('Write off'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets(
      'search refresh syncs list without billing gate or payment UX',
      (WidgetTester tester) async {
        await _pumpTemplates(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.communicationsRead},
          ),
        );

        clearInteractions(repository);
        await tester.enterText(find.byType(TextField).first, 'Discharge');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();

        verify(() => repository.getWorkspace(any())).called(greaterThan(0));
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Invoice'), findsNothing);
        expectFlatSections(tester);
      },
    );
  });

  group('Communications Templates section layout (AC5)', () {
    testWidgets('desktop Templates: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpTemplates(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        physicalSize: const Size(1920, 1200),
      );

      expectFlatSections(tester);

      await tester.tap(find.text('Discharge summary').first);
      await tester.pumpAndSettle();
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('mobile Templates: flat sections', (WidgetTester tester) async {
      await _pumpTemplates(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        physicalSize: const Size(390, 844),
      );
      expectFlatSections(tester);

      await tester.tap(find.textContaining('Discharge').first);
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpTemplates(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        themeMode: ThemeMode.light,
      );
      await tester.tap(find.text('Discharge summary').first);
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpTemplates(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        themeMode: ThemeMode.dark,
      );
      await tester.tap(find.text('Discharge summary').first);
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });

  group('Communications Templates sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('authorized empty state remains without billing UX', (
      WidgetTester tester,
    ) async {
      await _pumpTemplates(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        templates: const <CommunicationTemplate>[],
      );

      expect(find.text('No templates'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('error/retry remains for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpTemplates(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        workspaceOverride: const Result<CommunicationsWorkspaceState>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    test('inventory reuses shared financial class vocabulary + permissions', () {
      expect(
        CommunicationsTemplatesBillingInventory.atoms.any(
          (CommunicationsTemplatesFinancialAtom atom) =>
              atom.financialClass ==
              CommunicationsTemplatesFinancialClass.createCharge,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsTemplatesAtomPermissions.tab,
          communicationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsTemplatesAtomPermissions.delete,
          communicationsWorkspaceDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsTemplatesAtomPermissions.create,
          communicationsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
    });
  });
}
