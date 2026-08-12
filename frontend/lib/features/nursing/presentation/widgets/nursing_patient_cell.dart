import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';

class NursingPatientCell extends StatelessWidget {
  const NursingPatientCell({required this.item, super.key});

  final NursingPatientSummary item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // tables.mdc: no strong/bold weight in table row cells.
          style: theme.textTheme.bodyMedium,
        ),
        if (nursingJoinDisplay(<String?>[
          item.patientDisplayId,
          item.encounterDisplayId,
          item.displayId,
        ]).isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            nursingJoinDisplay(<String?>[
              item.patientDisplayId,
              item.encounterDisplayId,
              item.displayId,
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
