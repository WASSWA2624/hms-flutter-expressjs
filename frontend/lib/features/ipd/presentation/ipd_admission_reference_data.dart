import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';

const String ipdUnknownWardId = '__ipd_unknown_ward__';
const String ipdUnknownRoomIdPrefix = '__ipd_unknown_room__:';

/// Maps IPD workspace reference beds into the shared clinical admission picker.
ClinicalActionReferenceData ipdAdmissionReferenceData(
  BuildContext context,
  IpdReferenceData referenceData,
) {
  final AppLocalizations l10n = context.l10n;
  final Map<String, ClinicalActionCatalogOption> wards =
      <String, ClinicalActionCatalogOption>{
        for (final IpdWardOption ward in referenceData.wards)
          ward.id: ClinicalActionCatalogOption(
            id: ward.id,
            name: ward.displayTitle,
            category: ward.wardType,
            status: ward.isActive ? 'ACTIVE' : 'INACTIVE',
          ),
      };
  final Map<String, ClinicalActionCatalogOption> rooms =
      <String, ClinicalActionCatalogOption>{};
  final List<ClinicalActionCatalogOption> beds =
      <ClinicalActionCatalogOption>[];

  for (final IpdBedOption bed in referenceData.availableBeds) {
    final String wardId = _ipdBedWardId(bed);
    final String roomId = _ipdBedRoomId(bed, wardId);
    wards.putIfAbsent(
      wardId,
      () => ClinicalActionCatalogOption(
        id: wardId,
        name: _firstDisplayValue(<String?>[
          bed.wardName,
          bed.wardId,
          l10n.profileUnknownValue,
        ]),
      ),
    );
    rooms.putIfAbsent(
      roomId,
      () => ClinicalActionCatalogOption(
        id: roomId,
        name: _firstDisplayValue(<String?>[
          bed.roomName,
          bed.roomId,
          l10n.profileUnknownValue,
        ]),
        secondaryText: bed.roomFloor,
        parentId: wardId,
      ),
    );
    beds.add(
      ClinicalActionCatalogOption(
        id: bed.id,
        name: bed.displayTitle,
        status: bed.status,
        parentId: wardId,
        secondaryId: roomId,
        secondaryText: bed.displaySubtitle,
      ),
    );
  }

  return ClinicalActionReferenceData(
    wards: wards.values.toList(growable: false),
    rooms: rooms.values.toList(growable: false),
    availableBeds: beds,
  );
}

/// Returns null for synthetic local placeholder IDs that must not be posted.
String? ipdApiCatalogId(String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  if (normalized == ipdUnknownWardId ||
      normalized.startsWith(ipdUnknownRoomIdPrefix)) {
    return null;
  }
  return normalized;
}

String _ipdBedWardId(IpdBedOption bed) {
  return _trimmedValue(bed.wardId) ?? ipdUnknownWardId;
}

String _ipdBedRoomId(IpdBedOption bed, String wardId) {
  return _trimmedValue(bed.roomId) ??
      '$ipdUnknownRoomIdPrefix$wardId:${_trimmedValue(bed.roomName) ?? 'room'}';
}

String _firstDisplayValue(Iterable<String?> values) {
  for (final String? value in values) {
    final String? normalized = _trimmedValue(value);
    if (normalized != null) {
      return normalized;
    }
  }
  return '';
}

String? _trimmedValue(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
