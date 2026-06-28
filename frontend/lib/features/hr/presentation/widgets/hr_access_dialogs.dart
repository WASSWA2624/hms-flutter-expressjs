import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

Future<void> showHrAccessWorkspaceDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => Consumer(
      builder: (BuildContext context, WidgetRef dialogRef, _) {
        return const _HrAccessWorkspaceDialog();
      },
    ),
  );
}

class _HrAccessWorkspaceDialog extends ConsumerStatefulWidget {
  const _HrAccessWorkspaceDialog();

  @override
  ConsumerState<_HrAccessWorkspaceDialog> createState() =>
      _HrAccessWorkspaceDialogState();
}

class _HrAccessWorkspaceDialogState
    extends ConsumerState<_HrAccessWorkspaceDialog> {
  HrAccessPanel _panel = HrAccessPanel.users;
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  AppFailure? _failure;
  List<HrAccessUser> _users = const <HrAccessUser>[];
  List<HrAccessRole> _roles = const <HrAccessRole>[];
  List<HrAccessPermission> _permissions = const <HrAccessPermission>[];

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final String? tenantId = _tenantId(ref);
    final HrAccessQuery query = HrAccessQuery(
      panel: _panel,
      search: _searchController.text.trim(),
      tenantId: tenantId,
    );

    if (_panel == HrAccessPanel.users) {
      final Result<AppPage<HrAccessUser>> result = await controller
          .loadAccessUsers(query);
      if (!mounted) {
        return;
      }
      result.when(
        success: (AppPage<HrAccessUser> page) {
          setState(() {
            _loading = false;
            _users = page.items;
          });
        },
        failure: (AppFailure failure) {
          setState(() {
            _loading = false;
            _failure = failure;
          });
        },
      );
      return;
    }

    if (_panel == HrAccessPanel.roles) {
      final Result<AppPage<HrAccessRole>> result = await controller
          .loadAccessRoles(query);
      if (!mounted) {
        return;
      }
      result.when(
        success: (AppPage<HrAccessRole> page) {
          setState(() {
            _loading = false;
            _roles = page.items;
          });
        },
        failure: (AppFailure failure) {
          setState(() {
            _loading = false;
            _failure = failure;
          });
        },
      );
      return;
    }

    final Result<AppPage<HrAccessPermission>> result = await controller
        .loadAccessPermissions(query);
    if (!mounted) {
      return;
    }
    result.when(
      success: (AppPage<HrAccessPermission> page) {
        setState(() {
          _loading = false;
          _permissions = page.items;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _loading = false;
          _failure = failure;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.hrAccessWorkspaceTitle),
      icon: const Icon(Icons.manage_accounts_outlined),
      scrollable: true,
      maxWidth: 920,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.hrAccessWorkspaceDescription,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          SegmentedButton<HrAccessPanel>(
            segments: <ButtonSegment<HrAccessPanel>>[
              ButtonSegment<HrAccessPanel>(
                value: HrAccessPanel.users,
                label: Text(l10n.hrAccessPanelUsers),
              ),
              ButtonSegment<HrAccessPanel>(
                value: HrAccessPanel.roles,
                label: Text(l10n.hrAccessPanelRoles),
              ),
              ButtonSegment<HrAccessPanel>(
                value: HrAccessPanel.permissions,
                label: Text(l10n.hrAccessPanelPermissions),
              ),
            ],
            selected: <HrAccessPanel>{_panel},
            onSelectionChanged: (Set<HrAccessPanel> value) {
              final HrAccessPanel? next = value.firstOrNull;
              if (next == null || next == _panel) {
                return;
              }
              setState(() => _panel = next);
              unawaited(_reload());
            },
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _searchController,
            labelText: l10n.hrAccessSearchLabel,
            onFieldSubmitted: (_) => unawaited(_reload()),
          ),
          const SizedBox(height: 12),
          if (_loading)
            AppStateView(
              variant: AppStateViewVariant.loading,
              title: l10n.hrAccessWorkspaceTitle,
              body: l10n.hrAccessSearchLabel,
            )
          else if (_failure != null)
            AppFailureStateView(
              failure: _failure!,
              onRetry: () => unawaited(_reload()),
            )
          else
            _buildPanelContent(context, l10n),
        ],
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonRefreshActionLabel,
          leadingIcon: Icons.refresh,
          onPressed: _loading ? null : () => unawaited(_reload()),
        ),
        if (_panel == HrAccessPanel.users)
          AppButton.primary(
            label: l10n.hrCreateUserAction,
            leadingIcon: Icons.person_add_outlined,
            onPressed: () async {
              await showHrCreateStandaloneUserDialog(context, ref);
              if (context.mounted) {
                unawaited(_reload());
              }
            },
          ),
        if (_panel == HrAccessPanel.roles)
          AppButton.primary(
            label: l10n.hrAccessCreateRoleAction,
            leadingIcon: Icons.add_moderator_outlined,
            onPressed: () async {
              await showHrCreateRoleDialog(context, ref);
              if (context.mounted) {
                unawaited(_reload());
              }
            },
          ),
        if (_panel == HrAccessPanel.permissions)
          AppButton.primary(
            label: l10n.hrAccessCreatePermissionAction,
            leadingIcon: Icons.add_circle_outline,
            onPressed: () async {
              await showHrCreatePermissionDialog(context, ref);
              if (context.mounted) {
                unawaited(_reload());
              }
            },
          ),
      ],
    );
  }

  Widget _buildPanelContent(BuildContext context, AppLocalizations l10n) {
    return switch (_panel) {
      HrAccessPanel.users => _buildUsers(context, l10n),
      HrAccessPanel.roles => _buildRoles(context, l10n),
      HrAccessPanel.permissions => _buildPermissions(context, l10n),
    };
  }

  Widget _buildUsers(BuildContext context, AppLocalizations l10n) {
    if (_users.isEmpty) {
      return Text(l10n.hrAccessEmptyUsersLabel);
    }
    return Column(
      children: <Widget>[
        for (final HrAccessUser user in _users)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(user.profileName ?? user.email ?? user.effectiveId),
            subtitle: Text(
              <String>[
                if ((user.email ?? '').isNotEmpty) user.email!,
                if (user.roleNames.isNotEmpty) user.roleNames.join(', '),
                if ((user.status ?? '').isNotEmpty) user.status!,
              ].join(' · '),
            ),
            trailing: AppButton.secondary(
              label: l10n.hrAccessEditUserAction,
              onPressed: () async {
                await showHrEditAccessUserDialog(context, ref, user);
                if (context.mounted) {
                  unawaited(_reload());
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRoles(BuildContext context, AppLocalizations l10n) {
    if (_roles.isEmpty) {
      return Text(l10n.hrAccessEmptyRolesLabel);
    }
    return Column(
      children: <Widget>[
        for (final HrAccessRole role in _roles)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(role.name ?? role.effectiveId),
            subtitle: Text(
              l10n.hrAccessRoleSummary(role.permissionCount, role.userCount),
            ),
            trailing: Wrap(
              spacing: 8,
              children: <Widget>[
                AppButton.secondary(
                  label: l10n.hrAccessEditRoleAction,
                  onPressed: role.isSystemCritical
                      ? null
                      : () async {
                          await showHrEditRoleDialog(context, ref, role);
                          if (context.mounted) {
                            unawaited(_reload());
                          }
                        },
                ),
                AppButton.secondary(
                  label: l10n.hrAccessAssignPermissionsAction,
                  onPressed: role.isSystemCritical
                      ? null
                      : () async {
                          await showHrAssignRolePermissionsDialog(
                            context,
                            ref,
                            role,
                          );
                          if (context.mounted) {
                            unawaited(_reload());
                          }
                        },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPermissions(BuildContext context, AppLocalizations l10n) {
    if (_permissions.isEmpty) {
      return Text(l10n.hrAccessEmptyPermissionsLabel);
    }
    return Column(
      children: <Widget>[
        for (final HrAccessPermission permission in _permissions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(permission.name ?? permission.effectiveId),
            subtitle: Text(
              permission.description ??
                  l10n.hrAccessPermissionRoleCount(permission.roleCount),
            ),
            trailing: AppButton.secondary(
              label: l10n.hrAccessEditPermissionAction,
              onPressed: () async {
                await showHrEditPermissionDialog(context, ref, permission);
                if (context.mounted) {
                  unawaited(_reload());
                }
              },
            ),
          ),
      ],
    );
  }
}

String? _tenantId(WidgetRef ref) {
  final HrWorkspaceState? state = ref
      .read(hrWorkspaceControllerProvider)
      .asData
      ?.value
      .when(success: (HrWorkspaceState value) => value, failure: (_) => null);
  return state?.selectedStaff?.profile.tenantId ??
      state?.staff.items.firstOrNull?.tenantId;
}

Future<void> showHrCreateStandaloneUserDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final HrWorkspaceState? state = _readHrState(ref);
  final String? tenantId = _tenantId(ref);
  if (tenantId == null || tenantId.isEmpty) {
    _showHrAccessSnackBar(context, AppFailure.validation());
    return;
  }

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController positionController = TextEditingController();
  final Set<String> selectedRoleIds = <String>{};

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrCreateUserDialogTitle),
    icon: const Icon(Icons.person_add_outlined),
    submitLabel: l10n.hrCreateUserAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return AppFormSection(
        children: <Widget>[
          AppTextField(
            controller: emailController,
            labelText: l10n.hrEmailLabel,
            isRequired: true,
            keyboardType: TextInputType.emailAddress,
            validator: AppValidators.requiredText(
              l10n.hrFieldRequiredLabel(l10n.hrEmailLabel),
            ),
          ),
          AppTextField(
            controller: passwordController,
            labelText: l10n.hrPasswordLabel,
            isRequired: true,
            obscureText: true,
            validator: AppValidators.requiredText(
              l10n.hrFieldRequiredLabel(l10n.hrPasswordLabel),
            ),
          ),
          AppTextField(
            controller: phoneController,
            labelText: l10n.profilePhoneLabel,
            keyboardType: TextInputType.phone,
          ),
          AppTextField(
            controller: positionController,
            labelText: l10n.hrAccessPositionTitleLabel,
          ),
          Text(
            l10n.hrAccessInitialRolesLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final HrOption role in state?.referenceData.roles ?? const [])
            AppCheckboxField(
              title: role.label,
              value: selectedRoleIds.contains(role.value),
              onChanged: (bool checked) {
                if (checked) {
                  selectedRoleIds.add(role.value);
                } else {
                  selectedRoleIds.remove(role.value);
                }
              },
            ),
        ],
      );
    },
    onSubmit: () async {
      final Result<Object?> result = await ref
          .read(hrRepositoryProvider)
          .createUserAccount(<String, Object?>{
            'tenant_id': tenantId,
            'email': emailController.text.trim(),
            'password': passwordController.text.trim(),
            'phone': phoneController.text.trim(),
            'position_title': positionController.text.trim(),
            'status': 'ACTIVE',
          });
      final AppFailure? failure = result.when(
        success: (_) => null,
        failure: (AppFailure value) => value,
      );
      if (failure != null) {
        return failure;
      }
      final String? userId = result.when(
        success: (Object? data) {
          if (data is Map) {
            final Object? nested = data['data'];
            if (nested is Map) {
              return nested['display_id']?.toString() ??
                  nested['human_friendly_id']?.toString() ??
                  nested['id']?.toString();
            }
            return data['display_id']?.toString() ??
                data['human_friendly_id']?.toString() ??
                data['id']?.toString();
          }
          return null;
        },
        failure: (_) => null,
      );
      if (userId != null && selectedRoleIds.isNotEmpty) {
        return controller.assignUserRolesBatch(
          userId: userId,
          tenantId: tenantId,
          roleIds: selectedRoleIds.toList(growable: false),
        );
      }
      return null;
    },
  );
  emailController.dispose();
  passwordController.dispose();
  phoneController.dispose();
  positionController.dispose();
  if (saved == true && context.mounted) {
    _showHrAccessSnackBar(context, null);
  }
}

Future<void> showHrEditAccessUserDialog(
  BuildContext context,
  WidgetRef ref,
  HrAccessUser user,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  String status = user.status ?? 'ACTIVE';

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAccessEditUserAction),
    icon: const Icon(Icons.person_outline),
    submitLabel: l10n.commonSaveActionLabel,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return AppFormSection(
        children: <Widget>[
          AppSelectField<String>(
            value: status,
            labelText: l10n.hrStatusColumnLabel,
            options: const <AppSelectOption<String>>[
              AppSelectOption<String>(value: 'ACTIVE', label: 'Active'),
              AppSelectOption<String>(value: 'INACTIVE', label: 'Inactive'),
              AppSelectOption<String>(value: 'SUSPENDED', label: 'Suspended'),
            ],
            onChanged: (String? value) => status = value ?? status,
          ),
        ],
      );
    },
    onSubmit: () => controller.updateAccessUser(
      user.effectiveId,
      <String, Object?>{'status': status},
    ),
  );
  if (saved == true && context.mounted) {
    _showHrAccessSnackBar(context, null);
  }
}

Future<void> showHrCreateRoleDialog(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final String? tenantId = _tenantId(ref);
  if (tenantId == null || tenantId.isEmpty) {
    _showHrAccessSnackBar(context, AppFailure.validation());
    return;
  }
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAccessCreateRoleAction),
    icon: const Icon(Icons.add_moderator_outlined),
    submitLabel: l10n.commonSaveActionLabel,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return AppFormSection(
        children: <Widget>[
          AppTextField(
            controller: nameController,
            labelText: l10n.hrAccessRoleNameLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              l10n.hrFieldRequiredLabel(l10n.hrAccessRoleNameLabel),
            ),
          ),
          AppTextField(
            controller: descriptionController,
            labelText: l10n.hrAccessRoleDescriptionLabel,
            maxLines: 2,
          ),
        ],
      );
    },
    onSubmit: () => controller.createAccessRole(<String, Object?>{
      'tenant_id': tenantId,
      'name': nameController.text.trim(),
      'description': descriptionController.text.trim(),
    }),
  );
  nameController.dispose();
  descriptionController.dispose();
  if (saved == true && context.mounted) {
    _showHrAccessSnackBar(context, null);
  }
}

Future<void> showHrEditRoleDialog(
  BuildContext context,
  WidgetRef ref,
  HrAccessRole role,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final TextEditingController nameController = TextEditingController(
    text: role.name,
  );
  final TextEditingController descriptionController = TextEditingController(
    text: role.description,
  );

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAccessEditRoleAction),
    icon: const Icon(Icons.edit_outlined),
    submitLabel: l10n.commonSaveActionLabel,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return AppFormSection(
        children: <Widget>[
          AppTextField(
            controller: nameController,
            labelText: l10n.hrAccessRoleNameLabel,
            isRequired: true,
          ),
          AppTextField(
            controller: descriptionController,
            labelText: l10n.hrAccessRoleDescriptionLabel,
            maxLines: 2,
          ),
        ],
      );
    },
    onSubmit: () =>
        controller.updateAccessRole(role.effectiveId, <String, Object?>{
          'name': nameController.text.trim(),
          'description': descriptionController.text.trim(),
        }),
  );
  nameController.dispose();
  descriptionController.dispose();
  if (saved == true && context.mounted) {
    _showHrAccessSnackBar(context, null);
  }
}

Future<void> showHrAssignRolePermissionsDialog(
  BuildContext context,
  WidgetRef ref,
  HrAccessRole role,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final String? tenantId = _tenantId(ref);
  final Result<AppPage<HrAccessPermission>> permissionsResult = await controller
      .loadAccessPermissions(
        HrAccessQuery(panel: HrAccessPanel.permissions, tenantId: tenantId),
      );
  if (!context.mounted) {
    return;
  }
  final List<HrAccessPermission> permissionOptions = permissionsResult.when(
    success: (AppPage<HrAccessPermission> page) => page.items,
    failure: (_) => const <HrAccessPermission>[],
  );
  final Set<String> selectedPermissionIds = <String>{};

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAccessAssignPermissionsAction),
    icon: const Icon(Icons.security_outlined),
    submitLabel: l10n.commonSaveActionLabel,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return AppFormSection(
        children: <Widget>[
          Text(
            role.name ?? role.effectiveId,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (permissionOptions.isEmpty)
            Text(l10n.hrAccessEmptyPermissionsLabel)
          else
            for (final HrAccessPermission permission in permissionOptions)
              AppCheckboxField(
                title: permission.name ?? permission.effectiveId,
                value: selectedPermissionIds.contains(permission.effectiveId),
                onChanged: (bool checked) {
                  if (checked) {
                    selectedPermissionIds.add(permission.effectiveId);
                  } else {
                    selectedPermissionIds.remove(permission.effectiveId);
                  }
                },
              ),
        ],
      );
    },
    onSubmit: () => controller.assignRolePermissionsBatch(
      roleId: role.effectiveId,
      permissionIds: selectedPermissionIds.toList(growable: false),
    ),
  );
  if (saved == true && context.mounted) {
    _showHrAccessSnackBar(context, null);
  }
}

Future<void> showHrCreatePermissionDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final String? tenantId = _tenantId(ref);
  if (tenantId == null || tenantId.isEmpty) {
    _showHrAccessSnackBar(context, AppFailure.validation());
    return;
  }
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAccessCreatePermissionAction),
    icon: const Icon(Icons.add_circle_outline),
    submitLabel: l10n.commonSaveActionLabel,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return AppFormSection(
        children: <Widget>[
          AppTextField(
            controller: nameController,
            labelText: l10n.hrAccessPermissionNameLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              l10n.hrFieldRequiredLabel(l10n.hrAccessPermissionNameLabel),
            ),
          ),
          AppTextField(
            controller: descriptionController,
            labelText: l10n.hrAccessPermissionDescriptionLabel,
            maxLines: 2,
          ),
        ],
      );
    },
    onSubmit: () => controller.createAccessPermission(<String, Object?>{
      'tenant_id': tenantId,
      'name': nameController.text.trim(),
      'description': descriptionController.text.trim(),
    }),
  );
  nameController.dispose();
  descriptionController.dispose();
  if (saved == true && context.mounted) {
    _showHrAccessSnackBar(context, null);
  }
}

Future<void> showHrEditPermissionDialog(
  BuildContext context,
  WidgetRef ref,
  HrAccessPermission permission,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final TextEditingController nameController = TextEditingController(
    text: permission.name,
  );
  final TextEditingController descriptionController = TextEditingController(
    text: permission.description,
  );

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAccessEditPermissionAction),
    icon: const Icon(Icons.edit_outlined),
    submitLabel: l10n.commonSaveActionLabel,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return AppFormSection(
        children: <Widget>[
          AppTextField(
            controller: nameController,
            labelText: l10n.hrAccessPermissionNameLabel,
            isRequired: true,
          ),
          AppTextField(
            controller: descriptionController,
            labelText: l10n.hrAccessPermissionDescriptionLabel,
            maxLines: 2,
          ),
        ],
      );
    },
    onSubmit: () => controller
        .updateAccessPermission(permission.effectiveId, <String, Object?>{
          'name': nameController.text.trim(),
          'description': descriptionController.text.trim(),
        }),
  );
  nameController.dispose();
  descriptionController.dispose();
  if (saved == true && context.mounted) {
    _showHrAccessSnackBar(context, null);
  }
}

void _showHrAccessSnackBar(BuildContext context, AppFailure? failure) {
  if (!context.mounted) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null ? l10n.hrSavedMessage : l10n.failureMessage(failure),
      ),
    ),
  );
}

HrWorkspaceState? _readHrState(WidgetRef ref) {
  return ref
      .read(hrWorkspaceControllerProvider)
      .asData
      ?.value
      .when(success: (HrWorkspaceState state) => state, failure: (_) => null);
}
