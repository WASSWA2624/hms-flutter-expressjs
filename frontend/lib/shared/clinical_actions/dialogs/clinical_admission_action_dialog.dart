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
    this.maxWidth = 900,
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
  final double maxWidth;
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
      title: Text(widget.title ?? l10n.clinicalRequestAdmissionAction),
      icon: widget.icon,
      closeEnabled: !_isSaving,
      maxWidth: widget.maxWidth,
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            ...?widget.leadingSectionsBuilder?.call(context, !_isSaving),
            AppFormSection(
              title: l10n.clinicalAdmissionDetailsTitle,
              children: <Widget>[
                if (_failure != null)
                  AppFormInformationBanner.failure(
                    context: context,
                    failure: _failure!,
                  ),
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
                          !_isSaving &&
                          _wardId != null &&
                          roomOptions.isNotEmpty,
                      isRequired: true,
                      menuHeight: 280,
                      options: roomOptions,
                      validator: AppValidators.requiredValue<String>(
                        l10n.validationRequired,
                      ),
                      onChanged: _handleRoomChanged,
                    ),
                  ),
                  if (_wardId != null && roomOptions.isEmpty)
                    AppFormInformationBanner.message(
                      message: l10n.clinicalAdmissionNoRoomsMessage,
                      icon: Icons.meeting_room_outlined,
                    ),
                  AppSelectField<String>.searchable(
                    value: _bedId,
                    labelText: l10n.clinicalAdmissionBedLabel,
                    enabled:
                        !_isSaving && _roomId != null && bedOptions.isNotEmpty,
                    isRequired: true,
                    menuHeight: 320,
                    options: bedOptions,
                    validator: AppValidators.requiredValue<String>(
                      l10n.validationRequired,
                    ),
                    onChanged: (String? value) =>
                        _handleBedChanged(value, availableBeds),
                  ),
                  if (_roomId != null && bedOptions.isEmpty)
                    AppFormInformationBanner.message(
                      message: l10n.clinicalAdmissionNoBedsForRoomMessage,
                      icon: Icons.bed_outlined,
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
                      selectedBed,
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
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        widget.submitLabel ?? l10n.clinicalRequestAdmissionAction,
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
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
  ClinicalActionReferenceData referenceData,
  ClinicalActionCatalogOption? bed,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppInfoTileData>[
    AppInfoTileData(
      label: l10n.clinicalAdmissionWardLabel,
      value: bed == null
          ? null
          : _admissionCatalogDisplayLabelById(
              referenceData.wards,
              bed.parentId,
            ),
      icon: Icons.apartment_outlined,
    ),
    AppInfoTileData(
      label: l10n.clinicalAdmissionRoomLabel,
      value: bed == null
          ? null
          : _admissionCatalogDisplayLabelById(
              referenceData.rooms,
              bed.secondaryId,
            ),
      icon: Icons.meeting_room_outlined,
    ),
    AppInfoTileData(
      label: l10n.clinicalAdmissionBedLabel,
      value: bed?.displayTitle,
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
