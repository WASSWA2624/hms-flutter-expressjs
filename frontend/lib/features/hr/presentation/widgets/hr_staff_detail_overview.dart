import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_info_sheet.dart';

class HrStaffDetailOverview extends StatelessWidget {
  const HrStaffDetailOverview({required this.profile, super.key});

  final HrStaffProfile profile;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String emptyValue = l10n.profileUnknownValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.hrStaffOverviewSectionTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        AppInfoSheetGrid(
          emptyValue: emptyValue,
          items: <AppInfoSheetItem>[
            AppInfoSheetItem(
              label: l10n.hrStaffNumberLabel,
              value: profile.staffNumber ?? profile.displayId,
              copyable: true,
            ),
            if ((profile.position ?? '').trim().isNotEmpty)
              AppInfoSheetItem(
                label: l10n.hrPositionLabel,
                value: profile.position,
              ),
            if ((profile.practitionerType ?? '').trim().isNotEmpty)
              AppInfoSheetItem(
                label: l10n.hrPractitionerTypeLabel,
                value: _apiLabel(profile.practitionerType),
              ),
            AppInfoSheetItem(
              label: l10n.hrDepartmentLabel,
              value: profile.departmentName ?? profile.departmentDisplayId,
            ),
            AppInfoSheetItem(
              label: l10n.hrHireDateLabel,
              value: _formatDate(context, profile.hireDate),
            ),
          ],
        ),
        if (_hasLinkedUser(profile)) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          _LinkedUserSheet(profile: profile, emptyValue: emptyValue),
        ],
      ],
    );
  }
}

class _LinkedUserSheet extends StatelessWidget {
  const _LinkedUserSheet({required this.profile, required this.emptyValue});

  final HrStaffProfile profile;
  final String emptyValue;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.link_outlined,
              size: theme.appTokens.listIconSize,
              color: colorScheme.primary,
            ),
            SizedBox(width: theme.spacing.xs),
            Text(
              l10n.hrLinkedUserLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.sm),
        AppInfoSheetGrid(
          emptyValue: emptyValue,
          maxColumns: 2,
          minItemWidth: 200,
          items: <AppInfoSheetItem>[
            if ((profile.userFullName ?? '').trim().isNotEmpty)
              AppInfoSheetItem(
                label: l10n.hrStaffNameLabel,
                value: profile.userFullName,
              ),
            if ((profile.userEmail ?? '').trim().isNotEmpty)
              AppInfoSheetItem(
                label: l10n.hrEmailLabel,
                value: profile.userEmail,
              ),
            if ((profile.userDisplayId ?? profile.userId ?? '').trim().isNotEmpty)
              AppInfoSheetItem(
                label: l10n.hrUserIdLabel,
                value: profile.userDisplayId ?? profile.userId,
                copyable: true,
              ),
          ],
        ),
      ],
    );
  }
}

bool _hasLinkedUser(HrStaffProfile profile) {
  return (profile.userFullName ?? profile.userEmail ?? profile.userDisplayId ??
          profile.userId ??
          '')
      .trim()
      .isNotEmpty;
}

String _apiLabel(String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return lower.substring(0, 1).toUpperCase() + lower.substring(1);
      })
      .join(' ');
}

String _formatDate(BuildContext context, DateTime? value) {
  return value == null
      ? ''
      : AppFormatters.mediumDate(value, Localizations.localeOf(context));
}
