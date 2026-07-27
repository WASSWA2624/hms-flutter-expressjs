import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_workspace_table.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (BuildContext context) => child),
    );
  }

  testWidgets('permission columns use Permission ID/Name/Description labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    final BuildContext context = tester.element(find.byType(SizedBox));
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final List<AppListTableColumn<AccessAdminItem>> columns =
        accessAdminPermissionColumns(context);
    final Map<String, String> labels = <String, String>{
      for (final AppListTableColumn<AccessAdminItem> column in columns)
        if (column.id != null) column.id!: column.label,
    };

    expect(labels['perm_id'], l10n.accessAdminPermissionIdColumnLabel);
    expect(labels['perm_name'], l10n.accessAdminPermissionNameColumnLabel);
    expect(
      labels['perm_description'],
      l10n.accessAdminPermissionDescriptionColumnLabel,
    );
    expect(labels['perm_id'], 'Permission ID');
    expect(labels['perm_name'], 'Permission Name');
    expect(labels['perm_description'], 'Description');
  });

  testWidgets('permissions defaults omit mutation next_action column', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    final BuildContext context = tester.element(find.byType(SizedBox));

    final List<String> ids =
        accessAdminDefaultColumns(
              context,
              resource: AccessAdminResource.permissions,
              canWrite: true,
              onUserStatusToggle: (_) async {},
              onRoleEdit: (_) {},
              onRegistrationActivate: (_) async {},
            )
            .map((AppListTableColumn<AccessAdminItem> column) => column.id)
            .whereType<String>()
            .toList();

    expect(ids, containsAll(<String>['perm_id', 'perm_name', 'perm_description']));
    expect(ids, isNot(contains('next_action')));
  });
}
