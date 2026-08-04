import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/patient_registry_access.dart';
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
    this.applyAdmittedNestedReadFilter = false,
    super.key,
  });

  final PatientDetail detail;
  final PatientActiveWorkAction onContinue;

  /// When true (Admitted tab detail), strip clinical/billing Active Work
  /// bodies unless ∪ `clinical:read` | `billing:read` is granted.
  final bool applyAdmittedNestedReadFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<PatientActiveWorkItem> items = collectPatientActiveWorkItems(detail);
    if (applyAdmittedNestedReadFilter) {
      items = filterPatientActiveWorkForAdmittedNestedRead(
        items,
        ref.watch(appAccessPolicyProvider),
      );
    }
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return AppCollapsibleSection(
      title: l10n.patientsActiveWorkTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final PatientActiveWorkItem item in items)
            Padding(
              padding: EdgeInsets.only(bottom: theme.spacing.xs),
              child: _PatientActiveWorkRow(
                item: item,
                onContinue: () => onContinue(item),
              ),
            ),
        ],
      ),
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
    final String kindLabel = patientActiveWorkKindLabel(l10n, item);
    final String statusLabel = patientActiveWorkStatusLabel(l10n, item);
    final String nextStepLabel = patientActiveWorkNextStepLabel(l10n, item);
    final String actionLabel = patientActiveWorkActionLabel(l10n, item);
    final String contextLabel = patientActiveWorkContextLabel(item);
    final AppWorkspaceStatusTone statusTone = patientActiveWorkStatusTone(item);
    final String when = item.occurredAt == null
        ? ''
        : AppFormatters.dateTime(
            item.occurredAt!,
            Localizations.localeOf(context),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: theme.borders.all(),
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
                  Text(
                    kindLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (contextLabel.isNotEmpty) ...<Widget>[
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      contextLabel,
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
                  if (statusLabel.isNotEmpty) ...<Widget>[
                    SizedBox(height: theme.spacing.xs),
                    Wrap(
                      spacing: theme.spacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          '${l10n.patientsActiveWorkCurrentStatusLabel}:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        AppStatusText(label: statusLabel, tone: statusTone),
                      ],
                    ),
                  ],
                  SizedBox(height: theme.spacing.xs),
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: '${l10n.patientsActiveWorkNextStepLabel}: ',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        TextSpan(text: nextStepLabel),
                      ],
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AppAccessActionGate(
              requirement: patientActiveWorkContinueRequirement(item.kind),
              builder: (_, bool isAllowed) {
                if (!isAllowed) {
                  return const SizedBox.shrink();
                }
                return AppButton.secondary(
                  label: actionLabel,
                  leadingIcon: Icons.play_arrow_outlined,
                  tooltip: actionLabel,
                  onPressed: onContinue,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
