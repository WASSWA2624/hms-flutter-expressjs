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
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/physiotherapy/data/repositories/physiotherapy_repository_impl.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/entities/physiotherapy_entities.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/repositories/physiotherapy_repository.dart';
import 'package:hosspi_hms/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart';
import 'package:hosspi_hms/features/physiotherapy/presentation/physiotherapy_access.dart';
import 'package:hosspi_hms/features/reception/data/reception_follow_up_repository.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/follow_up_worklist_panel.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPhysiotherapyRepository extends Mock
    implements PhysiotherapyRepository {}

class _MockFollowUpRepository extends Mock
    implements ReceptionFollowUpRepository {}

final ReceptionFollowUpEntry _followUp = ReceptionFollowUpEntry(
  id: 'fu-physio-1',
  encounterId: 'enc-1',
  patientId: 'pat-1',
  patientIdentifier: 'PAT-FU-PHYS1',
  patientDisplayName: 'Follow Up Patient',
  patientPhone: '+256700000001',
  scheduledAt: DateTime.utc(2026, 7, 29, 9, 30),
  notes: 'Physio callback',
  status: 'SCHEDULED',
);

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['PHYSIOTHERAPIST'],
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
          code: physiotherapyModule,
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
  late _MockPhysiotherapyRepository physiotherapyRepository;
  late _MockFollowUpRepository followUpRepository;

  setUpAll(() {
    registerFallbackValue(const PhysiotherapyWorklistQuery());
    registerFallbackValue(
      const TherapyWorkItem(
        id: 'TH-FALLBACK',
        encounterId: 'ENC-FALLBACK',
        patientId: 'PAT-FALLBACK',
      ),
    );
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    physiotherapyRepository = _MockPhysiotherapyRepository();
    followUpRepository = _MockFollowUpRepository();
    _stubPhysiotherapy(physiotherapyRepository);
    _stubFollowUps(followUpRepository);
  });

  group('PhysiotherapyFollowUpsAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          PhysiotherapyFollowUpsAtomPermissions.tab,
          physiotherapyFollowUpsRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyFollowUpsAtomPermissions.write,
          physiotherapyFollowUpsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyFollowUpsAtomPermissions.write,
          physiotherapyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyFollowUpsAtomPermissions.success,
          physiotherapyFollowUpsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyFollowUpsAtomPermissions.validation,
          physiotherapyFollowUpsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyFollowUpsAtomPermissions.complete,
          physiotherapyFollowUpsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyFollowUpsAtomPermissions.routeEntry,
          physiotherapyWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyFollowUpsAtomPermissions.catalogEntry,
          RouteAccessCatalog.physiotherapyEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyFollowUpsAtomPermissions.billingColumn,
          billingReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyFollowUpsAtomPermissions.read,
          physiotherapyWorkspaceReadRequirement,
        ),
        isTrue,
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
      expect(PhysiotherapyFollowUpsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        PhysiotherapyFollowUpsAtomPermissions.write.isAllowed(reader),
        isFalse,
      );
      expect(
        PhysiotherapyFollowUpsAtomPermissions.markCompleted.isAllowed(reader),
        isFalse,
      );
      expect(
        PhysiotherapyFollowUpsAtomPermissions.reschedule.isAllowed(reader),
        isFalse,
      );
      expect(
        PhysiotherapyFollowUpsAtomPermissions.success.isAllowed(reader),
        isFalse,
      );
      expect(canWritePhysiotherapyFollowUps(reader), isFalse);
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
          PhysiotherapyFollowUpsAtomPermissions.tab.isAllowed(patientWriter),
          isTrue,
        );
        expect(
          PhysiotherapyFollowUpsAtomPermissions.write.isAllowed(patientWriter),
          isFalse,
        );
        expect(canWritePhysiotherapyFollowUps(patientWriter), isFalse);
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
      expect(PhysiotherapyFollowUpsAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        PhysiotherapyFollowUpsAtomPermissions.markCompleted.isAllowed(writer),
        isTrue,
      );
      expect(
        PhysiotherapyFollowUpsAtomPermissions.saveFollowUp.isAllowed(writer),
        isTrue,
      );
      expect(canWritePhysiotherapyFollowUps(writer), isTrue);
    });

    test('mapping note: matrix ∩ clinical:write via allPermissions', () {
      expect(
        physiotherapyFollowUpsWriteRequirement.allPermissions,
        <AppPermission>[AppPermissions.clinicalWrite],
      );
      expect(physiotherapyFollowUpsWriteRequirement.anyPermissions, isEmpty);
      expect(
        physiotherapyFollowUpsWriteRequirement.activeModules,
        contains(physiotherapyModule),
      );
    });

    test('∪ allowance: clinical:read alone satisfies Follow-ups read', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        roles: const <String>['DOCTOR'],
      );
      expect(
        PhysiotherapyFollowUpsAtomPermissions.tab.isAllowed(clinical),
        isTrue,
      );
      expect(
        PhysiotherapyFollowUpsAtomPermissions.search.isAllowed(clinical),
        isTrue,
      );
      expect(canViewPhysiotherapyFollowUps(clinical), isTrue);
      expect(canReadPhysiotherapyFollowUps(clinical), isTrue);
    });

    test('∪ allowance: patient:read alone satisfies Follow-ups read', () {
      final AppAccessPolicy patient = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
        roles: const <String>['RECEPTIONIST'],
      );
      expect(
        PhysiotherapyFollowUpsAtomPermissions.tab.isAllowed(patient),
        isTrue,
      );
      expect(
        PhysiotherapyFollowUpsAtomPermissions.loading.isAllowed(patient),
        isTrue,
      );
      expect(
        PhysiotherapyFollowUpsAtomPermissions.empty.isAllowed(patient),
        isTrue,
      );
      expect(
        PhysiotherapyFollowUpsAtomPermissions.write.isAllowed(patient),
        isFalse,
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
          PhysiotherapyFollowUpsAtomPermissions.routeEntryUnion.isAllowed(
            entryOnly,
          ),
          isTrue,
        );
        expect(
          PhysiotherapyFollowUpsAtomPermissions.tab.isAllowed(entryOnly),
          isFalse,
        );
        expect(canViewPhysiotherapyFollowUps(entryOnly), isFalse);
        expect(
          PhysiotherapyFollowUpsAtomPermissions.routeEntry.isAllowed(entryOnly),
          isTrue,
        );
      },
    );

    test('subscription strips Follow-ups when physiotherapy inactive', () {
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
      expect(
        PhysiotherapyFollowUpsAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(
        PhysiotherapyFollowUpsAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );
    });

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
        expect(
          PhysiotherapyFollowUpsAtomPermissions.tab.isAllowed(noFacility),
          isTrue,
        );
        expect(
          PhysiotherapyFollowUpsAtomPermissions.write.isAllowed(noFacility),
          isTrue,
        );
        expect(
          PhysiotherapyFollowUpsAtomPermissions.routeEntryUnion.isAllowed(
            noFacility,
          ),
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
              code: physiotherapyModule,
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          receptionFollowUpsRequirement.isAllowed(clinicalOnly),
          isFalse,
        );
        expect(
          physiotherapyFollowUpsRequirement.isAllowed(clinicalOnly),
          isTrue,
        );
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
        expect(
          PhysiotherapyFollowUpsAtomPermissions.write.isAllowed(writer),
          isTrue,
        );
        expect(writer.grants(AppPermissions.billingRead), isFalse);
        expect(
          PhysiotherapyFollowUpsAtomPermissions.billingChip.isAllowed(writer),
          isFalse,
        );
        final AppAccessPolicy billingOnly = _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        );
        expect(
          PhysiotherapyFollowUpsAtomPermissions.tab.isAllowed(billingOnly),
          isFalse,
        );
        expect(
          PhysiotherapyFollowUpsAtomPermissions.write.isAllowed(billingOnly),
          isFalse,
        );
      },
    );
  });

  testWidgets(
    '∪ denial: without patient:read or clinical:read, Follow-ups absent',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        physiotherapyRepository: physiotherapyRepository,
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
      expect(find.byType(AppTabStrip), findsNothing);
    },
  );

  testWidgets(
    'authorized read ∪: clinical:read mounts list; write actions absent',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        physiotherapyRepository: physiotherapyRepository,
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
        physiotherapyRepository: physiotherapyRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          roles: const <String>['RECEPTIONIST'],
        ),
      );

      expect(_tab('Follow-ups'), findsOneWidget);
      expect(find.byType(FollowUpWorklistPanel), findsOneWidget);
      expect(find.text('Follow Up Patient'), findsOneWidget);

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
        physiotherapyRepository: physiotherapyRepository,
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
          'fu-physio-1',
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
        physiotherapyRepository: physiotherapyRepository,
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
        physiotherapyRepository: physiotherapyRepository,
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
      physiotherapyRepository: physiotherapyRepository,
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
      physiotherapyRepository: physiotherapyRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        roles: const <String>['DOCTOR'],
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
        initialLocation: '/physiotherapy?section=follow-ups',
        routes: <RouteBase>[
          GoRoute(
            path: '/physiotherapy',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: PhysiotherapyWorkspacePage(
                  initialQuery: PhysiotherapyWorkspaceQuery.fromUri(state.uri),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            physiotherapyRepositoryProvider.overrideWithValue(
              physiotherapyRepository,
            ),
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
      physiotherapyRepository: physiotherapyRepository,
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
      physiotherapyRepository: physiotherapyRepository,
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
      physiotherapyRepository: physiotherapyRepository,
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
      physiotherapyRepository: physiotherapyRepository,
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
        physiotherapyRepository: physiotherapyRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        ),
        initialLocation: '/physiotherapy?section=follow-ups',
      );

      expect(_tab('Follow-ups'), findsNothing);
      expect(find.byType(FollowUpWorklistPanel), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strips Follow-ups tab when physiotherapy inactive',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        physiotherapyRepository: physiotherapyRepository,
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
}

Future<void> _pumpFollowUpsTab(
  WidgetTester tester, {
  required _MockPhysiotherapyRepository physiotherapyRepository,
  required _MockFollowUpRepository followUpRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/physiotherapy?section=follow-ups',
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
        path: '/physiotherapy',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: PhysiotherapyWorkspacePage(
              initialQuery: PhysiotherapyWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        physiotherapyRepositoryProvider.overrideWithValue(
          physiotherapyRepository,
        ),
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

void _stubPhysiotherapy(_MockPhysiotherapyRepository repository) {
  when(() => repository.listWorkItems(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final PhysiotherapyWorklistQuery query =
        invocation.positionalArguments.single as PhysiotherapyWorklistQuery;
    return Result<AppPage<TherapyWorkItem>>.success(
      AppPage<TherapyWorkItem>(
        items: const <TherapyWorkItem>[],
        request: query.pageRequest,
        totalItemCount: 0,
      ),
    );
  });
  when(() => repository.loadDetail(any())).thenAnswer(
    (_) async => Result<PhysiotherapyDetail>.success(
      PhysiotherapyDetail(
        item: const TherapyWorkItem(
          id: 'TH-STUB',
          encounterId: 'ENC-STUB',
          patientId: 'PAT-STUB',
        ),
      ),
    ),
  );
}

void _stubFollowUps(_MockFollowUpRepository repository) {
  when(
    () => repository.listScheduledFollowUps(
      encounterType: any(named: 'encounterType'),
    ),
  ).thenAnswer(
    (_) async => Result<List<ReceptionFollowUpEntry>>.success(
      <ReceptionFollowUpEntry>[_followUp],
    ),
  );
}
