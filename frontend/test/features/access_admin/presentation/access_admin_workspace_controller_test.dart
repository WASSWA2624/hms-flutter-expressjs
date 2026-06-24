import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/access_admin/data/repositories/access_admin_repository_impl.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/repositories/access_admin_repository.dart';
import 'package:hosspi_hms/features/access_admin/presentation/controllers/access_admin_workspace_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockAccessAdminRepository extends Mock implements AccessAdminRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const AccessAdminWorkspaceQuery());
    registerFallbackValue(
      const AccessAdminUserDraft(
        tenantId: 'tenant-1',
        email: 'user@example.com',
        positionTitle: 'Nurse',
        password: 'Password123',
      ),
    );
  });

  group('AccessAdminWorkspaceController', () {
    test('applyResource switches to roles panel', () async {
      final _MockAccessAdminRepository repository = _MockAccessAdminRepository();
      when(() => repository.getWorkspace(any())).thenAnswer(
        (_) async => const Result<AccessAdminWorkspaceData>.success(
          AccessAdminWorkspaceData(),
        ),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [
          accessAdminRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(accessAdminWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(accessAdminWorkspaceControllerProvider.notifier)
          .applyResource(AccessAdminResource.roles);

      expect(failure, isNull);
      verify(
        () => repository.getWorkspace(
          any(
            that: predicate<AccessAdminWorkspaceQuery>(
              (AccessAdminWorkspaceQuery query) =>
                  query.resource == AccessAdminResource.roles &&
                  query.panel == AccessAdminPanel.roles,
            ),
          ),
        ),
      ).called(greaterThanOrEqualTo(1));
    });
  });
}
