import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_catalog_similarity.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum RadiologyCatalogSimilarityAction { cancel, useExisting, proceed }

Future<RadiologyCatalogSimilarityAction> showRadiologyCatalogSimilarityDialog(
  BuildContext context, {
  required List<RadiologyCatalogSimilarityMatch> matches,
}) {
  final AppLocalizations l10n = context.l10n;

  return showAppDialog<RadiologyCatalogSimilarityAction>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);

      return AppDialog(
        title: Text(l10n.radiologySimilarImagingTestDialogTitle),
        icon: const Icon(Icons.warning_amber_outlined),
        scrollable: true,
        maxWidth: 640,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.radiologySimilarImagingTestDialogBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: theme.spacing.md),
            for (final RadiologyCatalogSimilarityMatch match
                in matches.take(5))
              _RadiologyCatalogSimilarityLine(match: match),
          ],
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            leadingIcon: Icons.close,
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(RadiologyCatalogSimilarityAction.cancel),
          ),
          AppButton.secondary(
            label: l10n.radiologyUseExistingImagingTestAction,
            leadingIcon: Icons.content_copy_outlined,
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(RadiologyCatalogSimilarityAction.useExisting),
          ),
          AppButton.primary(
            label: l10n.radiologyProceedCreateImagingTestAction,
            leadingIcon: Icons.add_circle_outline,
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(RadiologyCatalogSimilarityAction.proceed),
          ),
        ],
      );
    },
  ).then(
    (RadiologyCatalogSimilarityAction? value) =>
        value ?? RadiologyCatalogSimilarityAction.cancel,
  );
}

class _RadiologyCatalogSimilarityLine extends StatelessWidget {
  const _RadiologyCatalogSimilarityLine({required this.match});

  final RadiologyCatalogSimilarityMatch match;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(top: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.radiologySimilarImagingTestScoreLabel(match.score)),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Text(_lineText(l10n), style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  String _lineText(AppLocalizations l10n) {
    final RadiologyCatalogTest test = match.test;
    final List<String> parts = <String>[
      test.name,
      if (test.code != null && test.code!.trim().isNotEmpty) test.code!,
      if (test.modality != null && test.modality!.trim().isNotEmpty)
        test.modality!,
      if (test.isStandard) l10n.radiologyStandardCatalogBadge,
      match.reasons.map(AppDisplay.apiLabel).join(', '),
    ];

    return parts.where((String part) => part.trim().isNotEmpty).join(' • ');
  }
}
