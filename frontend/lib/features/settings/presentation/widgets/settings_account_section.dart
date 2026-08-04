import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/app_permission_catalog_localizations.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/change_password_dialog.dart';
import 'package:hosspi_hms/features/profile/domain/entities/user_profile_entities.dart';
import 'package:hosspi_hms/features/profile/presentation/controllers/user_profile_controller.dart';
import 'package:hosspi_hms/features/profile/presentation/state/user_profile_state.dart';
import 'package:hosspi_hms/features/profile/presentation/widgets/edit_user_profile_dialog.dart';
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Account and security tab (`/settings?tab=account`).
///
/// See [SettingsAccountAtomPermissions] for the inventory → matrix map.
class SettingsAccountSection extends ConsumerStatefulWidget {
  const SettingsAccountSection({
    this.initialPanel,
    this.onPanelChanged,
    super.key,
  });

  final String? initialPanel;
  final ValueChanged<String>? onPanelChanged;

  /// Deep-link / redirect target for the profile surface (`/profile`).
  static const String profilePanel = 'profile';

  /// Deep-link target that opens the change-password dialog on the profile
  /// surface (no intermediate panel).
  static const String changePasswordPanel = 'change-password';

  @override
  ConsumerState<SettingsAccountSection> createState() =>
      _SettingsAccountSectionState();
}

class _SettingsAccountSectionState
    extends ConsumerState<SettingsAccountSection> {
  bool _changePasswordDeepLinkPending = false;

  @override
  void initState() {
    super.initState();
    _scheduleChangePasswordDeepLink(widget.initialPanel);
  }

  @override
  void didUpdateWidget(covariant SettingsAccountSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPanel != oldWidget.initialPanel) {
      _scheduleChangePasswordDeepLink(widget.initialPanel);
    }
  }

  void _scheduleChangePasswordDeepLink(String? panel) {
    if (panel != SettingsAccountSection.changePasswordPanel) {
      return;
    }
    if (_changePasswordDeepLinkPending) {
      return;
    }
    _changePasswordDeepLinkPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_openChangePasswordFromDeepLink());
    });
  }

  Future<void> _openChangePasswordFromDeepLink() async {
    if (!mounted) {
      _changePasswordDeepLinkPending = false;
      return;
    }
    // Clear the deep-link panel so rebuilds stay on the profile surface.
    widget.onPanelChanged?.call(SettingsAccountSection.profilePanel);
    final AppAccessPolicy accessPolicy = ref.read(appAccessPolicyProvider);
    if (!SettingsAccountAtomPermissions.changePassword.isAllowed(accessPolicy)) {
      // Restricted deep link: surface forbidden feedback once, then stay read-only.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.routeForbiddenTitle)),
        );
      }
      _changePasswordDeepLinkPending = false;
      return;
    }
    await _changePassword(context);
    _changePasswordDeepLinkPending = false;
  }

  Future<void> _changePassword(BuildContext context) async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );

    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.authPasswordChangedMessage)),
      );
      context.go(AppRoutes.login.location());
    }
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    UserProfileRecord record,
  ) async {
    final UserProfileDraft? draft = await showAppDialog<UserProfileDraft>(
      context: context,
      builder: (_) => EditUserProfileDialog(record: record),
    );
    if (draft == null || !context.mounted) return;

    final bool saved = await ref
        .read(userProfileControllerProvider.notifier)
        .saveProfile(draft);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? context.l10n.profileSaveSuccessMessage
              : context.l10n.profileSaveErrorMessage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final AsyncValue<Result<UserProfileState>> profileState = ref.watch(
      userProfileControllerProvider,
    );

    final UserProfileRecord? record = profileState.maybeWhen(
      data: (Result<UserProfileState> result) => result.when(
        success: (UserProfileState state) => state.view.record,
        failure: (_) => null,
      ),
      orElse: () => null,
    );

    final bool isSaving = profileState.maybeWhen(
      data: (Result<UserProfileState> result) => result.when(
        success: (UserProfileState state) => state.isSaving,
        failure: (_) => false,
      ),
      orElse: () => false,
    );

    final bool canUpdate =
        SettingsAccountAtomPermissions.update.isAllowed(accessPolicy);
    final bool canChangePassword =
        SettingsAccountAtomPermissions.changePassword.isAllowed(accessPolicy);
    final UserProfileRecord? editableRecord = canUpdate ? record : null;
    final bool showToolbar = canChangePassword || editableRecord != null;

    return AppAccessGate(
      requirement: SettingsAccountAtomPermissions.tab,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (showToolbar)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  if (canChangePassword)
                    AppAccessActionGate(
                      requirement: SettingsAccountAtomPermissions.changePassword,
                      builder: (BuildContext context, bool _) {
                        return AppTabToolbarAction(
                          label: l10n.settingsChangePasswordActionTitle,
                          icon: Icons.lock_reset_outlined,
                          onPressed: () => unawaited(_changePassword(context)),
                        );
                      },
                    ),
                  if (editableRecord != null)
                    AppAccessActionGate(
                      requirement: SettingsAccountAtomPermissions.editProfile,
                      builder: (BuildContext context, bool _) {
                        return AppTabToolbarPrimary(
                          label: l10n.profileEditActionTitle,
                          icon: Icons.edit_outlined,
                          enabled: !isSaving,
                          onPressed: isSaving
                              ? null
                              : () => unawaited(
                                  _editProfile(context, ref, editableRecord),
                                ),
                        );
                      },
                    ),
                ],
              ),
            ),
          if (showToolbar) SizedBox(height: theme.spacing.sm),
          const _ProfilePanel(),
        ],
      ),
    );
  }
}
// ---------------------------------------------------------------------------
// Profile panel
// ---------------------------------------------------------------------------

class _ProfilePanel extends ConsumerWidget {
  const _ProfilePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<UserProfileState>> profileState = ref.watch(
      userProfileControllerProvider,
    );

    return profileState.when(
      loading: () => AppStateView(
        variant: AppStateViewVariant.loading,
        title: l10n.profileLoadingTitle,
        body: l10n.profileLoadingBody,
      ),
      error: (_, _) => AppFailureStateView(
        failure: const AppFailure.unexpected(),
        title: l10n.profileUnavailableTitle,
        onRetry: () => unawaited(
          ref.read(userProfileControllerProvider.notifier).refresh(),
        ),
      ),
      data: (Result<UserProfileState> result) => result.when(
        success: (UserProfileState state) => _ProfilePanelContent(state: state),
        failure: (AppFailure failure) => AppFailureStateView(
          failure: failure,
          title: l10n.profileUnavailableTitle,
          onRetry: () => unawaited(
            ref.read(userProfileControllerProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}

class _ProfilePanelContent extends ConsumerWidget {
  const _ProfilePanelContent({required this.state});

  final UserProfileState state;

  static const int _permissionsCollapseThreshold = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final UserProfileView view = state.view;
    final AuthUserProfile profile = view.profile;
    final AuthSession session = view.session;

    if (profile.displayName == null && session.subject == null) {
      return AppStateView(
        title: l10n.profileUnavailableTitle,
        body: l10n.profileUnavailableBody,
        icon: Icons.person_off_outlined,
      );
    }

    final List<String> roles = view.roles;
    final List<AppPermission> permissions = view.permissions;
    final List<AppInfoTileData> accountItems = <AppInfoTileData>[
      AppInfoTileData(
        label: l10n.profileEmailLabel,
        value: _optionalValue(profile.email),
        icon: Icons.mail_outline,
      ),
      AppInfoTileData(
        label: l10n.profilePhoneLabel,
        value: _optionalValue(profile.phone),
        icon: Icons.phone_outlined,
      ),
      AppInfoTileData(
        label: l10n.profileUserIdLabel,
        value: _optionalValue(profile.displayId ?? profile.id),
        icon: Icons.badge_outlined,
        copyable: true,
        copyTooltip: l10n.copyUserIdAction,
        copiedMessage: l10n.userIdCopiedMessage,
      ),
      AppInfoTileData(
        label: l10n.profileStatusLabel,
        value: _optionalValue(_formatProfileToken(profile.status)),
        icon: Icons.verified_user_outlined,
      ),
    ];
    final List<AppInfoTileData> professionalItems = <AppInfoTileData>[
      AppInfoTileData(
        label: l10n.profileOverallRoleLabel,
        value: _optionalValue(profile.overallRole),
        icon: Icons.work_outline,
      ),
      AppInfoTileData(
        label: l10n.profileUserTypeLabel,
        value: _optionalValue(profile.userType),
        icon: Icons.manage_accounts_outlined,
      ),
      AppInfoTileData(
        label: l10n.profileTitleLabel,
        value: _optionalValue(profile.effectiveTitle),
        icon: Icons.medical_services_outlined,
      ),
      AppInfoTileData(
        label: l10n.profileTenantLabel,
        value: _optionalValue(profile.tenantName),
        icon: Icons.business_outlined,
      ),
      AppInfoTileData(
        label: l10n.profileFacilityLabel,
        value: _optionalValue(profile.facilityName),
        icon: Icons.local_hospital_outlined,
      ),
      AppInfoTileData(
        label: l10n.profileFacilityTypeLabel,
        value: _optionalValue(_formatProfileToken(profile.facilityType)),
        icon: Icons.apartment_outlined,
      ),
      AppInfoTileData(
        label: l10n.profileStaffNumberLabel,
        value: _optionalValue(profile.staffNumber),
        icon: Icons.pin_outlined,
        copyable: true,
        copyTooltip: l10n.copyIdentifierAction,
        copiedMessage: l10n.identifierCopiedMessage,
      ),
    ];
    final List<AppPermissionAssignmentOption> permissionOptions =
        <AppPermissionAssignmentOption>[
          for (final AppPermission permission in permissions)
            AppPermissionAssignmentOption(
              id: permission.value,
              code: permission.value,
              label: l10n.permissionCatalogLabel(permission),
            ),
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ProfileSummary(profile: profile),
        SizedBox(height: theme.spacing.md),
        ...appCollapsibleSectionSpacing(context, <Widget>[
          AppCollapsibleSection(
            title: l10n.profileAccountSectionTitle,
            description: l10n.profileAccountSectionBody,
            titleIcon: Icons.person_outline,
            child: AppInfoTileGrid(
              emptyValue: l10n.profileUnknownValue,
              maxColumns: 3,
              items: accountItems,
            ),
          ),
          AppCollapsibleSection(
            title: l10n.profileProfessionalSectionTitle,
            description: l10n.profileProfessionalSectionBody,
            titleIcon: Icons.work_outline,
            child: AppInfoTileGrid(
              emptyValue: l10n.profileUnknownValue,
              maxColumns: 3,
              items: professionalItems,
            ),
          ),
          AppCollapsibleSection(
            title: l10n.profileRolesSectionTitle,
            description: l10n.profileRolesSectionBody,
            titleIcon: Icons.groups_outlined,
            child: _ProfileChipGroup(
              emptyLabel: l10n.profileRolesEmpty,
              labels: <String>[
                for (final String role in roles)
                  _formatProfileToken(role) ?? role,
              ],
            ),
          ),
          AppCollapsibleSection(
            title: l10n.profilePermissionsSectionTitle,
            description: l10n.profilePermissionsSectionBody,
            titleIcon: Icons.lock_outline,
            initiallyExpanded:
                permissions.isEmpty ||
                permissions.length <= _permissionsCollapseThreshold,
            child: permissions.length > _permissionsCollapseThreshold
                ? AppPermissionGroupedView(
                    permissions: permissionOptions,
                    emptyMessage: l10n.profilePermissionsEmpty,
                  )
                : _ProfileChipGroup(
                    emptyLabel: l10n.profilePermissionsEmpty,
                    labels: <String>[
                      for (final AppPermissionAssignmentOption option
                          in permissionOptions)
                        option.label,
                    ],
                  ),
          ),
        ]),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Profile summary (identity only — details live in sections below)
// ---------------------------------------------------------------------------

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile});

  final AuthUserProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;
    final String displayName = _value(profile.displayName, l10n);
    final String? statusLabel = _formatProfileToken(profile.status);
    final List<String> metaParts = <String>[
      if ((profile.effectiveTitle ?? '').trim().isNotEmpty)
        profile.effectiveTitle!.trim(),
      if ((profile.facilityName ?? '').trim().isNotEmpty)
        profile.facilityName!.trim(),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: theme.borders.all(),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: Text(
                profile.initials,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: AppFontWeight.strong,
                ),
              ),
            ),
            SizedBox(width: theme.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: theme.spacing.sm,
                    runSpacing: theme.spacing.xs,
                    children: <Widget>[
                      Text(
                        displayName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: AppFontWeight.strong,
                        ),
                      ),
                      if (statusLabel != null)
                        AppStatusBadge(
                          label: statusLabel,
                          tone: _statusTone(profile.status),
                        ),
                    ],
                  ),
                  if (metaParts.isNotEmpty) ...<Widget>[
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      metaParts.join(' · '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppWorkspaceStatusTone _statusTone(String? status) {
    final String normalized = (status ?? '').trim().toUpperCase();
    if (normalized == 'ACTIVE') {
      return AppWorkspaceStatusTone.success;
    }
    if (normalized == 'INACTIVE' || normalized == 'SUSPENDED') {
      return AppWorkspaceStatusTone.warning;
    }
    return AppWorkspaceStatusTone.neutral;
  }
}

class _ProfileChipGroup extends StatelessWidget {
  const _ProfileChipGroup({
    required this.labels,
    required this.emptyLabel,
  });

  final List<String> labels;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (labels.isEmpty) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.sm,
      children: <Widget>[
        for (final String label in labels)
          AppStatusBadge(
            label: label,
            tone: AppWorkspaceStatusTone.info,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String? _optionalValue(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _value(String? value, AppLocalizations l10n) {
  return _optionalValue(value) ?? l10n.profileUnknownValue;
}

String? _formatProfileToken(String? value) {
  final String? normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  final String words = normalized
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .map((String word) {
        final String lower = word.toLowerCase();
        return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');

  return words.isEmpty ? null : words;
}
