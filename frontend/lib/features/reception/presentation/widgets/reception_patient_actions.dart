import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/claims/data/repositories/claims_repository_impl.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/presentation/widgets/claims_insurance_config_dialogs.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/controllers/patient_registry_controller.dart';
import 'package:hosspi_hms/features/patients/presentation/pages/patient_registry_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

Future<void> openReceptionPatientEditor(
  BuildContext context,
  WidgetRef ref,
  String patientId,
) {
  return showPatientDetailDialog(context, ref, patientId);
}

Future<bool> openReceptionInsuranceCapture({
  required BuildContext context,
  required WidgetRef ref,
  required String patientId,
}) async {
  final Result<ClaimsReferenceData> lookups = await ref
      .read(claimsRepositoryProvider)
      .loadReferenceData();
  if (!context.mounted) {
    return false;
  }
  final ClaimsReferenceData? referenceData = lookups.when(
    success: (ClaimsReferenceData value) => value,
    failure: (_) => null,
  );
  if (referenceData == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.receptionInsuranceLookupFailed)),
    );
    return false;
  }
  await openClaimsEnrollmentDialog(
    context: context,
    ref: ref,
    referenceData: referenceData,
    patientId: patientId,
  );
  return true;
}

Future<bool> openReceptionScheduleAppointment({
  required BuildContext context,
  required WidgetRef ref,
  Patient? patient,
}) async {
  final Patient? selected =
      patient ??
      await showAppDialog<Patient>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ReceptionPatientPickerDialog(),
      );
  if (selected == null || !context.mounted) {
    return false;
  }

  final AsyncValue<Result<PatientRegistryState>> registryAsync = ref.read(
    patientRegistryControllerProvider,
  );
  PatientRegistryState? registry = registryAsync.asData?.value.when(
    success: (PatientRegistryState state) => state,
    failure: (_) => null,
  );
  if (registry == null) {
    final AppFailure? failure = await ref
        .read(patientRegistryControllerProvider.notifier)
        .refresh();
    if (!context.mounted) {
      return false;
    }
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failureMessage(failure))),
      );
      return false;
    }
    registry = ref
        .read(patientRegistryControllerProvider)
        .asData
        ?.value
        .when(
          success: (PatientRegistryState state) => state,
          failure: (_) => null,
        );
  }
  if (registry == null || !context.mounted) {
    return false;
  }

  final bool? saved = await showPatientAppointmentQuickDialog(
    context: context,
    patient: selected,
    referenceData: registry.referenceData,
  );
  return saved == true;
}

class _ReceptionPatientPickerDialog extends ConsumerStatefulWidget {
  const _ReceptionPatientPickerDialog();

  @override
  ConsumerState<_ReceptionPatientPickerDialog> createState() =>
      _ReceptionPatientPickerDialogState();
}

class _ReceptionPatientPickerDialogState
    extends ConsumerState<_ReceptionPatientPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  AppFailure? _failure;
  List<Patient> _patients = const <Patient>[];
  Patient? _selected;

  @override
  void initState() {
    super.initState();
    unawaited(_search(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String raw) async {
    setState(() {
      _isLoading = true;
      _failure = null;
    });
    final Result<AppPage<Patient>> result = await ref
        .read(patientRegistryControllerProvider.notifier)
        .loadPatientPage(
          PatientListQuery(
            search: raw.trim(),
            pageRequest: const AppPageRequest(pageSize: 12),
          ),
        );
    if (!mounted) {
      return;
    }
    result.when(
      success: (AppPage<Patient> page) {
        final String? selectedId = _selected?.id;
        Patient? nextSelected;
        if (selectedId != null) {
          for (final Patient patient in page.items) {
            if (patient.id == selectedId) {
              nextSelected = patient;
              break;
            }
          }
        }
        setState(() {
          _patients = page.items;
          _selected = nextSelected;
          _isLoading = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _patients = const <Patient>[];
          _selected = null;
          _isLoading = false;
        });
      },
    );
  }

  void _confirmSelection() {
    final Patient? selected = _selected;
    if (_isLoading || selected == null) {
      return;
    }
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool canConfirm = !_isLoading && _selected != null;

    return AppDialog(
      title: Text(l10n.receptionPatientPickerTitle),
      icon: const Icon(AppActionIcons.person),
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !_isLoading,
      maxWidth: 560,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          AppTextField(
            controller: _searchController,
            labelText: l10n.receptionPatientPickerSearchHint,
            prefixIcon: const Icon(AppActionIcons.search),
            onChanged: (String value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 250), () {
                unawaited(_search(value));
              });
            },
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: AppLoadingIndicator.compact()),
            )
          else if (_patients.isEmpty)
            Text(
              l10n.receptionPatientPickerEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ..._patients.map((Patient patient) {
              final bool selected = _selected?.id == patient.id;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                selected: selected,
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(patient.effectiveDisplayName),
                subtitle: Text(
                  patient.publicId ?? patient.id,
                  style: theme.textTheme.bodySmall,
                ),
                onTap: () {
                  setState(() {
                    _selected = patient;
                  });
                },
              );
            }),
        ],
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: AppActionIcons.cancel,
          enabled: !_isLoading,
          onPressed: _isLoading
              ? null
              : () => Navigator.of(context).maybePop(),
        ),
        AppButton.primary(
          label: l10n.commonSelectActionLabel,
          leadingIcon: AppActionIcons.person,
          enabled: canConfirm,
          onPressed: canConfirm ? _confirmSelection : null,
        ),
      ],
    );
  }
}
