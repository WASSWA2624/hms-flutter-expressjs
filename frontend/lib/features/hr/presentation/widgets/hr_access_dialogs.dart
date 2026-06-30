import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

final RegExp _hrAccessTenantUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

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
  Timer? _searchDebounce;
  bool _loading = true;
  bool _tenantContextRequired = false;
  AppFailure? _failure;
  int _pageIndex = 0;
  int _totalItemCount = 0;
  List<HrAccessUser> _users = const <HrAccessUser>[];
  List<HrAccessRole> _roles = const <HrAccessRole>[];
  List<HrAccessPermission> _permissions = const <HrAccessPermission>[];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    unawaited(_reload(resetPage: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) {
        return;
      }
      unawaited(_reload(resetPage: true));
    });
  }

  Future<void> _reload({bool resetPage = false}) async {
    if (resetPage) {
      _pageIndex = 0;
    }
    setState(() {
      _loading = true;
      _failure = null;
      _tenantContextRequired = false;
    });

    final String? tenantId = resolveHrAccessTenantId(ref);
    if (tenantId == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _tenantContextRequired = true;
        _users = const <HrAccessUser>[];
        _roles = const <HrAccessRole>[];
        _permissions = const <HrAccessPermission>[];
      });
      return;
    }

    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final HrAccessQuery query = HrAccessQuery(
      panel: _panel,
      search: _searchController.text.trim(),
      tenantId: tenantId,
      pageRequest: AppPageRequest(pageIndex: _pageIndex, pageSize: 12),
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
            _totalItemCount = page.totalItemCount ?? page.items.length;
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
            _totalItemCount = page.totalItemCount ?? page.items.length;
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
          _totalItemCount = page.totalItemCount ?? page.items.length;
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

  Future<void> _loadMore() async {
    _pageIndex += 1;
    setState(() => _loading = true);
    final String? tenantId = resolveHrAccessTenantId(ref);
    if (tenantId == null) {
      return;
    }
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final HrAccessQuery query = HrAccessQuery(
      panel: _panel,
      search: _searchController.text.trim(),
      tenantId: tenantId,
      pageRequest: AppPageRequest(pageIndex: _pageIndex, pageSize: 12),
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
            _users = <HrAccessUser>[..._users, ...page.items];
            _totalItemCount = page.totalItemCount ?? _users.length;
          });
        },
        failure: (AppFailure failure) {
          setState(() {
            _loading = false;
            _pageIndex -= 1;
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
            _roles = <HrAccessRole>[..._roles, ...page.items];
            _totalItemCount = page.totalItemCount ?? _roles.length;
          });
        },
        failure: (AppFailure failure) {
          setState(() {
            _loading = false;
            _pageIndex -= 1;
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
          _permissions = <HrAccessPermission>[..._permissions, ...page.items];
          _totalItemCount = page.totalItemCount ?? _permissions.length;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _loading = false;
          _pageIndex -= 1;
          _failure = failure;
        });
      },
    );
  }

  bool get _canWrite => canWriteHrAccess(ref);

  bool get _hasMoreItems {
    return switch (_panel) {
      HrAccessPanel.users => _users.length < _totalItemCount,
      HrAccessPanel.roles => _roles.length < _totalItemCount,
      HrAccessPanel.permissions => _permissions.length < _totalItemCount,
    };
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
              unawaited(_reload(resetPage: true));
            },
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _searchController,
            labelText: l10n.hrAccessSearchLabel,
            onFieldSubmitted: (_) => unawaited(_reload(resetPage: true)),
          ),
          const SizedBox(height: 12),
          if (_loading && _pageIndex == 0)
            AppStateView(
              variant: AppStateViewVariant.loading,
              title: l10n.hrAccessWorkspaceTitle,
              body: l10n.hrAccessSearchLabel,
            )
          else if (_tenantContextRequired)
            AppStateView(
              title: l10n.hrAccessTenantContextRequiredTitle,
              body: l10n.hrAccessTenantContextRequiredBody,
            )
          else if (_failure != null)
            AppFailureStateView(
              failure: _failure!,
              onRetry: () => unawaited(_reload(resetPage: true)),
            )
          else
            _buildPanelContent(context, l10n),
          if (_hasMoreItems && !_loading && !_tenantContextRequired)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AppButton.secondary(
                label: l10n.hrAccessLoadMoreAction,
                onPressed: _loading ? null : () => unawaited(_loadMore()),
              ),
            ),
          if (_loading && _pageIndex > 0)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonRefreshActionLabel,
          leadingIcon: Icons.refresh,
          onPressed: _loading
              ? null
              : () => unawaited(_reload(resetPage: true)),
        ),
        if (_canWrite &&
            !_tenantContextRequired &&
            _panel == HrAccessPanel.users)
          AppButton.primary(
            label: l10n.hrCreateUserAction,
            leadingIcon: Icons.person_add_outlined,
            onPressed: () async {
              await showHrStaffOnboardingDialog(context, ref);
              if (context.mounted) {
                unawaited(_reload(resetPage: true));
              }
            },
          ),
        if (_canWrite &&
            !_tenantContextRequired &&
            _panel == HrAccessPanel.roles)
          AppButton.primary(
            label: l10n.hrAccessCreateRoleAction,
            leadingIcon: Icons.add_moderator_outlined,
            onPressed: () async {
              await showHrCreateRoleDialog(context, ref);
              if (context.mounted) {
                unawaited(_reload(resetPage: true));
              }
            },
          ),
        if (_canWrite &&
            !_tenantContextRequired &&
            _panel == HrAccessPanel.permissions)
          AppButton.primary(
            label: l10n.hrAccessCreatePermissionAction,
            leadingIcon: Icons.add_circle_outline,
            onPressed: () async {
              await showHrCreatePermissionDialog(context, ref);
              if (context.mounted) {
                unawaited(_reload(resetPage: true));
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
          _HrAccessUserRow(
            user: user,
            canWrite: _canWrite,
            onOpen: () async {
              await showHrAccessUserDetailDialog(
                context,
                ref,
                user,
                onChanged: () => unawaited(_reload(resetPage: true)),
              );
            },
            onEdit: () async {
              await showHrEditAccessUserDialog(context, ref, user);
              if (context.mounted) {
                unawaited(_reload(resetPage: true));
              }
            },
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
            title: Row(
              children: <Widget>[
                Expanded(child: Text(role.name ?? role.effectiveId)),
                if (role.isSystemCritical)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Chip(
                      label: Text(l10n.hrAccessSystemCriticalRoleBadge),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              <String>[
                if ((role.description ?? '').isNotEmpty) role.description!,
                l10n.hrAccessRoleSummary(role.permissionCount, role.userCount),
              ].join(' · '),
            ),
            trailing: Wrap(
              spacing: 8,
              children: <Widget>[
                if (_canWrite)
                  AppButton.secondary(
                    label: l10n.hrAccessEditRoleAction,
                    onPressed: role.isSystemCritical
                        ? null
                        : () async {
                            await showHrEditRoleDialog(context, ref, role);
                            if (context.mounted) {
                              unawaited(_reload(resetPage: true));
                            }
                          },
                  ),
                if (_canWrite)
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
                              unawaited(_reload(resetPage: true));
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
            trailing: _canWrite
                ? AppButton.secondary(
                    label: l10n.hrAccessEditPermissionAction,
                    onPressed: () async {
                      await showHrEditPermissionDialog(
                        context,
                        ref,
                        permission,
                      );
                      if (context.mounted) {
                        unawaited(_reload(resetPage: true));
                      }
                    },
                  )
                : null,
          ),
      ],
    );
  }
}

class _HrAccessUserRow extends StatelessWidget {
  const _HrAccessUserRow({
    required this.user,
    required this.canWrite,
    required this.onOpen,
    required this.onEdit,
  });

  final HrAccessUser user;
  final bool canWrite;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(user.displayLabel, style: theme.textTheme.titleSmall),
                    if ((user.email ?? '').isNotEmpty)
                      Text(user.email!, style: theme.textTheme.bodySmall),
                    if (user.roleNames.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: user.roleNames
                            .map((String role) => Chip(label: Text(role)))
                            .toList(growable: false),
                      ),
                    ],
                    if ((user.staffProfileId ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${l10n.hrAccessLinkedStaffLabel}: ${user.staffProfileName ?? user.staffProfileId}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              if ((user.status ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: AppStatusText(
                    label: user.status!,
                    tone: hrAccessUserStatusTone(user.status),
                  ),
                ),
              AppButton.secondary(
                label: l10n.hrAccessViewUserAction,
                onPressed: onOpen,
              ),
              if (canWrite) ...<Widget>[
                const SizedBox(width: 8),
                AppButton.secondary(
                  label: l10n.hrAccessEditUserAction,
                  onPressed: onEdit,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String? resolveHrAccessTenantId(WidgetRef ref) {
  final String? sessionTenant = ref
      .read(sessionStateProvider)
      .session
      ?.user
      ?.tenantId;
  if (isHrAccessTenantUuid(sessionTenant)) {
    return sessionTenant;
  }

  final HrWorkspaceState? state = readHrWorkspaceState(ref);
  final String? staffTenant =
      state?.selectedStaff?.profile.tenantId ??
      state?.staff.items.firstOrNull?.tenantId;
  if (isHrAccessTenantUuid(staffTenant)) {
    return staffTenant;
  }

  return null;
}

bool isHrAccessTenantUuid(String? value) {
  if (value == null || value.trim().isEmpty) {
    return false;
  }
  return _hrAccessTenantUuidPattern.hasMatch(value.trim());
}

bool canWriteHrAccess(WidgetRef ref) {
  return ref.read(appAccessPolicyProvider).grants(AppPermissions.hrWrite);
}

HrWorkspaceState? readHrWorkspaceState(WidgetRef ref) {
  return ref
      .read(hrWorkspaceControllerProvider)
      .asData
      ?.value
      .when(success: (HrWorkspaceState state) => state, failure: (_) => null);
}

AppWorkspaceStatusTone hrAccessUserStatusTone(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'ACTIVE' => AppWorkspaceStatusTone.success,
    'SUSPENDED' || 'INACTIVE' => AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

Future<void> showHrAccessUserDetailDialog(
  BuildContext context,
  WidgetRef ref,
  HrAccessUser user, {
  VoidCallback? onChanged,
}) async {
  final AppLocalizations l10n = context.l10n;
  final String? tenantId = resolveHrAccessTenantId(ref);
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final bool canWrite = canWriteHrAccess(ref);

  HrAccessUserDetail? detail;
  AppFailure? failure;
  final Result<HrAccessUserDetail> result = await controller
      .loadAccessUserDetail(user.effectiveId, tenantId: tenantId);
  result.when(
    success: (HrAccessUserDetail value) => detail = value,
    failure: (AppFailure value) => failure = value,
  );
  if (!context.mounted) {
    return;
  }

  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      if (failure != null) {
        return AppDialog(
          title: Text(l10n.hrAccessUserDetailTitle),
          icon: const Icon(Icons.person_outline),
          content: AppFailureStateView(failure: failure!),
          actions: <Widget>[
            AppButton.secondary(
              label: l10n.commonCloseActionLabel,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      }

      final HrAccessUserDetail resolved = detail!;
      return AppDialog(
        title: Text(l10n.hrAccessUserDetailTitle),
        icon: const Icon(Icons.person_outline),
        scrollable: true,
        maxWidth: 720,
        content: _HrAccessUserDetailContent(detail: resolved),
        actions: <Widget>[
          if ((resolved.staffProfileId ?? '').isNotEmpty)
            AppButton.secondary(
              label: l10n.hrAccessOpenStaffProfileAction,
              leadingIcon: Icons.badge_outlined,
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
                await ref
                    .read(hrWorkspaceControllerProvider.notifier)
                    .selectStaffByDisplayId(resolved.staffProfileId!);
              },
            ),
          if (canWrite)
            AppButton.secondary(
              label: l10n.hrAccessEditUserAction,
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await showHrEditAccessUserDialog(
                  context,
                  ref,
                  resolved.toSummary(),
                  initialDetail: resolved,
                );
                onChanged?.call();
              },
            ),
          AppButton.primary(
            label: l10n.commonCloseActionLabel,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      );
    },
  );
}

class _HrAccessUserDetailContent extends StatelessWidget {
  const _HrAccessUserDetailContent({required this.detail});

  final HrAccessUserDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _HrAccessDetailRow(
          label: l10n.hrEmailLabel,
          value: detail.email ?? '—',
        ),
        if ((detail.phone ?? '').isNotEmpty)
          _HrAccessDetailRow(
            label: l10n.profilePhoneLabel,
            value: detail.phone!,
          ),
        if ((detail.positionTitle ?? '').isNotEmpty)
          _HrAccessDetailRow(
            label: l10n.hrAccessPositionTitleLabel,
            value: detail.positionTitle!,
          ),
        if ((detail.status ?? '').isNotEmpty)
          _HrAccessDetailRow(
            label: l10n.hrStatusColumnLabel,
            value: detail.status!,
          ),
        if ((detail.staffProfileId ?? '').isNotEmpty)
          _HrAccessDetailRow(
            label: l10n.hrAccessLinkedStaffLabel,
            value: detail.staffProfileName ?? detail.staffProfileId!,
          ),
        if (detail.userRoles.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            l10n.hrAccessAssignedRolesLabel,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: detail.roleNames
                .map((String role) => Chip(label: Text(role)))
                .toList(growable: false),
          ),
        ],
        if (detail.directPermissions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            l10n.hrAccessDirectPermissionsLabel,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: detail.directPermissions
                .map(
                  (HrAccessPermission permission) => Chip(
                    label: Text(permission.name ?? permission.effectiveId),
                  ),
                )
                .toList(growable: false),
          ),
        ],
        if (detail.effectivePermissionLabels.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            l10n.hrAccessEffectivePermissionsLabel,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: detail.effectivePermissionLabels
                .take(24)
                .map((String permission) => Chip(label: Text(permission)))
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

class _HrAccessDetailRow extends StatelessWidget {
  const _HrAccessDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 160,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

Future<void> showHrEditAccessUserDialog(
  BuildContext context,
  WidgetRef ref,
  HrAccessUser user, {
  HrAccessUserDetail? initialDetail,
}) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final HrWorkspaceState? state = readHrWorkspaceState(ref);
  final String? tenantId = resolveHrAccessTenantId(ref);
  if (tenantId == null) {
    _showHrAccessSnackBar(
      context,
      null,
      message: l10n.hrAccessTenantContextRequiredBody,
    );
    return;
  }

  HrAccessUserDetail? detail = initialDetail;
  if (detail == null) {
    final Result<HrAccessUserDetail> detailResult = await controller
        .loadAccessUserDetail(user.effectiveId, tenantId: tenantId);
    detail = detailResult.when(
      success: (HrAccessUserDetail value) => value,
      failure: (_) => null,
    );
  }
  if (detail == null) {
    if (context.mounted) {
      _showHrAccessSnackBar(context, const AppFailure.notFound());
    }
    return;
  }

  final TextEditingController emailController = TextEditingController(
    text: detail.email ?? '',
  );
  final TextEditingController phoneController = TextEditingController(
    text: detail.phone ?? '',
  );
  final TextEditingController positionController = TextEditingController(
    text: detail.positionTitle ?? '',
  );
  String status = detail.status ?? 'ACTIVE';
  final Set<String> selectedRoleIds = detail.userRoles
      .map((HrUserRole role) => role.roleId)
      .whereType<String>()
      .toSet();
  final Set<String> selectedPermissionIds = detail.directPermissions
      .map((HrAccessPermission permission) => permission.effectiveId)
      .toSet();
  final TextEditingController permissionSearchController =
      TextEditingController();

  final Result<AppPage<HrAccessPermission>> permissionsResult = await controller
      .loadAccessPermissions(
        HrAccessQuery(panel: HrAccessPanel.permissions, tenantId: tenantId),
      );
  final List<HrAccessPermission> permissionOptions = permissionsResult.when(
    success: (AppPage<HrAccessPermission> page) => page.items,
    failure: (_) => const <HrAccessPermission>[],
  );

  if (!context.mounted) {
    emailController.dispose();
    phoneController.dispose();
    positionController.dispose();
    permissionSearchController.dispose();
    return;
  }

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAccessManageRolesPermissionsAction),
    icon: const Icon(Icons.manage_accounts_outlined),
    submitLabel: l10n.commonSaveActionLabel,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final String permissionQuery = permissionSearchController.text
              .trim()
              .toLowerCase();
          final Iterable<HrAccessPermission> filteredPermissions =
              permissionOptions.where((HrAccessPermission permission) {
                final String haystack =
                    '${permission.name ?? ''} ${permission.description ?? ''}'
                        .toLowerCase();
                return permissionQuery.isEmpty ||
                    haystack.contains(permissionQuery);
              });

          return AppFormSection(
            children: <Widget>[
              AppTextField(
                controller: emailController,
                labelText: l10n.hrEmailLabel,
                keyboardType: TextInputType.emailAddress,
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
              AppSelectField<String>(
                value: status,
                labelText: l10n.hrStatusColumnLabel,
                options: const <AppSelectOption<String>>[
                  AppSelectOption<String>(value: 'ACTIVE', label: 'Active'),
                  AppSelectOption<String>(value: 'INACTIVE', label: 'Inactive'),
                  AppSelectOption<String>(
                    value: 'SUSPENDED',
                    label: 'Suspended',
                  ),
                ],
                onChanged: (String? value) => status = value ?? status,
              ),
              Text(
                l10n.hrAccessAssignedRolesLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _HrAccessMultiSelectHeader(
                selectAllLabel: l10n.hrAccessSelectAllRolesAction,
                clearLabel: l10n.hrAccessClearRolesAction,
                onSelectAll: () {
                  setState(() {
                    selectedRoleIds
                      ..clear()
                      ..addAll(
                        (state?.referenceData.roles ?? const <HrOption>[]).map(
                          (HrOption role) => role.value,
                        ),
                      );
                  });
                },
                onClear: () => setState(selectedRoleIds.clear),
              ),
              for (final HrOption role
                  in state?.referenceData.roles ?? const [])
                AppCheckboxField(
                  title: role.label,
                  value: selectedRoleIds.contains(role.value),
                  onChanged: (bool checked) {
                    setState(() {
                      if (checked) {
                        selectedRoleIds.add(role.value);
                      } else {
                        selectedRoleIds.remove(role.value);
                      }
                    });
                  },
                ),
              Text(
                l10n.hrAccessDirectPermissionsLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: permissionSearchController,
                labelText: l10n.hrAccessSearchLabel,
                onChanged: (_) => setState(() {}),
              ),
              _HrAccessMultiSelectHeader(
                selectAllLabel: l10n.hrAccessSelectAllPermissionsAction,
                clearLabel: l10n.hrAccessClearPermissionsAction,
                onSelectAll: () {
                  setState(() {
                    selectedPermissionIds
                      ..clear()
                      ..addAll(
                        permissionOptions.map(
                          (HrAccessPermission permission) =>
                              permission.effectiveId,
                        ),
                      );
                  });
                },
                onClear: () => setState(selectedPermissionIds.clear),
              ),
              for (final HrAccessPermission permission in filteredPermissions)
                AppCheckboxField(
                  title: permission.name ?? permission.effectiveId,
                  value: selectedPermissionIds.contains(permission.effectiveId),
                  onChanged: (bool checked) {
                    setState(() {
                      if (checked) {
                        selectedPermissionIds.add(permission.effectiveId);
                      } else {
                        selectedPermissionIds.remove(permission.effectiveId);
                      }
                    });
                  },
                ),
            ],
          );
        },
      );
    },
    onSubmit: () async {
      final AppFailure? profileFailure = await controller
          .updateAccessUser(user.effectiveId, <String, Object?>{
            'email': emailController.text.trim(),
            'phone': phoneController.text.trim(),
            'position_title': positionController.text.trim(),
            'status': status,
            'permission_ids': selectedPermissionIds.toList(growable: false),
          }, refreshReferences: false);
      if (profileFailure != null) {
        return profileFailure;
      }
      return controller.syncUserRoles(
        userId: user.effectiveId,
        tenantId: tenantId,
        roleIds: selectedRoleIds.toList(growable: false),
      );
    },
  );
  emailController.dispose();
  phoneController.dispose();
  positionController.dispose();
  permissionSearchController.dispose();
  if (saved == true && context.mounted) {
    _showHrAccessSnackBar(context, null);
  }
}

class _HrAccessMultiSelectHeader extends StatelessWidget {
  const _HrAccessMultiSelectHeader({
    required this.selectAllLabel,
    required this.clearLabel,
    required this.onSelectAll,
    required this.onClear,
  });

  final String selectAllLabel;
  final String clearLabel;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        children: <Widget>[
          AppButton.secondary(label: selectAllLabel, onPressed: onSelectAll),
          AppButton.secondary(label: clearLabel, onPressed: onClear),
        ],
      ),
    );
  }
}

Future<void> showHrCreateRoleDialog(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final String? tenantId = resolveHrAccessTenantId(ref);
  if (tenantId == null) {
    _showHrAccessSnackBar(
      context,
      null,
      message: l10n.hrAccessTenantContextRequiredBody,
    );
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
  final String? tenantId = resolveHrAccessTenantId(ref);

  final Result<AppPage<HrAccessPermission>> permissionsResult = await controller
      .loadAccessPermissions(
        HrAccessQuery(panel: HrAccessPanel.permissions, tenantId: tenantId),
      );
  final List<HrAccessPermission> permissionOptions = permissionsResult.when(
    success: (AppPage<HrAccessPermission> page) => page.items,
    failure: (_) => const <HrAccessPermission>[],
  );
  final Result<AppPage<HrOption>> assignedResult = await controller
      .listRolePermissionOptions(role.effectiveId);
  final Set<String> selectedPermissionIds = assignedResult.when(
    success: (AppPage<HrOption> page) =>
        page.items.map((HrOption option) => option.value).toSet(),
    failure: (_) => <String>{},
  );

  if (!context.mounted) {
    return;
  }

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAccessAssignPermissionsAction),
    icon: const Icon(Icons.security_outlined),
    submitLabel: l10n.commonSaveActionLabel,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AppFormSection(
            children: <Widget>[
              Text(
                role.name ?? role.effectiveId,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _HrAccessMultiSelectHeader(
                selectAllLabel: l10n.hrAccessSelectAllPermissionsAction,
                clearLabel: l10n.hrAccessClearPermissionsAction,
                onSelectAll: () {
                  setState(() {
                    selectedPermissionIds
                      ..clear()
                      ..addAll(
                        permissionOptions.map(
                          (HrAccessPermission permission) =>
                              permission.effectiveId,
                        ),
                      );
                  });
                },
                onClear: () => setState(selectedPermissionIds.clear),
              ),
              if (permissionOptions.isEmpty)
                Text(l10n.hrAccessEmptyPermissionsLabel)
              else
                for (final HrAccessPermission permission in permissionOptions)
                  AppCheckboxField(
                    title: permission.name ?? permission.effectiveId,
                    value: selectedPermissionIds.contains(
                      permission.effectiveId,
                    ),
                    onChanged: (bool checked) {
                      setState(() {
                        if (checked) {
                          selectedPermissionIds.add(permission.effectiveId);
                        } else {
                          selectedPermissionIds.remove(permission.effectiveId);
                        }
                      });
                    },
                  ),
            ],
          );
        },
      );
    },
    onSubmit: () => controller.syncRolePermissions(
      roleId: role.effectiveId,
      permissionIds: selectedPermissionIds.toList(growable: false),
    ),
  );
  if (saved == true && context.mounted) {
    _showHrAccessSnackBar(
      context,
      null,
      message: l10n.hrAccessRoleSyncSuccessMessage,
    );
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
  final String? tenantId = resolveHrAccessTenantId(ref);
  if (tenantId == null) {
    _showHrAccessSnackBar(
      context,
      null,
      message: l10n.hrAccessTenantContextRequiredBody,
    );
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

void _showHrAccessSnackBar(
  BuildContext context,
  AppFailure? failure, {
  String? message,
}) {
  if (!context.mounted) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message ??
            (failure == null
                ? l10n.hrSavedMessage
                : l10n.failureMessage(failure)),
      ),
    ),
  );
}
