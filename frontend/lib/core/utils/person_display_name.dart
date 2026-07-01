/// Resolves a human-friendly label for a person record.
///
/// Priority: first + last name → [displayName] → [username] → email → [fallbackId].
String resolvePersonDisplayName({
  String? firstName,
  String? lastName,
  String? displayName,
  String? username,
  String? email,
  String? fallbackId,
}) {
  final String combinedName = <String>[
    if ((firstName ?? '').trim().isNotEmpty) firstName!.trim(),
    if ((lastName ?? '').trim().isNotEmpty) lastName!.trim(),
  ].join(' ').trim();
  if (combinedName.isNotEmpty) {
    return combinedName;
  }

  final String? normalizedDisplay = _nonEmpty(displayName);
  if (normalizedDisplay != null) {
    return normalizedDisplay;
  }

  final String? normalizedUsername = _nonEmpty(username);
  if (normalizedUsername != null) {
    return normalizedUsername;
  }

  final String emailLocal = _emailLocalDisplayName(email);
  if (emailLocal.isNotEmpty) {
    return emailLocal;
  }

  final String? normalizedEmail = _nonEmpty(email);
  if (normalizedEmail != null) {
    return normalizedEmail;
  }

  return _nonEmpty(fallbackId) ?? '';
}

/// Builds up to two uppercase initials from [displayName].
String personInitials(String displayName) {
  final String trimmed = displayName.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  final List<String> words = trimmed
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.length == 1) {
    final String word = words.first;
    return word.length >= 2
        ? word.substring(0, 2).toUpperCase()
        : word.toUpperCase();
  }
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}

String _emailLocalDisplayName(String? email) {
  final String normalized = (email ?? '').trim();
  if (normalized.isEmpty || !normalized.contains('@')) {
    return '';
  }
  final String local = normalized.split('@').first.trim();
  if (local.isEmpty) {
    return '';
  }
  return local
      .replaceAll(RegExp(r'[._-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .map(_titleCaseWord)
      .join(' ');
}

String _titleCaseWord(String part) {
  if (part.isEmpty) {
    return part;
  }
  if (part.length == 1) {
    return part.toUpperCase();
  }
  return '${part[0].toUpperCase()}${part.substring(1)}';
}

String? _nonEmpty(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
