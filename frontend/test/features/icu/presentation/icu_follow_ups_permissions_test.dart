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
import 'package:hosspi_hms/features/icu/data/repositories/icu_repository_impl.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/domain/repositories/icu_repository.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';
import 'package:hosspi_hms/features/icu/presentation/pages/icu_workspace_page.dart';
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

class _MockIcuRepository extends Mock implements IcuRepository {}

class _MockFollowUpRepository extends Mock
    implements ReceptionFollowUpRepository {}

final ReceptionFollowUpEntry _followUp = ReceptionFollowUpEntry(
  id: 'fu-icu-1',
  encounterId: 'enc-1',
  patientId: 'pat-1',
  patientIdentifier: 'PAT-FU-ICU1',
  patientDisplayName: 'Follow Up Patient',
  patientPhone: '+256700000001',
  scheduledAt: DateTime.utc(2026, 7, 29, 9, 30),
  notes: 'ICU callback',
  status: 'SCHEDULED',
);

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['DOCTOR'],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalRead ||
        permission == AppPermissions.clinicalWrite,
  );
  final bool needsEmergency = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.emergencyRead ||
        permission == AppPermissions.emergencyWrite,
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
          code: 'icu-critical-care',
          licenseStatus: 'ACTIVE',
        ),
        if (needsClinical)
          const AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        if (needsEmergency)
          const AppModuleEntitlement(
            code: 'scheduling-queue',
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
  late _MockIcuRepository icuRepository;
  late _MockFollowUpRepository followUpRepository;

  setUpAll(() {
    registerFallbackValue(const IcuBoardQuery());
    registerFallbackValue(
      const IcuPatientSummary(id: 'ADM-1', admissionId: 'ADM-1'),
    );
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    icuRepository = _MockIcuRepository();
    followUpRepository = _MockFollowUpRepository();
    _stubIcu(icuRepository);
    _stubFollowUps(followUpRepository);
  });

  group('IcuFollowUpsAtomPermissions helpers', () {
    test('reuses ICU Follow-ups requirements (no second vocabulary)', () {
      expect(
        IcuFollowUpsAtomPermissions.tab,
        same(icuFollowUpsRequirement),
      );
      expect(
        IcuFollowUpsAtomPermissions.write,
        same(icuFollowUpsWriteRequirement),
      );
      expect(
        IcuFollowUpsAtomPermissions.success,
        same(icuFollowUpsWriteRequirement),
      );
      expect(
        IcuFollowUpsAtomPermissions.validation,
        same(icuFollowUpsWriteRequirement),
      );
      expect(
        icuBoardTabRequirement(IcuWorkspaceSection.followUps),
        same(icuFollowUpsRequirement),
      );
      expect(
        IcuFollowUpsAtomPermissions.routeEntry,
        same(icuWorkspaceEntryRequirement),
      );
      expect(
        IcuFollowUpsAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.icuEntry),
      );
      expect(icuRouteEntryMatchesAppRoutes(), isTrue);
    });

    test('∩ denial: missing clinical|emergency write hides Follow-ups writes',
        () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(IcuFollowUpsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(IcuFollowUpsAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        IcuFollowUpsAtomPermissions.markCompleted.isAllowed(reader),
        isFalse,
      );
      expect(IcuFollowUpsAtomPermissions.reschedule.isAllowed(reader), isFalse);
      expect(IcuFollowUpsAtomPermissions.success.isAllowed(reader), isFalse);
      expect(canWriteIcuFollowUps(reader), isFalse);
    });

    test('write ∪ presence: clinical:write + module allows mutations', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(IcuFollowUpsAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        IcuFollowUpsAtomPermissions.markCompleted.isAllowed(writer),
        isTrue,
      );
      expect(IcuFollowUpsAtomPermissions.saveFollowUp.isAllowed(writer), isTrue);
      expect(canWriteIcuFollowUps(writer), isTrue);
    });

    test(
      'mapping note: matrix ∩ clinical:write; source keeps write ∪ emergency',
      () {
        // Matrix create/update/delete list ∩ clinical:write alone; source
        // screens/icu.md keeps ∪ clinical:write | emergency:write.
        expect(
          icuFollowUpsWriteRequirement.anyPermissions,
          containsAll(<AppPermission>[
            AppPermissions.clinicalWrite,
            AppPermissions.emergencyWrite,
          ]),
        );
        expect(icuFollowUpsWriteRequirement.allPermissions, isEmpty);
        final AppAccessPolicy emergencyWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.emergencyRead,
            AppPermissions.emergencyWrite,
          },
        );
        expect(
          IcuFollowUpsAtomPermissions.write.isAllowed(emergencyWriter),
          isTrue,
        );
      },
    );

    test('∪ allowance: clinical:read alone satisfies Follow-ups read', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(IcuFollowUpsAtomPermissions.tab.isAllowed(clinical), isTrue);
      expect(IcuFollowUpsAtomPermissions.search.isAllowed(clinical), isTrue);
      expect(canViewIcuFollowUps(clinical), isTrue);
      expect(canReadIcuFollowUps(clinical), isTrue);
    });

    test('∪ allowance: emergency:read alone satisfies Follow-ups read', () {
      final AppAccessPolicy emergency = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(IcuFollowUpsAtomPermissions.tab.isAllowed(emergency), isTrue);
      expect(IcuFollowUpsAtomPermissions.loading.isAllowed(emergency), isTrue);
      expect(IcuFollowUpsAtomPermissions.empty.isAllowed(emergency), isTrue);
      expect(IcuFollowUpsAtomPermissions.write.isAllowed(emergency), isFalse);
      expect(canViewIcuSection(emergency, IcuWorkspaceSection.followUps),
          isTrue);
    });

    test(
      'route entry ∪: operations:read satisfies entry, not Follow-ups tab',
      () {
        final AppAccessPolicy entryOnly = _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
          roles: const <String>['FACILITY_ADMIN'],
        );
        expect(
          IcuFollowUpsAtomPermissions.routeEntry.isAllowed(entryOnly),
          isTrue,
        );
        expect(IcuFollowUpsAtomPermissions.tab.isAllowed(entryOnly), isFalse);
        expect(canViewIcuFollowUps(entryOnly), isFalse);
      },
    );

    test(
      'subscription strips Follow-ups when icu-critical-care inactive',
      () {
        final AppAccessPolicy noModule = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.emergencyRead,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(IcuFollowUpsAtomPermissions.tab.isAllowed(noModule), isFalse);
        expect(IcuFollowUpsAtomPermissions.write.isAllowed(noModule), isFalse);
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
        expect(IcuFollowUpsAtomPermissions.tab.isAllowed(noFacility), isTrue);
        expect(IcuFollowUpsAtomPermissions.write.isAllowed(noFacility), isTrue);
        expect(
          IcuFollowUpsAtomPermissions.routeEntry.isAllowed(noFacility),
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
              code: 'icu-critical-care',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(receptionFollowUpsRequirement.isAllowed(patientReader), isTrue);
        expect(icuFollowUpsRequirement.isAllowed(patientReader), isFalse);
      },
    );

    test(
      'nested cross-module _(n/a)_: Follow-ups write does not grant pharmacy',
      () {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        );
        expect(IcuFollowUpsAtomPermissions.write.isAllowed(writer), isTrue);
        expect(writer.grants(AppPermissions.pharmacyWrite), isFalse);
        expect(writer.grants(AppPermissions.billingWrite), isFalse);
        final AppAccessPolicy pharmacyOnly = _policy(
          permissions: <AppPermission>{AppPermissions.pharmacyWrite},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'icu-critical-care',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'pharmacy-dispensing',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          IcuFollowUpsAtomPermissions.tab.isAllowed(pharmacyOnly),
          isFalse,
        );
        expect(
          IcuFollowUpsAtomPermissions.write.isAllowed(pharmacyOnly),
          isFalse,
        );
      },
    );
  });

  testWidgets(
    '∪ denial: without clinical:read or emergency:read, Follow-ups absent',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        icuRepository: icuRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
      );

      expect(_tab('Follow-ups'), findsNothing);
      expect(find.byType(FollowUpWorklistPanel), findsNothing);
      expect(find.text('Follow Up Patient'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      // Board tabs also require clinical|emergency read — ops-only omits strip.
      expect(find.byType(AppTabStrip), findsNothing);
    },
  );

  testWidgets(
    'authorized read ∪: clinical:read mounts list; write actions absent',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        icuRepository: icuRepository,
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

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Reschedule follow-up'), findsNothing);
      expect(find.text('Mark completed'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∪ allowance: emergency:read mounts Follow-ups; write actions absent',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        icuRepository: icuRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.emergencyRead},
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
    'full write ∪: Mark completed / Reschedule mount; complete syncs list',
    (WidgetTester tester) async {
      when(
        () => followUpRepository.completeFollowUp(
          any(),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async => const Result<void>.success(null));

      await _pumpFollowUpsTab(
        tester,
        icuRepository: icuRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
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
          'fu-icu-1',
          notes: any(named: 'notes'),
        ),
      ).called(1);
      expect(find.text('Follow Up Patient'), findsNothing);
      expect(find.text('No scheduled follow-ups'), findsOneWidget);
    },
  );

  testWidgets(
    'write ∪: emergency:write mounts Mark completed without clinical:write',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        icuRepository: icuRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.emergencyRead,
            AppPermissions.emergencyWrite,
          },
        ),
      );

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Reschedule follow-up'), findsOneWidget);
      expect(find.text('Mark completed'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'reschedule entry opens Save follow-up dialog when write allowed',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        icuRepository: icuRepository,
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
        icuRepository: icuRepository,
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
      icuRepository: icuRepository,
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
      icuRepository: icuRepository,
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
        initialLocation: '/icu?section=follow-ups',
        routes: <RouteBase>[
          GoRoute(
            path: '/icu',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: IcuWorkspacePage(
                  initialQuery: IcuBoardQuery.fromUri(state.uri),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            icuRepositoryProvider.overrideWithValue(icuRepository),
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
      icuRepository: icuRepository,
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
      icuRepository: icuRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
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
      icuRepository: icuRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
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
      icuRepository: icuRepository,
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
        icuRepository: icuRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
        initialLocation: '/icu?section=follow-ups',
      );

      expect(_tab('Follow-ups'), findsNothing);
      expect(find.byType(FollowUpWorklistPanel), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );
}

Future<void> _pumpFollowUpsTab(
  WidgetTester tester, {
  required _MockIcuRepository icuRepository,
  required _MockFollowUpRepository followUpRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/icu?section=follow-ups',
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
        path: '/icu',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: IcuWorkspacePage(
              initialQuery: IcuBoardQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        icuRepositoryProvider.overrideWithValue(icuRepository),
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

void _stubIcu(_MockIcuRepository repository) {
  when(() => repository.listIcuBoard(any())).thenAnswer(
    (_) async => Result<AppPage<IcuPatientSummary>>.success(
      AppPage<IcuPatientSummary>(
        items: const <IcuPatientSummary>[],
        request: const AppPageRequest(pageSize: 12),
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async => const Result<IcuReferenceData>.success(IcuReferenceData()),
  );
  when(() => repository.loadBedBoard()).thenAnswer(
    (_) async => const Result<IcuBedBoard>.success(
      IcuBedBoard(wards: <IcuBedWard>[], beds: <IcuBed>[]),
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
