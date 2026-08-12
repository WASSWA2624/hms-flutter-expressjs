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
import 'package:hosspi_hms/features/reception/data/reception_follow_up_repository.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/features/theater/data/repositories/theater_repository_impl.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/features/theater/domain/repositories/theater_repository.dart';
import 'package:hosspi_hms/features/theater/presentation/pages/theater_workspace_page.dart';
import 'package:hosspi_hms/features/theater/presentation/theater_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/follow_up_worklist_panel.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockTheaterRepository extends Mock implements TheaterRepository {}

class _MockFollowUpRepository extends Mock
    implements ReceptionFollowUpRepository {}

final ReceptionFollowUpEntry _followUp = ReceptionFollowUpEntry(
  id: 'fu-theater-1',
  encounterId: 'enc-1',
  patientId: 'pat-1',
  patientIdentifier: 'PAT-FU-TH1',
  patientDisplayName: 'Follow Up Patient',
  patientPhone: '+256700000001',
  scheduledAt: DateTime.utc(2026, 7, 29, 9, 30),
  notes: 'Theatre callback',
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
  late _MockFollowUpRepository followUpRepository;

  setUpAll(() {
    registerFallbackValue(const TheaterCaseQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    theaterRepository = _MockTheaterRepository();
    followUpRepository = _MockFollowUpRepository();
    _stubTheater(theaterRepository);
    _stubFollowUps(followUpRepository);
  });

  group('TheaterFollowUpsAtomPermissions helpers', () {
    test('reuses Theater Follow-ups requirements (no second vocabulary)', () {
      expect(
        TheaterFollowUpsAtomPermissions.tab,
        same(theaterFollowUpsRequirement),
      );
      expect(
        TheaterFollowUpsAtomPermissions.write,
        same(theaterFollowUpsWriteRequirement),
      );
      expect(
        TheaterFollowUpsAtomPermissions.write,
        same(theaterClinicalWriteRequirement),
      );
      expect(
        TheaterFollowUpsAtomPermissions.success,
        same(theaterFollowUpsWriteRequirement),
      );
      expect(
        TheaterFollowUpsAtomPermissions.validation,
        same(theaterFollowUpsWriteRequirement),
      );
      expect(
        theaterBoardTabRequirement(TheaterSection.followUps),
        same(theaterFollowUpsRequirement),
      );
      expect(
        TheaterFollowUpsAtomPermissions.routeEntry,
        same(theaterWorkspaceEntryRequirement),
      );
      expect(
        TheaterFollowUpsAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.theaterEntry),
      );
      expect(
        TheaterFollowUpsAtomPermissions.routeEntryUnion,
        same(theaterWorkspaceRouteUnionRequirement),
      );
      expect(theaterRouteEntryMatchesAppRoutes(), isTrue);
    });

    test('∩ denial: missing clinical:write hides Follow-ups write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(TheaterFollowUpsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(TheaterFollowUpsAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        TheaterFollowUpsAtomPermissions.markCompleted.isAllowed(reader),
        isFalse,
      );
      expect(
        TheaterFollowUpsAtomPermissions.reschedule.isAllowed(reader),
        isFalse,
      );
      expect(TheaterFollowUpsAtomPermissions.success.isAllowed(reader), isFalse);
      expect(canWriteTheaterFollowUps(reader), isFalse);
    });

    test(
      '∩ denial: patient:write alone does not unlock Follow-ups mutations',
      () {
        final AppAccessPolicy patientWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.patientWrite,
          },
          roles: const <String>['RECEPTIONIST'],
        );
        expect(
          TheaterFollowUpsAtomPermissions.tab.isAllowed(patientWriter),
          isTrue,
        );
        expect(
          TheaterFollowUpsAtomPermissions.write.isAllowed(patientWriter),
          isFalse,
        );
        expect(canWriteTheaterFollowUps(patientWriter), isFalse);
      },
    );

    test('write ∩ presence: clinical:write + module allows mutations', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(TheaterFollowUpsAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        TheaterFollowUpsAtomPermissions.markCompleted.isAllowed(writer),
        isTrue,
      );
      expect(
        TheaterFollowUpsAtomPermissions.saveFollowUp.isAllowed(writer),
        isTrue,
      );
      expect(canWriteTheaterFollowUps(writer), isTrue);
    });

    test('mapping note: matrix ∩ clinical:write via allPermissions', () {
      expect(
        theaterFollowUpsWriteRequirement.allPermissions,
        <AppPermission>[AppPermissions.clinicalWrite],
      );
      expect(theaterFollowUpsWriteRequirement.anyPermissions, isEmpty);
      expect(
        theaterFollowUpsWriteRequirement.activeModules,
        contains(theaterTheatreAnesthesiaModule),
      );
    });

    test('∪ allowance: clinical:read alone satisfies Follow-ups read', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(TheaterFollowUpsAtomPermissions.tab.isAllowed(clinical), isTrue);
      expect(TheaterFollowUpsAtomPermissions.search.isAllowed(clinical), isTrue);
      expect(canViewTheaterFollowUps(clinical), isTrue);
      expect(canReadTheaterFollowUps(clinical), isTrue);
    });

    test('∪ allowance: patient:read alone satisfies Follow-ups read', () {
      final AppAccessPolicy patient = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
        roles: const <String>['RECEPTIONIST'],
      );
      expect(TheaterFollowUpsAtomPermissions.tab.isAllowed(patient), isTrue);
      expect(TheaterFollowUpsAtomPermissions.loading.isAllowed(patient), isTrue);
      expect(TheaterFollowUpsAtomPermissions.empty.isAllowed(patient), isTrue);
      expect(TheaterFollowUpsAtomPermissions.write.isAllowed(patient), isFalse);
      expect(
        canViewTheaterTab(patient, TheaterSection.followUps),
        isTrue,
      );
    });

    test(
      'route entry ∪: billing:read satisfies routeEntryUnion, not Follow-ups tab',
      () {
        final AppAccessPolicy entryOnly = _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        );
        expect(
          TheaterFollowUpsAtomPermissions.routeEntryUnion.isAllowed(entryOnly),
          isTrue,
        );
        expect(TheaterFollowUpsAtomPermissions.tab.isAllowed(entryOnly), isFalse);
        expect(canViewTheaterFollowUps(entryOnly), isFalse);
        expect(
          TheaterFollowUpsAtomPermissions.catalogEntry.isAllowed(entryOnly),
          isFalse,
        );
      },
    );

    test(
      'subscription strips Follow-ups when theatre-anesthesia inactive',
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
        expect(TheaterFollowUpsAtomPermissions.tab.isAllowed(noModule), isFalse);
        expect(
          TheaterFollowUpsAtomPermissions.write.isAllowed(noModule),
          isFalse,
        );
        expect(canViewTheaterFollowUps(noModule), isFalse);
      },
    );

    test(
      'ABAC: missing facility still allows Follow-ups chrome '
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
          TheaterFollowUpsAtomPermissions.tab.isAllowed(noFacility),
          isTrue,
        );
        expect(
          TheaterFollowUpsAtomPermissions.write.isAllowed(noFacility),
          isTrue,
        );
      },
    );

    test(
      'mapping note: shared panel default remains reception ∪ / front-desk write',
      () {
        final AppAccessPolicy patientReader = _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'patient-registry',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'scheduling-queue',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: theaterTheatreAnesthesiaModule,
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(receptionFollowUpsRequirement.isAllowed(patientReader), isTrue);
        expect(theaterFollowUpsRequirement.isAllowed(patientReader), isTrue);
      },
    );

    test(
      'nested cross-module _(n/a)_: Follow-ups write does not grant billing',
      () {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        );
        expect(TheaterFollowUpsAtomPermissions.write.isAllowed(writer), isTrue);
        expect(writer.grants(AppPermissions.billingRead), isFalse);
        expect(
          TheaterFollowUpsAtomPermissions.billingHold.isAllowed(writer),
          isFalse,
        );
        expect(
          TheaterFollowUpsAtomPermissions.operationsRead.isAllowed(writer),
          isFalse,
        );
        final AppAccessPolicy billingOnly = _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        );
        expect(
          TheaterFollowUpsAtomPermissions.tab.isAllowed(billingOnly),
          isFalse,
        );
        expect(
          TheaterFollowUpsAtomPermissions.write.isAllowed(billingOnly),
          isFalse,
        );
      },
    );

    test('Schedule case is not Follow-ups chrome; gate reuses write ∩', () {
      expect(
        TheaterFollowUpsAtomPermissions.scheduleCase,
        same(theaterScheduleCaseRequirement),
      );
      expect(
        TheaterFollowUpsAtomPermissions.scheduleCase,
        same(theaterClinicalWriteRequirement),
      );
    });
  });

  testWidgets(
    '∪ denial: without clinical:read or patient:read, Follow-ups absent',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        theaterRepository: theaterRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        ),
      );

      expect(_tab('Follow-ups'), findsNothing);
      expect(find.byType(FollowUpWorklistPanel), findsNothing);
      expect(find.text('Follow Up Patient'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expect(_scheduleCaseAction(), findsNothing);
      // Every board tab is read-gated; the strip collapses entirely.
      expect(find.byType(AppTabStrip), findsNothing);
    },
  );

  testWidgets(
    'authorized read ∪: clinical:read mounts list; write actions absent',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        theaterRepository: theaterRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      expect(_tab('Follow-ups'), findsOneWidget);
      expect(find.byType(FollowUpWorklistPanel), findsOneWidget);
      expect(find.text('Follow Up Patient'), findsOneWidget);
      expect(find.text('Reschedule follow-up'), findsNothing);
      expect(find.text('Mark completed'), findsNothing);
      expect(_scheduleCaseAction(), findsNothing);

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Reschedule follow-up'), findsNothing);
      expect(find.text('Mark completed'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∪ allowance: patient:read mounts Follow-ups; write actions absent',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        theaterRepository: theaterRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          roles: const <String>['RECEPTIONIST'],
        ),
      );

      expect(_tab('Follow-ups'), findsOneWidget);
      expect(find.byType(FollowUpWorklistPanel), findsOneWidget);
      expect(find.text('Follow Up Patient'), findsOneWidget);
      expect(_scheduleCaseAction(), findsNothing);

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Reschedule follow-up'), findsNothing);
      expect(find.text('Mark completed'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    },
  );

  testWidgets(
    'full write ∩: Mark completed / Reschedule mount; complete syncs list',
    (WidgetTester tester) async {
      when(
        () => followUpRepository.completeFollowUp(
          any(),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async => const Result<void>.success(null));

      await _pumpFollowUpsTab(
        tester,
        theaterRepository: theaterRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      expect(find.text('Follow Up Patient'), findsOneWidget);
      expect(_scheduleCaseAction(), findsNothing);

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Reschedule follow-up'), findsOneWidget);
      expect(find.text('Mark completed'), findsOneWidget);

      when(
        () => followUpRepository.listScheduledFollowUps(
          encounterType: any(named: 'encounterType'),
        ),
      ).thenAnswer(
        (_) async => const Result<List<ReceptionFollowUpEntry>>.success(
          <ReceptionFollowUpEntry>[],
        ),
      );

      await tester.tap(find.text('Mark completed'));
      await tester.pumpAndSettle();

      verify(
        () => followUpRepository.completeFollowUp(
          'fu-theater-1',
          notes: any(named: 'notes'),
        ),
      ).called(1);
      expect(find.text('Follow Up Patient'), findsNothing);
      expect(find.text('No scheduled follow-ups'), findsOneWidget);
    },
  );

  testWidgets(
    'reschedule entry opens Save follow-up dialog when write ∩ allowed',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        theaterRepository: theaterRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reschedule follow-up'));
      await tester.pumpAndSettle();

      expect(find.text('Save follow-up'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized reschedule shows validation feedback on submit failure',
    (WidgetTester tester) async {
      when(
        () => followUpRepository.updateFollowUp(any(), any()),
      ).thenAnswer(
        (_) async => Result<void>.failure(ValidationFailure()),
      );

      await _pumpFollowUpsTab(
        tester,
        theaterRepository: theaterRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reschedule follow-up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save follow-up'));
      await tester.pumpAndSettle();

      expect(find.text('Save follow-up'), findsOneWidget);
      expect(find.byType(AppFormInformationBanner), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('error / retry state remains for authorized Follow-ups users', (
    WidgetTester tester,
  ) async {
    when(
      () => followUpRepository.listScheduledFollowUps(
        encounterType: any(named: 'encounterType'),
      ),
    ).thenAnswer(
      (_) async => const Result<List<ReceptionFollowUpEntry>>.failure(
        NetworkFailure(),
      ),
    );

    await _pumpFollowUpsTab(
      tester,
      theaterRepository: theaterRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      ),
    );

    expect(find.text('Try again'), findsOneWidget);

    when(
      () => followUpRepository.listScheduledFollowUps(
        encounterType: any(named: 'encounterType'),
      ),
    ).thenAnswer(
      (_) async => Result<List<ReceptionFollowUpEntry>>.success(
        <ReceptionFollowUpEntry>[_followUp],
      ),
    );

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Follow Up Patient'), findsOneWidget);
  });

  testWidgets('empty state remains for authorized Follow-ups users', (
    WidgetTester tester,
  ) async {
    when(
      () => followUpRepository.listScheduledFollowUps(
        encounterType: any(named: 'encounterType'),
      ),
    ).thenAnswer(
      (_) async => const Result<List<ReceptionFollowUpEntry>>.success(
        <ReceptionFollowUpEntry>[],
      ),
    );

    await _pumpFollowUpsTab(
      tester,
      theaterRepository: theaterRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      ),
    );

    expect(find.text('No scheduled follow-ups'), findsOneWidget);
    expect(find.text('Mark completed'), findsNothing);
  });

  testWidgets(
    'authorized loading chrome remains observable on Follow-ups',
    (WidgetTester tester) async {
      final Completer<Result<List<ReceptionFollowUpEntry>>> listCompleter =
          Completer<Result<List<ReceptionFollowUpEntry>>>();
      when(
        () => followUpRepository.listScheduledFollowUps(
          encounterType: any(named: 'encounterType'),
        ),
      ).thenAnswer((_) => listCompleter.future);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/theater?section=follow-ups',
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
            receptionFollowUpRepositoryProvider.overrideWithValue(
              followUpRepository,
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

      expect(_tab('Follow-ups'), findsOneWidget);
      expect(find.byType(FollowUpWorklistPanel), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Mark completed'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      listCompleter.complete(
        Result<List<ReceptionFollowUpEntry>>.success(
          <ReceptionFollowUpEntry>[_followUp],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Follow Up Patient'), findsOneWidget);
    },
  );

  testWidgets('mobile viewport: authorized Follow-ups list remains usable', (
    WidgetTester tester,
  ) async {
    await _pumpFollowUpsTab(
      tester,
      theaterRepository: theaterRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
      physicalSize: const Size(390, 844),
    );

    expect(_tab('Follow-ups'), findsOneWidget);
    expect(find.byType(FollowUpWorklistPanel), findsOneWidget);
    expect(find.textContaining('Follow Up'), findsWidgets);
  });

  testWidgets('desktop viewport: authorized Follow-ups chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpFollowUpsTab(
      tester,
      theaterRepository: theaterRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
    );

    expect(find.text('Follow Up Patient'), findsOneWidget);
    expect(_tab('Follow-ups'), findsOneWidget);
  });

  testWidgets('light theme: authorized Follow-ups chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpFollowUpsTab(
      tester,
      theaterRepository: theaterRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
    );

    expect(find.text('Follow Up Patient'), findsOneWidget);
    expect(_tab('Follow-ups'), findsOneWidget);
  });

  testWidgets('dark theme: authorized Follow-ups chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpFollowUpsTab(
      tester,
      theaterRepository: theaterRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
      themeMode: ThemeMode.dark,
    );

    expect(find.text('Follow Up Patient'), findsOneWidget);
    expect(_tab('Follow-ups'), findsOneWidget);
  });

  testWidgets(
    'deep link section=follow-ups without read falls back off Follow-ups',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        theaterRepository: theaterRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        ),
      );

      expect(_tab('Follow-ups'), findsNothing);
      expect(find.byType(FollowUpWorklistPanel), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strips Follow-ups tab when theatre-anesthesia inactive',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        theaterRepository: theaterRepository,
        followUpRepository: followUpRepository,
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

      expect(_tab('Follow-ups'), findsNothing);
      expect(find.byType(FollowUpWorklistPanel), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'integration: panel receives Theater Follow-ups atom requirements',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        theaterRepository: theaterRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      final FollowUpWorklistPanel panel = tester.widget<FollowUpWorklistPanel>(
        find.byType(FollowUpWorklistPanel),
      );
      expect(panel.readRequirement, same(TheaterFollowUpsAtomPermissions.tab));
      expect(
        panel.writeRequirement,
        same(TheaterFollowUpsAtomPermissions.write),
      );
      expect(panel.scope.normalizedType, 'THEATRE');
    },
  );

  testWidgets(
    'compliance: Follow-ups toolbar Print/Export omit without evidence:export',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        theaterRepository: theaterRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      final FollowUpWorklistPanel panel = tester.widget<FollowUpWorklistPanel>(
        find.byType(FollowUpWorklistPanel),
      );
      expect(panel.showAdvancedFilterButton, isTrue);
      expect(panel.enableDateFilter, isTrue);
      expect(panel.canExport, isFalse);
      expect(panel.enablePrint, isTrue);
      expect(panel.canPrint, isFalse);
      expect(panel.printLabel, 'Print');
      expect(panel.advancedFilterButtonLabel, 'Filters');
      expect(panel.advancedFilterApplyLabel, 'Apply filters');
      expect(panel.advancedFilterResetLabel, 'Clear filters');
      expect(panel.advancedFilterCloseLabel, 'Close');

      final AppListTable<ReceptionFollowUpEntry> table =
          tester.widget<AppListTable<ReceptionFollowUpEntry>>(
            find.byType(AppListTable<ReceptionFollowUpEntry>),
          );
      expect(table.canExport, isFalse);
      expect(table.canPrint, isFalse);
      expect(table.columnVisibilityStorageKey, 'theater_follow_ups_cols');
      expect(find.byTooltip('Export'), findsNothing);
      expect(find.byTooltip('Print'), findsNothing);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(_scheduleCaseAction(), findsNothing);
    },
  );

  testWidgets(
    'compliance: Follow-ups mounts Export/Print when evidence:export allowed',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        theaterRepository: theaterRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.evidenceExport,
          },
        ),
      );

      final AppListTable<ReceptionFollowUpEntry> table =
          tester.widget<AppListTable<ReceptionFollowUpEntry>>(
            find.byType(AppListTable<ReceptionFollowUpEntry>),
          );
      expect(table.canExport, isTrue);
      expect(table.canPrint, isTrue);
      expect(table.enablePrint, isTrue);
      expect(table.printLabel, 'Print');
      expect(find.byTooltip('Export'), findsOneWidget);
      expect(find.byTooltip('Print'), findsOneWidget);
      expect(_scheduleCaseAction(), findsNothing);
    },
  );

  testWidgets(
    'compliance: Follow-ups defaults prefer-5 columns and info count tone',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        theaterRepository: theaterRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      final AppListTable<ReceptionFollowUpEntry> table =
          tester.widget<AppListTable<ReceptionFollowUpEntry>>(
            find.byType(AppListTable<ReceptionFollowUpEntry>),
          );
      expect(table.columns.length, 5);
      expect(
        table.columns.map(
          (AppListTableColumn<ReceptionFollowUpEntry> c) => c.key,
        ),
        containsAll(<String>['patient', 'phone', 'status', 'date', 'time']),
      );
      expect(
        table.columnChoices?.map(
          (AppListTableColumn<ReceptionFollowUpEntry> c) => c.key,
        ),
        containsAll(<String>['patient_id', 'email', 'notes']),
      );

      final AppTabStrip strip = tester.widget(find.byType(AppTabStrip));
      final AppTabItem followUps = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.id == TheaterSection.followUps.name,
      );
      expect(followUps.countTone, AppTabCountTone.info);
    },
  );
}

Future<void> _pumpFollowUpsTab(
  WidgetTester tester, {
  required _MockTheaterRepository theaterRepository,
  required _MockFollowUpRepository followUpRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/theater?section=follow-ups',
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
        receptionFollowUpRepositoryProvider.overrideWithValue(
          followUpRepository,
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void _stubTheater(_MockTheaterRepository repository) {
  when(() => repository.listCases(any())).thenAnswer(
    (_) async => const Result<AppPage<TheaterCase>>.success(
      AppPage<TheaterCase>(
        items: <TheaterCase>[],
        request: AppPageRequest(pageSize: 12),
        totalItemCount: 0,
      ),
    ),
  );
}

void _stubFollowUps(
  _MockFollowUpRepository repository, {
  List<ReceptionFollowUpEntry>? entries,
  bool failList = false,
}) {
  final List<ReceptionFollowUpEntry> list =
      entries ?? <ReceptionFollowUpEntry>[_followUp];
  when(
    () => repository.listScheduledFollowUps(
      encounterType: any(named: 'encounterType'),
    ),
  ).thenAnswer((_) async {
    if (failList) {
      return const Result<List<ReceptionFollowUpEntry>>.failure(
        NetworkFailure(),
      );
    }
    return Result<List<ReceptionFollowUpEntry>>.success(list);
  });
}
