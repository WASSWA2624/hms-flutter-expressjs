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
      itemLeadingIcon: Icons.history_outlined,
      itemTitle: (PatientTimelineItem item) =>
          item.title ?? AppDisplay.apiLabel(item.resource),
      itemSubtitle: (PatientTimelineItem item) => _joinDisplay(<String?>[
        AppDisplay.apiLabel(item.resource),
        _formatOptionalDateTime(context, item.occurredAt),
      ]),
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
