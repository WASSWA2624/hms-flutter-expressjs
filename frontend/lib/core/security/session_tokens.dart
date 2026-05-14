typedef DateTimeReader = DateTime Function();

final class SessionTokens {
  SessionTokens({
    required String accessToken,
    String? refreshToken,
    this.accessTokenExpiresAt,
  }) : accessToken = _requiredToken(accessToken, 'accessToken'),
       refreshToken = _optionalToken(refreshToken);

  final String accessToken;
  final String? refreshToken;
  final DateTime? accessTokenExpiresAt;

  bool get hasRefreshToken => refreshToken != null;

  bool isAccessTokenExpired(DateTime now) {
    final expiresAt = accessTokenExpiresAt;
    if (expiresAt == null) {
      return false;
    }

    return !expiresAt.isAfter(now.toUtc());
  }

  @override
  String toString() {
    return 'SessionTokens('
        'accessToken: <redacted>, '
        'refreshToken: ${refreshToken == null ? 'none' : '<redacted>'}, '
        'accessTokenExpiresAt: $accessTokenExpiresAt'
        ')';
  }

  static String _requiredToken(String value, String name) {
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) {
      throw ArgumentError.value(value, name, 'Token value is required.');
    }

    return normalizedValue;
  }

  static String? _optionalToken(String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }

    return normalizedValue;
  }
}
