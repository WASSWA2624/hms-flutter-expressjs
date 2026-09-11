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

/// Delivery state of the verification email, as the backend last observed it.
///
/// Separate from [RegistrationOutcome] because "still sending" and "could not
/// send" are the same outcome code but very different things to tell a user.
enum RegistrationEmailStatus {
  /// Handed to the mail transport; the result was not known yet when the
  /// backend answered. The code is normally in the inbox moments later.
  pending('PENDING'),

  /// The transport accepted the message.
  sent('SENT'),

  /// Delivery failed. The user needs a new code.
  failed('FAILED'),

  /// The backend did not report a status.
  unknown('');

  const RegistrationEmailStatus(this.wireValue);

  final String wireValue;

  static RegistrationEmailStatus fromWire(Object? raw) {
    final String value = raw?.toString().trim().toUpperCase() ?? '';
    for (final RegistrationEmailStatus status in RegistrationEmailStatus.values) {
      if (status != RegistrationEmailStatus.unknown &&
          status.wireValue == value) {
        return status;
      }
    }
    return RegistrationEmailStatus.unknown;
  }
}

/// Outcome of `POST /auth/register` or `POST /auth/registration-status`.
final class RegistrationResult {
  const RegistrationResult({
    required this.outcome,
    this.email,
    this.emailStatus = RegistrationEmailStatus.unknown,
    this.nextPath,
    this.rejectionCode,
  });

  final RegistrationOutcome outcome;

  /// What the backend last knew about the verification email.
  final RegistrationEmailStatus emailStatus;

  /// Email the verification code was (or will be) sent to.
  final String? email;

  /// Backend-suggested next route, when it supplies one.
  final String? nextPath;

  /// Backend error key for a rejected attempt, so the status lookup can report
  /// the original reason rather than a generic failure.
  final String? rejectionCode;

  bool get accountExists => outcome.accountExists;

  /// True when the verification page should lead with "request a new code"
  /// rather than "check your inbox".
  ///
  /// A send still in flight is not a failure: the backend answers without
  /// waiting for the mail transport, so `pending` is the ordinary path and the
  /// code usually arrives seconds later. Only a delivery the backend could not
  /// complete — or an outcome that reports no status at all — earns the
  /// delayed-email copy.
  bool get needsVerificationResend =>
      outcome == RegistrationOutcome.accountCreatedEmailPending &&
      emailStatus != RegistrationEmailStatus.pending &&
      emailStatus != RegistrationEmailStatus.sent;

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
    final RegistrationEmailStatus emailStatus = verification is Map
        ? RegistrationEmailStatus.fromWire(verification['email_status'])
        : RegistrationEmailStatus.unknown;

    final Object? rejection = map['rejection'];
    final String? rejectionCode = rejection is Map
        ? readString(rejection['code'])
        : null;

    return RegistrationResult(
      outcome: RegistrationOutcome.fromWire(map['outcome']),
      email: email,
      emailStatus: emailStatus,
      nextPath: readString(map['next_path']),
      rejectionCode: rejectionCode,
    );
  }
}
