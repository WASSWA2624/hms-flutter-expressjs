import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/facility_similarity.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

Future<bool> showFacilitySimilarityDialog(
  BuildContext context, {
  required List<FacilitySimilarityMatch> matches,
}) {
  final AppLocalizations l10n = context.l10n;

  return showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);

      return AppDialog(
        title: Text(l10n.tenantFacilitySimilarFacilityDialogTitle),
        icon: const Icon(Icons.warning_amber_outlined),
        scrollable: true,
        maxWidth: 640,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.tenantFacilitySimilarFacilityDialogBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: theme.spacing.md),
            for (final FacilitySimilarityMatch match in matches.take(5))
              _FacilitySimilarityLine(match: match),
          ],
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            leadingIcon: Icons.close,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton.primary(
            label: l10n.tenantFacilityProceedCreateFacilityAction,
            leadingIcon: Icons.local_hospital_outlined,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      );
    },
  ).then((bool? value) => value ?? false);
}

class FacilitySimilarityWarningPanel extends StatelessWidget {
  const FacilitySimilarityWarningPanel({required this.matches, super.key});

  final List<FacilitySimilarityMatch> matches;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormInformationBanner(
      title: l10n.tenantFacilitySimilarFacilityWarningTitle,
      message: l10n.tenantFacilitySimilarFacilityWarningBody,
      variant: AppFormInformationVariant.warning,
      icon: Icons.content_copy_outlined,
      children: <Widget>[
        for (final FacilitySimilarityMatch match in matches.take(3))
          _FacilitySimilarityLine(match: match),
      ],
    );
  }
}

class _FacilitySimilarityLine extends StatelessWidget {
  const _FacilitySimilarityLine({required this.match});

  final FacilitySimilarityMatch match;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(top: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.tenantFacilitySimilarFacilityScoreLabel(match.score)),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Text(_lineText(l10n), style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  String _lineText(AppLocalizations l10n) {
    final FacilityProfile facility = match.facility;
    final List<String> parts = <String>[
      facility.name,
      facility.isActive ? l10n.commonYesLabel : l10n.commonNoLabel,
      tenantFacilityFacilityTypeLabel(l10n, facility.type),
    ];

    return parts.where((String part) => part.trim().isNotEmpty).join(' • ');
  }
}
