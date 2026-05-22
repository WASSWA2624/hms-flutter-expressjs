import 'package:hosspi_hms/l10n/app_localizations.dart';

String clinicalDispositionActionLabel(
  AppLocalizations l10n, {
  String? sourceQueue,
  String? status,
  String? stage,
  String? location,
  bool hasAdmission = false,
  bool isOpdContext = false,
}) {
  final String normalizedSource = _normalize(sourceQueue);
  final String normalizedStatus = _normalize(status);
  final String normalizedStage = _normalize(stage);
  final String normalizedLocation = _normalize(location);
  final bool hasInpatientLocation =
      normalizedLocation.contains('WARD') ||
      normalizedLocation.contains('BED') ||
      normalizedLocation.contains('IPD');

  if (hasAdmission &&
      _matchesAny(<String>[
        normalizedStage,
        normalizedStatus,
      ], 'DISCHARGE_PLANNED')) {
    return l10n.ipdFinalizeDischargeAction;
  }

  if (hasAdmission &&
      (_isActiveAdmissionState(normalizedStage) ||
          _isActiveAdmissionState(normalizedStatus) ||
          normalizedSource == 'IPD' ||
          hasInpatientLocation)) {
    return l10n.navigationDischargeLabel;
  }

  if (isOpdContext || normalizedSource == 'OPD') {
    return l10n.opdDispositionAction;
  }

  return l10n.clinicalCompleteDispositionAction;
}

bool isClinicalAdmissionDischargeContext({
  String? sourceQueue,
  String? status,
  String? stage,
  String? location,
  bool hasAdmission = false,
}) {
  if (!hasAdmission) {
    return false;
  }
  final String normalizedSource = _normalize(sourceQueue);
  final String normalizedStatus = _normalize(status);
  final String normalizedStage = _normalize(stage);
  final String normalizedLocation = _normalize(location);

  return _isActiveAdmissionState(normalizedStage) ||
      _isActiveAdmissionState(normalizedStatus) ||
      normalizedSource == 'IPD' ||
      normalizedLocation.contains('WARD') ||
      normalizedLocation.contains('BED') ||
      normalizedLocation.contains('IPD');
}

bool _isActiveAdmissionState(String value) {
  return switch (value) {
    'ACTIVE' ||
    'ADMITTED' ||
    'ADMITTED_PENDING_BED' ||
    'ADMITTED_IN_BED' ||
    'TRANSFER_REQUESTED' ||
    'TRANSFER_IN_PROGRESS' ||
    'DISCHARGE_PLANNED' => true,
    _ => false,
  };
}

bool _matchesAny(List<String> values, String target) {
  return values.any((String value) => value == target);
}

String _normalize(String? value) {
  return (value ?? '').trim().toUpperCase();
}
