import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/repositories/hr_repository.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_assign_department_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/app_responsive_field_row.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockHrRepository extends Mock implements HrRepository {}

AppAccessPolicy _hrWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['HR'],
        tenantId: '550e8400-e29b-41d4-a716-446655440000',
        facilityId: 'facility-1',
      ),
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: hrRostersModule, licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

const HrReferenceData _referenceData = HrReferenceData(
  departments: <HrOption>[
    HrOption(value: 'dept-er', label: 'Emergency'),
    HrOption(
      value: 'DEP-TEST',
      label: 'Testing',
      displayId: 'DEP-TEST',
      extra: <String, Object?>{'entity_id': 'uuid-testing-dept'},
    ),
    HrOption(value: 'dept-lab', label: 'Laboratory'),
  ],
  units: <HrOption>[
    HrOption(
      value: 'unit-er-1',
      label: 'ER Triage',
      extra: <String, Object?>{'department_id': 'dept-er'},
    ),
    HrOption(
      value: 'unit-test-1',
      label: 'Testing Unit',
      extra: <String, Object?>{'department_id': 'uuid-testing-dept'},
    ),
  ],
  rooms: <HrOption>[
    HrOption(
      value: 'room-er-1',
      label: 'ER Room 1',
      extra: <String, Object?>{'department_id': 'dept-er'},
    ),
    HrOption(
      value: 'room-er-2',
      label: 'ER Room 2',
      extra: <String, Object?>{'department_id': 'dept-er'},
    ),
  ],
);

const HrStaffProfile _selectedStaff = HrStaffProfile(
  id: 'staff-1',
  displayId: 'STF0001',
  staffNumber: 'EMP-001',
);

const HrStaffProfile _assignedStaff = HrStaffProfile(
  id: 'staff-2',
  displayId: 'STF0002',
  staffNumber: 'EMP-002',
  departmentId: 'dept-er',
  departmentName: 'Emergency',
);

const HrStaffDetail _assignedDetail = HrStaffDetail(
  profile: _assignedStaff,
  assignments: <HrStaffAssignment>[
    HrStaffAssignment(
      id: 'asg-1',
      departmentId: 'dept-er',
      departmentName: 'Emergency',
      unitId: 'unit-er-1',
      unitName: 'ER Triage',
      roomId: 'room-er-1',
      isActive: true,
      isPrimary: true,
    ),
  ],
);

void _stubWorkspaceBootstrap(
  _MockHrRepository repository, {
  HrStaffProfile staff = _selectedStaff,
  HrStaffDetail? detail,
}) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async =>
        const Result<HrWorkspaceOverview>.success(HrWorkspaceOverview()),
  );
  when(() => repository.listStaffProfiles(any())).thenAnswer(
    (_) async => Result<AppPage<HrStaffProfile>>.success(
      AppPage<HrStaffProfile>(
        items: <HrStaffProfile>[staff],
        request: const AppPageRequest(),
      ),
    ),
  );
  when(
    () => repository.loadReferenceData(
      facilityId: any(named: 'facilityId'),
      departmentId: any(named: 'departmentId'),
    ),
  ).thenAnswer(
    (_) async => const Result<HrReferenceData>.success(_referenceData),
  );
  when(() => repository.listWorkItems(any())).thenAnswer(
    (_) async => const Result<AppPage<HrWorkItem>>.success(
      AppPage<HrWorkItem>(
        items: <HrWorkItem>[],
        request: AppPageRequest(pageSize: 10),
      ),
    ),
  );
  when(() => repository.loadStaffDetail(any())).thenAnswer(
    (_) async => Result<HrStaffDetail>.success(
      detail ?? HrStaffDetail(profile: staff),
    ),
  );
  when(() => repository.loadStaffAccessSummary(any())).thenAnswer(
    (_) async =>
        const Result<HrStaffAccessSummary>.success(HrStaffAccessSummary()),
  );
  when(
    () => repository.createStaffAssignment(any()),
  ).thenAnswer((_) async => const Result<Object?>.success(<String, Object?>{}));
}

class _AssignDepartmentLauncher extends ConsumerStatefulWidget {
  const _AssignDepartmentLauncher({required this.staff});

  final HrStaffProfile staff;

  @override
  ConsumerState<_AssignDepartmentLauncher> createState() =>
      _AssignDepartmentLauncherState();
}

class _AssignDepartmentLauncherState
    extends ConsumerState<_AssignDepartmentLauncher> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(hrWorkspaceControllerProvider.future);
      await ref
          .read(hrWorkspaceControllerProvider.notifier)
          .selectStaff(widget.staff);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => showHrAssignDepartmentDialog(context, ref),
      child: const Text('Open assign department'),
    );
  }
}

Future<void> _pumpAssignDepartmentDialog(
  WidgetTester tester,
  _MockHrRepository repository, {
  HrStaffProfile staff = _selectedStaff,
  HrStaffDetail? detail,
  Size viewport = const Size(900, 800),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspaceBootstrap(repository, staff: staff, detail: detail);

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hrRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(_hrWritePolicy()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: _AssignDepartmentLauncher(staff: staff)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.tap(find.text('Open assign department'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  late _MockHrRepository repository;

  setUp(() {
    repository = _MockHrRepository();
  });

  setUpAll(() {
    registerFallbackValue(const HrStaffQuery());
    registerFallbackValue(const HrWorkItemsQuery());
    registerFallbackValue(_selectedStaff);
  });

  testWidgets('shows assign department form fields in two-column rows', (
    WidgetTester tester,
  ) async {
    await _pumpAssignDepartmentDialog(tester, repository);

    expect(find.text('Assign department'), findsWidgets);
    expect(find.textContaining('Department'), findsOneWidget);
    expect(find.textContaining('Unit'), findsOneWidget);
    expect(find.textContaining('Start date'), findsOneWidget);
    expect(find.textContaining('End date'), findsOneWidget);
    expect(find.byType(AppResponsiveFieldRow), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens in change mode with current assignment pre-filled', (
    WidgetTester tester,
  ) async {
    await _pumpAssignDepartmentDialog(
      tester,
      repository,
      staff: _assignedStaff,
      detail: _assignedDetail,
    );

    expect(find.text('Change department'), findsWidgets);
    expect(find.text('Emergency'), findsWidgets);
    expect(find.text('ER Triage'), findsWidgets);
    expect(find.text('ER Room 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'change mode maps UUID department_id to reference option without duplicate',
    (WidgetTester tester) async {
      const HrStaffProfile staff = HrStaffProfile(
        id: 'staff-3',
        displayId: 'STF0003',
        departmentId: 'uuid-testing-dept',
        departmentDisplayId: 'DEP-TEST',
        departmentName: 'Testing',
      );
      const HrStaffDetail detail = HrStaffDetail(
        profile: staff,
        assignments: <HrStaffAssignment>[
          HrStaffAssignment(
            id: 'asg-2',
            departmentId: 'uuid-testing-dept',
            departmentDisplayId: 'DEP-TEST',
            departmentName: 'Testing',
            isActive: true,
            isPrimary: true,
          ),
        ],
      );

      await _pumpAssignDepartmentDialog(
        tester,
        repository,
        staff: staff,
        detail: detail,
      );

      expect(find.text('Change department'), findsWidgets);
      // Prefill resolved to the catalog option value, not a UUID orphan.
      expect(find.text('Testing'), findsWidgets);
      expect(find.text('uuid-testing-dept'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
