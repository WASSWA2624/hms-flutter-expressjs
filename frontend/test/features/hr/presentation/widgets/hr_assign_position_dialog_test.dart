import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/secure_session_storage.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/secure/app_secure_storage.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_staff_position.dart';
import 'package:hosspi_hms/features/hr/domain/repositories/hr_repository.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_assign_position_dialog.dart';
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

const HrStaffProfile _selectedStaff = HrStaffProfile(
  id: 'staff-1',
  displayId: 'STF0001',
  staffNumber: 'EMP-001',
);

const List<HrStaffPosition> _positions = <HrStaffPosition>[
  HrStaffPosition(id: 'pos-1', displayId: 'SPO0001', name: 'Nurse'),
  HrStaffPosition(id: 'pos-2', displayId: 'SPO0002', name: 'Doctor'),
];

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
    (_) async => const Result<HrReferenceData>.success(HrReferenceData()),
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
  when(() => repository.listStaffPositions(any())).thenAnswer(
    (_) async => const Result<AppPage<HrStaffPosition>>.success(
      AppPage<HrStaffPosition>(
        items: _positions,
        request: AppPageRequest(pageSize: 100),
      ),
    ),
  );
}

class _AssignPositionLauncher extends ConsumerStatefulWidget {
  const _AssignPositionLauncher();

  @override
  ConsumerState<_AssignPositionLauncher> createState() =>
      _AssignPositionLauncherState();
}

class _AssignPositionLauncherState
    extends ConsumerState<_AssignPositionLauncher> {
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
      onPressed: () => showHrAssignPositionDialog(context, ref, _selectedStaff),
      child: const Text('Open assign position'),
    );
  }
}

Future<void> _pumpAssignPositionDialog(
  WidgetTester tester,
  _MockHrRepository repository,
) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspaceBootstrap(repository);
  final _MemorySecureStorage storage = _MemorySecureStorage()
    ..values[SecureStorageKeys.accessToken] = 'access-token';

  final AuthSession session = AuthSession(
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
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hrRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          SessionState.authenticated(session: session),
        ),
        secureSessionStorageProvider.overrideWithValue(
          SecureAppSessionStorage(storage),
        ),
        appAccessPolicyProvider.overrideWithValue(_hrWritePolicy()),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: _AssignPositionLauncher()),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open assign position'));
  await tester.pump();
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
    registerFallbackValue(const HrStaffPositionQuery());
    registerFallbackValue(_selectedStaff);
  });

  testWidgets('shows positions table with create and assign actions', (
    WidgetTester tester,
  ) async {
    await _pumpAssignPositionDialog(tester, repository);

    verify(() => repository.listStaffPositions(any())).called(1);
    expect(find.text('ASSIGN POSITION'), findsWidgets);
    expect(find.byIcon(Icons.add_outlined), findsWidgets);
    expect(find.text('Nurse'), findsWidgets);
    expect(find.text('Doctor'), findsWidgets);
    expect(find.byIcon(Icons.check_outlined), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

final class _MemorySecureStorage implements AppSecureStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    values.clear();
  }

  @override
  Future<String?> read(String key) async {
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
