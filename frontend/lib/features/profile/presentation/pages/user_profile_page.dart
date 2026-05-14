import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';

class UserProfilePage extends ConsumerWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(
      sessionStateProvider.select((state) => state.session),
    );
    final profile = session?.user ?? AuthUserProfile(email: session?.subject);

    if (session == null || profile.displayName == null) {
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

    return AppScreen(
      title: l10n.profileTitle,
      body: l10n.profileBody,
      maxWidth: PageMaxWidth.dashboard,
      children: <Widget>[
        _ProfileSummary(
          profile: profile,
          permissionCount: session.permissions.length,
        ),
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile, required this.permissionCount});

  final AuthUserProfile profile;
  final int permissionCount;

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
        final value = item.selectable
            ? SelectableText(item.value, style: valueStyle)
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
  });

  final String label;
  final String value;
  final bool selectable;
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
