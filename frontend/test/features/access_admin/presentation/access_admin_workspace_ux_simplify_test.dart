import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_workspace_table.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  final String pageSource = File(
    'lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart',
  ).readAsStringSync();

  group('duplicates removed (source)', () {
    test('Overview tab is excluded from the tab strip', () {
      expect(
        pageSource.contains('panel != AccessAdminPanel.overview'),
        isTrue,
      );
      expect(
        pageSource.contains('accessAdminPanelOverview'),
        isFalse,
        reason: 'Overview label must not appear as a tab',
      );
    });

    test('tab-strip Refresh secondary action is absent', () {
      expect(pageSource.contains('commonRefreshActionLabel'), isFalse);
      expect(pageSource.contains('secondaryActions:'), isFalse);
    });

    test('create user uses shared mutation dialog only', () {
      expect(
        pageSource.contains('openAccessAdminCreateUserDialog'),
        isTrue,
      );
      expect(
        pageSource.contains('AccessAdminUserDraft('),
        isFalse,
        reason: 'Inline create-user draft must not remain on the page',
      );
    });

    test('create role does not force an extra refresh after dialog', () {
      expect(pageSource.contains('openAccessAdminCreateRoleDialog'), isTrue);
      expect(
        pageSource.contains('_showCreateRoleDialog'),
        isTrue,
      );
      final String createRoleBody = pageSource.substring(
        pageSource.indexOf('Future<void> _showCreateRoleDialog('),
        pageSource.indexOf('void _showSnack('),
      );
      expect(createRoleBody.contains('.refresh()'), isFalse);
    });

    test('detail no longer duplicates row next-actions', () {
      expect(
        pageSource.contains('accessAdminEditRoleAction'),
        isFalse,
        reason: 'Edit role stays on the list next-action only',
      );
      expect(
        pageSource.contains('accessAdminDeactivateAction'),
        isFalse,
        reason: 'Status toggle stays on the list next-action only',
      );
      expect(
        pageSource.contains('accessAdminActivateAction'),
        isFalse,
        reason: 'Status toggle stays on the list next-action only',
      );
      expect(
        pageSource.contains('accessAdminActivateRegistrationAction'),
        isFalse,
        reason: 'Activate registration stays on the list next-action only',
      );
      expect(
        pageSource.contains('accessAdminRejectRegistrationAction'),
        isTrue,
        reason: 'Reject remains detail-only',
      );
      expect(
        pageSource.contains('accessAdminDeleteRoleAction'),
        isTrue,
        reason: 'Delete role remains detail-only with confirm',
      );
    });

    test('mobile rows wire the shared next-action trailing', () {
      expect(pageSource.contains('accessAdminMobileNextAction'), isTrue);
      expect(pageSource.contains('trailing: accessAdminMobileNextAction'), isTrue);
    });
  });

  group('accessAdminMobileNextAction', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (BuildContext context) => child),
      );
    }

    testWidgets('shows Activate/Deactivate for users when canWrite', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));
      final AppLocalizations l10n = context.l10n;

      AccessAdminItem? toggled;
      final Widget? action = accessAdminMobileNextAction(
        context,
        resource: AccessAdminResource.users,
        item: const AccessAdminItem(
          id: 'u1',
          resource: AccessAdminResource.users,
          displayId: 'USR-1',
          title: 'Pat',
          status: 'ACTIVE',
        ),
        canWrite: true,
        onUserStatusToggle: (AccessAdminItem item) async {
          toggled = item;
        },
        onRoleEdit: (_) {},
        onRegistrationActivate: (_) async {},
      );

      expect(action, isA<AppButton>());
      await tester.pumpWidget(wrap(action!));
      expect(find.text(l10n.accessAdminDeactivateAction), findsOneWidget);

      await tester.tap(find.text(l10n.accessAdminDeactivateAction));
      await tester.pump();
      expect(toggled?.id, 'u1');
    });

    testWidgets('omits next-action when unauthorized', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      expect(
        accessAdminMobileNextAction(
          context,
          resource: AccessAdminResource.users,
          item: const AccessAdminItem(
            id: 'u1',
            resource: AccessAdminResource.users,
            displayId: 'USR-1',
            title: 'Pat',
            status: 'INACTIVE',
          ),
          canWrite: false,
          onUserStatusToggle: (_) async {},
          onRoleEdit: (_) {},
          onRegistrationActivate: (_) async {},
        ),
        isNull,
      );
    });

    testWidgets('shows Edit role for non-critical roles when canWrite', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));
      final AppLocalizations l10n = context.l10n;

      AccessAdminItem? edited;
      final Widget? action = accessAdminMobileNextAction(
        context,
        resource: AccessAdminResource.roles,
        item: const AccessAdminItem(
          id: 'r1',
          resource: AccessAdminResource.roles,
          displayId: 'ROL-1',
          title: 'Nurse',
          isSystemCritical: false,
        ),
        canWrite: true,
        onUserStatusToggle: (_) async {},
        onRoleEdit: (AccessAdminItem item) {
          edited = item;
        },
        onRegistrationActivate: (_) async {},
      );

      await tester.pumpWidget(wrap(action!));
      expect(find.text(l10n.accessAdminEditRoleAction), findsOneWidget);
      await tester.tap(find.text(l10n.accessAdminEditRoleAction));
      await tester.pump();
      expect(edited?.id, 'r1');
    });

    testWidgets('hides Edit role for system-critical roles', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      expect(
        accessAdminMobileNextAction(
          context,
          resource: AccessAdminResource.roles,
          item: const AccessAdminItem(
            id: 'r1',
            resource: AccessAdminResource.roles,
            displayId: 'ROL-1',
            title: 'Admin',
            isSystemCritical: true,
          ),
          canWrite: true,
          onUserStatusToggle: (_) async {},
          onRoleEdit: (_) {},
          onRegistrationActivate: (_) async {},
        ),
        isNull,
      );
    });
  });
}
