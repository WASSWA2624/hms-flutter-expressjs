import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_active_work_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

typedef PatientActiveWorkAction =
    Future<void> Function(PatientActiveWorkItem item);

class PatientDetailActiveWorkPanel extends ConsumerWidget {
  const PatientDetailActiveWorkPanel({
    required this.detail,
    required this.onContinue,
    super.key,
  });

  final PatientDetail detail;
  final PatientActiveWorkAction onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<PatientActiveWorkItem> items = collectPatientActiveWorkItems(
      detail,
    );
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.patientsActiveWorkTitle, style: theme.textTheme.titleSmall),
        SizedBox(height: theme.spacing.sm),
        for (final PatientActiveWorkItem item in items)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.xs),
            child: _PatientActiveWorkRow(
              item: item,
              onContinue: () => onContinue(item),
            ),
          ),
      ],
    );
  }
}

class _PatientActiveWorkRow extends StatelessWidget {
  const _PatientActiveWorkRow({required this.item, required this.onContinue});

  final PatientActiveWorkItem item;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final String statusLabel = AppDisplay.apiLabel(item.status);
    final String when = item.occurredAt == null
        ? ''
        : AppFormatters.dateTime(
            item.occurredAt!,
            Localizations.localeOf(context),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: theme.spacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      if (statusLabel.isNotEmpty)
                        AppStatusText(
                          label: statusLabel,
                          tone: AppWorkspaceStatusTone.info,
                        ),
                      Text(
                        item.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (item.subtitle != null &&
                      item.subtitle!.trim().isNotEmpty) ...<Widget>[
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      item.subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (when.isNotEmpty) ...<Widget>[
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      when,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            AppButton.secondary(
              label: l10n.patientsActiveWorkContinueAction,
              leadingIcon: Icons.play_arrow_outlined,
              onPressed: onContinue,
            ),
          ],
        ),
      ),
    );
  }
}
