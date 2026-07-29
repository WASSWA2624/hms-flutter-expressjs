import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
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

const BedProfile _cleaningBed = BedProfile(
  id: 'BED-CLEANING',
  tenantId: 'TEN-001',
  facilityId: 'FAC-001',
  wardId: 'WRD-001',
  roomId: 'RM-001',
  label: 'Bed C1',
  status: BedSetupStatus.cleaning,
);

const BedProfile _reservedBed = BedProfile(
  id: 'BED-RESERVED',
  tenantId: 'TEN-001',
  facilityId: 'FAC-001',
  wardId: 'WRD-001',
  roomId: 'RM-001',
  label: 'Bed R1',
  status: BedSetupStatus.reserved,
);

const BedProfile _maintenanceBed = BedProfile(
  id: 'BED-MAINT',
  tenantId: 'TEN-001',
  facilityId: 'FAC-001',
  wardId: 'WRD-001',
  roomId: 'RM-001',
  label: 'Bed M1',
  status: BedSetupStatus.maintenance,
);

const BedProfile _availableBed = BedProfile(
  id: 'BED-AVAILABLE',
  tenantId: 'TEN-001',
  facilityId: 'FAC-001',
  wardId: 'WRD-001',
  roomId: 'RM-001',
  label: 'Bed A1',
  status: BedSetupStatus.available,
);

const List<AppModuleEntitlement> _inpatientModules = <AppModuleEntitlement>[
  AppModuleEntitlement(
    code: roomsBedsInpatientBedManagementModule,
    licenseStatus: 'ACTIVE',
  ),
  AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'facilities-maintenance', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'hr-rosters', licenseStatus: 'ACTIVE'),
];

FacilitySetupSnapshot _snapshot({
  List<BedProfile> beds = const <BedProfile>[
    _cleaningBed,
    _reservedBed,
    _maintenanceBed,
    _availableBed,
  ],
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

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<String> roles = const <String>['VIEWER'],
  List<AppModuleEntitlement> modules = _inpatientModules,
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

AppAccessPolicy _readerPolicy() {
  return _policy(
    permissions: <AppPermission>{AppPermissions.clinicalRead},
  );
}

AppAccessPolicy _operationsReaderPolicy() {
  return _policy(
    permissions: <AppPermission>{AppPermissions.operationsRead},
  );
}

AppAccessPolicy _facilityAdminPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.facilityAdmin,
      AppPermissions.clinicalRead,
    },
    roles: const <String>['FACILITY_ADMIN'],
  );
}

AppAccessPolicy _unitManageOnlyPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.unitManage,
      AppPermissions.clinicalRead,
    },
    roles: const <String>['UNIT_MANAGER'],
  );
}

AppAccessPolicy _occupancyWriterPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
    },
    roles: const <String>['NURSE'],
  );
}

AppAccessPolicy _operationsWriterPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.operationsRead,
      AppPermissions.operationsWrite,
    },
    roles: const <String>['OPERATIONS'],
  );
}

AppAccessPolicy _adminWithoutModulePolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.facilityAdmin,
      AppPermissions.clinicalRead,
    },
    roles: const <String>['FACILITY_ADMIN'],
    modules: const <AppModuleEntitlement>[],
  );
}

void _stubRepository(_MockRoomsBedsRepository repository) {
  when(
    () => repository.loadSetup(facilityId: any(named: 'facilityId')),
  ).thenAnswer((_) async => Result<FacilitySetupSnapshot>.success(_snapshot()));
  when(() => repository.listBedAssignmentsForBed(any())).thenAnswer(
    (_) async => const Result<List<BedAssignmentRecord>>.success(
      <BedAssignmentRecord>[],
    ),
  );
  when(
    () => repository.loadAdmissionContext(any()),
  ).thenAnswer(
    (_) async => const Result<BedAdmissionContext>.success(
      BedAdmissionContext(admissionId: 'ADM-100'),
    ),
  );
  when(
    () => repository.assignBed(
      admissionId: any(named: 'admissionId'),
      bedId: any(named: 'bedId'),
    ),
  ).thenAnswer((_) async => const Result<void>.success(null));
  when(
    () => repository.updateBedStatus(
      bed: any(named: 'bed'),
      status: any(named: 'status'),
    ),
  ).thenAnswer(
    (Invocation invocation) async => Result<BedProfile>.success(
      (invocation.namedArguments[#bed] as BedProfile).copyWith(
        status: invocation.namedArguments[#status] as BedSetupStatus,
      ),
    ),
  );
}

Finder _toolbarPrimary(String label) => find.descendant(
  of: find.byType(AppTabStrip),
  matching: find.byWidgetPredicate(
    (Widget widget) =>
        widget is AppTabToolbarPrimary && widget.label == label,
  ),
);

Finder _toolbarAction(String label) => find.descendant(
  of: find.byType(AppTabStrip),
  matching: find.byWidgetPredicate(
    (Widget widget) =>
        widget is AppTabToolbarAction && widget.label == label,
  ),
);

Future<void> _pumpTurnoverTab(
  WidgetTester tester, {
  required _MockRoomsBedsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/rooms-beds?section=turnover',
  bool stubRepository = true,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  if (stubRepository) {
    _stubRepository(repository);
  }

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
      GoRoute(
        path: '/operations',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Operations destination'));
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  late _MockRoomsBedsRepository repository;

  setUpAll(() {
    registerFallbackValue(_cleaningBed);
    registerFallbackValue(BedSetupStatus.available);
  });

  setUp(() {
    repository = _MockRoomsBedsRepository();
  });

  test('Turnover atom helpers reuse AccessRequirement vocabulary', () {
    expect(
      identical(
        RoomsBedsTurnoverAtomPermissions.tab,
        roomsBedsWorkspaceReadRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsTurnoverAtomPermissions.manageCatalog,
        roomsBedsAdminRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsTurnoverAtomPermissions.markAvailable,
        roomsBedsAdminRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsTurnoverAtomPermissions.assign,
        roomsBedsOccupancyWriteRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsTurnoverAtomPermissions.openOperations,
        roomsBedsNavigationRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsTurnoverAtomPermissions.routeEntry,
        RouteAccessCatalog.roomsBedsEntry,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsTurnoverAtomPermissions.routeUnion,
        roomsBedsWorkspaceRouteUnionRequirement,
      ),
      isTrue,
    );
    expect(
      roomsBedsSectionTabRequirement(RoomsBedsSection.turnover),
      same(RoomsBedsTurnoverAtomPermissions.tab),
    );
    expect(
      RoomsBedsTurnoverAtomPermissions.tab.anyPermissions,
      containsAll(<AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.operationsRead,
        AppPermissions.facilityAdmin,
      ]),
    );
    // Matrix ∩ unit:manage alone maps to source admin ∪ (not a second map).
    expect(
      identical(
        RoomsBedsTurnoverAtomPermissions.create,
        roomsBedsWorkspaceCreateRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsTurnoverAtomPermissions.update,
        roomsBedsWorkspaceUpdateRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsTurnoverAtomPermissions.delete,
        roomsBedsWorkspaceDeleteRequirement,
      ),
      isTrue,
    );
  });

  test('inventory atoms map to matrix verbs (read ∪ / admin ∪ / occupancy ∪)', () {
    expect(RoomsBedsTurnoverAtomPermissions.tab, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.listChrome, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.search, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.filters, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.columns, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.settings, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.pagination, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.empty, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.loading, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.retry, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.success, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.validation, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.rowSelect, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.detail, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.nextAction, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.create, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.update, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.delete, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.markAvailable, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.manageCatalog, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.assign, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.release, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.transfer, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.completeTransfer, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.nestedWrite, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.nestedOccupancyWrite, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.navigateCrossModule, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.openOperations, isNotNull);
    expect(RoomsBedsTurnoverAtomPermissions.openHousekeeping, isNotNull);

    expect(
      RoomsBedsTurnoverAtomPermissions.markAvailable.anyPermissions,
      contains(AppPermissions.unitManage),
    );
    expect(
      RoomsBedsTurnoverAtomPermissions.assign.anyPermissions,
      containsAll(<AppPermission>[
        AppPermissions.clinicalWrite,
        AppPermissions.operationsWrite,
      ]),
    );
    expect(
      RoomsBedsTurnoverAtomPermissions.nestedWrite,
      same(RoomsBedsTurnoverAtomPermissions.manageCatalog),
    );
    expect(
      RoomsBedsTurnoverAtomPermissions.catalogEntry.requiresFacilityContext,
      isTrue,
    );
    expect(
      RoomsBedsTurnoverAtomPermissions.catalogEntry.allPermissions,
      contains(AppPermissions.roomsBedsRead),
    );
  });

  test('catalog ∩ rooms_beds:read denial without that permission', () {
    final AppAccessPolicy clinicalOnly = _readerPolicy();
    expect(
      RoomsBedsTurnoverAtomPermissions.catalogEntry.isAllowed(clinicalOnly),
      isFalse,
    );
    expect(
      RoomsBedsTurnoverAtomPermissions.routeUnion.isAllowed(clinicalOnly),
      isTrue,
    );
  });

  test('ABAC facility scope: catalog entry denied without facility context', () {
    final AppAccessPolicy noFacility = _policy(
      permissions: <AppPermission>{AppPermissions.roomsBedsRead},
      facilityId: null,
    );
    expect(
      RoomsBedsTurnoverAtomPermissions.catalogEntry.isAllowed(noFacility),
      isFalse,
    );
  });

  test('read ∪ allowance: clinical or operations or facility admin', () {
    expect(
      RoomsBedsTurnoverAtomPermissions.tab.isAllowed(_readerPolicy()),
      isTrue,
    );
    expect(
      RoomsBedsTurnoverAtomPermissions.tab.isAllowed(_operationsReaderPolicy()),
      isTrue,
    );
    expect(
      RoomsBedsTurnoverAtomPermissions.tab.isAllowed(_facilityAdminPolicy()),
      isTrue,
    );
    expect(
      RoomsBedsTurnoverAtomPermissions.markAvailable.isAllowed(_readerPolicy()),
      isFalse,
    );
    expect(
      RoomsBedsTurnoverAtomPermissions.manageCatalog.isAllowed(_readerPolicy()),
      isFalse,
    );
    expect(
      RoomsBedsTurnoverAtomPermissions.assign.isAllowed(_readerPolicy()),
      isFalse,
    );
  });

  test('admin ∪: unit:manage alone unlocks mark-available / catalog', () {
    final AppAccessPolicy unitManager = _unitManageOnlyPolicy();
    expect(
      RoomsBedsTurnoverAtomPermissions.markAvailable.isAllowed(unitManager),
      isTrue,
    );
    expect(
      RoomsBedsTurnoverAtomPermissions.manageCatalog.isAllowed(unitManager),
      isTrue,
    );
    expect(
      RoomsBedsTurnoverAtomPermissions.assign.isAllowed(unitManager),
      isFalse,
    );
  });

  test('subscription strip: facility admin without inpatient module denied', () {
    final AppAccessPolicy stripped = _adminWithoutModulePolicy();
    expect(RoomsBedsTurnoverAtomPermissions.tab.isAllowed(stripped), isFalse);
    expect(
      RoomsBedsTurnoverAtomPermissions.markAvailable.isAllowed(stripped),
      isFalse,
    );
    expect(canViewRoomsBedsSection(stripped, RoomsBedsSection.turnover), isFalse);
  });

  test('occupancy write ∪: clinical:write or operations:write', () {
    expect(
      RoomsBedsTurnoverAtomPermissions.assign.isAllowed(_occupancyWriterPolicy()),
      isTrue,
    );
    expect(
      RoomsBedsTurnoverAtomPermissions.assign.isAllowed(_operationsWriterPolicy()),
      isTrue,
    );
    expect(
      RoomsBedsTurnoverAtomPermissions.markAvailable.isAllowed(
        _occupancyWriterPolicy(),
      ),
      isFalse,
    );
    expect(
      RoomsBedsTurnoverAtomPermissions.markAvailable.isAllowed(
        _operationsWriterPolicy(),
      ),
      isFalse,
    );
  });

  test('next-action helpers: mark available admin; open operations navigate', () {
    expect(
      roomsBedsNextActionShouldRender(
        kind: RoomsBedsNextActionKind.markAvailable,
        canAdminBeds: false,
        canIpdWrite: true,
      ),
      isFalse,
    );
    expect(
      roomsBedsNextActionShouldRender(
        kind: RoomsBedsNextActionKind.markAvailable,
        canAdminBeds: true,
        canIpdWrite: false,
      ),
      isTrue,
    );
    expect(
      roomsBedsNextActionShouldRender(
        kind: RoomsBedsNextActionKind.openOperations,
        canAdminBeds: false,
        canIpdWrite: false,
      ),
      isTrue,
    );
    expect(
      roomsBedsPrimaryNextActionKind(
        const BedBoardItem(bed: _cleaningBed),
      ),
      RoomsBedsNextActionKind.markAvailable,
    );
    expect(
      roomsBedsPrimaryNextActionKind(
        const BedBoardItem(bed: _maintenanceBed),
      ),
      RoomsBedsNextActionKind.openOperations,
    );
  });

  testWidgets(
    'clinical-read ∩ denial: turnover list visible; Mark available / catalog absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _readerPolicy();
      expect(RoomsBedsTurnoverAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        RoomsBedsTurnoverAtomPermissions.markAvailable.isAllowed(reader),
        isFalse,
      );

      await _pumpTurnoverTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Turnover'), findsWidgets);
      expect(find.text('Bed C1'), findsWidgets);
      expect(find.text('Bed R1'), findsWidgets);
      expect(find.text('Bed M1'), findsWidgets);
      expect(find.text('Bed A1'), findsNothing);
      expect(_toolbarPrimary('Create room'), findsNothing);
      expect(_toolbarPrimary('Create bed'), findsNothing);
      expect(_toolbarAction('Manage catalog'), findsNothing);
      expect(find.text('Mark available'), findsNothing);
      expect(find.bySemanticsLabel('Mark available'), findsNothing);
      expect(find.text('Open operations'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'facility-admin ∪: Manage catalog + Mark available present; create primary null',
    (WidgetTester tester) async {
      final AppAccessPolicy admin = _facilityAdminPolicy();
      expect(
        RoomsBedsTurnoverAtomPermissions.manageCatalog.isAllowed(admin),
        isTrue,
      );

      await _pumpTurnoverTab(
        tester,
        repository: repository,
        accessPolicy: admin,
      );

      expect(_toolbarAction('Manage catalog'), findsOneWidget);
      expect(_toolbarPrimary('Create room'), findsNothing);
      expect(_toolbarPrimary('Create bed'), findsNothing);
      expect(find.text('Mark available'), findsWidgets);
      expect(find.text('Open operations'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'occupancy write ∪: Mark available / catalog absent; Open operations remains',
    (WidgetTester tester) async {
      await _pumpTurnoverTab(
        tester,
        repository: repository,
        accessPolicy: _occupancyWriterPolicy(),
      );

      expect(_toolbarAction('Manage catalog'), findsNothing);
      expect(find.text('Mark available'), findsNothing);
      expect(find.text('Open operations'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Bed C1').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Mark available'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Assign bed'),
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'operations:write ∪ also keeps Mark available absent on turnover',
    (WidgetTester tester) async {
      await _pumpTurnoverTab(
        tester,
        repository: repository,
        accessPolicy: _operationsWriterPolicy(),
      );

      expect(find.text('Mark available'), findsNothing);
      expect(_toolbarAction('Manage catalog'), findsNothing);
      expect(find.text('Open operations'), findsWidgets);
    },
  );

  testWidgets('authorized mark-available succeeds and syncs list', (
    WidgetTester tester,
  ) async {
    await _pumpTurnoverTab(
      tester,
      repository: repository,
      accessPolicy: _facilityAdminPolicy(),
    );

    await tester.tap(find.text('Mark available').first);
    await tester.pumpAndSettle();

    verify(
      () => repository.updateBedStatus(
        bed: any(named: 'bed'),
        status: BedSetupStatus.available,
      ),
    ).called(greaterThanOrEqualTo(1));
    verify(
      () => repository.loadSetup(facilityId: any(named: 'facilityId')),
    ).called(greaterThan(1));
  });

  testWidgets('mobile viewport: read chrome present, admin writes absent', (
    WidgetTester tester,
  ) async {
    await _pumpTurnoverTab(
      tester,
      repository: repository,
      accessPolicy: _readerPolicy(),
      physicalSize: const Size(390, 844),
    );

    expect(find.text('Bed C1'), findsWidgets);
    expect(find.text('Turnover'), findsWidgets);
    expect(_toolbarAction('Manage catalog'), findsNothing);
    expect(find.bySemanticsLabel('Mark available'), findsNothing);
  });

  testWidgets('desktop dark theme: admin mark-available remains visible', (
    WidgetTester tester,
  ) async {
    await _pumpTurnoverTab(
      tester,
      repository: repository,
      accessPolicy: _facilityAdminPolicy(),
      themeMode: ThemeMode.dark,
    );

    expect(find.text('Mark available'), findsWidgets);
    expect(_toolbarAction('Manage catalog'), findsOneWidget);
    expect(find.text('Bed C1'), findsWidgets);
  });

  testWidgets('empty turnover list state remains for authorized reader', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.loadSetup(facilityId: any(named: 'facilityId')),
    ).thenAnswer(
      (_) async => Result<FacilitySetupSnapshot>.success(
        _snapshot(beds: const <BedProfile>[_availableBed]),
      ),
    );
    when(() => repository.listBedAssignmentsForBed(any())).thenAnswer(
      (_) async => const Result<List<BedAssignmentRecord>>.success(
        <BedAssignmentRecord>[],
      ),
    );
    when(
      () => repository.loadAdmissionContext(any()),
    ).thenAnswer(
      (_) async => const Result<BedAdmissionContext>.success(
        BedAdmissionContext(admissionId: 'ADM-100'),
      ),
    );

    await _pumpTurnoverTab(
      tester,
      repository: repository,
      accessPolicy: _readerPolicy(),
      stubRepository: false,
    );

    expect(find.textContaining('No beds'), findsOneWidget);
    expect(_toolbarAction('Manage catalog'), findsNothing);
  });

  testWidgets('nested cross-module write entry points stay n/a absent', (
    WidgetTester tester,
  ) async {
    await _pumpTurnoverTab(
      tester,
      repository: repository,
      accessPolicy: _readerPolicy(),
    );

    expect(find.text('Create room'), findsNothing);
    expect(find.text('Create bed'), findsNothing);
    expect(RoomsBedsTurnoverAtomPermissions.nestedWrite.isAllowed(_readerPolicy()), isFalse);
  });
}
