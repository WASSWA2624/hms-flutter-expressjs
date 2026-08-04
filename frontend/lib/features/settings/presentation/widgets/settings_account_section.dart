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
    final List<_ProfileKvItem> accountItems = <_ProfileKvItem>[
      _ProfileKvItem(
        label: l10n.profilePhoneLabel,
        value: _value(profile.phone, l10n),
      ),
      _ProfileKvItem(
        label: l10n.profileUserIdLabel,
        value: _value(profile.displayId ?? profile.id, l10n),
        copyable: true,
        copyTooltip: l10n.copyUserIdAction,
        copiedMessage: l10n.userIdCopiedMessage,
      ),
    ];
    final List<_ProfileKvItem> professionalItems = <_ProfileKvItem>[
      _ProfileKvItem(
        label: l10n.profileOverallRoleLabel,
        value: _value(profile.overallRole, l10n),
      ),
      _ProfileKvItem(
        label: l10n.profileUserTypeLabel,
        value: _value(profile.userType, l10n),
      ),
      _ProfileKvItem(
        label: l10n.profileTenantLabel,
        value: _value(profile.tenantName, l10n),
      ),
      _ProfileKvItem(
        label: l10n.profileFacilityTypeLabel,
        value: _value(_formatProfileToken(profile.facilityType), l10n),
      ),
      _ProfileKvItem(
        label: l10n.profileStaffNumberLabel,
        value: _value(profile.staffNumber, l10n),
        copyable: true,
        copyTooltip: l10n.copyIdentifierAction,
        copiedMessage: l10n.identifierCopiedMessage,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ProfileSummary(profile: profile),
        SizedBox(height: theme.spacing.lg),
        _ProfileSectionPair(
          leading: _ProfileBlock(
            title: l10n.profileAccountSectionTitle,
            child: _ProfileKvList(items: accountItems),
          ),
          trailing: _ProfileBlock(
            title: l10n.profileProfessionalSectionTitle,
            child: _ProfileKvList(items: professionalItems),
          ),
        ),
        SizedBox(height: theme.spacing.lg),
        _ProfileSectionPair(
          leading: _ProfileBlock(
            title: l10n.profileRolesSectionTitle,
            child: _ProfileChipGroup(
              emptyLabel: l10n.profileRolesEmpty,
              labels: <String>[
                for (final String role in roles)
                  _formatProfileToken(role) ?? role,
              ],
            ),
          ),
          trailing: _ProfileBlock(
            title: l10n.profilePermissionsSectionTitle,
            child: _ProfileChipGroup(
              emptyLabel: l10n.profilePermissionsEmpty,
              labels: <String>[
                for (final AppPermission permission in permissions)
                  permission.value,
              ],
            ),
          ),
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
    final String? statusLabel = _formatProfileToken(profile.status);
    final List<String> metaParts = <String>[
      if ((profile.email ?? '').trim().isNotEmpty) profile.email!.trim(),
      if ((profile.effectiveTitle ?? '').trim().isNotEmpty)
        profile.effectiveTitle!.trim(),
      if ((profile.facilityName ?? '').trim().isNotEmpty)
        profile.facilityName!.trim(),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(theme.radius.md),
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
                        _ProfileBadge(
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

  _ProfileBadgeTone _statusTone(String? status) {
    final String normalized = (status ?? '').trim().toUpperCase();
    if (normalized == 'ACTIVE') {
      return _ProfileBadgeTone.success;
    }
    if (normalized == 'INACTIVE' || normalized == 'SUSPENDED') {
      return _ProfileBadgeTone.warning;
    }
    return _ProfileBadgeTone.neutral;
  }
}

enum _ProfileBadgeTone { neutral, success, warning }

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({
    required this.label,
    this.tone = _ProfileBadgeTone.neutral,
  });

  final String label;
  final _ProfileBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color background;
    final Color foreground;
    switch (tone) {
      case _ProfileBadgeTone.success:
        background = colorScheme.primaryContainer.withValues(alpha: 0.7);
        foreground = colorScheme.onPrimaryContainer;
      case _ProfileBadgeTone.warning:
        background = colorScheme.tertiaryContainer.withValues(alpha: 0.7);
        foreground = colorScheme.onTertiaryContainer;
      case _ProfileBadgeTone.neutral:
        background = colorScheme.secondaryContainer.withValues(alpha: 0.55);
        foreground = colorScheme.onSecondaryContainer;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(theme.radius.sm),
        border: theme.borders.all(),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs / 2,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: foreground,
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
      ),
    );
  }
}

class _ProfileBlock extends StatelessWidget {
  const _ProfileBlock({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: theme.borders.all(),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: AppFontWeight.strong,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

final class _ProfileKvItem {
  const _ProfileKvItem({
    required this.label,
    required this.value,
    this.copyable = false,
    this.copyTooltip,
    this.copiedMessage,
  });

  final String label;
  final String value;
  final bool copyable;
  final String? copyTooltip;
  final String? copiedMessage;
}

class _ProfileKvList extends StatelessWidget {
  const _ProfileKvList({required this.items});

  final List<_ProfileKvItem> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < items.length; index += 1) ...<Widget>[
          if (index > 0) SizedBox(height: theme.spacing.sm),
          _ProfileKvRow(item: items[index]),
        ],
      ],
    );
  }
}

class _ProfileKvRow extends StatelessWidget {
  const _ProfileKvRow({required this.item});

  final _ProfileKvItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextStyle? labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final TextStyle? valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: AppFontWeight.emphasis,
      color: colorScheme.onSurface,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('${item.label}:', style: labelStyle),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: item.copyable
              ? AppCopyableIdentifier(
                  value: item.value,
                  tooltip: item.copyTooltip,
                  copiedMessage: item.copiedMessage,
                  textStyle: valueStyle,
                )
              : Text(item.value, style: valueStyle),
        ),
      ],
    );
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
        for (final String label in labels) _ProfileBadge(label: label),
      ],
    );
  }
}

class _ProfileSectionPair extends StatelessWidget {
  const _ProfileSectionPair({
    required this.leading,
    required this.trailing,
  });

  final Widget leading;
  final Widget trailing;

  static const double _sideBySideBreakpoint = 760;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool sideBySide = constraints.maxWidth >= _sideBySideBreakpoint;
        if (!sideBySide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              leading,
              SizedBox(height: theme.spacing.md),
              trailing,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: leading),
            SizedBox(width: theme.spacing.md),
            Expanded(child: trailing),
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
