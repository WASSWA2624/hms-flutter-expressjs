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
import 'package:hosspi_hms/features/discharge/data/repositories/discharge_repository_impl.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/domain/repositories/discharge_repository.dart';
import 'package:hosspi_hms/features/discharge/presentation/discharge_access.dart';
import 'package:hosspi_hms/features/discharge/presentation/pages/discharge_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
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

class _MockDischargeRepository extends Mock implements DischargeRepository {}

class _MockFollowUpRepository extends Mock
    implements ReceptionFollowUpRepository {}

final ReceptionFollowUpEntry _followUp = ReceptionFollowUpEntry(
  id: 'fu-discharge-1',
  encounterId: 'enc-1',
  patientId: 'pat-1',
  patientIdentifier: 'PAT-FU-D1',
  patientDisplayName: 'Follow Up Patient',
  patientPhone: '+256700000001',
  scheduledAt: DateTime.utc(2026, 7, 29, 9, 30),
  notes: 'Post-discharge callback',
  status: 'SCHEDULED',
);

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: 'inpatient-bed-management',
      licenseStatus: 'ACTIVE',
    ),
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
  late _MockDischargeRepository dischargeRepository;
  late _MockFollowUpRepository followUpRepository;

  setUpAll(() {
    registerFallbackValue(const DischargeWorklistQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    dischargeRepository = _MockDischargeRepository();
    followUpRepository = _MockFollowUpRepository();
    _stubDischarge(dischargeRepository);
    _stubFollowUps(followUpRepository);
  });

  group('DischargeFollowUpsAtomPermissions helpers', () {
    test('reuses discharge Follow-ups requirements (no second vocabulary)', () {
      expect(
        DischargeFollowUpsAtomPermissions.tab,
        same(dischargeFollowUpsRequirement),
      );
      expect(
        DischargeFollowUpsAtomPermissions.write,
        same(dischargeFollowUpsWriteRequirement),
      );
      expect(
        dischargeSectionTabRequirement(DischargeDeskSection.followUps),
        same(dischargeFollowUpsRequirement),
      );
      expect(
        DischargeFollowUpsAtomPermissions.routeEntry,
        same(dischargeWorkspaceEntryRequirement),
      );
      expect(
        DischargeFollowUpsAtomPermissions.export,
        same(dischargeWorkspaceExportRequirement),
      );
      expect(
        DischargeFollowUpsAtomPermissions.print,
        same(dischargeWorkspacePrintRequirement),
      );
    });

    test('export/print toolbar atoms omit without evidence:export', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(
        DischargeFollowUpsAtomPermissions.export.isAllowed(reader),
        isFalse,
      );
      expect(
        DischargeFollowUpsAtomPermissions.print.isAllowed(reader),
        isFalse,
      );
      final AppAccessPolicy withExport = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.evidenceExport,
        },
      );
      expect(
        DischargeFollowUpsAtomPermissions.export.isAllowed(withExport),
        isTrue,
      );
      expect(
        DischargeFollowUpsAtomPermissions.print.isAllowed(withExport),
        isTrue,
      );
    });

    test('∩ denial: missing clinical:write hides Follow-ups write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(DischargeFollowUpsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(DischargeFollowUpsAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        DischargeFollowUpsAtomPermissions.markCompleted.isAllowed(reader),
        isFalse,
      );
      expect(
        DischargeFollowUpsAtomPermissions.reschedule.isAllowed(reader),
        isFalse,
      );
      expect(canWriteDischargeFollowUps(reader), isFalse);
    });

    test('∩ presence: clinical:write + module allows Follow-ups mutations', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(DischargeFollowUpsAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        DischargeFollowUpsAtomPermissions.markCompleted.isAllowed(writer),
        isTrue,
      );
      expect(
        DischargeFollowUpsAtomPermissions.saveFollowUp.isAllowed(writer),
        isTrue,
      );
    });

    test('∪ allowance: last_office:read alone satisfies Follow-ups read', () {
      final AppAccessPolicy lastOffice = _policy(
        permissions: <AppPermission>{AppPermissions.lastOfficeRead},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'inpatient-bed-management',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        DischargeFollowUpsAtomPermissions.tab.isAllowed(lastOffice),
        isTrue,
      );
      expect(
        DischargeFollowUpsAtomPermissions.search.isAllowed(lastOffice),
        isTrue,
      );
      expect(
        DischargeFollowUpsAtomPermissions.write.isAllowed(lastOffice),
        isFalse,
      );
      expect(canReadDischargeFollowUps(lastOffice), isTrue);
    });

    test('∪ allowance: clinical:read alone satisfies Follow-ups read', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(DischargeFollowUpsAtomPermissions.tab.isAllowed(clinical), isTrue);
      expect(canViewDischargeSection(clinical, DischargeDeskSection.followUps),
          isTrue);
    });

    test(
      'route entry ∩: discharge:read satisfies entry, not Follow-ups tab',
      () {
        // Source RouteAccessCatalog uses discharge:read (prompt any-of
        // clinical/pharmacy/billing/operations is superseded).
        final AppAccessPolicy entryOnly = _policy(
          permissions: <AppPermission>{AppPermissions.dischargeRead},
          roles: const <String>['PHARMACIST'],
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'inpatient-bed-management',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          DischargeFollowUpsAtomPermissions.routeEntry.isAllowed(entryOnly),
          isTrue,
        );
        expect(
          DischargeFollowUpsAtomPermissions.tab.isAllowed(entryOnly),
          isFalse,
        );
      },
    );

    test(
      'subscription strips Follow-ups when inpatient-bed-management inactive',
      () {
        final AppAccessPolicy noModule = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.lastOfficeRead,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          DischargeFollowUpsAtomPermissions.tab.isAllowed(noModule),
          isFalse,
        );
        expect(
          DischargeFollowUpsAtomPermissions.write.isAllowed(noModule),
          isFalse,
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
              code: 'inpatient-bed-management',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(receptionFollowUpsRequirement.isAllowed(patientReader), isTrue);
        expect(
          dischargeFollowUpsRequirement.isAllowed(patientReader),
          isFalse,
        );
      },
    );

    test(
      'nested cross-module _(n/a)_: Follow-ups write does not grant pharmacy/billing',
      () {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        );
        expect(DischargeFollowUpsAtomPermissions.write.isAllowed(writer), isTrue);
        expect(writer.grants(AppPermissions.pharmacyWrite), isFalse);
        expect(writer.grants(AppPermissions.billingWrite), isFalse);
        // Pharmacy-only write without clinical/last_office does not unlock tab.
        final AppAccessPolicy pharmacyOnly = _policy(
          permissions: <AppPermission>{AppPermissions.pharmacyWrite},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'inpatient-bed-management',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'pharmacy-dispensing',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          DischargeFollowUpsAtomPermissions.tab.isAllowed(pharmacyOnly),
          isFalse,
        );
        expect(
          DischargeFollowUpsAtomPermissions.write.isAllowed(pharmacyOnly),
          isFalse,
        );
      },
    );

    test(
      'planning write source differs from Follow-ups ∩ clinical:write mapping',
      () {
        // Source planning gate keeps role pack ∪ clinical:write; Follow-ups
        // mutations use matrix ∩ clinical:write (documented in tests).
        expect(
          dischargeClinicalWriteRequirement.anyPermissions,
          contains(AppPermissions.clinicalWrite),
        );
        expect(
          dischargeFollowUpsWriteRequirement.allPermissions,
          contains(AppPermissions.clinicalWrite),
        );
      },
    );
  });

  testWidgets(
    '∪ denial: without clinical:read or last_office:read, Follow-ups absent',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        dischargeRepository: dischargeRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          // Pending clearance read ∪ includes pharmacy:read; Follow-ups / All /
          // Planned / Completed still need clinical|last_office read ∪.
          permissions: <AppPermission>{AppPermissions.pharmacyRead},
          roles: const <String>['PHARMACIST'],
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'inpatient-bed-management',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'pharmacy-dispensing',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );

      expect(_tab('Follow-ups'), findsNothing);
      expect(find.byType(FollowUpWorklistPanel), findsNothing);
      expect(find.text('Follow Up Patient'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.textContaining('Pending clearance'), findsWidgets);
      expect(find.textContaining('All patients'), findsNothing);
      expect(_tab('Planned'), findsNothing);
    },
  );

  testWidgets(
    '∪ allowance: last_office:read mounts Follow-ups; write actions absent',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        dischargeRepository: dischargeRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.lastOfficeRead},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'inpatient-bed-management',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );

      expect(_tab('Follow-ups'), findsOneWidget);
      expect(find.byType(FollowUpWorklistPanel), findsOneWidget);
      expect(find.text('Follow Up Patient'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byTooltip('Export'), findsNothing);
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
      expect(panel.advancedFilterCloseLabel, 'Close');
      expect(panel.storageKeyPrefix, 'discharge_follow_ups');
      final AppListTable<ReceptionFollowUpEntry> table =
          tester.widget<AppListTable<ReceptionFollowUpEntry>>(
            find.byType(AppListTable<ReceptionFollowUpEntry>),
          );
      expect(table.enablePrint, isTrue);
      expect(table.canExport, isFalse);
      expect(table.canPrint, isFalse);
      expect(table.printLabel, 'Print');
      expect(table.columns.length, 5);
      expect(table.columnVisibilityStorageKey, 'discharge_follow_ups_cols');
      expect(table.columnWidthStorageKey, 'discharge_follow_ups_cw');
      expect(table.search?.advancedFilterCloseLabel, 'Close');
      expect(table.search?.enableDateFilter, isTrue);
      expect(
        table.columns.map(
          (AppListTableColumn<ReceptionFollowUpEntry> column) => column.id,
        ),
        containsAll(<String>['patient', 'phone', 'status', 'date', 'time']),
      );
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
    'Follow-ups Export/Print present with evidence:export; info count tone',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        dischargeRepository: dischargeRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.evidenceExport,
          },
        ),
      );

      final AppTabStrip strip = tester.widget(find.byType(AppTabStrip));
      final AppTabItem followUpsTab = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.id == 'followUps',
      );
      expect(followUpsTab.countTone, AppTabCountTone.info);
      expect(followUpsTab.count, 1);

      final AppListTable<ReceptionFollowUpEntry> table =
          tester.widget<AppListTable<ReceptionFollowUpEntry>>(
            find.byType(AppListTable<ReceptionFollowUpEntry>),
          );
      expect(table.enableExport, isTrue);
      expect(table.canExport, isTrue);
      expect(table.enablePrint, isTrue);
      expect(table.canPrint, isTrue);
      expect(table.printLabel, 'Print');
      expect(find.byTooltip('Export'), findsOneWidget);
      expect(find.byTooltip('Print'), findsOneWidget);
    },
  );

  testWidgets(
    'deep link section=follow_ups alias selects Follow-ups tab',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        dischargeRepository: dischargeRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        initialLocation: '/discharge?section=follow_ups',
      );

      expect(_tab('Follow-ups'), findsOneWidget);
      expect(find.byType(FollowUpWorklistPanel), findsOneWidget);
      expect(find.text('Follow Up Patient'), findsOneWidget);
    },
  );

  testWidgets(
    'authorized read ∪: clinical:read mounts list; ∩ write actions absent',
    (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        dischargeRepository: dischargeRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
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
        dischargeRepository: dischargeRepository,
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
          'fu-discharge-1',
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
        dischargeRepository: dischargeRepository,
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
      dischargeRepository: dischargeRepository,
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
      dischargeRepository: dischargeRepository,
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
        initialLocation: '/discharge?section=follow-ups',
        routes: <RouteBase>[
          GoRoute(
            path: '/discharge',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: DischargeWorkspacePage(
                  initialQuery: DischargeWorklistQuery.fromUri(state.uri),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dischargeRepositoryProvider.overrideWithValue(dischargeRepository),
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
      dischargeRepository: dischargeRepository,
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
      dischargeRepository: dischargeRepository,
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
      dischargeRepository: dischargeRepository,
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
      dischargeRepository: dischargeRepository,
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
        dischargeRepository: dischargeRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          // Pharmacy desk can open Pending clearance but not Follow-ups.
          permissions: <AppPermission>{AppPermissions.pharmacyRead},
          roles: const <String>['PHARMACIST'],
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'inpatient-bed-management',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'pharmacy-dispensing',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
        initialLocation: '/discharge?section=follow-ups',
      );

      expect(_tab('Follow-ups'), findsNothing);
      expect(find.byType(FollowUpWorklistPanel), findsNothing);
      expect(find.textContaining('Pending clearance'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );
}

Future<void> _pumpFollowUpsTab(
  WidgetTester tester, {
  required _MockDischargeRepository dischargeRepository,
  required _MockFollowUpRepository followUpRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/discharge?section=follow-ups',
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
        path: '/discharge',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: DischargeWorkspacePage(
              initialQuery: DischargeWorklistQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dischargeRepositoryProvider.overrideWithValue(dischargeRepository),
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

void _stubDischarge(_MockDischargeRepository repository) {
  when(() => repository.listQueue(any())).thenAnswer(
    (_) async => Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: const <IpdAdmissionSummary>[],
        request: const AppPageRequest(pageSize: 12),
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<DischargeReferenceData>.success(DischargeReferenceData()),
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
