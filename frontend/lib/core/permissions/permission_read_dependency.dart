/// Guard helpers: non-read actions require the matching `{domain}:read` atom
/// when that atom exists in the assignable catalog.
library;

/// Returns `{domain}:read` when [permissionCode] is a non-read action and a
/// matching read atom is present in [catalogCodes]. Otherwise null.
String? requiredReadPermissionFor(
  String permissionCode, {
  Iterable<String> catalogCodes = const <String>[],
}) {
  final String code = permissionCode.trim();
  final int separator = code.indexOf(':');
  if (separator <= 0 || separator >= code.length - 1) {
    return null;
  }
  final String domain = code.substring(0, separator);
  final String action = code.substring(separator + 1);
  if (action.isEmpty || action == 'read') {
    return null;
  }
  final String required = '$domain:read';
  final List<String> catalog = catalogCodes
      .map((String entry) => entry.trim())
      .where((String entry) => entry.isNotEmpty)
      .toList(growable: false);
  if (catalog.isNotEmpty && !catalog.contains(required)) {
    return null;
  }
  return required;
}

/// Expands [selectedCodes] so every non-read action also includes its read.
Set<String> expandPermissionCodesWithRequiredReads(
  Iterable<String> selectedCodes, {
  Iterable<String> catalogCodes = const <String>[],
}) {
  final Set<String> expanded = selectedCodes
      .map((String entry) => entry.trim())
      .where((String entry) => entry.isNotEmpty)
      .toSet();
  for (final String code in [...expanded]) {
    final String? required = requiredReadPermissionFor(
      code,
      catalogCodes: catalogCodes,
    );
    if (required != null) {
      expanded.add(required);
    }
  }
  return expanded;
}

/// Whether [permissionCode] may be deselected given the remaining selection.
///
/// Read atoms that other selected actions in the same domain still need cannot
/// be removed.
bool canDeselectPermissionCode(
  String permissionCode, {
  required Iterable<String> selectedCodes,
  Iterable<String> catalogCodes = const <String>[],
}) {
  final String code = permissionCode.trim();
  final int separator = code.indexOf(':');
  if (separator <= 0 || separator >= code.length - 1) {
    return true;
  }
  final String action = code.substring(separator + 1);
  if (action != 'read') {
    return true;
  }
  final Set<String> remaining = selectedCodes
      .map((String entry) => entry.trim())
      .where((String entry) => entry.isNotEmpty && entry != code)
      .toSet();
  for (final String selected in remaining) {
    final String? required = requiredReadPermissionFor(
      selected,
      catalogCodes: catalogCodes.isEmpty ? selectedCodes : catalogCodes,
    );
    if (required == code) {
      return false;
    }
  }
  return true;
}
