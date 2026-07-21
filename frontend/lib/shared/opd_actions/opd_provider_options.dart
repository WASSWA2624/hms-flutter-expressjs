import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/shared/components/app_list_item_text.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';

const String opdUnknownProviderLabel = 'Assigned staff unknown';

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

/// Ensures the appointment's assigned provider appears in the selectable list.
List<OpdProviderOption> opdProvidersWithAssigned({
  required List<OpdProviderOption> providers,
  String? assignedProviderId,
  String? assignedProviderDisplayName,
  String? facilityId,
}) {
  final String id = (assignedProviderId ?? '').trim();
  if (id.isEmpty) {
    return providers;
  }
  if (_providersContainId(providers, id)) {
    return providers;
  }
  return <OpdProviderOption>[
    OpdProviderOption(
      id: id,
      displayName: assignedProviderDisplayName,
      facilityId: facilityId,
    ),
    ...providers,
  ];
}

/// Resolves [assignedProviderId] to a selectable option value when possible.
String? resolveOpdProviderSelection({
  required List<AppSelectOption<String>> options,
  required List<OpdProviderOption> providers,
  String? assignedProviderId,
  String? assignedProviderDisplayName,
}) {
  final String id = (assignedProviderId ?? '').trim();
  final String name = (assignedProviderDisplayName ?? '').trim();
  if (id.isEmpty && name.isEmpty) {
    return null;
  }

  if (id.isNotEmpty) {
    for (final AppSelectOption<String> option in options) {
      if (option.value.trim() == id) {
        return option.value;
      }
    }
  }

  for (final OpdProviderOption provider in providers) {
    final bool idMatch =
        id.isNotEmpty &&
        _providerKeys(provider).any(
          (String key) => key.trim().toUpperCase() == id.toUpperCase(),
        );
    final bool nameMatch =
        name.isNotEmpty &&
        (provider.displayName ?? '').trim().toUpperCase() == name.toUpperCase();
    if (!idMatch && !nameMatch) {
      continue;
    }
    for (final AppSelectOption<String> option in options) {
      if (option.value.trim() == provider.id.trim()) {
        return option.value;
      }
    }
  }

  if (name.isNotEmpty) {
    for (final AppSelectOption<String> option in options) {
      if (option.label.toUpperCase().contains(name.toUpperCase())) {
        return option.value;
      }
    }
  }

  return id.isEmpty ? null : id;
}

bool _providersContainId(List<OpdProviderOption> providers, String id) {
  final String needle = id.toUpperCase();
  for (final OpdProviderOption provider in providers) {
    if (_providerKeys(provider).any(
      (String key) => key.trim().toUpperCase() == needle,
    )) {
      return true;
    }
  }
  return false;
}

List<AppSelectOption<String>> opdProviderSelectOptions({
  required List<OpdProviderOption> providers,
  required List<OpdProviderSchedule> schedules,
  String unknownProviderLabel = opdUnknownProviderLabel,
}) {
  final Map<String, AppSelectOption<String>> options =
      <String, AppSelectOption<String>>{};
  final Set<String> seenKeys = <String>{};
  final Set<String> availableProviderIds = _scheduledProviderIds(schedules);
  final Map<String, OpdProviderSchedule> scheduleByProvider =
      _scheduleByProviderId(schedules);

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
    final bool isAvailable = _isProviderScheduled(
      value,
      provider.staffProfileId,
      availableProviderIds,
    );
    final OpdProviderSchedule? schedule = _matchingSchedule(
      value,
      provider.staffProfileId,
      scheduleByProvider,
    );
    final String roleSubtitle = _joinDisplay(<String?>[
      provider.positionTitle,
      provider.practitionerType,
    ]);
    final String subtitle = _buildAvailabilitySubtitle(
      roleSubtitle,
      isAvailable: isAvailable,
      schedule: schedule,
    );
    options[value] = AppSelectOption<String>(
      value: value,
      label: _joinDisplay(<String?>[title, subtitle]),
      leadingIcon: Icon(
        isAvailable
            ? Icons.event_available_outlined
            : Icons.person_search_outlined,
        color: isAvailable ? const Color(0xFF4CAF50) : null,
      ),
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
    final String scheduleSubtitle = _buildAvailabilitySubtitle(
      schedule.facilityName ?? '',
      isAvailable: true,
      schedule: schedule,
    );
    options[value] = AppSelectOption<String>(
      value: value,
      label: _joinDisplay(<String?>[title, scheduleSubtitle]),
      leadingIcon: const Icon(
        Icons.event_available_outlined,
        color: Color(0xFF4CAF50),
      ),
      labelWidget: AppListItemText(
        title: title,
        subtitle: scheduleSubtitle.isEmpty ? null : scheduleSubtitle,
      ),
    );
  }

  final List<AppSelectOption<String>> result = options.values.toList(
    growable: false,
  );
  if (availableProviderIds.isEmpty) {
    return result;
  }
  final List<AppSelectOption<String>> available = <AppSelectOption<String>>[];
  final List<AppSelectOption<String>> others = <AppSelectOption<String>>[];
  for (final AppSelectOption<String> option in result) {
    if (availableProviderIds.contains(option.value.trim().toUpperCase())) {
      available.add(option);
    } else {
      others.add(option);
    }
  }
  return <AppSelectOption<String>>[...available, ...others];
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

Set<String> _scheduledProviderIds(List<OpdProviderSchedule> schedules) {
  final Set<String> ids = <String>{};
  for (final OpdProviderSchedule schedule in schedules) {
    final String userId = (schedule.providerUserId ?? '').trim().toUpperCase();
    final String publicId = (schedule.providerPublicId ?? '')
        .trim()
        .toUpperCase();
    if (userId.isNotEmpty) ids.add(userId);
    if (publicId.isNotEmpty) ids.add(publicId);
  }
  return ids;
}

Map<String, OpdProviderSchedule> _scheduleByProviderId(
  List<OpdProviderSchedule> schedules,
) {
  final Map<String, OpdProviderSchedule> map = <String, OpdProviderSchedule>{};
  for (final OpdProviderSchedule schedule in schedules) {
    final String userId = (schedule.providerUserId ?? '').trim().toUpperCase();
    final String publicId = (schedule.providerPublicId ?? '')
        .trim()
        .toUpperCase();
    if (userId.isNotEmpty) map.putIfAbsent(userId, () => schedule);
    if (publicId.isNotEmpty) map.putIfAbsent(publicId, () => schedule);
  }
  return map;
}

bool _isProviderScheduled(
  String providerId,
  String? staffProfileId,
  Set<String> scheduledIds,
) {
  if (scheduledIds.isEmpty) return false;
  if (scheduledIds.contains(providerId.trim().toUpperCase())) return true;
  final String profileKey = (staffProfileId ?? '').trim().toUpperCase();
  return profileKey.isNotEmpty && scheduledIds.contains(profileKey);
}

OpdProviderSchedule? _matchingSchedule(
  String providerId,
  String? staffProfileId,
  Map<String, OpdProviderSchedule> scheduleByProvider,
) {
  if (scheduleByProvider.isEmpty) return null;
  final OpdProviderSchedule? byId =
      scheduleByProvider[providerId.trim().toUpperCase()];
  if (byId != null) return byId;
  final String profileKey = (staffProfileId ?? '').trim().toUpperCase();
  if (profileKey.isEmpty) return null;
  return scheduleByProvider[profileKey];
}

String _buildAvailabilitySubtitle(
  String baseSubtitle, {
  required bool isAvailable,
  OpdProviderSchedule? schedule,
}) {
  if (!isAvailable) return baseSubtitle;
  final String timeRange = _scheduleTimeRange(schedule);
  final String availabilityTag = timeRange.isNotEmpty
      ? 'Available $timeRange'
      : 'Available today';
  if (baseSubtitle.isEmpty) return availabilityTag;
  return '$baseSubtitle · $availabilityTag';
}

String _scheduleTimeRange(OpdProviderSchedule? schedule) {
  if (schedule == null) return '';
  final DateTime? start = schedule.startTime;
  final DateTime? end = schedule.endTime;
  if (start == null && end == null) return '';
  final String startLabel = start != null ? _formatTimeOfDay(start) : '';
  final String endLabel = end != null ? _formatTimeOfDay(end) : '';
  if (startLabel.isNotEmpty && endLabel.isNotEmpty) {
    return '$startLabel – $endLabel';
  }
  return startLabel.isNotEmpty ? 'from $startLabel' : 'until $endLabel';
}

String _formatTimeOfDay(DateTime dt) {
  final int hour = dt.hour;
  final int minute = dt.minute;
  final String period = hour >= 12 ? 'PM' : 'AM';
  final int displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  final String minuteStr = minute.toString().padLeft(2, '0');
  return '$displayHour:$minuteStr $period';
}
