import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/room_similarity.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum RoomSimilarityAction { cancel, useExisting, proceed }

final class RoomSimilarityDialogResult {
  const RoomSimilarityDialogResult._({
    required this.action,
    this.selectedRoom,
  });

  const RoomSimilarityDialogResult.cancel()
    : this._(action: RoomSimilarityAction.cancel);

  const RoomSimilarityDialogResult.proceed()
    : this._(action: RoomSimilarityAction.proceed);

  const RoomSimilarityDialogResult.useExisting(RoomProfile room)
    : this._(action: RoomSimilarityAction.useExisting, selectedRoom: room);

  final RoomSimilarityAction action;
  final RoomProfile? selectedRoom;
}

/// Room adapter over [showAppSimilarityReviewDialog].
Future<RoomSimilarityDialogResult> showRoomSimilarityDialog(
  BuildContext context, {
  required RoomSimilarityProposedValues proposed,
  required List<RoomSimilarityMatch> matches,
  bool allowProceed = true,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<RoomSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactNameConflict = visibleMatches.any(
    (RoomSimilarityMatch match) => match.exactNameConflict,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  final bool canProceed = allowProceed && !hasExactNameConflict;
  final int overallScore = _maxMatchScore(visibleMatches);

  final String dialogTitle = hasExactNameConflict || hasMatches
      ? l10n.tenantFacilitySimilarRoomDialogTitle
      : l10n.tenantFacilityNoSimilarRoomDialogTitle;
  final String bannerTitle = hasExactNameConflict
      ? l10n.tenantFacilityRoomNameAlreadyInUse
      : hasMatches
      ? l10n.tenantFacilitySimilarRoomWarningTitle
      : l10n.tenantFacilityNoSimilarRoomBannerTitle;
  final String bannerMessage = hasExactNameConflict || hasMatches
      ? l10n.tenantFacilitySimilarRoomWarningBody
      : l10n.tenantFacilityNoSimilarRoomDialogBody;
  final AppFormInformationVariant bannerVariant = hasExactNameConflict
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<RoomProfile>> appMatches = visibleMatches
      .map((RoomSimilarityMatch match) {
        final List<AppSimilarityFieldRow> fields = match.fieldComparisons
            .map(
              (RoomFieldComparison comparison) => AppSimilarityFieldRow(
                key: comparison.field,
                label: _roomFieldLabel(l10n, comparison.field),
                proposedValue: comparison.inputValue,
                existingValue: comparison.candidateValue,
                score: comparison.score,
              ),
            )
            .toList(growable: false);
        return AppSimilarityMatch<RoomProfile>(
          item: match.room,
          title: match.room.name,
          subtitle: _nonEmpty(match.room.displayId),
          overallScore: match.score,
          isExact: match.exactNameConflict,
          fields: fields,
        );
      })
      .toList(growable: false);

  final AppSimilarityReviewResult<RoomProfile> result =
      await showAppSimilarityReviewDialog<RoomProfile>(
        context,
        title: dialogTitle,
        bannerTitle: bannerTitle,
        bannerMessage: bannerMessage,
        bannerVariant: bannerVariant,
        proposedFields: <AppSimilarityProposedField>[
          AppSimilarityProposedField(
            key: 'name',
            label: l10n.tenantFacilityRoomNameLabel,
            initialValue: proposed.name,
            isRequired: true,
          ),
          AppSimilarityProposedField(
            key: 'ward',
            label: l10n.tenantFacilityRoomWardLabel,
            initialValue: proposed.wardName ?? '',
          ),
          AppSimilarityProposedField(
            key: 'floor',
            label: l10n.tenantFacilityRoomFloorLabel,
            initialValue: proposed.floor ?? '',
          ),
        ],
        matches: appMatches,
        overallScore: overallScore,
        blockProceed: !canProceed,
        enableRetry: false,
        proposedReadOnly: true,
        proceedLabel: l10n.tenantFacilityProceedCreateRoomAction,
        continueLabel: l10n.tenantFacilityContinueCreateRoomAction,
        useThisLabel: l10n.tenantFacilityUseThisRoomAction,
        proposedHeading: l10n.tenantFacilitySimilarRoomProposedHeading,
        matchesHeading: l10n.tenantFacilitySimilarTenantMatchesHeading,
        exactBadgeLabel: l10n.tenantFacilitySimilarTenantExactConflictLabel,
        nearBadgeLabel: l10n.tenantFacilitySimilarTenantNearMatchLabel,
        existingHeading: l10n.tenantFacilitySimilarRoomExistingHeading,
        fieldColumnLabel: l10n.tenantFacilitySimilarTenantFieldLabel,
        proposedColumnLabel: l10n.tenantFacilitySimilarTenantProposedValueLabel,
        existingColumnLabel: l10n.tenantFacilitySimilarTenantExistingValueLabel,
        closestMatchLabel: l10n.tenantFacilityRoomOverallSimilarityLabel,
        noMatchLabel: l10n.tenantFacilityRoomNoMatchScoreLabel(overallScore),
        emptyValueLabel: l10n.clinicalOrderEmptyValueLabel,
        dialogIcon: hasExactNameConflict
            ? Icons.gpp_bad_outlined
            : hasMatches
            ? Icons.warning_amber_outlined
            : Icons.verified_outlined,
      );

  switch (result.action) {
    case AppSimilarityReviewAction.cancel:
    case AppSimilarityReviewAction.retry:
      return const RoomSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.useExisting:
      final RoomProfile? room = result.selected;
      if (room == null) {
        return const RoomSimilarityDialogResult.cancel();
      }
      return RoomSimilarityDialogResult.useExisting(room);
    case AppSimilarityReviewAction.proceed:
      return const RoomSimilarityDialogResult.proceed();
  }
}

int _maxMatchScore(List<RoomSimilarityMatch> matches) {
  if (matches.isEmpty) {
    return 0;
  }
  return matches
      .map((RoomSimilarityMatch match) => match.score)
      .reduce((int a, int b) => a > b ? a : b);
}

String? _nonEmpty(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

String _roomFieldLabel(AppLocalizations l10n, String field) {
  return switch (field) {
    'name' => l10n.tenantFacilityRoomNameLabel,
    'ward' => l10n.tenantFacilityRoomWardLabel,
    'floor' => l10n.tenantFacilityRoomFloorLabel,
    _ => AppDisplay.apiLabel(field),
  };
}
