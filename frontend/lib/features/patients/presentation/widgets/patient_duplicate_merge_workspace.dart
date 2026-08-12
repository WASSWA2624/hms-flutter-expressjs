import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/patient_registry_access.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_form_fields.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// How the user intends to resolve identity fields before confirming merge.
enum PatientMergeResolution { keepLeft, keepRight, autoMerge }

/// One comparable field in the merge workspace.
@immutable
final class PatientMergeFieldLane {
  const PatientMergeFieldLane({
    required this.key,
    required this.label,
    required this.leftValue,
    required this.rightValue,
    this.leftRaw,
    this.rightRaw,
    this.status,
    this.score,
    this.includeInSummary = false,
  });

  final String key;
  final String label;
  final String leftValue;
  final String rightValue;
  final String? leftRaw;
  final String? rightRaw;
  final String? status;
  final int? score;
  final bool includeInSummary;

  PatientMergeFieldLane copyWith({
    String? leftValue,
    String? rightValue,
    String? leftRaw,
    String? rightRaw,
    bool clearLeftRaw = false,
    bool clearRightRaw = false,
  }) {
    return PatientMergeFieldLane(
      key: key,
      label: label,
      leftValue: leftValue ?? this.leftValue,
      rightValue: rightValue ?? this.rightValue,
      leftRaw: clearLeftRaw ? null : leftRaw ?? this.leftRaw,
      rightRaw: clearRightRaw ? null : rightRaw ?? this.rightRaw,
      status: status,
      score: score,
      includeInSummary: includeInSummary,
    );
  }

  PatientMergeFieldLane swapped() {
    return copyWith(
      leftValue: rightValue,
      rightValue: leftValue,
      leftRaw: rightRaw,
      rightRaw: leftRaw,
      clearLeftRaw: rightRaw == null,
      clearRightRaw: leftRaw == null,
    );
  }

  String resolvedDisplay(PatientMergeResolution resolution) {
    switch (resolution) {
      case PatientMergeResolution.keepLeft:
        return leftValue;
      case PatientMergeResolution.keepRight:
        return rightValue;
      case PatientMergeResolution.autoMerge:
        return prefersLeft ? leftValue : rightValue;
    }
  }

  String? resolvedRaw(PatientMergeResolution resolution) {
    switch (resolution) {
      case PatientMergeResolution.keepLeft:
        return leftRaw ?? _nonEmpty(leftValue);
      case PatientMergeResolution.keepRight:
        return rightRaw ?? _nonEmpty(rightValue);
      case PatientMergeResolution.autoMerge:
        return prefersLeft
            ? (leftRaw ?? _nonEmpty(leftValue))
            : (rightRaw ?? _nonEmpty(rightValue));
    }
  }

  /// Whether auto-merge keeps the left value for this field.
  bool get prefersLeft {
    final String left = leftValue.trim();
    final String right = rightValue.trim();
    if (left.isEmpty && right.isNotEmpty) {
      return false;
    }
    if (right.isEmpty && left.isNotEmpty) {
      return true;
    }
    final String normalizedStatus = (status ?? '').toUpperCase();
    if (normalizedStatus == 'CONFLICT' && right.length > left.length) {
      return false;
    }
    return true;
  }
}

/// Built merge commit payload for [PatientRepository.mergePatients].
@immutable
final class PatientMergeCommitPlan {
  const PatientMergeCommitPlan({
    required this.primaryPatientId,
    required this.secondaryPatientId,
    required this.summary,
  });

  final String primaryPatientId;
  final String secondaryPatientId;
  final Map<String, Object?> summary;
}

/// Builds comparable field lanes from a duplicate pair and merge preview.
List<PatientMergeFieldLane> buildPatientMergeFieldLanes({
  required AppLocalizations l10n,
  required Locale locale,
  required Patient left,
  required Patient right,
  List<PatientDuplicateFieldComparison> comparisons =
      const <PatientDuplicateFieldComparison>[],
}) {
  final Map<String, PatientDuplicateFieldComparison> byField =
      <String, PatientDuplicateFieldComparison>{
        for (final PatientDuplicateFieldComparison comparison in comparisons)
          comparison.field.toUpperCase(): comparison,
      };

  String displayDob(DateTime? value) =>
      value == null ? '' : AppFormatters.mediumDate(value, locale);

  String? rawDob(DateTime? value) =>
      value?.toIso8601String().split('T').first;

  PatientMergeFieldLane lane({
    required String key,
    required String label,
    required String leftValue,
    required String rightValue,
    String? leftRaw,
    String? rightRaw,
    bool includeInSummary = false,
    List<String> comparisonKeys = const <String>[],
  }) {
    PatientDuplicateFieldComparison? match;
    for (final String comparisonKey in comparisonKeys) {
      match = byField[comparisonKey.toUpperCase()];
      if (match != null) {
        break;
      }
    }
    return PatientMergeFieldLane(
      key: key,
      label: label,
      leftValue: leftValue,
      rightValue: rightValue,
      leftRaw: leftRaw,
      rightRaw: rightRaw,
      status: match?.status,
      score: match?.similarityPercent ??
          (match == null
              ? null
              : match.status.toUpperCase() == 'MATCH'
              ? 100
              : match.contribution),
      includeInSummary: includeInSummary,
    );
  }

  final String leftIdentifier = _joinIdentifier(left);
  final String rightIdentifier = _joinIdentifier(right);

  return <PatientMergeFieldLane>[
    lane(
      key: 'first_name',
      label: l10n.patientsFirstNameLabel,
      leftValue: left.firstName?.trim() ?? '',
      rightValue: right.firstName?.trim() ?? '',
      includeInSummary: true,
      comparisonKeys: const <String>['FIRST_NAME', 'NAME'],
    ),
    lane(
      key: 'last_name',
      label: l10n.patientsLastNameLabel,
      leftValue: left.lastName?.trim() ?? '',
      rightValue: right.lastName?.trim() ?? '',
      includeInSummary: true,
      comparisonKeys: const <String>['LAST_NAME', 'NAME'],
    ),
    lane(
      key: 'date_of_birth',
      label: l10n.patientsDobLabel,
      leftValue: displayDob(left.dateOfBirth),
      rightValue: displayDob(right.dateOfBirth),
      leftRaw: rawDob(left.dateOfBirth),
      rightRaw: rawDob(right.dateOfBirth),
      includeInSummary: true,
      comparisonKeys: const <String>['DATE_OF_BIRTH', 'DOB'],
    ),
    lane(
      key: 'gender',
      label: l10n.patientsGenderLabel,
      leftValue: left.gender?.trim() ?? '',
      rightValue: right.gender?.trim() ?? '',
      includeInSummary: true,
      comparisonKeys: const <String>['GENDER'],
    ),
    lane(
      key: 'phone',
      label: l10n.patientsPhoneLabel,
      leftValue: left.primaryPhone?.trim() ?? '',
      rightValue: right.primaryPhone?.trim() ?? '',
      comparisonKeys: const <String>['PHONE'],
    ),
    lane(
      key: 'email',
      label: l10n.patientsEmailLabel,
      leftValue: left.primaryEmail?.trim() ?? '',
      rightValue: right.primaryEmail?.trim() ?? '',
      comparisonKeys: const <String>['EMAIL'],
    ),
    lane(
      key: 'identifier',
      label: l10n.patientsIdentifierLabel,
      leftValue: leftIdentifier,
      rightValue: rightIdentifier,
      comparisonKeys: const <String>['IDENTIFIER'],
    ),
    lane(
      key: 'facility_id',
      label: l10n.patientsFacilityLabel,
      leftValue: (left.facilityLabel ?? left.facilityId)?.trim() ?? '',
      rightValue: (right.facilityLabel ?? right.facilityId)?.trim() ?? '',
      leftRaw: left.facilityId,
      rightRaw: right.facilityId,
      includeInSummary: true,
      comparisonKeys: const <String>['FACILITY'],
    ),
  ];
}

PatientMergeCommitPlan buildPatientMergeCommitPlan({
  required Patient left,
  required Patient right,
  required List<PatientMergeFieldLane> fields,
  required PatientMergeResolution resolution,
}) {
  final bool keepRight = resolution == PatientMergeResolution.keepRight;
  final Patient primary = keepRight ? right : left;
  final Patient secondary = keepRight ? left : right;
  final Map<String, Object?> summary = <String, Object?>{};
  for (final PatientMergeFieldLane field in fields) {
    if (!field.includeInSummary) {
      continue;
    }
    final String? raw = field.resolvedRaw(resolution);
    if (raw == null || raw.trim().isEmpty) {
      continue;
    }
    summary[field.key] = raw.trim();
  }
  return PatientMergeCommitPlan(
    primaryPatientId: primary.id,
    secondaryPatientId: secondary.id,
    summary: summary,
  );
}

String _joinIdentifier(Patient patient) {
  final String type = patient.primaryIdentifierType?.trim() ?? '';
  final String value = patient.primaryIdentifierValue?.trim() ?? '';
  if (type.isEmpty && value.isEmpty) {
    return patient.publicId?.trim() ?? '';
  }
  if (type.isEmpty) {
    return value;
  }
  if (value.isEmpty) {
    return type;
  }
  return '$type $value';
}

String? _nonEmpty(String value) {
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Compact survivor lines for a merge choice, reflecting current lane values.
List<String> buildPatientMergeChoicePreviewLines({
  required AppLocalizations l10n,
  required List<PatientMergeFieldLane> fields,
  required PatientMergeResolution resolution,
}) {
  String displayFor(String key) {
    for (final PatientMergeFieldLane field in fields) {
      if (field.key == key) {
        final String value = field.resolvedDisplay(resolution).trim();
        return value.isEmpty ? l10n.patientsMergeEmptyValueLabel : value;
      }
    }
    return l10n.patientsMergeEmptyValueLabel;
  }

  final String firstName = displayFor('first_name');
  final String lastName = displayFor('last_name');
  final bool firstEmpty = firstName == l10n.patientsMergeEmptyValueLabel;
  final bool lastEmpty = lastName == l10n.patientsMergeEmptyValueLabel;
  final String name;
  if (firstEmpty && lastEmpty) {
    name = l10n.patientsMergeEmptyValueLabel;
  } else if (firstEmpty) {
    name = lastName;
  } else if (lastEmpty) {
    name = firstName;
  } else {
    name = '$firstName $lastName';
  }

  return <String>[
    name,
    displayFor('date_of_birth'),
    displayFor('gender'),
    displayFor('phone'),
    displayFor('email'),
  ];
}

/// Field-level merge workspace shown after Review merge.
class PatientDuplicateMergeWorkspace extends StatefulWidget {
  const PatientDuplicateMergeWorkspace({
    required this.preview,
    required this.comparisons,
    required this.isSaving,
    required this.onConfirmMerge,
    super.key,
  });

  final PatientMergePreview preview;
  final List<PatientDuplicateFieldComparison> comparisons;
  final bool isSaving;
  final Future<void> Function(PatientMergeCommitPlan plan) onConfirmMerge;

  @override
  State<PatientDuplicateMergeWorkspace> createState() =>
      _PatientDuplicateMergeWorkspaceState();
}

class _PatientDuplicateMergeWorkspaceState
    extends State<PatientDuplicateMergeWorkspace> {
  List<PatientMergeFieldLane> _fields = const <PatientMergeFieldLane>[];
  PatientMergeResolution? _resolution;
  bool _didLoadFields = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadFields) {
      _fields = _buildFields();
      _didLoadFields = true;
    }
  }

  @override
  void didUpdateWidget(covariant PatientDuplicateMergeWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preview.primaryPatient.id !=
            widget.preview.primaryPatient.id ||
        oldWidget.preview.secondaryPatient.id !=
            widget.preview.secondaryPatient.id) {
      _fields = _buildFields();
      _resolution = null;
    }
  }

  List<PatientMergeFieldLane> _buildFields() {
    return buildPatientMergeFieldLanes(
      l10n: context.l10n,
      locale: Localizations.localeOf(context),
      left: widget.preview.primaryPatient,
      right: widget.preview.secondaryPatient,
      comparisons: widget.comparisons,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final List<MapEntry<String, int>> counts = widget
        .preview
        .transferCounts
        .entries
        .where((MapEntry<String, int> entry) => entry.value > 0)
        .toList(growable: false);

    return AppSectionPanel(
      title: l10n.patientsMergePreviewTitle,
      leadingIcon: Icons.merge_type_outlined,
      tone: AppWorkspaceStatusTone.warning,
      spacing: theme.spacing.sm,
      children: <Widget>[
        Text(
          l10n.patientsMergeWorkspaceBody,
          style: theme.textTheme.bodyMedium,
        ),
        _MergeLaneHeader(
          leftLabel: widget.preview.primaryPatient.effectiveDisplayName,
          rightLabel: widget.preview.secondaryPatient.effectiveDisplayName,
        ),
        for (int index = 0; index < _fields.length; index += 1)
          _MergeFieldLaneRow(
            key: ValueKey<String>(_fields[index].key),
            field: _fields[index],
            resolution: _resolution,
            enabled: !widget.isSaving,
            onSwap: () => _swapField(index),
            onEditLeft: (String value, {String? raw, bool clearRaw = false}) {
              _editField(
                index,
                isLeft: true,
                value: value,
                raw: raw,
                clearRaw: clearRaw,
              );
            },
            onEditRight: (String value, {String? raw, bool clearRaw = false}) {
              _editField(
                index,
                isLeft: false,
                value: value,
                raw: raw,
                clearRaw: clearRaw,
              );
            },
          ),
        if (counts.isNotEmpty)
          Wrap(
            spacing: theme.spacing.xs,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              for (final MapEntry<String, int> count in counts)
                AppWorkspaceStatusBadge(
                  status: AppWorkspaceStatus(
                    label: l10n.patientsMergeTransferCountLabel(
                      _apiLabel(count.key),
                      count.value,
                    ),
                    tone: AppWorkspaceStatusTone.info,
                  ),
                ),
            ],
          ),
        AppAccessActionGate(
          requirement: PatientAllAtomPermissions.duplicateReview,
          builder: (_, bool isAllowed) {
            if (!isAllowed) {
              return const SizedBox.shrink();
            }
            return _MergeChoiceRow(
              fields: _fields,
              isSaving: widget.isSaving,
              selected: _resolution,
              onSelect: (PatientMergeResolution resolution) {
                setState(() {
                  _resolution = resolution;
                });
              },
            );
          },
        ),
        if (_resolution != null) ...<Widget>[
          AppFormInformationBanner(
            title: _resolutionBannerTitle(l10n, _resolution!),
            message: l10n.patientsMergeConfirmHint,
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AppAccessActionGate(
              requirement: PatientAllAtomPermissions.duplicateReview,
              builder: (_, bool isAllowed) {
                if (!isAllowed) {
                  return const SizedBox.shrink();
                }
                return AppButton.primary(
                  label: l10n.patientsMergePatientsAction,
                  leadingIcon: Icons.merge_type_outlined,
                  isLoading: widget.isSaving,
                  enabled: !widget.isSaving,
                  onPressed: _confirm,
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _swapField(int index) {
    setState(() {
      _fields = <PatientMergeFieldLane>[
        for (int i = 0; i < _fields.length; i += 1)
          if (i == index) _fields[i].swapped() else _fields[i],
      ];
    });
  }

  void _editField(
    int index, {
    required bool isLeft,
    required String value,
    String? raw,
    bool clearRaw = false,
  }) {
    setState(() {
      final PatientMergeFieldLane current = _fields[index];
      final PatientMergeFieldLane next = isLeft
          ? current.copyWith(
              leftValue: value,
              leftRaw: raw,
              clearLeftRaw: clearRaw,
            )
          : current.copyWith(
              rightValue: value,
              rightRaw: raw,
              clearRightRaw: clearRaw,
            );
      _fields = <PatientMergeFieldLane>[
        for (int i = 0; i < _fields.length; i += 1)
          if (i == index) next else _fields[i],
      ];
    });
  }

  Future<void> _confirm() async {
    final PatientMergeResolution? resolution = _resolution;
    if (resolution == null) {
      return;
    }
    final PatientMergeCommitPlan plan = buildPatientMergeCommitPlan(
      left: widget.preview.primaryPatient,
      right: widget.preview.secondaryPatient,
      fields: _fields,
      resolution: resolution,
    );
    await widget.onConfirmMerge(plan);
  }

  String _resolutionBannerTitle(
    AppLocalizations l10n,
    PatientMergeResolution resolution,
  ) {
    return switch (resolution) {
      PatientMergeResolution.keepLeft => l10n.patientsMergeKeepLeftSelected,
      PatientMergeResolution.keepRight => l10n.patientsMergeKeepRightSelected,
      PatientMergeResolution.autoMerge => l10n.patientsMergeAutoSelected,
    };
  }
}

class _MergeChoiceRow extends StatelessWidget {
  const _MergeChoiceRow({
    required this.fields,
    required this.isSaving,
    required this.selected,
    required this.onSelect,
  });

  final List<PatientMergeFieldLane> fields;
  final bool isSaving;
  final PatientMergeResolution? selected;
  final ValueChanged<PatientMergeResolution> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final List<Widget> choices = <Widget>[
      _MergeChoiceColumn(
        fields: fields,
        resolution: PatientMergeResolution.keepLeft,
        selected: selected == PatientMergeResolution.keepLeft,
        isSaving: isSaving,
        align: CrossAxisAlignment.start,
        buttonLabel: l10n.patientsMergeKeepLeftAction,
        buttonIcon: Icons.west_outlined,
        onPressed: () => onSelect(PatientMergeResolution.keepLeft),
      ),
      _MergeChoiceColumn(
        fields: fields,
        resolution: PatientMergeResolution.autoMerge,
        selected: selected == PatientMergeResolution.autoMerge,
        isSaving: isSaving,
        align: CrossAxisAlignment.center,
        buttonLabel: l10n.patientsMergeAutoAction,
        buttonIcon: Icons.auto_fix_high_outlined,
        onPressed: () => onSelect(PatientMergeResolution.autoMerge),
      ),
      _MergeChoiceColumn(
        fields: fields,
        resolution: PatientMergeResolution.keepRight,
        selected: selected == PatientMergeResolution.keepRight,
        isSaving: isSaving,
        align: CrossAxisAlignment.end,
        buttonLabel: l10n.patientsMergeKeepRightAction,
        buttonIcon: Icons.east_outlined,
        onPressed: () => onSelect(PatientMergeResolution.keepRight),
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stacked = constraints.maxWidth < 720;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int index = 0; index < choices.length; index += 1) ...<Widget>[
                choices[index],
                if (index < choices.length - 1)
                  SizedBox(height: theme.spacing.sm),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: choices[0]),
            SizedBox(width: theme.spacing.sm),
            Expanded(child: choices[1]),
            SizedBox(width: theme.spacing.sm),
            Expanded(child: choices[2]),
          ],
        );
      },
    );
  }
}

class _MergeChoiceColumn extends StatelessWidget {
  const _MergeChoiceColumn({
    required this.fields,
    required this.resolution,
    required this.selected,
    required this.isSaving,
    required this.align,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.onPressed,
  });

  final List<PatientMergeFieldLane> fields;
  final PatientMergeResolution resolution;
  final bool selected;
  final bool isSaving;
  final CrossAxisAlignment align;
  final String buttonLabel;
  final IconData buttonIcon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = theme.colorScheme;
    final List<String> lines = buildPatientMergeChoicePreviewLines(
      l10n: l10n,
      fields: fields,
      resolution: resolution,
    );

    return Column(
      crossAxisAlignment: align,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(theme.spacing.sm),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer.withValues(alpha: 0.45)
                : colors.surfaceContainerHighest.withValues(alpha: 0.3),
            border: theme.borders.all(
              color: selected
                  ? colors.primary
                  : colors.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.patientsMergeChoicePreviewLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              SizedBox(height: theme.spacing.xs),
              for (final String line in lines)
                Text(
                  line,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: line == l10n.patientsMergeEmptyValueLabel
                        ? FontStyle.italic
                        : FontStyle.normal,
                    color: line == l10n.patientsMergeEmptyValueLabel
                        ? colors.onSurfaceVariant
                        : colors.onSurface,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        AppButton.secondary(
          label: buttonLabel,
          leadingIcon: buttonIcon,
          enabled: !isSaving,
          onPressed: onPressed,
        ),
      ],
    );
  }
}

class _MergeLaneHeader extends StatelessWidget {
  const _MergeLaneHeader({required this.leftLabel, required this.rightLabel});

  final String leftLabel;
  final String rightLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '${l10n.patientsMergeLeftColumnLabel}: $leftLabel',
            style: theme.textTheme.labelLarge,
          ),
        ),
        SizedBox(width: theme.spacing.xl),
        Expanded(
          child: Text(
            '${l10n.patientsMergeRightColumnLabel}: $rightLabel',
            style: theme.textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}

class _MergeFieldLaneRow extends StatefulWidget {
  const _MergeFieldLaneRow({
    required this.field,
    required this.resolution,
    required this.enabled,
    required this.onSwap,
    required this.onEditLeft,
    required this.onEditRight,
    super.key,
  });

  final PatientMergeFieldLane field;
  final PatientMergeResolution? resolution;
  final bool enabled;
  final VoidCallback onSwap;
  final void Function(String value, {String? raw, bool clearRaw}) onEditLeft;
  final void Function(String value, {String? raw, bool clearRaw}) onEditRight;

  @override
  State<_MergeFieldLaneRow> createState() => _MergeFieldLaneRowState();
}

class _MergeFieldLaneRowState extends State<_MergeFieldLaneRow> {
  late final TextEditingController _leftController;
  late final TextEditingController _rightController;

  @override
  void initState() {
    super.initState();
    _leftController = TextEditingController(text: widget.field.leftValue);
    _rightController = TextEditingController(text: widget.field.rightValue);
  }

  @override
  void didUpdateWidget(covariant _MergeFieldLaneRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.field.leftValue != widget.field.leftValue &&
        _leftController.text != widget.field.leftValue) {
      _leftController.value = TextEditingValue(
        text: widget.field.leftValue,
        selection: TextSelection.collapsed(
          offset: widget.field.leftValue.length,
        ),
      );
    }
    if (oldWidget.field.rightValue != widget.field.rightValue &&
        _rightController.text != widget.field.rightValue) {
      _rightController.value = TextEditingValue(
        text: widget.field.rightValue,
        selection: TextSelection.collapsed(
          offset: widget.field.rightValue.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return AppContentPanel(
      density: AppContentPanelDensity.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.field.label,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (widget.field.status != null &&
                  widget.field.status!.trim().isNotEmpty)
                AppWorkspaceStatusBadge(
                  status: AppWorkspaceStatus(
                    label: _statusLabel(l10n, widget.field),
                    tone: _statusTone(widget.field.status),
                  ),
                ),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stacked = constraints.maxWidth < 640;
              final bool leftSelected = switch (widget.resolution) {
                null => false,
                PatientMergeResolution.keepLeft => true,
                PatientMergeResolution.keepRight => false,
                PatientMergeResolution.autoMerge => widget.field.prefersLeft,
              };
              final bool rightSelected = switch (widget.resolution) {
                null => false,
                PatientMergeResolution.keepLeft => false,
                PatientMergeResolution.keepRight => true,
                PatientMergeResolution.autoMerge => !widget.field.prefersLeft,
              };
              final Widget leftCell = _MergeEditableValue(
                fieldKey: widget.field.key,
                controller: _leftController,
                displayValue: widget.field.leftValue,
                rawValue: widget.field.leftRaw,
                selected: leftSelected,
                enabled: widget.enabled,
                semanticLabel: l10n.patientsMergeLeftColumnLabel,
                onChanged: widget.onEditLeft,
              );
              final Widget rightCell = _MergeEditableValue(
                fieldKey: widget.field.key,
                controller: _rightController,
                displayValue: widget.field.rightValue,
                rawValue: widget.field.rightRaw,
                selected: rightSelected,
                enabled: widget.enabled,
                semanticLabel: l10n.patientsMergeRightColumnLabel,
                onChanged: widget.onEditRight,
              );
              final Widget swap = IconButton(
                tooltip: l10n.patientsMergeSwapFieldAction,
                onPressed: widget.enabled ? widget.onSwap : null,
                icon: const Icon(Icons.swap_horiz),
              );
              if (stacked) {
                return Column(
                  children: <Widget>[
                    leftCell,
                    swap,
                    rightCell,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: leftCell),
                  swap,
                  Expanded(child: rightCell),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, PatientMergeFieldLane field) {
    final String status = (field.status ?? '').toUpperCase();
    final String base = switch (status) {
      'MATCH' => l10n.patientsDuplicateStatusMatchLabel,
      'SIMILAR' => l10n.patientsDuplicateStatusSimilarLabel,
      'CONFLICT' => l10n.patientsDuplicateStatusConflictLabel,
      _ => _apiLabel(field.status ?? ''),
    };
    if (field.score == null) {
      return base;
    }
    return '$base · ${field.score}%';
  }

  AppWorkspaceStatusTone _statusTone(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'MATCH':
        return AppWorkspaceStatusTone.success;
      case 'CONFLICT':
        return AppWorkspaceStatusTone.error;
      default:
        return AppWorkspaceStatusTone.warning;
    }
  }
}

enum _MergeFieldInputKind { text, phone, email, date, gender }

_MergeFieldInputKind _mergeFieldInputKind(String key) {
  switch (key) {
    case 'phone':
      return _MergeFieldInputKind.phone;
    case 'email':
      return _MergeFieldInputKind.email;
    case 'date_of_birth':
      return _MergeFieldInputKind.date;
    case 'gender':
      return _MergeFieldInputKind.gender;
    default:
      return _MergeFieldInputKind.text;
  }
}

class _MergeEditableValue extends StatelessWidget {
  const _MergeEditableValue({
    required this.fieldKey,
    required this.controller,
    required this.displayValue,
    required this.rawValue,
    required this.selected,
    required this.enabled,
    required this.semanticLabel,
    required this.onChanged,
  });

  final String fieldKey;
  final TextEditingController controller;
  final String displayValue;
  final String? rawValue;
  final bool selected;
  final bool enabled;
  final String semanticLabel;
  final void Function(String value, {String? raw, bool clearRaw}) onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = theme.colorScheme;
    final Locale locale = Localizations.localeOf(context);
    final _MergeFieldInputKind kind = _mergeFieldInputKind(fieldKey);
    final DateTime now = DateTime.now();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacing.xs),
      decoration: BoxDecoration(
        color: selected
            ? colors.primaryContainer.withValues(alpha: 0.35)
            : colors.surface.withValues(alpha: 0),
        border: theme.borders.all(
          color: selected
              ? colors.primary
              : colors.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Semantics(
        label: semanticLabel,
        child: switch (kind) {
          _MergeFieldInputKind.phone => PatientPhoneField(
            controller: controller,
            enabled: enabled,
            onChanged: (String value) {
              onChanged(value, raw: value, clearRaw: value.trim().isEmpty);
            },
          ),
          _MergeFieldInputKind.email => PatientEmailField(
            controller: controller,
            enabled: enabled,
            onChanged: (String value) {
              onChanged(value, raw: value, clearRaw: value.trim().isEmpty);
            },
          ),
          _MergeFieldInputKind.date => PatientDateField(
            value: _parseMergeDate(rawValue),
            enabled: enabled,
            firstDate: DateTime(now.year - 120),
            lastDate: now,
            onChanged: (DateTime? date) {
              if (date == null) {
                onChanged('', clearRaw: true);
                return;
              }
              onChanged(
                AppFormatters.mediumDate(date, locale),
                raw: date.toIso8601String().split('T').first,
              );
            },
          ),
          _MergeFieldInputKind.gender => AppGenderField(
            value: displayValue.trim().isEmpty ? null : displayValue.trim(),
            enabled: enabled,
            maleLabel: l10n.patientsGenderMale,
            femaleLabel: l10n.patientsGenderFemale,
            otherLabel: l10n.patientsGenderOther,
            unknownLabel: l10n.patientsGenderUnknown,
            onChanged: (String? value) {
              final String next = value?.trim() ?? '';
              onChanged(next, raw: next, clearRaw: next.isEmpty);
            },
          ),
          _MergeFieldInputKind.text => AppTextField(
            controller: controller,
            enabled: enabled,
            useFloatingLabel: false,
            textCapitalization: fieldKey == 'first_name' || fieldKey == 'last_name'
                ? TextCapitalization.words
                : TextCapitalization.none,
            onChanged: (String value) {
              onChanged(value, raw: value, clearRaw: value.trim().isEmpty);
            },
          ),
        },
      ),
    );
  }
}

DateTime? _parseMergeDate(String? raw) {
  final String? value = raw?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

String _apiLabel(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  return trimmed
      .toLowerCase()
      .split(RegExp(r'[_\s]+'))
      .where((String part) => part.isNotEmpty)
      .map(
        (String part) =>
            '${part[0].toUpperCase()}${part.length > 1 ? part.substring(1) : ''}',
      )
      .join(' ');
}
