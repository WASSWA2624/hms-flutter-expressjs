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
import 'package:hosspi_hms/shared/layout/layout.dart';

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
      barrierDismissible: false,
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
    final UserProfileRecord? editableRecord = canUpdate ? record : null;

    return AppAccessGate(
      requirement: SettingsAccountAtomPermissions.tab,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (canUpdate)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
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
          if (canUpdate) SizedBox(height: theme.spacing.sm),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ProfileSummary(profile: profile),
        SizedBox(height: theme.spacing.lg),
        _ProfileSectionGrid(
          sections: <Widget>[
            _ProfileDetailSection(
              title: l10n.profileAccountSectionTitle,
              body: l10n.profileAccountSectionBody,
              items: <_ProfileDetailItem>[
                _ProfileDetailItem(
                  label: l10n.profileNameLabel,
                  value: _value(profile.displayName, l10n),
                ),
                _ProfileDetailItem(
                  label: l10n.profileEmailLabel,
                  value: _value(profile.email ?? session.subject, l10n),
                ),
                _ProfileDetailItem(
                  label: l10n.profilePhoneLabel,
                  value: _value(profile.phone, l10n),
                ),
                _ProfileDetailItem(
                  label: l10n.profileStatusLabel,
                  value: _value(_formatProfileToken(profile.status), l10n),
                ),
                _ProfileDetailItem(
                  label: l10n.profileUserIdLabel,
                  value: _value(profile.displayId ?? profile.id, l10n),
                  selectable: true,
                  copyTooltip: l10n.copyUserIdAction,
                  copiedMessage: l10n.userIdCopiedMessage,
                ),
              ],
            ),
            _ProfileDetailSection(
              title: l10n.profileProfessionalSectionTitle,
              body: l10n.profileProfessionalSectionBody,
              items: <_ProfileDetailItem>[
                _ProfileDetailItem(
                  label: l10n.profileTitleLabel,
                  value: _value(profile.effectiveTitle, l10n),
                ),
                _ProfileDetailItem(
                  label: l10n.profileOverallRoleLabel,
                  value: _value(profile.overallRole, l10n),
                ),
                _ProfileDetailItem(
                  label: l10n.profileUserTypeLabel,
                  value: _value(profile.userType, l10n),
                ),
                _ProfileDetailItem(
                  label: l10n.profileTenantLabel,
                  value: _value(profile.tenantName, l10n),
                ),
                _ProfileDetailItem(
                  label: l10n.profileFacilityLabel,
                  value: _value(profile.facilityName, l10n),
                ),
                _ProfileDetailItem(
                  label: l10n.profileFacilityTypeLabel,
                  value: _value(
                    _formatProfileToken(profile.facilityType),
                    l10n,
                  ),
                ),
                _ProfileDetailItem(
                  label: l10n.profileStaffNumberLabel,
                  value: _value(profile.staffNumber, l10n),
                  selectable: true,
                  copyTooltip: l10n.copyIdentifierAction,
                  copiedMessage: l10n.identifierCopiedMessage,
                ),
              ],
            ),
            _ProfileRolesSection(roles: roles),
            _ProfilePermissionsSection(permissions: permissions),
          ],
        ),
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
    final String supportingLine = <String>[
      if (profile.email != null) profile.email!,
      if (profile.effectiveTitle != null) profile.effectiveTitle!,
    ].join(' | ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              radius: 32,
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: Text(
                profile.initials,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: theme.spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (supportingLine.isNotEmpty) ...<Widget>[
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      supportingLine,
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
}

// ---------------------------------------------------------------------------
// Profile detail widgets
// ---------------------------------------------------------------------------

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ProfileDetailSection extends StatelessWidget {
  const _ProfileDetailSection({
    required this.title,
    required this.body,
    required this.items,
  });

  final String title;
  final String body;
  final List<_ProfileDetailItem> items;

  @override
  Widget build(BuildContext context) {
    return AppCollapsibleSection(
      title: title,
      description: body,
      child: _ProfileDetailList(items: items),
    );
  }
}

class _ProfileRolesSection extends StatelessWidget {
  const _ProfileRolesSection({required this.roles});

  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppCollapsibleSection(
      title: l10n.profileRolesSectionTitle,
      description: l10n.profileRolesSectionBody,
      child: roles.isEmpty
          ? Text(
              l10n.profileRolesEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                for (final String role in roles)
                  _ProfileBadge(label: _formatProfileToken(role) ?? role),
              ],
            ),
    );
  }
}

class _ProfilePermissionsSection extends StatelessWidget {
  const _ProfilePermissionsSection({required this.permissions});

  final List<AppPermission> permissions;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppCollapsibleSection(
      title: l10n.profilePermissionsSectionTitle,
      description: l10n.profilePermissionsSectionBody,
      child: permissions.isEmpty
          ? Text(
              l10n.profilePermissionsEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                for (final AppPermission permission in permissions)
                  _ProfileBadge(label: permission.value),
              ],
            ),
    );
  }
}

class _ProfileDetailList extends StatelessWidget {
  const _ProfileDetailList({required this.items});

  final List<_ProfileDetailItem> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Column(
      children: <Widget>[
        for (var index = 0; index < items.length; index += 1) ...<Widget>[
          if (index > 0)
            Divider(
              height: theme.spacing.lg,
              color: colorScheme.outlineVariant,
            ),
          _ProfileDetailRow(item: items[index]),
        ],
      ],
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({required this.item});

  final _ProfileDetailItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextStyle? valueStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w500,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget label = Text(
          item.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        );
        final Widget value = item.selectable
            ? AppCopyableIdentifier(
                value: item.value,
                tooltip: item.copyTooltip,
                copiedMessage: item.copiedMessage,
                textStyle: valueStyle,
              )
            : Text(item.value, style: valueStyle);

        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              label,
              SizedBox(height: theme.spacing.xs),
              value,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(width: 150, child: label),
            SizedBox(width: theme.spacing.md),
            Expanded(child: value),
          ],
        );
      },
    );
  }
}

class _ProfileDetailItem {
  const _ProfileDetailItem({
    required this.label,
    required this.value,
    this.selectable = false,
    this.copyTooltip,
    this.copiedMessage,
  });

  final String label;
  final String value;
  final bool selectable;
  final String? copyTooltip;
  final String? copiedMessage;
}

class _ProfileSectionGrid extends StatelessWidget {
  const _ProfileSectionGrid({required this.sections});

  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool useTwoColumns = constraints.maxWidth >= 920;
        final double itemWidth = useTwoColumns
            ? (constraints.maxWidth - theme.spacing.lg) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: theme.spacing.lg,
          runSpacing: theme.spacing.lg,
          children: <Widget>[
            for (final Widget section in sections)
              SizedBox(width: itemWidth, child: section),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _value(String? value, AppLocalizations l10n) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty
      ? l10n.profileUnknownValue
      : normalized;
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
