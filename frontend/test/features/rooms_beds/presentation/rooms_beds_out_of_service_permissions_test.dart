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

const BedProfile _blockedBed = BedProfile(
  id: 'BED-BLOCKED',
  tenantId: 'TEN-001',
  facilityId: 'FAC-001',
  wardId: 'WRD-001',
  roomId: 'RM-001',
  label: 'Bed B1',
  status: BedSetupStatus.blocked,
);

const BedProfile _outOfServiceBed = BedProfile(
  id: 'BED-OOS',
  tenantId: 'TEN-001',
  facilityId: 'FAC-001',
  wardId: 'WRD-001',
  roomId: 'RM-001',
  label: 'Bed X1',
  status: BedSetupStatus.outOfService,
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
    _blockedBed,
    _outOfServiceBed,
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

Future<void> _pumpOutOfServiceTab(
  WidgetTester tester, {
  required _MockRoomsBedsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/rooms-beds?section=out-of-service',
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
    registerFallbackValue(_blockedBed);
    registerFallbackValue(BedSetupStatus.available);
  });

  setUp(() {
    repository = _MockRoomsBedsRepository();
  });

  test('Out of service atom helpers reuse AccessRequirement vocabulary', () {
    expect(
      identical(
        RoomsBedsOutOfServiceAtomPermissions.tab,
        roomsBedsWorkspaceReadRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsOutOfServiceAtomPermissions.manageCatalog,
        roomsBedsAdminRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsOutOfServiceAtomPermissions.markAvailable,
        roomsBedsAdminRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsOutOfServiceAtomPermissions.markOutOfService,
        roomsBedsAdminRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsOutOfServiceAtomPermissions.assign,
        roomsBedsOccupancyWriteRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsOutOfServiceAtomPermissions.openOperations,
        roomsBedsNavigationRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsOutOfServiceAtomPermissions.routeEntry,
        RouteAccessCatalog.roomsBedsEntry,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsOutOfServiceAtomPermissions.routeUnion,
        roomsBedsWorkspaceRouteUnionRequirement,
      ),
      isTrue,
    );
    expect(
      roomsBedsSectionTabRequirement(RoomsBedsSection.outOfService),
      same(RoomsBedsOutOfServiceAtomPermissions.tab),
    );
    expect(
      RoomsBedsOutOfServiceAtomPermissions.tab.anyPermissions,
      containsAll(<AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.operationsRead,
        AppPermissions.facilityAdmin,
      ]),
    );
    // Matrix ∩ unit:manage alone maps to source admin ∪ (not a second map).
    expect(
      identical(
        RoomsBedsOutOfServiceAtomPermissions.create,
        roomsBedsWorkspaceCreateRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsOutOfServiceAtomPermissions.update,
        roomsBedsWorkspaceUpdateRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsOutOfServiceAtomPermissions.delete,
        roomsBedsWorkspaceDeleteRequirement,
      ),
      isTrue,
    );
  });

  test('read ∪ allowance: clinical or operations or facility admin', () {
    expect(
      RoomsBedsOutOfServiceAtomPermissions.tab.isAllowed(_readerPolicy()),
      isTrue,
    );
    expect(
      RoomsBedsOutOfServiceAtomPermissions.tab.isAllowed(
        _operationsReaderPolicy(),
      ),
      isTrue,
    );
    expect(
      RoomsBedsOutOfServiceAtomPermissions.tab.isAllowed(
        _facilityAdminPolicy(),
      ),
      isTrue,
    );
    expect(
      RoomsBedsOutOfServiceAtomPermissions.markAvailable.isAllowed(
        _readerPolicy(),
      ),
      isFalse,
    );
    expect(
      RoomsBedsOutOfServiceAtomPermissions.manageCatalog.isAllowed(
        _readerPolicy(),
      ),
      isFalse,
    );
    expect(
      RoomsBedsOutOfServiceAtomPermissions.assign.isAllowed(_readerPolicy()),
      isFalse,
    );
  });

  test('admin ∪: unit:manage alone unlocks mark-available / catalog', () {
    final AppAccessPolicy unitManager = _unitManageOnlyPolicy();
    expect(
      RoomsBedsOutOfServiceAtomPermissions.markAvailable.isAllowed(
        unitManager,
      ),
      isTrue,
    );
    expect(
      RoomsBedsOutOfServiceAtomPermissions.manageCatalog.isAllowed(
        unitManager,
      ),
      isTrue,
    );
    expect(
      RoomsBedsOutOfServiceAtomPermissions.assign.isAllowed(unitManager),
      isFalse,
    );
  });

  test('subscription strip: facility admin without inpatient module denied', () {
    final AppAccessPolicy stripped = _adminWithoutModulePolicy();
    expect(
      RoomsBedsOutOfServiceAtomPermissions.tab.isAllowed(stripped),
      isFalse,
    );
    expect(
      RoomsBedsOutOfServiceAtomPermissions.markAvailable.isAllowed(stripped),
      isFalse,
    );
    expect(
      canViewRoomsBedsSection(stripped, RoomsBedsSection.outOfService),
      isFalse,
    );
  });

  test('occupancy write ∪: clinical:write or operations:write', () {
    expect(
      RoomsBedsOutOfServiceAtomPermissions.assign.isAllowed(
        _occupancyWriterPolicy(),
      ),
      isTrue,
    );
    expect(
      RoomsBedsOutOfServiceAtomPermissions.assign.isAllowed(
        _operationsWriterPolicy(),
      ),
      isTrue,
    );
    expect(
      RoomsBedsOutOfServiceAtomPermissions.markAvailable.isAllowed(
        _occupancyWriterPolicy(),
      ),
      isFalse,
    );
    expect(
      RoomsBedsOutOfServiceAtomPermissions.markAvailable.isAllowed(
        _operationsWriterPolicy(),
      ),
      isFalse,
    );
  });

  test(
    'next-action helpers: mark available admin; open operations navigate',
    () {
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
          const BedBoardItem(bed: _blockedBed),
        ),
        RoomsBedsNextActionKind.markAvailable,
      );
      expect(
        roomsBedsPrimaryNextActionKind(
          const BedBoardItem(bed: _outOfServiceBed),
        ),
        RoomsBedsNextActionKind.openOperations,
      );
    },
  );

  testWidgets(
    'clinical-read ∩ denial: OOS list visible; Mark available / catalog absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _readerPolicy();
      expect(
        RoomsBedsOutOfServiceAtomPermissions.tab.isAllowed(reader),
        isTrue,
      );
      expect(
        RoomsBedsOutOfServiceAtomPermissions.markAvailable.isAllowed(reader),
        isFalse,
      );

      await _pumpOutOfServiceTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Out of service'), findsWidgets);
      expect(find.text('Bed B1'), findsWidgets);
      expect(find.text('Bed X1'), findsWidgets);
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
        RoomsBedsOutOfServiceAtomPermissions.manageCatalog.isAllowed(admin),
        isTrue,
      );

      await _pumpOutOfServiceTab(
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
      await _pumpOutOfServiceTab(
        tester,
        repository: repository,
        accessPolicy: _occupancyWriterPolicy(),
      );

      expect(_toolbarAction('Manage catalog'), findsNothing);
      expect(find.text('Mark available'), findsNothing);
      expect(find.text('Open operations'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Bed B1').first);
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
    'operations:write ∪ also keeps Mark available absent on out-of-service',
    (WidgetTester tester) async {
      await _pumpOutOfServiceTab(
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
    await _pumpOutOfServiceTab(
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
    await _pumpOutOfServiceTab(
      tester,
      repository: repository,
      accessPolicy: _readerPolicy(),
      physicalSize: const Size(390, 844),
    );

    expect(find.text('Bed B1'), findsWidgets);
    expect(find.text('Out of service'), findsWidgets);
    expect(_toolbarAction('Manage catalog'), findsNothing);
    expect(find.bySemanticsLabel('Mark available'), findsNothing);
  });

  testWidgets('desktop dark theme: admin mark-available remains visible', (
    WidgetTester tester,
  ) async {
    await _pumpOutOfServiceTab(
      tester,
      repository: repository,
      accessPolicy: _facilityAdminPolicy(),
      themeMode: ThemeMode.dark,
    );

    expect(find.text('Mark available'), findsWidgets);
    expect(_toolbarAction('Manage catalog'), findsOneWidget);
    expect(find.text('Bed B1'), findsWidgets);
  });

  testWidgets('empty out-of-service list state remains for authorized reader', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.loadSetup(facilityId: any(named: 'facilityId')),
    ).thenAnswer(
      (_) async => Result<FacilitySetupSnapshot>.success(
        _snapshot(beds: const <BedProfile>[_availableBed]),
      ),
    );

    await _pumpOutOfServiceTab(
      tester,
      repository: repository,
      accessPolicy: _readerPolicy(),
    );

    expect(find.textContaining('No beds'), findsOneWidget);
    expect(_toolbarAction('Manage catalog'), findsNothing);
  });

  testWidgets('nested cross-module write entry points stay n/a absent', (
    WidgetTester tester,
  ) async {
    await _pumpOutOfServiceTab(
      tester,
      repository: repository,
      accessPolicy: _readerPolicy(),
    );

    expect(find.text('Create room'), findsNothing);
    expect(find.text('Create bed'), findsNothing);
    expect(
      RoomsBedsOutOfServiceAtomPermissions.nestedWrite.isAllowed(
        _readerPolicy(),
      ),
      isFalse,
    );
  });
}
