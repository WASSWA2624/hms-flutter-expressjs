import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/access_admin/data/repositories/access_admin_repository_impl.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/repositories/access_admin_repository.dart';
import 'package:hosspi_hms/features/access_admin/presentation/controllers/access_admin_workspace_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockAccessAdminRepository extends Mock
    implements AccessAdminRepository {}

const AccessAdminItem _user = AccessAdminItem(
  id: 'USR-0042',
  resource: AccessAdminResource.users,
  displayId: 'USR-0042',
  title: 'Grace Nakato',
  email: 'grace.nakato@example.com',
  status: 'ACTIVE',
);

const AccessAdminUserDraft _draft = AccessAdminUserDraft(
  tenantId: 'tenant-1',
  facilityId: 'facility-1',
  email: 'grace.nakato@example.com',
  firstName: 'Grace',
  positionTitle: 'Charge Nurse',
  password: 'StrongPass123!',
  roleIds: <String>['role-1'],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const AccessAdminWorkspaceQuery());
    registerFallbackValue(_draft);
  });

  late _MockAccessAdminRepository repository;
  late ProviderContainer container;

  Future<AccessAdminWorkspaceController> readyController() async {
    container = ProviderContainer(
      overrides: [accessAdminRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(accessAdminWorkspaceControllerProvider.future);
    clearInteractions(repository);
    return container.read(accessAdminWorkspaceControllerProvider.notifier);
  }

  setUp(() {
    repository = _MockAccessAdminRepository();
    when(() => repository.getWorkspace(any())).thenAnswer(
      (_) async => const Result<AccessAdminWorkspaceData>.success(
        AccessAdminWorkspaceData(),
      ),
    );
  });

  group('AccessAdminWorkspaceController user lifecycle', () {
    test('create sends the roles with the account and refreshes the list', () async {
      when(() => repository.createUser(any())).thenAnswer(
        (_) async => const Result<String>.success('USR-0042'),
      );
      final AccessAdminWorkspaceController controller = await readyController();

      final Result<AccessAdminItem> result = await controller
          .createUserReviewed(_draft);

      expect(result.when(success: (_) => true, failure: (_) => false), isTrue);
      final AccessAdminUserDraft sent =
          verify(() => repository.createUser(captureAny())).captured.single
              as AccessAdminUserDraft;
      expect(sent.roleIds, <String>['role-1']);
      verify(() => repository.getWorkspace(any())).called(greaterThanOrEqualTo(1));
    });

    test('activate or deactivate refreshes the list', () async {
      when(
        () => repository.setUserStatus(any(), any()),
      ).thenAnswer((_) async => const Result<void>.success(null));
      final AccessAdminWorkspaceController controller = await readyController();

      final AppFailure? failure = await controller.setUserStatus(
        _user,
        'INACTIVE',
      );

      expect(failure, isNull);
      verify(() => repository.setUserStatus(_user.mutationId, 'INACTIVE')).called(1);
      verify(() => repository.getWorkspace(any())).called(greaterThanOrEqualTo(1));
    });

    test('credential reset refreshes the list after a reset is issued', () async {
      when(() => repository.resetUserCredentials(any())).thenAnswer(
        (_) async => const Result<AccessAdminCredentialResetResult>.success(
          AccessAdminCredentialResetResult(
            delivery: AccessAdminCredentialDelivery.sent,
            maskedEmail: 'gr***@e***.com',
          ),
        ),
      );
      final AccessAdminWorkspaceController controller = await readyController();

      final Result<AccessAdminCredentialResetResult> result = await controller
          .resetUserCredentials(_user);

      expect(result.when(success: (_) => true, failure: (_) => false), isTrue);
      verify(() => repository.resetUserCredentials(_user.mutationId)).called(1);
      verify(() => repository.getWorkspace(any())).called(greaterThanOrEqualTo(1));
    });

    test('a failed credential reset leaves the list alone', () async {
      when(() => repository.resetUserCredentials(any())).thenAnswer(
        (_) async => const Result<AccessAdminCredentialResetResult>.failure(
          AppFailure.forbidden(),
        ),
      );
      final AccessAdminWorkspaceController controller = await readyController();

      final Result<AccessAdminCredentialResetResult> result = await controller
          .resetUserCredentials(_user);

      expect(result.when(success: (_) => true, failure: (_) => false), isFalse);
      verifyNever(() => repository.getWorkspace(any()));
    });

    test('demo accounts are never sent for a credential reset', () async {
      final AccessAdminWorkspaceController controller = await readyController();

      final Result<AccessAdminCredentialResetResult> result = await controller
          .resetUserCredentials(
            const AccessAdminItem(
              id: 'USR-DEMO',
              resource: AccessAdminResource.demoUsers,
              displayId: 'USR-DEMO',
              title: 'Demo Doctor',
              isDemo: true,
            ),
          );

      expect(result.when(success: (_) => true, failure: (_) => false), isFalse);
      verifyNever(() => repository.resetUserCredentials(any()));
    });
  });
}
