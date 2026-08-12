import 'dart:async';

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
import 'package:hosspi_hms/features/theater/data/repositories/theater_repository_impl.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/features/theater/domain/repositories/theater_repository.dart';
import 'package:hosspi_hms/features/theater/presentation/pages/theater_workspace_page.dart';
import 'package:hosspi_hms/features/theater/presentation/theater_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockTheaterRepository extends Mock implements TheaterRepository {}

/// PACU case: ready, anesthesia FINAL, post-op DRAFT → next action Post-op.
const TheaterCase _recoveryCase = TheaterCase(
  id: 'TC-PACU',
  displayId: 'TC-PACU',
  patientDisplayName: 'Rita Pacu',
  status: 'IN_PROGRESS',
  workflowStage: 'POST_OP',
  checklistTotal: 2,
  checklistCompleted: 2,
  anesthesiaStatus: 'FINAL',
  postOpStatus: 'DRAFT',
  roomDisplayLabel: 'PACU-1',
);

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

Finder _scheduleCaseAction() => find.text('Schedule case');

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['DOCTOR'],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  final bool needsPatient = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.patientRead ||
        permission == AppPermissions.patientWrite,
  );
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalRead ||
        permission == AppPermissions.clinicalWrite,
  );
  final bool needsBilling = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.billingRead ||
        permission == AppPermissions.billingWrite,
  );
  final bool needsOperations = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.operationsRead ||
        permission == AppPermissions.operationsWrite,
  );
  final List<AppModuleEntitlement> resolvedModules =
      modules ??
      <AppModuleEntitlement>[
        const AppModuleEntitlement(
          code: theaterTheatreAnesthesiaModule,
          licenseStatus: 'ACTIVE',
        ),
        if (needsPatient)
          const AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
        if (needsClinical)
          const AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        if (needsBilling)
          const AppModuleEntitlement(
            code: 'billing-payments',
            licenseStatus: 'ACTIVE',
          ),
        if (needsOperations)
          const AppModuleEntitlement(
            code: 'facilities-maintenance',
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

void main() {
  late _MockTheaterRepository theaterRepository;

  setUpAll(() {
    registerFallbackValue(const TheaterCaseQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    theaterRepository = _MockTheaterRepository();
    _stubTheater(theaterRepository);
  });

  group('TheaterRecoveryAtomPermissions helpers', () {
    test('reuses Theater Recovery requirements (no second vocabulary)', () {
      expect(
        TheaterRecoveryAtomPermissions.tab,
        same(theaterWorkspaceReadRequirement),
      );
      expect(
        TheaterRecoveryAtomPermissions.write,
        same(theaterClinicalWriteRequirement),
      );
      expect(
        TheaterRecoveryAtomPermissions.scheduleCase,
        same(theaterScheduleCaseRequirement),
      );
      expect(
        TheaterRecoveryAtomPermissions.success,
        same(theaterClinicalWriteRequirement),
      );
      expect(
        TheaterRecoveryAtomPermissions.validation,
        same(theaterClinicalWriteRequirement),
      );
      expect(
        theaterBoardTabRequirement(TheaterSection.recovery),
        same(TheaterRecoveryAtomPermissions.tab),
      );
      expect(
        theaterWriteRequirementForSection(TheaterSection.recovery),
        same(TheaterRecoveryAtomPermissions.write),
      );
      expect(
        theaterDetailReadRequirement(TheaterSection.recovery),
        same(TheaterRecoveryAtomPermissions.detail),
      );
      expect(
        TheaterRecoveryAtomPermissions.routeEntry,
        same(theaterWorkspaceEntryRequirement),
      );
      expect(
        TheaterRecoveryAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.theaterEntry),
      );
      expect(
        TheaterRecoveryAtomPermissions.routeEntryUnion,
        same(theaterWorkspaceRouteUnionRequirement),
      );
      expect(
        TheaterRecoveryAtomPermissions.billingHolds,
        same(theaterBillingHoldReadRequirement),
      );
      expect(
        TheaterRecoveryAtomPermissions.roomContext,
        same(theaterRoomContextReadRequirement),
      );
      expect(theaterRouteEntryMatchesAppRoutes(), isTrue);
    });

    test('∩ denial: missing clinical:write hides Recovery write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(TheaterRecoveryAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(TheaterRecoveryAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        TheaterRecoveryAtomPermissions.scheduleCase.isAllowed(reader),
        isFalse,
      );
      expect(
        TheaterRecoveryAtomPermissions.nextActionPostOp.isAllowed(reader),
        isFalse,
      );
      expect(
        TheaterRecoveryAtomPermissions.nextActionHandover.isAllowed(reader),
        isFalse,
      );
      expect(
        TheaterRecoveryAtomPermissions.cancelCase.isAllowed(reader),
        isFalse,
      );
      expect(canWriteTheaterRecovery(reader), isFalse);
      expect(
        theaterBoardShowsNextActionColumn(reader, TheaterSection.recovery),
        isFalse,
      );
    });

    test('∩ denial: patient:write alone does not unlock Recovery mutations', () {
      final AppAccessPolicy patientWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.patientWrite,
        },
        roles: const <String>['RECEPTIONIST'],
      );
      expect(
        TheaterRecoveryAtomPermissions.tab.isAllowed(patientWriter),
        isTrue,
      );
      expect(
        TheaterRecoveryAtomPermissions.write.isAllowed(patientWriter),
        isFalse,
      );
      expect(canWriteTheaterRecovery(patientWriter), isFalse);
    });

    test('write ∩ presence: clinical:write + module allows mutations', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(TheaterRecoveryAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        TheaterRecoveryAtomPermissions.nextAction.isAllowed(writer),
        isTrue,
      );
      expect(TheaterRecoveryAtomPermissions.postOp.isAllowed(writer), isTrue);
      expect(
        TheaterRecoveryAtomPermissions.handover.isAllowed(writer),
        isTrue,
      );
      expect(
        TheaterRecoveryAtomPermissions.panelDeepLink.isAllowed(writer),
        isTrue,
      );
      expect(canWriteTheaterRecovery(writer), isTrue);
      expect(
        theaterBoardShowsNextActionColumn(writer, TheaterSection.recovery),
        isTrue,
      );
    });

    test('mapping note: matrix ∩ clinical:write via allPermissions', () {
      expect(
        theaterClinicalWriteRequirement.allPermissions,
        <AppPermission>[AppPermissions.clinicalWrite],
      );
      expect(theaterClinicalWriteRequirement.anyPermissions, isEmpty);
      expect(
        theaterClinicalWriteRequirement.activeModules,
        contains(theaterTheatreAnesthesiaModule),
      );
    });

    test('∪ allowance: clinical:read alone satisfies Recovery read', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(TheaterRecoveryAtomPermissions.tab.isAllowed(clinical), isTrue);
      expect(TheaterRecoveryAtomPermissions.search.isAllowed(clinical), isTrue);
      expect(canViewTheaterRecovery(clinical), isTrue);
      expect(canReadTheaterRecovery(clinical), isTrue);
    });

    test('∪ allowance: patient:read alone satisfies Recovery read', () {
      final AppAccessPolicy patient = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
        roles: const <String>['RECEPTIONIST'],
      );
      expect(TheaterRecoveryAtomPermissions.tab.isAllowed(patient), isTrue);
      expect(TheaterRecoveryAtomPermissions.loading.isAllowed(patient), isTrue);
      expect(TheaterRecoveryAtomPermissions.empty.isAllowed(patient), isTrue);
      expect(TheaterRecoveryAtomPermissions.write.isAllowed(patient), isFalse);
      expect(canViewTheaterTab(patient, TheaterSection.recovery), isTrue);
    });

    test(
      'route entry ∪: billing:read satisfies routeEntryUnion, not Recovery tab',
      () {
        final AppAccessPolicy entryOnly = _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        );
        expect(
          TheaterRecoveryAtomPermissions.routeEntryUnion.isAllowed(entryOnly),
          isTrue,
        );
        expect(
          TheaterRecoveryAtomPermissions.tab.isAllowed(entryOnly),
          isFalse,
        );
        expect(canViewTheaterRecovery(entryOnly), isFalse);
        expect(
          TheaterRecoveryAtomPermissions.catalogEntry.isAllowed(entryOnly),
          isFalse,
        );
      },
    );

    test('subscription strips Recovery when theatre-anesthesia inactive', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(TheaterRecoveryAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(TheaterRecoveryAtomPermissions.write.isAllowed(noModule), isFalse);
      expect(canViewTheaterRecovery(noModule), isFalse);
    });

    test(
      'ABAC: missing facility still allows Recovery chrome '
      '(row/own scope remains backend-authoritative)',
      () {
        final AppAccessPolicy noFacility = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
          facilityId: null,
        );
        expect(noFacility.hasFacilityContext, isFalse);
        expect(TheaterRecoveryAtomPermissions.tab.isAllowed(noFacility), isTrue);
        expect(
          TheaterRecoveryAtomPermissions.write.isAllowed(noFacility),
          isTrue,
        );
      },
    );

    test(
      'nested cross-module _(n/a)_: Recovery write does not grant billing',
      () {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        );
        expect(TheaterRecoveryAtomPermissions.write.isAllowed(writer), isTrue);
        expect(writer.grants(AppPermissions.billingRead), isFalse);
        expect(
          TheaterRecoveryAtomPermissions.billingHolds.isAllowed(writer),
          isFalse,
        );
        expect(
          TheaterRecoveryAtomPermissions.roomContext.isAllowed(writer),
          isFalse,
        );
        final AppAccessPolicy billingOnly = _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        );
        expect(
          TheaterRecoveryAtomPermissions.tab.isAllowed(billingOnly),
          isFalse,
        );
        expect(
          TheaterRecoveryAtomPermissions.write.isAllowed(billingOnly),
          isFalse,
        );
      },
    );

    test('nested billing holds require billing:read + billing-payments', () {
      final AppAccessPolicy billingReader = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.billingRead,
        },
      );
      expect(
        TheaterRecoveryAtomPermissions.billingHolds.isAllowed(billingReader),
        isTrue,
      );
      expect(canViewTheaterBillingHolds(billingReader), isTrue);
    });

    test('room/asset operations context requires operations:read', () {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.operationsRead,
        },
      );
      expect(
        TheaterRecoveryAtomPermissions.roomContext.isAllowed(opsReader),
        isTrue,
      );
      expect(canViewTheaterRoomContext(opsReader), isTrue);
      // Core room column stays on workspace read ∪ (not operations).
      expect(
        TheaterRecoveryAtomPermissions.roomColumn.isAllowed(
          _policy(permissions: <AppPermission>{AppPermissions.clinicalRead}),
        ),
        isTrue,
      );
    });
  });

  testWidgets(
    '∪ denial: without clinical:read or patient:read, Recovery absent',
    (WidgetTester tester) async {
      await _pumpRecoveryTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        ),
      );

      expect(_tab('Recovery'), findsNothing);
      expect(find.text('Rita Pacu'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expect(_scheduleCaseAction(), findsNothing);
      // Every board tab is read-gated; the strip collapses entirely.
      expect(find.byType(AppTabStrip), findsNothing);
    },
  );

  testWidgets(
    'authorized read ∪: clinical:read mounts list; write actions absent',
    (WidgetTester tester) async {
      await _pumpRecoveryTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      expect(_tab('Recovery'), findsOneWidget);
      expect(find.text('Rita Pacu'), findsOneWidget);
      expect(_scheduleCaseAction(), findsNothing);
      expect(find.widgetWithText(AppButton, 'Post-op'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Rita Pacu'));
      await _pumpAfterAction(tester);

      expect(find.text('CASE DETAIL'), findsOneWidget);
      expect(find.byType(AppQuickActions), findsNothing);
      expect(find.text('Reschedule'), findsNothing);
      expect(find.text('Cancel case'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∪ allowance: patient:read mounts Recovery; write actions absent',
    (WidgetTester tester) async {
      await _pumpRecoveryTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          roles: const <String>['RECEPTIONIST'],
        ),
      );

      expect(_tab('Recovery'), findsOneWidget);
      expect(find.text('Rita Pacu'), findsOneWidget);
      expect(_scheduleCaseAction(), findsNothing);
      expect(find.widgetWithText(AppButton, 'Post-op'), findsNothing);

      await tester.tap(find.text('Rita Pacu'));
      await _pumpAfterAction(tester);

      expect(find.byType(AppQuickActions), findsNothing);
      expect(find.text('Cancel case'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Schedule / Post-op next action / detail Quick Actions mount',
    (WidgetTester tester) async {
      await _pumpRecoveryTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      expect(find.text('Rita Pacu'), findsOneWidget);
      expect(_scheduleCaseAction(), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Post-op'), findsOneWidget);

      await tester.tap(find.text('Rita Pacu'));
      await _pumpAfterAction(tester);

      expect(find.byType(AppQuickActions), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Reschedule'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Cancel case'),
        ),
        findsOneWidget,
      );
      // Next-action Post-op is omitted from Quick Actions when opened from row.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Post-op'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'authorized Post-op next-action syncs after Save record',
    (WidgetTester tester) async {
      when(
        () => theaterRepository.upsertPostOpNote(any(), any()),
      ).thenAnswer(
        (_) async => Result<TheaterCase>.success(
          TheaterCase(
            id: _recoveryCase.id,
            displayId: _recoveryCase.displayId,
            patientDisplayName: _recoveryCase.patientDisplayName,
            status: 'IN_PROGRESS',
            workflowStage: 'POST_OP',
            checklistTotal: 2,
            checklistCompleted: 2,
            anesthesiaStatus: 'FINAL',
            postOpStatus: 'FINAL',
          ),
        ),
      );

      await _pumpRecoveryTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      final Finder postOp = find.widgetWithText(AppButton, 'Post-op');
      await tester.ensureVisible(postOp);
      await tester.tap(postOp);
      await _pumpAfterAction(tester);

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('CASE DETAIL'), findsNothing);

      final Finder dialogFields = find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(TextField),
      );
      expect(dialogFields, findsWidgets);
      await tester.enterText(dialogFields.last, 'Recovering well in PACU');
      await tester.tap(find.widgetWithText(AppButton, 'Save record'));
      await _pumpAfterAction(tester);

      verify(() => theaterRepository.upsertPostOpNote(any(), any())).called(1);
      expect(find.textContaining('Theater changes saved'), findsWidgets);
    },
  );

  testWidgets(
    'authorized validation feedback remains on cancel without reason',
    (WidgetTester tester) async {
      await _pumpRecoveryTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      await tester.tap(find.text('Rita Pacu'));
      await _pumpAfterAction(tester);
      await tester.ensureVisible(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Cancel case'),
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Cancel case'),
        ),
      );
      await _pumpAfterAction(tester);

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.widgetWithText(AppButton, 'Cancel case'), findsWidgets);
      await tester.tap(find.widgetWithText(AppButton, 'Cancel case').last);
      await _pumpAfterAction(tester);

      verifyNever(() => theaterRepository.updateStage(any(), any()));
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('error / retry state remains for authorized Recovery users', (
    WidgetTester tester,
  ) async {
    when(() => theaterRepository.listCases(any())).thenAnswer(
      (_) async => const Result<AppPage<TheaterCase>>.failure(NetworkFailure()),
    );

    await _pumpRecoveryTab(
      tester,
      theaterRepository: theaterRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      ),
    );

    expect(find.textContaining('Try again'), findsWidgets);
    expect(find.widgetWithText(AppButton, 'Post-op'), findsNothing);
    expect(_scheduleCaseAction(), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('empty state remains for authorized Recovery users', (
    WidgetTester tester,
  ) async {
    _stubTheater(theaterRepository, cases: const <TheaterCase>[]);

    await _pumpRecoveryTab(
      tester,
      theaterRepository: theaterRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      ),
    );

    expect(find.text('No theater cases'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Post-op'), findsNothing);
    expect(_scheduleCaseAction(), findsNothing);
  });

  testWidgets('authorized loading chrome remains observable on Recovery', (
    WidgetTester tester,
  ) async {
    final Completer<Result<AppPage<TheaterCase>>> listCompleter =
        Completer<Result<AppPage<TheaterCase>>>();
    when(
      () => theaterRepository.listCases(any()),
    ).thenAnswer((_) => listCompleter.future);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/theater?section=recovery',
      routes: <RouteBase>[
        GoRoute(
          path: '/theater',
          builder: (BuildContext context, GoRouterState state) {
            return Scaffold(
              body: TheaterWorkspacePage(
                initialQuery: TheaterBoardQuery.fromUri(state.uri),
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          theaterRepositoryProvider.overrideWithValue(theaterRepository),
          followUpTabCountProvider.overrideWith(
            (Ref ref, FollowUpWorklistScope scope) => null,
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.ready(),
          ),
          appAccessPolicyProvider.overrideWithValue(
            _policy(
              permissions: <AppPermission>{AppPermissions.clinicalRead},
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.light,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.textContaining('Loading'), findsWidgets);
    expect(find.widgetWithText(AppButton, 'Post-op'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);

    listCompleter.complete(
      Result<AppPage<TheaterCase>>.success(
        AppPage<TheaterCase>(
          items: const <TheaterCase>[_recoveryCase],
          request: const AppPageRequest(pageSize: 12),
          totalItemCount: 1,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Rita Pacu'), findsOneWidget);
  });

  testWidgets('mobile viewport: authorized Recovery list remains usable', (
    WidgetTester tester,
  ) async {
    await _pumpRecoveryTab(
      tester,
      theaterRepository: theaterRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
      physicalSize: const Size(390, 844),
    );

    expect(_tab('Recovery'), findsOneWidget);
    expect(find.byType(AppListTableMobileItem), findsWidgets);
    expect(find.textContaining('Rita'), findsWidgets);
    expect(find.widgetWithText(AppButton, 'Post-op'), findsOneWidget);
  });

  testWidgets('desktop viewport: authorized Recovery chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpRecoveryTab(
      tester,
      theaterRepository: theaterRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
      physicalSize: const Size(1440, 900),
    );

    expect(find.text('Rita Pacu'), findsOneWidget);
    expect(_tab('Recovery'), findsOneWidget);
    expect(_scheduleCaseAction(), findsOneWidget);
  });

  testWidgets('light theme: authorized Recovery chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpRecoveryTab(
      tester,
      theaterRepository: theaterRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
      themeMode: ThemeMode.light,
    );

    expect(find.text('Rita Pacu'), findsOneWidget);
    expect(_tab('Recovery'), findsOneWidget);
  });

  testWidgets('dark theme: authorized Recovery chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpRecoveryTab(
      tester,
      theaterRepository: theaterRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
      themeMode: ThemeMode.dark,
    );

    expect(find.text('Rita Pacu'), findsOneWidget);
    expect(_tab('Recovery'), findsOneWidget);
  });

  testWidgets(
    'deep link section=recovery without read falls back off Recovery',
    (WidgetTester tester) async {
      await _pumpRecoveryTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        ),
        initialLocation: '/theater?section=recovery',
      );

      expect(_tab('Recovery'), findsNothing);
      expect(find.text('Rita Pacu'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strips Recovery tab when theatre-anesthesia inactive',
    (WidgetTester tester) async {
      await _pumpRecoveryTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'patient-registry',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );

      expect(_tab('Recovery'), findsNothing);
      expect(find.text('Rita Pacu'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'integration: Recovery board uses section write ∩ for next-action column',
    (WidgetTester tester) async {
      await _pumpRecoveryTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      final AppListTable<TheaterCase> table = tester
          .widget<AppListTable<TheaterCase>>(
            find.byType(AppListTable<TheaterCase>),
          );
      expect(table.columnVisibilityStorageKey, 'theater_recovery');
      expect(
        table.columns.any(
          (AppListTableColumn<TheaterCase> c) => c.id == 'next_action',
        ),
        isTrue,
      );
      expect(
        table.columns.any((AppListTableColumn<TheaterCase> c) => c.id == 'room'),
        isTrue,
      );
    },
  );

  testWidgets(
    'integration: read-only Recovery board omits next-action column',
    (WidgetTester tester) async {
      await _pumpRecoveryTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      final AppListTable<TheaterCase> table = tester
          .widget<AppListTable<TheaterCase>>(
            find.byType(AppListTable<TheaterCase>),
          );
      expect(
        table.columns.any(
          (AppListTableColumn<TheaterCase> c) => c.id == 'next_action',
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'compliance: Recovery toolbar Print/Export omit without evidence:export',
    (WidgetTester tester) async {
      await _pumpRecoveryTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      final AppListTable<TheaterCase> table = tester
          .widget<AppListTable<TheaterCase>>(
            find.byType(AppListTable<TheaterCase>),
          );
      expect(table.canExport, isFalse);
      expect(table.canPrint, isFalse);
      expect(table.enablePrint, isTrue);
      expect(table.printLabel, 'Print');
      expect(table.search?.advancedFilterButtonLabel, 'Filters');
      expect(table.search?.advancedFilterApplyLabel, 'Apply filters');
      expect(table.search?.advancedFilterResetLabel, 'Clear filters');
      expect(table.search?.advancedFilterCloseLabel, 'Close');
      expect(table.columnVisibilityLabel, 'Settings');
      expect(find.text('Export'), findsNothing);
      expect(find.text('Print'), findsNothing);
      expect(find.text('Schedule case'), findsOneWidget);
    },
  );

  testWidgets(
    'compliance: Recovery mounts Export/Print when evidence:export allowed',
    (WidgetTester tester) async {
      await _pumpRecoveryTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.evidenceExport,
          },
        ),
      );

      final AppListTable<TheaterCase> table = tester
          .widget<AppListTable<TheaterCase>>(
            find.byType(AppListTable<TheaterCase>),
          );
      expect(table.canExport, isTrue);
      expect(table.canPrint, isTrue);
      expect(table.printLabel, 'Print');
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);
      expect(find.text('Schedule case'), findsOneWidget);
    },
  );

  testWidgets(
    'compliance: Recovery defaults prefer-5 columns, warning count, aligned stage',
    (WidgetTester tester) async {
      clearInteractions(theaterRepository);
      when(() => theaterRepository.listCases(any())).thenAnswer((
        Invocation invocation,
      ) async {
        final TheaterCaseQuery query =
            invocation.positionalArguments.single as TheaterCaseQuery;
        List<TheaterCase> items = const <TheaterCase>[_recoveryCase];
        final String? status = query.status?.trim().toUpperCase();
        final String? stage = query.stage?.trim().toUpperCase();
        if (status != null && status.isNotEmpty) {
          items = items
              .where((TheaterCase item) => item.normalizedStatus == status)
              .toList(growable: false);
        }
        if (stage != null && stage.isNotEmpty) {
          final Set<String> stages = stage
              .split(',')
              .map((String part) => part.trim().toUpperCase())
              .where((String part) => part.isNotEmpty)
              .toSet();
          items = items
              .where(
                (TheaterCase item) => stages.contains(item.normalizedStage),
              )
              .toList(growable: false);
        }
        return Result<AppPage<TheaterCase>>.success(
          AppPage<TheaterCase>(
            items: items,
            request: query.pageRequest,
            totalItemCount: items.length,
          ),
        );
      });
      when(() => theaterRepository.getCase(any())).thenAnswer(
        (_) async => const Result<TheaterCase>.success(_recoveryCase),
      );

      await _pumpRecoveryTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      final List<TheaterCaseQuery> queries = verify(
        () => theaterRepository.listCases(captureAny()),
      ).captured.cast<TheaterCaseQuery>();
      expect(
        queries.any(
          (TheaterCaseQuery q) => q.stage == theaterRecoveryStageFilter,
        ),
        isTrue,
      );

      final AppListTable<TheaterCase> table = tester
          .widget<AppListTable<TheaterCase>>(
            find.byType(AppListTable<TheaterCase>),
          );
      final Set<String> dataIds = table.columns
          .map((AppListTableColumn<TheaterCase> c) => c.key)
          .where((String id) => id != 'next_action')
          .toSet();
      expect(
        dataIds,
        <String>{'patient', 'procedure', 'room', 'time', 'status'},
      );
      expect(dataIds.length, 5);

      final AppTabStrip strip = tester.widget(find.byType(AppTabStrip));
      final AppTabItem recovery = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.id == TheaterSection.recovery.name,
      );
      expect(recovery.countTone, AppTabCountTone.warning);
      expect(recovery.count, isNotNull);
    },
  );
}

Future<void> _pumpAfterAction(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pumpRecoveryTab(
  WidgetTester tester, {
  required _MockTheaterRepository theaterRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/theater?section=recovery',
}) async {
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
        path: '/theater',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: TheaterWorkspacePage(
              initialQuery: TheaterBoardQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        theaterRepositoryProvider.overrideWithValue(theaterRepository),
        followUpTabCountProvider.overrideWith(
          (Ref ref, FollowUpWorklistScope scope) => null,
        ),
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
  // Adaptive polling keeps timers alive, so avoid pumpAndSettle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(seconds: 1));
}

void _stubTheater(
  _MockTheaterRepository repository, {
  List<TheaterCase> cases = const <TheaterCase>[_recoveryCase],
}) {
  when(() => repository.listCases(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final TheaterCaseQuery query =
        invocation.positionalArguments.single as TheaterCaseQuery;
    List<TheaterCase> items = cases;
    final String? status = query.status?.trim().toUpperCase();
    final String? stage = query.stage?.trim().toUpperCase();
    if (status != null && status.isNotEmpty) {
      items = items
          .where((TheaterCase item) => item.normalizedStatus == status)
          .toList(growable: false);
    }
    if (stage != null && stage.isNotEmpty) {
      final Set<String> stages = stage
          .split(',')
          .map((String part) => part.trim().toUpperCase())
          .where((String part) => part.isNotEmpty)
          .toSet();
      items = items
          .where(
            (TheaterCase item) => stages.contains(item.normalizedStage),
          )
          .toList(growable: false);
    }
    return Result<AppPage<TheaterCase>>.success(
      AppPage<TheaterCase>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.getCase(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final String id = invocation.positionalArguments.single as String;
    if (cases.isEmpty) {
      return Result<TheaterCase>.success(_recoveryCase);
    }
    final TheaterCase match = cases.firstWhere(
      (TheaterCase item) => item.id == id || item.effectiveDisplayId == id,
      orElse: () => cases.first,
    );
    return Result<TheaterCase>.success(match);
  });
}
