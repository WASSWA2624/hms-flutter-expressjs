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
  static const double _dialogMaxWidth = 1120;

  late Set<_RadiologyPrintSection> _selectedSections;
  bool _isPrinting = false;
  AppPrintPreviewPaneMode _paneMode = AppPrintPreviewPaneMode.split;
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    final Set<_RadiologyPrintSection> available =
        _radiologyPrintAvailabilities(widget.workflow)
            .where((ReportSectionAvailability section) => section.enabled)
            .map(
              (ReportSectionAvailability section) =>
                  section.id as _RadiologyPrintSection,
            )
            .toSet();
    // A standard clinical report contains patient context, order details,
    // findings/conclusion, and signatures. Studies, images, and references are
    // optional attachments and must not repeat the same procedure by default.
    _selectedSections = <_RadiologyPrintSection>{
      _RadiologyPrintSection.header,
      _RadiologyPrintSection.patient,
      _RadiologyPrintSection.order,
      _RadiologyPrintSection.report,
      _RadiologyPrintSection.signer,
    }.intersection(available);
  }

  String _documentHtml(
    BuildContext context,
    _RadiologyPrintSettings settings,
  ) {
    final AppLocalizations l10n = context.l10n;
    final PrintFormTemplateContext templateContext = ref.read(
      printFormTemplateContextProvider,
    );
    final AuthSession? session = ref.read(
      sessionStateProvider.select((state) => state.session),
    );
    return PrintFormTemplate.build(
      context: context,
      title: l10n.radiologyPrintReportTitle,
      patientContext: settings.includePatient
          ? buildPrintFormPatientContext(
              l10n,
              patientName:
                  widget.workflow.order.patientDisplayName ??
                  l10n.profileUnknownValue,
              patientId: widget.workflow.order.patientId,
              encounterId: widget.workflow.order.encounterId,
              patientNameLabel: l10n.radiologyPatientLabel,
              patientIdLabel: l10n.radiologyPatientIdLabel,
              encounterIdLabel: l10n.radiologyEncounterLabel,
            )
          : null,
      contextReference: settings.includeOrder
          ? PrintFormContextReference(
              label: l10n.radiologyOrderColumnLabel,
              value: widget.workflow.order.effectiveDisplayId,
            )
          : null,
      bodyHtml: _radiologyPrintBodyHtml(context, widget.workflow, settings),
      signatures: settings.includeSigner
          ? buildPrintFormSignatures(
              l10n,
              printedByName: session?.user?.displayName,
            )
          : null,
      printedLabel: l10n.printFormPrintedLabel,
      printedOnLabel: l10n.printFormPrintedOnLabel,
      printedAtLabel: l10n.printFormPrintedAtLabel,
      footerNote: l10n.radiologyPrintFooterNote,
      appBranding: templateContext.appBranding,
      facilityBranding: templateContext.facilityBranding,
    );
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
    final double viewportHeight = MediaQuery.sizeOf(context).height;
    final double workspaceHeight = (viewportHeight * 0.72).clamp(400.0, 860.0);
    final bool previewMaximized =
        _paneMode == AppPrintPreviewPaneMode.preview;

    return AppDialog(
      title: Text(l10n.radiologyPrintReportDialogTitle),
      icon: const Icon(Icons.print_outlined),
      scrollable: false,
      pinActionsToBottom: true,
      maxWidth: _dialogMaxWidth,
      closeEnabled: !_isPrinting,
      content: AppPrintPreviewWorkspace(
        height: workspaceHeight,
        paneMode: _paneMode,
        paneModeEnabled: !_isPrinting,
        onPaneModeChanged: (AppPrintPreviewPaneMode next) {
          setState(() => _paneMode = next);
        },
        sectionPicker: AppReportSectionPicker(
          sections: tiles,
          selectedIds: _selectedSections,
          compact: true,
          minTileWidth: 140,
          onSelectionChanged: (Set<Object> next) {
            setState(() {
              _selectedSections = sanitizeReportSectionSelection(
                selectedIds: next,
                sections: availabilities,
              ).cast<_RadiologyPrintSection>().toSet();
            });
          },
        ),
        preview: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return AppPrintPreviewPanel(
              html: _documentHtml(context, settings),
              title: l10n.printPreviewTitle,
              height: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : workspaceHeight,
              scale: _scale,
              maximized: previewMaximized,
              maximizeEnabled: !_isPrinting,
              onZoomIn: () {
                setState(() => _scale = AppPrintPreviewZoom.zoomIn(_scale));
              },
              onZoomOut: () {
                setState(() => _scale = AppPrintPreviewZoom.zoomOut(_scale));
              },
              onZoomIncrease: () {
                setState(() => _scale = AppPrintPreviewZoom.increase(_scale));
              },
              onZoomDecrease: () {
                setState(() => _scale = AppPrintPreviewZoom.decrease(_scale));
              },
              onFitPage: () {
                setState(() {
                  _scale = AppPrintPreviewZoom.fitPage(
                    constraints.maxWidth - theme.spacing.lg * 2,
                  );
                });
              },
              onMaximizeToggle: () {
                setState(() {
                  _paneMode = previewMaximized
                      ? AppPrintPreviewPaneMode.split
                      : AppPrintPreviewPaneMode.preview;
                });
              },
              fallbackChild: SelectableText(
                _radiologyPrintPreviewText(context, widget.workflow, settings),
              ),
            );
          },
        ),
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
    await PrintDocumentTemplates.clinicalResult(
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
      orderReference: settings.includeOrder
          ? PrintFormContextReference(
              label: context.l10n.radiologyOrderColumnLabel,
              value: widget.workflow.order.effectiveDisplayId,
            )
          : null,
      bodyHtml: _radiologyPrintBodyHtml(context, widget.workflow, settings),
      footerNote: context.l10n.radiologyPrintFooterNote,
      includeSignatures: settings.includeSigner,
      showPreview: false,
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
    sections.add(_radiologyStructuredReportHtml(context, result));
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
  if (sections.isEmpty) {
    return _printParagraph(l10n.radiologyPrintNoSectionsSelected);
  }
  return sections.join('\n');
}

String _radiologyStructuredReportHtml(
  BuildContext context,
  RadiologyResult? result,
) {
  final AppLocalizations l10n = context.l10n;
  final String reportText = (result?.reportText ?? '').trim();
  if (reportText.isEmpty) {
    return PrintFormTemplate.section(
      title: l10n.radiologyFindingsLabel,
      bodyHtml: _printParagraph(l10n.radiologyEmptyReportBody),
    );
  }

  final Map<String, StringBuffer> values = <String, StringBuffer>{};
  String? currentKey;
  final RegExp heading = RegExp(
    r'^(Technique|Findings|Impression(?:/Conclusion)?|Conclusion|Recommendation|Reporting narrative|Report narrative|Narrative|Addendum)\s*:\s*(.*)$',
    caseSensitive: false,
  );

  String canonicalKey(String value) {
    final String normalized = value.trim().toLowerCase();
    if (normalized == 'findings') return 'findings';
    if (normalized.startsWith('impression') || normalized == 'conclusion') {
      return 'impression';
    }
    if (normalized == 'recommendation') return 'recommendation';
    if (normalized == 'addendum') return 'addendum';
    if (normalized.contains('narrative')) return 'narrative';
    return 'technique';
  }

  void append(String key, String value) {
    final String clean = value.trim();
    if (clean.isEmpty) {
      return;
    }
    final StringBuffer buffer = values.putIfAbsent(key, StringBuffer.new);
    if (buffer.isNotEmpty) {
      buffer.writeln();
    }
    buffer.write(clean);
  }

  for (final String rawLine in reportText.split(RegExp(r'\r?\n'))) {
    final String line = rawLine.trim();
    final RegExpMatch? match = heading.firstMatch(line);
    if (match != null) {
      currentKey = canonicalKey(match.group(1)!);
      append(currentKey, match.group(2) ?? '');
      continue;
    }
    if (line.isNotEmpty) {
      append(currentKey ?? 'findings', line);
    }
  }

  final List<String> sections = <String>[];
  for (final (String key, String title) in <(String, String)>[
    ('findings', l10n.radiologyFindingsLabel),
    ('impression', l10n.radiologyImpressionLabel),
    ('recommendation', l10n.radiologyRecommendationLabel),
    ('narrative', l10n.radiologyReportTextLabel),
    ('addendum', l10n.radiologyWorkflowStepAddendum),
  ]) {
    final String value = values[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      continue;
    }
    sections.add(
      PrintFormTemplate.section(
        title: title,
        bodyHtml: _printParagraph(value),
        avoidPageBreak: key == 'impression' || key == 'recommendation',
      ),
    );
  }

  if (sections.isEmpty) {
    return PrintFormTemplate.section(
      title: l10n.radiologyFindingsLabel,
      bodyHtml: _printParagraph(reportText),
    );
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
