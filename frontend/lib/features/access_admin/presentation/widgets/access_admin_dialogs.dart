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
import 'package:hosspi_hms/features/access_admin/domain/entities/role_similarity.dart';
import 'package:hosspi_hms/features/access_admin/domain/repositories/access_admin_repository.dart';
import 'package:hosspi_hms/features/access_admin/presentation/controllers/access_admin_workspace_controller.dart';
import 'package:hosspi_hms/features/access_admin/presentation/pages/access_admin_workspace_page.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/role_mutation_dialog.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/role_similarity_dialog.dart';
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

Future<AccessAdminItem?> showAccessAdminCreateRoleDialog(
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

Future<bool?> openAccessAdminEditUserDialog(
  BuildContext context,
  WidgetRef ref,
  AccessAdminWorkspaceState state, {
  required AccessAdminItem user,
  AccessAdminUserDetail? detail,
}) async {
  if (!context.mounted) {
    return null;
  }

  return showUserMutationDialog(
    context: context,
    ref: ref,
    mode: UserMutationMode.edit,
    state: state,
    initialUser: user,
    initialDetail: detail,
    onSubmit: (AccessAdminUserDraft draft, List<String> roleIds) =>
        _submitAccessAdminUserUpdate(ref, user.mutationId, draft, roleIds),
  );
}

Future<AccessAdminItem?> openAccessAdminCreateRoleDialog(
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

  final bool needsFacilityScope = !allowTenantWideScope;
  final bool provideAllFacilitiesLoader = isCrossTenantAdmin;
  final bool provideTenantLoader =
      allowTenantWideScope ||
      requireTenantPicker ||
      !provideAllFacilitiesLoader;
  AccessAdminLookups? prefetched;
  if ((initialTenantId ?? '').isNotEmpty) {
    prefetched = await _prefetchRoleDialogLookups(
      ref,
      tenantId: initialTenantId!,
      facilityId: needsFacilityScope ? initialFacilityId : null,
      includeFacilities: needsFacilityScope || initialFacilityId != null,
    );
  }

  if (!context.mounted) {
    return null;
  }

  AccessAdminItem? createdRole;
  AccessAdminItem? existingRoleToOpen;
  var similarityAccepted = false;

  final bool? saved = await showRoleMutationDialog(
    context: context,
    mode: RoleMutationMode.create,
    includePermissions: false,
    permissionLookups:
        prefetched?.permissions ?? state.data.lookups.permissions,
    initialFacilityOptions:
        prefetched?.facilities ?? state.data.lookups.facilities,
    loadTenantOptions: provideTenantLoader
        ? () => loadAccessAdminTenantOptions(
            ref,
            state,
            preferTenantFacilityApi: isCrossTenantAdmin,
          )
        : null,
    loadFacilityOptions: (String tenantId) =>
        loadAccessAdminFacilityOptions(ref, tenantId),
    loadAllFacilityOptions: provideAllFacilitiesLoader
        ? () => loadAccessAdminAllFacilityOptions(ref, state)
        : null,
    tenantId: initialTenantId,
    facilityId: initialFacilityId,
    requireTenantPicker: requireTenantPicker,
    allowTenantWideScope: allowTenantWideScope,
    forceFacilityScope: !allowTenantWideScope,
    allowPlatformScope: isCrossTenantAdmin,
    allowTenantScope: allowTenantWideScope,
    onSubmit: (List<AccessAdminRoleDraft> drafts) async {
      for (final AccessAdminRoleDraft draft in drafts) {
        var pending = draft.copyWith(
          confirmSimilar: similarityAccepted || draft.confirmSimilar,
        );

        if (!pending.confirmSimilar) {
          if (!context.mounted) {
            return const AppFailure.cancelled();
          }
          final AppFailure? reviewFailure = await _reviewRoleSimilarity(
            context,
            ref,
            pending: pending,
            onAccepted: () => similarityAccepted = true,
            onUseExisting: (AccessAdminItem role) {
              existingRoleToOpen = role;
            },
          );
          if (reviewFailure != null) {
            return reviewFailure;
          }
          if (existingRoleToOpen != null) {
            return null;
          }
          pending = pending.copyWith(confirmSimilar: similarityAccepted);
        }

        final Result<AccessAdminItem> result = await ref
            .read(accessAdminWorkspaceControllerProvider.notifier)
            .createRole(pending);
        AppFailure? failure = result.when(
          success: (AccessAdminItem created) {
            createdRole ??= created;
            return null;
          },
          failure: (AppFailure value) => value,
        );

        // Backend uniqueness is authoritative; never surface it as an inline
        // create-dialog conflict banner — reopen the dedicated review dialog.
        if (failure != null &&
            failure.category == AppFailureCategory.conflict) {
          if (!context.mounted) {
            return const AppFailure.cancelled();
          }
          similarityAccepted = false;
          final AppFailure? reviewFailure = await _reviewRoleSimilarity(
            context,
            ref,
            pending: pending.copyWith(confirmSimilar: false),
            forceReviewMatches: true,
            onAccepted: () => similarityAccepted = true,
            onUseExisting: (AccessAdminItem role) {
              existingRoleToOpen = role;
            },
          );
          if (reviewFailure != null) {
            return reviewFailure;
          }
          if (existingRoleToOpen != null) {
            return null;
          }
          if (!similarityAccepted) {
            return const AppFailure.cancelled();
          }

          final Result<AccessAdminItem> retry = await ref
              .read(accessAdminWorkspaceControllerProvider.notifier)
              .createRole(pending.copyWith(confirmSimilar: true));
          final AppFailure? retryFailure = retry.when(
            success: (AccessAdminItem created) {
              createdRole ??= created;
              return null;
            },
            failure: (AppFailure value) => value,
          );
          if (retryFailure != null &&
              retryFailure.category == AppFailureCategory.conflict) {
            return const AppFailure.cancelled();
          }
          if (retryFailure != null) {
            return retryFailure;
          }
          failure = null;
        }

        if (failure != null) {
          return failure;
        }
        if (existingRoleToOpen != null) {
          return null;
        }
      }
      return null;
    },
  );

  if (existingRoleToOpen != null) {
    return existingRoleToOpen;
  }
  if (saved == true) {
    return createdRole;
  }
  return null;
}

Future<AppFailure?> _reviewRoleSimilarity(
  BuildContext context,
  WidgetRef ref, {
  required AccessAdminRoleDraft pending,
  required VoidCallback onAccepted,
  required ValueChanged<AccessAdminItem> onUseExisting,
  bool forceReviewMatches = false,
}) async {
  final List<AccessAdminItem> peers = await _loadRoleSimilarityPeers(
    ref,
    tenantId: pending.tenantId,
  );
  if (!context.mounted) {
    return const AppFailure.cancelled();
  }

  final RoleDuplicateCheckResult check = checkRoleDuplicates(
    name: pending.name,
    displayName: pending.displayName ?? '',
    description: pending.description,
    tenantId: pending.tenantId,
    facilityId: pending.facilityId,
    existing: peers,
  );

  List<RoleSimilarityMatch> reviewMatches;
  if (forceReviewMatches) {
    reviewMatches = check.similarMatches;
  } else if (check.hasExactConflict) {
    reviewMatches = check.similarMatches
        .where(
          (RoleSimilarityMatch match) =>
              match.exactNameConflict || match.exactDisplayNameConflict,
        )
        .toList(growable: false);
    if (reviewMatches.isEmpty) {
      reviewMatches = check.similarMatches;
    }
  } else {
    reviewMatches = check.overridableMatches;
  }

  // Create always opens review (including zero matches). Force-review is used
  // when the backend returns a uniqueness conflict after the client scan.
  final RoleSimilarityDialogResult review = await showRoleSimilarityDialog(
    context,
    proposed: RoleSimilarityProposedValues(
      name: pending.name,
      displayName: pending.displayName ?? '',
      description: pending.description,
    ),
    matches: reviewMatches,
    allowProceed: !check.hasExactConflict,
  );
  if (!context.mounted) {
    return const AppFailure.cancelled();
  }

  switch (review.action) {
    case RoleSimilarityAction.cancel:
      return const AppFailure.cancelled();
    case RoleSimilarityAction.useExisting:
      final AccessAdminItem? existing = review.selectedRole?.role;
      if (existing != null) {
        onUseExisting(existing);
      }
      return null;
    case RoleSimilarityAction.proceed:
      onAccepted();
      return null;
  }
}

Future<List<AccessAdminItem>> _loadRoleSimilarityPeers(
  WidgetRef ref, {
  String? tenantId,
}) async {
  // Load tenant-wide (all facilities) or all tenants for platform proposals so
  // org/facility peers are visible. Same-scope hard conflicts remain enforced
  // in checkRoleDuplicates.
  final bool allTenants = tenantId == null || tenantId.trim().isEmpty;
  final Result<AccessAdminWorkspaceData> result = await ref
      .read(accessAdminRepositoryProvider)
      .getWorkspace(
        AccessAdminWorkspaceQuery(
          panel: AccessAdminPanel.roles,
          resource: AccessAdminResource.roles,
          tenantId: allTenants ? null : tenantId,
          facilityId: null,
          allTenants: allTenants,
          allFacilities: true,
          lean: true,
          // Match backend ROLE_SIMILARITY_LOOKUP_LIMIT so client review is not
          // starved by a short first page.
          pageRequest: const AppPageRequest(pageSize: 500),
        ),
      );
  return result.when(
    success: (AccessAdminWorkspaceData data) => data.items,
    failure: (_) => const <AccessAdminItem>[],
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

  final AccessAdminRepository repository = ref.read(
    accessAdminRepositoryProvider,
  );

  final Future<Result<List<AccessAdminRolePermissionAssignment>>>
  assignmentsFuture = repository.listRolePermissions(role.id);
  final Future<AccessAdminLookups?> lookupsFuture = (tenantId ?? '').isEmpty
      ? Future<AccessAdminLookups?>.value()
      : _prefetchRoleDialogLookups(
          ref,
          tenantId: tenantId!,
          facilityId: facilityId,
          includeFacilities: true,
        );

  final Result<List<AccessAdminRolePermissionAssignment>> assignmentsResult =
      await assignmentsFuture;
  final AccessAdminLookups? prefetched = await lookupsFuture;

  if (!context.mounted) {
    return null;
  }

  final List<AccessAdminLookupOption> permissionLookups =
      prefetched?.permissions ??
      (state.data.lookups.permissions.isNotEmpty
          ? state.data.lookups.permissions
          : const <AccessAdminLookupOption>[]);

  final List<AccessAdminRolePermissionAssignment> assignments =
      assignmentsResult.when(
        success: (List<AccessAdminRolePermissionAssignment> value) => value,
        failure: (_) => const <AccessAdminRolePermissionAssignment>[],
      );

  final Set<String> initialPermissionIds = _resolveAttachedPermissionIds(
    assignments: assignments,
    embeddedPermissions: role.permissions,
    permissionLookups: permissionLookups,
  );

  return showRoleMutationDialog(
    context: context,
    mode: RoleMutationMode.edit,
    permissionLookups: permissionLookups,
    initialFacilityOptions:
        prefetched?.facilities ?? state.data.lookups.facilities,
    initialName: role.name ?? role.title,
    initialDisplayName: role.displayName,
    initialDescription: role.subtitle,
    initialPermissionIds: initialPermissionIds,
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
              ),
    onSubmit: (List<AccessAdminRoleDraft> drafts) =>
        _submitAccessAdminRoleUpdate(ref, role.id, drafts.first),
  );
}

/// Maps role permission assignments onto catalog lookup option ids.
Set<String> _resolveAttachedPermissionIds({
  required List<AccessAdminRolePermissionAssignment> assignments,
  required List<AccessAdminPermissionRef> embeddedPermissions,
  required List<AccessAdminLookupOption> permissionLookups,
}) {
  final Map<String, String> idByLookupId = <String, String>{
    for (final AccessAdminLookupOption option in permissionLookups)
      option.id: option.id,
  };
  final Map<String, String> idByName = <String, String>{
    for (final AccessAdminLookupOption option in permissionLookups)
      option.label: option.id,
  };
  final Set<String> resolved = <String>{};

  String? resolveOne({String? id, String? name}) {
    if (id != null && idByLookupId.containsKey(id)) {
      return idByLookupId[id];
    }
    if (name != null && idByName.containsKey(name)) {
      return idByName[name];
    }
    if (id != null && idByName.containsKey(id)) {
      return idByName[id];
    }
    return null;
  }

  void addCandidate({String? id, String? name}) {
    final String? matched = resolveOne(id: id, name: name);
    if (matched != null) {
      resolved.add(matched);
      return;
    }
    // Prefer permission code/name so a later catalog load can remap by label.
    if (name != null && name.trim().isNotEmpty) {
      resolved.add(name.trim());
    }
    if (id != null && id.trim().isNotEmpty) {
      resolved.add(id.trim());
    }
  }

  for (final AccessAdminRolePermissionAssignment assignment in assignments) {
    addCandidate(id: assignment.permissionId, name: assignment.permissionName);
  }

  if (resolved.isEmpty) {
    for (final AccessAdminPermissionRef permission in embeddedPermissions) {
      addCandidate(id: permission.id, name: permission.name);
    }
  }

  return resolved;
}

Future<AppFailure?> _submitAccessAdminUserCreate(
  WidgetRef ref,
  AccessAdminUserDraft draft,
  List<String> roleIds,
) async {
  return ref
      .read(accessAdminWorkspaceControllerProvider.notifier)
      .createUserWithRoles(draft, roleIds);
}

Future<AppFailure?> _submitAccessAdminUserUpdate(
  WidgetRef ref,
  String userId,
  AccessAdminUserDraft draft,
  List<String> roleIds,
) async {
  return ref
      .read(accessAdminWorkspaceControllerProvider.notifier)
      .updateUserWithRoles(userId, draft, roleIds);
}

Future<AppFailure?> _submitAccessAdminRoleUpdate(
  WidgetRef ref,
  String roleId,
  AccessAdminRoleDraft draft,
) async {
  return ref
      .read(accessAdminWorkspaceControllerProvider.notifier)
      .updateRole(roleId, draft);
}

Future<AccessAdminLookups?> _prefetchRoleDialogLookups(
  WidgetRef ref, {
  required String tenantId,
  String? facilityId,
  bool includeFacilities = false,
}) async {
  final List<String> include = <String>[
    'permissions',
    if (includeFacilities) 'facilities',
  ];
  final Result<AccessAdminLookups> result = await ref
      .read(accessAdminRepositoryProvider)
      .getReferenceData(
        tenantId: tenantId,
        facilityId: facilityId,
        include: include,
      );
  return result.when(
    success: (AccessAdminLookups lookups) => lookups,
    failure: (_) => null,
  );
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
        include: const <String>['permissions'],
        forceRefresh: forceRefresh,
      );

  return result.when(
    success: (AccessAdminLookups lookups) =>
        Result<List<AccessAdminLookupOption>>.success(lookups.permissions),
    failure: (AppFailure failure) =>
        Result<List<AccessAdminLookupOption>>.failure(failure),
  );
}

Future<List<AccessAdminLookupOption>> loadAccessAdminAllFacilityOptions(
  WidgetRef ref,
  AccessAdminWorkspaceState state,
) async {
  final List<AccessAdminLookupOption> tenants =
      await loadAccessAdminTenantOptions(
        ref,
        state,
        preferTenantFacilityApi: true,
      );
  if (tenants.isEmpty) {
    return const <AccessAdminLookupOption>[];
  }

  final List<AccessAdminLookupOption> facilities = <AccessAdminLookupOption>[];
  for (final AccessAdminLookupOption tenant in tenants) {
    final List<AccessAdminLookupOption> tenantFacilities =
        await loadAccessAdminFacilityOptions(ref, tenant.id);
    for (final AccessAdminLookupOption facility in tenantFacilities) {
      facilities.add(
        AccessAdminLookupOption(
          id: facility.id,
          label: tenants.length > 1
              ? '${facility.label} (${tenant.label})'
              : facility.label,
          meta: tenant.id,
        ),
      );
    }
  }
  return facilities;
}

Future<List<AccessAdminLookupOption>> loadAccessAdminFacilityOptions(
  WidgetRef ref,
  String tenantId,
) async {
  final Result<AccessAdminLookups> cached = await ref
      .read(accessAdminRepositoryProvider)
      .getReferenceData(
        tenantId: tenantId,
        include: const <String>['facilities'],
      );
  final List<AccessAdminLookupOption>? fromReference = cached.when(
    success: (AccessAdminLookups lookups) =>
        lookups.facilities.isEmpty ? null : lookups.facilities,
    failure: (_) => null,
  );
  if (fromReference != null) {
    return fromReference;
  }

  final Result<AppPage<FacilityProfile>> result = await ref
      .read(tenantFacilityRepositoryProvider)
      .listFacilities(
        tenantId: tenantId,
        request: const AppPageRequest(pageSize: 100),
      );
  return result.when(
    success: (AppPage<FacilityProfile> page) => page.items
        .map(
          (FacilityProfile facility) => AccessAdminLookupOption(
            id: facility.mutationId,
            label: facility.name,
          ),
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
                (TenantProfile tenant) => AccessAdminLookupOption(
                  id: tenant.mutationId,
                  label: tenant.name,
                ),
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
