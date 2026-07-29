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

const BedProfile _availableBed = BedProfile(
  id: 'BED-AVAILABLE',
  tenantId: 'TEN-001',
  facilityId: 'FAC-001',
  wardId: 'WRD-001',
  roomId: 'RM-001',
  label: 'Bed A1',
  status: BedSetupStatus.available,
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
  AppModuleEntitlement(code: 'facilities-maintenance', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'hr-rosters', licenseStatus: 'ACTIVE'),
];

FacilitySetupSnapshot _snapshot({
  List<BedProfile> beds = const <BedProfile>[_availableBed, _occupiedBed],
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
      invocation.namedArguments[#bed] as BedProfile,
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

Future<void> _pumpAllBedsTab(
  WidgetTester tester, {
  required _MockRoomsBedsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/rooms-beds',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository);

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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  late _MockRoomsBedsRepository repository;

  setUpAll(() {
    registerFallbackValue(_availableBed);
    registerFallbackValue(BedSetupStatus.available);
  });

  setUp(() {
    repository = _MockRoomsBedsRepository();
  });

  test('All beds atom helpers reuse AccessRequirement vocabulary', () {
    expect(
      identical(
        RoomsBedsAllBedsAtomPermissions.tab,
        roomsBedsWorkspaceReadRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsAllBedsAtomPermissions.createRoom,
        roomsBedsAdminRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsAllBedsAtomPermissions.assign,
        roomsBedsOccupancyWriteRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsAllBedsAtomPermissions.routeEntry,
        RouteAccessCatalog.roomsBedsEntry,
      ),
      isTrue,
    );
    expect(
      identical(
        RoomsBedsAllBedsAtomPermissions.routeUnion,
        roomsBedsWorkspaceRouteUnionRequirement,
      ),
      isTrue,
    );
    expect(
      RoomsBedsAllBedsAtomPermissions.tab.anyPermissions,
      containsAll(<AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.operationsRead,
        AppPermissions.facilityAdmin,
      ]),
    );
    expect(
      RoomsBedsAllBedsAtomPermissions.create.anyPermissions,
      containsAll(<AppPermission>[
        AppPermissions.unitManage,
        AppPermissions.facilityAdmin,
        AppPermissions.tenantAdmin,
        AppPermissions.systemAdmin,
      ]),
    );
    expect(
      RoomsBedsAllBedsAtomPermissions.occupancyWrite.anyPermissions,
      containsAll(<AppPermission>[
        AppPermissions.clinicalWrite,
        AppPermissions.operationsWrite,
      ]),
    );
    // Matrix ∩ unit:manage alone maps to source admin ∪ (not a second map).
    expect(
      identical(
        RoomsBedsAllBedsAtomPermissions.create,
        roomsBedsWorkspaceCreateRequirement,
      ),
      isTrue,
    );
  });

  test('read ∪ allowance: clinical or operations or facility admin', () {
    expect(RoomsBedsAllBedsAtomPermissions.tab.isAllowed(_readerPolicy()), isTrue);
    expect(
      RoomsBedsAllBedsAtomPermissions.tab.isAllowed(_operationsReaderPolicy()),
      isTrue,
    );
    expect(
      RoomsBedsAllBedsAtomPermissions.tab.isAllowed(_facilityAdminPolicy()),
      isTrue,
    );
    expect(
      RoomsBedsAllBedsAtomPermissions.create.isAllowed(_readerPolicy()),
      isFalse,
    );
    expect(
      RoomsBedsAllBedsAtomPermissions.assign.isAllowed(_readerPolicy()),
      isFalse,
    );
  });

  test('admin ∪: unit:manage alone (with modules) unlocks create', () {
    final AppAccessPolicy unitManager = _unitManageOnlyPolicy();
    expect(RoomsBedsAllBedsAtomPermissions.create.isAllowed(unitManager), isTrue);
    expect(canAdminRoomsBeds(unitManager), isTrue);
    expect(
      RoomsBedsAllBedsAtomPermissions.assign.isAllowed(unitManager),
      isFalse,
    );
  });

  test('subscription strip: facility admin without inpatient module denied', () {
    final AppAccessPolicy stripped = _adminWithoutModulePolicy();
    expect(RoomsBedsAllBedsAtomPermissions.tab.isAllowed(stripped), isFalse);
    expect(RoomsBedsAllBedsAtomPermissions.create.isAllowed(stripped), isFalse);
    expect(canAdminRoomsBeds(stripped), isFalse);
  });

  test('occupancy write ∪: clinical:write or operations:write', () {
    expect(
      RoomsBedsAllBedsAtomPermissions.assign.isAllowed(_occupancyWriterPolicy()),
      isTrue,
    );
    expect(
      RoomsBedsAllBedsAtomPermissions.assign.isAllowed(_operationsWriterPolicy()),
      isTrue,
    );
    expect(
      RoomsBedsAllBedsAtomPermissions.create.isAllowed(_occupancyWriterPolicy()),
      isFalse,
    );
  });

  test('next-action helpers honor occupancy / admin flags', () {
    expect(
      roomsBedsNextActionShouldRender(
        kind: RoomsBedsNextActionKind.assign,
        canAdminBeds: false,
        canIpdWrite: false,
      ),
      isFalse,
    );
    expect(
      roomsBedsNextActionShouldRender(
        kind: RoomsBedsNextActionKind.assign,
        canAdminBeds: false,
        canIpdWrite: true,
      ),
      isTrue,
    );
    expect(
      roomsBedsNextActionShouldRender(
        kind: RoomsBedsNextActionKind.markAvailable,
        canAdminBeds: true,
        canIpdWrite: false,
      ),
      isTrue,
    );
  });

  testWidgets(
    'clinical-read ∩ denial: list visible; Create room / Assign absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _readerPolicy();
      expect(RoomsBedsAllBedsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(RoomsBedsAllBedsAtomPermissions.create.isAllowed(reader), isFalse);

      await _pumpAllBedsTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Bed A1'), findsWidgets);
      expect(find.text('All beds'), findsWidgets);
      expect(_toolbarPrimary('Create room'), findsNothing);
      expect(_toolbarAction('Create bed'), findsNothing);
      expect(_toolbarAction('Manage catalog'), findsNothing);
      expect(find.text('Assign bed'), findsNothing);
      expect(find.bySemanticsLabel('Assign bed'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'facility-admin ∪: Create room / Create bed / Manage catalog present',
    (WidgetTester tester) async {
      final AppAccessPolicy admin = _facilityAdminPolicy();
      expect(RoomsBedsAllBedsAtomPermissions.create.isAllowed(admin), isTrue);

      await _pumpAllBedsTab(
        tester,
        repository: repository,
        accessPolicy: admin,
      );

      expect(_toolbarPrimary('Create room'), findsOneWidget);
      expect(_toolbarAction('Create bed'), findsOneWidget);
      expect(_toolbarAction('Manage catalog'), findsOneWidget);
      expect(find.text('Assign bed'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'occupancy write ∪: Assign next-action mounts; Create room absent',
    (WidgetTester tester) async {
      await _pumpAllBedsTab(
        tester,
        repository: repository,
        accessPolicy: _occupancyWriterPolicy(),
      );

      expect(_toolbarPrimary('Create room'), findsNothing);
      expect(find.text('Assign bed'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Bed A1').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Assign bed'),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Mark available'),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'operations:write ∪ also unlocks Assign without clinical:write',
    (WidgetTester tester) async {
      await _pumpAllBedsTab(
        tester,
        repository: repository,
        accessPolicy: _operationsWriterPolicy(),
      );

      expect(find.text('Assign bed'), findsWidgets);
      expect(_toolbarPrimary('Create room'), findsNothing);
    },
  );

  testWidgets('authorized assign flow succeeds and syncs list', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.assignBed(
        admissionId: any(named: 'admissionId'),
        bedId: any(named: 'bedId'),
      ),
    ).thenAnswer((_) async {
      return const Result<void>.success(null);
    });

    await _pumpAllBedsTab(
      tester,
      repository: repository,
      accessPolicy: _occupancyWriterPolicy(),
    );

    await tester.tap(find.text('Assign bed').first);
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
    await tester.enterText(find.byType(TextFormField).first, 'ADM-200');
    await tester.tap(find.text('Assign bed').last);
    await tester.pumpAndSettle();

    verify(
      () => repository.assignBed(admissionId: 'ADM-200', bedId: 'BED-AVAILABLE'),
    ).called(1);
    verify(
      () => repository.loadSetup(facilityId: any(named: 'facilityId')),
    ).called(greaterThan(1));
  });

  testWidgets('mobile viewport: read chrome present, create absent for reader', (
    WidgetTester tester,
  ) async {
    await _pumpAllBedsTab(
      tester,
      repository: repository,
      accessPolicy: _readerPolicy(),
      physicalSize: const Size(390, 844),
    );

    expect(find.text('Bed A1'), findsWidgets);
    expect(_toolbarPrimary('Create room'), findsNothing);
    expect(find.bySemanticsLabel('Assign bed'), findsNothing);
  });

  testWidgets('desktop dark theme: admin create remains visible', (
    WidgetTester tester,
  ) async {
    await _pumpAllBedsTab(
      tester,
      repository: repository,
      accessPolicy: _facilityAdminPolicy(),
      themeMode: ThemeMode.dark,
    );

    expect(_toolbarPrimary('Create room'), findsOneWidget);
    expect(find.text('Bed A1'), findsWidgets);
  });

  testWidgets('empty list state remains for authorized reader', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.loadSetup(facilityId: any(named: 'facilityId')),
    ).thenAnswer(
      (_) async => Result<FacilitySetupSnapshot>.success(
        _snapshot(beds: const <BedProfile>[]),
      ),
    );

    await _pumpAllBedsTab(
      tester,
      repository: repository,
      accessPolicy: _readerPolicy(),
    );

    expect(find.textContaining('No beds'), findsOneWidget);
    expect(_toolbarPrimary('Create room'), findsNothing);
  });
}
