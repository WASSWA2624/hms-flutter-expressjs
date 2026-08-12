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
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart';
import 'package:hosspi_hms/features/clinical/presentation/pages/clinical_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/reception/data/reception_follow_up_repository.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/follow_up_worklist_panel.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockClinicalRepository extends Mock implements ClinicalRepository {}

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockIpdRepository extends Mock implements IpdRepository {}

class _MockFollowUpRepository extends Mock
    implements ReceptionFollowUpRepository {}

final ReceptionFollowUpEntry _followUp = ReceptionFollowUpEntry(
  id: 'fu-clinical-1',
  encounterId: 'enc-1',
  patientId: 'pat-1',
  patientIdentifier: 'PAT-FU-1',
  patientDisplayName: 'Follow Up Patient',
  patientPhone: '+256700000001',
  scheduledAt: DateTime.utc(2026, 7, 29, 9, 30),
  notes: 'Callback about labs',
  status: 'SCHEDULED',
);

final ReceptionFollowUpEntry _followUpOther = ReceptionFollowUpEntry(
  id: 'fu-clinical-2',
  encounterId: 'enc-2',
  patientId: 'pat-2',
  patientIdentifier: 'PAT-FU-2',
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
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
  ],
  List<String> roles = const <String>['DOCTOR'],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void main() {
  late _MockClinicalRepository clinicalRepository;
  late _MockOpdRepository opdRepository;
  late _MockIpdRepository ipdRepository;
  late _MockFollowUpRepository followUpRepository;

  setUpAll(() {
    registerFallbackValue(const ClinicalWorklistQuery());
    registerFallbackValue(
      const ClinicalWorklistEntry(
        id: 'encounter-fallback',
        sourceQueue: 'OPD',
        encounterId: 'encounter-fallback',
      ),
    );
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    clinicalRepository = _MockClinicalRepository();
    opdRepository = _MockOpdRepository();
    ipdRepository = _MockIpdRepository();
    followUpRepository = _MockFollowUpRepository();
    _stubClinical(clinicalRepository);
    _stubOpd(opdRepository);
    _stubIpd(ipdRepository);
    _stubFollowUps(followUpRepository);
  });

  group('ClinicalFollowUpsAtomPermissions helpers', () {
    test('reuses clinical read/write requirements (no second vocabulary)', () {
      expect(
        ClinicalFollowUpsAtomPermissions.tab,
        same(clinicalFollowUpsRequirement),
      );
      expect(
        ClinicalFollowUpsAtomPermissions.tab,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalFollowUpsAtomPermissions.write,
        same(clinicalFollowUpsWriteRequirement),
      );
      expect(
        ClinicalFollowUpsAtomPermissions.write,
        same(clinicalEncounterWriteRequirement),
      );
      expect(
        ClinicalFollowUpsAtomPermissions.success,
        same(clinicalFollowUpsWriteRequirement),
      );
      expect(
        ClinicalFollowUpsAtomPermissions.validation,
        same(clinicalFollowUpsWriteRequirement),
      );
      expect(
        ClinicalFollowUpsAtomPermissions.routeEntry,
        same(clinicalWorkspaceEntryRequirement),
      );
      expect(
        ClinicalFollowUpsAtomPermissions.export,
        same(clinicalWorkspaceExportRequirement),
      );
      expect(
        ClinicalFollowUpsAtomPermissions.listPrint,
        same(clinicalWorkspacePrintRequirement),
      );
      expect(
        clinicalSectionRequirement(ClinicalWorkspaceSection.followUps),
        same(clinicalFollowUpsRequirement),
      );
    });

    test('∩ denial: missing clinical:read hides Follow-ups tab requirement', () {
      final AppAccessPolicy none = _policy(permissions: <AppPermission>{});
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalWrite},
      );
      expect(ClinicalFollowUpsAtomPermissions.tab.isAllowed(none), isFalse);
      expect(ClinicalFollowUpsAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(canReadClinicalFollowUps(writeOnly), isFalse);
      expect(canViewClinicalSection(none, ClinicalWorkspaceSection.followUps),
          isFalse);
    });

    test('∩ presence: clinical:read + module allows Follow-ups read atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(ClinicalFollowUpsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(ClinicalFollowUpsAtomPermissions.search.isAllowed(reader), isTrue);
      expect(ClinicalFollowUpsAtomPermissions.loading.isAllowed(reader), isTrue);
      expect(ClinicalFollowUpsAtomPermissions.empty.isAllowed(reader), isTrue);
      expect(ClinicalFollowUpsAtomPermissions.detail.isAllowed(reader), isTrue);
      expect(ClinicalFollowUpsAtomPermissions.write.isAllowed(reader), isFalse);
      expect(ClinicalFollowUpsAtomPermissions.success.isAllowed(reader), isFalse);
      expect(
        ClinicalFollowUpsAtomPermissions.validation.isAllowed(reader),
        isFalse,
      );
      expect(ClinicalFollowUpsAtomPermissions.markCompleted.isAllowed(reader),
          isFalse);
      expect(ClinicalFollowUpsAtomPermissions.reschedule.isAllowed(reader),
          isFalse);
    });

    test(
      'route entry ∩: clinical:write alone fails catalog entry and Follow-ups tab',
      () {
        final AppAccessPolicy writeOnly = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalWrite},
        );
        // Catalog entry is ∩ clinical:read (prompt ∪ read|write → keep catalog).
        expect(
          ClinicalFollowUpsAtomPermissions.routeEntry.isAllowed(writeOnly),
          isFalse,
        );
        expect(
          ClinicalFollowUpsAtomPermissions.tab.isAllowed(writeOnly),
          isFalse,
        );
        expect(
          ClinicalFollowUpsAtomPermissions.write.isAllowed(writeOnly),
          isTrue,
        );
        expect(
          ClinicalFollowUpsAtomPermissions.success.isAllowed(writeOnly),
          isTrue,
        );
      },
    );

    test(
      'write ∪: platform:admin satisfies mark/reschedule without clinical:write',
      () {
        final AppAccessPolicy adminReader = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.platformAdmin,
          },
        );
        expect(ClinicalFollowUpsAtomPermissions.tab.isAllowed(adminReader),
            isTrue);
        expect(ClinicalFollowUpsAtomPermissions.write.isAllowed(adminReader),
            isTrue);
        expect(
          ClinicalFollowUpsAtomPermissions.markCompleted.isAllowed(adminReader),
          isTrue,
        );
        expect(
          ClinicalFollowUpsAtomPermissions.reschedule.isAllowed(adminReader),
          isTrue,
        );
        expect(
          ClinicalFollowUpsAtomPermissions.saveFollowUp.isAllowed(adminReader),
          isTrue,
        );
        expect(
          ClinicalFollowUpsAtomPermissions.success.isAllowed(adminReader),
          isTrue,
        );
        expect(
          ClinicalFollowUpsAtomPermissions.validation.isAllowed(adminReader),
          isTrue,
        );
      },
    );

    test('subscription strips Follow-ups when encounters-vitals inactive', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(ClinicalFollowUpsAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(ClinicalFollowUpsAtomPermissions.write.isAllowed(noModule), isFalse);
    });

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
          ],
        );
        expect(receptionFollowUpsRequirement.isAllowed(patientReader), isTrue);
        expect(
          clinicalFollowUpsRequirement.isAllowed(patientReader),
          isFalse,
        );
      },
    );

    test(
      'nested cross-module _(n/a)_: Follow-ups write does not grant lab/radiology',
      () {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        );
        expect(ClinicalFollowUpsAtomPermissions.write.isAllowed(writer), isTrue);
        expect(clinicalLabOrderWriteRequirement.isAllowed(writer), isTrue);
        expect(
          clinicalRadiologyOrderWriteRequirement.isAllowed(writer),
          isTrue,
        );
        // Lab-only write without clinical does not unlock Follow-ups mutations.
        final AppAccessPolicy labOnly = _policy(
          permissions: <AppPermission>{AppPermissions.labWrite},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
            AppModuleEntitlement(code: 'lab-workflows', licenseStatus: 'ACTIVE'),
          ],
        );
        expect(ClinicalFollowUpsAtomPermissions.tab.isAllowed(labOnly), isFalse);
        expect(
          ClinicalFollowUpsAtomPermissions.write.isAllowed(labOnly),
          isFalse,
        );
      },
    );
  });

  testWidgets(
    '∩ denial: without clinical:read, Follow-ups tab and panel are absent',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalWrite},
        ),
      );

      expect(_tab('Follow-ups'), findsNothing);
      expect(find.byType(FollowUpWorklistPanel), findsNothing);
      expect(find.text('Follow Up Patient'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      // Worklist tabs also require clinical:read — write-only omits strip chrome.
      expect(find.byType(AppTabStrip), findsNothing);
      expect(_tab('Pending'), findsNothing);
    },
  );

  testWidgets(
    'authorized read ∩: Follow-ups list mounts; write actions absent',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
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
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
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
          'fu-clinical-1',
          notes: any(named: 'notes'),
        ),
      ).called(1);
      expect(find.text('Follow Up Patient'), findsNothing);
      expect(find.text('No scheduled follow-ups'), findsOneWidget);
    },
  );

  testWidgets(
    'write ∪: platform:admin mounts Mark completed without clinical:write',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.platformAdmin,
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
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
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
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
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
      clinicalRepository: clinicalRepository,
      opdRepository: opdRepository,
      ipdRepository: ipdRepository,
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
      clinicalRepository: clinicalRepository,
      opdRepository: opdRepository,
      ipdRepository: ipdRepository,
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
        initialLocation: '/clinical?section=follow-ups',
        routes: <RouteBase>[
          GoRoute(
            path: '/clinical',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: ClinicalWorkspacePage(
                  initialQuery: ClinicalWorkspaceQuery.fromUri(state.uri),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clinicalRepositoryProvider.overrideWithValue(clinicalRepository),
            opdRepositoryProvider.overrideWithValue(opdRepository),
            ipdRepositoryProvider.overrideWithValue(ipdRepository),
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
      // Clinical workspace stubs resolve; Follow-ups list stays pending.
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
      clinicalRepository: clinicalRepository,
      opdRepository: opdRepository,
      ipdRepository: ipdRepository,
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
      clinicalRepository: clinicalRepository,
      opdRepository: opdRepository,
      ipdRepository: ipdRepository,
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
      clinicalRepository: clinicalRepository,
      opdRepository: opdRepository,
      ipdRepository: ipdRepository,
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
      clinicalRepository: clinicalRepository,
      opdRepository: opdRepository,
      ipdRepository: ipdRepository,
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
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(permissions: <AppPermission>{}),
        initialLocation: '/clinical?section=follow-ups',
      );

      expect(_tab('Follow-ups'), findsNothing);
      expect(find.byType(FollowUpWorklistPanel), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(_tab('Pending'), findsNothing);
    },
  );

  testWidgets(
    'Export/Print omit without evidence:export; present when granted',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );
      expect(find.text('Export'), findsNothing);
      expect(find.text('Print'), findsNothing);

      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.evidenceExport,
          },
        ),
      );
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    },
  );

  testWidgets(
    'defaults five data columns; Follow-ups count tone is info; Settings lists choices',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.evidenceExport,
          },
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
      expect(find.textContaining('TABLE SETTINGS'), findsOneWidget);
      expect(find.text('Patient ID'), findsWidgets);
      expect(find.text('Email'), findsWidgets);
      expect(find.text('Notes'), findsWidgets);
      expect(find.text('Close'), findsWidgets);
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Advanced filters footer is Clear filters → Apply filters → Close',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ADVANCED FILTERS'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
      expect(find.text('Apply filters'), findsOneWidget);
      expect(find.text('Close'), findsWidgets);
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('ADVANCED FILTERS'), findsNothing);
    },
  );

  testWidgets(
    'active Follow-ups badge uses filtered total when search narrows',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
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

  testWidgets('deep link section=followups opens Follow-ups', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: '/clinical?section=followups',
      routes: <RouteBase>[
        GoRoute(
          path: '/clinical',
          builder: (BuildContext context, GoRouterState state) {
            return Scaffold(
              body: ClinicalWorkspacePage(
                initialQuery: ClinicalWorkspaceQuery.fromUri(state.uri),
              ),
            );
          },
        ),
      ],
    );

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clinicalRepositoryProvider.overrideWithValue(clinicalRepository),
          opdRepositoryProvider.overrideWithValue(opdRepository),
          ipdRepositoryProvider.overrideWithValue(ipdRepository),
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
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(_tab('Follow-ups'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.queryParameters,
      containsPair('section', 'follow-ups'),
    );
  });
}

Future<void> _pumpFollowUpsTab(
  WidgetTester tester, {
  required _MockClinicalRepository clinicalRepository,
  required _MockOpdRepository opdRepository,
  required _MockIpdRepository ipdRepository,
  required _MockFollowUpRepository followUpRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/clinical?section=follow-ups',
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
        path: '/clinical',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: ClinicalWorkspacePage(
              initialQuery: ClinicalWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clinicalRepositoryProvider.overrideWithValue(clinicalRepository),
        opdRepositoryProvider.overrideWithValue(opdRepository),
        ipdRepositoryProvider.overrideWithValue(ipdRepository),
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

void _stubClinical(_MockClinicalRepository repository) {
  when(() => repository.listEncounters(any())).thenAnswer(
    (Invocation invocation) async =>
        Result<AppPage<ClinicalWorklistEntry>>.success(
      AppPage<ClinicalWorklistEntry>(
        items: const <ClinicalWorklistEntry>[],
        request:
            (invocation.positionalArguments.single as ClinicalWorklistQuery)
                .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listAdmissions(any())).thenAnswer(
    (Invocation invocation) async =>
        Result<AppPage<ClinicalWorklistEntry>>.success(
      AppPage<ClinicalWorklistEntry>(
        items: const <ClinicalWorklistEntry>[],
        request:
            (invocation.positionalArguments.single as ClinicalWorklistQuery)
                .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(repository.loadReferenceData).thenAnswer(
    (_) async =>
        const Result<ClinicalReferenceData>.success(ClinicalReferenceData()),
  );
}

void _stubOpd(_MockOpdRepository repository) {
  when(() => repository.listOpdFlows(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request: (invocation.positionalArguments.single as OpdTriageQueueQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
}

void _stubIpd(_MockIpdRepository repository) {
  when(() => repository.listAdmissions(any())).thenAnswer(
    (Invocation invocation) async =>
        Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: const <IpdAdmissionSummary>[],
        request: (invocation.positionalArguments.single as IpdAdmissionQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
}

void _stubFollowUps(
  _MockFollowUpRepository repository, {
  List<ReceptionFollowUpEntry>? entries,
}) {
  final List<ReceptionFollowUpEntry> worklist =
      entries ?? <ReceptionFollowUpEntry>[_followUp];
  when(
    () => repository.listScheduledFollowUps(
      encounterType: any(named: 'encounterType'),
    ),
  ).thenAnswer(
    (_) async => Result<List<ReceptionFollowUpEntry>>.success(worklist),
  );
}
