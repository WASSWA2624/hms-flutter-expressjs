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
    registry = ref.read(patientRegistryControllerProvider).asData?.value.when(
      success: (PatientRegistryState state) => state,
      failure: (_) => null,
    );
  }
  if (registry == null || !context.mounted) {
    return false;
  }

  final bool? saved = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PatientAppointmentQuickDialog(
      patient: selected,
      referenceData: registry!.referenceData,
    ),
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
        setState(() {
          _patients = page.items;
          _isLoading = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _patients = const <Patient>[];
          _isLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      title: Text(l10n.receptionScheduleAppointmentAction),
      icon: const Icon(Icons.event_available_outlined),
      scrollable: true,
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
            prefixIcon: const Icon(Icons.search),
            onChanged: (String value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 250), () {
                unawaited(_search(value));
              });
            },
          ),
          if (_isLoading) const LinearProgressIndicator(),
          if (!_isLoading && _patients.isEmpty)
            Text(
              l10n.receptionPatientPickerEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ..._patients.map(
              (Patient patient) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(patient.effectiveDisplayName),
                subtitle: Text(
                  patient.publicId ?? patient.id,
                  style: theme.textTheme.bodySmall,
                ),
                onTap: () => Navigator.of(context).pop(patient),
              ),
            ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
