import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_layout.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_actions.dart';

AppAccessPolicy _elevatedPolicy({
  required List<String> roles,
  required Iterable<AppPermission> permissions,
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: AuthUserProfile(roles: roles),
      permissions: permissions,
      isAuthorizationHydrated: true,
    ),
  );
}

void main() {
  group('home action canonicalization', () {
    test('maps legacy aliases to one primary action id', () {
      expect(homeCanonicalActionId('new_patient'), 'register_patient');
      expect(homeCanonicalActionId('manage_users_roles'), 'manage_users');
      expect(homeCanonicalActionId('view_my_care'), 'update_own_profile');
      expect(homeCanonicalActionId('staff_profile'), 'add_staff_profile');
    });

    test('dedupes alias ids against the canonical definition', () {
      final AppAccessPolicy policy = _elevatedPolicy(
        roles: <String>['SUPER_ADMIN'],
        permissions: AppPermissions.all,
      );

      final List<HomeActionDefinition> actions = homeVisibleActions(
        <String>[
          'create_tenant',
          'manage_users',
          'manage_users_roles',
          'create_user',
        ],
        policy,
      );

      expect(
        actions.map((HomeActionDefinition action) => action.id).toList(),
        <String>['create_tenant', 'manage_users', 'create_user'],
      );
    });

    test('empty actions omit ids already shown as next steps', () {
      final AppAccessPolicy policy = _elevatedPolicy(
        roles: <String>['SUPER_ADMIN'],
        permissions: AppPermissions.all,
      );
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.superAdmin);

      final List<HomeActionDefinition> quick = homeDeduplicateQuickActionsAgainstManage(
        homeVisibleActions(
          profile.quickActionIds,
          policy,
          maxCount: profile.maxQuickActions,
        ),
        profile.emptyActionIds,
        policy,
      );
      final List<HomeActionDefinition> empty = homeVisibleEmptyActions(
        profile.emptyActionIds,
        policy,
        excludeActionIds: quick.map((HomeActionDefinition a) => a.id),
      );

      expect(quick, isEmpty);
      expect(
        empty.map((HomeActionDefinition action) => action.id),
        <String>[
          'manage_tenants',
          'manage_facilities',
          'manage_roles_access',
          'manage_users',
        ],
      );
    });

    test('unauthorized manage actions do not render', () {
      final AppAccessPolicy policy = _elevatedPolicy(
        roles: <String>['PATIENT'],
        permissions: const <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
      );

      final List<HomeActionDefinition> actions = homeVisibleActions(
        <String>['manage_users', 'update_own_profile', 'create_tenant'],
        policy,
      );

      expect(
        actions.map((HomeActionDefinition action) => action.id),
        <String>['update_own_profile'],
      );
    });
  });

  group('profile entry points stay singular', () {
    test('no profile lists both manage_users and manage_users_roles', () {
      for (final AppRole role in AppRole.values) {
        final HomeDashboardProfile profile = homeProfileForRole(role);
        final Set<String> ids = <String>{
          ...profile.quickActionIds,
          ...profile.emptyActionIds,
        };
        expect(
          ids.contains('manage_users') && ids.contains('manage_users_roles'),
          isFalse,
          reason: role.value,
        );
      }
    });

    test('no profile lists book_appointment with check_in_patient', () {
      for (final AppRole role in AppRole.values) {
        final HomeDashboardProfile profile = homeProfileForRole(role);
        final Set<String> ids = profile.quickActionIds.toSet();
        expect(
          ids.contains('book_appointment') && ids.contains('check_in_patient'),
          isFalse,
          reason: role.value,
        );
      }
    });

    test('empty action ids never duplicate quick action ids', () {
      for (final AppRole role in AppRole.values) {
        final HomeDashboardProfile profile = homeProfileForRole(role);
        final Set<String> overlap = profile.emptyActionIds
            .map(homeCanonicalActionId)
            .toSet()
            .intersection(
              profile.quickActionIds.map(homeCanonicalActionId).toSet(),
            );
        expect(overlap, isEmpty, reason: role.value);
      }
    });
  });
}
