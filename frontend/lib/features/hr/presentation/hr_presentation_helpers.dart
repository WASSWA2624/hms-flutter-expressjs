import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

export 'package:hosspi_hms/features/hr/presentation/hr_access.dart';

/// Reads the current HR workspace state when the controller has loaded successfully.
HrWorkspaceState? readHrWorkspaceState(WidgetRef ref) {
  return ref
      .read(hrWorkspaceControllerProvider)
      .asData
      ?.value
      .when(success: (HrWorkspaceState state) => state, failure: (_) => null);
}

List<AppSelectOption<String>> hrSelectOptions(List<HrOption> options) {
  return <AppSelectOption<String>>[
    for (final HrOption option in options)
      AppSelectOption<String>(value: option.value, label: option.label),
  ];
}

/// Maps a stored UUID or display id onto the matching [HrOption.value].
///
/// Reference-data options typically use the human-friendly id as [HrOption.value]
/// and stash the UUID in `extra['entity_id']`. Callers that prefill from raw
/// `department_id` / `unit_id` UUIDs should resolve through this helper so the
/// select field does not orphan-inject a duplicate labeled option.
String? resolveHrOptionValue({
  required List<HrOption> options,
  required Iterable<String?> candidates,
}) {
  final List<String> needles = <String>[
    for (final String? candidate in candidates)
      if ((candidate ?? '').trim().isNotEmpty) candidate!.trim(),
  ];
  if (needles.isEmpty) {
    return null;
  }

  for (final String needle in needles) {
    for (final HrOption option in options) {
      final String extraId =
          (option.extra['entity_id'] ?? option.extra['id'] ?? '')
              .toString()
              .trim();
      if (option.value == needle ||
          (option.displayId?.trim() == needle) ||
          (extraId.isNotEmpty && extraId == needle)) {
        return option.value;
      }
    }
  }
  return null;
}

/// Entity UUID for a department option value (friendly id or UUID).
String? hrOptionEntityId(List<HrOption> options, String? optionValue) {
  final String selected = optionValue?.trim() ?? '';
  if (selected.isEmpty) {
    return null;
  }
  for (final HrOption option in options) {
    final String extraId =
        (option.extra['entity_id'] ?? option.extra['id'] ?? '')
            .toString()
            .trim();
    if (option.value == selected ||
        (option.displayId?.trim() == selected) ||
        (extraId.isNotEmpty && extraId == selected)) {
      if (extraId.isNotEmpty) {
        return extraId;
      }
      return option.value;
    }
  }
  return selected;
}

List<AppSelectOption<String>> hrLocalizedSelectOptions(
  AppLocalizations l10n,
  List<HrOption> options,
) {
  return <AppSelectOption<String>>[
    for (final HrOption option in options)
      AppSelectOption<String>(
        value: option.value,
        label: l10n.hrLocalizedOptionLabel(option),
      ),
  ];
}

void showHrMutationSnackBar(BuildContext context, AppFailure? failure) {
  if (!context.mounted) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null ? l10n.hrSavedMessage : l10n.failureMessage(failure),
      ),
    ),
  );
}
