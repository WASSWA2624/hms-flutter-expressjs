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
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/opd/presentation/opd_access.dart';
import 'package:hosspi_hms/features/opd/presentation/pages/opd_workspace_page.dart';
import 'package:hosspi_hms/features/reception/data/reception_follow_up_repository.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/components/opd_encounter_dialog.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/follow_up_worklist_panel.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockFollowUpRepository extends Mock
    implements ReceptionFollowUpRepository {}

final ReceptionFollowUpEntry _followUp = ReceptionFollowUpEntry(
  id: 'fu-opd-1',
  encounterId: 'enc-1',
  patientId: 'pat-1',
  patientIdentifier: 'PAT-FU-OPD1',
  patientDisplayName: 'Follow Up Patient',
  patientPhone: '+256700000001',
  scheduledAt: DateTime.utc(2026, 7, 29, 9, 30),
  notes: 'OPD callback',
  status: 'SCHEDULED',
);

final ReceptionFollowUpEntry _followUpOther = ReceptionFollowUpEntry(
  id: 'fu-opd-2',
  encounterId: 'enc-2',
  patientId: 'pat-2',
  patientIdentifier: 'PAT-FU-OPD2',
  patientDisplayName: 'Other Follow Up',
  patientPhone: '+256700000002',
  scheduledAt: DateTime.utc(2026, 7, 30, 11, 0),
  notes: 'Second callback',
  status: 'SCHEDULED',
);

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['NURSE'],
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
  final List<AppModuleEntitlement> resolvedModules =
      modules ??
      <AppModuleEntitlement>[
        const AppModuleEntitlement(
          code: opdSchedulingQueueModule,
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
  late _MockOpdRepository opdRepository;
  late _MockFollowUpRepository followUpRepository;

  setUpAll(() {
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdQueueQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    opdRepository = _MockOpdRepository();
    followUpRepository = _MockFollowUpRepository();
    _stubOpd(opdRepository);
    _stubFollowUps(followUpRepository);
  });

  group('OpdFollowUpsAtomPermissions helpers', () {
    test('reuses OPD Follow-ups requirements (no second vocabulary)', () {
      expect(OpdFollowUpsAtomPermissions.tab, same(opdFollowUpsRequirement));
      expect(
        OpdFollowUpsAtomPermissions.write,
        same(opdFollowUpsWriteRequirement),
      );
      expect(
        OpdFollowUpsAtomPermissions.write,
        same(opdClinicalWriteRequirement),
      );
      expect(
        OpdFollowUpsAtomPermissions.success,
        same(opdFollowUpsWriteRequirement),
      );
      expect(
        OpdFollowUpsAtomPermissions.validation,
        same(opdFollowUpsWriteRequirement),
      );
      expect(
        OpdFollowUpsAtomPermissions.complete,
        same(opdFollowUpsWriteRequirement),
      );
      expect(
        OpdFollowUpsAtomPermissions.startEncounter,
        same(opdEncounterPermissionRequirement),
      );
      expect(
        opdBoardTabRequirement(OpdWorkspaceSection.followUps),
        same(opdFollowUpsRequirement),
      );
      expect(
        OpdFollowUpsAtomPermissions.routeEntry,
        same(opdWorkspaceEntryRequirement),
      );
      expect(
        OpdFollowUpsAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.opdEntry),
      );
      expect(
        OpdFollowUpsAtomPermissions.nestedBillingWrite,
        same(opdBillingActionRequirement),
      );
      expect(
        OpdFollowUpsAtomPermissions.nestedAdmissionWrite,
        same(opdAdmissionHandoffRequirement),
      );
      expect(
        OpdFollowUpsAtomPermissions.export,
        same(opdWorkspaceExportRequirement),
      );
      expect(
        OpdFollowUpsAtomPermissions.print,
        same(opdWorkspacePrintRequirement),
      );
    });

    test('∩ denial: missing clinical:write hides Follow-ups write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.clinicalRead,
        },
        roles: const <String>['CUSTOM_READER'],
      );
      expect(OpdFollowUpsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(OpdFollowUpsAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        OpdFollowUpsAtomPermissions.markCompleted.isAllowed(reader),
        isFalse,
      );
      expect(
        OpdFollowUpsAtomPermissions.reschedule.isAllowed(reader),
        isFalse,
      );
      expect(OpdFollowUpsAtomPermissions.success.isAllowed(reader), isFalse);
      expect(canWriteOpdFollowUps(reader), isFalse);
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
        expect(OpdFollowUpsAtomPermissions.tab.isAllowed(patientWriter), isTrue);
        expect(
          OpdFollowUpsAtomPermissions.write.isAllowed(patientWriter),
          isFalse,
        );
        expect(canWriteOpdFollowUps(patientWriter), isFalse);
      },
    );

    test('write ∩ presence: clinical:write + module allows mutations', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(OpdFollowUpsAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        OpdFollowUpsAtomPermissions.markCompleted.isAllowed(writer),
        isTrue,
      );
      expect(
        OpdFollowUpsAtomPermissions.saveFollowUp.isAllowed(writer),
        isTrue,
      );
      expect(canWriteOpdFollowUps(writer), isTrue);
    });

    test('mapping note: matrix ∩ clinical:write via allPermissions', () {
      expect(
        opdFollowUpsWriteRequirement.allPermissions,
        <AppPermission>[AppPermissions.clinicalWrite],
      );
      expect(opdFollowUpsWriteRequirement.anyPermissions, isEmpty);
      expect(
        opdFollowUpsWriteRequirement.activeModules,
        contains(opdSchedulingQueueModule),
      );
    });

    test('∪ allowance: clinical:read alone satisfies Follow-ups read', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        roles: const <String>['DOCTOR'],
      );
      expect(OpdFollowUpsAtomPermissions.tab.isAllowed(clinical), isTrue);
      expect(OpdFollowUpsAtomPermissions.search.isAllowed(clinical), isTrue);
      expect(canViewOpdFollowUps(clinical), isTrue);
      expect(canReadOpdFollowUps(clinical), isTrue);
    });

    test('∪ allowance: patient:read alone satisfies Follow-ups read', () {
      final AppAccessPolicy patient = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
        roles: const <String>['RECEPTIONIST'],
      );
      expect(OpdFollowUpsAtomPermissions.tab.isAllowed(patient), isTrue);
      expect(OpdFollowUpsAtomPermissions.loading.isAllowed(patient), isTrue);
      expect(OpdFollowUpsAtomPermissions.empty.isAllowed(patient), isTrue);
      expect(OpdFollowUpsAtomPermissions.write.isAllowed(patient), isFalse);
      expect(
        canViewOpdTab(patient, OpdWorkspaceSection.followUps),
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
          OpdFollowUpsAtomPermissions.routeEntryUnion.isAllowed(entryOnly),
          isTrue,
        );
        expect(OpdFollowUpsAtomPermissions.tab.isAllowed(entryOnly), isFalse);
        expect(canViewOpdFollowUps(entryOnly), isFalse);
        // Catalog keeps unique opd:read — billing alone does not satisfy it.
        expect(
          OpdFollowUpsAtomPermissions.routeEntry.isAllowed(entryOnly),
          isFalse,
        );
      },
    );

    test(
      'subscription strips Follow-ups when scheduling-queue inactive',
      () {
        final AppAccessPolicy noModule = _policy(
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
        );
        expect(OpdFollowUpsAtomPermissions.tab.isAllowed(noModule), isFalse);
        expect(OpdFollowUpsAtomPermissions.write.isAllowed(noModule), isFalse);
      },
    );

    test(
      'ABAC: missing facility still allows Follow-ups chrome '
      '(row/own scope remains backend-authoritative)',
      () {
        final AppAccessPolicy noFacility = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
          facilityId: null,
        );
        expect(noFacility.hasFacilityContext, isFalse);
        expect(OpdFollowUpsAtomPermissions.tab.isAllowed(noFacility), isTrue);
        expect(
          OpdFollowUpsAtomPermissions.write.isAllowed(noFacility),
          isTrue,
        );
        expect(
          OpdFollowUpsAtomPermissions.routeEntryUnion.isAllowed(noFacility),
          isTrue,
        );
      },
    );

    test(
      'mapping note: shared panel default remains reception ∪ / front-desk write',
      () {
        final AppAccessPolicy clinicalOnly = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: opdSchedulingQueueModule,
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        // Reception Follow-ups also needs patient-registry module.
        expect(
          receptionFollowUpsRequirement.isAllowed(clinicalOnly),
          isFalse,
        );
        expect(opdFollowUpsRequirement.isAllowed(clinicalOnly), isTrue);
      },
    );

    test(
      'nested cross-module _(n/a)_: Follow-ups write does not grant billing',
      () {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        );
        expect(OpdFollowUpsAtomPermissions.write.isAllowed(writer), isTrue);
        expect(writer.grants(AppPermissions.billingRead), isFalse);
        expect(writer.grants(AppPermissions.pharmacyWrite), isFalse);
        expect(
          OpdFollowUpsAtomPermissions.nestedBillingWrite.isAllowed(writer),
          isFalse,
        );
        final AppAccessPolicy billingOnly = _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        );
        expect(
          OpdFollowUpsAtomPermissions.tab.isAllowed(billingOnly),
          isFalse,
        );
        expect(
          OpdFollowUpsAtomPermissions.write.isAllowed(billingOnly),
          isFalse,
        );
      },
    );

    test('Start OPD encounter is documented but unused on Follow-ups chrome', () {
      expect(
        OpdFollowUpsAtomPermissions.startEncounter,
        same(opdStartEncounterRequirement),
      );
      expect(
        opdStartEncounterRequirementForSection(OpdWorkspaceSection.followUps),
        same(OpdFollowUpsAtomPermissions.startEncounter),
      );
    });
  });

  testWidgets(
    '∪ denial: without patient:read or clinical:read, Follow-ups absent',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        opdRepository: opdRepository,
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
      // Board tabs also require patient|clinical read — billing-only omits strip.
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Start OPD encounter'), findsNothing);
    },
  );

  testWidgets(
    'authorized read ∪: clinical:read mounts list; write actions absent',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        ),
      );

      expect(_tab('Follow-ups'), findsOneWidget);
      expect(find.byType(FollowUpWorklistPanel), findsOneWidget);
      expect(find.text('Follow Up Patient'), findsOneWidget);
      expect(find.text('Reschedule follow-up'), findsNothing);
      expect(find.text('Mark completed'), findsNothing);
      expect(find.text('Start OPD encounter'), findsNothing);

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
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          roles: const <String>['RECEPTIONIST'],
        ),
      );

      expect(_tab('Follow-ups'), findsOneWidget);
      expect(find.byType(FollowUpWorklistPanel), findsOneWidget);
      expect(find.text('Follow Up Patient'), findsOneWidget);
      expect(find.text('Start OPD encounter'), findsNothing);
      expect(find.byTooltip('Filters'), findsOneWidget);

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
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      expect(find.text('Follow Up Patient'), findsOneWidget);
      expect(find.text('Start OPD encounter'), findsNothing);

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
          'fu-opd-1',
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
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
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
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
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
      opdRepository: opdRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        roles: const <String>['DOCTOR'],
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
      opdRepository: opdRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        roles: const <String>['DOCTOR'],
      ),
    );

    expect(find.text('No scheduled follow-ups'), findsOneWidget);
    expect(find.text('Mark completed'), findsNothing);
    expect(find.text('Start OPD encounter'), findsNothing);
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
        initialLocation: '/opd?section=follow-ups',
        routes: <RouteBase>[
          GoRoute(
            path: '/opd',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: OpdWorkspacePage(
                  initialQuery: OpdWorkspaceQuery.fromUri(state.uri),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            opdRepositoryProvider.overrideWithValue(opdRepository),
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
                roles: const <String>['DOCTOR'],
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
      opdRepository: opdRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
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
      opdRepository: opdRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
      physicalSize: const Size(1440, 900),
    );

    expect(find.text('Follow Up Patient'), findsOneWidget);
    expect(_tab('Follow-ups'), findsOneWidget);
  });

  testWidgets('light theme: authorized Follow-ups chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpFollowUpsTab(
      tester,
      opdRepository: opdRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
      themeMode: ThemeMode.light,
    );

    expect(find.text('Follow Up Patient'), findsOneWidget);
    expect(_tab('Follow-ups'), findsOneWidget);
  });

  testWidgets('dark theme: authorized Follow-ups chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpFollowUpsTab(
      tester,
      opdRepository: opdRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
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
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        ),
        initialLocation: '/opd?section=follow-ups',
      );

      expect(_tab('Follow-ups'), findsNothing);
      expect(find.byType(FollowUpWorklistPanel), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expect(find.text('Access denied'), findsOneWidget);
    },
  );

  testWidgets(
    'subscription strips Follow-ups tab when scheduling-queue inactive',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        opdRepository: opdRepository,
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
    'Export/Print omit without evidence:export; present when granted',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );
      expect(find.byTooltip('Export'), findsNothing);
      expect(find.byTooltip('Print'), findsNothing);
      expect(find.text('Start OPD encounter'), findsNothing);

      await _pumpFollowUpsTab(
        tester,
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.evidenceExport,
          },
          roles: const <String>['PLATFORM_ADMIN'],
        ),
      );
      expect(find.byTooltip('Export'), findsOneWidget);
      expect(find.byTooltip('Print'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.text('Start OPD encounter'), findsNothing);
    },
  );

  testWidgets(
    'defaults five data columns; Follow-ups count tone is info; Settings lists choices',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.clinicalRead,
          },
          roles: const <String>['CUSTOM_READER'],
        ),
      );

      final AppTabStrip strip = tester.widget<AppTabStrip>(
        find.byType(AppTabStrip),
      );
      final AppTabItem followUps = strip.tabs.firstWhere(
        (AppTabItem item) => item.id == 'followUps',
      );
      expect(followUps.count, 1);
      expect(followUps.countTone, AppTabCountTone.info);

      expect(find.text('Patient name'), findsWidgets);
      expect(find.text('Phone'), findsWidgets);
      expect(find.text('Status'), findsWidgets);
      expect(find.text('Follow-up date'), findsWidgets);
      expect(find.text('Follow-up time'), findsWidgets);
      expect(find.text('Email'), findsNothing);
      expect(find.text('Patient ID'), findsNothing);
      expect(find.text('Notes'), findsNothing);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('TABLE SETTINGS'), findsOneWidget);
      expect(find.text('Patient ID'), findsWidgets);
      expect(find.text('Email'), findsWidgets);
      expect(find.text('Notes'), findsWidgets);
      expect(find.text('Close'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Advanced filters footer is Clear filters → Apply filters → Close',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        ),
      );

      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      expect(find.text('ADVANCED FILTERS'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
      expect(find.text('Apply filters'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('ADVANCED FILTERS'), findsNothing);
    },
  );

  testWidgets(
    'active Follow-ups badge uses filtered total when search narrows',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        ),
        followUps: <ReceptionFollowUpEntry>[_followUp, _followUpOther],
      );

      final AppTabStrip initial = tester.widget<AppTabStrip>(
        find.byType(AppTabStrip),
      );
      expect(
        initial.tabs.firstWhere((AppTabItem t) => t.id == 'followUps').count,
        2,
      );

      await tester.enterText(find.byType(TextField).first, 'Other Follow Up');
      await tester.pumpAndSettle();

      final AppTabStrip filtered = tester.widget<AppTabStrip>(
        find.byType(AppTabStrip),
      );
      expect(
        filtered.tabs.firstWhere((AppTabItem t) => t.id == 'followUps').count,
        1,
      );
      expect(find.text('Other Follow Up'), findsWidgets);
      expect(find.text('Follow Up Patient'), findsNothing);
    },
  );
}

Future<void> _pumpFollowUpsTab(
  WidgetTester tester, {
  required _MockOpdRepository opdRepository,
  required _MockFollowUpRepository followUpRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/opd?section=follow-ups',
  List<ReceptionFollowUpEntry>? followUps,
}) async {
  if (followUps != null) {
    _stubFollowUps(followUpRepository, entries: followUps);
  }
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
        path: '/opd',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: OpdWorkspacePage(
              initialQuery: OpdWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        opdRepositoryProvider.overrideWithValue(opdRepository),
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

void _stubOpd(_MockOpdRepository repository) {
  when(() => repository.listAppointments(any())).thenAnswer((invocation) async {
    return Result<AppPage<OpdAppointment>>.success(
      AppPage<OpdAppointment>(
        items: const <OpdAppointment>[],
        request: (invocation.positionalArguments.single as OpdAppointmentQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    );
  });
  when(() => repository.listVisitQueues(any())).thenAnswer((invocation) async {
    return Result<AppPage<OpdQueueEntry>>.success(
      AppPage<OpdQueueEntry>(
        items: const <OpdQueueEntry>[],
        request:
            (invocation.positionalArguments.single as OpdQueueQuery).pageRequest,
        totalItemCount: 0,
      ),
    );
  });
  when(() => repository.listOpdFlows(any())).thenAnswer((invocation) async {
    return Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: 0,
      ),
    );
  });
  when(() => repository.listTriageQueue(any())).thenAnswer((invocation) async {
    return Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request: (invocation.positionalArguments.single as OpdTriageQueueQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    );
  });
  when(() => repository.getOpdSummaryCounts()).thenAnswer(
    (_) async => const Result<OpdFlowAggregateCounts>.success(
      OpdFlowAggregateCounts(activeOpd: 0),
    ),
  );
  when(
    () => repository.listClinicalAlertThresholds(
      vitalType: any(named: 'vitalType'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<OpdClinicalAlertThreshold>>.success(
      <OpdClinicalAlertThreshold>[],
    ),
  );
  when(() => repository.listProviderSchedules()).thenAnswer(
    (_) async => const Result<List<OpdProviderSchedule>>.success(
      <OpdProviderSchedule>[],
    ),
  );
  when(() => repository.listProviders()).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
  when(
    () => repository.getBillingDefaults(
      facilityId: any(named: 'facilityId'),
      tenantId: any(named: 'tenantId'),
    ),
  ).thenAnswer(
    (_) async => const Result<OpdBillingDefaults>.success(OpdBillingDefaults()),
  );
}

void _stubFollowUps(
  _MockFollowUpRepository repository, {
  List<ReceptionFollowUpEntry>? entries,
}) {
  final List<ReceptionFollowUpEntry> resolved =
      entries ?? <ReceptionFollowUpEntry>[_followUp];
  when(
    () => repository.listScheduledFollowUps(
      encounterType: any(named: 'encounterType'),
    ),
  ).thenAnswer(
    (_) async => Result<List<ReceptionFollowUpEntry>>.success(resolved),
  );
}
