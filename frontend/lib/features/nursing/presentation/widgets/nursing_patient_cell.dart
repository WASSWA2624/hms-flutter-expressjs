import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class NursingPatientCell extends StatelessWidget {
  const NursingPatientCell({required this.item, super.key});

  final NursingPatientSummary item;

  @override
  Widget build(BuildContext context) {
    return AppListItemText(title: item.displayTitle);
  }
}
