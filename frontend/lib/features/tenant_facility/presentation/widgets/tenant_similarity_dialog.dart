import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

Future<bool> showTenantSimilarityDialog(
  BuildContext context, {
  required List<TenantSimilarityMatch> matches,
}) {
  final AppLocalizations l10n = context.l10n;

  return showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);

      return AppDialog(
        title: Text(l10n.tenantFacilitySimilarTenantDialogTitle),
        icon: const Icon(Icons.warning_amber_outlined),
        scrollable: true,
        maxWidth: 640,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.tenantFacilitySimilarTenantDialogBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: theme.spacing.md),
            for (final TenantSimilarityMatch match in matches.take(5))
              _TenantSimilarityLine(match: match),
          ],
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            leadingIcon: Icons.close,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton.primary(
            label: l10n.tenantFacilityProceedCreateTenantAction,
            leadingIcon: Icons.add_business_outlined,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      );
    },
  ).then((bool? value) => value ?? false);
}

class TenantSimilarityWarningPanel extends StatelessWidget {
  const TenantSimilarityWarningPanel({required this.matches, super.key});

  final List<TenantSimilarityMatch> matches;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormInformationBanner(
      title: l10n.tenantFacilitySimilarTenantWarningTitle,
      message: l10n.tenantFacilitySimilarTenantWarningBody,
      variant: AppFormInformationVariant.warning,
      icon: Icons.content_copy_outlined,
      children: <Widget>[
        for (final TenantSimilarityMatch match in matches.take(3))
          _TenantSimilarityLine(match: match),
      ],
    );
  }
}

class _TenantSimilarityLine extends StatelessWidget {
  const _TenantSimilarityLine({required this.match});

  final TenantSimilarityMatch match;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(top: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.tenantFacilitySimilarTenantScoreLabel(match.score)),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Text(_lineText(l10n), style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  String _lineText(AppLocalizations l10n) {
    final List<String> parts = <String>[
      match.tenant.name,
      if (match.tenant.slug != null && match.tenant.slug!.isNotEmpty)
        match.tenant.slug!,
      match.tenant.isActive ? l10n.commonYesLabel : l10n.commonNoLabel,
      match.reasons.map(AppDisplay.apiLabel).join(', '),
    ];

    return parts.where((String part) => part.trim().isNotEmpty).join(' • ');
  }
}
