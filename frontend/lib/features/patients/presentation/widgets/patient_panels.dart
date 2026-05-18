import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

class PatientInlineFormError extends StatelessWidget {
  const PatientInlineFormError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppMessagePanel(
      message: message,
      tone: AppWorkspaceStatusTone.error,
      density: AppContentPanelDensity.compact,
    );
  }
}

class PatientRelatedSection<T> extends StatelessWidget {
  const PatientRelatedSection({
    required this.title,
    required this.emptyLabel,
    required this.items,
    required this.resource,
    required this.itemTitle,
    required this.itemSubtitle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final String title;
  final String emptyLabel;
  final List<T> items;
  final PatientRelatedResource resource;
  final String Function(T item) itemTitle;
  final String Function(T item) itemSubtitle;
  final VoidCallback onAdd;
  final ValueChanged<T> onEdit;
  final ValueChanged<T> onDelete;

  static const AccessRequirement _writeRequirement = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.patientWrite],
  );
  static const AccessRequirement _deleteRequirement = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.patientDelete],
  );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.only(bottom: theme.spacing.sm),
      title: Text(title, style: theme.textTheme.titleSmall),
      trailing: AppAccessActionGate(
        requirement: _writeRequirement,
        builder: (_, bool isAllowed) => AppIconButton(
          icon: Icons.add,
          semanticLabel: l10n.patientsAddRelatedAction,
          tooltip: l10n.patientsAddRelatedAction,
          onPressed: isAllowed ? onAdd : null,
        ),
      ),
      children: <Widget>[
        if (items.isEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              emptyLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final T item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(itemTitle(item)),
              subtitle: Text(itemSubtitle(item)),
              trailing: Wrap(
                children: <Widget>[
                  AppAccessActionGate(
                    requirement: _writeRequirement,
                    builder: (_, bool isAllowed) => AppIconButton(
                      icon: Icons.edit_outlined,
                      semanticLabel: l10n.patientsEditAction,
                      tooltip: l10n.patientsEditAction,
                      onPressed: isAllowed ? () => onEdit(item) : null,
                    ),
                  ),
                  AppAccessActionGate(
                    requirement: _deleteRequirement,
                    builder: (_, bool isAllowed) => AppIconButton(
                      icon: Icons.delete_outline,
                      semanticLabel: l10n.patientsDeleteAction,
                      tooltip: l10n.patientsDeleteAction,
                      onPressed: isAllowed ? () => onDelete(item) : null,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class PatientTimelineList extends StatelessWidget {
  const PatientTimelineList({required this.items, super.key});

  final List<PatientTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        l10n.patientsTimelineSectionTitle,
        style: theme.textTheme.titleSmall,
      ),
      children: <Widget>[
        if (items.isEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(l10n.patientsNoTimeline),
          )
        else
          for (final PatientTimelineItem item in items.take(8))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_outlined),
              title: Text(item.title ?? AppDisplay.apiLabel(item.resource)),
              subtitle: Text(
                _joinDisplay(<String?>[
                  AppDisplay.apiLabel(item.resource),
                  _formatOptionalDateTime(context, item.occurredAt),
                ]),
              ),
            ),
      ],
    );
  }
}

String _formatOptionalDateTime(BuildContext context, DateTime? value) {
  return value == null
      ? ''
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String _joinDisplay(Iterable<String?> values) {
  return AppDisplay.joinNonEmpty(values);
}
