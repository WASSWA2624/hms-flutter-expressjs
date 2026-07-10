import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/access_admin/data/repositories/access_admin_repository_impl.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/repositories/access_admin_repository.dart';
import 'package:hosspi_hms/features/access_admin/presentation/controllers/access_admin_workspace_controller.dart';
import 'package:hosspi_hms/features/access_admin/presentation/pages/access_admin_workspace_page.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/role_mutation_dialog.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/user_mutation_dialog.dart';
import 'package:hosspi_hms/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';

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

Future<bool?> showAccessAdminCreateUserDialog(
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
        openAccessAdminCreateUserDialog(context, ref, value),
    failure: (AppFailure failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failureMessage(failure))),
      );
      return null;
    },
  );
}

Future<bool?> showAccessAdminCreateRoleDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!context.mounted) {
    return null;
  }
  return openAccessAdminCreateRoleDialog(
    context,
    ref,
    _emptyCreateRoleWorkspaceState(),
  );
}

AccessAdminWorkspaceState _emptyCreateRoleWorkspaceState() {
  return const AccessAdminWorkspaceState(
    data: AccessAdminWorkspaceData(state: 'tenant_context_required'),
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

Future<void> showAccessAdminUserFormDialog(
  BuildContext context,
  WidgetRef ref,
  AccessAdminWorkspaceState state,
) {
  return openAccessAdminCreateUserDialog(context, ref, state);
}

Future<bool?> openAccessAdminCreateUserDialog(
  BuildContext context,
  WidgetRef ref,
  AccessAdminWorkspaceState state,
) async {
  if (!context.mounted) {
    return null;
  }

  return showUserMutationDialog(
    context: context,
    ref: ref,
    mode: UserMutationMode.create,
    state: state,
    onSubmit: (AccessAdminUserDraft draft, List<String> roleIds) =>
        _submitAccessAdminUserCreate(ref, draft, roleIds),
  );
}

Future<void> openAccessAdminEditUserDialog(
  BuildContext context,
  WidgetRef ref,
  AccessAdminWorkspaceState state, {
  required AccessAdminItem user,
  AccessAdminUserDetail? detail,
}) async {
  if (!context.mounted) {
    return;
  }

  await showUserMutationDialog(
    context: context,
    ref: ref,
    mode: UserMutationMode.edit,
    state: state,
    initialUser: user,
    initialDetail: detail,
    onSubmit: (AccessAdminUserDraft draft, List<String> roleIds) =>
        _submitAccessAdminUserUpdate(ref, user.id, draft, roleIds),
  );
}

Future<bool?> openAccessAdminCreateRoleDialog(
  BuildContext context,
  WidgetRef ref,
  AccessAdminWorkspaceState state,
) async {
  final AppAccessPolicy accessPolicy = ref.read(appAccessPolicyProvider);
  final bool isCrossTenantAdmin = accessPolicy.canCreateTenant();
  final bool allowTenantWideScope = accessPolicy.canCreateTenantWideRole();
  final String? workspaceTenantId = state.query.tenantId;
  final String? sessionTenantId = ref
      .read(sessionStateProvider)
      .session
      ?.user
      ?.tenantId;
  final String? sessionFacilityId = ref
      .read(sessionStateProvider)
      .session
      ?.user
      ?.facilityId;
  final String? initialTenantId = isCrossTenantAdmin
      ? workspaceTenantId
      : (workspaceTenantId ?? sessionTenantId);
  final String? initialFacilityId =
      state.query.facilityId ??
      (allowTenantWideScope ? null : sessionFacilityId);
  final bool requireTenantPicker = isCrossTenantAdmin
      ? workspaceTenantId == null
      : initialTenantId == null;
  if (!context.mounted) {
    return null;
  }

  return showRoleMutationDialog(
    context: context,
    mode: RoleMutationMode.create,
    loadTenantOptions: requireTenantPicker
        ? () => loadAccessAdminTenantOptions(
            ref,
            state,
            preferTenantFacilityApi: isCrossTenantAdmin,
          )
        : null,
    loadFacilityOptions: (String tenantId) =>
        loadAccessAdminFacilityOptions(ref, tenantId),
    loadPermissionsForTenant:
        ({required String tenantId, String? facilityId}) =>
            _loadAccessAdminPermissionLookups(
              ref,
              state,
              tenantId: tenantId,
              facilityId: facilityId,
              forceRefresh: true,
            ),
    tenantId: initialTenantId,
    facilityId: initialFacilityId,
    requireTenantPicker: requireTenantPicker,
    allowTenantWideScope: allowTenantWideScope,
    forceFacilityScope: !allowTenantWideScope,
    onSubmit: (AccessAdminRoleDraft draft) =>
        _submitAccessAdminRoleCreate(ref, draft),
  );
}

  Future<bool?> openAccessAdminEditRoleDialog(
  BuildContext context,
  WidgetRef ref,
  AccessAdminWorkspaceState state,
  AccessAdminItem role,
) async {
  if (!context.mounted) {
    return null;
  }

  final AppAccessPolicy accessPolicy = ref.read(appAccessPolicyProvider);
  final bool allowTenantWideScope = accessPolicy.canCreateTenantWideRole();
  final String? tenantId =
      state.query.tenantId ??
      ref.read(sessionStateProvider).session?.user?.tenantId;
  final String? facilityId = role.facilityId ?? state.query.facilityId;

  return showRoleMutationDialog(
    context: context,
    mode: RoleMutationMode.edit,
    initialName: role.title,
    initialDescription: role.subtitle,
    initialPermissionIds: role.permissions
        .map((AccessAdminPermissionRef permission) => permission.id)
        .toSet(),
    tenantId: tenantId,
    facilityId: facilityId,
    allowTenantWideScope: allowTenantWideScope,
    forceFacilityScope: !allowTenantWideScope,
    loadFacilityOptions: tenantId == null
        ? null
        : (String resolvedTenantId) =>
              loadAccessAdminFacilityOptions(ref, resolvedTenantId),
    loadPermissionsForTenant: tenantId == null
        ? null
        : ({required String tenantId, String? facilityId}) =>
              _loadAccessAdminPermissionLookups(
                ref,
                state,
                tenantId: tenantId,
                facilityId: facilityId,
                forceRefresh: true,
              ),
    onSubmit: (AccessAdminRoleDraft draft) =>
        _submitAccessAdminRoleUpdate(ref, role.id, draft),
  );
}

Future<AppFailure?> _submitAccessAdminUserCreate(
  WidgetRef ref,
  AccessAdminUserDraft draft,
  List<String> roleIds,
) async {
  final AccessAdminRepository repository = ref.read(
    accessAdminRepositoryProvider,
  );
  final Result<String> createResult = await repository.createUser(draft);
  final String? userId = createResult.when(
    success: (String value) => value,
    failure: (AppFailure failure) {
      return null;
    },
  );
  if (userId == null) {
    return createResult.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
  }

  return repository
      .syncUserRoles(
        userId: userId,
        tenantId: draft.tenantId,
        facilityId: draft.facilityId,
        roleIds: roleIds,
      )
      .then(
        (Result<void> result) => result.when(
          success: (_) => null,
          failure: (AppFailure failure) => failure,
        ),
      );
}

Future<AppFailure?> _submitAccessAdminUserUpdate(
  WidgetRef ref,
  String userId,
  AccessAdminUserDraft draft,
  List<String> roleIds,
) async {
  final AccessAdminRepository repository = ref.read(
    accessAdminRepositoryProvider,
  );
  final Result<void> updateResult = await repository.updateUser(userId, draft);
  final AppFailure? updateFailure = updateResult.when(
    success: (_) => null,
    failure: (AppFailure failure) => failure,
  );
  if (updateFailure != null) {
    return updateFailure;
  }

  return repository
      .syncUserRoles(
        userId: userId,
        tenantId: draft.tenantId,
        facilityId: draft.facilityId,
        roleIds: roleIds,
      )
      .then(
        (Result<void> result) => result.when(
          success: (_) => null,
          failure: (AppFailure failure) => failure,
        ),
      );
}

Future<AppFailure?> _submitAccessAdminRoleCreate(
  WidgetRef ref,
  AccessAdminRoleDraft draft,
) async {
  final AppFailure? failure = await ref
      .read(accessAdminWorkspaceControllerProvider.notifier)
      .createRole(draft);
  return failure;
}

Future<AppFailure?> _submitAccessAdminRoleUpdate(
  WidgetRef ref,
  String roleId,
  AccessAdminRoleDraft draft,
) async {
  final Result<void> result = await ref
      .read(accessAdminRepositoryProvider)
      .updateRole(roleId, draft);
  if (result case ResultFailure<void>(:final failure)) {
    return failure;
  }
  unawaited(
    ref.read(accessAdminWorkspaceControllerProvider.notifier).refresh(),
  );
  return null;
}

Future<Result<List<AccessAdminLookupOption>>> _loadAccessAdminPermissionLookups(
  WidgetRef ref,
  AccessAdminWorkspaceState state, {
  String? tenantId,
  String? facilityId,
  bool forceRefresh = false,
}) async {
  final String? resolvedTenantId = tenantId ?? state.query.tenantId;
  final String? resolvedFacilityId = facilityId ?? state.query.facilityId;
  if ((resolvedTenantId ?? '').isEmpty) {
    return const Result<List<AccessAdminLookupOption>>.success(
      <AccessAdminLookupOption>[],
    );
  }

  if (!forceRefresh &&
      resolvedTenantId == state.query.tenantId &&
      resolvedFacilityId == state.query.facilityId &&
      state.data.lookups.permissions.isNotEmpty) {
    return Result<List<AccessAdminLookupOption>>.success(
      state.data.lookups.permissions,
    );
  }

  final Result<AccessAdminLookups> result = await ref
      .read(accessAdminRepositoryProvider)
      .getReferenceData(
        tenantId: resolvedTenantId,
        facilityId: resolvedFacilityId,
      );

  return result.when(
    success: (AccessAdminLookups lookups) =>
        Result<List<AccessAdminLookupOption>>.success(lookups.permissions),
    failure: (AppFailure failure) =>
        Result<List<AccessAdminLookupOption>>.failure(failure),
  );
}

Future<List<AccessAdminLookupOption>> loadAccessAdminFacilityOptions(
  WidgetRef ref,
  String tenantId,
) async {
  final Result<AppPage<FacilityProfile>> result = await ref
      .read(tenantFacilityRepositoryProvider)
      .listFacilities(
        tenantId: tenantId,
        request: const AppPageRequest(pageSize: 100),
      );
  return result.when(
    success: (AppPage<FacilityProfile> page) => page.items
        .map(
          (FacilityProfile facility) =>
              AccessAdminLookupOption(id: facility.id, label: facility.name),
        )
        .toList(growable: false),
    failure: (_) => const <AccessAdminLookupOption>[],
  );
}

Future<List<AccessAdminLookupOption>> loadAccessAdminTenantOptions(
  WidgetRef ref,
  AccessAdminWorkspaceState state, {
  bool preferTenantFacilityApi = false,
}) async {
  if (!preferTenantFacilityApi && state.data.lookups.tenants.isNotEmpty) {
    return state.data.lookups.tenants;
  }

  if (preferTenantFacilityApi || state.data.lookups.tenants.isEmpty) {
    final Result<AppPage<TenantProfile>> tenantPageResult = await ref
        .read(tenantFacilityRepositoryProvider)
        .listTenants(request: const AppPageRequest(pageSize: 100));
    final List<AccessAdminLookupOption>? tenantFacilityOptions =
        tenantPageResult.when(
          success: (AppPage<TenantProfile> page) => page.items
              .map(
                (TenantProfile tenant) =>
                    AccessAdminLookupOption(id: tenant.id, label: tenant.name),
              )
              .toList(growable: false),
          failure: (_) => null,
        );
    if (tenantFacilityOptions != null && tenantFacilityOptions.isNotEmpty) {
      return tenantFacilityOptions;
    }
  }

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
