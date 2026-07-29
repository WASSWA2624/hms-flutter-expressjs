import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
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
import 'package:hosspi_hms/features/rooms_beds/data/repositories/rooms_beds_repository_impl.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/repositories/rooms_beds_repository.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/rooms_beds_access.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/widgets/rooms_beds_next_action_button.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/widgets/rooms_beds_status_helpers.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRoomsBedsRepository extends Mock implements RoomsBedsRepository {}

const FacilityProfile _facility = FacilityProfile(
  id: 'FAC-001',
  tenantId: 'TEN-001',
  name: 'Main Campus',
  type: FacilitySetupType.hospital,
);

const WardProfile _ward = WardProfile(
  id: 'WRD-001',
  tenantId: 'TEN-001',
  facilityId: 'FAC-001',
  name: 'Ward A',
  type: WardSetupType.general,
);

const RoomProfile _room = RoomProfile(
  id: 'RM-001',
  tenantId: 'TEN-001',
  facilityId: 'FAC-001',
  wardId: 'WRD-001',
  name: 'Room 1',
  floor: '1',
);

const BedProfile _occupiedBed = BedProfile(
  id: 'BED-OCCUPIED',
  tenantId: 'TEN-001',
  facilityId: 'FAC-001',
  wardId: 'WRD-001',
  roomId: 'RM-001',
  label: 'Bed O1',
  status: BedSetupStatus.occupied,
);

const BedAssignmentRecord _activeAssignment = BedAssignmentRecord(
  id: 'ASN-1',
  admissionId: 'ADM-100',
  bedId: 'BED-OCCUPIED',
  admissionDisplayId: 'IPD-100',
);

const List<AppModuleEntitlement> _inpatientModules = <AppModuleEntitlement>[
  AppModuleEntitlement(
    code: roomsBedsInpatientBedManagementModule,
    licenseStatus: 'ACTIVE',
  ),
  AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(
    code: 'facilities-maintenance',
    licenseStatus: 'ACTIVE',
  ),
  AppModuleEntitlement(code: 'hr-rosters', licenseStatus: 'ACTIVE'),
];

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = _inpatientModules,
  List<String> roles = const <String>['NURSE'],
  String? facilityId = 'FAC-001',
  String? tenantId = 'TEN-001',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

FacilitySetupSnapshot _snapshot({
  List<BedProfile> beds = const <BedProfile>[_occupiedBed],
}) {
  return FacilitySetupSnapshot(
    tenant: const TenantProfile(id: 'TEN-001', name: 'Tenant'),
    facility: _facility,
    facilities: const <FacilityProfile>[_facility],
    wards: const <WardProfile>[_ward],
    rooms: const <RoomProfile>[_room],
    beds: beds,
  );
}

void _stubRepository(
  _MockRoomsBedsRepository repository, {
  List<BedProfile> beds = const <BedProfile>[_occupiedBed],
}) {
  when(
    () => repository.loadSetup(facilityId: any(named: 'facilityId')),
  ).thenAnswer(
    (_) async => Result<FacilitySetupSnapshot>.success(_snapshot(beds: beds)),
  );
  when(() => repository.listBedAssignmentsForBed(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final String bedId = invocation.positionalArguments.single as String;
    if (bedId == _occupiedBed.id) {
      return const Result<List<BedAssignmentRecord>>.success(
        <BedAssignmentRecord>[_activeAssignment],
      );
    }
    return const Result<List<BedAssignmentRecord>>.success(
      <BedAssignmentRecord>[],
    );
  });
  when(() => repository.loadAdmissionContext(any())).thenAnswer(
    (_) async => const Result<BedAdmissionContext>.success(
      BedAdmissionContext(
        admissionId: 'ADM-100',
        admissionDisplayId: 'IPD-100',
      ),
    ),
  );
  when(
    () => repository.releaseBed(admissionId: any(named: 'admissionId')),
  ).thenAnswer((_) async => const Result<void>.success(null));
}

Finder _tabLabel(String label) {
  return find.descendant(
    of: find.byType(AppTabStrip),
    matching: find.textContaining(label),
  );
}

Finder _toolbarAction(String label) => find.descendant(
  of: find.byType(AppTabStrip),
  matching: find.byWidgetPredicate(
    (Widget widget) =>
        widget is AppTabToolbarAction && widget.label == label,
  ),
);

AppListTable<BedBoardItem> _table(WidgetTester tester) {
  return tester.widget<AppListTable<BedBoardItem>>(
    find.byType(AppListTable<BedBoardItem>),
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pumpOccupiedTab(
  WidgetTester tester, {
  required _MockRoomsBedsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/rooms-beds?section=occupied',
  List<BedProfile> beds = const <BedProfile>[_occupiedBed],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, beds: beds);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/rooms-beds',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: RoomsBedsWorkspacePage(
              initialQuery: RoomsBedsQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roomsBedsRepositoryProvider.overrideWithValue(repository),
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
  await _pumpFrames(tester);
}

void main() {
  late _MockRoomsBedsRepository repository;

  setUp(() {
    repository = _MockRoomsBedsRepository();
  });

  group('RoomsBedsOccupiedAtomPermissions helpers (reuse / AC1)', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          RoomsBedsOccupiedAtomPermissions.tab,
          roomsBedsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RoomsBedsOccupiedAtomPermissions.release,
          roomsBedsOccupancyWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RoomsBedsOccupiedAtomPermissions.transfer,
          roomsBedsOccupancyWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RoomsBedsOccupiedAtomPermissions.manageCatalog,
          roomsBedsAdminRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RoomsBedsOccupiedAtomPermissions.create,
          roomsBedsAdminRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RoomsBedsOccupiedAtomPermissions.catalogEntry,
          RouteAccessCatalog.roomsBedsEntry,
        ),
        isTrue,
      );
      expect(
        roomsBedsSectionTabRequirement(RoomsBedsSection.occupied),
        same(RoomsBedsOccupiedAtomPermissions.tab),
      );
    });

    test('inventory atoms map to matrix verbs (read ∪ / admin ∪ / occupancy ∪)', () {
      expect(RoomsBedsOccupiedAtomPermissions.tab, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.listChrome, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.search, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.filters, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.columns, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.settings, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.pagination, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.empty, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.loading, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.retry, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.success, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.validation, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.rowSelect, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.detail, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.nextAction, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.create, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.update, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.delete, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.release, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.transfer, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.completeTransfer, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.manageCatalog, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.nestedOccupancyWrite, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.nestedWrite, isNotNull);
      expect(RoomsBedsOccupiedAtomPermissions.navigateCrossModule, isNotNull);

      expect(
        RoomsBedsOccupiedAtomPermissions.tab.anyPermissions,
        containsAll(<AppPermission>[
          AppPermissions.clinicalRead,
          AppPermissions.operationsRead,
          AppPermissions.facilityAdmin,
        ]),
      );
      expect(
        RoomsBedsOccupiedAtomPermissions.release.anyPermissions,
        containsAll(<AppPermission>[
          AppPermissions.clinicalWrite,
          AppPermissions.operationsWrite,
        ]),
      );
      // Matrix create ∩ unit:manage alone maps to source admin ∪.
      expect(
        RoomsBedsOccupiedAtomPermissions.create.anyPermissions,
        contains(AppPermissions.unitManage),
      );
      expect(
        RoomsBedsOccupiedAtomPermissions.nestedRead,
        same(RoomsBedsOccupiedAtomPermissions.tab),
      );
      expect(
        RoomsBedsOccupiedAtomPermissions.nestedWrite,
        same(RoomsBedsOccupiedAtomPermissions.manageCatalog),
      );
    });

    test('∪ read / occupancy write; ∩-style admin denial without rights', () {
      final AppAccessPolicy clinicalReader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(
        RoomsBedsOccupiedAtomPermissions.tab.isAllowed(clinicalReader),
        isTrue,
      );
      expect(
        RoomsBedsOccupiedAtomPermissions.release.isAllowed(clinicalReader),
        isFalse,
      );
      expect(
        RoomsBedsOccupiedAtomPermissions.create.isAllowed(clinicalReader),
        isFalse,
      );
      expect(
        RoomsBedsOccupiedAtomPermissions.manageCatalog.isAllowed(clinicalReader),
        isFalse,
      );

      final AppAccessPolicy operationsWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      );
      expect(
        RoomsBedsOccupiedAtomPermissions.tab.isAllowed(operationsWriter),
        isTrue,
      );
      expect(
        RoomsBedsOccupiedAtomPermissions.release.isAllowed(operationsWriter),
        isTrue,
      );
      expect(
        RoomsBedsOccupiedAtomPermissions.manageCatalog.isAllowed(
          operationsWriter,
        ),
        isFalse,
      );

      final AppAccessPolicy unitManager = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.unitManage,
        },
        roles: const <String>['UNIT_MANAGER'],
      );
      expect(
        RoomsBedsOccupiedAtomPermissions.create.isAllowed(unitManager),
        isTrue,
      );
      expect(
        RoomsBedsOccupiedAtomPermissions.release.isAllowed(unitManager),
        isFalse,
      );
    });

    test('subscription ∩ strips Occupied UI without inpatient module', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.unitManage,
          AppPermissions.facilityAdmin,
        },
        modules: const <AppModuleEntitlement>[],
        roles: const <String>['FACILITY_ADMIN'],
      );
      expect(RoomsBedsOccupiedAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(
        RoomsBedsOccupiedAtomPermissions.release.isAllowed(noModule),
        isFalse,
      );
      expect(
        RoomsBedsOccupiedAtomPermissions.manageCatalog.isAllowed(noModule),
        isFalse,
      );
    });

    test('nested cross-module matrix rows are n/a (empty navigate gate)', () {
      expect(
        RoomsBedsOccupiedAtomPermissions.navigateCrossModule.isEmpty,
        isTrue,
      );
      expect(
        RoomsBedsOccupiedAtomPermissions.navigateCrossModule.isAllowed(
          _policy(permissions: const <AppPermission>{}),
        ),
        isTrue,
      );
    });
  });

  group('Occupied UI permission enforcement', () {
    testWidgets(
      '∩-style denial: clinical:read Occupied shows list; writes/admin absent',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        );
        expect(
          RoomsBedsOccupiedAtomPermissions.release.isAllowed(reader),
          isFalse,
        );
        expect(
          RoomsBedsOccupiedAtomPermissions.create.isAllowed(reader),
          isFalse,
        );

        await _pumpOccupiedTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        expect(_tabLabel('Occupied'), findsOneWidget);
        expect(find.text('Bed O1'), findsWidgets);
        expect(find.text('Release bed'), findsNothing);
        expect(find.text('Request transfer'), findsNothing);
        expect(find.text('Manage transfer'), findsNothing);
        expect(_toolbarAction('Manage catalog'), findsNothing);
        expect(find.byType(AppTabToolbarPrimary), findsNothing);
        expect(find.textContaining('no access'), findsNothing);

        await tester.tap(find.text('Bed O1').first);
        await _pumpFrames(tester);

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        expect(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Release bed'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Request transfer'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Create room'),
          ),
          findsNothing,
        );
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      '∪ allowance: operations:write alone shows Release; admin create absent',
      (WidgetTester tester) async {
        final AppAccessPolicy operationsWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        );
        expect(
          RoomsBedsOccupiedAtomPermissions.release.isAllowed(operationsWriter),
          isTrue,
        );
        expect(
          RoomsBedsOccupiedAtomPermissions.create.isAllowed(operationsWriter),
          isFalse,
        );

        await _pumpOccupiedTab(
          tester,
          repository: repository,
          accessPolicy: operationsWriter,
        );

        expect(find.text('Bed O1'), findsWidgets);
        expect(find.text('Release bed'), findsWidgets);
        expect(_toolbarAction('Manage catalog'), findsNothing);
        expect(find.byType(AppTabToolbarPrimary), findsNothing);

        await tester.tap(find.text('Bed O1').first);
        await _pumpFrames(tester);

        expect(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Request transfer'),
          ),
          findsOneWidget,
        );
        // Primary next-action is Release, so detail omits the twin.
        expect(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Release bed'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      '∪ allowance: clinical:write shows Release; facility:admin shows catalog',
      (WidgetTester tester) async {
        final AppAccessPolicy clinicalWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        );
        await _pumpOccupiedTab(
          tester,
          repository: repository,
          accessPolicy: clinicalWriter,
        );
        expect(find.text('Release bed'), findsWidgets);
        expect(_toolbarAction('Manage catalog'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        final AppAccessPolicy facilityAdmin = _policy(
          permissions: <AppPermission>{
            AppPermissions.facilityAdmin,
            AppPermissions.clinicalRead,
          },
          roles: const <String>['FACILITY_ADMIN'],
        );
        await _pumpOccupiedTab(
          tester,
          repository: repository,
          accessPolicy: facilityAdmin,
        );
        expect(_toolbarAction('Manage catalog'), findsOneWidget);
        expect(find.text('Release bed'), findsNothing);
        expect(find.byType(AppTabToolbarPrimary), findsNothing);
      },
    );

    testWidgets('nested cross-module write absent without occupancy rights', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(
        RoomsBedsOccupiedAtomPermissions.nestedOccupancyWrite.isAllowed(reader),
        isFalse,
      );

      await _pumpOccupiedTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );
      await tester.tap(find.text('Bed O1').first);
      await _pumpFrames(tester);

      expect(find.text('Release bed'), findsNothing);
      expect(find.text('Request transfer'), findsNothing);
      expect(find.text('Manage transfer'), findsNothing);
    });

    testWidgets('authorized empty / loading chrome remain on Occupied', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      await _pumpOccupiedTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        beds: const <BedProfile>[],
      );

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );
      expect(find.text(l10n.roomsBedsEmptyTitle), findsOneWidget);
      expect(_table(tester).search, isNotNull);
      expect(_table(tester).search?.advancedFilterButtonLabel, 'Filters');
      expect(_table(tester).columnVisibilityLabel, 'Settings');
      expect(
        _table(tester).columnVisibilityStorageKey,
        'rooms_beds_occupied',
      );
    });

    testWidgets('post-mutation sync: Release refreshes and shows success', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      await _pumpOccupiedTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      await tester.tap(find.bySemanticsLabel('Release bed').first);
      await _pumpFrames(tester);

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      await tester.tap(find.text('Release bed').last);
      await _pumpFrames(tester);

      verify(
        () => repository.releaseBed(admissionId: 'ADM-100'),
      ).called(1);
      expect(find.text('Rooms and beds updated.'), findsOneWidget);
    });

    testWidgets('mobile viewport: Occupied tab + release next-action', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      await _pumpOccupiedTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        physicalSize: const Size(390, 844),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(_tabLabel('Occupied'), findsOneWidget);
      expect(find.byType(AppListTableMobileItem), findsOneWidget);
      expect(find.byTooltip('Release bed'), findsWidgets);
      expect(_toolbarAction('Manage catalog'), findsNothing);
    });

    testWidgets('desktop dark theme: Occupied authorized chrome renders', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.facilityAdmin,
        },
        roles: const <String>['FACILITY_ADMIN'],
      );
      await _pumpOccupiedTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        themeMode: ThemeMode.dark,
      );

      expect(_tabLabel('Occupied'), findsOneWidget);
      expect(find.text('Bed O1'), findsWidgets);
      expect(find.text('Release bed'), findsWidgets);
      expect(_toolbarAction('Manage catalog'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('light theme: Occupied read ∪ operations:read shows board', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy operationsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      await _pumpOccupiedTab(
        tester,
        repository: repository,
        accessPolicy: operationsReader,
      );

      expect(_tabLabel('Occupied'), findsOneWidget);
      expect(find.text('Bed O1'), findsWidgets);
      expect(find.text('Release bed'), findsNothing);
    });

    testWidgets(
      'without inpatient module Occupied strip collapses (subscription ∩)',
      (WidgetTester tester) async {
        final AppAccessPolicy noModule = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
          modules: const <AppModuleEntitlement>[],
        );

        await _pumpOccupiedTab(
          tester,
          repository: repository,
          accessPolicy: noModule,
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.byType(AppListTable<BedBoardItem>), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    test('next-action auth: release requires occupancy write ∪', () {
      expect(
        roomsBedsNextActionShouldRender(
          kind: RoomsBedsNextActionKind.release,
          canAdminBeds: false,
          canIpdWrite: false,
        ),
        isFalse,
      );
      expect(
        roomsBedsNextActionShouldRender(
          kind: RoomsBedsNextActionKind.release,
          canAdminBeds: false,
          canIpdWrite: true,
        ),
        isTrue,
      );
      expect(
        roomsBedsNextActionShouldRender(
          kind: RoomsBedsNextActionKind.completeTransfer,
          canAdminBeds: true,
          canIpdWrite: false,
        ),
        isFalse,
      );
    });
  });
}
