import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/app_permission_catalog_localizations.dart';
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
    expect(labels['perm_code'], l10n.accessAdminPermissionCodeColumnLabel);
    expect(labels.containsKey('perm_status'), isFalse);
  });

  testWidgets('permission columns omit Status and show machine codes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    final BuildContext context = tester.element(find.byType(SizedBox));
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    const AccessAdminItem item = AccessAdminItem(
      id: 'perm-1',
      resource: AccessAdminResource.permissions,
      displayId: 'PERM-001',
      title: 'Patient — Read',
      permissionName: 'patient:read',
    );

    final List<AppListTableColumn<AccessAdminItem>> columns =
        accessAdminPermissionColumns(context);
    final List<String> ids = columns
        .map((AppListTableColumn<AccessAdminItem> column) => column.id)
        .whereType<String>()
        .toList();

    expect(ids, isNot(contains('perm_status')));
    expect(accessAdminPermissionMachineCode(item), 'patient:read');
    expect(
      accessAdminPermissionDescription(l10n, item),
      'Allows read access within patient.',
    );
    expect(
      accessAdminPermissionDescription(
        l10n,
        item.copyWith(subtitle: 'Synced description'),
      ),
      'Synced description',
    );

    final AppListTableColumn<AccessAdminItem> codeColumn = columns.firstWhere(
      (AppListTableColumn<AccessAdminItem> column) => column.id == 'perm_code',
    );
    await tester.pumpWidget(
      wrap(Builder(builder: (BuildContext ctx) => codeColumn.cellBuilder(ctx, item))),
    );
    expect(find.text('patient:read'), findsOneWidget);
    expect(find.text(l10n.permissionCatalogPatientRead), findsNothing);
  });

  testWidgets('permissions defaults omit mutation and status columns', (
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
              onRegistrationApprove: (_) async {},
            )
            .map((AppListTableColumn<AccessAdminItem> column) => column.id)
            .whereType<String>()
            .toList();

    expect(
      ids,
      containsAll(<String>['perm_id', 'perm_name', 'perm_description', 'perm_code']),
    );
    expect(ids, isNot(contains('next_action')));
    expect(ids, isNot(contains('perm_status')));
  });
}
