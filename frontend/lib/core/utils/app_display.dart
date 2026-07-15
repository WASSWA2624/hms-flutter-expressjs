abstract final class AppDisplay {
  static final RegExp _separatorPattern = RegExp(r'[_\-]+');
  static final RegExp _whitespacePattern = RegExp(r'\s+');

  /// Converts a snake_case or kebab-case API value to a human-readable label.
  ///
  /// Handles underscores, hyphens, and whitespace as word separators.
  static String apiLabel(String? value) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return '';
    }

    return normalized
        .replaceAll(_separatorPattern, ' ')
        .split(_whitespacePattern)
        .where((String part) => part.isNotEmpty)
        .map((String part) {
          final String lower = part.toLowerCase();
          return lower.substring(0, 1).toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }

  static String joinNonEmpty(
    Iterable<String?> values, {
    String separator = ' - ',
  }) {
    return values
        .map((String? value) => value?.trim() ?? '')
        .where(
          (String value) => value.isNotEmpty && value.toLowerCase() != 'null',
        )
        .join(separator);
  }
}
