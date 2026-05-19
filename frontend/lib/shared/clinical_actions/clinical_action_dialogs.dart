import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class ClinicalFreeTextActionDialog extends StatefulWidget {
  const ClinicalFreeTextActionDialog({
    required this.title,
    required this.label,
    required this.submitLabel,
    required this.onSubmit,
    this.sectionTitle,
    this.icon = const Icon(Icons.edit_note_outlined),
    this.prefixIcon,
    this.minLines,
    this.maxLines = 5,
    this.maxWidth = 720,
    this.autofocus = true,
    super.key,
  });

  final String title;
  final String? sectionTitle;
  final String label;
  final String submitLabel;
  final Widget icon;
  final Widget? prefixIcon;
  final int? minLines;
  final int maxLines;
  final double maxWidth;
  final bool autofocus;
  final Future<AppFailure?> Function(String value) onSubmit;

  @override
  State<ClinicalFreeTextActionDialog> createState() =>
      _ClinicalFreeTextActionDialogState();
}

class _ClinicalFreeTextActionDialogState
    extends State<ClinicalFreeTextActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(widget.title),
      icon: widget.icon,
      maxWidth: widget.maxWidth,
      scrollable: true,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          title: widget.sectionTitle,
          density: AppFormSectionDensity.spacious,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _controller,
              labelText: widget.label,
              prefixIcon: widget.prefixIcon,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              enabled: !_isSaving,
              isRequired: true,
              autofocus: widget.autofocus,
              textCapitalization: TextCapitalization.sentences,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        widget.submitLabel,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(_controller.text.trim());
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class ClinicalReferralActionDialog extends StatefulWidget {
  const ClinicalReferralActionDialog({required this.onSubmit, super.key});

  final Future<AppFailure?> Function({
    required String externalFacilityName,
    required String reason,
    required String notes,
  }) onSubmit;

  @override
  State<ClinicalReferralActionDialog> createState() =>
      _ClinicalReferralActionDialogState();
}

class _ClinicalReferralActionDialogState
    extends State<ClinicalReferralActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _facilityController;
  late final TextEditingController _reasonController;
  late final TextEditingController _notesController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _facilityController = TextEditingController();
    _reasonController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _facilityController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdReferAction),
      icon: const Icon(Icons.alt_route_outlined),
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _facilityController,
              labelText: l10n.opdExternalFacilityLabel,
              enabled: !_isSaving,
              isRequired: true,
              textCapitalization: TextCapitalization.words,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _reasonController,
              labelText: l10n.opdReasonLabel,
              enabled: !_isSaving,
              isRequired: true,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _notesController,
              labelText: l10n.opdNotesLabel,
              enabled: !_isSaving,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        l10n.opdReferAction,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      externalFacilityName: _facilityController.text.trim(),
      reason: _reasonController.text.trim(),
      notes: _notesController.text.trim(),
    );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class ClinicalFollowUpActionDialog extends StatefulWidget {
  const ClinicalFollowUpActionDialog({required this.onSubmit, super.key});

  final Future<AppFailure?> Function({
    required DateTime scheduledAt,
    required String notes,
  }) onSubmit;

  @override
  State<ClinicalFollowUpActionDialog> createState() =>
      _ClinicalFollowUpActionDialogState();
}

class _ClinicalFollowUpActionDialogState
    extends State<ClinicalFollowUpActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  late DateTime _followUpDate;
  late TimeOfDay _followUpTime;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final DateTime defaultAt = DateTime.now().add(const Duration(days: 7));
    _followUpDate = _dateOnly(defaultAt);
    _followUpTime = TimeOfDay.fromDateTime(defaultAt);
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final DateTime today = _dateOnly(DateTime.now());
    return AppDialog(
      title: Text(l10n.opdFollowUpAction),
      icon: const Icon(Icons.event_repeat_outlined),
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: AppDateField(
                value: _followUpDate,
                labelText: l10n.opdFollowUpDateLabel,
                hintText: l10n.appDateFormatHint,
                firstDate: today,
                lastDate: _dateOnly(today.add(const Duration(days: 365))),
                currentDate: today,
                pickerButtonLabel: l10n.opdDatePickerButtonLabel,
                invalidDateMessage: l10n.appDateInvalidMessage,
                enabled: !_isSaving,
                isRequired: true,
                validator: AppValidators.requiredValue<DateTime>(
                  l10n.validationRequired,
                ),
                onChanged: (DateTime? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _followUpDate = _dateOnly(value));
                },
              ),
              right: AppTimeField(
                value: _followUpTime,
                labelText: l10n.opdFollowUpTimeLabel,
                hintText: l10n.appTimeFormatHint,
                pickerButtonLabel: l10n.appTimePickerAction,
                invalidTimeMessage: l10n.appTimeInvalidMessage,
                enabled: !_isSaving,
                isRequired: true,
                validator: AppValidators.requiredValue<TimeOfDay>(
                  l10n.validationRequired,
                ),
                onChanged: (TimeOfDay? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _followUpTime = value);
                },
              ),
            ),
            AppTextField(
              controller: _notesController,
              labelText: l10n.opdNotesLabel,
              enabled: !_isSaving,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        l10n.opdFollowUpAction,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final DateTime scheduledAt = _combineDateAndTime(
      _followUpDate,
      _followUpTime,
    );
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      scheduledAt: scheduledAt,
      notes: _notesController.text.trim(),
    );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class ClinicalAdmissionActionDialog extends StatefulWidget {
  const ClinicalAdmissionActionDialog({
    required this.referenceData,
    required this.onSubmit,
    super.key,
  });

  final ClinicalActionReferenceData referenceData;
  final Future<AppFailure?> Function(ClinicalActionCatalogOption bed) onSubmit;

  @override
  State<ClinicalAdmissionActionDialog> createState() =>
      _ClinicalAdmissionActionDialogState();
}

class _ClinicalAdmissionActionDialogState
    extends State<ClinicalAdmissionActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _wardId;
  String? _roomId;
  String? _bedId;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<ClinicalActionCatalogOption> availableBeds =
        _availableAdmissionBeds(widget.referenceData);
    final List<AppSelectOption<String>> wardOptions = _admissionWardOptions(
      widget.referenceData,
      availableBeds,
    );
    final List<AppSelectOption<String>> roomOptions = _admissionRoomOptions(
      widget.referenceData,
      availableBeds,
      _wardId,
    );
    final List<AppSelectOption<String>> bedOptions = _admissionBedOptions(
      widget.referenceData,
      availableBeds,
      wardId: _wardId,
      roomId: _roomId,
    );
    final ClinicalActionCatalogOption? selectedBed = _selectedAdmissionBed(
      availableBeds,
      _bedId,
    );

    return AppDialog(
      title: Text(l10n.clinicalRequestAdmissionAction),
      icon: const Icon(Icons.bed_outlined),
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          title: l10n.clinicalAdmissionDetailsTitle,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            if (availableBeds.isEmpty)
              AppStateView(
                title: l10n.clinicalAdmissionNoBedsTitle,
                body: l10n.clinicalAdmissionNoBedsMessage,
                icon: Icons.bed_outlined,
                variant: AppStateViewVariant.empty,
              )
            else ...<Widget>[
              AppResponsiveFieldRow.two(
                gap: AppResponsiveFieldRowGap.form,
                left: AppSelectField<String>.searchable(
                  value: _wardId,
                  labelText: l10n.clinicalAdmissionWardLabel,
                  enabled: !_isSaving && wardOptions.isNotEmpty,
                  isRequired: true,
                  menuHeight: 280,
                  options: wardOptions,
                  validator: AppValidators.requiredValue<String>(
                    l10n.validationRequired,
                  ),
                  onChanged: _handleWardChanged,
                ),
                right: AppSelectField<String>.searchable(
                  value: _roomId,
                  labelText: l10n.clinicalAdmissionRoomLabel,
                  enabled:
                      !_isSaving && _wardId != null && roomOptions.isNotEmpty,
                  isRequired: true,
                  menuHeight: 280,
                  options: roomOptions,
                  validator: AppValidators.requiredValue<String>(
                    l10n.validationRequired,
                  ),
                  onChanged: _handleRoomChanged,
                ),
              ),
              AppSelectField<String>.searchable(
                value: _bedId,
                labelText: l10n.clinicalAdmissionBedLabel,
                enabled: !_isSaving && _roomId != null && bedOptions.isNotEmpty,
                isRequired: true,
                menuHeight: 320,
                options: bedOptions,
                validator: AppValidators.requiredValue<String>(
                  l10n.validationRequired,
                ),
                onChanged: (String? value) =>
                    _handleBedChanged(value, availableBeds),
              ),
              AppInfoTileGrid(
                items: _admissionDetailTiles(
                  context,
                  widget.referenceData,
                  selectedBed,
                ),
                maxColumns: 2,
              ),
            ],
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        l10n.clinicalRequestAdmissionAction,
        _isSaving,
        availableBeds.isEmpty ? null : _submit,
      ),
    );
  }

  void _handleWardChanged(String? value) {
    setState(() {
      _wardId = value;
      _roomId = null;
      _bedId = null;
    });
  }

  void _handleRoomChanged(String? value) {
    setState(() {
      _roomId = value;
      _bedId = null;
    });
  }

  void _handleBedChanged(
    String? value,
    List<ClinicalActionCatalogOption> availableBeds,
  ) {
    final ClinicalActionCatalogOption? bed = _selectedAdmissionBed(
      availableBeds,
      value,
    );
    setState(() {
      _bedId = value;
      if (bed != null) {
        _wardId = bed.parentId;
        _roomId = bed.secondaryId;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final ClinicalActionCatalogOption? bed = _selectedAdmissionBed(
      _availableAdmissionBeds(widget.referenceData),
      _bedId,
    );
    if (bed == null || !_isAdmissionBedAvailable(bed)) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(bed);
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class ClinicalDispositionActionDialog extends StatefulWidget {
  const ClinicalDispositionActionDialog({
    required this.reasons,
    required this.onSubmit,
    this.title,
    this.reasonLabel,
    this.notesLabel,
    this.submitLabel,
    this.initialReason,
    this.icon = const Icon(Icons.task_alt_outlined),
    super.key,
  });

  final List<String> reasons;
  final String? title;
  final String? reasonLabel;
  final String? notesLabel;
  final String? submitLabel;
  final String? initialReason;
  final Widget icon;
  final Future<AppFailure?> Function({
    required String reason,
    required String notes,
  }) onSubmit;

  @override
  State<ClinicalDispositionActionDialog> createState() =>
      _ClinicalDispositionActionDialogState();
}

class _ClinicalDispositionActionDialogState
    extends State<ClinicalDispositionActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  late String? _reason;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _reason = _initialReason();
  }

  String? _initialReason() {
    final String? requested = widget.initialReason;
    if (requested != null && widget.reasons.contains(requested)) {
      return requested;
    }
    return widget.reasons.isEmpty ? null : widget.reasons.first;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(widget.title ?? l10n.clinicalCompleteDispositionAction),
      icon: widget.icon,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>.searchable(
              value: _reason,
              labelText:
                  widget.reasonLabel ?? l10n.clinicalDispositionReasonLabel,
              enabled: !_isSaving,
              isRequired: true,
              menuHeight: 320,
              options: _dispositionReasonOptions(widget.reasons),
              validator: AppValidators.requiredValue<String>(
                l10n.validationRequired,
              ),
              onChanged: (String? value) => setState(() => _reason = value),
            ),
            AppTextField(
              controller: _notesController,
              labelText: widget.notesLabel ?? l10n.opdNotesLabel,
              enabled: !_isSaving,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        widget.submitLabel ?? l10n.clinicalCompleteDispositionAction,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final String? reason = _reason;
    if (reason == null || reason.trim().isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      reason: reason,
      notes: _notesController.text.trim(),
    );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

List<Widget> clinicalActionDialogActions(
  BuildContext context,
  String submitLabel,
  bool isSaving,
  VoidCallback? onSubmit,
) {
  final AppLocalizations l10n = context.l10n;
  return <Widget>[
    AppButton.tertiary(
      label: l10n.commonCancelActionLabel,
      enabled: !isSaving,
      onPressed: () => Navigator.of(context).pop(false),
    ),
    AppButton.primary(
      label: submitLabel,
      isLoading: isSaving,
      enabled: onSubmit != null,
      onPressed: onSubmit,
    ),
  ];
}

List<AppSelectOption<String>> _dispositionReasonOptions(List<String> reasons) {
  return <AppSelectOption<String>>[
    for (final String reason in reasons)
      AppSelectOption<String>(
        value: reason,
        label: _apiLabel(reason),
        leadingIcon: const Icon(Icons.fact_check_outlined),
      ),
  ];
}

List<ClinicalActionCatalogOption> _availableAdmissionBeds(
  ClinicalActionReferenceData referenceData,
) {
  final List<ClinicalActionCatalogOption> beds = referenceData.availableBeds
      .where(_isAdmissionBedAvailable)
      .toList(growable: false);
  return beds..sort(
    (ClinicalActionCatalogOption a, ClinicalActionCatalogOption b) =>
        a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()),
  );
}

bool _isAdmissionBedAvailable(ClinicalActionCatalogOption bed) {
  final String status = (bed.status ?? 'AVAILABLE').trim().toUpperCase();
  return status.isEmpty || status == 'AVAILABLE';
}

List<AppSelectOption<String>> _admissionWardOptions(
  ClinicalActionReferenceData referenceData,
  List<ClinicalActionCatalogOption> availableBeds,
) {
  final List<AppSelectOption<String>> options = _distinctAdmissionIds(
    availableBeds.map((ClinicalActionCatalogOption bed) => bed.parentId),
  ).map((String wardId) {
    final ClinicalActionCatalogOption? ward = _catalogOptionById(
      referenceData.wards,
      wardId,
    );
    return AppSelectOption<String>(
      value: wardId,
      label: _admissionCatalogLabel(ward, wardId),
      leadingIcon: const Icon(Icons.apartment_outlined),
    );
  }).toList(growable: false);
  return _sortAdmissionOptions(options);
}

List<AppSelectOption<String>> _admissionRoomOptions(
  ClinicalActionReferenceData referenceData,
  List<ClinicalActionCatalogOption> availableBeds,
  String? wardId,
) {
  final Iterable<ClinicalActionCatalogOption> beds = wardId == null
      ? availableBeds
      : availableBeds.where(
          (ClinicalActionCatalogOption bed) => bed.parentId == wardId,
        );
  final List<AppSelectOption<String>> options = _distinctAdmissionIds(
    beds.map((ClinicalActionCatalogOption bed) => bed.secondaryId),
  ).map((String roomId) {
    final ClinicalActionCatalogOption? room = _catalogOptionById(
      referenceData.rooms,
      roomId,
    );
    return AppSelectOption<String>(
      value: roomId,
      label: _admissionCatalogLabel(room, roomId),
      leadingIcon: const Icon(Icons.meeting_room_outlined),
    );
  }).toList(growable: false);
  return _sortAdmissionOptions(options);
}

List<AppSelectOption<String>> _admissionBedOptions(
  ClinicalActionReferenceData referenceData,
  List<ClinicalActionCatalogOption> availableBeds, {
  required String? wardId,
  required String? roomId,
}) {
  final List<AppSelectOption<String>> options = <AppSelectOption<String>>[
    for (final ClinicalActionCatalogOption bed in availableBeds)
      if ((wardId == null || bed.parentId == wardId) &&
          (roomId == null || bed.secondaryId == roomId))
        AppSelectOption<String>(
          value: bed.apiId,
          label: _admissionBedDisplayLabel(referenceData, bed),
          leadingIcon: const Icon(Icons.bed_outlined),
          trailingIcon: const Icon(Icons.check_circle_outline),
        ),
  ];
  return _sortAdmissionOptions(options);
}

ClinicalActionCatalogOption? _selectedAdmissionBed(
  List<ClinicalActionCatalogOption> availableBeds,
  String? bedId,
) {
  if (bedId == null || bedId.trim().isEmpty) {
    return null;
  }
  for (final ClinicalActionCatalogOption bed in availableBeds) {
    if (_catalogIdMatches(bed, bedId)) {
      return bed;
    }
  }
  return null;
}

List<AppInfoTileData> _admissionDetailTiles(
  BuildContext context,
  ClinicalActionReferenceData referenceData,
  ClinicalActionCatalogOption? bed,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppInfoTileData>[
    AppInfoTileData(
      label: l10n.clinicalAdmissionWardLabel,
      value: bed == null
          ? null
          : _catalogDisplayLabelById(referenceData.wards, bed.parentId) ??
                bed.parentId,
      icon: Icons.apartment_outlined,
    ),
    AppInfoTileData(
      label: l10n.clinicalAdmissionRoomLabel,
      value: bed == null
          ? null
          : _catalogDisplayLabelById(referenceData.rooms, bed.secondaryId) ??
                bed.secondaryId,
      icon: Icons.meeting_room_outlined,
    ),
    AppInfoTileData(
      label: l10n.clinicalAdmissionBedLabel,
      value: bed?.displayTitle,
      icon: Icons.bed_outlined,
    ),
    AppInfoTileData(
      label: l10n.clinicalAdmissionAvailabilityLabel,
      value: bed == null ? null : _apiLabel(bed.status ?? 'AVAILABLE'),
      icon: Icons.check_circle_outline,
    ),
  ];
}

String _admissionBedDisplayLabel(
  ClinicalActionReferenceData referenceData,
  ClinicalActionCatalogOption bed,
) {
  return _joinDisplay(<String?>[
    _catalogDisplayLabelById(referenceData.wards, bed.parentId),
    _catalogDisplayLabelById(referenceData.rooms, bed.secondaryId),
    bed.displayTitle,
    _apiLabel(bed.status ?? 'AVAILABLE'),
  ]);
}

String _admissionCatalogLabel(
  ClinicalActionCatalogOption? option,
  String fallback,
) {
  if (option == null) {
    return fallback;
  }
  return _joinDisplay(<String?>[option.displayTitle, option.displaySubtitle]);
}

String? _catalogDisplayLabelById(
  List<ClinicalActionCatalogOption> options,
  String? apiId,
) {
  final ClinicalActionCatalogOption? option = _catalogOptionById(
    options,
    apiId,
  );
  if (option == null) {
    return null;
  }
  return _joinDisplay(<String?>[option.displayTitle, option.displaySubtitle]);
}

ClinicalActionCatalogOption? _catalogOptionById(
  List<ClinicalActionCatalogOption> options,
  String? id,
) {
  if (id == null || id.trim().isEmpty) {
    return null;
  }
  for (final ClinicalActionCatalogOption option in options) {
    if (_catalogIdMatches(option, id)) {
      return option;
    }
  }
  return null;
}

bool _catalogIdMatches(ClinicalActionCatalogOption option, String id) {
  final String normalized = id.trim();
  return option.id == normalized ||
      option.publicId == normalized ||
      option.apiId == normalized;
}

List<String> _distinctAdmissionIds(Iterable<String?> ids) {
  final Set<String> seen = <String>{};
  final List<String> values = <String>[];
  for (final String? id in ids) {
    final String normalized = id?.trim() ?? '';
    if (normalized.isEmpty || seen.contains(normalized)) {
      continue;
    }
    seen.add(normalized);
    values.add(normalized);
  }
  return values;
}

List<AppSelectOption<String>> _sortAdmissionOptions(
  List<AppSelectOption<String>> options,
) {
  return options..sort(
    (AppSelectOption<String> a, AppSelectOption<String> b) =>
        a.label.toLowerCase().compareTo(b.label.toLowerCase()),
  );
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

String _apiLabel(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .split(RegExp(r'[_\s-]+'))
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

String _joinDisplay(Iterable<String?> values) {
  return values
      .map((String? item) => item?.trim() ?? '')
      .where((String item) => item.isNotEmpty)
      .join(' · ');
}
