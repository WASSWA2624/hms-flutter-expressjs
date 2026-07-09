import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/access_admin/data/repositories/access_admin_repository_impl.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/presentation/controllers/access_admin_workspace_controller.dart';
import 'package:hosspi_hms/features/access_admin/presentation/pages/access_admin_workspace_page.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/role_mutation_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

Future<void> showAccessAdminWorkspaceDialog(
  BuildContext context, {
  AccessAdminPanel? initialPanel,
}) async {
  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _AccessAdminWorkspaceDialogShell(initialPanel: initialPanel),
  );
}

Future<void> showAccessAdminCreateUserDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AccessAdminWorkspaceController controller = ref.read(
    accessAdminWorkspaceControllerProvider.notifier,
  );
  final Result<AccessAdminWorkspaceState> stateResult = await ref.read(
    accessAdminWorkspaceControllerProvider.future,
  );
  final AccessAdminWorkspaceState? state = stateResult.when(
    success: (AccessAdminWorkspaceState value) => value,
    failure: (_) => null,
  );
  if (state == null) {
    await controller.refresh();
  }
  final Result<AccessAdminWorkspaceState> refreshed = await ref.read(
    accessAdminWorkspaceControllerProvider.future,
  );
  return refreshed.when(
    success: (AccessAdminWorkspaceState value) =>
        _showCreateUserDialog(context, ref, value),
    failure: (AppFailure failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failureMessage(failure))),
      );
    },
  );
}

Future<void> showAccessAdminCreateRoleDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AccessAdminWorkspaceController controller = ref.read(
    accessAdminWorkspaceControllerProvider.notifier,
  );
  final Result<AccessAdminWorkspaceState> stateResult = await ref.read(
    accessAdminWorkspaceControllerProvider.future,
  );
  final AccessAdminWorkspaceState? state = stateResult.when(
    success: (AccessAdminWorkspaceState value) => value,
    failure: (_) => null,
  );
  if (state == null) {
    await controller.refresh();
  }
  final Result<AccessAdminWorkspaceState> refreshed = await ref.read(
    accessAdminWorkspaceControllerProvider.future,
  );
  return refreshed.when(
    success: (AccessAdminWorkspaceState value) =>
        _showCreateRoleDialog(context, ref, value),
    failure: (AppFailure failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failureMessage(failure))),
      );
    },
  );
}

class _AccessAdminWorkspaceDialogShell extends ConsumerStatefulWidget {
  const _AccessAdminWorkspaceDialogShell({this.initialPanel});

  final AccessAdminPanel? initialPanel;

  @override
  ConsumerState<_AccessAdminWorkspaceDialogShell> createState() =>
      _AccessAdminWorkspaceDialogShellState();
}

class _AccessAdminWorkspaceDialogShellState
    extends ConsumerState<_AccessAdminWorkspaceDialogShell> {
  @override
  void initState() {
    super.initState();
    if (widget.initialPanel != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(accessAdminWorkspaceControllerProvider.notifier)
            .applyPanel(widget.initialPanel!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Result<AccessAdminWorkspaceState>> workspace = ref.watch(
      accessAdminWorkspaceControllerProvider,
    );

    return AppDialog(
      title: Text(context.l10n.accessAdminTitle),
      icon: const Icon(Icons.manage_accounts_outlined),
      pinActionsToBottom: true,
      maxWidth: 1180,
      content: SizedBox(
        height: 640,
        child: workspace.when(
          data: (Result<AccessAdminWorkspaceState> result) => result.when(
            success: (AccessAdminWorkspaceState state) =>
                AccessAdminWorkspacePage(
                  initialQuery: AccessAdminWorkspaceQuery(
                    panel: state.query.panel,
                    resource: state.query.resource,
                  ),
                ),
            failure: (AppFailure failure) => AppFailureStateView(
              failure: failure,
              onRetry: () {
                ref.invalidate(accessAdminWorkspaceControllerProvider);
              },
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => AppFailureStateView(
            failure: const AppFailure.unexpected(),
            onRetry: () {
              ref.invalidate(accessAdminWorkspaceControllerProvider);
            },
          ),
        ),
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: context.l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

Future<void> _showCreateUserDialog(
  BuildContext context,
  WidgetRef ref,
  AccessAdminWorkspaceState state,
) async {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String status = 'ACTIVE';

  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AppDialog(
      title: Text(context.l10n.accessAdminCreateUserAction),
      icon: const Icon(Icons.person_add_alt_1_outlined),
      content: Form(
        key: formKey,
        child: Column(
          children: <Widget>[
            AppTextField(
              controller: emailController,
              labelText: context.l10n.accessAdminEmailLabel,
              validator: (String? value) => (value ?? '').contains('@')
                  ? null
                  : context.l10n.validationRequired,
            ),
            SizedBox(height: Theme.of(context).spacing.md),
            AppTextField(
              controller: titleController,
              labelText: context.l10n.accessAdminPositionLabel,
              validator: (String? value) => (value ?? '').trim().isEmpty
                  ? context.l10n.validationRequired
                  : null,
            ),
            SizedBox(height: Theme.of(context).spacing.md),
            AppTextField(
              controller: passwordController,
              labelText: context.l10n.accessAdminPasswordLabel,
              obscureText: true,
              validator: (String? value) => (value ?? '').length >= 8
                  ? null
                  : context.l10n.accessAdminPasswordHint,
            ),
            SizedBox(height: Theme.of(context).spacing.md),
            AppSelectField<String>(
              labelText: context.l10n.accessAdminStatusLabel,
              value: status,
              options: state.data.lookups.userStatuses
                  .map(
                    (String value) =>
                        AppSelectOption<String>(value: value, label: value),
                  )
                  .toList(growable: false),
              onChanged: (String? value) {
                if (value != null) status = value;
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: context.l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        AppButton.primary(
          label: context.l10n.commonSaveActionLabel,
          onPressed: () async {
            if (formKey.currentState?.validate() != true) return;
            final String? tenantId =
                state.query.tenantId ??
                state.data.lookups.tenants.firstOrNull?.id;
            if (tenantId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.l10n.accessAdminTenantContextRequiredBody,
                  ),
                ),
              );
              return;
            }
            final AppFailure? failure = await ref
                .read(accessAdminWorkspaceControllerProvider.notifier)
                .createUser(
                  AccessAdminUserDraft(
                    tenantId: tenantId,
                    facilityId: state.query.facilityId,
                    email: emailController.text.trim(),
                    phone: phoneController.text.trim(),
                    positionTitle: titleController.text.trim(),
                    password: passwordController.text,
                    status: status,
                  ),
                );
            if (!dialogContext.mounted) return;
            if (failure == null) {
              Navigator.of(dialogContext).pop();
            } else {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(content: Text(context.l10n.failureMessage(failure))),
              );
            }
          },
        ),
      ],
    ),
  );

  emailController.dispose();
  phoneController.dispose();
  titleController.dispose();
  passwordController.dispose();
}

Future<void> _showCreateRoleDialog(
  BuildContext context,
  WidgetRef ref,
  AccessAdminWorkspaceState state,
) async {
  await openAccessAdminCreateRoleDialog(context, ref, state);
}

Future<void> openAccessAdminCreateRoleDialog(
  BuildContext context,
  WidgetRef ref,
  AccessAdminWorkspaceState state,
) async {
  final String? sessionTenantId =
      ref.read(sessionStateProvider).session?.user?.tenantId;
  final String? initialTenantId = state.query.tenantId ?? sessionTenantId;
  final List<AccessAdminLookupOption> tenantOptions =
      await _loadAccessAdminTenantOptions(ref, state);
  final List<AccessAdminLookupOption> permissionLookups =
      await _loadAccessAdminPermissionLookups(
        ref,
        state,
        tenantId: initialTenantId,
      );
  if (!context.mounted) {
    return;
  }

  await showRoleMutationDialog(
    context: context,
    mode: RoleMutationMode.create,
    permissionLookups: permissionLookups,
    tenantId: initialTenantId,
    facilityId: state.query.facilityId,
    tenantOptions: tenantOptions,
    requireTenantPicker: initialTenantId == null,
    onSubmit: (AccessAdminRoleDraft draft) => ref
        .read(accessAdminWorkspaceControllerProvider.notifier)
        .createRole(draft),
  );
}

Future<List<AccessAdminLookupOption>> _loadAccessAdminPermissionLookups(
  WidgetRef ref,
  AccessAdminWorkspaceState state, {
  String? tenantId,
}) async {
  if (state.data.lookups.permissions.isNotEmpty) {
    return state.data.lookups.permissions;
  }

  final Result<AccessAdminLookups> result = await ref
      .read(accessAdminRepositoryProvider)
      .getReferenceData(
        tenantId: tenantId ?? state.query.tenantId,
        facilityId: state.query.facilityId,
      );

  final List<AccessAdminLookupOption> permissions = result.when(
    success: (AccessAdminLookups lookups) => lookups.permissions,
    failure: (_) => const <AccessAdminLookupOption>[],
  );

  if (permissions.isNotEmpty) {
    await ref.read(accessAdminWorkspaceControllerProvider.notifier).refresh();
  }

  return permissions;
}

Future<List<AccessAdminLookupOption>> _loadAccessAdminTenantOptions(
  WidgetRef ref,
  AccessAdminWorkspaceState state,
) async {
  if (state.data.lookups.tenants.isNotEmpty) {
    return state.data.lookups.tenants;
  }

  final Result<AccessAdminLookups> result = await ref
      .read(accessAdminRepositoryProvider)
      .getReferenceData();
  return result.when(
    success: (AccessAdminLookups lookups) => lookups.tenants,
    failure: (_) => const <AccessAdminLookupOption>[],
  );
}
