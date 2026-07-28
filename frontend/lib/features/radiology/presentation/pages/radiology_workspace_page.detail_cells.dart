part of 'radiology_workspace_page.dart';

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.maxLines = 2,
  });

  final String label;
  final String? value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String resolvedValue = _valueOrUnknown(context, value);
    final bool isPlaceholder =
        resolvedValue == context.l10n.profileUnknownValue;

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 118,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Text(
              resolvedValue,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: isPlaceholder
                  ? theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w400,
                    )
                  : theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModalityLabel extends StatelessWidget {
  const _ModalityLabel({required this.modality});

  final String? modality;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    return Row(
      children: <Widget>[
        Icon(
          _radiologyModalityIcon(modality),
          size: theme.appTokens.listIconSize,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: theme.spacing.xs),
        Expanded(
          child: Text(
            _modalityLabelOrNull(l10n, modality) ?? l10n.profileUnknownValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

void _showMutationResult(BuildContext context, AppFailure? failure) {
  if (!context.mounted) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null
            ? l10n.radiologySavedMessage
            : l10n.failureMessage(failure),
      ),
    ),
  );
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  showAppFailureSnackBar(context, failure);
}

AppWorkspaceStatus _orderStatus(BuildContext context, RadiologyOrder order) {
  final AppLocalizations l10n = context.l10n;
  return AppWorkspaceStatus(
    label: _orderStatusLabel(l10n, order.status),
    tone: _orderStatusTone(order.status),
    icon: _orderStatusIcon(order.status),
  );
}

AppWorkspaceStatus _resultStatus(BuildContext context, RadiologyResult result) {
  final AppLocalizations l10n = context.l10n;
  return AppWorkspaceStatus(
    label: _resultStatusLabel(l10n, result.status),
    tone: _resultStatusTone(result.status),
    icon: result.isReleased
        ? Icons.verified_outlined
        : Icons.description_outlined,
  );
}

String _stageFilterLabel(AppLocalizations l10n, String? stage) {
  return switch ((stage ?? '').trim().toUpperCase()) {
    'ALL' => l10n.radiologyStageAll,
    'ORDERED' => l10n.radiologyStageOrdered,
    'PROCESSING' => l10n.radiologyStageProcessing,
    'REPORTING' => l10n.radiologyStageReporting,
    'COMPLETED' => l10n.radiologyStageCompleted,
    'CANCELLED' => l10n.radiologyStageCancelled,
    _ => l10n.profileUnknownValue,
  };
}

String _orderStatusLabel(AppLocalizations l10n, String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'ORDERED' => l10n.radiologyStatusOrdered,
    'IN_PROCESS' => l10n.radiologyStatusInProcess,
    'COMPLETED' => l10n.radiologyStatusCompleted,
    'CANCELLED' => l10n.radiologyStatusCancelled,
    _ => l10n.profileUnknownValue,
  };
}

String _resultStatusLabel(AppLocalizations l10n, String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'DRAFT' => l10n.radiologyResultDraft,
    'FINAL' => l10n.radiologyResultFinal,
    'AMENDED' => l10n.radiologyResultAmended,
    _ => l10n.profileUnknownValue,
  };
}

String _modalityLabel(AppLocalizations l10n, String? modality) {
  return switch ((modality ?? '').trim().toUpperCase()) {
    'XRAY' || 'X_RAY' || 'X-RAY' => l10n.radiologyModalityXray,
    'CT' => l10n.radiologyModalityCt,
    'MRI' => l10n.radiologyModalityMri,
    'ULTRASOUND' => l10n.radiologyModalityUltrasound,
    'FLUOROSCOPY' => l10n.radiologyModalityFluoroscopy,
    'MAMMOGRAPHY' => l10n.radiologyModalityMammography,
    'NUCLEAR_MEDICINE' ||
    'NUCLEAR MEDICINE' => l10n.radiologyModalityNuclearMedicine,
    'INTERVENTIONAL_RADIOLOGY' ||
    'INTERVENTIONAL RADIOLOGY' => l10n.radiologyModalityInterventionalRadiology,
    'PET' => l10n.radiologyModalityPet,
    'ECG' => l10n.radiologyModalityEcg,
    'ECHO' => l10n.radiologyModalityEcho,
    'ENDO' => l10n.radiologyModalityEndo,
    'GASTRO' => l10n.radiologyModalityGastro,
    'OTHER' => l10n.radiologyModalityOther,
    _ => l10n.profileUnknownValue,
  };
}

String? _modalityLabelOrNull(AppLocalizations l10n, String? modality) {
  final String normalized = modality?.trim() ?? '';
  return normalized.isEmpty ? null : _modalityLabel(l10n, normalized);
}

IconData _radiologyModalityIcon(String? modality) {
  return switch ((modality ?? '').trim().toUpperCase()) {
    'XRAY' || 'X_RAY' || 'X-RAY' => Icons.photo_camera_outlined,
    'CT' => Icons.donut_large_outlined,
    'MRI' => Icons.all_out_outlined,
    'ULTRASOUND' || 'US' => Icons.graphic_eq_outlined,
    'FLUOROSCOPY' => Icons.video_camera_back_outlined,
    'MAMMOGRAPHY' => Icons.image_search_outlined,
    'PET' => Icons.blur_on_outlined,
    'NUCLEAR_MEDICINE' || 'NUCLEAR MEDICINE' => Icons.radio_button_checked,
    'INTERVENTIONAL_RADIOLOGY' ||
    'INTERVENTIONAL RADIOLOGY' => Icons.medical_services_outlined,
    'ECG' => Icons.monitor_heart_outlined,
    'ECHO' => Icons.favorite_border,
    'ENDO' || 'GASTRO' => Icons.biotech_outlined,
    'OTHER' => Icons.image_search_outlined,
    _ => Icons.image_search_outlined,
  };
}

String _activeOrderCountLabel(AppLocalizations l10n, int count) {
  return count == 1
      ? l10n.radiologyOneActiveOrderLabel
      : l10n.radiologyActiveOrdersLabel(count);
}

List<ClinicalActionCatalogOption> _radiologyCatalogOptions(
  RadiologyWorkspaceState? state,
) {
  final List<RadiologyCatalogProcedure> catalogTests =
      state?.catalogTests ?? const <RadiologyCatalogProcedure>[];
  if (catalogTests.isNotEmpty) {
    return <ClinicalActionCatalogOption>[
      for (final RadiologyCatalogProcedure test in catalogTests)
        ClinicalActionCatalogOption(
          id: test.id,
          publicId: test.effectiveId,
          name: test.name,
          code: test.code,
          unitPrice: test.unitPrice,
          currency: test.currency,
          category: test.modality,
          secondaryText: _joinDisplay(<String?>[
            test.bodyRegion,
            test.laterality,
            test.procedureType,
            test.equipment,
          ]),
          status: test.status,
          searchText: _joinDisplay(<String?>[
            test.searchText,
            test.name,
            test.code,
            test.modality,
            test.bodyRegion,
            test.laterality,
            test.procedureType,
            test.equipment,
          ]),
          metadata: <String, Object?>{
            'modality': test.modality,
            'body_region': test.bodyRegion,
            'laterality': test.laterality,
            'procedure_type': test.procedureType,
            'equipment': test.equipment,
            'source': test.source,
          },
        ),
    ];
  }

  final List<RadiologyReferenceOption> references =
      state?.references.radiologyProcedures ?? const <RadiologyReferenceOption>[];
  return <ClinicalActionCatalogOption>[
    for (final RadiologyReferenceOption option in references)
      ClinicalActionCatalogOption(
        id: option.value,
        publicId: option.value,
        name: option.label,
        secondaryText: option.subtitle,
        searchText: option.displayLabel,
      ),
  ];
}

const String _radiologyStageFilterKey = 'stage';
const String _radiologyStatusFilterKey = 'status';
const String _radiologyModalityFilterKey = 'modality';
const String _radiologyPriorityFilterKey = 'priority';
const String _radiologyBillingGateFilterKey = 'billing_gate';

Widget _radiologyWorklistTextCell(BuildContext context, String? value) {
  final ThemeData theme = Theme.of(context);
  return Text(
    _valueOrUnknown(context, value),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: theme.textTheme.bodyMedium,
  );
}

String _radiologyStudyLabel(RadiologyOrder item, AppLocalizations l10n) {
  return item.testsSummary ?? item.testDisplayName ?? l10n.profileUnknownValue;
}

AppSearchBarFilterValue _radiologyFilterValue(RadiologyWorkspaceQuery query) {
  return AppSearchBarFilterValue(
    dateFrom: query.from,
    options: <String, String>{
      if (query.stage != 'ALL') _radiologyStageFilterKey: query.stage,
      if (query.status != null) _radiologyStatusFilterKey: query.status!,
      if (query.modality != null) _radiologyModalityFilterKey: query.modality!,
      if (query.priority != null) _radiologyPriorityFilterKey: query.priority!,
      if (query.billingGate != null)
        _radiologyBillingGateFilterKey: query.billingGate!,
    },
  );
}

bool _hasRadiologyFilters(RadiologyWorkspaceQuery query) {
  return query.stage != 'ALL' ||
      query.status != null ||
      query.modality != null ||
      query.priority != null ||
      query.billingGate != null ||
      query.from != null;
}

List<AppSearchBarFilterChoice> _radiologyStageFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    for (final String stage in radiologyStageFilters)
      if (stage != 'ALL')
        AppSearchBarFilterChoice(
          value: stage,
          label: _stageFilterLabel(l10n, stage),
          icon: Icons.timeline_outlined,
        ),
  ];
}

List<AppSearchBarFilterChoice> _radiologyStatusFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    for (final String status in radiologyOrderStatuses)
      AppSearchBarFilterChoice(
        value: status,
        label: _orderStatusLabel(l10n, status),
        icon: Icons.task_alt_outlined,
      ),
  ];
}

List<AppSearchBarFilterChoice> _radiologyModalityFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    for (final String modality in radiologyModalities)
      AppSearchBarFilterChoice(
        value: modality,
        label: _modalityLabel(l10n, modality),
        icon: _radiologyModalityIcon(modality),
      ),
  ];
}

List<AppSearchBarFilterChoice> _radiologyPriorityFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    for (final String priority in radiologyPriorities)
      AppSearchBarFilterChoice(
        value: priority,
        label: _radiologyPriorityDisplayLabel(l10n, priority) ?? priority,
        icon: Icons.priority_high_outlined,
      ),
  ];
}

List<AppSearchBarFilterChoice> _radiologyBillingGateFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: 'AWAITING',
      label: l10n.radiologyBillingGateAwaitingLabel,
      icon: Icons.receipt_long_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'CONFIRMED',
      label: l10n.radiologyBillingGateConfirmedLabel,
      icon: Icons.verified_outlined,
    ),
  ];
}

bool _isSameFilterDate(DateTime? left, DateTime? right) {
  if (left == null || right == null) {
    return left == null && right == null;
  }
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

bool _radiologyWorklistSearchMatcher(
  BuildContext context,
  RadiologyOrder item,
  String query,
) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }

  final AppLocalizations l10n = context.l10n;
  final int activeOrders = item.activeOrderCount > 0
      ? item.activeOrderCount
      : item.orderCount;
  final Iterable<String?> values = <String?>[
    item.patientDisplayName,
    item.patientId,
    item.effectiveDisplayId,
    item.displayId,
    item.id,
    item.testsSummary,
    item.testDisplayName,
    item.modality,
    _modalityLabelOrNull(l10n, item.modality),
    _orderStatusLabel(l10n, item.status),
    _radiologyPriorityDisplayLabel(l10n, item.priority),
    _billingGateLabel(context, item),
    _nextActionLabel(context, item),
    item.bodyRegion,
    item.laterality,
    item.encounterId,
    _formatDateTimeOrNull(context, item.orderedAt),
    if (item.isPatientGroup) _activeOrderCountLabel(l10n, activeOrders),
  ];

  return values.any(
    (String? value) => (value ?? '').trim().toLowerCase().contains(needle),
  );
}

String _nextActionLabel(BuildContext context, RadiologyOrder order) {
  final AppLocalizations l10n = context.l10n;
  if (order.normalizedStatus == 'CANCELLED') {
    return l10n.radiologyStatusCancelled;
  }
  if (!order.hasBillingGate) {
    return l10n.radiologyNextActionConfirmBilling;
  }
  if (order.normalizedStatus == 'ORDERED') {
    return l10n.radiologyNextActionStartImaging;
  }
  if (order.normalizedStatus == 'IN_PROCESS' && order.studyCount == 0) {
    return l10n.radiologyNextActionPerformStudy;
  }
  if (order.hasDraftResult) {
    return l10n.radiologyNextActionReleaseReport;
  }
  if (order.hasFinalResult) {
    return l10n.radiologyNextActionDoctorReview;
  }
  if (order.normalizedStatus == 'COMPLETED') {
    return l10n.radiologyNextActionDoctorReview;
  }
  return l10n.radiologyNextActionReportPending;
}

String _billingGateLabel(BuildContext context, RadiologyOrder order) {
  final AppLocalizations l10n = context.l10n;
  if (!order.hasBillingGate) {
    return l10n.radiologyBillingGateUnavailable;
  }

  return _joinDisplay(<String?>[
    order.effectivePaymentStatus,
    order.authorizationStatus,
  ]).ifEmpty(l10n.profileUnknownValue);
}

AppWorkspaceStatusTone _billingGateTone(RadiologyOrder order) {
  if (!order.hasBillingGate) {
    return AppWorkspaceStatusTone.warning;
  }

  final String payment = (order.effectivePaymentStatus ?? '')
      .trim()
      .toUpperCase();
  return switch (payment) {
    'PAID' || 'CONFIRMED' => AppWorkspaceStatusTone.success,
    'PARTIAL' || 'UNPAID' || 'AWAITING' => AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatusTone _orderStatusTone(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'COMPLETED' => AppWorkspaceStatusTone.success,
    'CANCELLED' => AppWorkspaceStatusTone.error,
    'IN_PROCESS' => AppWorkspaceStatusTone.info,
    'ORDERED' => AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatusTone _resultStatusTone(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'FINAL' || 'AMENDED' => AppWorkspaceStatusTone.success,
    'DRAFT' => AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

IconData _orderStatusIcon(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'COMPLETED' => Icons.check_circle_outline,
    'CANCELLED' => Icons.cancel_outlined,
    'IN_PROCESS' => Icons.play_circle_outline,
    'ORDERED' => Icons.pending_actions_outlined,
    _ => Icons.radio_button_unchecked,
  };
}

String? _formatDateTimeOrNull(BuildContext context, DateTime? value) {
  return value == null
      ? null
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String? _trimmedOrNull(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

String _valueOrUnknown(BuildContext context, String? value) {
  return (value ?? '').trim().ifEmpty(context.l10n.profileUnknownValue);
}

String _joinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

String _composeRadiologyReportText({
  required String findings,
  required String impression,
  required String narrative,
}) {
  if (narrative.isNotEmpty) {
    return narrative;
  }
  return _joinDisplay(<String?>[findings, impression]);
}

extension on String {
  String ifEmpty(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}
