import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class PatientTimelineList extends StatelessWidget {
  const PatientTimelineList({required this.items, super.key});

  final List<PatientTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppExpandableRecordSection<PatientTimelineItem>(
      title: l10n.patientsTimelineSectionTitle,
      emptyLabel: l10n.patientsNoTimeline,
      items: items,
      maxItems: 8,
      initiallyExpanded: true,
      itemLeadingIcon: Icons.history_outlined,
      itemTitle: (PatientTimelineItem item) {
        final String label = item.title ?? AppDisplay.apiLabel(item.resource);
        final String when = _formatOptionalDateTime(context, item.occurredAt);
        if (item.subtitle != null && item.subtitle!.trim().isNotEmpty) {
          return '${AppDisplay.apiLabel(item.subtitle!)}: $label';
        }
        return when.isEmpty ? label : '$label: $when';
      },
    );
  }
}

String _formatOptionalDateTime(BuildContext context, DateTime? value) {
  return value == null
      ? ''
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}
