part of 'radiology_workspace_page.dart';

class _RadiologyReportReference {
  const _RadiologyReportReference({
    required this.label,
    required this.text,
    required this.icon,
  });

  final String label;
  final String text;
  final IconData icon;
}

List<_RadiologyReportReference> _radiologyReportReferences(
  AppLocalizations l10n,
  RadiologyOrder order,
) {
  final List<_RadiologyReportReference> references =
      <_RadiologyReportReference>[];
  for (final ImagingStudy study in order.imagingStudies) {
    for (final ImagingAsset asset in study.assets) {
      final String label =
          asset.fileName ??
          asset.displayId ??
          asset.storageKey ??
          study.effectiveDisplayId;
      references.add(
        _RadiologyReportReference(
          label: l10n.radiologyInsertAssetReferenceAction(label),
          text: '${l10n.radiologyAssetReferencePrefix}: $label',
          icon: Icons.image_outlined,
        ),
      );
    }
    for (final PacsLink link in study.pacsLinks) {
      final String label =
          link.url ?? link.displayId ?? study.effectiveDisplayId;
      references.add(
        _RadiologyReportReference(
          label: l10n.radiologyInsertPacsReferenceAction(label),
          text: '${l10n.radiologyPacsReferencePrefix}: $label',
          icon: Icons.cloud_outlined,
        ),
      );
    }
  }
  return references;
}

Future<void> _showRadiologyPrintDialog(
  BuildContext context,
  RadiologyWorkflow workflow,
) async {
  await showAppDialog<void>(
    context: context,
    builder: (_) => _RadiologyPrintDialog(workflow: workflow),
  );
}

class _RadiologyPrintDialog extends ConsumerStatefulWidget {
  const _RadiologyPrintDialog({required this.workflow});

  final RadiologyWorkflow workflow;

  @override
  ConsumerState<_RadiologyPrintDialog> createState() =>
      _RadiologyPrintDialogState();
}

enum _RadiologyPrintSection {
  header,
  patient,
  order,
  studies,
  report,
  references,
  signer,
  images,
}

class _RadiologyPrintDialogState extends ConsumerState<_RadiologyPrintDialog> {
  late Set<_RadiologyPrintSection> _selectedSections;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _selectedSections = resolveDefaultReportSectionSelection(
      _radiologyPrintAvailabilities(widget.workflow),
    ).cast<_RadiologyPrintSection>().toSet();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<ReportSectionAvailability> availabilities =
        _radiologyPrintAvailabilities(widget.workflow);
    final _RadiologyPrintSettings settings = _settingsFromSelection(
      _selectedSections,
    );
    final List<AppReportSectionData> tiles = buildReportSectionTiles(
      sections: availabilities,
      titleFor: (Object id) =>
          _radiologyPrintSectionLabel(l10n, id as _RadiologyPrintSection),
      iconFor: (Object id) =>
          _radiologyPrintSectionIcon(id as _RadiologyPrintSection),
      emptyDisabledReason: l10n.reportSectionEmptyDisabledReason,
    );

    return AppDialog(
      title: Text(l10n.radiologyPrintReportDialogTitle),
      icon: const Icon(Icons.print_outlined),
      scrollable: true,
      maxWidth: 860,
      closeEnabled: !_isPrinting,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.radiologyPrintReportDialogBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          AppReportSectionPicker(
            sections: tiles,
            selectedIds: _selectedSections,
            onSelectionChanged: (Set<Object> next) {
              setState(() {
                _selectedSections = sanitizeReportSectionSelection(
                  selectedIds: next,
                  sections: availabilities,
                ).cast<_RadiologyPrintSection>().toSet();
              });
            },
          ),
          SizedBox(height: theme.spacing.md),
          AppReportPreviewPanel(
            title: l10n.radiologyPrintPreviewTitle,
            selectable: true,
            child: Text(
              _radiologyPrintPreviewText(context, widget.workflow, settings),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCloseActionLabel,
          enabled: !_isPrinting,
          onPressed: _isPrinting ? null : () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: l10n.radiologyPrintAction,
          leadingIcon: Icons.print_outlined,
          isLoading: _isPrinting,
          enabled: !_isPrinting && _selectedSections.isNotEmpty,
          onPressed: _isPrinting || _selectedSections.isEmpty ? null : _print,
        ),
      ],
    );
  }

  Future<void> _print() async {
    final _RadiologyPrintSettings settings = _settingsFromSelection(
      _selectedSections,
    );
    setState(() => _isPrinting = true);
    await printFormTemplateDocument(
      ref: ref,
      context: context,
      title: context.l10n.radiologyPrintReportTitle,
      patientContext: settings.includePatient
          ? buildPrintFormPatientContext(
              context.l10n,
              patientName:
                  widget.workflow.order.patientDisplayName ??
                  context.l10n.profileUnknownValue,
              patientId: widget.workflow.order.patientId,
              encounterId: widget.workflow.order.encounterId,
              patientNameLabel: context.l10n.radiologyPatientLabel,
              patientIdLabel: context.l10n.radiologyPatientIdLabel,
              encounterIdLabel: context.l10n.radiologyEncounterLabel,
            )
          : null,
      contextReference: settings.includeOrder
          ? PrintFormContextReference(
              label: context.l10n.radiologyOrderColumnLabel,
              value: widget.workflow.order.effectiveDisplayId,
            )
          : null,
      bodyHtml: _radiologyPrintBodyHtml(context, widget.workflow, settings),
      footerNote: context.l10n.radiologyPrintFooterNote,
      includeSignatures: settings.includeSigner,
    );
    if (mounted) {
      setState(() => _isPrinting = false);
    }
  }
}

List<ReportSectionAvailability> _radiologyPrintAvailabilities(
  RadiologyWorkflow workflow,
) {
  final int imageCount = workflow.studies.fold<int>(
    0,
    (int total, ImagingStudy study) => total + study.assets.length,
  );
  final int referenceCount = workflow.studies.fold<int>(0, (
    int total,
    ImagingStudy study,
  ) {
    return total + study.assets.length + study.pacsLinks.length;
  });
  final RadiologyResult? result = workflow.order.latestResult;
  final bool hasReport =
      (result?.reportText?.trim().isNotEmpty ?? false) || result != null;
  final bool hasPatient =
      (workflow.order.patientId?.trim().isNotEmpty ?? false) ||
      (workflow.order.patientDisplayName?.trim().isNotEmpty ?? false);

  return <ReportSectionAvailability>[
    const ReportSectionAvailability(
      id: _RadiologyPrintSection.header,
      count: 1,
      alwaysAvailable: true,
    ),
    ReportSectionAvailability(
      id: _RadiologyPrintSection.patient,
      count: hasPatient ? 1 : 0,
    ),
    const ReportSectionAvailability(
      id: _RadiologyPrintSection.order,
      count: 1,
      alwaysAvailable: true,
    ),
    ReportSectionAvailability(
      id: _RadiologyPrintSection.studies,
      count: workflow.studies.isEmpty ? 1 : workflow.studies.length,
      alwaysAvailable: true,
    ),
    ReportSectionAvailability(
      id: _RadiologyPrintSection.report,
      count: hasReport ? 1 : 0,
    ),
    ReportSectionAvailability(
      id: _RadiologyPrintSection.references,
      count: referenceCount,
    ),
    const ReportSectionAvailability(
      id: _RadiologyPrintSection.signer,
      count: 1,
      alwaysAvailable: true,
    ),
    ReportSectionAvailability(
      id: _RadiologyPrintSection.images,
      count: imageCount,
    ),
  ];
}

_RadiologyPrintSettings _settingsFromSelection(
  Set<_RadiologyPrintSection> selected,
) {
  return _RadiologyPrintSettings(
    includePatient: selected.contains(_RadiologyPrintSection.patient),
    includeOrder: selected.contains(_RadiologyPrintSection.order),
    includeStudies: selected.contains(_RadiologyPrintSection.studies),
    includeReport: selected.contains(_RadiologyPrintSection.report),
    includeReferences: selected.contains(_RadiologyPrintSection.references),
    includeSigner: selected.contains(_RadiologyPrintSection.signer),
    includeImages: selected.contains(_RadiologyPrintSection.images),
  );
}

String _radiologyPrintSectionLabel(
  AppLocalizations l10n,
  _RadiologyPrintSection section,
) {
  return switch (section) {
    _RadiologyPrintSection.header => l10n.radiologyPrintIncludeHeaderLabel,
    _RadiologyPrintSection.patient => l10n.radiologyPrintIncludePatientLabel,
    _RadiologyPrintSection.order => l10n.radiologyPrintIncludeOrderLabel,
    _RadiologyPrintSection.studies => l10n.radiologyPrintIncludeStudiesLabel,
    _RadiologyPrintSection.report => l10n.radiologyPrintIncludeReportLabel,
    _RadiologyPrintSection.references =>
      l10n.radiologyPrintIncludeReferencesLabel,
    _RadiologyPrintSection.signer => l10n.radiologyPrintIncludeSignerLabel,
    _RadiologyPrintSection.images => l10n.radiologyPrintIncludeImagesLabel,
  };
}

IconData _radiologyPrintSectionIcon(_RadiologyPrintSection section) {
  return switch (section) {
    _RadiologyPrintSection.header => Icons.apartment_outlined,
    _RadiologyPrintSection.patient => Icons.person_outline,
    _RadiologyPrintSection.order => Icons.receipt_long_outlined,
    _RadiologyPrintSection.studies => Icons.biotech_outlined,
    _RadiologyPrintSection.report => Icons.description_outlined,
    _RadiologyPrintSection.references => Icons.link_outlined,
    _RadiologyPrintSection.signer => Icons.draw_outlined,
    _RadiologyPrintSection.images => Icons.image_outlined,
  };
}

@immutable
final class _RadiologyPrintSettings {
  const _RadiologyPrintSettings({
    this.includePatient = true,
    this.includeOrder = true,
    this.includeStudies = true,
    this.includeReport = true,
    this.includeReferences = true,
    this.includeSigner = true,
    this.includeImages = false,
  });

  final bool includePatient;
  final bool includeOrder;
  final bool includeStudies;
  final bool includeReport;
  final bool includeReferences;
  final bool includeSigner;
  final bool includeImages;

  _RadiologyPrintSettings copyWith({
    bool? includePatient,
    bool? includeOrder,
    bool? includeStudies,
    bool? includeReport,
    bool? includeReferences,
    bool? includeSigner,
    bool? includeImages,
  }) {
    return _RadiologyPrintSettings(
      includePatient: includePatient ?? this.includePatient,
      includeOrder: includeOrder ?? this.includeOrder,
      includeStudies: includeStudies ?? this.includeStudies,
      includeReport: includeReport ?? this.includeReport,
      includeReferences: includeReferences ?? this.includeReferences,
      includeSigner: includeSigner ?? this.includeSigner,
      includeImages: includeImages ?? this.includeImages,
    );
  }
}

String _radiologyPrintBodyHtml(
  BuildContext context,
  RadiologyWorkflow workflow,
  _RadiologyPrintSettings settings,
) {
  final AppLocalizations l10n = context.l10n;
  final RadiologyOrder order = workflow.order;
  final RadiologyResult? result = order.latestResult;
  final List<String> sections = <String>[];

  if (settings.includeOrder) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.radiologyPrintOrderSectionTitle,
        bodyHtml: PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
          PrintFormMetadataItem(
            label: l10n.radiologyOrderColumnLabel,
            value: order.effectiveDisplayId,
          ),
          PrintFormMetadataItem(
            label: l10n.radiologyEncounterLabel,
            value: order.encounterId ?? l10n.profileUnknownValue,
          ),
          PrintFormMetadataItem(
            label: l10n.radiologyModalityLabel,
            value:
                _modalityLabelOrNull(l10n, order.modality) ??
                l10n.profileUnknownValue,
          ),
          PrintFormMetadataItem(
            label: l10n.radiologyStudyLabel,
            value:
                order.testsSummary ??
                order.testDisplayName ??
                l10n.profileUnknownValue,
          ),
          PrintFormMetadataItem(
            label: l10n.radiologyPriorityLabel,
            value:
                _radiologyPriorityDisplayLabel(l10n, order.priority) ??
                l10n.profileUnknownValue,
          ),
          PrintFormMetadataItem(
            label: l10n.radiologyOrderedAtLabel,
            value:
                _formatDateTimeOrNull(context, order.orderedAt) ??
                l10n.profileUnknownValue,
          ),
          PrintFormMetadataItem(
            label: l10n.radiologyClinicalNotesLabel,
            value: order.clinicalNote ?? '',
          ),
        ]),
      ),
    );
  }
  if (settings.includeStudies) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.radiologyPrintStudiesSectionTitle,
        bodyHtml: _radiologyPrintStudiesHtml(context, workflow),
        avoidPageBreak: true,
      ),
    );
  }
  if (settings.includeImages) {
    final List<String> imageLines = <String>[
      for (final ImagingStudy study in workflow.studies)
        for (final ImagingAsset asset in study.assets)
          _joinDisplay(<String?>[
            study.effectiveDisplayId,
            asset.fileName ?? asset.displayId,
            asset.contentType,
          ]),
    ];
    sections.add(
      PrintFormTemplate.section(
        title: l10n.radiologyPrintIncludeImagesLabel,
        bodyHtml: PrintFormTemplate.unorderedList(
          imageLines,
          emptyText: l10n.radiologyNoAssetsLabel,
        ),
        avoidPageBreak: true,
      ),
    );
  }
  if (settings.includeReport) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.radiologyPrintReportSectionTitle,
        bodyHtml: _printParagraph(
          result?.reportText ?? l10n.radiologyEmptyReportBody,
        ),
      ),
    );
  }
  if (settings.includeReferences) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.radiologyPrintReferencesSectionTitle,
        bodyHtml: PrintFormTemplate.unorderedList(
          _radiologyReferenceStrings(workflow),
          emptyText: l10n.radiologyNoReportReferencesLabel,
        ),
        avoidPageBreak: true,
      ),
    );
  }
  if (settings.includeSigner) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.radiologyPrintSignerSectionTitle,
        bodyHtml: _radiologySignerHtml(context, result),
        avoidPageBreak: true,
      ),
    );
  }
  if (sections.isEmpty) {
    return _printParagraph(l10n.radiologyPrintNoSectionsSelected);
  }
  return sections.join('\n');
}

String _radiologyPrintStudiesHtml(
  BuildContext context,
  RadiologyWorkflow workflow,
) {
  final AppLocalizations l10n = context.l10n;
  final RadiologyOrder order = workflow.order;
  final List<List<String>> requestedRows = order.requestedTests.isEmpty
      ? <List<String>>[
          <String>[
            order.testDisplayName ??
                order.radiologyTestId ??
                l10n.profileUnknownValue,
            _modalityLabelOrNull(l10n, order.modality) ??
                l10n.profileUnknownValue,
            order.bodyRegion ?? l10n.profileUnknownValue,
            order.laterality ?? l10n.profileUnknownValue,
          ],
        ]
      : <List<String>>[
          for (final RadiologyRequestedTest test in order.requestedTests)
            <String>[
              test.testDisplayName ??
                  test.radiologyTestId ??
                  l10n.profileUnknownValue,
              _modalityLabelOrNull(l10n, test.modality) ??
                  l10n.profileUnknownValue,
              test.bodyRegion ?? l10n.profileUnknownValue,
              test.laterality ?? l10n.profileUnknownValue,
            ],
        ];
  final String testsTable = PrintFormTemplate.table(
    headers: <String>[
      l10n.radiologyStudyLabel,
      l10n.radiologyModalityLabel,
      l10n.radiologyBodyRegionLabel,
      l10n.radiologyLateralityLabel,
    ],
    rows: requestedRows,
    emptyText: l10n.radiologyNoStudiesBody,
  );
  final String studiesTable = PrintFormTemplate.table(
    headers: <String>[
      l10n.radiologyStudyLabel,
      l10n.radiologyModalityLabel,
      l10n.radiologyPerformedAtLabel,
      l10n.radiologyAssetsLabel,
    ],
    rows: <List<String>>[
      for (final ImagingStudy study in workflow.studies)
        <String>[
          study.effectiveDisplayId,
          _modalityLabelOrNull(l10n, study.modality) ??
              l10n.profileUnknownValue,
          _formatDateTimeOrNull(context, study.performedAt) ??
              l10n.profileUnknownValue,
          study.assetCount.toString(),
        ],
    ],
    emptyText: l10n.radiologyNoStudiesBody,
  );
  return '$testsTable\n$studiesTable';
}

String _radiologySignerHtml(BuildContext context, RadiologyResult? result) {
  final AppLocalizations l10n = context.l10n;
  if (result == null) {
    return _printParagraph(l10n.radiologyNoReportBody);
  }
  return PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
    PrintFormMetadataItem(
      label: l10n.radiologyReportedAtLabel,
      value:
          _formatDateTimeOrNull(context, result.reportedAt) ??
          l10n.profileUnknownValue,
    ),
    PrintFormMetadataItem(
      label: l10n.radiologyStatusColumnLabel,
      value: _resultStatusLabel(l10n, result.status),
    ),
    PrintFormMetadataItem(
      label: l10n.radiologyFinalizationRequestedLabel,
      value: result.finalization.requested
          ? l10n.commonYesLabel
          : l10n.commonNoLabel,
    ),
    PrintFormMetadataItem(
      label: l10n.radiologyFinalizationAttestedLabel,
      value: result.finalization.attested
          ? l10n.commonYesLabel
          : l10n.commonNoLabel,
    ),
  ]);
}

Iterable<String> _radiologyReferenceStrings(RadiologyWorkflow workflow) sync* {
  for (final ImagingStudy study in workflow.studies) {
    for (final ImagingAsset asset in study.assets) {
      yield _joinDisplay(<String?>[
        asset.fileName,
        asset.displayId,
        asset.contentType,
        study.effectiveDisplayId,
      ]);
    }
    for (final PacsLink link in study.pacsLinks) {
      yield _joinDisplay(<String?>[
        link.url,
        link.displayId,
        study.effectiveDisplayId,
      ]);
    }
  }
}

String _radiologyPrintPreviewText(
  BuildContext context,
  RadiologyWorkflow workflow,
  _RadiologyPrintSettings settings,
) {
  final AppLocalizations l10n = context.l10n;
  final RadiologyOrder order = workflow.order;
  final StringBuffer buffer = StringBuffer();
  buffer.writeln(l10n.radiologyPrintReportTitle);
  buffer.writeln(
    _joinDisplay(<String?>[
      order.patientDisplayName,
      order.effectiveDisplayId,
      order.testDisplayName ?? order.testsSummary,
    ]),
  );
  if (settings.includePatient) {
    buffer
      ..writeln('\n${l10n.radiologyPrintPatientSectionTitle}')
      ..writeln(order.patientDisplayName ?? l10n.profileUnknownValue)
      ..writeln(order.patientId ?? l10n.profileUnknownValue);
  }
  if (settings.includeOrder) {
    buffer
      ..writeln('\n${l10n.radiologyPrintOrderSectionTitle}')
      ..writeln(
        _joinDisplay(<String?>[
          order.effectiveDisplayId,
          _orderStatusLabel(l10n, order.status),
          _modalityLabelOrNull(l10n, order.modality),
        ]),
      );
  }
  if (settings.includeStudies) {
    buffer
      ..writeln('\n${l10n.radiologyPrintStudiesSectionTitle}')
      ..writeln(
        order.testsSummary ?? order.testDisplayName ?? l10n.profileUnknownValue,
      )
      ..writeln(l10n.radiologyPrintStudyCount(workflow.studies.length));
  }
  if (settings.includeImages) {
    buffer.writeln('\n${l10n.radiologyPrintIncludeImagesLabel}');
    for (final ImagingStudy study in workflow.studies) {
      for (final ImagingAsset asset in study.assets) {
        buffer.writeln(
          _joinDisplay(<String?>[
            study.effectiveDisplayId,
            asset.fileName ?? asset.displayId,
          ]),
        );
      }
    }
  }
  if (settings.includeReport) {
    buffer
      ..writeln('\n${l10n.radiologyPrintReportSectionTitle}')
      ..writeln(
        workflow.order.latestResult?.reportText ??
            l10n.radiologyEmptyReportBody,
      );
  }
  if (settings.includeReferences) {
    buffer
      ..writeln('\n${l10n.radiologyPrintReferencesSectionTitle}')
      ..writeln(
        _radiologyReferenceStrings(
          workflow,
        ).join('\n').ifEmpty(l10n.radiologyNoReportReferencesLabel),
      );
  }
  if (settings.includeSigner) {
    buffer
      ..writeln('\n${l10n.radiologyPrintSignerSectionTitle}')
      ..writeln(
        workflow.order.latestResult == null
            ? l10n.radiologyNoReportBody
            : _resultStatusLabel(l10n, workflow.order.latestResult!.status),
      );
  }
  return buffer.toString().trim();
}

String _printParagraph(String text) {
  final String escaped = PrintFormTemplate.escape(
    text.trim(),
  ).replaceAll('\n', '<br>');
  return '<p>$escaped</p>';
}

Future<void> _showFinalizeDialog(
  BuildContext context,
  WidgetRef ref,
  RadiologyResult result,
) async {
  final bool? saved = await showAppDialog<bool>(
    context: context,
    builder: (_) => _FinalizeReportDialog(
      result: result,
      onSubmit: (Map<String, Object?> payload) => ref
          .read(radiologyWorkspaceControllerProvider.notifier)
          .finalizeResult(result, payload),
    ),
  );
  if (saved == true && context.mounted) {
    _showMutationResult(context, null);
  }
}
