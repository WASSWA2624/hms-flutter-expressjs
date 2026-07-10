/// Resolves stored media paths (e.g. facility logos) into loadable URLs.
String? resolveAppMediaUrl(String? value, Uri apiBaseUrl) {
  final String? trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  if (trimmed.startsWith('assets/')) {
    return trimmed;
  }

  final Uri? parsed = Uri.tryParse(trimmed);
  if (parsed != null &&
      parsed.hasScheme &&
      (parsed.scheme == 'http' ||
          parsed.scheme == 'https' ||
          parsed.scheme == 'data' ||
          parsed.scheme == 'blob')) {
    return trimmed;
  }

  String pathPart = trimmed;
  String? query;
  final int queryIndex = trimmed.indexOf('?');
  if (queryIndex >= 0) {
    pathPart = trimmed.substring(0, queryIndex);
    query = trimmed.substring(queryIndex + 1);
  }

  pathPart = pathPart.replaceFirst(RegExp(r'^/+'), '');
  if (!pathPart.startsWith('uploads/')) {
    pathPart = 'uploads/$pathPart';
  }

  final Uri resolved = apiBaseUrl.replace(
    path: '/$pathPart',
    query: query,
  );
  return resolved.toString();
}
