import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
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

const List<AppModuleEntitlement> _inpatientModules = <AppModuleEntitlement>[
  AppModuleEntitlement(
    code: roomsBedsInpatientBedManagementModule,
    licenseStatus: 'ACTIVE',
  ),
  AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'facilities-maintenance', licenseStatus: 'ACTIVE'),
];

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

const BedProfile _cleaningBed = BedProfile(
  id: 'BED-CLEANING',
  tenantId: 'TEN-001',
  facilityId: 'FAC-001',
  wardId: 'WRD-001',
  roomId: 'RM-001',
  label: 'Bed C1',
  status: BedSetupStatus.cleaning,
);

const BedAssignmentRecord _activeAssignment = BedAssignmentRecord(
  id: 'ASN-1',
  admissionId: 'ADM-100',
  bedId: 'BED-OCCUPIED',
  admissionDisplayId: 'IPD-100',
);

FacilitySetupSnapshot _snapshot({
  List<BedProfile> beds = const <BedProfile>[
    _availableBed,
    _occupiedBed,
    _cleaningBed,
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

AppAccessPolicy _adminAndClinicalPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['FACILITY_ADMIN'],
        tenantId: 'TEN-001',
        facilityId: 'FAC-001',
      ),
      permissions: <AppPermission>{
        AppPermissions.facilityAdmin,
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
      moduleEntitlements: _inpatientModules,
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _readOnlyPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['VIEWER'],
        tenantId: 'TEN-001',
        facilityId: 'FAC-001',
      ),
      permissions: <AppPermission>{AppPermissions.clinicalRead},
      moduleEntitlements: _inpatientModules,
      isAuthorizationHydrated: true,
    ),
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
  when(() => repository.loadAdmissionContext(any())).thenAnswer(
    (_) async => const Result<BedAdmissionContext>.success(
      BedAdmissionContext(admissionId: 'ADM-100'),
    ),
  );
}

Finder _toolbarPrimary(String label) => find.descendant(
  of: find.byType(AppTabStrip),
  matching: find.byWidgetPredicate(
    (Widget widget) => widget is AppTabToolbarPrimary && widget.label == label,
  ),
);

Finder _toolbarAction(String label) => find.descendant(
  of: find.byType(AppTabStrip),
  matching: find.byWidgetPredicate(
    (Widget widget) => widget is AppTabToolbarAction && widget.label == label,
  ),
);

Finder _tabToolbarRefresh() => find.descendant(
  of: find.byType(AppTabStrip),
  matching: find.byWidgetPredicate(
    (Widget widget) =>
        (widget is AppTabToolbarAction && widget.label == 'Refresh') ||
        (widget is AppTabToolbarPrimary && widget.label == 'Refresh'),
  ),
);

Future<void> _selectTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

Future<void> _pumpRoomsBedsWorkspace(
  WidgetTester tester, {
  required _MockRoomsBedsRepository repository,
  AppAccessPolicy? accessPolicy,
  String initialLocation = '/rooms-beds',
  Size viewport = const Size(1440, 900),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository);

  tester.view.physicalSize = viewport;
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
        appAccessPolicyProvider.overrideWithValue(
          accessPolicy ?? _adminAndClinicalPolicy(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Routed bed detail opens after the initial provider load settles.
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  late _MockRoomsBedsRepository repository;

  setUp(() {
    repository = _MockRoomsBedsRepository();
  });

  group('duplicates removed (source)', () {
    final String pageSource = File(
      'lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart',
    ).readAsStringSync();

    test('tab-strip Refresh helpers are absent', () {
      expect(pageSource.contains('_refreshPrimary'), isFalse);
      expect(pageSource.contains('_refreshSecondary'), isFalse);
      expect(pageSource.contains('commonRefreshActionLabel'), isFalse);
    });

    test('leave-screen strip primaries are absent', () {
      expect(pageSource.contains('navigationIpdShortLabel'), isFalse);
      expect(pageSource.contains('primaryAction:'), isFalse);
      expect(pageSource.contains('secondaryActions:'), isFalse);
      expect(pageSource.contains('_buildPrimaryAction'), isFalse);
      expect(pageSource.contains('_buildSecondaryActions'), isFalse);
    });

    test('detail omits board next-action twin', () {
      expect(pageSource.contains('omitNextActionKind'), isTrue);
      expect(pageSource.contains('roomsBedsReadinessLabel'), isFalse);
      expect(pageSource.contains('hideAdmissionField'), isTrue);
    });

    test('deep link awaits initial load then opens detail', () {
      expect(
        pageSource.contains('roomsBedsWorkspaceControllerProvider.future'),
        isTrue,
      );
      expect(pageSource.contains("query.bedId"), isTrue);
    });
  });

  group('next-action auth helpers', () {
    test('unauthorized assign does not render', () {
      expect(
        roomsBedsNextActionShouldRender(
          kind: RoomsBedsNextActionKind.assign,
          canAdminBeds: false,
          canIpdWrite: false,
        ),
        isFalse,
      );
    });

    test('authorized assign renders', () {
      expect(
        roomsBedsNextActionShouldRender(
          kind: RoomsBedsNextActionKind.assign,
          canAdminBeds: false,
          canIpdWrite: true,
        ),
        isTrue,
      );
    });

    test('viewDetail never renders as next-action chrome', () {
      expect(
        roomsBedsNextActionShouldRender(
          kind: RoomsBedsNextActionKind.viewDetail,
          canAdminBeds: true,
          canIpdWrite: true,
        ),
        isFalse,
      );
    });
  });

  testWidgets('omits strip refresh and catalog CRUD toolbar actions', (
    WidgetTester tester,
  ) async {
    await _pumpRoomsBedsWorkspace(tester, repository: repository);

    expect(_toolbarPrimary('Create room'), findsNothing);
    expect(_toolbarAction('Create bed'), findsNothing);
    expect(_toolbarAction('Manage catalog'), findsNothing);
    expect(find.byType(AppTabToolbarPrimary), findsNothing);
    expect(_tabToolbarRefresh(), findsNothing);
    expect(_toolbarPrimary('IPD'), findsNothing);
    expect(find.text('Open housekeeping'), findsNothing);
    expect(find.text('Open operations'), findsNothing);

    await _selectTab(tester, 'Occupied');
    expect(find.byType(AppTabToolbarPrimary), findsNothing);
    expect(_toolbarAction('Manage catalog'), findsNothing);
    expect(_tabToolbarRefresh(), findsNothing);

    await _selectTab(tester, 'Turnover');
    expect(find.byType(AppTabToolbarPrimary), findsNothing);
    expect(find.text('Open housekeeping'), findsNothing);

    await _selectTab(tester, 'Out of service');
    expect(find.byType(AppTabToolbarPrimary), findsNothing);
    expect(find.text('Open operations'), findsNothing);
  });

  testWidgets('unauthorized write next-actions are absent', (
    WidgetTester tester,
  ) async {
    await _pumpRoomsBedsWorkspace(
      tester,
      repository: repository,
      accessPolicy: _readOnlyPolicy(),
    );

    expect(_toolbarPrimary('Create room'), findsNothing);
    expect(_toolbarAction('Manage catalog'), findsNothing);
    expect(find.text('Assign bed'), findsNothing);
    expect(find.text('Release bed'), findsNothing);
    expect(find.text('Mark available'), findsNothing);
    expect(find.bySemanticsLabel('Assign bed'), findsNothing);
    expect(find.bySemanticsLabel('Release bed'), findsNothing);
    expect(find.bySemanticsLabel('Mark available'), findsNothing);
  });

  testWidgets('route bedId filters the board to the target bed', (
    WidgetTester tester,
  ) async {
    await _pumpRoomsBedsWorkspace(
      tester,
      repository: repository,
      initialLocation: '/rooms-beds?bedId=BED-AVAILABLE',
    );

    expect(find.text('Bed A1'), findsWidgets);
    expect(find.text('Bed O1'), findsNothing);
    expect(find.text('Bed C1'), findsNothing);
  });
}
