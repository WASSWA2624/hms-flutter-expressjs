import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_provider_options.dart';

/// Schedule a visitor (non-patient) meeting with any facility staff host.
class ReceptionVisitorAppointmentDialog extends ConsumerStatefulWidget {
  const ReceptionVisitorAppointmentDialog({
    this.embedded = false,
    this.onSaved,
    this.onCancel,
    this.onBusyChanged,
    super.key,
  });

  final bool embedded;
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;
  final ValueChanged<bool>? onBusyChanged;

  @override
  ConsumerState<ReceptionVisitorAppointmentDialog> createState() =>
      _ReceptionVisitorAppointmentDialogState();
}

class _ReceptionVisitorAppointmentDialogState
    extends ConsumerState<ReceptionVisitorAppointmentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _visitorNameController = TextEditingController();
  final TextEditingController _visitorPhoneController = TextEditingController();
  final TextEditingController _visitorOrganizationController =
      TextEditingController();
  final TextEditingController _durationController = TextEditingController(
    text: '30',
  );
  final TextEditingController _reasonController = TextEditingController();

  DateTime? _date = DateTime.now();
  AppTimeValue? _startTime = const AppTimeValue(hour: 9, minute: 0);
  String? _hostId;
  List<OpdProviderOption> _hosts = const <OpdProviderOption>[];
  List<OpdProviderSchedule> _schedules = const <OpdProviderSchedule>[];
  bool _isLoadingHosts = false;
  bool _isSaving = false;
  AppFailure? _failure;

  bool get _isBusy => _isSaving || _isLoadingHosts;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_loadHosts());
    });
  }

  @override
  void dispose() {
    _visitorNameController.dispose();
    _visitorPhoneController.dispose();
    _visitorOrganizationController.dispose();
    _durationController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppSelectOption<String>> hostOptions = opdProviderSelectOptions(
      providers: _hosts,
      schedules: _schedules,
    );

    final Widget form = AppFormShell(
      formKey: _formKey,
      enabled: !_isBusy,
      density: AppFormSectionDensity.compact,
      formStatus: appFormFailureStatus(
        context,
        _failure,
        messageBuilder: (AppFailure failure) => failure.displayMessage(l10n),
      ),
      children: <Widget>[
        AppFormInformationBanner(
          title: l10n.receptionVisitorMeetingBannerTitle,
          message: l10n.receptionVisitorMeetingBannerBody,
          variant: AppFormInformationVariant.info,
          icon: Icons.badge_outlined,
        ),
        AppTextField(
          controller: _visitorNameController,
          labelText: l10n.receptionVisitorNameLabel,
          enabled: !_isBusy,
          isRequired: true,
          textInputAction: TextInputAction.next,
          validator: (String? value) {
            if ((value ?? '').trim().isEmpty) {
              return l10n.validationRequired;
            }
            return null;
          },
        ),
        AppResponsiveFieldRow(
          gap: AppResponsiveFieldRowGap.form,
          children: <Widget>[
            AppTextField(
              controller: _visitorPhoneController,
              labelText: l10n.receptionVisitorPhoneLabel,
              enabled: !_isBusy,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            AppTextField(
              controller: _visitorOrganizationController,
              labelText: l10n.receptionVisitorOrganizationLabel,
              enabled: !_isBusy,
              textInputAction: TextInputAction.next,
            ),
          ],
        ),
        AppSelectField<String>.searchable(
          value: _hostId,
          labelText: l10n.receptionStaffHostLabel,
          options: hostOptions,
          enabled: !_isBusy,
          isLoading: _isLoadingHosts,
          isRequired: true,
          onChanged: (String? value) => setState(() => _hostId = value),
          validator: (String? value) {
            if ((value ?? '').trim().isEmpty) {
              return l10n.validationRequired;
            }
            return null;
          },
        ),
        AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppDateField(
              value: _date,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              labelText: l10n.patientsAppointmentDateLabel,
              pickerButtonLabel: l10n.patientsDatePickerAction,
              invalidDateMessage: l10n.appDateInvalidMessage,
              enabled: !_isBusy,
              isRequired: true,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              onChanged: (DateTime? value) => setState(() => _date = value),
            ),
            AppResponsiveFieldRow(
              gap: AppResponsiveFieldRowGap.form,
              children: <Widget>[
                AppTimeField(
                  value: _startTime,
                  labelText: l10n.patientsAppointmentTimeLabel,
                  pickerButtonLabel: l10n.appTimePickerAction,
                  invalidTimeMessage: l10n.patientsTimeInvalidMessage,
                  hintText: l10n.patientsTimeHint,
                  hourLabelText: l10n.appTimeHourLabel,
                  minuteLabelText: l10n.appTimeMinuteLabel,
                  enabled: !_isBusy,
                  isRequired: true,
                  validator: (AppTimeValue? value) =>
                      value == null ? l10n.validationRequired : null,
                  onChanged: (AppTimeValue? value) {
                    setState(() => _startTime = value);
                  },
                ),
                AppTextField(
                  controller: _durationController,
                  labelText: l10n.patientsAppointmentDurationLabel,
                  enabled: !_isBusy,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  validator: (String? value) {
                    final int? minutes = int.tryParse((value ?? '').trim());
                    if (minutes == null || minutes <= 0) {
                      return l10n.validationRequired;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ],
        ),
        AppTextField(
          controller: _reasonController,
          labelText: l10n.patientsAppointmentReasonLabel,
          enabled: !_isBusy,
          maxLines: 2,
          textInputAction: TextInputAction.done,
        ),
      ],
    );

    final List<Widget> actions = <Widget>[
      if (widget.onCancel != null)
        AppButton(
          label: l10n.commonCancelActionLabel,
          onPressed: _isBusy ? null : widget.onCancel,
        ),
      AppButton(
        label: l10n.receptionScheduleAppointmentAction,
        variant: AppButtonVariant.primary,
        isLoading: _isSaving,
        onPressed: _isBusy ? null : _submit,
      ),
    ];

    if (widget.embedded) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          form,
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: actions,
          ),
        ],
      );
    }

    return AppDialog(
      title: Text(l10n.receptionVisitorMeetingTitle),
      icon: const Icon(Icons.badge_outlined),
      scrollable: true,
      closeEnabled: !_isBusy,
      maxWidth: 720,
      content: form,
      actions: actions,
    );
  }

  Future<void> _loadHosts() async {
    setState(() => _isLoadingHosts = true);
    widget.onBusyChanged?.call(true);
    final Result<List<OpdProviderOption>> hostsResult = await ref
        .read(opdRepositoryProvider)
        .listMeetingHosts();
    final Result<List<OpdProviderSchedule>> schedulesResult = await ref
        .read(opdRepositoryProvider)
        .listProviderSchedules();
    if (!mounted) {
      return;
    }
    hostsResult.when(
      success: (List<OpdProviderOption> hosts) {
        schedulesResult.when(
          success: (List<OpdProviderSchedule> schedules) {
            setState(() {
              _hosts = hosts;
              _schedules = schedules;
              _isLoadingHosts = false;
              _failure = null;
            });
          },
          failure: (AppFailure failure) {
            setState(() {
              _hosts = hosts;
              _isLoadingHosts = false;
              _failure = failure;
            });
          },
        );
      },
      failure: (AppFailure failure) {
        setState(() {
          _isLoadingHosts = false;
          _failure = failure;
        });
      },
    );
    widget.onBusyChanged?.call(false);
  }

  Future<void> _submit() async {
    if (_isBusy) {
      return;
    }
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final DateTime? scheduledStart = _combineDateAndTime(_date, _startTime);
    if (scheduledStart == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    final int duration = int.parse(_durationController.text.trim());
    final DateTime scheduledEnd = scheduledStart.add(
      Duration(minutes: duration),
    );

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    widget.onBusyChanged?.call(true);

    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .createAppointment(<String, Object?>{
          'subject_type': 'VISITOR',
          'visitor_name': _visitorNameController.text.trim(),
          'visitor_phone': _visitorPhoneController.text.trim().isEmpty
              ? null
              : _visitorPhoneController.text.trim(),
          'visitor_organization':
              _visitorOrganizationController.text.trim().isEmpty
              ? null
              : _visitorOrganizationController.text.trim(),
          'provider_user_id': _hostId,
          'status': 'SCHEDULED',
          'scheduled_start': scheduledStart.toUtc().toIso8601String(),
          'scheduled_end': scheduledEnd.toUtc().toIso8601String(),
          'reason': _reasonController.text.trim().isEmpty
              ? null
              : _reasonController.text.trim(),
        });

    if (!mounted) {
      return;
    }
    if (failure != null) {
      setState(() {
        _isSaving = false;
        _failure = failure;
      });
      widget.onBusyChanged?.call(false);
      return;
    }

    setState(() => _isSaving = false);
    widget.onBusyChanged?.call(false);
    if (widget.onSaved != null) {
      widget.onSaved!();
      return;
    }
    Navigator.of(context).pop(true);
  }

  DateTime? _combineDateAndTime(DateTime? date, AppTimeValue? time) {
    if (date == null || time == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}
