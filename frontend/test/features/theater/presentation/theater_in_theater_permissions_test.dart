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

const TheaterCase _inTheaterCase = TheaterCase(
  id: 'TC-OR',
  displayId: 'TC-OR',
  patientDisplayName: 'Ira InTheater',
  status: 'IN_PROGRESS',
  workflowStage: 'INTRA_OP',
  checklistTotal: 2,
  checklistCompleted: 2,
  anesthesiaStatus: 'DRAFT',
  roomDisplayLabel: 'OR-1',
);

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

Finder _toolbarPrimary(String label) => find.descendant(
  of: find.byType(AppTabToolbarPrimary),
  matching: find.text(label),
);

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
  final bool needsTheater = permissions.any(
    (AppPermission permission) => permission == AppPermissions.theaterRead,
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
        if (needsTheater)
          const AppModuleEntitlement(
            code: theaterTheatreAnesthesiaModule,
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

  group('TheaterInTheaterAtomPermissions helpers', () {
    test('reuses Theater In theater requirements (no second vocabulary)', () {
      expect(
        TheaterInTheaterAtomPermissions.tab,
        same(theaterWorkspaceReadRequirement),
      );
      expect(
        TheaterInTheaterAtomPermissions.write,
        same(theaterClinicalWriteRequirement),
      );
      expect(
        TheaterInTheaterAtomPermissions.scheduleCase,
        same(theaterScheduleCaseRequirement),
      );
      expect(
        TheaterInTheaterAtomPermissions.success,
        same(theaterClinicalWriteRequirement),
      );
      expect(
        TheaterInTheaterAtomPermissions.validation,
        same(theaterClinicalWriteRequirement),
      );
      expect(
        theaterBoardTabRequirement(TheaterSection.inTheater),
        same(TheaterInTheaterAtomPermissions.tab),
      );
      expect(
        theaterWriteRequirementForSection(TheaterSection.inTheater),
        same(TheaterInTheaterAtomPermissions.write),
      );
      expect(
        TheaterInTheaterAtomPermissions.routeEntry,
        same(theaterWorkspaceEntryRequirement),
      );
      expect(
        TheaterInTheaterAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.theaterEntry),
      );
      expect(
        TheaterInTheaterAtomPermissions.routeEntryUnion,
        same(theaterWorkspaceRouteUnionRequirement),
      );
      expect(
        TheaterInTheaterAtomPermissions.billingHolds,
        same(theaterBillingHoldReadRequirement),
      );
      expect(
        TheaterInTheaterAtomPermissions.roomContext,
        same(theaterRoomContextReadRequirement),
      );
      expect(theaterRouteEntryMatchesAppRoutes(), isTrue);
    });

    test('∩ denial: missing clinical:write hides In theater write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(TheaterInTheaterAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(TheaterInTheaterAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        TheaterInTheaterAtomPermissions.scheduleCase.isAllowed(reader),
        isFalse,
      );
      expect(
        TheaterInTheaterAtomPermissions.nextActionAnesthesia.isAllowed(reader),
        isFalse,
      );
      expect(
        TheaterInTheaterAtomPermissions.cancelCase.isAllowed(reader),
        isFalse,
      );
      expect(canWriteTheaterInTheater(reader), isFalse);
      expect(
        theaterBoardShowsNextActionColumn(reader, TheaterSection.inTheater),
        isFalse,
      );
    });

    test(
      '∩ denial: patient:write alone does not unlock In theater mutations',
      () {
        final AppAccessPolicy patientWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.patientWrite,
          },
          roles: const <String>['RECEPTIONIST'],
        );
        expect(
          TheaterInTheaterAtomPermissions.tab.isAllowed(patientWriter),
          isTrue,
        );
        expect(
          TheaterInTheaterAtomPermissions.write.isAllowed(patientWriter),
          isFalse,
        );
        expect(canWriteTheaterInTheater(patientWriter), isFalse);
      },
    );

    test('write ∩ presence: clinical:write + module allows mutations', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(TheaterInTheaterAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        TheaterInTheaterAtomPermissions.nextAction.isAllowed(writer),
        isTrue,
      );
      expect(
        TheaterInTheaterAtomPermissions.anesthesia.isAllowed(writer),
        isTrue,
      );
      expect(
        TheaterInTheaterAtomPermissions.panelDeepLink.isAllowed(writer),
        isTrue,
      );
      expect(canWriteTheaterInTheater(writer), isTrue);
      expect(
        theaterBoardShowsNextActionColumn(writer, TheaterSection.inTheater),
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

    test('∪ allowance: clinical:read alone satisfies In theater read', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(TheaterInTheaterAtomPermissions.tab.isAllowed(clinical), isTrue);
      expect(
        TheaterInTheaterAtomPermissions.search.isAllowed(clinical),
        isTrue,
      );
      expect(canViewTheaterInTheater(clinical), isTrue);
      expect(canReadTheaterInTheater(clinical), isTrue);
    });

    test('∪ allowance: patient:read alone satisfies In theater read', () {
      final AppAccessPolicy patient = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
        roles: const <String>['RECEPTIONIST'],
      );
      expect(TheaterInTheaterAtomPermissions.tab.isAllowed(patient), isTrue);
      expect(
        TheaterInTheaterAtomPermissions.loading.isAllowed(patient),
        isTrue,
      );
      expect(TheaterInTheaterAtomPermissions.empty.isAllowed(patient), isTrue);
      expect(TheaterInTheaterAtomPermissions.write.isAllowed(patient), isFalse);
      expect(
        canViewTheaterTab(patient, TheaterSection.inTheater),
        isTrue,
      );
    });

    test(
      'route entry ∪: billing:read satisfies routeEntryUnion, not In theater tab',
      () {
        final AppAccessPolicy entryOnly = _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        );
        expect(
          TheaterInTheaterAtomPermissions.routeEntryUnion.isAllowed(entryOnly),
          isTrue,
        );
        expect(
          TheaterInTheaterAtomPermissions.tab.isAllowed(entryOnly),
          isFalse,
        );
        expect(canViewTheaterInTheater(entryOnly), isFalse);
        expect(
          TheaterInTheaterAtomPermissions.catalogEntry.isAllowed(entryOnly),
          isFalse,
        );
      },
    );

    test(
      'subscription strips In theater when theatre-anesthesia inactive',
      () {
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
        expect(
          TheaterInTheaterAtomPermissions.tab.isAllowed(noModule),
          isFalse,
        );
        expect(
          TheaterInTheaterAtomPermissions.write.isAllowed(noModule),
          isFalse,
        );
        expect(canViewTheaterInTheater(noModule), isFalse);
      },
    );

    test(
      'ABAC: missing facility still allows In theater chrome '
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
        expect(
          TheaterInTheaterAtomPermissions.tab.isAllowed(noFacility),
          isTrue,
        );
        expect(
          TheaterInTheaterAtomPermissions.write.isAllowed(noFacility),
          isTrue,
        );
      },
    );

    test(
      'nested cross-module _(n/a)_: In theater write does not grant billing',
      () {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        );
        expect(TheaterInTheaterAtomPermissions.write.isAllowed(writer), isTrue);
        expect(writer.grants(AppPermissions.billingRead), isFalse);
        expect(
          TheaterInTheaterAtomPermissions.billingHolds.isAllowed(writer),
          isFalse,
        );
        expect(
          TheaterInTheaterAtomPermissions.roomContext.isAllowed(writer),
          isFalse,
        );
        final AppAccessPolicy billingOnly = _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        );
        expect(
          TheaterInTheaterAtomPermissions.tab.isAllowed(billingOnly),
          isFalse,
        );
        expect(
          TheaterInTheaterAtomPermissions.write.isAllowed(billingOnly),
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
        TheaterInTheaterAtomPermissions.billingHolds.isAllowed(billingReader),
        isTrue,
      );
      expect(
        canViewTheaterBillingHolds(billingReader),
        isTrue,
      );
    });

    test('room/asset operations context requires operations:read', () {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.operationsRead,
        },
      );
      expect(
        TheaterInTheaterAtomPermissions.roomContext.isAllowed(opsReader),
        isTrue,
      );
      expect(canViewTheaterRoomContext(opsReader), isTrue);
      // Core room column stays on workspace read ∪ (not operations).
      expect(
        TheaterInTheaterAtomPermissions.roomColumn.isAllowed(
          _policy(permissions: <AppPermission>{AppPermissions.clinicalRead}),
        ),
        isTrue,
      );
    });
  });

  testWidgets(
    '∪ denial: without clinical:read or patient:read, In theater absent',
    (WidgetTester tester) async {
      await _pumpInTheaterTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        ),
      );

      expect(_tab('In theater'), findsNothing);
      expect(find.text('Ira InTheater'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expect(_toolbarPrimary('Schedule case'), findsNothing);
      // Unscanned Scheduled / Recovery remain once route is entered.
      expect(find.byType(AppTabStrip), findsOneWidget);
    },
  );

  testWidgets(
    'authorized read ∪: clinical:read mounts list; write actions absent',
    (WidgetTester tester) async {
      await _pumpInTheaterTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      expect(_tab('In theater'), findsOneWidget);
      expect(find.text('Ira InTheater'), findsOneWidget);
      expect(_toolbarPrimary('Schedule case'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Anesthesia'), findsNothing);
      expect(find.text('Anesthesia'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Ira InTheater'));
      await _pumpAfterAction(tester);

      expect(find.text('CASE DETAIL'), findsOneWidget);
      expect(find.byType(AppQuickActions), findsNothing);
      expect(find.text('Reschedule'), findsNothing);
      expect(find.text('Cancel case'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∪ allowance: patient:read mounts In theater; write actions absent',
    (WidgetTester tester) async {
      await _pumpInTheaterTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          roles: const <String>['RECEPTIONIST'],
        ),
      );

      expect(_tab('In theater'), findsOneWidget);
      expect(find.text('Ira InTheater'), findsOneWidget);
      expect(_toolbarPrimary('Schedule case'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Anesthesia'), findsNothing);

      await tester.tap(find.text('Ira InTheater'));
      await _pumpAfterAction(tester);

      expect(find.byType(AppQuickActions), findsNothing);
      expect(find.text('Cancel case'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Schedule / Anesthesia / detail Quick Actions mount',
    (WidgetTester tester) async {
      await _pumpInTheaterTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      expect(find.text('Ira InTheater'), findsOneWidget);
      expect(_toolbarPrimary('Schedule case'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Anesthesia'), findsOneWidget);

      await tester.tap(find.text('Ira InTheater'));
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
      // Next-action Anesthesia is omitted from Quick Actions when opened from row.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Anesthesia'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'authorized Anesthesia next-action syncs after Save record',
    (WidgetTester tester) async {
      when(
        () => theaterRepository.upsertAnesthesiaRecord(any(), any()),
      ).thenAnswer(
        (_) async => Result<TheaterCase>.success(
          TheaterCase(
            id: _inTheaterCase.id,
            displayId: _inTheaterCase.displayId,
            patientDisplayName: _inTheaterCase.patientDisplayName,
            status: 'IN_PROGRESS',
            workflowStage: 'INTRA_OP',
            checklistTotal: 2,
            checklistCompleted: 2,
            anesthesiaStatus: 'FINAL',
          ),
        ),
      );

      await _pumpInTheaterTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      final Finder anesthesia = find.widgetWithText(AppButton, 'Anesthesia');
      await tester.ensureVisible(anesthesia);
      await tester.tap(anesthesia);
      await _pumpAfterAction(tester);

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('CASE DETAIL'), findsNothing);

      final Finder notesField = find.widgetWithText(
        TextField,
        'Anesthesia notes',
      );
      // Label may be outside TextField; fall back to last TextField in dialog.
      if (notesField.evaluate().isEmpty) {
        final Finder dialogFields = find.descendant(
          of: find.byType(AppDialog),
          matching: find.byType(TextField),
        );
        expect(dialogFields, findsWidgets);
        await tester.enterText(dialogFields.last, 'Stable under GA');
      } else {
        await tester.enterText(notesField, 'Stable under GA');
      }
      await tester.tap(find.widgetWithText(AppButton, 'Save record'));
      await _pumpAfterAction(tester);

      verify(
        () => theaterRepository.upsertAnesthesiaRecord(any(), any()),
      ).called(1);
      expect(find.textContaining('Saved'), findsWidgets);
    },
  );

  testWidgets(
    'authorized validation feedback remains on cancel without reason',
    (WidgetTester tester) async {
      await _pumpInTheaterTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      await tester.tap(find.text('Ira InTheater'));
      await _pumpAfterAction(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Cancel case'),
        ),
      );
      await _pumpAfterAction(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Cancel case').last);
      await _pumpAfterAction(tester);

      expect(find.text('Cancellation reason'), findsOneWidget);
      verifyNever(() => theaterRepository.updateStage(any(), any()));
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('error / retry state remains for authorized In theater users', (
    WidgetTester tester,
  ) async {
    when(() => theaterRepository.listCases(any())).thenAnswer(
      (_) async => const Result<AppPage<TheaterCase>>.failure(NetworkFailure()),
    );

    await _pumpInTheaterTab(
      tester,
      theaterRepository: theaterRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      ),
    );

    expect(find.text('Try again'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Anesthesia'), findsNothing);

    _stubTheater(theaterRepository);
    await tester.tap(find.text('Try again'));
    await _pumpAfterAction(tester);

    expect(find.text('Ira InTheater'), findsOneWidget);
  });

  testWidgets('empty state remains for authorized In theater users', (
    WidgetTester tester,
  ) async {
    _stubTheater(theaterRepository, cases: const <TheaterCase>[]);

    await _pumpInTheaterTab(
      tester,
      theaterRepository: theaterRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      ),
    );

    expect(find.text('No theater cases'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Anesthesia'), findsNothing);
    expect(_toolbarPrimary('Schedule case'), findsNothing);
  });

  testWidgets('authorized loading chrome remains observable on In theater', (
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
      initialLocation: '/theater?section=in-theater',
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
    expect(find.widgetWithText(AppButton, 'Anesthesia'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);

    listCompleter.complete(
      Result<AppPage<TheaterCase>>.success(
        AppPage<TheaterCase>(
          items: const <TheaterCase>[_inTheaterCase],
          request: const AppPageRequest(pageSize: 12),
          totalItemCount: 1,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Ira InTheater'), findsOneWidget);
  });

  testWidgets('mobile viewport: authorized In theater list remains usable', (
    WidgetTester tester,
  ) async {
    await _pumpInTheaterTab(
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

    expect(_tab('In theater'), findsOneWidget);
    expect(find.byType(AppListTableMobileItem), findsWidgets);
    expect(find.textContaining('Ira'), findsWidgets);
    expect(find.widgetWithText(AppButton, 'Anesthesia'), findsOneWidget);
  });

  testWidgets('desktop viewport: authorized In theater chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpInTheaterTab(
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

    expect(find.text('Ira InTheater'), findsOneWidget);
    expect(_tab('In theater'), findsOneWidget);
    expect(_toolbarPrimary('Schedule case'), findsOneWidget);
  });

  testWidgets('light theme: authorized In theater chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpInTheaterTab(
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

    expect(find.text('Ira InTheater'), findsOneWidget);
    expect(_tab('In theater'), findsOneWidget);
  });

  testWidgets('dark theme: authorized In theater chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpInTheaterTab(
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

    expect(find.text('Ira InTheater'), findsOneWidget);
    expect(_tab('In theater'), findsOneWidget);
  });

  testWidgets(
    'deep link section=in-theater without read falls back off In theater',
    (WidgetTester tester) async {
      await _pumpInTheaterTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        ),
        initialLocation: '/theater?section=in-theater',
      );

      expect(_tab('In theater'), findsNothing);
      expect(find.text('Ira InTheater'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strips In theater tab when theatre-anesthesia inactive',
    (WidgetTester tester) async {
      await _pumpInTheaterTab(
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

      expect(_tab('In theater'), findsNothing);
      expect(find.text('Ira InTheater'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'integration: In theater board uses section write ∩ for next-action column',
    (WidgetTester tester) async {
      await _pumpInTheaterTab(
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
      expect(table.columnVisibilityStorageKey, 'theater_inTheater');
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
}

Future<void> _pumpAfterAction(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pumpInTheaterTab(
  WidgetTester tester, {
  required _MockTheaterRepository theaterRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/theater?section=in-theater',
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
  List<TheaterCase> cases = const <TheaterCase>[_inTheaterCase],
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
      items = items
          .where((TheaterCase item) => item.normalizedStage == stage)
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
      return Result<TheaterCase>.success(_inTheaterCase);
    }
    final TheaterCase match = cases.firstWhere(
      (TheaterCase item) => item.id == id || item.effectiveDisplayId == id,
      orElse: () => cases.first,
    );
    return Result<TheaterCase>.success(match);
  });
}
