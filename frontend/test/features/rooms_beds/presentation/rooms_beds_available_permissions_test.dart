import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
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

const List<AppModuleEntitlement> _bedModules = <AppModuleEntitlement>[
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

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = _bedModules,
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

AppAccessPolicy _clinicalReader() {
  return _policyFor(
    permissions: <AppPermission>{AppPermissions.clinicalRead},
  );
}

AppAccessPolicy _operationsReader() {
  return _policyFor(
    permissions: <AppPermission>{AppPermissions.operationsRead},
    roles: const <String>['OPERATIONS'],
  );
}

AppAccessPolicy _facilityAdmin() {
  return _policyFor(
    permissions: <AppPermission>{
      AppPermissions.facilityAdmin,
      AppPermissions.clinicalRead,
    },
    roles: const <String>['FACILITY_ADMIN'],
  );
}

AppAccessPolicy _occupancyClinicalWriter() {
  return _policyFor(
    permissions: <AppPermission>{
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
    },
  );
}

AppAccessPolicy _occupancyOperationsWriter() {
  return _policyFor(
    permissions: <AppPermission>{
      AppPermissions.operationsRead,
      AppPermissions.operationsWrite,
    },
    roles: const <String>['OPERATIONS'],
  );
}

AppAccessPolicy _unitManageOnly() {
  return _policyFor(
    permissions: <AppPermission>{
      AppPermissions.clinicalRead,
      AppPermissions.unitManage,
    },
    roles: const <String>['UNIT_MANAGER'],
  );
}

AppAccessPolicy _adminWithoutModule() {
  return _policyFor(
    permissions: <AppPermission>{
      AppPermissions.facilityAdmin,
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
    },
    modules: const <AppModuleEntitlement>[
      AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
    ],
    roles: const <String>['FACILITY_ADMIN'],
  );
}

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

FacilitySetupSnapshot _snapshot() {
  return FacilitySetupSnapshot(
    tenant: const TenantProfile(id: 'TEN-001', name: 'Tenant'),
    facility: _facility,
    facilities: const <FacilityProfile>[_facility],
    wards: const <WardProfile>[_ward],
    rooms: const <RoomProfile>[_room],
    beds: const <BedProfile>[_availableBed],
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
  when(() => repository.loadAdmissionContext(any())).thenAnswer(
    (_) async => const Result<BedAdmissionContext>.success(
      BedAdmissionContext(admissionId: 'ADM-100'),
    ),
  );
  when(
    () => repository.assignBed(
      bedId: any(named: 'bedId'),
      admissionId: any(named: 'admissionId'),
    ),
  ).thenAnswer((_) async => const Result<void>.success(null));
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

Future<void> _pumpAvailable(
  WidgetTester tester, {
  required _MockRoomsBedsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  bool stubRepository = true,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  if (stubRepository) {
    _stubRepository(repository);
  }

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/rooms-beds?section=available',
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
  await tester.pumpAndSettle();
}

void main() {
  late _MockRoomsBedsRepository repository;

  setUp(() {
    repository = _MockRoomsBedsRepository();
  });

  group('RoomsBedsAvailableAtomPermissions helpers (reuse)', () {
    test('tab / create / assign map to shared *Requirement helpers', () {
      expect(
        RoomsBedsAvailableAtomPermissions.tab,
        same(roomsBedsWorkspaceReadRequirement),
      );
      expect(
        RoomsBedsAvailableAtomPermissions.createBed,
        same(roomsBedsAdminRequirement),
      );
      expect(
        RoomsBedsAvailableAtomPermissions.createRoom,
        same(roomsBedsAdminRequirement),
      );
      expect(
        RoomsBedsAvailableAtomPermissions.manageCatalog,
        same(roomsBedsAdminRequirement),
      );
      expect(
        RoomsBedsAvailableAtomPermissions.assign,
        same(roomsBedsOccupancyWriteRequirement),
      );
      expect(
        RoomsBedsAvailableAtomPermissions.routeEntry,
        same(RouteAccessCatalog.roomsBedsEntry),
      );
      expect(
        RoomsBedsAvailableAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.roomsBedsEntry),
      );
      expect(
        roomsBedsSectionTabRequirement(RoomsBedsSection.available),
        same(RoomsBedsAvailableAtomPermissions.tab),
      );
    });

    test('inventory atoms map to matrix verbs (read ∪ / admin ∪ / occupancy ∪)', () {
      expect(RoomsBedsAvailableAtomPermissions.tab, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.listChrome, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.search, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.filters, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.columns, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.settings, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.pagination, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.empty, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.loading, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.retry, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.success, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.validation, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.rowSelect, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.detail, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.nextAction, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.create, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.update, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.delete, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.createBed, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.createRoom, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.manageCatalog, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.markAvailable, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.assign, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.nestedWrite, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.nestedOccupancyWrite, isNotNull);
      expect(RoomsBedsAvailableAtomPermissions.navigateCrossModule, isNotNull);
      expect(
        RoomsBedsAvailableAtomPermissions.navigateCrossModule.isEmpty,
        isTrue,
      );
      expect(
        RoomsBedsAvailableAtomPermissions.nestedWrite,
        same(RoomsBedsAvailableAtomPermissions.manageCatalog),
      );
      expect(
        RoomsBedsAvailableAtomPermissions.createBed.anyPermissions,
        contains(AppPermissions.unitManage),
      );
    });

    test('nested cross-module matrix rows are n/a (empty navigate gate)', () {
      expect(
        RoomsBedsAvailableAtomPermissions.navigateCrossModule.isEmpty,
        isTrue,
      );
      expect(
        RoomsBedsAvailableAtomPermissions.openOperations.isEmpty,
        isTrue,
      );
      expect(
        RoomsBedsAvailableAtomPermissions.openHousekeeping.isEmpty,
        isTrue,
      );
      expect(
        RoomsBedsAvailableAtomPermissions.navigateCrossModule.isAllowed(
          _clinicalReader(),
        ),
        isTrue,
      );
    });

    test('catalog entry ABAC: facility context required (∩ rooms_beds:read)', () {
      final AppAccessPolicy withFacility = _policyFor(
        permissions: <AppPermission>{AppPermissions.roomsBedsRead},
      );
      final AppAccessPolicy withoutFacility = _policyFor(
        permissions: <AppPermission>{AppPermissions.roomsBedsRead},
        facilityId: null,
      );
      expect(
        RoomsBedsAvailableAtomPermissions.catalogEntry.isAllowed(withFacility),
        isTrue,
      );
      expect(
        RoomsBedsAvailableAtomPermissions.catalogEntry.isAllowed(
          withoutFacility,
        ),
        isFalse,
      );
      expect(
        RoomsBedsAvailableAtomPermissions.catalogEntry.requiresFacilityContext,
        isTrue,
      );
    });

    test('read ∪ allows clinical, operations, or facility admin', () {
      expect(canReadRoomsBeds(_clinicalReader()), isTrue);
      expect(canReadRoomsBeds(_operationsReader()), isTrue);
      expect(canReadRoomsBeds(_facilityAdmin()), isTrue);
      expect(
        canReadRoomsBeds(
          _policyFor(permissions: <AppPermission>{AppPermissions.billingRead}),
        ),
        isFalse,
      );
    });

    test('admin ∩ denial without module entitlement strips create', () {
      // Intersection-style denial: facility admin role pack alone without
      // inpatient-bed-management must not unlock create.
      expect(canAdminRoomsBeds(_adminWithoutModule()), isFalse);
      expect(
        RoomsBedsAvailableAtomPermissions.createBed.isAllowed(
          _adminWithoutModule(),
        ),
        isFalse,
      );
    });

    test('admin ∪ allows facility admin or unit:manage with module', () {
      // Matrix ∩ unit:manage alone maps to source admin ∪ (documented).
      expect(canAdminRoomsBeds(_facilityAdmin()), isTrue);
      expect(canAdminRoomsBeds(_unitManageOnly()), isTrue);
      expect(canAdminRoomsBeds(_clinicalReader()), isFalse);
    });

    test('occupancy write ∪ allows clinical:write or operations:write', () {
      expect(canWriteRoomsBedsOccupancy(_occupancyClinicalWriter()), isTrue);
      expect(canWriteRoomsBedsOccupancy(_occupancyOperationsWriter()), isTrue);
      expect(canWriteRoomsBedsOccupancy(_clinicalReader()), isFalse);
      expect(
        RoomsBedsAvailableAtomPermissions.assign.isAllowed(_clinicalReader()),
        isFalse,
      );
    });

    test('route AppRoutes ∪ integrates with Available routeUnion atom', () {
      expect(
        RoomsBedsAvailableAtomPermissions.routeUnion.anyPermissions,
        containsAll(<AppPermission>[
          AppPermissions.clinicalRead,
          AppPermissions.operationsRead,
          AppPermissions.tenantAdmin,
          AppPermissions.facilityAdmin,
          AppPermissions.platformAdmin,
        ]),
      );
      expect(
        AppRoutes.roomsBeds.requiredActiveModules,
        contains(roomsBedsInpatientBedManagementModule),
      );
    });
  });

  group('Available tab widget authorization', () {
    testWidgets(
      'clinical-read-only: Available tab + list present; create/assign absent',
      (WidgetTester tester) async {
        await _pumpAvailable(
          tester,
          repository: repository,
          accessPolicy: _clinicalReader(),
        );

        expect(find.text('Available'), findsWidgets);
        expect(find.text('Bed A1'), findsWidgets);
        expect(_toolbarPrimary('Create bed'), findsNothing);
        expect(_toolbarAction('Create room'), findsNothing);
        expect(_toolbarAction('Manage catalog'), findsNothing);
        expect(find.text('Assign bed'), findsNothing);
        expect(find.bySemanticsLabel('Assign bed'), findsNothing);
        expect(find.text('No access'), findsNothing);
      },
    );

    testWidgets(
      'facility admin: Create bed / Create room / Manage catalog absent (setup-only)',
      (WidgetTester tester) async {
        await _pumpAvailable(
          tester,
          repository: repository,
          accessPolicy: _facilityAdmin(),
        );

        expect(_toolbarPrimary('Create bed'), findsNothing);
        expect(_toolbarAction('Create room'), findsNothing);
        expect(_toolbarAction('Manage catalog'), findsNothing);
        expect(find.text('Assign bed'), findsNothing);
      },
    );

    testWidgets(
      'unit:manage union: Create bed / Manage catalog absent (setup-only)',
      (WidgetTester tester) async {
        await _pumpAvailable(
          tester,
          repository: repository,
          accessPolicy: _unitManageOnly(),
        );

        expect(_toolbarPrimary('Create bed'), findsNothing);
        expect(_toolbarAction('Manage catalog'), findsNothing);
      },
    );

    testWidgets(
      'clinical:write union grant shows Assign; admin create absent',
      (WidgetTester tester) async {
        await _pumpAvailable(
          tester,
          repository: repository,
          accessPolicy: _occupancyClinicalWriter(),
        );

        expect(_toolbarPrimary('Create bed'), findsNothing);
        expect(find.text('Assign bed'), findsWidgets);
      },
    );

    testWidgets(
      'operations:write union grant shows Assign without bed admin',
      (WidgetTester tester) async {
        await _pumpAvailable(
          tester,
          repository: repository,
          accessPolicy: _occupancyOperationsWriter(),
        );

        expect(_toolbarPrimary('Create bed'), findsNothing);
        expect(find.text('Assign bed'), findsWidgets);
      },
    );

    testWidgets(
      'subscription strip: facility admin without inpatient module hides create',
      (WidgetTester tester) async {
        await _pumpAvailable(
          tester,
          repository: repository,
          accessPolicy: _adminWithoutModule(),
        );

        expect(_toolbarPrimary('Create bed'), findsNothing);
        expect(_toolbarAction('Manage catalog'), findsNothing);
        // Read also requires inpatient module — list chrome collapses.
        expect(find.text('Available'), findsNothing);
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      when(
        () => repository.loadSetup(facilityId: any(named: 'facilityId')),
      ).thenAnswer(
        (_) async => Result<FacilitySetupSnapshot>.success(
          FacilitySetupSnapshot(
            tenant: const TenantProfile(id: 'TEN-001', name: 'Tenant'),
            facility: _facility,
            facilities: const <FacilityProfile>[_facility],
            wards: const <WardProfile>[_ward],
            rooms: const <RoomProfile>[_room],
            beds: const <BedProfile>[],
          ),
        ),
      );
      when(() => repository.listBedAssignmentsForBed(any())).thenAnswer(
        (_) async => const Result<List<BedAssignmentRecord>>.success(
          <BedAssignmentRecord>[],
        ),
      );

      await _pumpAvailable(
        tester,
        repository: repository,
        accessPolicy: _clinicalReader(),
        stubRepository: false,
      );

      expect(find.text('No beds found'), findsOneWidget);
    });

    testWidgets('error/retry state remains for authorized reader', (
      WidgetTester tester,
    ) async {
      when(
        () => repository.loadSetup(facilityId: any(named: 'facilityId')),
      ).thenAnswer(
        (_) async => const Result<FacilitySetupSnapshot>.failure(
          AppFailure.network(),
        ),
      );

      await _pumpAvailable(
        tester,
        repository: repository,
        accessPolicy: _clinicalReader(),
        stubRepository: false,
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(_toolbarPrimary('Create bed'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets(
      'admin detail: Reserve on available bed; Assign twin omitted from detail',
      (WidgetTester tester) async {
        await _pumpAvailable(
          tester,
          repository: repository,
          accessPolicy: _facilityAdmin(),
        );

        await tester.tap(find.text('Bed A1').first);
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        expect(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Reserve'),
          ),
          findsOneWidget,
        );
        // Assign is board next-action for available — not a detail twin for admin
        // without occupancy write.
        expect(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Assign bed'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('reader detail omits status and occupancy write actions', (
      WidgetTester tester,
    ) async {
      await _pumpAvailable(
        tester,
        repository: repository,
        accessPolicy: _clinicalReader(),
      );

      await tester.tap(find.text('Bed A1').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Reserve'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Assign bed'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Create bed'),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'nested occupancy write absent without clinical/operations write',
      (WidgetTester tester) async {
        await _pumpAvailable(
          tester,
          repository: repository,
          accessPolicy: _facilityAdmin(),
        );

        expect(find.text('Assign bed'), findsNothing);
        expect(find.bySemanticsLabel('Assign bed'), findsNothing);

        await tester.tap(find.text('Bed A1').first);
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Assign bed'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('mobile viewport: Assign next-action for occupancy writer', (
      WidgetTester tester,
    ) async {
      await _pumpAvailable(
        tester,
        repository: repository,
        accessPolicy: _occupancyClinicalWriter(),
        viewport: const Size(390, 844),
      );

      expect(find.byType(RoomsBedsNextActionButton), findsWidgets);
      expect(find.byTooltip('Assign bed'), findsWidgets);
    });

    testWidgets('desktop dark theme: Create bed absent for facility admin', (
      WidgetTester tester,
    ) async {
      await _pumpAvailable(
        tester,
        repository: repository,
        accessPolicy: _facilityAdmin(),
        viewport: const Size(1440, 900),
        themeMode: ThemeMode.dark,
      );

      expect(_toolbarPrimary('Create bed'), findsNothing);
      expect(find.text('Bed A1'), findsWidgets);
    });

    testWidgets(
      'light theme desktop: operations:read ∪ shows Available without writes',
      (WidgetTester tester) async {
        await _pumpAvailable(
          tester,
          repository: repository,
          accessPolicy: _operationsReader(),
          themeMode: ThemeMode.light,
        );

        expect(find.text('Available'), findsWidgets);
        expect(find.text('Bed A1'), findsWidgets);
        expect(_toolbarPrimary('Create bed'), findsNothing);
        expect(find.bySemanticsLabel('Assign bed'), findsNothing);
      },
    );

    testWidgets('post-mutation sync: assign dialog mounts for writer', (
      WidgetTester tester,
    ) async {
      await _pumpAvailable(
        tester,
        repository: repository,
        accessPolicy: _occupancyClinicalWriter(),
      );

      await tester.tap(find.bySemanticsLabel('Assign bed').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      final Finder admissionField = find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(TextFormField),
      );
      expect(admissionField, findsOneWidget);
      await tester.enterText(admissionField, 'ADM-200');
      await tester.pump();

      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.widgetWithText(AppButton, 'Assign bed'),
        ),
      );
      await tester.pumpAndSettle();

      verify(
        () => repository.assignBed(
          admissionId: 'ADM-200',
          bedId: 'BED-AVAILABLE',
        ),
      ).called(1);
      expect(find.byType(AppDialog), findsNothing);
      expect(find.textContaining('Rooms and beds updated'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    });
  });

  group('Available next-action authorization mapping', () {
    test('assign requires occupancy write; mark available requires admin', () {
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
          canAdminBeds: false,
          canIpdWrite: true,
        ),
        isFalse,
      );
    });

    test('available primary next-action kind is assign', () {
      final BedBoardItem item = BedBoardItem(
        bed: _availableBed,
        ward: _ward,
        room: _room,
        facility: _facility,
      );
      expect(
        roomsBedsPrimaryNextActionKind(item),
        RoomsBedsNextActionKind.assign,
      );
    });
  });
}
