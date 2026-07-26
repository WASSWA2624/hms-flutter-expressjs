import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';

/// Max rows loaded when collecting facility offerings used for match + merge.
const int labEnableOfferedMatchLimit = 5000;

/// Marks platform/tenant catalog rows that already have an active facility offering
/// and appends facility offerings that are not already represented in the page.
///
/// Matching uses type-scoped api/id/display ids, codes, and case-insensitive names
/// so tenant catalog rows still resolve against offerings even when public ids
/// differ. Offered-only rows are included so Status → Configured is never empty
/// when the facility has active offerings outside the current platform page.
List<LabCatalogItem> markLabCatalogItemsOfferedAtFacility({
  required List<LabCatalogItem> platformItems,
  required List<LabCatalogItem> offeredItems,
}) {
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
      offeredCodes.add(_typedKey(item, code.toUpperCase()));
    }
    final String? name = item.name?.trim();
    if (name != null && name.isNotEmpty) {
      offeredNames.add(_typedKey(item, name.toLowerCase()));
    }
  }

  final List<LabCatalogItem> marked = platformItems
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
                offeredCodes.contains(_typedKey(item, code.toUpperCase()))) ||
            (name != null &&
                name.isNotEmpty &&
                offeredNames.contains(_typedKey(item, name.toLowerCase())));
        return isOffered ? item.copyWith(isOfferedAtFacility: true) : item;
      })
      .toList(growable: true);

  final Set<String> coveredIds = <String>{};
  final Set<String> coveredCodes = <String>{};
  final Set<String> coveredNames = <String>{};
  for (final LabCatalogItem item in marked) {
    if (!item.isOfferedAtFacility) {
      continue;
    }
    _addLabOfferedIdentity(item, coveredIds);
    final String? code = item.code?.trim();
    if (code != null && code.isNotEmpty) {
      coveredCodes.add(_typedKey(item, code.toUpperCase()));
    }
    final String? name = item.name?.trim();
    if (name != null && name.isNotEmpty) {
      coveredNames.add(_typedKey(item, name.toLowerCase()));
    }
  }

  for (final LabCatalogItem offered in offeredItems) {
    final String? code = offered.code?.trim();
    final String? name = offered.name?.trim();
    final bool alreadyListed =
        _labOfferedIdentityMatches(offered, coveredIds) ||
        (code != null &&
            code.isNotEmpty &&
            coveredCodes.contains(_typedKey(offered, code.toUpperCase()))) ||
        (name != null &&
            name.isNotEmpty &&
            coveredNames.contains(_typedKey(offered, name.toLowerCase())));
    if (alreadyListed) {
      continue;
    }
    final LabCatalogItem configured = offered.isOfferedAtFacility
        ? offered
        : offered.copyWith(isOfferedAtFacility: true);
    marked.add(configured);
    _addLabOfferedIdentity(configured, coveredIds);
    if (code != null && code.isNotEmpty) {
      coveredCodes.add(_typedKey(configured, code.toUpperCase()));
    }
    if (name != null && name.isNotEmpty) {
      coveredNames.add(_typedKey(configured, name.toLowerCase()));
    }
  }

  return List<LabCatalogItem>.of(marked, growable: false);
}

String _typedKey(LabCatalogItem item, String value) {
  return '${item.type.name}:$value';
}

void _addLabOfferedIdentity(LabCatalogItem item, Set<String> ids) {
  for (final String? candidate in <String?>[
    item.apiId,
    item.id,
    item.displayId,
  ]) {
    final String value = candidate?.trim() ?? '';
    if (value.isNotEmpty) {
      ids.add(_typedKey(item, value));
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
    if (value.isNotEmpty && offeredIds.contains(_typedKey(item, value))) {
      return true;
    }
  }
  return false;
}
