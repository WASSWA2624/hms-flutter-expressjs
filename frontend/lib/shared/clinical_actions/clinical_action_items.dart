import 'package:flutter/material.dart';

/// App-wide clinical action identifiers used to keep action bars consistent.
enum ClinicalActionKind {
  addNote,
  addDiagnosis,
  requestLab,
  requestRadiology,
  prescribe,
  addProcedure,
  carePlan,
  refer,
  requestAdmission,
  followUp,
  completeDisposition,
  printSummary,
}

@immutable
final class ClinicalActionItem {
  const ClinicalActionItem({
    required this.kind,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
    this.isLoading = false,
    this.tooltip,
    this.semanticLabel,
  });

  final ClinicalActionKind kind;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isLoading;
  final String? tooltip;
  final String? semanticLabel;
}
