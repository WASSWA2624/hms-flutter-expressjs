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
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_panel.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockTheaterRepository extends Mock implements TheaterRepository {}

const TheaterCase _scheduledCase = TheaterCase(
  id: 'TC-SCH',
  displayId: 'TC-SCH',
  patientDisplayName: 'Sam Scheduled',
  status: 'SCHEDULED',
  workflowStage: 'PRE_OP',
  checklistTotal: 2,
  checklistCompleted: 1,
);

const TheaterCase _readyScheduledCase = TheaterCase(
  id: 'TC-SCH-READY',
  displayId: 'TC-SCH-READY',
  patientDisplayName: 'Pat Ready',
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

AppListTable<TheaterCase> _table(WidgetTester tester) =>
    tester.widget<AppListTable<TheaterCase>>(
      find.byType(AppListTable<TheaterCase>),
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

  group('TheaterScheduledAtomPermissions helpers', () {
    test('reuses Theater Scheduled requirements (no second vocabulary)', () {
      expect(
        TheaterScheduledAtomPermissions.tab,
        same(theaterWorkspaceReadRequirement),
      );
      expect(
        TheaterScheduledAtomPermissions.write,
        same(theaterClinicalWriteRequirement),
      );
      expect(
        TheaterScheduledAtomPermissions.scheduleCase,
        same(theaterScheduleCaseRequirement),
      );
      expect(
        TheaterScheduledAtomPermissions.success,
        same(theaterClinicalWriteRequirement),
      );
      expect(
        TheaterScheduledAtomPermissions.validation,
        same(theaterClinicalWriteRequirement),
      );
      expect(
        theaterBoardTabRequirement(TheaterSection.scheduled),
        same(TheaterScheduledAtomPermissions.tab),
      );
      expect(
        theaterWriteRequirementForSection(TheaterSection.scheduled),
        same(TheaterScheduledAtomPermissions.write),
      );
      expect(
        theaterDetailReadRequirement(TheaterSection.scheduled),
        same(TheaterScheduledAtomPermissions.detail),
      );
      expect(
        TheaterScheduledAtomPermissions.routeEntry,
        same(theaterWorkspaceEntryRequirement),
      );
      expect(
        TheaterScheduledAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.theaterEntry),
      );
      expect(
        TheaterScheduledAtomPermissions.routeEntryUnion,
        same(theaterWorkspaceRouteUnionRequirement),
      );
      expect(
        TheaterScheduledAtomPermissions.billingHolds,
        same(theaterBillingHoldReadRequirement),
      );
      expect(
        TheaterScheduledAtomPermissions.roomContext,
        same(theaterRoomContextReadRequirement),
      );
      expect(theaterRouteEntryMatchesAppRoutes(), isTrue);
    });

    test('∩ denial: missing clinical:write hides Scheduled write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(TheaterScheduledAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(TheaterScheduledAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        TheaterScheduledAtomPermissions.scheduleCase.isAllowed(reader),
        isFalse,
      );
      expect(
        TheaterScheduledAtomPermissions.nextActionUpdateReadiness.isAllowed(
          reader,
        ),
        isFalse,
      );
      expect(
        TheaterScheduledAtomPermissions.nextActionStartCase.isAllowed(reader),
        isFalse,
      );
      expect(
        TheaterScheduledAtomPermissions.cancelCase.isAllowed(reader),
        isFalse,
      );
      expect(canWriteTheaterScheduled(reader), isFalse);
      expect(
        theaterBoardShowsNextActionColumn(reader, TheaterSection.scheduled),
        isFalse,
      );
    });

    test(
      '∩ denial: patient:write alone does not unlock Scheduled mutations',
      () {
        final AppAccessPolicy patientWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.patientWrite,
          },
          roles: const <String>['RECEPTIONIST'],
        );
        expect(
          TheaterScheduledAtomPermissions.tab.isAllowed(patientWriter),
          isTrue,
        );
        expect(
          TheaterScheduledAtomPermissions.write.isAllowed(patientWriter),
          isFalse,
        );
        expect(canWriteTheaterScheduled(patientWriter), isFalse);
      },
    );

    test('write ∩ presence: clinical:write + module allows mutations', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(TheaterScheduledAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        TheaterScheduledAtomPermissions.nextAction.isAllowed(writer),
        isTrue,
      );
      expect(
        TheaterScheduledAtomPermissions.updateReadiness.isAllowed(writer),
        isTrue,
      );
      expect(
        TheaterScheduledAtomPermissions.startCase.isAllowed(writer),
        isTrue,
      );
      expect(
        TheaterScheduledAtomPermissions.panelDeepLink.isAllowed(writer),
        isTrue,
      );
      expect(canWriteTheaterScheduled(writer), isTrue);
      expect(
        theaterBoardShowsNextActionColumn(writer, TheaterSection.scheduled),
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

    test('∪ allowance: clinical:read alone satisfies Scheduled read', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(TheaterScheduledAtomPermissions.tab.isAllowed(clinical), isTrue);
      expect(
        TheaterScheduledAtomPermissions.search.isAllowed(clinical),
        isTrue,
      );
      expect(canViewTheaterScheduled(clinical), isTrue);
      expect(canReadTheaterScheduled(clinical), isTrue);
    });

    test('∪ allowance: patient:read alone satisfies Scheduled read', () {
      final AppAccessPolicy patient = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
        roles: const <String>['RECEPTIONIST'],
      );
      expect(TheaterScheduledAtomPermissions.tab.isAllowed(patient), isTrue);
      expect(TheaterScheduledAtomPermissions.loading.isAllowed(patient), isTrue);
      expect(TheaterScheduledAtomPermissions.empty.isAllowed(patient), isTrue);
      expect(TheaterScheduledAtomPermissions.write.isAllowed(patient), isFalse);
      expect(canViewTheaterTab(patient, TheaterSection.scheduled), isTrue);
    });

    test(
      'route entry ∪: billing:read satisfies routeEntryUnion, not Scheduled tab',
      () {
        final AppAccessPolicy entryOnly = _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        );
        expect(
          TheaterScheduledAtomPermissions.routeEntryUnion.isAllowed(entryOnly),
          isTrue,
        );
        expect(
          TheaterScheduledAtomPermissions.tab.isAllowed(entryOnly),
          isFalse,
        );
        expect(canViewTheaterScheduled(entryOnly), isFalse);
        expect(
          TheaterScheduledAtomPermissions.catalogEntry.isAllowed(entryOnly),
          isFalse,
        );
      },
    );

    test('subscription strips Scheduled when theatre-anesthesia inactive', () {
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
      expect(TheaterScheduledAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(TheaterScheduledAtomPermissions.write.isAllowed(noModule), isFalse);
      expect(canViewTheaterScheduled(noModule), isFalse);
    });

    test(
      'ABAC: missing facility still allows Scheduled chrome '
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
        expect(TheaterScheduledAtomPermissions.tab.isAllowed(noFacility), isTrue);
        expect(
          TheaterScheduledAtomPermissions.write.isAllowed(noFacility),
          isTrue,
        );
      },
    );

    test(
      'nested cross-module _(n/a)_: Scheduled write does not grant billing',
      () {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        );
        expect(TheaterScheduledAtomPermissions.write.isAllowed(writer), isTrue);
        expect(writer.grants(AppPermissions.billingRead), isFalse);
        expect(
          TheaterScheduledAtomPermissions.billingHolds.isAllowed(writer),
          isFalse,
        );
        expect(
          TheaterScheduledAtomPermissions.roomContext.isAllowed(writer),
          isFalse,
        );
        final AppAccessPolicy billingOnly = _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        );
        expect(
          TheaterScheduledAtomPermissions.tab.isAllowed(billingOnly),
          isFalse,
        );
        expect(
          TheaterScheduledAtomPermissions.write.isAllowed(billingOnly),
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
        TheaterScheduledAtomPermissions.billingHolds.isAllowed(billingReader),
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
        TheaterScheduledAtomPermissions.roomContext.isAllowed(opsReader),
        isTrue,
      );
      expect(canViewTheaterRoomContext(opsReader), isTrue);
      // Core time column stays on workspace read ∪ (not operations).
      expect(
        TheaterScheduledAtomPermissions.timeColumn.isAllowed(
          _policy(permissions: <AppPermission>{AppPermissions.clinicalRead}),
        ),
        isTrue,
      );
    });
  });

  testWidgets(
    '∪ denial: without clinical:read or patient:read, Scheduled absent',
    (WidgetTester tester) async {
      await _pumpScheduledTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        ),
      );

      expect(_tab('Scheduled'), findsNothing);
      expect(find.text('Sam Scheduled'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expect(_toolbarPrimary('Schedule case'), findsNothing);
      // Every board tab is read-gated; the strip collapses entirely.
      expect(find.byType(AppTabStrip), findsNothing);
      expect(_tab('Recovery'), findsNothing);
    },
  );

  testWidgets(
    'authorized read ∪: clinical:read mounts list; write actions absent',
    (WidgetTester tester) async {
      await _pumpScheduledTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      expect(_tab('Scheduled'), findsOneWidget);
      expect(find.text('Sam Scheduled'), findsOneWidget);
      expect(_toolbarPrimary('Schedule case'), findsNothing);
      expect(
        find.widgetWithText(AppButton, 'Update readiness'),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Sam Scheduled'));
      await _pumpAfterAction(tester);

      expect(find.text('CASE DETAIL'), findsOneWidget);
      expect(find.byType(AppQuickActions), findsNothing);
      expect(find.text('Reschedule'), findsNothing);
      expect(find.text('Cancel case'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∪ allowance: patient:read mounts Scheduled; write actions absent',
    (WidgetTester tester) async {
      await _pumpScheduledTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          roles: const <String>['RECEPTIONIST'],
        ),
      );

      expect(_tab('Scheduled'), findsOneWidget);
      expect(find.text('Sam Scheduled'), findsOneWidget);
      expect(_toolbarPrimary('Schedule case'), findsNothing);
      expect(
        find.widgetWithText(AppButton, 'Update readiness'),
        findsNothing,
      );

      await tester.tap(find.text('Sam Scheduled'));
      await _pumpAfterAction(tester);

      expect(find.byType(AppQuickActions), findsNothing);
      expect(find.text('Cancel case'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Schedule case / next-action / detail Quick Actions mount',
    (WidgetTester tester) async {
      await _pumpScheduledTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      expect(find.text('Sam Scheduled'), findsOneWidget);
      expect(_toolbarPrimary('Schedule case'), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, 'Update readiness'),
        findsOneWidget,
      );

      await tester.tap(find.text('Sam Scheduled'));
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
      // Next-action Update readiness is omitted from Quick Actions when
      // opened from a row.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Update readiness'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'nested billing holds panel absent in Scheduled Schedule dialog '
    'without billing:read',
    (WidgetTester tester) async {
      await _pumpScheduledTab(
        tester,
        theaterRepository: theaterRepository,
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
    'nested billing holds panel mounts in Scheduled Schedule dialog '
    'with billing:read',
    (WidgetTester tester) async {
      await _pumpScheduledTab(
        tester,
        theaterRepository: theaterRepository,
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
    'ready case shows Start case next-action for writers only',
    (WidgetTester tester) async {
      _stubTheater(
        theaterRepository,
        cases: const <TheaterCase>[_readyScheduledCase],
      );

      await _pumpScheduledTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      expect(find.widgetWithText(AppButton, 'Start case'), findsOneWidget);
    },
  );

  testWidgets(
    'authorized Update readiness next-action syncs after save',
    (WidgetTester tester) async {
      when(
        () => theaterRepository.toggleChecklistItem(any(), any()),
      ).thenAnswer(
        (_) async => Result<TheaterCase>.success(
          TheaterCase(
            id: _scheduledCase.id,
            displayId: _scheduledCase.displayId,
            patientDisplayName: _scheduledCase.patientDisplayName,
            status: 'SCHEDULED',
            workflowStage: 'PRE_OP',
            checklistTotal: 2,
            checklistCompleted: 2,
          ),
        ),
      );

      await _pumpScheduledTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      final Finder readiness = find.widgetWithText(
        AppButton,
        'Update readiness',
      );
      await tester.ensureVisible(readiness);
      await tester.tap(readiness);
      await _pumpAfterAction(tester);

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('CASE DETAIL'), findsNothing);

      final Finder dialogFields = find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(TextField),
      );
      expect(dialogFields, findsWidgets);
      // First TextField is the phase dropdown's inner field; the required
      // item-code field is the second.
      await tester.enterText(dialogFields.at(1), 'WHO-SIGN-IN');
      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.widgetWithText(AppButton, 'Update readiness'),
        ),
      );
      await _pumpAfterAction(tester);

      verify(
        () => theaterRepository.toggleChecklistItem(any(), any()),
      ).called(1);
      expect(find.textContaining('Theater changes saved'), findsWidgets);
    },
  );

  testWidgets(
    'authorized validation feedback remains on cancel without reason',
    (WidgetTester tester) async {
      await _pumpScheduledTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      await tester.tap(find.text('Sam Scheduled'));
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

  testWidgets('error / retry state remains for authorized Scheduled users', (
    WidgetTester tester,
  ) async {
    when(() => theaterRepository.listCases(any())).thenAnswer(
      (_) async => const Result<AppPage<TheaterCase>>.failure(NetworkFailure()),
    );

    await _pumpScheduledTab(
      tester,
      theaterRepository: theaterRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      ),
    );

    expect(find.textContaining('Try again'), findsWidgets);
    expect(find.widgetWithText(AppButton, 'Update readiness'), findsNothing);
    expect(_toolbarPrimary('Schedule case'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('empty state remains for authorized Scheduled users', (
    WidgetTester tester,
  ) async {
    _stubTheater(theaterRepository, cases: const <TheaterCase>[]);

    await _pumpScheduledTab(
      tester,
      theaterRepository: theaterRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      ),
    );

    expect(find.text('No theater cases'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Update readiness'), findsNothing);
    expect(_toolbarPrimary('Schedule case'), findsNothing);
  });

  testWidgets('authorized loading chrome remains observable on Scheduled', (
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
      initialLocation: '/theater?section=scheduled',
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
    expect(find.widgetWithText(AppButton, 'Update readiness'), findsNothing);
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
    expect(find.text('Sam Scheduled'), findsOneWidget);
  });

  testWidgets('mobile viewport: authorized Scheduled list remains usable', (
    WidgetTester tester,
  ) async {
    await _pumpScheduledTab(
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

    expect(_tab('Scheduled'), findsOneWidget);
    expect(find.byType(AppListTableMobileItem), findsWidgets);
    expect(find.textContaining('Sam'), findsWidgets);
    expect(
      find.widgetWithText(AppButton, 'Update readiness'),
      findsOneWidget,
    );
  });

  testWidgets('desktop viewport: authorized Scheduled chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpScheduledTab(
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

    expect(find.text('Sam Scheduled'), findsOneWidget);
    expect(_tab('Scheduled'), findsOneWidget);
    expect(_toolbarPrimary('Schedule case'), findsOneWidget);
  });

  testWidgets('light theme: authorized Scheduled chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpScheduledTab(
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

    expect(find.text('Sam Scheduled'), findsOneWidget);
    expect(_tab('Scheduled'), findsOneWidget);
  });

  testWidgets('dark theme: authorized Scheduled chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpScheduledTab(
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

    expect(find.text('Sam Scheduled'), findsOneWidget);
    expect(_tab('Scheduled'), findsOneWidget);
  });

  testWidgets(
    'deep link section=scheduled without read falls back off Scheduled',
    (WidgetTester tester) async {
      await _pumpScheduledTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        ),
        initialLocation: '/theater?section=scheduled',
      );

      expect(_tab('Scheduled'), findsNothing);
      expect(find.text('Sam Scheduled'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strips Scheduled tab when theatre-anesthesia inactive',
    (WidgetTester tester) async {
      await _pumpScheduledTab(
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

      expect(_tab('Scheduled'), findsNothing);
      expect(find.text('Sam Scheduled'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'integration: Scheduled board uses section write ∩ for next-action column',
    (WidgetTester tester) async {
      await _pumpScheduledTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      final AppListTable<TheaterCase> table = _table(tester);
      expect(table.columnVisibilityStorageKey, 'theater_scheduled');
      expect(
        table.columns.any(
          (AppListTableColumn<TheaterCase> c) => c.id == 'next_action',
        ),
        isTrue,
      );
      expect(
        table.columns.any((AppListTableColumn<TheaterCase> c) => c.id == 'time'),
        isTrue,
      );
    },
  );

  testWidgets(
    'integration: read-only Scheduled board omits next-action column',
    (WidgetTester tester) async {
      await _pumpScheduledTab(
        tester,
        theaterRepository: theaterRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      final AppListTable<TheaterCase> table = _table(tester);
      expect(
        table.columns.any(
          (AppListTableColumn<TheaterCase> c) => c.id == 'next_action',
        ),
        isFalse,
      );
    },
  );
}

Future<void> _pumpAfterAction(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pumpScheduledTab(
  WidgetTester tester, {
  required _MockTheaterRepository theaterRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/theater?section=scheduled',
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
    if (cases.isEmpty) {
      return const Result<TheaterCase>.success(_scheduledCase);
    }
    final TheaterCase match = cases.firstWhere(
      (TheaterCase item) => item.id == id || item.effectiveDisplayId == id,
      orElse: () => cases.first,
    );
    return Result<TheaterCase>.success(match);
  });
}
