import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class ClinicalAdmissionActionDialog extends StatefulWidget {
  const ClinicalAdmissionActionDialog({
    required this.referenceData,
    required this.onSubmit,
    this.title,
    this.submitLabel,
    this.icon = const Icon(Icons.bed_outlined),
    this.reasonLabel,
    this.reasonRequired = false,
    this.notesLabel,
    this.requiresBed = true,
    this.maxWidth = 900,
    this.initialMaximized = true,
    this.showCancelButton = true,
    this.submitLeadingIcon,
    this.leadingSectionsBuilder,
    super.key,
  });

  final ClinicalActionReferenceData referenceData;
  final Future<AppFailure?> Function(ClinicalActionAdmissionInput input)
  onSubmit;
  final String? title;
  final String? submitLabel;
  final Widget icon;
  final String? reasonLabel;
  final bool reasonRequired;
  final String? notesLabel;
  final bool requiresBed;
  final double maxWidth;
  final bool initialMaximized;
  final bool showCancelButton;
  final IconData? submitLeadingIcon;
  final List<Widget> Function(BuildContext context, bool enabled)?
  leadingSectionsBuilder;

  @override
  State<ClinicalAdmissionActionDialog> createState() =>
      _ClinicalAdmissionActionDialogState();
}

class _ClinicalAdmissionActionDialogState
    extends State<ClinicalAdmissionActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _wardId;
  String? _roomId;
  String? _bedId;
  String? _bedWarning;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void didUpdateWidget(covariant ClinicalAdmissionActionDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedAdmissionBed(
          _availableAdmissionBeds(widget.referenceData),
          _bedId,
        ) ==
        null) {
      _wardId = null;
      _roomId = null;
      _bedId = null;
      _bedWarning = null;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String title = widget.title ?? l10n.clinicalRequestAdmissionAction;
    final String submitLabel =
        widget.submitLabel ?? l10n.clinicalRequestAdmissionAction;
    final IconData? submitLeadingIcon =
        widget.submitLeadingIcon ?? Icons.local_hospital_outlined;

    if (!widget.requiresBed) {
      return AppDialog(
        title: Text(title),
        icon: widget.icon,
        closeEnabled: !_isSaving,
        initialMaximized: widget.initialMaximized,
        maxWidth: widget.maxWidth,
        scrollable: true,
        pinActionsToBottom: true,
        content: AppFormShell(
          formKey: _formKey,
          enabled: !_isSaving,
          density: AppFormSectionDensity.compact,
          formStatus: appFormFailureStatus(context, _failure),
          children: <Widget>[
            ...?widget.leadingSectionsBuilder?.call(context, !_isSaving),
            AppFormSection(
              title: l10n.clinicalAdmissionDetailsTitle,
              density: AppFormSectionDensity.compact,
              children: <Widget>[
                if (widget.reasonLabel != null)
                  AppTextField(
                    controller: _reasonController,
                    labelText: widget.reasonLabel!,
                    enabled: !_isSaving,
                    isRequired: widget.reasonRequired,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    prefixIcon: const Icon(Icons.notes_outlined),
                    validator: widget.reasonRequired
                        ? AppValidators.requiredText(l10n.validationRequired)
                        : null,
                  ),
                if (widget.notesLabel != null)
                  AppTextField(
                    controller: _notesController,
                    labelText: widget.notesLabel!,
                    enabled: !_isSaving,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    prefixIcon: const Icon(Icons.edit_note_outlined),
                  ),
              ],
            ),
          ],
        ),
        actions: clinicalActionDialogActions(
          context,
          submitLabel,
          _isSaving,
          _isSaving ? null : _submitRequestOnly,
          showCancel: widget.showCancelButton,
          submitLeadingIcon: submitLeadingIcon,
        ),
      );
    }

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
    final bool wardEnabled = !_isSaving && wardOptions.isNotEmpty;
    final bool roomEnabled =
        !_isSaving && _wardId != null && roomOptions.isNotEmpty;
    final bool bedEnabled =
        !_isSaving && _roomId != null && bedOptions.isNotEmpty;

    return AppDialog(
      title: Text(title),
      icon: widget.icon,
      closeEnabled: !_isSaving,
      initialMaximized: widget.initialMaximized,
      maxWidth: widget.maxWidth,
      scrollable: true,
      pinActionsToBottom: true,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        density: AppFormSectionDensity.compact,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          ...?widget.leadingSectionsBuilder?.call(context, !_isSaving),
          AppFormSection(
            title: l10n.clinicalAdmissionDetailsTitle,
            density: AppFormSectionDensity.compact,
            children: <Widget>[
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
                    enabled: wardEnabled,
                    helperText: wardEnabled
                        ? null
                        : l10n.clinicalAdmissionNoWardsHelper,
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
                    enabled: roomEnabled,
                    helperText: roomEnabled
                        ? null
                        : (_wardId == null
                              ? l10n.clinicalAdmissionSelectWardFirstHint
                              : l10n.clinicalAdmissionNoRoomsMessage),
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
                  enabled: bedEnabled,
                  helperText: bedEnabled
                      ? null
                      : (_roomId == null
                            ? l10n.clinicalAdmissionSelectRoomFirstHint
                            : l10n.clinicalAdmissionNoBedsForRoomMessage),
                  isRequired: true,
                  menuHeight: 320,
                  options: bedOptions,
                  validator: AppValidators.requiredValue<String>(
                    l10n.validationRequired,
                  ),
                  onChanged: (String? value) =>
                      _handleBedChanged(value, availableBeds),
                ),
                if (_bedWarning != null)
                  AppFormInformationBanner.message(
                    message: _bedWarning!,
                    variant: AppFormInformationVariant.warning,
                    icon: Icons.warning_amber_outlined,
                  ),
                AppInfoTileGrid(
                  items: _admissionDetailTiles(
                    context,
                    widget.referenceData,
                    wardId: _wardId,
                    roomId: _roomId,
                    selectedBed: selectedBed,
                  ),
                  minItemWidth: 180,
                ),
                if (widget.reasonLabel != null)
                  AppTextField(
                    controller: _reasonController,
                    labelText: widget.reasonLabel!,
                    enabled: !_isSaving,
                    isRequired: widget.reasonRequired,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    prefixIcon: const Icon(Icons.notes_outlined),
                    validator: widget.reasonRequired
                        ? AppValidators.requiredText(l10n.validationRequired)
                        : null,
                  ),
                if (widget.notesLabel != null)
                  AppTextField(
                    controller: _notesController,
                    labelText: widget.notesLabel!,
                    enabled: !_isSaving,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    prefixIcon: const Icon(Icons.edit_note_outlined),
                  ),
              ],
            ],
          ),
        ],
      ),
      actions: clinicalActionDialogActions(
        context,
        submitLabel,
        _isSaving,
        availableBeds.isEmpty || _isSaving ? null : _submit,
        showCancel: widget.showCancelButton,
        submitLeadingIcon: submitLeadingIcon,
      ),
    );
  }

  void _handleWardChanged(String? value) {
    setState(() {
      _wardId = value;
      _roomId = null;
      _bedId = null;
      _bedWarning = null;
    });
  }

  void _handleRoomChanged(String? value) {
    setState(() {
      _roomId = value;
      _bedId = null;
      _bedWarning = null;
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
      _bedWarning = null;
      if (bed != null) {
        _wardId = bed.parentId;
        _roomId = bed.secondaryId;
      }
    });
  }

  Future<void> _submitRequestOnly() async {
    if (_isSaving) {
      return;
    }
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      ClinicalActionAdmissionInput(
        reason: clinicalActionNonEmpty(_reasonController.text),
        notes: clinicalActionNonEmpty(_notesController.text),
      ),
    );
    _finishSubmit(failure);
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    final ClinicalActionCatalogOption? bed = _selectedAdmissionBed(
      _availableAdmissionBeds(widget.referenceData),
      _bedId,
    );
    if (bed == null || !_isAdmissionBedAvailable(bed)) {
      setState(() {
        _failure = AppFailure.validation();
        _bedWarning = context.l10n.clinicalAdmissionBedUnavailableMessage;
      });
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      ClinicalActionAdmissionInput(
        bed: bed,
        reason: clinicalActionNonEmpty(_reasonController.text),
        notes: clinicalActionNonEmpty(_notesController.text),
      ),
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
  final List<AppSelectOption<String>> options =
      _distinctAdmissionIds(
            availableBeds.map(
              (ClinicalActionCatalogOption bed) => bed.parentId,
            ),
          )
          .map((String wardId) {
            final ClinicalActionCatalogOption? ward =
                clinicalActionCatalogOptionById(referenceData.wards, wardId);
            return AppSelectOption<String>(
              value: wardId,
              label: _admissionCatalogLabel(ward, wardId),
              leadingIcon: const Icon(Icons.apartment_outlined),
            );
          })
          .toList(growable: false);
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
  final List<AppSelectOption<String>> options =
      _distinctAdmissionIds(
            beds.map((ClinicalActionCatalogOption bed) => bed.secondaryId),
          )
          .map((String roomId) {
            final ClinicalActionCatalogOption? room =
                clinicalActionCatalogOptionById(referenceData.rooms, roomId);
            return AppSelectOption<String>(
              value: roomId,
              label: _admissionCatalogLabel(room, roomId),
              leadingIcon: const Icon(Icons.meeting_room_outlined),
            );
          })
          .toList(growable: false);
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
    if (clinicalActionCatalogIdMatches(bed, bedId)) {
      return bed;
    }
  }
  return null;
}

List<AppInfoTileData> _admissionDetailTiles(
  BuildContext context,
  ClinicalActionReferenceData referenceData, {
  required String? wardId,
  required String? roomId,
  required ClinicalActionCatalogOption? selectedBed,
}) {
  final AppLocalizations l10n = context.l10n;
  final String? resolvedWardId = wardId ?? selectedBed?.parentId;
  final String? resolvedRoomId = roomId ?? selectedBed?.secondaryId;
  return <AppInfoTileData>[
    AppInfoTileData(
      label: l10n.clinicalAdmissionWardLabel,
      value: resolvedWardId == null
          ? null
          : _admissionCatalogDisplayLabelById(
              referenceData.wards,
              resolvedWardId,
            ),
      icon: Icons.apartment_outlined,
    ),
    AppInfoTileData(
      label: l10n.clinicalAdmissionRoomLabel,
      value: resolvedRoomId == null
          ? null
          : _admissionCatalogDisplayLabelById(
              referenceData.rooms,
              resolvedRoomId,
            ),
      icon: Icons.meeting_room_outlined,
    ),
    AppInfoTileData(
      label: l10n.clinicalAdmissionBedLabel,
      value: selectedBed?.displayTitle,
      icon: Icons.bed_outlined,
    ),
  ];
}

String _admissionBedDisplayLabel(
  ClinicalActionReferenceData referenceData,
  ClinicalActionCatalogOption bed,
) {
  return _admissionJoinDisplay(<String?>[
    _admissionCatalogDisplayLabelById(referenceData.wards, bed.parentId),
    _admissionCatalogDisplayLabelById(referenceData.rooms, bed.secondaryId),
    bed.displayTitle,
    clinicalActionApiLabel(bed.status ?? 'AVAILABLE'),
  ]);
}

String _admissionCatalogLabel(
  ClinicalActionCatalogOption? option,
  String fallback,
) {
  if (option == null) {
    return fallback;
  }
  return _admissionJoinDisplay(<String?>[
    option.displayTitle,
    option.displaySubtitle,
  ]);
}

String? _admissionCatalogDisplayLabelById(
  List<ClinicalActionCatalogOption> options,
  String? apiId,
) {
  return clinicalActionCatalogDisplayLabelById(
    options,
    apiId,
    separator: ' · ',
  );
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

String _admissionJoinDisplay(Iterable<String?> values) {
  return clinicalActionJoinDisplay(values, separator: ' · ');
}
