import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/workspace/realtime_delta.dart';
import 'package:hosspi_hms/core/workspace/realtime_sync_action.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/presentation/controllers/access_admin_realtime_delta_applier.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('AccessAdminRealtimeDeltaApplier', () {
    test('upserts user into active users list', () {
      final AccessAdminWorkspaceState state = _usersState(count: 2);
      final AccessAdminWorkspaceState? patched =
          AccessAdminRealtimeDeltaApplier.apply(
            state,
            RealtimeDelta(
              action: RealtimeSyncAction.upsert,
              resourceType: 'user',
              resourceId: 'USR-3',
              entity: <String, Object?>{
                'id': 'USR-3',
                'display_id': 'USR-3',
                'email': 'new@example.com',
                'position_title': 'Admin',
                'status': 'ACTIVE',
              },
            ),
          );

      expect(patched, isNotNull);
      expect(patched!.data.page.items.length, 3);
      expect(patched.data.page.items.first.email, 'new@example.com');
      expect(patched.data.overview.activeUsers, 3);
    });

    test('removes user from list and overview', () {
      final AccessAdminWorkspaceState state = _usersState(count: 2);
      final AccessAdminWorkspaceState? patched =
          AccessAdminRealtimeDeltaApplier.apply(
            state,
            const RealtimeDelta(
              action: RealtimeSyncAction.remove,
              resourceType: 'user',
              resourceId: 'USR-1',
            ),
          );

      expect(patched, isNotNull);
      expect(patched!.data.page.items.length, 1);
      expect(patched.data.overview.activeUsers, 1);
    });
  });
}

AccessAdminWorkspaceState _usersState({required int count}) {
  final List<AccessAdminItem> items = List<AccessAdminItem>.generate(
    count,
    (int index) => AccessAdminItem(
      id: 'USR-${index + 1}',
      resource: AccessAdminResource.users,
      displayId: 'USR-${index + 1}',
      title: 'user$index@example.com',
      email: 'user$index@example.com',
    ),
  );

  return AccessAdminWorkspaceState(
    data: AccessAdminWorkspaceData(
      overview: AccessAdminOverview(activeUsers: count),
      page: AppPage<AccessAdminItem>(
        items: items,
        request: const AppPageRequest(pageSize: 12),
        totalItemCount: count,
      ),
      items: items,
    ),
    query: const AccessAdminWorkspaceQuery(resource: AccessAdminResource.users),
  );
}
