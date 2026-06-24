import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/change_password_dialog.dart';
import 'package:hosspi_hms/features/profile/domain/entities/user_profile_entities.dart';
import 'package:hosspi_hms/features/profile/presentation/controllers/user_profile_controller.dart';
import 'package:hosspi_hms/features/profile/presentation/state/user_profile_state.dart';
import 'package:hosspi_hms/features/profile/presentation/widgets/edit_user_profile_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';

class UserProfilePage extends ConsumerWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<UserProfileState>> profileState = ref.watch(
      userProfileControllerProvider,
    );

    return profileState.when(
      loading: () => AppScreen(
        title: l10n.profileTitle,
        body: l10n.profileBody,
        maxWidth: PageMaxWidth.dashboard,
        children: <Widget>[
          AppStateView(
            variant: AppStateViewVariant.loading,
            title: l10n.profileLoadingTitle,
            body: l10n.profileLoadingBody,
          ),
        ],
      ),
      error: (_, _) => AppScreen(
        title: l10n.profileTitle,
        body: l10n.profileBody,
        maxWidth: PageMaxWidth.dashboard,
        children: <Widget>[
          AppFailureStateView(
            failure: const AppFailure.unexpected(),
            title: l10n.profileUnavailableTitle,
            onRetry: () => unawaited(
              ref.read(userProfileControllerProvider.notifier).refresh(),
            ),
          ),
        ],
      ),
      data: (Result<UserProfileState> result) => result.when(
        success: (UserProfileState state) {
          return _ProfileContent(state: state);
        },
        failure: (AppFailure failure) {
          return AppScreen(
            title: l10n.profileTitle,
            body: l10n.profileBody,
            maxWidth: PageMaxWidth.dashboard,
            children: <Widget>[
              AppFailureStateView(
                failure: failure,
                title: l10n.profileUnavailableTitle,
                onRetry: () => unawaited(
                  ref.read(userProfileControllerProvider.notifier).refresh(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.state});

  final UserProfileState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final UserProfileView view = state.view;
    final AuthUserProfile profile = view.profile;
    final AuthSession session = view.session;

    if (profile.displayName == null && session.subject == null) {
      return AppScreen(
        title: l10n.profileTitle,
        body: l10n.profileBody,
        children: <Widget>[
          AppStateView(
            title: l10n.profileUnavailableTitle,
            body: l10n.profileUnavailableBody,
            icon: Icons.person_off_outlined,
          ),
        ],
      );
    }

    final List<String> roles = view.roles;
    final List<AppPermission> permissions = view.permissions;

    return AppScreen(
      title: l10n.profileTitle,
      body: l10n.profileBody,
      maxWidth: PageMaxWidth.dashboard,
      headerActions: <Widget>[
        if (view.record != null)
          AppButton.secondary(
            label: l10n.profileEditActionTitle,
            leadingIcon: Icons.edit_outlined,
            enabled: !state.isSaving,
            onPressed: state.isSaving
                ? null
                : () => unawaited(_editProfile(context, ref, view.record!)),
          ),
        AppButton.secondary(
          label: l10n.profileChangePasswordActionTitle,
          leadingIcon: Icons.lock_reset_outlined,
          onPressed: () => unawaited(_changePassword(context)),
        ),
        AppButton.secondary(
          label: l10n.commonRefreshActionLabel,
          leadingIcon: Icons.refresh,
          onPressed: () => unawaited(
            ref.read(userProfileControllerProvider.notifier).refresh(),
          ),
        ),
      ],
      children: <Widget>[
        _ProfileSummary(
          profile: profile,
          permissionCount: permissions.length,
          roleCount: roles.length,
        ),
        SizedBox(height: Theme.of(context).spacing.lg),
        _ProfileSectionGrid(
          sections: <Widget>[
            AppScreenSection(
              title: l10n.profileAccountSectionTitle,
              body: l10n.profileAccountSectionBody,
              child: _ProfileDetailList(
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
            ),
            AppScreenSection(
              title: l10n.profileProfessionalSectionTitle,
              body: l10n.profileProfessionalSectionBody,
              child: _ProfileDetailList(
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
            ),
            AppScreenSection(
              title: l10n.profileRolesSectionTitle,
              body: l10n.profileRolesSectionBody,
              child: roles.isEmpty
                  ? Text(
                      l10n.profileRolesEmpty,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Wrap(
                      spacing: Theme.of(context).spacing.sm,
                      runSpacing: Theme.of(context).spacing.sm,
                      children: <Widget>[
                        for (final String role in roles)
                          _ProfileBadge(
                            label: _formatProfileToken(role) ?? role,
                          ),
                      ],
                    ),
            ),
            AppScreenSection(
              title: l10n.profilePermissionsSectionTitle,
              body: l10n.profilePermissionsSectionBody,
              child: permissions.isEmpty
                  ? Text(
                      l10n.profilePermissionsEmpty,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Wrap(
                      spacing: Theme.of(context).spacing.sm,
                      runSpacing: Theme.of(context).spacing.sm,
                      children: <Widget>[
                        for (final AppPermission permission in permissions)
                          _ProfileBadge(label: permission.value),
                      ],
                    ),
            ),
          ],
        ),
      ],
    );
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
    if (draft == null || !context.mounted) {
      return;
    }

    final bool saved = await ref
        .read(userProfileControllerProvider.notifier)
        .saveProfile(draft);
    if (!context.mounted) {
      return;
    }

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
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({
    required this.profile,
    required this.permissionCount,
    required this.roleCount,
  });

  final AuthUserProfile profile;
  final int permissionCount;
  final int roleCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final displayName = _value(profile.displayName, l10n);
    final supportingLine = <String>[
      if (profile.email != null) profile.email!,
      if (profile.effectiveTitle != null) profile.effectiveTitle!,
    ].join(' | ');
    final badges = <String>{
      if (profile.overallRole != null) profile.overallRole!,
      if (profile.userType != null) profile.userType!,
      l10n.profileRoleCountLabel(roleCount),
      l10n.profilePermissionCountLabel(permissionCount),
    }.toList(growable: false);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              radius: 30,
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: Text(
                profile.initials,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
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
                      fontWeight: FontWeight.w700,
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
                  SizedBox(height: theme.spacing.md),
                  Wrap(
                    spacing: theme.spacing.sm,
                    runSpacing: theme.spacing.sm,
                    children: <Widget>[
                      for (final badge in badges) _ProfileBadge(label: badge),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        border: Border.all(color: colorScheme.outlineVariant),
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
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ProfileDetailList extends StatelessWidget {
  const _ProfileDetailList({required this.items});

  final List<_ProfileDetailItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final valueStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final label = Text(
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
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final useTwoColumns = constraints.maxWidth >= 920;
        final itemWidth = useTwoColumns
            ? (constraints.maxWidth - theme.spacing.lg) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: theme.spacing.lg,
          runSpacing: theme.spacing.lg,
          children: <Widget>[
            for (final section in sections)
              SizedBox(width: itemWidth, child: section),
          ],
        );
      },
    );
  }
}

String _value(String? value, AppLocalizations l10n) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty
      ? l10n.profileUnknownValue
      : normalized;
}

String? _formatProfileToken(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  final words = normalized
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) {
        final lower = word.toLowerCase();
        return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');

  return words.isEmpty ? null : words;
}
