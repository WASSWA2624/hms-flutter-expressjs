import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

/// Stage-aware next step for a theater case row.
enum TheaterNextActionKind {
  updateReadiness,
  startCase,
  anesthesia,
  postOp,
  handover,
}

TheaterNextActionKind? theaterResolveNextActionKind(TheaterCase theaterCase) {
  if (theaterCase.normalizedStatus == 'CANCELLED' ||
      theaterCase.normalizedStatus == 'COMPLETED') {
    return null;
  }
  if (!theaterCase.isReady) {
    return TheaterNextActionKind.updateReadiness;
  }
  if (theaterCase.normalizedStatus == 'SCHEDULED') {
    return TheaterNextActionKind.startCase;
  }
  if (!theaterCase.hasFinalAnesthesia) {
    return TheaterNextActionKind.anesthesia;
  }
  if (!theaterCase.hasFinalPostOp) {
    return TheaterNextActionKind.postOp;
  }
  return TheaterNextActionKind.handover;
}

String theaterNextActionLabel(
  AppLocalizations l10n,
  TheaterCase theaterCase,
) {
  final TheaterNextActionKind? kind = theaterResolveNextActionKind(theaterCase);
  if (kind == null) {
    return switch (theaterCase.normalizedStatus) {
      'CANCELLED' => l10n.theaterStatusCancelled,
      'COMPLETED' => l10n.theaterStatusCompleted,
      _ => l10n.profileUnknownValue,
    };
  }
  return switch (kind) {
    TheaterNextActionKind.updateReadiness => l10n.theaterUpdateReadinessAction,
    TheaterNextActionKind.startCase => l10n.theaterStartCaseAction,
    TheaterNextActionKind.anesthesia => l10n.theaterAnesthesiaAction,
    TheaterNextActionKind.postOp => l10n.theaterPostOpAction,
    TheaterNextActionKind.handover => l10n.theaterHandoverAction,
  };
}
