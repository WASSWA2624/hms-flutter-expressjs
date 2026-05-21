import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/shared/components/app_list_item_text.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';

const String opdUnknownProviderLabel = 'Unknown provider';

List<OpdProviderOption> dedupeOpdProviderOptions(
  Iterable<OpdProviderOption> providers,
) {
  final Map<String, OpdProviderOption> byKey = <String, OpdProviderOption>{};
  final List<OpdProviderOption> unique = <OpdProviderOption>[];

  for (final OpdProviderOption provider in providers) {
    final List<String> keys = _providerKeys(provider).toList(growable: false);
    if (keys.isEmpty) {
      unique.add(provider);
      continue;
    }
    final bool exists = keys.any(byKey.containsKey);
    if (exists) {
      continue;
    }
    unique.add(provider);
    for (final String key in keys) {
      byKey[key] = provider;
    }
  }

  return unique;
}

List<AppSelectOption<String>> opdProviderSelectOptions({
  required List<OpdProviderOption> providers,
  required List<OpdProviderSchedule> schedules,
  String unknownProviderLabel = opdUnknownProviderLabel,
}) {
  final Map<String, AppSelectOption<String>> options =
      <String, AppSelectOption<String>>{};
  final Set<String> seenKeys = <String>{};

  bool addKeys(Iterable<String> keys) {
    final List<String> normalized = keys
        .map(_normalizeProviderKey)
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    if (normalized.any(seenKeys.contains)) {
      return false;
    }
    seenKeys.addAll(normalized);
    return true;
  }

  for (final OpdProviderOption provider in dedupeOpdProviderOptions(
    providers,
  )) {
    final String value = provider.id.trim();
    if (value.isEmpty || options.containsKey(value)) {
      continue;
    }
    final String title = opdProviderTitle(provider, unknownProviderLabel);
    if (!addKeys(<String>[
      value,
      provider.displayName ?? '',
      provider.email ?? '',
      provider.phone ?? '',
      provider.staffProfileId ?? '',
      title,
    ])) {
      continue;
    }
    final String subtitle = _joinDisplay(<String?>[
      provider.positionTitle,
      provider.practitionerType,
    ]);
    options[value] = AppSelectOption<String>(
      value: value,
      label: _joinDisplay(<String?>[title, subtitle]),
      leadingIcon: const Icon(Icons.person_search_outlined),
      labelWidget: AppListItemText(
        title: title,
        subtitle: subtitle.isEmpty ? null : subtitle,
      ),
    );
  }

  for (final OpdProviderSchedule schedule in schedules) {
    final String value = schedule.providerApiId.trim();
    if (value.isEmpty || options.containsKey(value)) {
      continue;
    }
    final String title = _firstNonEmpty(<String?>[
      schedule.providerDisplayName,
      unknownProviderLabel,
    ])!;
    if (!addKeys(<String>[
      value,
      schedule.providerUserId ?? '',
      schedule.providerPublicId ?? '',
      schedule.providerDisplayName ?? '',
      title,
    ])) {
      continue;
    }
    options[value] = AppSelectOption<String>(
      value: value,
      label: _joinDisplay(<String?>[title, schedule.facilityName]),
      leadingIcon: const Icon(Icons.person_search_outlined),
      labelWidget: AppListItemText(
        title: title,
        subtitle: schedule.facilityName,
      ),
    );
  }

  return options.values.toList(growable: false);
}

String opdProviderTitle(
  OpdProviderOption provider, [
  String unknownProviderLabel = opdUnknownProviderLabel,
]) {
  return _firstNonEmpty(<String?>[provider.displayName, unknownProviderLabel])!;
}

Iterable<String> _providerKeys(OpdProviderOption provider) sync* {
  yield provider.id;
  if (provider.displayName case final String displayName) {
    yield displayName;
  }
  if (provider.email case final String email) {
    yield email;
  }
  if (provider.phone case final String phone) {
    yield phone;
  }
  if (provider.staffProfileId case final String staffProfileId) {
    yield staffProfileId;
  }
}

String _normalizeProviderKey(String value) {
  return value.trim().toUpperCase();
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final String? value in values) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}

String _joinDisplay(Iterable<String?> values) {
  return AppDisplay.joinNonEmpty(values, separator: ' | ');
}
