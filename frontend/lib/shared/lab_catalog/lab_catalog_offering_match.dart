import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';

/// Max rows loaded when collecting facility offerings used only for match keys.
const int labEnableOfferedMatchLimit = 5000;

/// Marks platform/tenant catalog rows that already have an active facility offering.
///
/// Matching uses api/id/display ids, codes, and case-insensitive names so tenant
/// catalog rows still resolve against offerings even when public ids differ.
List<LabCatalogItem> markLabCatalogItemsOfferedAtFacility({
  required List<LabCatalogItem> platformItems,
  required List<LabCatalogItem> offeredItems,
}) {
  if (platformItems.isEmpty) {
    return const <LabCatalogItem>[];
  }
  if (offeredItems.isEmpty) {
    return List<LabCatalogItem>.of(platformItems, growable: false);
  }

  final Set<String> offeredIds = <String>{};
  final Set<String> offeredCodes = <String>{};
  final Set<String> offeredNames = <String>{};
  for (final LabCatalogItem item in offeredItems) {
    _addLabOfferedIdentity(item, offeredIds);
    final String? code = item.code?.trim();
    if (code != null && code.isNotEmpty) {
      offeredCodes.add(code.toUpperCase());
    }
    final String? name = item.name?.trim();
    if (name != null && name.isNotEmpty) {
      offeredNames.add(name.toLowerCase());
    }
  }

  return platformItems
      .map((LabCatalogItem item) {
        if (item.isOfferedAtFacility) {
          return item;
        }
        final String? code = item.code?.trim();
        final String? name = item.name?.trim();
        final bool isOffered =
            _labOfferedIdentityMatches(item, offeredIds) ||
            (code != null &&
                code.isNotEmpty &&
                offeredCodes.contains(code.toUpperCase())) ||
            (name != null &&
                name.isNotEmpty &&
                offeredNames.contains(name.toLowerCase()));
        return isOffered ? item.copyWith(isOfferedAtFacility: true) : item;
      })
      .toList(growable: false);
}

void _addLabOfferedIdentity(LabCatalogItem item, Set<String> ids) {
  for (final String? candidate in <String?>[
    item.apiId,
    item.id,
    item.displayId,
  ]) {
    final String value = candidate?.trim() ?? '';
    if (value.isNotEmpty) {
      ids.add(value);
    }
  }
}

bool _labOfferedIdentityMatches(LabCatalogItem item, Set<String> offeredIds) {
  for (final String? candidate in <String?>[
    item.apiId,
    item.id,
    item.displayId,
  ]) {
    final String value = candidate?.trim() ?? '';
    if (value.isNotEmpty && offeredIds.contains(value)) {
      return true;
    }
  }
  return false;
}
