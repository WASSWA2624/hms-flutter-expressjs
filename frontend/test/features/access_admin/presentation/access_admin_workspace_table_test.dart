import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_workspace_table.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (BuildContext context) => child),
    );
  }

  Future<void> Function(AccessAdminItem item) noopAsync =
      (AccessAdminItem _) async {};
  void noopRoleEdit(AccessAdminItem _) {}

  group('accessAdminDefaultColumns', () {
    testWidgets('returns at most five default columns for every resource', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      for (final AccessAdminResource resource in <AccessAdminResource>[
        AccessAdminResource.users,
        AccessAdminResource.demoUsers,
        AccessAdminResource.roles,
        AccessAdminResource.permissions,
        AccessAdminResource.moduleEntitlements,
        AccessAdminResource.registrationFollowUps,
      ]) {
        final List<AppListTableColumn<AccessAdminItem>> columns =
            accessAdminDefaultColumns(
              context,
              resource: resource,
              canWrite: true,
              onUserStatusToggle: noopAsync,
              onRoleEdit: noopRoleEdit,
              onRegistrationActivate: noopAsync,
            );
        expect(
          columns.length,
          lessThanOrEqualTo(5),
          reason: resource.serverValue,
        );
      }
    });

    testWidgets('workflow resources include next_action when canWrite', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      for (final AccessAdminResource resource in <AccessAdminResource>[
        AccessAdminResource.users,
        AccessAdminResource.demoUsers,
        AccessAdminResource.roles,
        AccessAdminResource.registrationFollowUps,
      ]) {
        final List<String> ids =
            accessAdminDefaultColumns(
                  context,
                  resource: resource,
                  canWrite: true,
                  onUserStatusToggle: noopAsync,
                  onRoleEdit: noopRoleEdit,
                  onRegistrationActivate: noopAsync,
                )
                .map((AppListTableColumn<AccessAdminItem> column) => column.id)
                .whereType<String>()
                .toList();
        expect(ids, contains('next_action'), reason: resource.serverValue);
      }
    });

    testWidgets('permissions and entitlements have no next_action column', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      for (final AccessAdminResource resource in <AccessAdminResource>[
        AccessAdminResource.permissions,
        AccessAdminResource.moduleEntitlements,
      ]) {
        final List<String> ids =
            accessAdminDefaultColumns(
                  context,
                  resource: resource,
                  canWrite: true,
                  onUserStatusToggle: noopAsync,
                  onRoleEdit: noopRoleEdit,
                  onRegistrationActivate: noopAsync,
                )
                .map((AppListTableColumn<AccessAdminItem> column) => column.id)
                .whereType<String>()
                .toList();
        expect(ids, isNot(contains('next_action')));
      }
    });
  });

  group('accessAdminColumnVisibilityStorageKey', () {
    test('returns per-resource storage keys', () {
      expect(
        accessAdminColumnVisibilityStorageKey(AccessAdminResource.users),
        'access_admin_workspace_users_v1',
      );
      expect(
        accessAdminColumnVisibilityStorageKey(
          AccessAdminResource.registrationFollowUps,
        ),
        'access_admin_workspace_registrations_v1',
      );
    });
  });

  group('accessAdminSearchMatcher', () {
    testWidgets('matches hidden tenant and role fields for users', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      const AccessAdminItem item = AccessAdminItem(
        id: 'user-1',
        resource: AccessAdminResource.users,
        displayId: 'USR-1',
        title: 'Jane Doe',
        tenantName: 'Acme Health',
        roles: <AccessAdminRoleRef>[
          AccessAdminRoleRef(id: 'role-1', name: 'Nurse'),
        ],
      );

      expect(
        accessAdminSearchMatcher(
          context,
          AccessAdminResource.users,
          item,
          'acme health',
        ),
        isTrue,
      );
      expect(
        accessAdminSearchMatcher(
          context,
          AccessAdminResource.users,
          item,
          'nurse',
        ),
        isTrue,
      );
    });

    testWidgets('matches registration activate action label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      const AccessAdminItem item = AccessAdminItem(
        id: 'reg-1',
        resource: AccessAdminResource.registrationFollowUps,
        displayId: 'REG-1',
        title: 'Pending Clinic',
        status: 'PENDING',
      );

      expect(
        accessAdminSearchMatcher(
          context,
          AccessAdminResource.registrationFollowUps,
          item,
          'activate account',
        ),
        isTrue,
      );
    });
  });

  group('accessAdminFilterGroups', () {
    test('users resource exposes status filter group', () {
      final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));
      final List<AppSearchBarFilterGroup> groups = accessAdminFilterGroups(
        l10n,
        AccessAdminResource.users,
        const AccessAdminLookups(userStatuses: <String>['ACTIVE', 'INACTIVE']),
      );

      expect(groups.single.key, accessAdminStatusFilterKey);
    });

    test('roles resource exposes role scope filter group', () {
      final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));
      final List<AppSearchBarFilterGroup> groups = accessAdminFilterGroups(
        l10n,
        AccessAdminResource.roles,
        const AccessAdminLookups(),
      );

      expect(groups.single.key, accessAdminRoleScopeFilterKey);
    });
  });

  group('registration next action column', () {
    testWidgets('uses Activate account label', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));
      final AppLocalizations l10n = context.l10n;

      final List<AppListTableColumn<AccessAdminItem>> columns =
          accessAdminDefaultColumns(
            context,
            resource: AccessAdminResource.registrationFollowUps,
            canWrite: true,
            onUserStatusToggle: noopAsync,
            onRoleEdit: noopRoleEdit,
            onRegistrationActivate: noopAsync,
          );
      final AppListTableColumn<AccessAdminItem> nextAction = columns.firstWhere(
        (AppListTableColumn<AccessAdminItem> column) =>
            column.id == 'next_action',
      );

      expect(nextAction.label, l10n.accessAdminActivateRegistrationAction);
    });
  });
}
