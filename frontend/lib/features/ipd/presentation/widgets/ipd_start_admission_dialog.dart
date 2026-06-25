import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Admission-desk dialog to start a new IPD admission (flow §2/§3).
class IpdStartAdmissionDialog extends ConsumerStatefulWidget {
  const IpdStartAdmissionDialog({required this.referenceData, super.key});

  final IpdReferenceData referenceData;

  @override
  ConsumerState<IpdStartAdmissionDialog> createState() =>
      _IpdStartAdmissionDialogState();
}

class _IpdStartAdmissionDialogState
    extends ConsumerState<IpdStartAdmissionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _searchController;
  Timer? _debounce;

  List<Patient> _results = <Patient>[];
  Patient? _selectedPatient;
  String? _wardId;
  String? _bedId;
  bool _isSearching = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_runSearch(value));
    });
  }

  Future<void> _runSearch(String value) async {
    final String term = value.trim();
    if (term.length < 2) {
      setState(() {
        _results = <Patient>[];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    final Result<AppPage<Patient>> result = await ref
        .read(patientRepositoryProvider)
        .listPatients(
          PatientListQuery(
            search: term,
            pageRequest: const AppPageRequest(pageSize: 12),
          ),
        );
    if (!mounted) {
      return;
    }
    result.when(
      success: (AppPage<Patient> page) {
        setState(() {
          _results = page.items;
          _isSearching = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _results = <Patient>[];
          _isSearching = false;
          _failure = failure;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      title: Text(l10n.ipdStartAdmissionTitle),
      icon: const Icon(Icons.person_add_alt_1_outlined),
      scrollable: true,
      maxWidth: 560,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _searchController,
              labelText: l10n.ipdStartAdmissionPatientLabel,
              hintText: l10n.ipdStartAdmissionPatientHint,
              enabled: !_isSaving,
              prefixIcon: const Icon(Icons.search),
              onChanged: _onSearchChanged,
            ),
            if (_selectedPatient != null)
              _SelectedPatientTile(
                patient: _selectedPatient!,
                onClear: _isSaving
                    ? null
                    : () => setState(() => _selectedPatient = null),
              )
            else if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_results.isEmpty &&
                _searchController.text.trim().length >= 2)
              Padding(
                padding: EdgeInsets.all(theme.spacing.sm),
                child: Text(
                  l10n.ipdStartAdmissionNoPatients,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final Patient patient in _results)
                    _PatientResultTile(
                      patient: patient,
                      onTap: () => setState(() {
                        _selectedPatient = patient;
                        _results = <Patient>[];
                      }),
                    ),
                ],
              ),
            AppSelectField<String>.searchable(
              value: _wardId,
              labelText: l10n.ipdStartAdmissionWardLabel,
              hintText: l10n.ipdSelectWardHint,
              enabled: !_isSaving,
              options: <AppSelectOption<String>>[
                for (final IpdWardOption ward in widget.referenceData.wards)
                  AppSelectOption<String>(
                    value: ward.id,
                    label: ward.displayTitle,
                  ),
              ],
              onChanged: (String? value) => setState(() {
                _wardId = value;
                _bedId = null;
              }),
            ),
            AppSelectField<String>.searchable(
              value: _bedId,
              labelText: l10n.ipdStartAdmissionBedLabel,
              hintText: l10n.ipdSelectBedHint,
              enabled: !_isSaving,
              options: <AppSelectOption<String>>[
                for (final IpdBedOption bed in _bedsForWard())
                  AppSelectOption<String>(
                    value: bed.id,
                    label: <String?>[bed.displayTitle, bed.displaySubtitle]
                        .where((String? v) => v != null && v.trim().isNotEmpty)
                        .join(' • '),
                  ),
              ],
              onChanged: (String? value) => setState(() => _bedId = value),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.ipdStartAdmissionAction,
          leadingIcon: Icons.person_add_alt_1_outlined,
          isLoading: _isSaving,
          enabled: _selectedPatient != null && !_isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  List<IpdBedOption> _bedsForWard() {
    final List<IpdBedOption> beds = widget.referenceData.availableBeds;
    if (_wardId == null) {
      return beds;
    }
    return beds
        .where((IpdBedOption bed) => bed.wardId == _wardId)
        .toList(growable: false);
  }

  Future<void> _submit() async {
    final Patient? patient = _selectedPatient;
    if (patient == null) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(ipdWorkspaceControllerProvider.notifier)
        .startAdmission(<String, Object?>{
          'patient_id': patient.id,
          'ward_id': _wardId,
          'bed_id': _bedId,
        });
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

class _PatientResultTile extends StatelessWidget {
  const _PatientResultTile({required this.patient, required this.onTap});

  final Patient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: theme.spacing.sm,
          horizontal: theme.spacing.xs,
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.person_outline, size: 20),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    patient.effectiveDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if ((patient.effectiveIdentifier ?? '').trim().isNotEmpty)
                    Text(
                      patient.effectiveIdentifier!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedPatientTile extends StatelessWidget {
  const _SelectedPatientTile({required this.patient, required this.onClear});

  final Patient patient;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary),
        borderRadius: BorderRadius.circular(theme.radius.md),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.check_circle,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    patient.effectiveDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if ((patient.effectiveIdentifier ?? '').trim().isNotEmpty)
                    Text(
                      patient.effectiveIdentifier!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (onClear != null)
              AppIconButton(
                icon: Icons.close,
                semanticLabel: context.l10n.commonCancelActionLabel,
                tooltip: context.l10n.commonCancelActionLabel,
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}
