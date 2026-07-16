import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/housekeeping/domain/entities/housekeeping_entities.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/controllers/housekeeping_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Opens the operational maintenance triage dialog for a housekeeping request.
///
/// Returns after the dialog closes. On persisted success, the housekeeping
/// worklist and selected detail are patched by the workspace controller.
Future<void> showHousekeepingTriageDialog(
  BuildContext context,
  WidgetRef ref,
  HousekeepingWorkItem item,
) async {
  if (!item.isMaintenanceRequest || item.isTerminal) {
    return;
  }

  final AppLocalizations l10n = context.l10n;
  final GlobalKey<_HousekeepingTriageFormState> fieldsKey =
      GlobalKey<_HousekeepingTriageFormState>();

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.housekeepingTriageDialogTitle),
    icon: const Icon(AppActionIcons.triage),
    cancelLabel: l10n.commonCancelActionLabel,
    cancelIcon: AppActionIcons.cancel,
    submitLabel: l10n.housekeepingTriageSubmitAction,
    submitIcon: AppActionIcons.triage,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool isSubmitting, [
          AppFailure? failure,
        ]) {
          return HousekeepingTriageForm(
            key: fieldsKey,
            item: item,
            enabled: !isSubmitting,
          );
        },
    onSubmit: () {
      final _HousekeepingTriageFormState? fields = fieldsKey.currentState;
      if (fields == null) {
        return Future<AppFailure?>.value(const AppFailure.unexpected());
      }
      final String? validationError = fields.validate(context.l10n);
      if (validationError != null) {
        return Future<AppFailure?>.value(
          AppFailure.validation(detailMessage: validationError),
        );
      }
      return ref
          .read(housekeepingWorkspaceControllerProvider.notifier)
          .triageMaintenanceRequest(item, fields.toDraft());
    },
  );

  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.housekeepingSavedMessage)),
    );
  }
}

class HousekeepingTriageForm extends StatefulWidget {
  const HousekeepingTriageForm({
    required this.item,
    this.enabled = true,
    super.key,
  });

  final HousekeepingWorkItem item;
  final bool enabled;

  @override
  State<HousekeepingTriageForm> createState() => _HousekeepingTriageFormState();
}

class _HousekeepingTriageFormState extends State<HousekeepingTriageForm> {
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _slaController = TextEditingController();
  late String _status = _triageStatusFromItem(widget.item);

  HousekeepingMaintenanceTriageDraft toDraft() {
    return HousekeepingMaintenanceTriageDraft(
      status: _status,
      summary: _emptyToNull(_summaryController.text),
      slaHours: int.tryParse(_slaController.text.trim()),
    );
  }

  String? validate(AppLocalizations l10n) {
    if (_status != 'OPEN' && _status != 'IN_PROGRESS') {
      return l10n.housekeepingStatusRequiredMessage;
    }
    final String summary = _summaryController.text.trim();
    if (summary.length > 10000) {
      return l10n.housekeepingTriageSummaryMaxLengthMessage;
    }
    final String slaText = _slaController.text.trim();
    if (slaText.isNotEmpty) {
      final int? slaHours = int.tryParse(slaText);
      if (slaHours == null || slaHours < 1 || slaHours > 10000) {
        return l10n.housekeepingSlaHoursInvalidMessage;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _slaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final HousekeepingWorkItem item = widget.item;
    return AppFormSection(
      children: <Widget>[
        AppInfoTileGrid(
          maxColumns: 2,
          items: <AppInfoTileData>[
            AppInfoTileData(
              label: l10n.housekeepingReferenceLabel,
              value: item.effectiveDisplayId,
              icon: Icons.tag_outlined,
              copyable: true,
            ),
            AppInfoTileData(
              label: l10n.housekeepingLocationLabel,
              value: _locationLabel(l10n, item),
              icon: Icons.meeting_room_outlined,
            ),
            AppInfoTileData(
              label: l10n.housekeepingStatusFieldLabel,
              value: _maintenanceStatusLabel(l10n, item.status),
              icon: _statusIcon(item.status),
            ),
            AppInfoTileData(
              label: l10n.housekeepingDueLabel,
              value: _dateTimeLabel(context, item.reportedAt ?? item.timelineAt),
              icon: Icons.schedule_outlined,
            ),
          ],
        ),
        AppSelectField<String>(
          value: _status,
          labelText: l10n.housekeepingStatusFieldLabel,
          isRequired: true,
          enabled: widget.enabled,
          options: <AppSelectOption<String>>[
            AppSelectOption<String>(
              value: 'OPEN',
              label: l10n.housekeepingStatusOpenLabel,
            ),
            AppSelectOption<String>(
              value: 'IN_PROGRESS',
              label: l10n.housekeepingStatusInProgressLabel,
            ),
          ],
          validator: AppValidators.requiredValue(
            l10n.housekeepingStatusRequiredMessage,
          ),
          onChanged: widget.enabled
              ? (String? value) {
                  if (value != null) {
                    setState(() => _status = value);
                  }
                }
              : null,
        ),
        AppTextField(
          controller: _summaryController,
          labelText: l10n.housekeepingTriageSummaryFieldLabel,
          enabled: widget.enabled,
          maxLines: 4,
          validator: AppValidators.maxLength(
            10000,
            l10n.housekeepingTriageSummaryMaxLengthMessage,
          ),
        ),
        AppTextField(
          controller: _slaController,
          labelText: l10n.housekeepingSlaHoursFieldLabel,
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          validator: (String? value) {
            final String normalized = (value ?? '').trim();
            if (normalized.isEmpty) {
              return null;
            }
            final int? slaHours = int.tryParse(normalized);
            if (slaHours == null || slaHours < 1 || slaHours > 10000) {
              return l10n.housekeepingSlaHoursInvalidMessage;
            }
            return null;
          },
        ),
      ],
    );
  }
}

String _triageStatusFromItem(HousekeepingWorkItem item) {
  final String normalized = (item.status ?? '').trim().toUpperCase();
  if (normalized == 'OPEN' || normalized == 'IN_PROGRESS') {
    return normalized;
  }
  return 'IN_PROGRESS';
}

String _locationLabel(AppLocalizations l10n, HousekeepingWorkItem item) {
  final String location = item.locationDisplay.trim();
  return location.isEmpty ? l10n.housekeepingLocationNotSet : location;
}

String _maintenanceStatusLabel(AppLocalizations l10n, String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'OPEN' => l10n.housekeepingStatusOpen,
    'IN_PROGRESS' => l10n.housekeepingStatusInProgress,
    'COMPLETED' => l10n.housekeepingStatusCompleted,
    'CANCELLED' => l10n.housekeepingStatusCancelled,
    _ => l10n.housekeepingStatusUnknown,
  };
}

IconData _statusIcon(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'COMPLETED' => Icons.task_alt_outlined,
    'CANCELLED' => Icons.cancel_outlined,
    'IN_PROGRESS' => Icons.cleaning_services_outlined,
    'OPEN' => Icons.report_problem_outlined,
    _ => Icons.flag_outlined,
  };
}

String _dateTimeLabel(BuildContext context, DateTime? value) {
  return value == null
      ? context.l10n.housekeepingNotRecorded
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String? _emptyToNull(String value) {
  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
