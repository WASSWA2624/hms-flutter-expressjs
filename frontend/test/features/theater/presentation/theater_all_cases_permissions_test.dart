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
import 'package:hosspi_hms/features/theater/presentation/theater_next_action.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_panel.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockTheaterRepository extends Mock implements TheaterRepository {}

const TheaterCase _scheduledCase = TheaterCase(
  id: 'TC-ALL-1',
  displayId: 'TC-ALL-1',
  patientDisplayName: 'All Cases Patient',
  status: 'SCHEDULED',
  workflowStage: 'PRE_OP',
  checklistTotal: 2,
);

const TheaterCase _readyScheduledCase = TheaterCase(
  id: 'TC-ALL-READY',
  displayId: 'TC-ALL-READY',
  patientDisplayName: 'All Ready Patient',
  status: 'SCHEDULED',
  workflowStage: 'PRE_OP',
  checklistTotal: 2,
  checklistCompleted: 2,
);

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

Finder _toolbarPrimary(String label) => find.descendant(
  of: find.byType(AppTabToolbarPrimary),
  matching: find.text(label),
);

AppListTable<TheaterCase> _table(WidgetTester tester) {
  return tester.widget<AppListTable<TheaterCase>>(
    find.byType(AppListTable<TheaterCase>),
  );
}

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
  late _MockTheaterRepository repository;

  setUpAll(() {
    registerFallbackValue(const TheaterCaseQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockTheaterRepository();
    _stubCases(repository);
  });

  group('TheaterAllAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(TheaterAllAtomPermissions.tab, same(theaterWorkspaceReadRequirement));
      expect(TheaterAllAtomPermissions.read, same(theaterWorkspaceReadRequirement));
      expect(
        TheaterAllAtomPermissions.listChrome,
        same(theaterWorkspaceReadRequirement),
      );
      expect(TheaterAllAtomPermissions.search, same(theaterWorkspaceReadRequirement));
      expect(TheaterAllAtomPermissions.filters, same(theaterWorkspaceReadRequirement));
      expect(
        TheaterAllAtomPermissions.settings,
        same(theaterWorkspaceReadRequirement),
      );
      expect(TheaterAllAtomPermissions.empty, same(theaterWorkspaceReadRequirement));
      expect(
        TheaterAllAtomPermissions.loading,
        same(theaterWorkspaceReadRequirement),
      );
      expect(TheaterAllAtomPermissions.retry, same(theaterWorkspaceReadRequirement));
      expect(TheaterAllAtomPermissions.detail, same(theaterWorkspaceReadRequirement));
      expect(
        TheaterAllAtomPermissions.write,
        same(theaterClinicalWriteRequirement),
      );
      expect(
        TheaterAllAtomPermissions.create,
        same(theaterClinicalWriteRequirement),
      );
      expect(
        TheaterAllAtomPermissions.update,
        same(theaterClinicalWriteRequirement),
      );
      expect(
        TheaterAllAtomPermissions.delete,
        same(theaterWorkspaceDeleteRequirement),
      );
      expect(
        TheaterAllAtomPermissions.scheduleCase,
        same(theaterScheduleCaseRequirement),
      );
      expect(
        TheaterAllAtomPermissions.nextAction,
        same(theaterClinicalWriteRequirement),
      );
      expect(
        TheaterAllAtomPermissions.billingHolds,
        same(theaterBillingHoldReadRequirement),
      );
      expect(
        TheaterAllAtomPermissions.roomContext,
        same(theaterRoomContextReadRequirement),
      );
      expect(
        TheaterAllAtomPermissions.roomColumn,
        same(theaterWorkspaceReadRequirement),
      );
      expect(
        TheaterAllAtomPermissions.navigation,
        same(theaterNavigationRequirement),
      );
      expect(
        TheaterAllAtomPermissions.nestedWrite,
        same(theaterClinicalWriteRequirement),
      );
      expect(
        TheaterAllAtomPermissions.nestedRead,
        same(theaterWorkspaceReadRequirement),
      );
      expect(
        TheaterAllAtomPermissions.panelDeepLink,
        same(theaterClinicalWriteRequirement),
      );
      expect(
        TheaterAllAtomPermissions.routeEntry,
        same(theaterWorkspaceEntryRequirement),
      );
      expect(
        TheaterAllAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.theaterEntry),
      );
      expect(
        TheaterAllAtomPermissions.appRoutesEntry,
        same(theaterWorkspaceRouteUnionRequirement),
      );
      expect(
        theaterBoardTabRequirement(TheaterSection.all),
        same(TheaterAllAtomPermissions.tab),
      );
      expect(
        theaterWriteRequirementForSection(TheaterSection.all),
        same(TheaterAllAtomPermissions.write),
      );
      expect(
        theaterDetailReadRequirement(TheaterSection.all),
        same(TheaterAllAtomPermissions.detail),
      );
      expect(theaterRouteEntryMatchesAppRoutes(), isTrue);
      expect(theaterAppRoutesEntryMatchesAppRoutes(), isTrue);
    });

    test('∩ denial: missing clinical:write hides All-cases write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(TheaterAllAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(TheaterAllAtomPermissions.write.isAllowed(reader), isFalse);
      expect(TheaterAllAtomPermissions.scheduleCase.isAllowed(reader), isFalse);
      expect(TheaterAllAtomPermissions.nextAction.isAllowed(reader), isFalse);
      expect(TheaterAllAtomPermissions.cancelCase.isAllowed(reader), isFalse);
      expect(TheaterAllAtomPermissions.success.isAllowed(reader), isFalse);
      expect(canWriteTheater(reader), isFalse);
      expect(canScheduleTheaterCase(reader), isFalse);
      expect(
        theaterBoardShowsNextActionColumn(reader, TheaterSection.all),
        isFalse,
      );
    });

    test(
      '∩ denial: patient:write alone does not unlock All-cases mutations',
      () {
        final AppAccessPolicy patientWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.patientWrite,
          },
          roles: const <String>['RECEPTIONIST'],
        );
        expect(TheaterAllAtomPermissions.tab.isAllowed(patientWriter), isTrue);
        expect(
          TheaterAllAtomPermissions.write.isAllowed(patientWriter),
          isFalse,
        );
        expect(canWriteTheater(patientWriter), isFalse);
      },
    );

    test('write ∩ presence: clinical:write + module allows mutations', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(TheaterAllAtomPermissions.write.isAllowed(writer), isTrue);
      expect(TheaterAllAtomPermissions.scheduleCase.isAllowed(writer), isTrue);
      expect(
        TheaterAllAtomPermissions.nextActionStartCase.isAllowed(writer),
        isTrue,
      );
      expect(TheaterAllAtomPermissions.reschedule.isAllowed(writer), isTrue);
      expect(canWriteTheater(writer), isTrue);
      expect(canScheduleTheaterCase(writer), isTrue);
      expect(
        theaterBoardShowsNextActionColumn(writer, TheaterSection.all),
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

    test('∪ allowance: clinical:read alone satisfies All-cases read', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(TheaterAllAtomPermissions.tab.isAllowed(clinical), isTrue);
      expect(TheaterAllAtomPermissions.search.isAllowed(clinical), isTrue);
      expect(canViewTheaterAll(clinical), isTrue);
      expect(canReadTheater(clinical), isTrue);
    });

    test('∪ allowance: patient:read alone satisfies All-cases read', () {
      final AppAccessPolicy patient = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
        roles: const <String>['RECEPTIONIST'],
      );
      expect(TheaterAllAtomPermissions.tab.isAllowed(patient), isTrue);
      expect(TheaterAllAtomPermissions.loading.isAllowed(patient), isTrue);
      expect(TheaterAllAtomPermissions.empty.isAllowed(patient), isTrue);
      expect(TheaterAllAtomPermissions.write.isAllowed(patient), isFalse);
      expect(canViewTheaterTab(patient, TheaterSection.all), isTrue);
    });

    test(
      'route entry ∪: billing:read satisfies appRoutesEntry, not All tab',
      () {
        final AppAccessPolicy entryOnly = _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        );
        expect(
          TheaterAllAtomPermissions.appRoutesEntry.isAllowed(entryOnly),
          isTrue,
        );
        expect(TheaterAllAtomPermissions.tab.isAllowed(entryOnly), isFalse);
        expect(canViewTheaterAll(entryOnly), isFalse);
        expect(
          TheaterAllAtomPermissions.catalogEntry.isAllowed(entryOnly),
          isFalse,
        );
      },
    );

    test(
      'subscription strips All cases when theatre-anesthesia inactive',
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
        expect(TheaterAllAtomPermissions.tab.isAllowed(noModule), isFalse);
        expect(TheaterAllAtomPermissions.write.isAllowed(noModule), isFalse);
        expect(canViewTheaterAll(noModule), isFalse);
      },
    );

    test(
      'ABAC: missing facility still allows All chrome '
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
        expect(TheaterAllAtomPermissions.tab.isAllowed(noFacility), isTrue);
        expect(TheaterAllAtomPermissions.write.isAllowed(noFacility), isTrue);
      },
    );

    test(
      'nested cross-module _(n/a)_: theater write does not grant billing',
      () {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        );
        expect(TheaterAllAtomPermissions.write.isAllowed(writer), isTrue);
        expect(writer.grants(AppPermissions.billingRead), isFalse);
        expect(
          TheaterAllAtomPermissions.billingHolds.isAllowed(writer),
          isFalse,
        );
        expect(
          TheaterAllAtomPermissions.operationsRead.isAllowed(writer),
          isFalse,
        );
        final AppAccessPolicy billingWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.billingRead,
          },
        );
        expect(
          TheaterAllAtomPermissions.billingHolds.isAllowed(billingWriter),
          isTrue,
        );
      },
    );

    test('next-action kinds map to All write ∩', () {
      expect(
        theaterResolveNextActionKind(_scheduledCase),
        TheaterNextActionKind.updateReadiness,
      );
      expect(
        theaterResolveNextActionKind(_readyScheduledCase),
        TheaterNextActionKind.startCase,
      );
      expect(
        theaterNextActionRequirement(TheaterNextActionKind.updateReadiness),
        same(TheaterAllAtomPermissions.nextActionUpdateReadiness),
      );
      expect(
        theaterNextActionRequirement(TheaterNextActionKind.startCase),
        same(TheaterAllAtomPermissions.nextActionStartCase),
      );
      expect(
        theaterFocusedPanelRequirement(TheaterDetailPanel.checklist),
        same(theaterClinicalWriteRequirement),
      );
    });
  });

  testWidgets(
    '∪ denial: without clinical:read or patient:read, All cases absent',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        ),
      );

      expect(_tab('All cases'), findsNothing);
      expect(_tab('In theater'), findsNothing);
      expect(_tab('Scheduled'), findsNothing);
      expect(_toolbarPrimary('Schedule case'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      // Every board tab is read-gated; the strip collapses entirely.
      expect(find.byType(AppTabStrip), findsNothing);
      expect(_tab('Recovery'), findsNothing);
    },
  );

  testWidgets(
    'authorized read ∪: clinical:read mounts list; write actions absent',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      expect(_tab('All cases'), findsOneWidget);
      expect(find.byType(AppListTable<TheaterCase>), findsOneWidget);
      expect(find.text('All Cases Patient'), findsOneWidget);
      expect(_toolbarPrimary('Schedule case'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Update readiness'), findsNothing);
      expect(_table(tester).columnVisibilityStorageKey, 'theater_all');
      expect(_table(tester).search?.filterGroups.length, 2);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('All Cases Patient'));
      await _pumpAfterAction(tester);

      expect(find.text('CASE DETAIL'), findsOneWidget);
      expect(find.byType(AppQuickActions), findsNothing);
      expect(find.text('Reschedule'), findsNothing);
      expect(find.text('Cancel case'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∪ allowance: patient:read mounts All cases; write actions absent',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          roles: const <String>['RECEPTIONIST'],
        ),
      );

      expect(_tab('All cases'), findsOneWidget);
      expect(find.text('All Cases Patient'), findsOneWidget);
      expect(_toolbarPrimary('Schedule case'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Update readiness'), findsNothing);

      await tester.tap(find.text('All Cases Patient'));
      await _pumpAfterAction(tester);

      expect(find.byType(AppQuickActions), findsNothing);
      expect(find.text('Reschedule'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Schedule case / next-action / detail mutations mount',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      expect(find.text('All Cases Patient'), findsOneWidget);
      expect(_toolbarPrimary('Schedule case'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Update readiness'), findsWidgets);

      await tester.tap(find.text('All Cases Patient'));
      await _pumpAfterAction(tester);

      expect(find.byType(AppQuickActions), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Update readiness'),
        ),
        findsNothing,
      );
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
    },
  );

  testWidgets(
    'nested billing holds panel absent in Schedule dialog without '
    'billing:read',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      await tester.tap(_toolbarPrimary('Schedule case'));
      await _pumpAfterAction(tester);

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.byType(ClinicalRequestBillingPanel), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested billing holds panel mounts in Schedule dialog with billing:read',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.billingRead,
          },
        ),
      );

      await tester.tap(_toolbarPrimary('Schedule case'));
      await _pumpAfterAction(tester);

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.byType(ClinicalRequestBillingPanel), findsOneWidget);
    },
  );

  testWidgets(
    'authorized Start case next-action syncs stage after confirm',
    (WidgetTester tester) async {
      _stubCases(repository, cases: const <TheaterCase>[_readyScheduledCase]);
      when(() => repository.updateStage(any(), any())).thenAnswer((
        Invocation invocation,
      ) async {
        final Map<String, Object?> payload =
            invocation.positionalArguments[1] as Map<String, Object?>;
        return Result<TheaterCase>.success(
          TheaterCase(
            id: _readyScheduledCase.id,
            displayId: _readyScheduledCase.displayId,
            patientDisplayName: _readyScheduledCase.patientDisplayName,
            status: payload['status'] as String? ?? 'IN_PROGRESS',
            workflowStage:
                payload['workflow_stage'] as String? ?? 'SIGN_IN',
            checklistTotal: 2,
            checklistCompleted: 2,
          ),
        );
      });

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      final Finder startCase = find.widgetWithText(AppButton, 'Start case');
      await tester.ensureVisible(startCase);
      await tester.tap(startCase);
      await _pumpAfterAction(tester);

      expect(find.byType(AppDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Start case').last);
      await _pumpAfterAction(tester);

      verify(() => repository.updateStage(any(), any())).called(1);
      expect(find.textContaining('Theater changes saved'), findsWidgets);
    },
  );

  testWidgets(
    'panel=checklist deep link opens readiness only when write ∩ allowed',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
        initialLocation: '/theater?id=TC-ALL-1&panel=checklist',
      );

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('UPDATE READINESS'), findsOneWidget);
      expect(find.text('CASE DETAIL'), findsNothing);
    },
  );

  testWidgets(
    'panel=checklist deep link skipped for read-only (opens detail instead)',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        initialLocation: '/theater?id=TC-ALL-1&panel=checklist',
      );

      expect(find.text('CASE DETAIL'), findsOneWidget);
      expect(find.text('UPDATE READINESS'), findsNothing);
      expect(find.byType(AppQuickActions), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('error / retry state remains for authorized All-cases users', (
    WidgetTester tester,
  ) async {
    when(() => repository.listCases(any())).thenAnswer(
      (_) async => const Result<AppPage<TheaterCase>>.failure(NetworkFailure()),
    );

    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      ),
    );

    expect(find.textContaining('Try again'), findsWidgets);
    expect(_toolbarPrimary('Schedule case'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('empty state remains for authorized All-cases users', (
    WidgetTester tester,
  ) async {
    _stubCases(repository, cases: const <TheaterCase>[]);

    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      ),
    );

    expect(find.text('No theater cases'), findsOneWidget);
    expect(_toolbarPrimary('Schedule case'), findsNothing);
    expect(find.widgetWithText(AppButton, 'Update readiness'), findsNothing);
  });

  testWidgets(
    'authorized loading chrome remains observable on All cases',
    (WidgetTester tester) async {
      final Completer<Result<AppPage<TheaterCase>>> listCompleter =
          Completer<Result<AppPage<TheaterCase>>>();
      when(() => repository.listCases(any())).thenAnswer(
        (_) => listCompleter.future,
      );

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/theater',
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
            theaterRepositoryProvider.overrideWithValue(repository),
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
      expect(_toolbarPrimary('Schedule case'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      listCompleter.complete(
        const Result<AppPage<TheaterCase>>.success(
          AppPage<TheaterCase>(
            items: <TheaterCase>[_scheduledCase],
            request: AppPageRequest(pageSize: 12),
            totalItemCount: 1,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('All Cases Patient'), findsOneWidget);
    },
  );

  testWidgets('mobile viewport: authorized All cases list remains usable', (
    WidgetTester tester,
  ) async {
    // Read-only avoids next-action width overflow on narrow layouts.
    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      ),
      physicalSize: const Size(390, 844),
    );

    expect(_tab('All cases'), findsOneWidget);
    expect(find.byType(AppListTableMobileItem), findsWidgets);
    expect(find.textContaining('All Cases'), findsWidgets);
    expect(find.widgetWithText(AppButton, 'Update readiness'), findsNothing);
  });

  testWidgets('desktop viewport: authorized All cases chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
    );

    expect(find.text('All Cases Patient'), findsOneWidget);
    expect(_tab('All cases'), findsOneWidget);
    expect(_toolbarPrimary('Schedule case'), findsOneWidget);
  });

  testWidgets('light theme: authorized All cases chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
    );

    expect(find.text('All Cases Patient'), findsOneWidget);
    expect(_tab('All cases'), findsOneWidget);
  });

  testWidgets('dark theme: authorized All cases chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
      themeMode: ThemeMode.dark,
    );

    expect(find.text('All Cases Patient'), findsOneWidget);
    expect(_tab('All cases'), findsOneWidget);
  });

  testWidgets(
    'deep link section=all without read falls back off All cases',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        ),
        initialLocation: '/theater?section=all',
      );

      expect(_tab('All cases'), findsNothing);
      // Every board tab is read-gated; no fallback board mounts.
      expect(_tab('Scheduled'), findsNothing);
      expect(_tab('Recovery'), findsNothing);
      expect(find.byType(AppListTable<TheaterCase>), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strips All cases tab when theatre-anesthesia inactive',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
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

      expect(_tab('All cases'), findsNothing);
      expect(_tab('In theater'), findsNothing);
      expect(_toolbarPrimary('Schedule case'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      // Inactive module strips every board tab; the strip collapses.
      expect(find.byType(AppTabStrip), findsNothing);
    },
  );

  testWidgets(
    'integration: All cases default board uses theater_all storage key',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      expect(_table(tester).columnVisibilityStorageKey, 'theater_all');
      expect(_table(tester).search?.filterGroups.length, 2);
      expect(
        theaterAllowedBoardSections(
          _policy(
            permissions: <AppPermission>{AppPermissions.clinicalRead},
          ),
        ),
        contains(TheaterSection.all),
      );
    },
  );
}

Future<void> _pumpAfterAction(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pumpAllTab(
  WidgetTester tester, {
  required _MockTheaterRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/theater',
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
        theaterRepositoryProvider.overrideWithValue(repository),
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

void _stubCases(
  _MockTheaterRepository repository, {
  List<TheaterCase> cases = const <TheaterCase>[_scheduledCase],
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
  when(() => repository.searchSchedulePatients(any())).thenAnswer(
    (_) async => const Result<List<TheaterSchedulePatient>>.success(
      <TheaterSchedulePatient>[],
    ),
  );
  when(() => repository.getCase(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final String id = invocation.positionalArguments.single as String;
    final TheaterCase match = cases.firstWhere(
      (TheaterCase item) => item.id == id || item.effectiveDisplayId == id,
      orElse: () => cases.isEmpty ? _scheduledCase : cases.first,
    );
    return Result<TheaterCase>.success(match);
  });
}
