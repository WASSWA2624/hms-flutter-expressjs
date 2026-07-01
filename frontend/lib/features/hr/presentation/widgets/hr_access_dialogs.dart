import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/app_permission_catalog_localizations.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
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

Future<void> showHrAccessWorkspaceDialog(BuildContext context) async {
  await showAppDialog<void>(
    context: context,
    builder: (_) => const _HrAccessWorkspaceDialog(),
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
  static const int _pageSize = 12;

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
  late final AppListTableColumnVisibilityController<HrAccessUser>
  _userColumnVisibility;
  late final AppListTableColumnVisibilityController<HrAccessRole>
  _roleColumnVisibility;
  late final AppListTableColumnVisibilityController<HrAccessPermission>
  _permissionColumnVisibility;

  @override
  void initState() {
    super.initState();
    _userColumnVisibility =
        AppListTableColumnVisibilityController<HrAccessUser>();
    _roleColumnVisibility =
        AppListTableColumnVisibilityController<HrAccessRole>();
    _permissionColumnVisibility =
        AppListTableColumnVisibilityController<HrAccessPermission>();
    _searchController.addListener(_onSearchChanged);
    unawaited(_reload(resetPage: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _userColumnVisibility.dispose();
    _roleColumnVisibility.dispose();
    _permissionColumnVisibility.dispose();
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
      pageRequest: _pageRequest,
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

  void _onPageChanged(AppPageRequest request) {
    _pageIndex = request.pageIndex;
    unawaited(_reload());
  }

  AppPageRequest get _pageRequest =>
      AppPageRequest(pageIndex: _pageIndex, pageSize: _pageSize);

  AppListTableSearch<T> _accessTableSearch<T>(AppLocalizations l10n) {
    return AppListTableSearch<T>(
      controller: _searchController,
      semanticLabel: l10n.hrAccessSearchLabel,
      hintText: l10n.hrAccessSearchHint,
      clearLabel: l10n.hrClearFiltersAction,
      matcher: (_, _) => true,
      onSubmitted: (_) => unawaited(_reload(resetPage: true)),
      onClear: () {
        _searchController.clear();
        unawaited(_reload(resetPage: true));
      },
    );
  }

  String _accessPageLabel<T>(AppPage<T> page, AppLocalizations l10n) {
    return l10n.hrPageLabel(
      page.firstItemNumber,
      page.lastItemNumber,
      page.totalItemCount ?? page.lastItemNumber,
    );
  }

  bool get _canWrite => canWriteHrAccess(ref);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.hrAccessWorkspaceTitle),
      icon: const Icon(Icons.manage_accounts_outlined),
      pinActionsToBottom: true,
      initialMaximized: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.hrAccessWorkspaceDescription,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          AppWorkspaceBoardToggle<HrAccessPanel>(
            value: _panel,
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
            onChanged: (HrAccessPanel next) {
              if (next == _panel) {
                return;
              }
              setState(() => _panel = next);
              unawaited(_reload(resetPage: true));
            },
          ),
          const SizedBox(height: 12),
          if (_tenantContextRequired)
            Expanded(
              child: AppStateView(
                title: l10n.hrAccessTenantContextRequiredTitle,
                body: l10n.hrAccessTenantContextRequiredBody,
              ),
            )
          else if (_failure != null)
            Expanded(
              child: AppFailureStateView(
                failure: _failure!,
                onRetry: () => unawaited(_reload(resetPage: true)),
              ),
            )
          else
            Expanded(child: _buildPanelTable(context, l10n)),
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

  Widget _buildPanelTable(BuildContext context, AppLocalizations l10n) {
    return switch (_panel) {
      HrAccessPanel.users => _buildUsersTable(context, l10n),
      HrAccessPanel.roles => _buildRolesTable(context, l10n),
      HrAccessPanel.permissions => _buildPermissionsTable(context, l10n),
    };
  }

  Widget _buildUsersTable(BuildContext context, AppLocalizations l10n) {
    final bool showPositionColumn = _users.any(
      (HrAccessUser user) => (user.positionTitle ?? '').trim().isNotEmpty,
    );

    return AppListTable<HrAccessUser>(
      page: AppPage<HrAccessUser>(
        items: _users,
        request: _pageRequest,
        totalItemCount: _totalItemCount,
      ),
      isLoading: _loading,
      search: _accessTableSearch<HrAccessUser>(l10n),
      columnVisibilityController: _userColumnVisibility,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      itemKeyBuilder: (HrAccessUser item) => ValueKey<String>(item.effectiveId),
      onRowSelected: (HrAccessUser user) async {
        await showHrAccessUserDetailDialog(
          context,
          ref,
          user,
          onChanged: () => unawaited(_reload(resetPage: true)),
        );
      },
      previousPageLabel: l10n.hrPreviousPageLabel,
      nextPageLabel: l10n.hrNextPageLabel,
      pageLabelBuilder: (AppPage<HrAccessUser> page) =>
          _accessPageLabel(page, l10n),
      onPageChanged: _onPageChanged,
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.hrAccessPanelUsers,
        body: l10n.hrAccessEmptyUsersLabel,
      ),
      columns: <AppListTableColumn<HrAccessUser>>[
        AppListTableColumn<HrAccessUser>(
          label: l10n.hrStaffColumnLabel,
          sortComparator: (HrAccessUser left, HrAccessUser right) =>
              appListTableCompareText(left.displayLabel, right.displayLabel),
          cellBuilder: (BuildContext context, HrAccessUser item) {
            return _HrAccessCopyableIdentifierCell(
              title: item.displayLabel,
              identifier: item.staffProfileId != null
                  ? (item.staffProfileName ?? item.staffProfileId)
                  : item.displayId,
              subtitle:
                  (item.staffProfileName ?? '').trim().isNotEmpty &&
                      item.staffProfileName != item.displayLabel
                  ? item.staffProfileName
                  : null,
            );
          },
        ),
        AppListTableColumn<HrAccessUser>(
          label: l10n.hrEmailLabel,
          sortComparator: (HrAccessUser left, HrAccessUser right) =>
              appListTableCompareText(left.email, right.email),
          cellBuilder: (BuildContext context, HrAccessUser item) {
            return Text(
              (item.email ?? '').trim().isNotEmpty
                  ? item.email!
                  : context.l10n.profileUnknownValue,
            );
          },
        ),
        AppListTableColumn<HrAccessUser>(
          label: l10n.hrAccessAssignedRolesLabel,
          sortComparator: (HrAccessUser left, HrAccessUser right) =>
              appListTableCompareText(
                left.roleNames.join(', '),
                right.roleNames.join(', '),
              ),
          cellBuilder: (BuildContext context, HrAccessUser item) {
            if (item.roleNames.isEmpty) {
              return const Text('—');
            }
            return Text(
              item.roleNames
                  .map(
                    (String role) =>
                        l10n.hrReferenceRoleLabel(role, fallback: role),
                  )
                  .join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        AppListTableColumn<HrAccessUser>(
          label: l10n.hrStatusColumnLabel,
          sortComparator: (HrAccessUser left, HrAccessUser right) =>
              appListTableCompareText(left.status, right.status),
          cellBuilder: (BuildContext context, HrAccessUser item) {
            if ((item.status ?? '').isEmpty) {
              return Text(context.l10n.profileUnknownValue);
            }
            return AppStatusText(
              label: item.status!,
              tone: hrAccessUserStatusTone(item.status),
            );
          },
        ),
        if (showPositionColumn)
          AppListTableColumn<HrAccessUser>(
            label: l10n.hrAccessPositionTitleLabel,
            sortComparator: (HrAccessUser left, HrAccessUser right) =>
                appListTableCompareText(
                  left.positionTitle,
                  right.positionTitle,
                ),
            cellBuilder: (BuildContext context, HrAccessUser item) {
              return Text(
                (item.positionTitle ?? '').trim().isNotEmpty
                    ? item.positionTitle!
                    : context.l10n.profileUnknownValue,
              );
            },
          ),
      ],
      mobileItemBuilder: (BuildContext context, HrAccessUser item) {
        return ListTile(
          title: Text(item.displayLabel),
          subtitle: Text(item.email ?? ''),
          trailing: (item.status ?? '').isNotEmpty
              ? AppStatusText(
                  label: item.status!,
                  tone: hrAccessUserStatusTone(item.status),
                )
              : null,
        );
      },
    );
  }

  Widget _buildRolesTable(BuildContext context, AppLocalizations l10n) {
    return AppListTable<HrAccessRole>(
      page: AppPage<HrAccessRole>(
        items: _roles,
        request: _pageRequest,
        totalItemCount: _totalItemCount,
      ),
      isLoading: _loading,
      search: _accessTableSearch<HrAccessRole>(l10n),
      columnVisibilityController: _roleColumnVisibility,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      itemKeyBuilder: (HrAccessRole item) => ValueKey<String>(item.effectiveId),
      onRowSelected: (HrAccessRole role) async {
        await showHrAccessRoleDetailDialog(
          context,
          ref,
          role,
          canWrite: _canWrite,
          onChanged: () => unawaited(_reload(resetPage: true)),
        );
      },
      previousPageLabel: l10n.hrPreviousPageLabel,
      nextPageLabel: l10n.hrNextPageLabel,
      pageLabelBuilder: (AppPage<HrAccessRole> page) =>
          _accessPageLabel(page, l10n),
      onPageChanged: _onPageChanged,
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.hrAccessPanelRoles,
        body: l10n.hrAccessEmptyRolesLabel,
      ),
      columns: <AppListTableColumn<HrAccessRole>>[
        AppListTableColumn<HrAccessRole>(
          label: l10n.hrAccessRoleNameLabel,
          sortComparator: (HrAccessRole left, HrAccessRole right) =>
              appListTableCompareText(left.name, right.name),
          cellBuilder: (BuildContext context, HrAccessRole item) {
            final String label = l10n.hrReferenceRoleLabel(
              item.name ?? item.effectiveId,
              fallback: item.name ?? item.effectiveId,
            );
            return Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
          },
        ),
        AppListTableColumn<HrAccessRole>(
          label: l10n.hrAccessRoleDescriptionLabel,
          sortComparator: (HrAccessRole left, HrAccessRole right) =>
              appListTableCompareText(left.description, right.description),
          cellBuilder: (BuildContext context, HrAccessRole item) {
            return Text(
              (item.description ?? '').trim().isNotEmpty
                  ? item.description!
                  : context.l10n.profileUnknownValue,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        AppListTableColumn<HrAccessRole>(
          label: l10n.hrAccessPanelPermissions,
          sortComparator: (HrAccessRole left, HrAccessRole right) =>
              left.permissionCount.compareTo(right.permissionCount),
          cellBuilder: (BuildContext context, HrAccessRole item) {
            return Text(
              l10n.hrAccessPermissionCountLabel(item.permissionCount),
            );
          },
        ),
        AppListTableColumn<HrAccessRole>(
          label: l10n.hrStaffColumnLabel,
          sortComparator: (HrAccessRole left, HrAccessRole right) =>
              left.userCount.compareTo(right.userCount),
          cellBuilder: (BuildContext context, HrAccessRole item) {
            return Text(l10n.hrAccessStaffAssignmentCountLabel(item.userCount));
          },
        ),
        AppListTableColumn<HrAccessRole>(
          label: l10n.hrAccessSystemColumnLabel,
          sortComparator: (HrAccessRole left, HrAccessRole right) =>
              appListTableCompareText(
                left.isSystemCritical ? '1' : '0',
                right.isSystemCritical ? '1' : '0',
              ),
          cellBuilder: (BuildContext context, HrAccessRole item) {
            if (!item.isSystemCritical) {
              return const Text('—');
            }
            return Chip(
              label: Text(l10n.hrAccessSystemCriticalRoleBadge),
              visualDensity: VisualDensity.compact,
            );
          },
        ),
      ],
      mobileItemBuilder: (BuildContext context, HrAccessRole item) {
        return ListTile(
          title: Text(item.name ?? item.effectiveId),
          subtitle: Text(
            l10n.hrAccessRoleSummary(item.permissionCount, item.userCount),
          ),
        );
      },
    );
  }

  Widget _buildPermissionsTable(BuildContext context, AppLocalizations l10n) {
    return AppListTable<HrAccessPermission>(
      page: AppPage<HrAccessPermission>(
        items: _permissions,
        request: _pageRequest,
        totalItemCount: _totalItemCount,
      ),
      isLoading: _loading,
      search: _accessTableSearch<HrAccessPermission>(l10n),
      columnVisibilityController: _permissionColumnVisibility,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      itemKeyBuilder: (HrAccessPermission item) =>
          ValueKey<String>(item.effectiveId),
      onRowSelected: (HrAccessPermission permission) async {
        if (_canWrite) {
          await showHrEditPermissionDialog(context, ref, permission);
          if (context.mounted) {
            unawaited(_reload(resetPage: true));
          }
          return;
        }
        await showHrAccessPermissionDetailDialog(context, permission);
      },
      previousPageLabel: l10n.hrPreviousPageLabel,
      nextPageLabel: l10n.hrNextPageLabel,
      pageLabelBuilder: (AppPage<HrAccessPermission> page) =>
          _accessPageLabel(page, l10n),
      onPageChanged: _onPageChanged,
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.hrAccessPanelPermissions,
        body: l10n.hrAccessEmptyPermissionsLabel,
      ),
      columns: <AppListTableColumn<HrAccessPermission>>[
        AppListTableColumn<HrAccessPermission>(
          label: l10n.hrAccessPermissionNameLabel,
          sortComparator: (HrAccessPermission left, HrAccessPermission right) =>
              appListTableCompareText(left.name, right.name),
          cellBuilder: (BuildContext context, HrAccessPermission item) {
            return Text(item.name ?? item.effectiveId);
          },
        ),
        AppListTableColumn<HrAccessPermission>(
          label: l10n.hrAccessPermissionDescriptionLabel,
          sortComparator: (HrAccessPermission left, HrAccessPermission right) =>
              appListTableCompareText(left.description, right.description),
          cellBuilder: (BuildContext context, HrAccessPermission item) {
            final String code = item.name ?? item.effectiveId;
            return Text(
              item.description ??
                  l10n.permissionCatalogDescriptionForCode(code),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        AppListTableColumn<HrAccessPermission>(
          label: l10n.hrAccessPanelRoles,
          sortComparator: (HrAccessPermission left, HrAccessPermission right) =>
              left.roleCount.compareTo(right.roleCount),
          cellBuilder: (BuildContext context, HrAccessPermission item) {
            return Text(l10n.hrAccessPermissionRoleCount(item.roleCount));
          },
        ),
      ],
      mobileItemBuilder: (BuildContext context, HrAccessPermission item) {
        return ListTile(
          title: Text(item.name ?? item.effectiveId),
          subtitle: Text(
            item.description ??
                l10n.hrAccessPermissionRoleCount(item.roleCount),
          ),
        );
      },
    );
  }
}

class _HrAccessCopyableIdentifierCell extends StatelessWidget {
  const _HrAccessCopyableIdentifierCell({
    required this.title,
    this.identifier,
    this.subtitle,
  });

  final String title;
  final String? identifier;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        if ((identifier ?? '').trim().isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          AppCopyableIdentifier(
            value: identifier,
            textStyle: theme.textTheme.bodySmall,
          ),
        ],
        if ((subtitle ?? '').trim().isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

Future<void> showHrAccessPermissionDetailDialog(
  BuildContext context,
  HrAccessPermission permission,
) async {
  final AppLocalizations l10n = context.l10n;

  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AppDialog(
        title: Text(permission.name ?? permission.effectiveId),
        icon: const Icon(Icons.lock_outline),
        scrollable: true,
        maxWidth: 560,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _HrAccessDetailRow(
              label: l10n.hrAccessPermissionDescriptionLabel,
              value: (permission.description ?? '').trim().isNotEmpty
                  ? permission.description!
                  : '—',
            ),
            _HrAccessDetailRow(
              label: l10n.hrAccessPanelRoles,
              value: l10n.hrAccessPermissionRoleCount(permission.roleCount),
            ),
          ],
        ),
        actions: <Widget>[
          AppButton.primary(
            label: l10n.commonCloseActionLabel,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      );
    },
  );
}

Future<void> showHrAccessRoleDetailDialog(
  BuildContext context,
  WidgetRef ref,
  HrAccessRole role, {
  required bool canWrite,
  VoidCallback? onChanged,
}) async {
  final AppLocalizations l10n = context.l10n;
  final String roleLabel = l10n.hrReferenceRoleLabel(
    role.name ?? role.effectiveId,
    fallback: role.name ?? role.effectiveId,
  );

  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AppDialog(
        title: Text(roleLabel),
        icon: const Icon(Icons.shield_outlined),
        scrollable: true,
        maxWidth: 640,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (role.isSystemCritical)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Chip(
                  label: Text(l10n.hrAccessSystemCriticalRoleBadge),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            _HrAccessDetailRow(
              label: l10n.hrAccessRoleDescriptionLabel,
              value: (role.description ?? '').trim().isNotEmpty
                  ? role.description!
                  : '—',
            ),
            _HrAccessDetailRow(
              label: l10n.hrAccessPanelPermissions,
              value: l10n.hrAccessPermissionCountLabel(role.permissionCount),
            ),
            _HrAccessDetailRow(
              label: l10n.hrStaffColumnLabel,
              value: l10n.hrAccessStaffAssignmentCountLabel(role.userCount),
            ),
          ],
        ),
        actions: <Widget>[
          if (canWrite && !role.isSystemCritical) ...<Widget>[
            AppButton.secondary(
              label: l10n.hrAccessAssignPermissionsAction,
              leadingIcon: Icons.security_outlined,
              onPressed: () async {
                await showHrAssignRolePermissionsDialog(context, ref, role);
                onChanged?.call();
              },
            ),
            AppButton.secondary(
              label: l10n.hrAccessEditRoleAction,
              leadingIcon: Icons.edit_outlined,
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await showHrEditRoleDialog(context, ref, role);
                onChanged?.call();
              },
            ),
          ],
          AppButton.primary(
            label: l10n.commonCloseActionLabel,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      );
    },
  );
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
  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return _HrAccessUserDetailDialog(
        user: user,
        onChanged: onChanged,
      );
    },
  );
}

class _HrAccessUserDetailDialog extends ConsumerStatefulWidget {
  const _HrAccessUserDetailDialog({required this.user, this.onChanged});

  final HrAccessUser user;
  final VoidCallback? onChanged;

  @override
  ConsumerState<_HrAccessUserDetailDialog> createState() =>
      _HrAccessUserDetailDialogState();
}

class _HrAccessUserDetailDialogState
    extends ConsumerState<_HrAccessUserDetailDialog> {
  HrAccessUserDetail? _detail;
  AppFailure? _failure;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDetail());
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    final String? tenantId = resolveHrAccessTenantId(ref);
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final Result<HrAccessUserDetail> result = await controller
        .loadAccessUserDetail(widget.user.effectiveId, tenantId: tenantId);
    if (!mounted) {
      return;
    }
    result.when(
      success: (HrAccessUserDetail value) {
        setState(() {
          _loading = false;
          _detail = value;
        });
      },
      failure: (AppFailure value) {
        setState(() {
          _loading = false;
          _failure = value;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool canWrite = canWriteHrAccess(ref);
    final String title = _detail?.profileName ??
        widget.user.displayLabel;

    if (_loading) {
      return AppDialog(
        title: Text(title),
        icon: const Icon(Icons.person_outline),
        content: const Center(child: CircularProgressIndicator()),
        actions: <Widget>[
          AppButton.primary(
            label: l10n.commonCloseActionLabel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    if (_failure != null) {
      return AppDialog(
        title: Text(l10n.hrAccessUserDetailTitle),
        icon: const Icon(Icons.person_outline),
        content: AppFailureStateView(
          failure: _failure!,
          onRetry: () => unawaited(_loadDetail()),
        ),
        actions: <Widget>[
          AppButton.primary(
            label: l10n.commonCloseActionLabel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    final HrAccessUserDetail resolved = _detail!;
    return AppDialog(
      title: Text(title),
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
              Navigator.of(context).pop();
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
              Navigator.of(context).pop();
              await showHrEditAccessUserDialog(
                context,
                ref,
                resolved.toSummary(),
                initialDetail: resolved,
              );
              widget.onChanged?.call();
            },
          ),
        AppButton.primary(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
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
                .map(
                  (String role) => Chip(
                    label: Text(
                      l10n.hrReferenceRoleLabel(role, fallback: role),
                    ),
                  ),
                )
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

  final Result<List<HrAccessPermission>> permissionsResult = await controller
      .loadAllAccessPermissions(
        HrAccessQuery(panel: HrAccessPanel.permissions, tenantId: tenantId),
      );
  final List<HrAccessPermission> permissionOptions = permissionsResult.when(
    success: (List<HrAccessPermission> items) => items,
    failure: (_) => const <HrAccessPermission>[],
  );

  final List<AppRoleAssignmentOption> roleOptions =
      (state?.referenceData.roles ?? const <HrOption>[])
          .map(
            (HrOption role) => AppRoleAssignmentOption(
              id: role.value,
              label: l10n.hrLocalizedOptionLabel(role),
              permissionCount: (role.extra['permission_count'] as int?) ?? 0,
              isSystemCritical: role.extra['is_system_critical'] == true,
            ),
          )
          .toList(growable: false);

  final List<AppPermissionAssignmentOption> permissionAssignmentOptions =
      permissionOptions
          .map(
            (HrAccessPermission permission) => AppPermissionAssignmentOption(
              id: permission.effectiveId,
              code: permission.name ?? permission.effectiveId,
              label: l10n.permissionCatalogLabelForCode(
                permission.name ?? permission.effectiveId,
              ),
              description: permission.description,
            ),
          )
          .toList(growable: false);

  if (!context.mounted) {
    emailController.dispose();
    phoneController.dispose();
    positionController.dispose();
    return;
  }

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAccessManageRolesPermissionsAction),
    icon: const Icon(Icons.manage_accounts_outlined),
    submitLabel: l10n.commonSaveActionLabel,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
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
                      AppSelectOption<String>(
                        value: 'INACTIVE',
                        label: 'Inactive',
                      ),
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
                  AppRoleAssignmentPicker(
                    roles: roleOptions,
                    selectedRoleIds: selectedRoleIds,
                    onSelectionChanged: (Set<String> next) {
                      setState(() {
                        selectedRoleIds
                          ..clear()
                          ..addAll(next);
                      });
                    },
                    loadRolePermissions: (String roleId) async {
                      final Result<AppPage<HrOption>> result = await controller
                          .listRolePermissionOptions(roleId);
                      return result.when(
                        success: (AppPage<HrOption> page) => page.items
                            .map((HrOption option) => option.label)
                            .toSet(),
                        failure: (_) => <String>{},
                      );
                    },
                  ),
                  Text(
                    l10n.hrAccessDirectPermissionsLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  AppPermissionAssignmentPicker(
                    permissions: permissionAssignmentOptions,
                    selectedPermissionIds: selectedPermissionIds,
                    onSelectionChanged: (Set<String> next) {
                      setState(() {
                        selectedPermissionIds
                          ..clear()
                          ..addAll(next);
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
  if (saved == true && context.mounted) {
    _showHrAccessSnackBar(context, null);
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
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
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
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
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

  final Result<List<HrAccessPermission>> permissionsResult = await controller
      .loadAllAccessPermissions(
        HrAccessQuery(panel: HrAccessPanel.permissions, tenantId: tenantId),
      );
  final List<HrAccessPermission> permissionOptions = permissionsResult.when(
    success: (List<HrAccessPermission> items) => items,
    failure: (_) => const <HrAccessPermission>[],
  );
  final Result<AppPage<HrOption>> assignedResult = await controller
      .listRolePermissionOptions(role.effectiveId);
  final Set<String> selectedPermissionIds = assignedResult.when(
    success: (AppPage<HrOption> page) =>
        page.items.map((HrOption option) => option.value).toSet(),
    failure: (_) => <String>{},
  );

  final List<AppPermissionAssignmentOption> permissionAssignmentOptions =
      permissionOptions
          .map(
            (HrAccessPermission permission) => AppPermissionAssignmentOption(
              id: permission.effectiveId,
              code: permission.name ?? permission.effectiveId,
              label: l10n.permissionCatalogLabelForCode(
                permission.name ?? permission.effectiveId,
              ),
              description: permission.description,
            ),
          )
          .toList(growable: false);

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
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AppFormSection(
                children: <Widget>[
                  Text(
                    role.name ?? role.effectiveId,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (permissionAssignmentOptions.isEmpty)
                    Text(l10n.hrAccessEmptyPermissionsLabel)
                  else
                    AppPermissionAssignmentPicker(
                      permissions: permissionAssignmentOptions,
                      selectedPermissionIds: selectedPermissionIds,
                      onSelectionChanged: (Set<String> next) {
                        setState(() {
                          selectedPermissionIds
                            ..clear()
                            ..addAll(next);
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

  final Result<List<HrAccessPermission>> existingResult = await controller
      .loadAllAccessPermissions(
        HrAccessQuery(panel: HrAccessPanel.permissions, tenantId: tenantId),
      );
  final Set<String> provisionedCodes = existingResult.when(
    success: (List<HrAccessPermission> items) => items
        .map((HrAccessPermission p) => p.name ?? '')
        .where((String name) => name.isNotEmpty)
        .toSet(),
    failure: (_) => <String>{},
  );
  final List<AppPermission> catalogOptions = AppPermissions.all
      .where(
        (AppPermission permission) =>
            !provisionedCodes.contains(permission.value),
      )
      .toList(growable: false)
    ..sort((AppPermission left, AppPermission right) =>
        left.value.compareTo(right.value));

  String? selectedPermissionCode;
  final TextEditingController descriptionController = TextEditingController();

  if (!context.mounted) {
    descriptionController.dispose();
    return;
  }

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAccessCreatePermissionAction),
    icon: const Icon(Icons.add_circle_outline),
    submitLabel: l10n.commonSaveActionLabel,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AppFormSection(
                children: <Widget>[
                  if (catalogOptions.isEmpty)
                    Text(l10n.hrAccessEmptyPermissionsLabel)
                  else
                    AppSelectField<String>.searchable(
                      value: selectedPermissionCode,
                      labelText: l10n.hrAccessPermissionCatalogSelectLabel,
                      isRequired: true,
                      options: <AppSelectOption<String>>[
                        for (final AppPermission permission in catalogOptions)
                          AppSelectOption<String>(
                            value: permission.value,
                            label: l10n.permissionCatalogLabel(permission),
                            searchText:
                                '${permission.value} ${l10n.permissionCatalogLabel(permission)}',
                          ),
                      ],
                      onChanged: (String? value) {
                        setState(() {
                          selectedPermissionCode = value;
                          if (value != null) {
                            descriptionController.text = l10n
                                .permissionCatalogDescriptionForCode(value);
                          }
                        });
                      },
                    ),
                  AppTextField(
                    controller: descriptionController,
                    labelText: l10n.hrAccessPermissionDescriptionLabel,
                    maxLines: 2,
                  ),
                ],
              );
            },
          );
        },
    onSubmit: () {
      final String? code = selectedPermissionCode?.trim();
      if (code == null || code.isEmpty) {
        return Future<AppFailure?>.value(AppFailure.validation());
      }
      return controller.createAccessPermission(<String, Object?>{
        'tenant_id': tenantId,
        'name': code,
        'description': descriptionController.text.trim(),
      });
    },
  );
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
  final TextEditingController descriptionController = TextEditingController(
    text: permission.description,
  );
  final String permissionName = permission.name ?? permission.effectiveId;

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAccessEditPermissionAction),
    icon: const Icon(Icons.edit_outlined),
    submitLabel: l10n.commonSaveActionLabel,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return AppFormSection(
            children: <Widget>[
              AppTextField(
                initialValue: permissionName,
                labelText: l10n.hrAccessPermissionNameLabel,
                readOnly: true,
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
          'description': descriptionController.text.trim(),
        }),
  );
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
