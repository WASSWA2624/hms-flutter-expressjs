import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class PatientTimelineList extends StatelessWidget {
  const PatientTimelineList({required this.items, super.key});

  final List<PatientTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppTimeline(
      title: l10n.patientsTimelineSectionTitle,
      emptyTitle: l10n.patientsNoTimeline,
      maxItems: 8,
      items: <AppTimelineItem>[
        for (final PatientTimelineItem item in items)
          AppTimelineItem(
            title: item.title ?? AppDisplay.apiLabel(item.resource),
            occurredAt: item.occurredAt,
            description: item.subtitle == null || item.subtitle!.trim().isEmpty
                ? null
                : AppDisplay.apiLabel(item.subtitle!),
            icon: Icons.history_outlined,
          ),
      ],
    );
  }
}
