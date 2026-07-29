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
    HrOption(value: 'dept-lab', label: 'Laboratory'),
  ],
  units: <HrOption>[
    HrOption(
      value: 'unit-er-1',
      label: 'ER Triage',
      extra: <String, Object?>{'department_id': 'dept-er'},
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

void _stubWorkspaceBootstrap(_MockHrRepository repository) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async =>
        const Result<HrWorkspaceOverview>.success(HrWorkspaceOverview()),
  );
  when(() => repository.listStaffProfiles(any())).thenAnswer(
    (_) async => const Result<AppPage<HrStaffProfile>>.success(
      AppPage<HrStaffProfile>(
        items: <HrStaffProfile>[_selectedStaff],
        request: AppPageRequest(),
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
    (_) async => const Result<HrStaffDetail>.success(
      HrStaffDetail(profile: _selectedStaff),
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
  const _AssignDepartmentLauncher();

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
          .selectStaff(_selectedStaff);
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
  _MockHrRepository repository,
) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspaceBootstrap(repository);

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
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: _AssignDepartmentLauncher()),
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

  testWidgets('shows assign department form fields', (
    WidgetTester tester,
  ) async {
    await _pumpAssignDepartmentDialog(tester, repository);

    expect(find.text('Assign department'), findsWidgets);
    expect(find.textContaining('Department'), findsOneWidget);
    expect(find.textContaining('Unit'), findsOneWidget);
    expect(find.textContaining('Start date'), findsOneWidget);
    expect(find.textContaining('End date'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
