part of '../pages/patient_registry_page.dart';

Future<void> showPatientDetailDialog(
  BuildContext context,
  WidgetRef ref,
  String patientId,
) async {
  unawaited(
    ref
        .read(patientRegistryControllerProvider.notifier)
        .selectPatient(patientId)
        .then((AppFailure? failure) async {
          if (context.mounted) {
            await _showFailureIfNeeded(context, failure);
          }
        }),
  );

  await showAppDialog<void>(
    context: context,
    builder: (_) => PatientDetailDialog(patientId: patientId),
  );

  if (context.mounted) {
    ref.read(patientRegistryControllerProvider.notifier).clearSelection();
  }
}

class PatientDetailDialog extends ConsumerWidget {
  const PatientDetailDialog({required this.patientId, super.key});

  final String patientId;

  static const AccessRequirement _writeRequirement = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.patientWrite],
  );
  static const AccessRequirement _deleteRequirement = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.patientDelete],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final Result<PatientRegistryState>? result = ref
        .watch(patientRegistryControllerProvider)
        .asData
        ?.value;
    final PatientRegistryState? state = switch (result) {
      ResultSuccess<PatientRegistryState>(value: final value) => value,
      _ => null,
    };
    final PatientDetail? selectedDetail = state?.selectedDetail;
    final PatientDetail? detail = selectedDetail?.patient.id == patientId
        ? selectedDetail
        : null;
    final Patient? cachedPatient = _cachedPatientFromState(state, patientId);
    final bool isLoadingDetail =
        (state?.isRefreshingDetail ?? true) && detail == null;

    if (isLoadingDetail) {
      final String dialogTitle =
          cachedPatient?.effectiveDisplayName ?? l10n.patientsDetailTitle;
      return AppDialog(
        title: Text(dialogTitle),
        icon: const Icon(Icons.assignment_ind_outlined),
        maxWidth: 980,
        scrollable: true,
        content: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: Column(
            key: ValueKey<String>('loading-$patientId'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const LinearProgressIndicator(),
              if (cachedPatient != null) ...<Widget>[
                SizedBox(height: Theme.of(context).spacing.md),
                _PatientListPreviewHeader(patient: cachedPatient),
                const Divider(),
              ],
              SizedBox(
                height: cachedPatient == null ? 320 : null,
                child: cachedPatient == null
                    ? AppWorkspaceStatePanel.loading(
                        title: l10n.patientsDetailLoadingTitle,
                        body: l10n.patientsDetailLoadingBody,
                        minHeight: 320,
                      )
                    : Padding(
                        padding: EdgeInsets.only(
                          top: Theme.of(context).spacing.md,
                        ),
                        child: const AppPatientDetailSkeleton(),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    if (detail == null) {
      final Object? failure = state?.lastFailure;
      return AppDialog(
        title: Text(l10n.patientsDetailTitle),
        icon: const Icon(Icons.assignment_ind_outlined),
        maxWidth: 960,
        scrollable: true,
        content: failure is AppFailure
            ? AppFailureStateView(failure: failure)
            : AppWorkspaceStatePanel.empty(
                title: l10n.patientsNoSelectionTitle,
                body: l10n.patientsNoSelectionBody,
                icon: Icons.badge_outlined,
                minHeight: 320,
              ),
      );
    }

    final Patient patient = detail.patient;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool pharmacyReader = isPharmacyRegistryReader(accessPolicy);
    final bool billingReader = isBillingRegistryReader(accessPolicy);
    final bool hideClinicalSections = pharmacyReader || billingReader;
    return AppDialog(
      title: Text(patient.effectiveDisplayName),
      icon: const Icon(Icons.assignment_ind_outlined),
      maxWidth: 980,
      scrollable: true,
      actions: <Widget>[
        AppAccessActionGate(
          requirement: _writeRequirement,
          builder: (_, bool isAllowed) => AppButton.secondary(
            label: l10n.patientsEditAction,
            leadingIcon: Icons.edit_outlined,
            onPressed: isAllowed
                ? () => _openPatientForm(context, ref, patient)
                : null,
          ),
        ),
        AppAccessActionGate(
          requirement: _deleteRequirement,
          builder: (_, bool isAllowed) => AppButton.tertiary(
            label: l10n.patientsDeleteAction,
            leadingIcon: Icons.delete_outline,
            onPressed: isAllowed
                ? () => _confirmDeletePatient(context, ref, patient)
                : null,
          ),
        ),
      ],
      content: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: Column(
          key: ValueKey<String>('detail-${patient.id}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (state?.isRefreshingDetail ?? false)
              const LinearProgressIndicator(),
            PatientDetailHeader(
              detail: detail,
              referenceData:
                  state?.referenceData ?? const PatientReferenceData(),
            ),
            const Divider(),
            if (!hideClinicalSections) ...<Widget>[
              PatientDetailActiveWorkPanel(
                detail: detail,
                onContinue: (PatientActiveWorkItem item) =>
                    _continuePatientActiveWork(context, ref, detail, item),
              ),
              if (collectPatientActiveWorkItems(detail).isNotEmpty)
                const Divider(),
              PatientDetailQuickActions(
                detail: detail,
                onAction: (PatientQuickAction action) =>
                    _openPatientQuickAction(
                      context,
                      ref,
                      detail.patient,
                      action,
                    ),
              ),
              const Divider(),
            ],
            if (pharmacyReader) ...<Widget>[
              PatientPharmacyContextPanel(detail: detail),
              const Divider(),
            ],
            if (billingReader) ...<Widget>[
              PatientBillingContextPanel(detail: detail),
              const Divider(),
            ],
            if (!billingReader)
              AppExpandableRecordSection<PatientAllergy>(
                title: l10n.patientsAllergiesSectionTitle,
                emptyLabel: l10n.patientsNoAllergies,
                items: detail.allergies,
                initiallyExpanded: true,
                responsiveActionButtons: true,
                itemTitle: (PatientAllergy item) =>
                    '${l10n.patientsAllergiesSectionTitle}: ${item.allergen} (${_apiLabel(item.severity)})',
                addLabel: l10n.patientsAddRelatedAction,
                editLabel: l10n.patientsEditAction,
                deleteLabel: l10n.patientsDeleteAction,
                addRequirement: _writeRequirement,
                editRequirement: _writeRequirement,
                deleteRequirement: _deleteRequirement,
                onAdd: () =>
                    _openRelatedForm<PatientAllergy>(context, ref, detail),
                onEdit: (PatientAllergy item) =>
                    _openRelatedForm(context, ref, detail, item: item),
                onDelete: (PatientAllergy item) =>
                    _confirmDeleteRelated(context, ref, detail, item.id),
              ),
            if (!hideClinicalSections) ...<Widget>[
              AppExpandableRecordSection<PatientIdentifier>(
                title: l10n.patientsIdentifiersSectionTitle,
                emptyLabel: l10n.patientsNoIdentifiers,
                items: detail.identifiers,
                initiallyExpanded: true,
                responsiveActionButtons: true,
                itemTitle: (PatientIdentifier item) =>
                    '${_apiLabel(item.type)}: ${item.value}',
                addLabel: l10n.patientsAddRelatedAction,
                editLabel: l10n.patientsEditAction,
                deleteLabel: l10n.patientsDeleteAction,
                addRequirement: _writeRequirement,
                editRequirement: _writeRequirement,
                deleteRequirement: _deleteRequirement,
                onAdd: () =>
                    _openRelatedForm<PatientIdentifier>(context, ref, detail),
                onEdit: (PatientIdentifier item) =>
                    _openRelatedForm(context, ref, detail, item: item),
                onDelete: (PatientIdentifier item) =>
                    _confirmDeleteRelated(context, ref, detail, item.id),
              ),
              AppExpandableRecordSection<PatientContact>(
                title: l10n.patientsContactsSectionTitle,
                emptyLabel: l10n.patientsNoContacts,
                items: detail.contacts,
                initiallyExpanded: true,
                responsiveActionButtons: true,
                itemTitle: (PatientContact item) =>
                    '${_apiLabel(item.type)}: ${item.value}',
                addLabel: l10n.patientsAddRelatedAction,
                editLabel: l10n.patientsEditAction,
                deleteLabel: l10n.patientsDeleteAction,
                addRequirement: _writeRequirement,
                editRequirement: _writeRequirement,
                deleteRequirement: _deleteRequirement,
                onAdd: () =>
                    _openRelatedForm<PatientContact>(context, ref, detail),
                onEdit: (PatientContact item) =>
                    _openRelatedForm(context, ref, detail, item: item),
                onDelete: (PatientContact item) =>
                    _confirmDeleteRelated(context, ref, detail, item.id),
              ),
              AppExpandableRecordSection<PatientGuardian>(
                title: l10n.patientsGuardiansSectionTitle,
                emptyLabel: l10n.patientsNoGuardians,
                items: detail.guardians,
                initiallyExpanded: true,
                responsiveActionButtons: true,
                itemTitle: (PatientGuardian item) =>
                    '${item.relationship == null ? l10n.patientsGuardiansSectionTitle : _apiLabel(item.relationship!)}: ${item.name}',
                addLabel: l10n.patientsAddRelatedAction,
                editLabel: l10n.patientsEditAction,
                deleteLabel: l10n.patientsDeleteAction,
                addRequirement: _writeRequirement,
                editRequirement: _writeRequirement,
                deleteRequirement: _deleteRequirement,
                onAdd: () =>
                    _openRelatedForm<PatientGuardian>(context, ref, detail),
                onEdit: (PatientGuardian item) =>
                    _openRelatedForm(context, ref, detail, item: item),
                onDelete: (PatientGuardian item) =>
                    _confirmDeleteRelated(context, ref, detail, item.id),
              ),
            ],
            if (!hideClinicalSections)
              AppExpandableRecordSection<PatientMedicalHistory>(
                title: l10n.patientsMedicalHistorySectionTitle,
                emptyLabel: l10n.patientsNoMedicalHistory,
                items: detail.medicalHistories,
                initiallyExpanded: true,
                responsiveActionButtons: true,
                itemTitle: (PatientMedicalHistory item) {
                  final String? date = item.diagnosisDate == null
                      ? null
                      : _formatOptionalDate(context, item.diagnosisDate);
                  return date == null
                      ? item.condition
                      : '${item.condition}: $date';
                },
                addLabel: l10n.patientsAddRelatedAction,
                editLabel: l10n.patientsEditAction,
                deleteLabel: l10n.patientsDeleteAction,
                addRequirement: _writeRequirement,
                editRequirement: _writeRequirement,
                deleteRequirement: _deleteRequirement,
                onAdd: () => _openRelatedForm<PatientMedicalHistory>(
                  context,
                  ref,
                  detail,
                ),
                onEdit: (PatientMedicalHistory item) =>
                    _openRelatedForm(context, ref, detail, item: item),
                onDelete: (PatientMedicalHistory item) =>
                    _confirmDeleteRelated(context, ref, detail, item.id),
              ),
            if (!hideClinicalSections)
              AppExpandableRecordSection<PatientDocument>(
                title: l10n.patientsDocumentsSectionTitle,
                emptyLabel: l10n.patientsNoDocuments,
                items: detail.documents,
                initiallyExpanded: true,
                responsiveActionButtons: true,
                itemTitle: (PatientDocument item) =>
                    '${_apiLabel(item.documentType)}: ${item.fileName ?? item.documentType}',
                addLabel: l10n.patientsAddRelatedAction,
                editLabel: l10n.patientsEditAction,
                deleteLabel: l10n.patientsDeleteAction,
                addRequirement: _writeRequirement,
                editRequirement: _writeRequirement,
                deleteRequirement: _deleteRequirement,
                onAdd: () =>
                    _openRelatedForm<PatientDocument>(context, ref, detail),
                onEdit: (PatientDocument item) =>
                    _openRelatedForm(context, ref, detail, item: item),
                onDelete: (PatientDocument item) =>
                    _confirmDeleteRelated(context, ref, detail, item.id),
              ),
            if (!hideClinicalSections)
              AppExpandableRecordSection<PatientConsent>(
                title: l10n.patientsConsentsSectionTitle,
                emptyLabel: l10n.patientsNoConsents,
                items: detail.consents,
                initiallyExpanded: true,
                responsiveActionButtons: true,
                itemTitle: (PatientConsent item) =>
                    '${_apiLabel(item.consentType)}: ${_apiLabel(item.status)}',
                addLabel: l10n.patientsAddRelatedAction,
                editLabel: l10n.patientsEditAction,
                deleteLabel: l10n.patientsDeleteAction,
                addRequirement: _writeRequirement,
                editRequirement: _writeRequirement,
                deleteRequirement: _deleteRequirement,
                onAdd: () =>
                    _openRelatedForm<PatientConsent>(context, ref, detail),
                onEdit: (PatientConsent item) =>
                    _openRelatedForm(context, ref, detail, item: item),
                onDelete: (PatientConsent item) =>
                    _confirmDeleteRelated(context, ref, detail, item.id),
              ),
            if (!hideClinicalSections)
              PatientTimelineList(items: detail.timeline),
          ],
        ),
      ),
    );
  }

  Future<void> _openPatientForm(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PatientFormDialog(
        patient: patient,
        referenceData:
            _readCurrentState(ref)?.referenceData ??
            const PatientReferenceData(),
        onSubmit: (Map<String, Object?> payload) {
          return ref
              .read(patientRegistryControllerProvider.notifier)
              .updatePatient(patient.id, payload);
        },
      ),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.patientsSavedMessage)),
      );
    }
  }

  Future<void> _confirmDeletePatient(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) async {
    final bool? confirmed = await _showDeleteDialog(
      context,
      title: context.l10n.patientsDeleteTitle,
      body: context.l10n.patientsDeleteBody(patient.effectiveDisplayName),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final AppFailure? failure = await ref
        .read(patientRegistryControllerProvider.notifier)
        .deletePatient(patient.id);
    if (context.mounted && failure == null) {
      final NavigatorState navigator = Navigator.of(context);
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      final String message = context.l10n.patientsDeletedMessage;
      await navigator.maybePop();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } else if (context.mounted) {
      await _showFailureIfNeeded(context, failure);
    }
  }

  Future<void> _openRelatedForm<T>(
    BuildContext context,
    WidgetRef ref,
    PatientDetail detail, {
    T? item,
  }) async {
    final PatientRelatedResource resource = _resourceForItem<T>(item);
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PatientRelatedRecordDialog<T>(
        detail: detail,
        resource: resource,
        item: item,
        referenceData:
            _readCurrentState(ref)?.referenceData ??
            const PatientReferenceData(),
        onCreate: (Map<String, Object?> payload) {
          return ref
              .read(patientRegistryControllerProvider.notifier)
              .createRelatedRecord(resource, payload);
        },
        onUpdate: (String recordId, Map<String, Object?> payload) {
          return ref
              .read(patientRegistryControllerProvider.notifier)
              .updateRelatedRecord(resource, recordId, payload);
        },
        onUploadDocuments:
            ({
              required String patientId,
              required String documentType,
              required List<PatientDocumentUploadFile> files,
            }) {
              return ref
                  .read(patientRegistryControllerProvider.notifier)
                  .uploadPatientDocuments(
                    patientId: patientId,
                    documentType: documentType,
                    files: files,
                  );
            },
      ),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.patientsSavedMessage)),
      );
    }
  }

  Future<void> _confirmDeleteRelated(
    BuildContext context,
    WidgetRef ref,
    PatientDetail detail,
    String recordId,
  ) async {
    final bool? confirmed = await _showDeleteDialog(
      context,
      title: context.l10n.patientsRelatedDeleteTitle,
      body: context.l10n.patientsRelatedDeleteBody,
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final PatientRelatedResource resource = _resourceForRecordId(
      detail,
      recordId,
    );
    final AppFailure? failure = await ref
        .read(patientRegistryControllerProvider.notifier)
        .deleteRelatedRecord(resource, recordId);
    if (context.mounted && failure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.patientsDeletedMessage)),
      );
    } else if (context.mounted) {
      await _showFailureIfNeeded(context, failure);
    }
  }
}

class _PatientListPreviewHeader extends StatelessWidget {
  const _PatientListPreviewHeader({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String gender = patient.gender == null
        ? l10n.profileUnknownValue
        : _genderLabel(l10n, patient.gender!);
    final String demographics = _joinDisplay(<String?>[
      _patientAgeLabel(context, patient.dateOfBirth),
      gender,
    ]);
    final PatientVisitContext? visit = patient.currentVisit;

    return AppWorkspacePatientContextHeader(
      patientName: patient.effectiveDisplayName,
      showPatientName: false,
      patientNumber: patient.effectiveIdentifier ?? '',
      demographics: demographics,
      semanticLabel: l10n.patientsDetailTitle,
      status: AppWorkspaceStatus(
        label: patient.isActive
            ? l10n.patientsActiveFilter
            : l10n.patientsInactiveFilter,
        tone: patient.isActive
            ? AppWorkspaceStatusTone.success
            : AppWorkspaceStatusTone.neutral,
        icon: patient.isActive
            ? Icons.check_circle_outline
            : Icons.block_outlined,
      ),
      alerts: <AppWorkspaceStatus>[
        if (patient.hasAllergyAlert)
          AppWorkspaceStatus(
            label: patient.allergyAlertLabel ?? l10n.patientsAllergyAlertLabel,
            tone: AppWorkspaceStatusTone.warning,
            icon: Icons.warning_amber_outlined,
          ),
        if (patient.requiresCompletion)
          AppWorkspaceStatus(
            label: l10n.patientsRegistrationIncompleteValue,
            tone: AppWorkspaceStatusTone.warning,
            icon: Icons.error_outline,
          ),
      ],
      fieldStyle: AppWorkspacePatientContextFieldStyle.inline,
      fields: <AppWorkspacePatientContextField>[
        AppWorkspacePatientContextField(
          label: l10n.patientsDobLabel,
          value: _formatOptionalDate(context, patient.dateOfBirth),
          icon: Icons.cake_outlined,
        ),
        AppWorkspacePatientContextField(
          label: l10n.patientsPhoneLabel,
          value: patient.primaryPhone ?? '',
          icon: Icons.phone_outlined,
        ),
        AppWorkspacePatientContextField(
          label: l10n.patientsFacilityLabel,
          value: patient.facilityLabel ?? '',
          icon: Icons.business_outlined,
        ),
        if (visit != null)
          AppWorkspacePatientContextField(
            label: l10n.patientsVisitColumnLabel,
            value: visit.publicId ?? '',
            icon: Icons.assignment_turned_in_outlined,
            tone: AppWorkspaceStatusTone.info,
            copyable: true,
            copyTooltip: l10n.copyIdentifierAction,
            copiedMessage: l10n.identifierCopiedMessage,
          ),
      ],
    );
  }
}
