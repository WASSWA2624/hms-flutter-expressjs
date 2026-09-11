/// Machine-readable outcome of a registration submission.
///
/// The backend reports one of these on `POST /auth/register` and on
/// `POST /auth/registration-status`. The UI renders from the outcome, never
/// from the transport result, so a request that timed out after the account was
/// created can never be shown as a failed registration.
enum RegistrationOutcome {
  /// Account exists and the verification email was accepted by the transport.
  accountCreatedEmailSent('ACCOUNT_CREATED_EMAIL_SENT'),

  /// Account exists but the verification email is delayed or failed.
  accountCreatedEmailPending('ACCOUNT_CREATED_EMAIL_PENDING'),

  /// The attempt is still running on the backend.
  inProgress('REGISTRATION_IN_PROGRESS'),

  /// The backend rejected the submission; nothing was created.
  rejected('REGISTRATION_REJECTED'),

  /// No attempt with this idempotency key ever reached the backend.
  unknown('REGISTRATION_UNKNOWN');

  const RegistrationOutcome(this.wireValue);

  final String wireValue;

  /// True when an account, tenant, and facility exist for this attempt.
  bool get accountExists =>
      this == RegistrationOutcome.accountCreatedEmailSent ||
      this == RegistrationOutcome.accountCreatedEmailPending;

  /// True when the verification email did not go out and the user needs to
  /// request a new code.
  bool get needsVerificationResend =>
      this == RegistrationOutcome.accountCreatedEmailPending;

  static RegistrationOutcome fromWire(Object? raw) {
    final String value = raw?.toString().trim().toUpperCase() ?? '';
    for (final RegistrationOutcome outcome in RegistrationOutcome.values) {
      if (outcome.wireValue == value) {
        return outcome;
      }
    }
    return RegistrationOutcome.unknown;
  }
}

/// Outcome of `POST /auth/register` or `POST /auth/registration-status`.
final class RegistrationResult {
  const RegistrationResult({
    required this.outcome,
    this.email,
    this.nextPath,
    this.rejectionCode,
  });

  final RegistrationOutcome outcome;

  /// Email the verification code was (or will be) sent to.
  final String? email;

  /// Backend-suggested next route, when it supplies one.
  final String? nextPath;

  /// Backend error key for a rejected attempt, so the status lookup can report
  /// the original reason rather than a generic failure.
  final String? rejectionCode;

  bool get accountExists => outcome.accountExists;

  bool get needsVerificationResend => outcome.needsVerificationResend;

  static RegistrationResult fromResponseData(Object? data) {
    if (data is! Map) {
      return const RegistrationResult(outcome: RegistrationOutcome.unknown);
    }

    final Map<Object?, Object?> map = data;

    String? readString(Object? value) {
      final String text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    }

    final Object? verification = map['verification'];
    final String? email = verification is Map
        ? readString(verification['email'])
        : null;

    final Object? rejection = map['rejection'];
    final String? rejectionCode = rejection is Map
        ? readString(rejection['code'])
        : null;

    return RegistrationResult(
      outcome: RegistrationOutcome.fromWire(map['outcome']),
      email: email,
      nextPath: readString(map['next_path']),
      rejectionCode: rejectionCode,
    );
  }
}
