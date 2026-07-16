import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';

const String icuBoardAlertFilterKey = 'alert';
const String icuBoardBedFilterKey = 'bed';
const String icuBoardSourceFilterKey = 'source';

const String icuBoardAlertHasValue = 'has_alert';
const String icuBoardAlertNoValue = 'no_alert';
const String icuBoardBedHasValue = 'has_bed';
const String icuBoardBedNoValue = 'no_bed';
const String icuBoardSourceEmergencyValue = 'emergency';
const String icuBoardSourceOtherValue = 'other';

List<AppSearchBarFilterGroup> icuBoardFilterGroups(AppLocalizations l10n) {
  return <AppSearchBarFilterGroup>[
    AppSearchBarFilterGroup(
      key: icuBoardAlertFilterKey,
      label: l10n.icuColumnAlertLabel,
      allLabel: l10n.opdAllFieldsFilterLabel,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: icuBoardAlertHasValue,
          label: l10n.icuBoardFilterHasAlertLabel,
          icon: Icons.notification_important_outlined,
        ),
        AppSearchBarFilterChoice(
          value: icuBoardAlertNoValue,
          label: l10n.icuBoardFilterNoAlertLabel,
          icon: Icons.check_circle_outline,
        ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: icuBoardBedFilterKey,
      label: l10n.icuColumnBedLabel,
      allLabel: l10n.opdAllFieldsFilterLabel,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: icuBoardBedHasValue,
          label: l10n.icuBoardFilterHasBedLabel,
          icon: Icons.bed_outlined,
        ),
        AppSearchBarFilterChoice(
          value: icuBoardBedNoValue,
          label: l10n.icuBoardFilterNoBedLabel,
          icon: Icons.bed_outlined,
        ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: icuBoardSourceFilterKey,
      label: l10n.icuColumnSourceLabel,
      allLabel: l10n.opdAllFieldsFilterLabel,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: icuBoardSourceEmergencyValue,
          label: l10n.icuBoardFilterEmergencySourceLabel,
          icon: Icons.emergency_outlined,
        ),
        AppSearchBarFilterChoice(
          value: icuBoardSourceOtherValue,
          label: l10n.icuBoardFilterOtherSourceLabel,
          icon: Icons.alt_route_outlined,
        ),
      ],
    ),
  ];
}

List<IcuPatientSummary> filterIcuBoardItems(
  List<IcuPatientSummary> items,
  AppSearchBarFilterValue filterValue,
) {
  if (!filterValue.isActive) {
    return items;
  }

  final String? alert = filterValue.option(icuBoardAlertFilterKey);
  final String? bed = filterValue.option(icuBoardBedFilterKey);
  final String? source = filterValue.option(icuBoardSourceFilterKey);

  return items
      .where((IcuPatientSummary item) {
        if (alert == icuBoardAlertHasValue && !item.hasCriticalAlert) {
          return false;
        }
        if (alert == icuBoardAlertNoValue && item.hasCriticalAlert) {
          return false;
        }
        if (bed == icuBoardBedHasValue && !item.hasActiveBed) {
          return false;
        }
        if (bed == icuBoardBedNoValue && item.hasActiveBed) {
          return false;
        }
        if (source == icuBoardSourceEmergencyValue &&
            !item.sourceLabel.toUpperCase().contains('EMERGENCY')) {
          return false;
        }
        if (source == icuBoardSourceOtherValue &&
            item.sourceLabel.toUpperCase().contains('EMERGENCY')) {
          return false;
        }
        return true;
      })
      .toList(growable: false);
}

AppPage<IcuPatientSummary> icuBoardDisplayPage(
  AppPage<IcuPatientSummary> page,
  AppSearchBarFilterValue filterValue,
) {
  final List<IcuPatientSummary> filteredItems = filterIcuBoardItems(
    page.items,
    filterValue,
  );
  return AppPage<IcuPatientSummary>(
    items: filteredItems,
    request: page.request,
    totalItemCount: filterValue.isActive
        ? filteredItems.length
        : page.totalItemCount,
  );
}
