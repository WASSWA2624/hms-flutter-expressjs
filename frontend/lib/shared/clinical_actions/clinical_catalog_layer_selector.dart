import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_models.dart';

class ClinicalCatalogLayerSelector extends StatelessWidget {
  const ClinicalCatalogLayerSelector({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final ClinicalCatalogSource value;
  final ValueChanged<ClinicalCatalogSource> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Wrap(
      spacing: theme.spacing.xs,
      runSpacing: theme.spacing.xs,
      children: <Widget>[
        for (final ClinicalCatalogSource source in ClinicalCatalogSource.values)
          FilterChip(
            label: Text(_labelForSource(l10n, source)),
            selected: value == source,
            onSelected: enabled
                ? (bool selected) {
                    if (selected) {
                      onChanged(source);
                    }
                  }
                : null,
          ),
      ],
    );
  }

  String _labelForSource(AppLocalizations l10n, ClinicalCatalogSource source) {
    return switch (source) {
      ClinicalCatalogSource.all => l10n.clinicalCatalogSourceAll,
      ClinicalCatalogSource.favorites => l10n.clinicalCatalogSourceFavorites,
      ClinicalCatalogSource.facility => l10n.clinicalCatalogSourceFacility,
      ClinicalCatalogSource.global => l10n.clinicalCatalogSourceGlobal,
    };
  }
}
