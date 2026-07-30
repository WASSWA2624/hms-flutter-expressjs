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
import 'package:hosspi_hms/features/communications/presentation/communications_notifications_billing_inventory.dart';
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

Finder _tableRowInkWell() => find.byWidgetPredicate(
  (Widget widget) => widget.runtimeType.toString() == 'TableRowInkWell',
);

const NotificationItem _notification = NotificationItem(
  id: 'notification-1',
  title: 'Critical lab result',
  message: 'Potassium critically high',
  priority: 'HIGH',
  notificationType: 'LAB_ALERT',
  targetPath: '/patients/patient-1',
  deliveries: <NotificationDelivery>[
    NotificationDelivery(
      id: 'delivery-1',
      status: 'DELIVERED',
      channel: 'IN_APP',
      notificationTitle: 'Critical lab result',
      attemptCount: 1,
    ),
  ],
);

const NotificationItem _notificationNoPath = NotificationItem(
  id: 'notification-2',
  title: 'System maintenance',
  message: 'Brief downtime tonight',
  priority: 'LOW',
  notificationType: 'SYSTEM',
);

final NotificationItem _readNotification = NotificationItem(
  id: 'notification-1',
  title: 'Critical lab result',
  message: 'Potassium critically high',
  priority: 'HIGH',
  notificationType: 'LAB_ALERT',
  readAt: DateTime.utc(2026, 5, 20, 9),
  targetPath: '/patients/patient-1',
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
  List<NotificationItem> notifications = const <NotificationItem>[
    _notification,
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
          notifications: notifications.length,
        ),
        metrics: NotificationMetrics(total: notifications.length),
        conversations: const AppPage<CommunicationsConversation>(
          items: <CommunicationsConversation>[],
          request: AppPageRequest(pageSize: 30),
          totalItemCount: 0,
        ),
        notifications: AppPage<NotificationItem>(
          items: notifications,
          request: query.pageRequest,
          totalItemCount: notifications.length,
        ),
        deliveries: const AppPage<NotificationDelivery>(
          items: <NotificationDelivery>[],
          request: AppPageRequest(pageSize: 30),
          totalItemCount: 0,
        ),
        templates: const AppPage<CommunicationTemplate>(
          items: <CommunicationTemplate>[],
          request: AppPageRequest(pageSize: 30),
          totalItemCount: 0,
        ),
        selectedNotification:
            query.panel == CommunicationsPanel.notifications &&
                query.notificationId != null
            ? notifications.cast<NotificationItem?>().firstWhere(
                (NotificationItem? item) => item?.id == query.notificationId,
                orElse: () => null,
              )
            : null,
      ),
    );
  });
}

Future<void> _pumpNotifications(
  WidgetTester tester, {
  required _MockCommunicationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<NotificationItem> notifications = const <NotificationItem>[
    _notification,
  ],
  Result<CommunicationsWorkspaceState>? workspaceOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    notifications: notifications,
    workspaceOverride: workspaceOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/communications?panel=notifications',
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

  group('Communications Notifications financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        CommunicationsNotificationsBillingInventory
            .notificationsTabHasNoBillableActions,
        isTrue,
      );
      expect(
        CommunicationsNotificationsBillingInventory
            .allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(CommunicationsNotificationsBillingInventory.atoms, isNotEmpty);
      expect(
        CommunicationsNotificationsBillingInventory.billableClasses.every(
          (CommunicationsNotificationsFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(
        communicationsNotificationsBillingScopeNote,
        contains('NOT_BILLED'),
      );

      for (final CommunicationsNotificationsFinancialAtom atom
          in CommunicationsNotificationsBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<CommunicationsNotificationsFinancialClass>[
            CommunicationsNotificationsFinancialClass.notRequired,
            CommunicationsNotificationsFinancialClass.notBilled,
            CommunicationsNotificationsFinancialClass.noCharge,
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

    test('mark read/unread and archive stay NOT_BILLED internal ops', () {
      final CommunicationsNotificationsFinancialAtom markRead =
          CommunicationsNotificationsBillingInventory.atoms.singleWhere(
            (CommunicationsNotificationsFinancialAtom atom) =>
                atom.id == 'next_action_mark_read_unread',
          );
      expect(
        markRead.financialClass,
        CommunicationsNotificationsFinancialClass.notBilled,
      );
      expect(markRead.auditCode, 'NOT_BILLED');

      final CommunicationsNotificationsFinancialAtom archive =
          CommunicationsNotificationsBillingInventory.atoms.singleWhere(
            (CommunicationsNotificationsFinancialAtom atom) =>
                atom.id == 'detail_archive',
          );
      expect(
        archive.financialClass,
        CommunicationsNotificationsFinancialClass.notBilled,
      );
      expect(archive.auditCode, 'NOT_BILLED');
    });

    test('open linked stays NOT_REQUIRED navigate-only', () {
      final CommunicationsNotificationsFinancialAtom openLinked =
          CommunicationsNotificationsBillingInventory.atoms.singleWhere(
            (CommunicationsNotificationsFinancialAtom atom) =>
                atom.id == 'detail_open_linked',
          );
      expect(
        openLinked.financialClass,
        CommunicationsNotificationsFinancialClass.notRequired,
      );
      expect(openLinked.auditCode, 'NOT_REQUIRED');
    });

    test('unmounted billable atoms document Billing / subscriptions SoR', () {
      expect(
        CommunicationsNotificationsBillingInventory.atoms
            .singleWhere(
              (CommunicationsNotificationsFinancialAtom atom) =>
                  atom.id == 'sms_notification_commercial_package',
            )
            .mounted,
        isFalse,
      );
      expect(
        CommunicationsNotificationsBillingInventory.atoms
            .singleWhere(
              (CommunicationsNotificationsFinancialAtom atom) =>
                  atom.id == 'patient_clinical_charge_via_notification',
            )
            .mounted,
        isFalse,
      );
      expect(
        CommunicationsNotificationsBillingInventory.atoms
            .singleWhere(
              (CommunicationsNotificationsFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        CommunicationsNotificationsBillingInventory.atoms
            .singleWhere(
              (CommunicationsNotificationsFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
      expect(communicationsNotificationsBillingScopeNote, contains('Billing'));
      expect(
        communicationsNotificationsBillingScopeNote,
        contains('subscriptions'),
      );
    });
  });

  group('Communications Notifications billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpNotifications(
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

    testWidgets(
      'detail dialog: sibling sections; no financial controls',
      (WidgetTester tester) async {
        await _pumpNotifications(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.communicationsRead,
              AppPermissions.billingWrite,
            },
          ),
          physicalSize: const Size(1024, 900),
        );

        await tester.tap(_tableRowInkWell().first);
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        expect(find.text('NOTIFICATION DETAIL'), findsWidgets);
        expect(find.text('Details'), findsWidgets);
        expect(find.text('Linked record'), findsWidgets);
        expect(find.text('Delivery history'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.byType(AppCollapsibleSection), findsAtLeastNWidgets(3));
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'unauthorized users cannot collect or adjust from Notifications',
      (WidgetTester tester) async {
        await _pumpNotifications(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.communicationsRead},
          ),
        );

        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.byTooltip('New message'), findsNothing);

        await tester.tap(_tableRowInkWell().first);
        await tester.pumpAndSettle();

        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Adjust'), findsNothing);
        expect(find.textContaining('Write off'), findsNothing);
        expect(find.text('Archive'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'mark read syncs list without billing gate or payment UX',
      (WidgetTester tester) async {
        when(
          () => repository.markNotificationRead('notification-1'),
        ).thenAnswer(
          (_) async => Result<NotificationItem>.success(_readNotification),
        );
        when(() => repository.getNotificationMetrics()).thenAnswer(
          (_) async => const Result<NotificationMetrics>.success(
            NotificationMetrics(total: 1),
          ),
        );

        await _pumpNotifications(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.communicationsRead,
              AppPermissions.communicationsWrite,
            },
          ),
        );

        await tester.tap(find.text('Mark read').first);
        await tester.pumpAndSettle();

        verify(
          () => repository.markNotificationRead('notification-1'),
        ).called(1);
        expect(find.text('Communication action saved.'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Invoice'), findsNothing);
        expectFlatSections(tester);
      },
    );
  });

  group('Communications Notifications section layout (AC5)', () {
    testWidgets('desktop Notifications: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpNotifications(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        physicalSize: const Size(1920, 1200),
      );

      expectFlatSections(tester);

      await tester.tap(_tableRowInkWell().first);
      await tester.pumpAndSettle();
      expect(find.text('Details'), findsWidgets);
      expect(find.text('Linked record'), findsWidgets);
      expect(find.text('Delivery history'), findsWidgets);
      expectFlatSections(tester);
    });

    testWidgets('mobile Notifications: flat sections', (
      WidgetTester tester,
    ) async {
      await _pumpNotifications(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        physicalSize: const Size(390, 844),
      );
      expectFlatSections(tester);

      await tester.tap(find.textContaining('Critical lab').first);
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpNotifications(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
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
      await _pumpNotifications(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        themeMode: ThemeMode.dark,
      );
      await tester.tap(_tableRowInkWell().first);
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('detail without path keeps Details section flat', (
      WidgetTester tester,
    ) async {
      await _pumpNotifications(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        notifications: const <NotificationItem>[_notificationNoPath],
      );

      await tester.tap(_tableRowInkWell().first);
      await tester.pumpAndSettle();

      expect(find.text('Details'), findsWidgets);
      expect(find.text('Linked record'), findsNothing);
      expect(find.text('Delivery history'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.byType(AppCollapsibleSection),
        ),
        findsAtLeastNWidgets(1),
      );
      expectFlatSections(tester);
    });
  });

  group('Communications Notifications sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('authorized empty state remains without billing UX', (
      WidgetTester tester,
    ) async {
      await _pumpNotifications(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        notifications: const <NotificationItem>[],
      );

      expect(find.text('No notifications'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('error/retry remains for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpNotifications(
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
        CommunicationsNotificationsBillingInventory.atoms.any(
          (CommunicationsNotificationsFinancialAtom atom) =>
              atom.financialClass ==
              CommunicationsNotificationsFinancialClass.createCharge,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsNotificationsAtomPermissions.tab,
          communicationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsNotificationsAtomPermissions.openLinked,
          communicationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsNotificationsAtomPermissions.markRead,
          communicationsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsNotificationsAtomPermissions.archive,
          communicationsWorkspaceDeleteRequirement,
        ),
        isTrue,
      );
    });
  });
}
