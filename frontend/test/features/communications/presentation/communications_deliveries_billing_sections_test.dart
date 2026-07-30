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
import 'package:hosspi_hms/features/communications/presentation/communications_deliveries_billing_inventory.dart';
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

const NotificationDelivery _delivery = NotificationDelivery(
  id: 'delivery-1',
  status: 'FAILED',
  channel: 'EMAIL',
  notificationTitle: 'Critical lab result',
  recipientTarget: 'nurse@example.com',
  attemptCount: 2,
  errorMessage: 'Mailbox full',
  targetPath: '/patients/patient-1',
);

const NotificationDelivery _deliveryNoPath = NotificationDelivery(
  id: 'delivery-2',
  status: 'SENT',
  channel: 'SMS',
  notificationTitle: 'Appointment reminder',
  recipientTarget: '+256700000000',
  attemptCount: 1,
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
  List<NotificationDelivery> deliveries = const <NotificationDelivery>[
    _delivery,
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
          failedDeliveries: deliveries.length,
          templates: 0,
        ),
        metrics: NotificationMetrics(
          total: 0,
          unread: 0,
          attentionRequired: 0,
          failedDeliveries: deliveries.length,
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
          items: deliveries,
          request: query.pageRequest,
          totalItemCount: deliveries.length,
        ),
        templates: AppPage<CommunicationTemplate>(
          items: const <CommunicationTemplate>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
        selectedDelivery: query.panel == CommunicationsPanel.deliveries
            ? deliveries.firstOrNull
            : null,
      ),
    );
  });
}

Finder _tableRowInkWell() => find.byWidgetPredicate(
  (Widget widget) => widget.runtimeType.toString() == 'TableRowInkWell',
);

Future<void> _openDeliveryDetail(WidgetTester tester) async {
  final Finder row = _tableRowInkWell();
  if (row.evaluate().isNotEmpty) {
    await tester.tap(row.first);
  } else {
    await tester.tap(find.textContaining('Critical lab').first);
  }
  await tester.pumpAndSettle();
}

Future<void> _pumpDeliveries(
  WidgetTester tester, {
  required _MockCommunicationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<NotificationDelivery> deliveries = const <NotificationDelivery>[
    _delivery,
  ],
  Result<CommunicationsWorkspaceState>? workspaceOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    deliveries: deliveries,
    workspaceOverride: workspaceOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/communications?panel=deliveries',
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
      GoRoute(
        path: '/patients/:id',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Patient detail'));
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

  group('Communications Deliveries financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        CommunicationsDeliveriesBillingInventory.deliveriesTabHasNoBillableActions,
        isTrue,
      );
      expect(
        CommunicationsDeliveriesBillingInventory
            .allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(CommunicationsDeliveriesBillingInventory.atoms, isNotEmpty);
      expect(
        CommunicationsDeliveriesBillingInventory.billableClasses.every(
          (CommunicationsDeliveriesFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(communicationsDeliveriesBillingScopeNote, contains('NOT_BILLED'));

      for (final CommunicationsDeliveriesFinancialAtom atom
          in CommunicationsDeliveriesBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<CommunicationsDeliveriesFinancialClass>[
            CommunicationsDeliveriesFinancialClass.notRequired,
            CommunicationsDeliveriesFinancialClass.notBilled,
            CommunicationsDeliveriesFinancialClass.noCharge,
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

    test('delivery status display stays NOT_BILLED ops telemetry', () {
      final CommunicationsDeliveriesFinancialAtom status =
          CommunicationsDeliveriesBillingInventory.atoms.singleWhere(
            (CommunicationsDeliveriesFinancialAtom atom) =>
                atom.id == 'delivery_status_display',
          );
      expect(
        status.financialClass,
        CommunicationsDeliveriesFinancialClass.notBilled,
      );
      expect(status.auditCode, 'NOT_BILLED');
    });

    test('open linked stays NOT_REQUIRED navigate-only', () {
      final CommunicationsDeliveriesFinancialAtom openLinked =
          CommunicationsDeliveriesBillingInventory.atoms.singleWhere(
            (CommunicationsDeliveriesFinancialAtom atom) =>
                atom.id == 'next_action_open_linked',
          );
      expect(
        openLinked.financialClass,
        CommunicationsDeliveriesFinancialClass.notRequired,
      );
      expect(openLinked.auditCode, 'NOT_REQUIRED');
    });

    test('unmounted billable atoms document Billing / subscriptions SoR', () {
      expect(
        CommunicationsDeliveriesBillingInventory.atoms
            .singleWhere(
              (CommunicationsDeliveriesFinancialAtom atom) =>
                  atom.id == 'sms_notification_commercial_package',
            )
            .mounted,
        isFalse,
      );
      expect(
        CommunicationsDeliveriesBillingInventory.atoms
            .singleWhere(
              (CommunicationsDeliveriesFinancialAtom atom) =>
                  atom.id == 'patient_clinical_charge_via_message',
            )
            .mounted,
        isFalse,
      );
      expect(
        CommunicationsDeliveriesBillingInventory.atoms
            .singleWhere(
              (CommunicationsDeliveriesFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        CommunicationsDeliveriesBillingInventory.atoms
            .singleWhere(
              (CommunicationsDeliveriesFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
      expect(communicationsDeliveriesBillingScopeNote, contains('Billing'));
      expect(
        communicationsDeliveriesBillingScopeNote,
        contains('subscriptions'),
      );
    });
  });

  group('Communications Deliveries billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpDeliveries(
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
      expect(find.text('Critical lab result'), findsWidgets);
      expect(find.byTooltip('New message'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('detail dialog: no financial controls; flat sibling sections', (
      WidgetTester tester,
    ) async {
      await _pumpDeliveries(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.communicationsRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      await _openDeliveryDetail(tester);

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('DELIVERY DETAIL'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Linked record'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.text('Archive'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.byType(AppCollapsibleSection), findsAtLeastNWidgets(2));
      expectFlatSections(tester);
    });

    testWidgets('unauthorized users cannot collect or adjust from Deliveries', (
      WidgetTester tester,
    ) async {
      await _pumpDeliveries(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.byTooltip('New message'), findsNothing);

      await _openDeliveryDetail(tester);

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Adjust'), findsNothing);
      expect(find.textContaining('Write off'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets(
      'search refresh syncs list without billing gate or payment UX',
      (WidgetTester tester) async {
        await _pumpDeliveries(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.communicationsRead},
          ),
        );

        clearInteractions(repository);
        await tester.enterText(find.byType(TextField).first, 'Critical');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();

        verify(() => repository.getWorkspace(any())).called(greaterThan(0));
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Invoice'), findsNothing);
        expectFlatSections(tester);
      },
    );
  });

  group('Communications Deliveries section layout (AC5)', () {
    testWidgets('desktop Deliveries: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpDeliveries(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        physicalSize: const Size(1920, 1200),
      );

      expectFlatSections(tester);

      await _openDeliveryDetail(tester);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Linked record'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('mobile Deliveries: flat sections', (WidgetTester tester) async {
      await _pumpDeliveries(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        physicalSize: const Size(390, 844),
      );
      expectFlatSections(tester);

      await _openDeliveryDetail(tester);
      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpDeliveries(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        themeMode: ThemeMode.light,
      );
      await _openDeliveryDetail(tester);
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpDeliveries(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        themeMode: ThemeMode.dark,
      );
      await _openDeliveryDetail(tester);
      expectFlatSections(tester);
    });

    testWidgets('detail without path keeps single Details section flat', (
      WidgetTester tester,
    ) async {
      await _pumpDeliveries(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        deliveries: const <NotificationDelivery>[_deliveryNoPath],
      );

      await tester.tap(find.text('View delivery').first);
      await tester.pumpAndSettle();

      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Linked record'), findsNothing);
      expect(find.byType(AppCollapsibleSection), findsOneWidget);
      expectFlatSections(tester);
    });
  });

  group('Communications Deliveries sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('authorized empty state remains without billing UX', (
      WidgetTester tester,
    ) async {
      await _pumpDeliveries(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        deliveries: const <NotificationDelivery>[],
      );

      expect(find.text('No deliveries'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('error/retry remains for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpDeliveries(
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
        CommunicationsDeliveriesBillingInventory.atoms.any(
          (CommunicationsDeliveriesFinancialAtom atom) =>
              atom.financialClass ==
              CommunicationsDeliveriesFinancialClass.createCharge,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsDeliveriesAtomPermissions.tab,
          communicationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsDeliveriesAtomPermissions.openLinked,
          communicationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
    });
  });
}
