import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
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

    test('denies HomeActionDefinition with empty permission lists', () {
      final AppAccessPolicy policy = _elevatedPolicy(
        roles: <String>['PLATFORM_ADMIN'],
        permissions: AppPermissions.all,
      );
      const HomeActionDefinition bare = HomeActionDefinition(
        id: 'ungated_probe',
        label: 'Ungated probe',
        icon: Icons.warning_amber_outlined,
        route: AppRoutes.home,
      );

      expect(bare.isAllowed(policy), isFalse);
      expect(
        homeVisibleActions(const <String>['ungated_probe'], policy),
        isEmpty,
      );
    });

    test('dedupes alias ids against the canonical definition', () {
      final AppAccessPolicy policy = _elevatedPolicy(
        roles: <String>['PLATFORM_ADMIN'],
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

    test('platform admin exposes no quick or manage entry points', () {
      final AppAccessPolicy policy = _elevatedPolicy(
        roles: <String>['PLATFORM_ADMIN'],
        permissions: AppPermissions.all,
      );
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.platformAdmin);

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
      expect(empty, isEmpty);
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
