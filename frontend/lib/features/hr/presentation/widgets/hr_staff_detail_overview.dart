import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_info_sheet.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

class HrStaffDetailOverview extends StatelessWidget {
  const HrStaffDetailOverview({required this.profile, super.key});

  final HrStaffProfile profile;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String emptyValue = l10n.profileUnknownValue;
    final bool hasLinkedUser = _hasLinkedUser(profile);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppWorkspaceDetailPanel(
          title: l10n.hrStaffOverviewSectionTitle,
          child: AppInfoSheetGrid(
            emptyValue: emptyValue,
            spacing: theme.spacing.lg,
            runSpacing: theme.spacing.sm,
            items: _overviewItems(l10n, context, emptyValue),
          ),
        ),
        if (hasLinkedUser) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppWorkspaceDetailPanel(
            title: l10n.hrLinkedUserLabel,
            titleIcon: Icons.link_outlined,
            child: AppInfoSheetGrid(
              emptyValue: emptyValue,
              spacing: theme.spacing.lg,
              runSpacing: theme.spacing.sm,
              items: _linkedUserItems(l10n, emptyValue),
            ),
          ),
        ],
      ],
    );
  }

  List<AppInfoSheetItem> _overviewItems(
    AppLocalizations l10n,
    BuildContext context,
    String emptyValue,
  ) {
    return <AppInfoSheetItem>[
      AppInfoSheetItem(
        label: l10n.hrStaffNumberLabel,
        value: profile.staffNumber ?? profile.displayId,
        copyable: true,
      ),
      if ((profile.position ?? '').trim().isNotEmpty)
        AppInfoSheetItem(label: l10n.hrPositionLabel, value: profile.position),
      if ((profile.practitionerType ?? '').trim().isNotEmpty)
        AppInfoSheetItem(
          label: l10n.hrPractitionerTypeLabel,
          value: context.l10n.hrReferencePractitionerTypeLabel(
            profile.practitionerType,
            fallback: profile.practitionerType,
          ),
        ),
      AppInfoSheetItem(
        label: l10n.hrDepartmentLabel,
        value: profile.departmentName ?? profile.departmentDisplayId,
      ),
      AppInfoSheetItem(
        label: l10n.hrHireDateLabel,
        value: _formatDate(context, profile.hireDate),
      ),
    ];
  }

  List<AppInfoSheetItem> _linkedUserItems(
    AppLocalizations l10n,
    String emptyValue,
  ) {
    return <AppInfoSheetItem>[
      if ((profile.userEmail ?? '').trim().isNotEmpty)
        AppInfoSheetItem(label: l10n.hrEmailLabel, value: profile.userEmail),
      if ((profile.userDisplayId ?? profile.userId ?? '').trim().isNotEmpty)
        AppInfoSheetItem(
          label: l10n.hrUserIdLabel,
          value: profile.userDisplayId ?? profile.userId,
          copyable: true,
        ),
    ];
  }
}

bool _hasLinkedUser(HrStaffProfile profile) {
  return (profile.userEmail ?? profile.userDisplayId ?? profile.userId ?? '')
      .trim()
      .isNotEmpty;
}

String _formatDate(BuildContext context, DateTime? value) {
  return value == null
      ? ''
      : AppFormatters.mediumDate(value, Localizations.localeOf(context));
}
