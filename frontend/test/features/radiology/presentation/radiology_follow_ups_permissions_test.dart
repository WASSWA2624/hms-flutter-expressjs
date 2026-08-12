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
import 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart';
import 'package:hosspi_hms/features/radiology/data/repositories/radiology_repository_impl.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/domain/repositories/radiology_repository.dart';
import 'package:hosspi_hms/features/radiology/presentation/pages/radiology_workspace_page.dart';
import 'package:hosspi_hms/features/radiology/presentation/radiology_access.dart';
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

class _MockRadiologyRepository extends Mock implements RadiologyRepository {}

class _MockFollowUpRepository extends Mock
    implements ReceptionFollowUpRepository {}

final ReceptionFollowUpEntry _followUp = ReceptionFollowUpEntry(
  id: 'fu-rad-1',
  encounterId: 'enc-1',
  patientId: 'pat-1',
  patientIdentifier: 'PAT-FU-RAD1',
  patientDisplayName: 'Follow Up Patient',
  patientPhone: '+256700000001',
  scheduledAt: DateTime.utc(2026, 7, 29, 9, 30),
  notes: 'Radiology callback',
  status: 'SCHEDULED',
);

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['RADIOLOGIST'],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalRead ||
        permission == AppPermissions.clinicalWrite,
  );
  final bool needsBilling = permissions.contains(AppPermissions.billingRead);
  final List<AppModuleEntitlement> resolvedModules =
      modules ??
      <AppModuleEntitlement>[
        const AppModuleEntitlement(
          code: radiologyWorkflowsModule,
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
  late _MockRadiologyRepository radiologyRepository;
  late _MockFollowUpRepository followUpRepository;

  setUpAll(() {
    registerFallbackValue(const RadiologyWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    radiologyRepository = _MockRadiologyRepository();
    followUpRepository = _MockFollowUpRepository();
    _stubRadiology(radiologyRepository);
    _stubFollowUps(followUpRepository);
  });

  group('RadiologyFollowUpsAtomPermissions helpers', () {
    test('reuses radiology Follow-ups requirements (no second vocabulary)', () {
      expect(
        RadiologyFollowUpsAtomPermissions.tab,
        same(radiologyFollowUpsRequirement),
      );
      expect(
        RadiologyFollowUpsAtomPermissions.write,
        same(radiologyFollowUpsWriteRequirement),
      );
      expect(
        RadiologyFollowUpsAtomPermissions.write,
        same(radiologyWorkspaceWriteRequirement),
      );
      expect(
        RadiologyFollowUpsAtomPermissions.export,
        same(radiologyWorkspaceExportRequirement),
      );
      expect(
        RadiologyFollowUpsAtomPermissions.print,
        same(radiologyWorkspacePrintRequirement),
      );
      expect(
        RadiologyFollowUpsAtomPermissions.success,
        same(radiologyFollowUpsWriteRequirement),
      );
      expect(
        RadiologyFollowUpsAtomPermissions.validation,
        same(radiologyFollowUpsWriteRequirement),
      );
      expect(
        radiologySectionTabRequirement(RadiologyDeskSection.followUps),
        same(radiologyFollowUpsRequirement),
      );
      expect(
        radiologyStripCreateRequirement(RadiologyDeskSection.followUps),
        same(RadiologyFollowUpsAtomPermissions.create),
      );
      expect(
        radiologyStripConfigureRequirement(RadiologyDeskSection.followUps),
        same(RadiologyFollowUpsAtomPermissions.configure),
      );
      expect(
        RadiologyFollowUpsAtomPermissions.routeEntry,
        same(radiologyWorkspaceRouteEntryRequirement),
      );
      expect(
        RadiologyFollowUpsAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.radiologyEntry),
      );
      expect(
        RadiologyFollowUpsAtomPermissions.requestFromClinical,
        same(clinicalRadiologyOrderWriteRequirement),
      );
      expect(
        RadiologyFollowUpsAtomPermissions.billingHold,
        same(radiologyBillingHoldReadRequirement),
      );
    });

    test('∩ denial: missing radiology:write hides Follow-ups write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.radiologyRead},
      );
      expect(RadiologyFollowUpsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(RadiologyFollowUpsAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        RadiologyFollowUpsAtomPermissions.markCompleted.isAllowed(reader),
        isFalse,
      );
      expect(
        RadiologyFollowUpsAtomPermissions.reschedule.isAllowed(reader),
        isFalse,
      );
      expect(RadiologyFollowUpsAtomPermissions.success.isAllowed(reader), isFalse);
      expect(canWriteRadiologyFollowUps(reader), isFalse);
    });

    test('∩ denial: missing radiology:read hides Follow-ups tab', () {
      final AppAccessPolicy writerOnly = _policy(
        permissions: <AppPermission>{AppPermissions.radiologyWrite},
      );
      expect(
        RadiologyFollowUpsAtomPermissions.tab.isAllowed(writerOnly),
        isFalse,
      );
      expect(canViewRadiologyFollowUps(writerOnly), isFalse);
      expect(canReadRadiologyFollowUps(writerOnly), isFalse);
    });

    test('write ∩ presence: radiology:write + module allows mutations', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.radiologyRead,
          AppPermissions.radiologyWrite,
        },
      );
      expect(RadiologyFollowUpsAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        RadiologyFollowUpsAtomPermissions.markCompleted.isAllowed(writer),
        isTrue,
      );
      expect(
        RadiologyFollowUpsAtomPermissions.saveFollowUp.isAllowed(writer),
        isTrue,
      );
      expect(canWriteRadiologyFollowUps(writer), isTrue);
    });

    test('mapping note: matrix ∩ radiology:write via allPermissions', () {
      expect(
        radiologyFollowUpsWriteRequirement.allPermissions,
        <AppPermission>[AppPermissions.radiologyWrite],
      );
      expect(radiologyFollowUpsWriteRequirement.anyPermissions, isEmpty);
      expect(
        radiologyFollowUpsWriteRequirement.activeModules,
        contains(radiologyWorkflowsModule),
      );
    });

    test('∩ allowance: radiology:read alone satisfies Follow-ups read', () {
      final AppAccessPolicy radiologyReader = _policy(
        permissions: <AppPermission>{AppPermissions.radiologyRead},
      );
      expect(
        RadiologyFollowUpsAtomPermissions.tab.isAllowed(radiologyReader),
        isTrue,
      );
      expect(
        RadiologyFollowUpsAtomPermissions.search.isAllowed(radiologyReader),
        isTrue,
      );
      expect(canViewRadiologyFollowUps(radiologyReader), isTrue);
      expect(canReadRadiologyFollowUps(radiologyReader), isTrue);
    });

    test(
      '∪ allowance: clinical:read satisfies route entry, not Follow-ups tab',
      () {
        final AppAccessPolicy clinical = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        );
        expect(
          RadiologyFollowUpsAtomPermissions.routeEntry.isAllowed(clinical),
          isTrue,
        );
        expect(
          RadiologyFollowUpsAtomPermissions.tab.isAllowed(clinical),
          isFalse,
        );
        expect(canViewRadiologyFollowUps(clinical), isFalse);
        expect(canEnterRadiologyWorkspace(clinical), isTrue);
        expect(
          radiologyAllowedSections(clinical),
          isNot(contains(RadiologyDeskSection.followUps)),
        );
        expect(
          radiologyAllowedSections(clinical),
          contains(RadiologyDeskSection.worklist),
        );
      },
    );

    test(
      '∪ allowance: billing:read satisfies route entry, not Follow-ups tab',
      () {
        final AppAccessPolicy billing = _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING_CLERK'],
        );
        expect(
          RadiologyFollowUpsAtomPermissions.routeEntry.isAllowed(billing),
          isTrue,
        );
        expect(
          RadiologyFollowUpsAtomPermissions.tab.isAllowed(billing),
          isFalse,
        );
        expect(
          RadiologyFollowUpsAtomPermissions.billingHold.isAllowed(billing),
          isTrue,
        );
        expect(canViewRadiologyFollowUps(billing), isFalse);
      },
    );

    test(
      '∪ allowance: clinical:write satisfies route entry, not Follow-ups write',
      () {
        final AppAccessPolicy clinicalWriter = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalWrite},
          roles: const <String>['DOCTOR'],
        );
        expect(
          RadiologyFollowUpsAtomPermissions.routeEntry.isAllowed(clinicalWriter),
          isTrue,
        );
        expect(
          RadiologyFollowUpsAtomPermissions.tab.isAllowed(clinicalWriter),
          isFalse,
        );
        expect(
          RadiologyFollowUpsAtomPermissions.write.isAllowed(clinicalWriter),
          isFalse,
        );
        expect(
          RadiologyFollowUpsAtomPermissions.requestFromClinical.isAllowed(
            clinicalWriter,
          ),
          isTrue,
        );
      },
    );

    test(
      'subscription strips Follow-ups when radiology-workflows inactive',
      () {
        final AppAccessPolicy noModule = _policy(
          permissions: <AppPermission>{
            AppPermissions.radiologyRead,
            AppPermissions.radiologyWrite,
          },
          modules: const <AppModuleEntitlement>[],
        );
        expect(
          RadiologyFollowUpsAtomPermissions.tab.isAllowed(noModule),
          isFalse,
        );
        expect(
          RadiologyFollowUpsAtomPermissions.write.isAllowed(noModule),
          isFalse,
        );
      },
    );

    test(
      'ABAC: missing facility still allows Follow-ups chrome '
      '(row/own scope remains backend-authoritative)',
      () {
        final AppAccessPolicy noFacility = _policy(
          permissions: <AppPermission>{
            AppPermissions.radiologyRead,
            AppPermissions.radiologyWrite,
          },
          facilityId: null,
        );
        expect(noFacility.hasFacilityContext, isFalse);
        expect(
          RadiologyFollowUpsAtomPermissions.tab.isAllowed(noFacility),
          isTrue,
        );
        expect(
          RadiologyFollowUpsAtomPermissions.write.isAllowed(noFacility),
          isTrue,
        );
        expect(
          RadiologyFollowUpsAtomPermissions.routeEntry.isAllowed(noFacility),
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
              code: radiologyWorkflowsModule,
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          receptionFollowUpsRequirement.isAllowed(patientReader),
          isTrue,
        );
        expect(
          radiologyFollowUpsRequirement.isAllowed(patientReader),
          isFalse,
        );
      },
    );

    test(
      'nested cross-module _(n/a)_: Follow-ups write does not grant billing hold',
      () {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.radiologyRead,
            AppPermissions.radiologyWrite,
          },
        );
        expect(RadiologyFollowUpsAtomPermissions.write.isAllowed(writer), isTrue);
        expect(
          RadiologyFollowUpsAtomPermissions.billingHold.isAllowed(writer),
          isFalse,
        );
        expect(writer.grants(AppPermissions.billingRead), isFalse);
        expect(writer.grants(AppPermissions.clinicalWrite), isFalse);
      },
    );
  });

  testWidgets(
    '∩ denial: without radiology:read, Follow-ups tab and panel absent',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        radiologyRepository: radiologyRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        ),
      );

      expect(_tab('Follow-ups'), findsNothing);
      expect(find.byType(FollowUpWorklistPanel), findsNothing);
      expect(find.text('Follow Up Patient'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      // Route ∪ still mounts worklist chrome without Follow-ups.
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byTooltip('Request imaging'), findsNothing);
      expect(find.byTooltip('Configurations'), findsNothing);
    },
  );

  testWidgets(
    'subscription strips Follow-ups tab when radiology-workflows inactive',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        radiologyRepository: radiologyRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.radiologyRead,
            AppPermissions.radiologyWrite,
          },
          modules: const <AppModuleEntitlement>[],
        ),
      );

      expect(_tab('Follow-ups'), findsNothing);
      expect(find.byType(FollowUpWorklistPanel), findsNothing);
      expect(find.text('Mark completed'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized read ∩: radiology:read mounts list; write actions absent',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        radiologyRepository: radiologyRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.radiologyRead},
        ),
      );

      expect(_tab('Follow-ups'), findsOneWidget);
      expect(find.byType(FollowUpWorklistPanel), findsOneWidget);
      expect(find.text('Follow Up Patient'), findsOneWidget);
      expect(find.text('Reschedule follow-up'), findsNothing);
      expect(find.text('Mark completed'), findsNothing);
      expect(find.byTooltip('Request imaging'), findsNothing);
      expect(find.byTooltip('Configurations'), findsNothing);

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Reschedule follow-up'), findsNothing);
      expect(find.text('Mark completed'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'Follow-ups toolbar: Filters/Settings, ≤5 columns, info tone, Close',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        radiologyRepository: radiologyRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.radiologyRead,
            AppPermissions.radiologyWrite,
          },
        ),
      );

      final AppListTable<ReceptionFollowUpEntry> table =
          tester.widget<AppListTable<ReceptionFollowUpEntry>>(
            find.byType(AppListTable<ReceptionFollowUpEntry>),
          );
      expect(table.columnVisibilityLabel, 'Settings');
      expect(table.search?.advancedFilterButtonLabel, 'Filters');
      expect(table.search?.advancedFilterTitle, 'Advanced filters');
      expect(table.search?.advancedFilterApplyLabel, 'Apply filters');
      expect(table.search?.advancedFilterResetLabel, 'Clear filters');
      expect(table.search?.advancedFilterCloseLabel, 'Close');
      expect(table.enablePrint, isTrue);
      expect(table.canExport, isFalse);
      expect(table.canPrint, isFalse);
      expect(table.columns.length, lessThanOrEqualTo(5));
      expect(table.columnChoices, isNotEmpty);
      expect(table.columnVisibilityStorageKey, 'radiology_follow_ups_cols');
      expect(find.byTooltip('Export'), findsNothing);
      expect(find.byTooltip('Request imaging'), findsNothing);
      expect(find.byTooltip('Configurations'), findsNothing);

      final AppTabStrip strip = tester.widget<AppTabStrip>(
        find.byType(AppTabStrip),
      );
      final AppTabItem followUps = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.label.contains('Follow-ups'),
      );
      expect(followUps.countTone, AppTabCountTone.info);
      expect(followUps.count, isNotNull);
    },
  );

  testWidgets(
    'Follow-ups Export/Print omit without evidence:export; present when granted',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        radiologyRepository: radiologyRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.radiologyRead,
            AppPermissions.radiologyWrite,
          },
        ),
      );
      expect(find.byTooltip('Export'), findsNothing);
      expect(find.byTooltip('Print'), findsNothing);

      await _pumpFollowUpsTab(
        tester,
        radiologyRepository: radiologyRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.radiologyRead,
            AppPermissions.radiologyWrite,
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
      expect(find.byTooltip('Request imaging'), findsNothing);
    },
  );

  testWidgets(
    '∪ allowance: clinical:read mounts radiology worklist without Follow-ups',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        radiologyRepository: radiologyRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        ),
        initialLocation: '/radiology?section=follow-ups',
      );

      expect(_tab('Follow-ups'), findsNothing);
      expect(find.byType(FollowUpWorklistPanel), findsNothing);
      expect(find.byType(AppTabStrip), findsOneWidget);
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
        radiologyRepository: radiologyRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.radiologyRead,
            AppPermissions.radiologyWrite,
          },
        ),
      );

      expect(find.text('Follow Up Patient'), findsOneWidget);
      expect(find.byTooltip('Request imaging'), findsNothing);

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
          'fu-rad-1',
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
        radiologyRepository: radiologyRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.radiologyRead,
            AppPermissions.radiologyWrite,
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
        radiologyRepository: radiologyRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.radiologyRead,
            AppPermissions.radiologyWrite,
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
      radiologyRepository: radiologyRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.radiologyRead},
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
      radiologyRepository: radiologyRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.radiologyRead},
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
        initialLocation: '/radiology?section=follow-ups',
        routes: <RouteBase>[
          GoRoute(
            path: '/radiology',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: RadiologyWorkspacePage(
                  initialQuery: RadiologyWorkspaceQuery.fromUri(state.uri),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            radiologyRepositoryProvider.overrideWithValue(radiologyRepository),
            receptionFollowUpRepositoryProvider.overrideWithValue(
              followUpRepository,
            ),
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(
              _policy(
                permissions: <AppPermission>{AppPermissions.radiologyRead},
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
      radiologyRepository: radiologyRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.radiologyRead,
          AppPermissions.radiologyWrite,
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
      radiologyRepository: radiologyRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.radiologyRead,
          AppPermissions.radiologyWrite,
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
      radiologyRepository: radiologyRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.radiologyRead,
          AppPermissions.radiologyWrite,
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
      radiologyRepository: radiologyRepository,
      followUpRepository: followUpRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.radiologyRead,
          AppPermissions.radiologyWrite,
        },
      ),
      themeMode: ThemeMode.dark,
    );

    expect(find.text('Follow Up Patient'), findsOneWidget);
    expect(_tab('Follow-ups'), findsOneWidget);
  });

  testWidgets(
    'deep link section=follow-ups without radiology:read falls back off Follow-ups',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        radiologyRepository: radiologyRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        ),
        initialLocation: '/radiology?section=follow-ups',
      );

      expect(_tab('Follow-ups'), findsNothing);
      expect(find.byType(FollowUpWorklistPanel), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );
}

Future<void> _pumpFollowUpsTab(
  WidgetTester tester, {
  required _MockRadiologyRepository radiologyRepository,
  required _MockFollowUpRepository followUpRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/radiology?section=follow-ups',
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
        path: '/radiology',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: RadiologyWorkspacePage(
              initialQuery: RadiologyWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        radiologyRepositoryProvider.overrideWithValue(radiologyRepository),
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

void _stubRadiology(_MockRadiologyRepository repository) {
  when(
    () => repository.getReferenceData(
      search: any(named: 'search'),
      patientId: any(named: 'patientId'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer(
    (_) async =>
        const Result<RadiologyReferenceData>.success(RadiologyReferenceData()),
  );
  when(() => repository.getWorkbench(any())).thenAnswer(
    (_) async => Result<RadiologyWorkbench>.success(
      RadiologyWorkbench(
        summary: const RadiologySummary(
          totalOrders: 0,
          orderedQueue: 0,
          processingQueue: 0,
          draftReports: 0,
          finalizedReports: 0,
          actionablePatients: 0,
          reportingPatients: 0,
          releasedPatients: 0,
          totalPatients: 0,
        ),
        orders: AppPage<RadiologyOrder>(
          items: const <RadiologyOrder>[],
          request: const AppPageRequest(pageSize: 12),
          totalItemCount: 0,
        ),
      ),
    ),
  );
  when(
    () => repository.listRadiologyCatalogProcedures(
      search: any(named: 'search'),
      includeStandardCatalog: any(named: 'includeStandardCatalog'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<RadiologyCatalogProcedure>>.success(
      <RadiologyCatalogProcedure>[],
    ),
  );
  when(
    () => repository.listFacilityRadiologyProcedures(
      tenantId: any(named: 'tenantId'),
      facilityId: any(named: 'facilityId'),
      search: any(named: 'search'),
      page: any(named: 'page'),
      limit: any(named: 'limit'),
      offeredOnly: any(named: 'offeredOnly'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<RadiologyCatalogProcedure>>.success(
      <RadiologyCatalogProcedure>[],
    ),
  );
  when(
    () => repository.listEquipmentRecords(search: any(named: 'search')),
  ).thenAnswer(
    (_) async => const Result<List<RadiologyEquipmentRecord>>.success(
      <RadiologyEquipmentRecord>[],
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
