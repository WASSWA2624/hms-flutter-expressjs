import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/patient_registry_access.dart';
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
            field: _fields[index],
            resolution: _resolution,
            enabled: !widget.isSaving,
            onSwap: () => _swapField(index),
            onAcceptLeft: (String value) => _setSideValue(index, left: value),
            onAcceptRight: (String value) =>
                _setSideValue(index, right: value),
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
            return Wrap(
              spacing: theme.spacing.xs,
              runSpacing: theme.spacing.xs,
              children: <Widget>[
                AppButton.secondary(
                  label: l10n.patientsMergeKeepLeftAction,
                  leadingIcon: Icons.west_outlined,
                  enabled: !widget.isSaving,
                  onPressed: () => setState(() {
                    _resolution = PatientMergeResolution.keepLeft;
                  }),
                ),
                AppButton.secondary(
                  label: l10n.patientsMergeKeepRightAction,
                  leadingIcon: Icons.east_outlined,
                  enabled: !widget.isSaving,
                  onPressed: () => setState(() {
                    _resolution = PatientMergeResolution.keepRight;
                  }),
                ),
                AppButton.secondary(
                  label: l10n.patientsMergeAutoAction,
                  leadingIcon: Icons.auto_fix_high_outlined,
                  enabled: !widget.isSaving,
                  onPressed: () => setState(() {
                    _resolution = PatientMergeResolution.autoMerge;
                  }),
                ),
              ],
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

  void _setSideValue(int index, {String? left, String? right}) {
    setState(() {
      final PatientMergeFieldLane current = _fields[index];
      final bool shouldSwap = (left != null && left == current.rightValue) ||
          (right != null && right == current.leftValue);
      if (!shouldSwap) {
        return;
      }
      _fields = <PatientMergeFieldLane>[
        for (int i = 0; i < _fields.length; i += 1)
          if (i == index) current.swapped() else _fields[i],
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

class _MergeFieldLaneRow extends StatelessWidget {
  const _MergeFieldLaneRow({
    required this.field,
    required this.resolution,
    required this.enabled,
    required this.onSwap,
    required this.onAcceptLeft,
    required this.onAcceptRight,
  });

  final PatientMergeFieldLane field;
  final PatientMergeResolution? resolution;
  final bool enabled;
  final VoidCallback onSwap;
  final ValueChanged<String> onAcceptLeft;
  final ValueChanged<String> onAcceptRight;

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
                child: Text(field.label, style: theme.textTheme.titleSmall),
              ),
              if (field.status != null && field.status!.trim().isNotEmpty)
                AppWorkspaceStatusBadge(
                  status: AppWorkspaceStatus(
                    label: _statusLabel(l10n, field),
                    tone: _statusTone(field.status),
                  ),
                ),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stacked = constraints.maxWidth < 520;
              final bool leftSelected = switch (resolution) {
                null => false,
                PatientMergeResolution.keepLeft => true,
                PatientMergeResolution.keepRight => false,
                PatientMergeResolution.autoMerge => field.prefersLeft,
              };
              final bool rightSelected = switch (resolution) {
                null => false,
                PatientMergeResolution.keepLeft => false,
                PatientMergeResolution.keepRight => true,
                PatientMergeResolution.autoMerge => !field.prefersLeft,
              };
              final Widget leftCell = _MergeValueCell(
                value: field.leftValue,
                selected: leftSelected,
                enabled: enabled,
                semanticLabel: l10n.patientsMergeLeftColumnLabel,
                onAccept: onAcceptLeft,
              );
              final Widget rightCell = _MergeValueCell(
                value: field.rightValue,
                selected: rightSelected,
                enabled: enabled,
                semanticLabel: l10n.patientsMergeRightColumnLabel,
                onAccept: onAcceptRight,
              );
              final Widget swap = IconButton(
                tooltip: l10n.patientsMergeSwapFieldAction,
                onPressed: enabled ? onSwap : null,
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

class _MergeValueCell extends StatelessWidget {
  const _MergeValueCell({
    required this.value,
    required this.selected,
    required this.enabled,
    required this.semanticLabel,
    required this.onAccept,
  });

  final String value;
  final bool selected;
  final bool enabled;
  final String semanticLabel;
  final ValueChanged<String> onAccept;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = theme.colorScheme;
    final String display = value.trim().isEmpty
        ? l10n.patientsMergeEmptyValueLabel
        : value;
    final Widget child = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacing.sm),
      decoration: BoxDecoration(
        color: selected
            ? colors.primaryContainer.withValues(alpha: 0.55)
            : colors.surfaceContainerHighest.withValues(alpha: 0.35),
        border: theme.borders.all(
          color: selected
              ? colors.primary
              : colors.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Text(
        display,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: value.trim().isEmpty
              ? colors.onSurfaceVariant
              : colors.onSurface,
          fontStyle: value.trim().isEmpty ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );

    return Semantics(
      label: '$semanticLabel: $display',
      child: DragTarget<String>(
        onWillAcceptWithDetails: (DragTargetDetails<String> details) {
          return enabled && details.data != value;
        },
        onAcceptWithDetails: (DragTargetDetails<String> details) {
          onAccept(details.data);
        },
        builder:
            (
              BuildContext context,
              List<String?> candidateData,
              List<dynamic> rejectedData,
            ) {
              final bool hovering = candidateData.isNotEmpty;
              final Widget decorated = hovering
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        border: theme.borders.all(color: colors.primary),
                      ),
                      child: child,
                    )
                  : child;
              if (!enabled || value.trim().isEmpty) {
                return decorated;
              }
              return LongPressDraggable<String>(
                data: value,
                feedback: Material(
                  elevation: 3,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: child,
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.35, child: decorated),
                child: decorated,
              );
            },
      ),
    );
  }
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
