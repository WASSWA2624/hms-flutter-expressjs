import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class IcuPatientCell extends StatelessWidget {
  const IcuPatientCell({required this.item, super.key});

  final IcuPatientSummary item;

  @override
  Widget build(BuildContext context) {
    return AppListItemText(title: item.displayTitle);
  }
}
