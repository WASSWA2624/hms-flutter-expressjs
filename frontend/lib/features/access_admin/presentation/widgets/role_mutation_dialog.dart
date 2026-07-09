import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/app_permission_catalog_localizations.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';
import 'package:hosspi_hms/shared/forms/app_validators.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_mutation_dialog.dart';

enum RoleMutationMode { create, edit }

typedef RoleMutationSubmitHandler =
    Future<AppFailure?> Function(AccessAdminRoleDraft draft);

Future<bool?> showRoleMutationDialog({
  required BuildContext context,
  required RoleMutationMode mode,
  required List<AccessAdminLookupOption> permissionLookups,
  required String tenantId,
  String? facilityId,
  String? initialName,
  String? initialDescription,
  Set<String> initialPermissionIds = const <String>{},
  required RoleMutationSubmitHandler onSubmit,
}) async {
  final AppLocalizations l10n = context.l10n;
  final TextEditingController nameController = TextEditingController(
    text: initialName,
  );
  final TextEditingController descriptionController = TextEditingController(
    text: initialDescription,
  );
  final Set<String> selectedPermissionIds = Set<String>.from(
    initialPermissionIds,
  );
  final List<AppPermissionAssignmentOption> permissionOptions =
      permissionLookups
          .map(
            (AccessAdminLookupOption option) => AppPermissionAssignmentOption(
              id: option.id,
              code: option.label,
              label: l10n.permissionCatalogLabelForCode(option.label),
              description: option.label,
            ),
          )
          .toList(growable: false);

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(
      mode == RoleMutationMode.create
          ? l10n.accessAdminCreateRoleAction
          : l10n.accessAdminEditRoleAction,
    ),
    icon: Icon(
      mode == RoleMutationMode.create
          ? Icons.add_moderator_outlined
          : Icons.edit_outlined,
    ),
    submitLabel: l10n.commonSaveActionLabel,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    maxWidth: 720,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool isSubmitting, [
          AppFailure? failure,
        ]) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AppFormSection(
                children: <Widget>[
                  AppTextField(
                    controller: nameController,
                    enabled: !isSubmitting,
                    labelText: l10n.accessAdminRoleNameLabel,
                    isRequired: true,
                    validator: AppValidators.requiredText(
                      l10n.validationRequired,
                    ),
                  ),
                  AppTextField(
                    controller: descriptionController,
                    enabled: !isSubmitting,
                    labelText: l10n.accessAdminRoleDescriptionLabel,
                    maxLines: 2,
                  ),
                  Text(
                    l10n.accessAdminRolePermissionsLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  SizedBox(height: Theme.of(context).spacing.xs),
                  AppPermissionAssignmentPicker(
                    permissions: permissionOptions,
                    selectedPermissionIds: selectedPermissionIds,
                    onSelectionChanged: (Set<String> next) {
                      setState(() {
                        selectedPermissionIds
                          ..clear()
                          ..addAll(next);
                      });
                    },
                  ),
                  if (selectedPermissionIds.isEmpty)
                    Text(
                      l10n.accessAdminRolePermissionsRequired,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              );
            },
          );
        },
    onSubmit: () {
      if (selectedPermissionIds.isEmpty) {
        return Future<AppFailure?>.value(AppFailure.validation());
      }
      return onSubmit(
        AccessAdminRoleDraft(
          tenantId: tenantId,
          facilityId: facilityId,
          name: nameController.text.trim().toUpperCase(),
          description: descriptionController.text.trim(),
          permissionIds: selectedPermissionIds.toList(growable: false),
        ),
      );
    },
  );

  nameController.dispose();
  descriptionController.dispose();
  return saved;
}
