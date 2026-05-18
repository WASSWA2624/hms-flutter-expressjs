abstract final class AppDisplay {
  static String apiLabel(String? value) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return '';
    }

    return normalized
        .split('_')
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
