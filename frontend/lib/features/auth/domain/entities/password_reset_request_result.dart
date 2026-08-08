/// Outcome of POST /auth/forgot-password.
final class PasswordResetRequestResult {
  const PasswordResetRequestResult({
    this.maskedEmail,
    this.maskedPhone,
  });

  final String? maskedEmail;
  final String? maskedPhone;

  factory PasswordResetRequestResult.fromResponseData(Object? data) {
    if (data is! Map) {
      return const PasswordResetRequestResult();
    }

    final Map<Object?, Object?> map = data;
    String? read(String key) {
      final Object? value = map[key];
      if (value == null) {
        return null;
      }
      final String text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    return PasswordResetRequestResult(
      maskedEmail: read('masked_email') ?? read('maskedEmail'),
      maskedPhone: read('masked_phone') ?? read('maskedPhone'),
    );
  }
}
