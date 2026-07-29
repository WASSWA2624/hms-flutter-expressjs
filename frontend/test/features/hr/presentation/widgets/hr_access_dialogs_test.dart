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
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/repositories/hr_repository.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_access_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockHrRepository extends Mock implements HrRepository {}

const String _tenantUuid = '550e8400-e29b-41d4-a716-446655440000';

const HrAccessUser _accessUser = HrAccessUser(
  id: 'USR-1',
  displayId: 'USR-1',
  email: 'hr.admin@example.com',
  status: 'ACTIVE',
  profileName: 'HR Admin',
);

SessionState _authenticatedSession({
  String? tenantId,
  List<AppPermission> permissions = const <AppPermission>[
    AppPermissions.hrRead,
    AppPermissions.hrWrite,
    AppPermissions.tenantAdmin,
  ],
}) {
  return SessionState.authenticated(
    session: AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: AuthUserProfile(
        tenantId: tenantId,
        facilityId: tenantId == null ? null : 'facility-1',
        email: 'hr.admin@example.com',
        roles: const <String>['TENANT_ADMIN'],
      ),
      permissions: permissions,
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'hr-rosters', licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspaceBootstrap(_MockHrRepository repository) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async =>
        const Result<HrWorkspaceOverview>.success(HrWorkspaceOverview()),
  );
  when(() => repository.listStaffProfiles(any())).thenAnswer(
    (_) async => const Result<AppPage<HrStaffProfile>>.success(
      AppPage<HrStaffProfile>(
        items: <HrStaffProfile>[],
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
}

class _AccessDialogLauncher extends ConsumerWidget {
  const _AccessDialogLauncher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () => showHrAccessWorkspaceDialog(context),
      child: const Text('Open access'),
    );
  }
}

Future<void> _pumpAccessDialog(
  WidgetTester tester,
  _MockHrRepository repository, {
  String? tenantId = _tenantUuid,
}) async {
  _stubWorkspaceBootstrap(repository);
  final SessionState session = _authenticatedSession(tenantId: tenantId);
  final AppAccessPolicy policy = AppAccessPolicy.fromSession(session.session);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hrRepositoryProvider.overrideWithValue(repository),
        initialSessionStateProvider.overrideWithValue(session),
        appAccessPolicyProvider.overrideWithValue(policy),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: _AccessDialogLauncher()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open access'));
  await tester.pumpAndSettle();
}

void main() {
  late _MockHrRepository repository;

  setUp(() {
    repository = _MockHrRepository();
    registerFallbackValue(const HrAccessQuery());
    registerFallbackValue(const HrStaffQuery());
    registerFallbackValue(const HrWorkItemsQuery());
    when(() => repository.listAllAccessPermissions(any())).thenAnswer(
      (_) async => const Result<List<HrAccessPermission>>.success(
        <HrAccessPermission>[],
      ),
    );
  });

  test('isHrAccessTenantUuid rejects display ids', () {
    expect(isHrAccessTenantUuid('TEN0001'), isFalse);
    expect(isHrAccessTenantUuid(_tenantUuid), isTrue);
  });

  testWidgets('loads users when tenant UUID is resolved', (tester) async {
    when(() => repository.listAccessUsers(any())).thenAnswer(
      (_) async => const Result<AppPage<HrAccessUser>>.success(
        AppPage<HrAccessUser>(
          items: <HrAccessUser>[_accessUser],
          request: AppPageRequest(pageSize: 12),
          totalItemCount: 1,
        ),
      ),
    );

    await _pumpAccessDialog(tester, repository);

    expect(find.text('HR Admin'), findsOneWidget);
    expect(find.text('hr.admin@example.com'), findsOneWidget);
    verify(
      () => repository.listAccessUsers(
        any(
          that: predicate<HrAccessQuery>(
            (HrAccessQuery query) => query.tenantId == _tenantUuid,
          ),
        ),
      ),
    ).called(1);
  });

  testWidgets('shows tenant-required empty state when tenant UUID missing', (
    tester,
  ) async {
    _stubWorkspaceBootstrap(repository);

    await _pumpAccessDialog(tester, repository, tenantId: null);

    expect(find.text('Tenant context required'), findsOneWidget);
    verifyNever(() => repository.listAccessUsers(any()));
  });

  testWidgets('opens staff detail without limit validation error', (
    tester,
  ) async {
    when(() => repository.listAccessUsers(any())).thenAnswer(
      (_) async => const Result<AppPage<HrAccessUser>>.success(
        AppPage<HrAccessUser>(
          items: <HrAccessUser>[_accessUser],
          request: AppPageRequest(pageSize: 12),
          totalItemCount: 1,
        ),
      ),
    );
    when(() => repository.loadAccessUserDetail(any())).thenAnswer(
      (_) async => const Result<HrAccessUserDetail>.success(
        HrAccessUserDetail(
          id: 'USR-1',
          displayId: 'USR-1',
          email: 'hr.admin@example.com',
          profileName: 'HR Admin',
          status: 'ACTIVE',
        ),
      ),
    );
    when(
      () => repository.listUserRoles(
        userId: any(named: 'userId'),
        tenantId: any(named: 'tenantId'),
      ),
    ).thenAnswer(
      (_) async => const Result<List<HrUserRole>>.success(<HrUserRole>[]),
    );

    await _pumpAccessDialog(tester, repository);
    await tester.tap(find.text('HR Admin'));
    await tester.pumpAndSettle();

    expect(find.text('hr.admin@example.com'), findsWidgets);
    verify(
      () => repository.listUserRoles(userId: 'USR-1', tenantId: _tenantUuid),
    ).called(1);
  });
}
