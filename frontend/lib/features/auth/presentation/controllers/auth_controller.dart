import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/idempotency.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hosspi_hms/features/auth/domain/entities/auth_identify_result.dart';
import 'package:hosspi_hms/features/auth/domain/entities/email_verification_result.dart';
import 'package:hosspi_hms/features/auth/domain/entities/password_reset_request_result.dart';
import 'package:hosspi_hms/features/auth/domain/entities/registration_result.dart';
import 'package:hosspi_hms/features/auth/domain/repositories/auth_repository.dart';

final authControllerProvider =
    NotifierProvider<AuthController, AuthControllerState>(AuthController.new);

final class AuthControllerState {
  const AuthControllerState({
    this.isSubmitting = false,
    this.failure,
    this.registrationSubmitted = false,
    this.passwordChanged = false,
    this.passwordResetSubmitted = false,
    this.passwordResetCompleted = false,
    this.emailVerificationCompleted = false,
    this.awaitingPlatformApproval = false,
    this.platformAdminContacts = const <AuthPlatformAdminContact>[],
    this.identifyTenants = const <AuthTenantOption>[],
    this.passwordResetMaskedEmail,
    this.passwordResetMaskedPhone,
    this.loginPrefillIdentifier,
    this.loginPrefillPassword,
  });

  final bool isSubmitting;
  final AppFailure? failure;
  final bool registrationSubmitted;
  final bool passwordChanged;
  final bool passwordResetSubmitted;
  final bool passwordResetCompleted;
  final bool emailVerificationCompleted;
  final bool awaitingPlatformApproval;
  final List<AuthPlatformAdminContact> platformAdminContacts;
  final List<AuthTenantOption> identifyTenants;
  final String? passwordResetMaskedEmail;
  final String? passwordResetMaskedPhone;

  /// One-shot credentials after password reset (never persisted / never in URL).
  final String? loginPrefillIdentifier;
  final String? loginPrefillPassword;

  AuthControllerState copyWith({
    bool? isSubmitting,
    AppFailure? failure,
    bool clearFailure = false,
    bool? registrationSubmitted,
    bool? passwordChanged,
    bool? passwordResetSubmitted,
    bool? passwordResetCompleted,
    bool? emailVerificationCompleted,
    bool? awaitingPlatformApproval,
    List<AuthPlatformAdminContact>? platformAdminContacts,
    bool clearPlatformAdminContacts = false,
    List<AuthTenantOption>? identifyTenants,
    bool clearIdentifyTenants = false,
    String? passwordResetMaskedEmail,
    String? passwordResetMaskedPhone,
    bool clearPasswordResetContacts = false,
    String? loginPrefillIdentifier,
    String? loginPrefillPassword,
    bool clearLoginPrefill = false,
  }) {
    return AuthControllerState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : failure ?? this.failure,
      registrationSubmitted:
          registrationSubmitted ?? this.registrationSubmitted,
      passwordChanged: passwordChanged ?? this.passwordChanged,
      passwordResetSubmitted:
          passwordResetSubmitted ?? this.passwordResetSubmitted,
      passwordResetCompleted:
          passwordResetCompleted ?? this.passwordResetCompleted,
      emailVerificationCompleted:
          emailVerificationCompleted ?? this.emailVerificationCompleted,
      awaitingPlatformApproval:
          awaitingPlatformApproval ?? this.awaitingPlatformApproval,
      platformAdminContacts: clearPlatformAdminContacts
          ? const <AuthPlatformAdminContact>[]
          : platformAdminContacts ?? this.platformAdminContacts,
      identifyTenants: clearIdentifyTenants
          ? const <AuthTenantOption>[]
          : identifyTenants ?? this.identifyTenants,
      passwordResetMaskedEmail: clearPasswordResetContacts
          ? null
          : passwordResetMaskedEmail ?? this.passwordResetMaskedEmail,
      passwordResetMaskedPhone: clearPasswordResetContacts
          ? null
          : passwordResetMaskedPhone ?? this.passwordResetMaskedPhone,
      loginPrefillIdentifier: clearLoginPrefill
          ? null
          : loginPrefillIdentifier ?? this.loginPrefillIdentifier,
      loginPrefillPassword: clearLoginPrefill
          ? null
          : loginPrefillPassword ?? this.loginPrefillPassword,
    );
  }
}

final class AuthController extends Notifier<AuthControllerState> {
  /// Idempotency key for the registration submission currently being retried,
  /// with the form fingerprint it belongs to.
  String? _pendingRegistrationKey;
  String? _pendingRegistrationFingerprint;

  @override
  AuthControllerState build() {
    return const AuthControllerState();
  }

  void clearFailure() {
    if (state.failure == null) {
      return;
    }

    state = state.copyWith(clearFailure: true);
  }

  void clearSubmitting() => _finishSubmitting();

  /// The single reset point for the submit-in-flight flag. Every submit flow
  /// runs this in a `finally`, so success, server failure, a thrown timeout or
  /// network error, and provider disposal all leave the auth forms enabled —
  /// this notifier is shared by every auth page, and a flag left set here
  /// renders their fields `enabled: false` until a full page reload.
  void _finishSubmitting() {
    if (!ref.mounted || !state.isSubmitting) {
      return;
    }

    state = state.copyWith(isSubmitting: false);
  }

  void clearIdentifyTenants() {
    if (state.identifyTenants.isEmpty) {
      return;
    }

    state = state.copyWith(clearIdentifyTenants: true);
  }

  void clearPasswordResetSubmitted() {
    if (!state.passwordResetSubmitted &&
        state.passwordResetMaskedEmail == null &&
        state.passwordResetMaskedPhone == null) {
      return;
    }

    state = state.copyWith(
      passwordResetSubmitted: false,
      clearPasswordResetContacts: true,
    );
  }

  void clearPasswordResetCompleted() {
    if (!state.passwordResetCompleted &&
        state.loginPrefillIdentifier == null &&
        state.loginPrefillPassword == null) {
      return;
    }

    state = state.copyWith(
      passwordResetCompleted: false,
      clearLoginPrefill: true,
    );
  }

  void clearLoginPrefill() {
    if (state.loginPrefillIdentifier == null &&
        state.loginPrefillPassword == null) {
      return;
    }

    state = state.copyWith(clearLoginPrefill: true);
  }

  void clearEmailVerificationCompleted() {
    if (!state.emailVerificationCompleted &&
        !state.awaitingPlatformApproval &&
        state.platformAdminContacts.isEmpty) {
      return;
    }

    state = state.copyWith(
      emailVerificationCompleted: false,
      awaitingPlatformApproval: false,
      clearPlatformAdminContacts: true,
    );
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    if (state.isSubmitting) {
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearFailure: true);
    try {
      final AuthRepository repository = ref.read(authRepositoryProvider);
      final result = await repository.login(
        identifier: identifier,
        password: password,
      );

      return await result.when(
        success: (AuthSession session) async {
          // Login already returns a complete session payload. Persist first so
          // authenticated clients can read tokens from storage when needed.
          await ref.read(sessionStateProvider.notifier).persistSession(session);
          state = state.copyWith(isSubmitting: false, clearFailure: true);
          return true;
        },
        failure: (AppFailure failure) async {
          state = state.copyWith(isSubmitting: false, failure: failure);
          return false;
        },
      );
    } catch (_) {
      // Report rather than rethrow: an escaping error from the sign-in button
      // leaves the user with a dead form and no message.
      if (ref.mounted) {
        state = state.copyWith(failure: const AppFailure.unexpected());
      }
      return false;
    } finally {
      _finishSubmitting();
    }
  }

  /// Submits a registration and returns the outcome the backend confirmed.
  ///
  /// Returns `null` only when the backend confirmed that no account exists, or
  /// rejected the submission; the failure is on [AuthControllerState.failure].
  /// A transport error alone never produces `null` — it triggers a status
  /// lookup first, because a timed-out request may well have created the
  /// account.
  Future<RegistrationResult?> register({
    required String email,
    required String password,
    required String facilityName,
    required String adminName,
    required String facilityType,
    required String phone,
    String? tenantName,
    String? location,
    String? interests,
  }) async {
    if (state.isSubmitting) {
      return null;
    }

    final String idempotencyKey = _idempotencyKeyForRegistration(
      email: email,
      facilityName: facilityName,
      adminName: adminName,
      facilityType: facilityType,
      phone: phone,
      tenantName: tenantName,
    );

    state = state.copyWith(
      isSubmitting: true,
      clearFailure: true,
      registrationSubmitted: false,
    );
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .register(
            email: email,
            password: password,
            facilityName: facilityName,
            adminName: adminName,
            facilityType: facilityType,
            phone: phone,
            idempotencyKey: idempotencyKey,
            tenantName: tenantName,
            location: location,
            interests: interests,
          );

      return await result.when(
        success: (RegistrationResult registration) async {
          if (registration.accountExists) {
            return _completeRegistration(registration);
          }

          // A success envelope that reports no account means an earlier
          // submission with this key is still running. Keep asking until it
          // settles rather than rendering it as a completed registration.
          return _resolveAndReport(
            idempotencyKey: idempotencyKey,
            fallbackFailure: const AppFailure.timeout(),
          );
        },
        failure: (AppFailure failure) async {
          if (!_warrantsRegistrationStatusLookup(failure)) {
            state = state.copyWith(isSubmitting: false, failure: failure);
            return null;
          }

          // The request did not complete, but the backend may still have
          // created the account. Resolve the truth before reporting anything.
          return _resolveAndReport(
            idempotencyKey: idempotencyKey,
            fallbackFailure: failure,
          );
        },
      );
    } finally {
      _finishSubmitting();
    }
  }

  /// Reports whatever the backend confirms about an unfinished submission,
  /// falling back to [fallbackFailure] when it confirms nothing.
  Future<RegistrationResult?> _resolveAndReport({
    required String idempotencyKey,
    required AppFailure fallbackFailure,
  }) async {
    final RegistrationResult? resolved = await _resolveRegistrationStatus(
      idempotencyKey,
    );

    if (resolved != null && resolved.accountExists) {
      return _completeRegistration(resolved);
    }

    if (resolved != null &&
        resolved.outcome != RegistrationOutcome.inProgress) {
      // The backend confirmed it has no record of this attempt, or rejected
      // it, so a failure message is the truth and the next submit is new.
      _clearPendingRegistration();
    }

    // Otherwise nothing was confirmed either way: keep the key so a resubmit
    // replays the same attempt instead of creating a second workspace.
    state = state.copyWith(isSubmitting: false, failure: fallbackFailure);
    return null;
  }

  RegistrationResult _completeRegistration(RegistrationResult registration) {
    _clearPendingRegistration();
    state = state.copyWith(
      isSubmitting: false,
      clearFailure: true,
      registrationSubmitted: false,
    );
    return registration;
  }

  /// Transport-level failures where the backend may still have succeeded.
  bool _warrantsRegistrationStatusLookup(AppFailure failure) {
    return switch (failure.category) {
      AppFailureCategory.timeout ||
      AppFailureCategory.network ||
      AppFailureCategory.offline => true,
      AppFailureCategory.unexpectedResponse => (failure.statusCode ?? 0) >= 500,
      _ => false,
    };
  }

  /// Asks the backend what happened, re-checking a few times while the attempt
  /// is still running. This resolves truth rather than waiting longer on the
  /// original request: the lookup is a separate, cheap, non-mutating call.
  Future<RegistrationResult?> _resolveRegistrationStatus(
    String idempotencyKey,
  ) async {
    const List<Duration> backoff = <Duration>[
      Duration.zero,
      Duration(seconds: 1),
      Duration(seconds: 2),
    ];

    RegistrationResult? latest;
    for (final Duration delay in backoff) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      if (!ref.mounted) {
        return latest;
      }

      final Result<RegistrationResult> lookup = await ref
          .read(authRepositoryProvider)
          .registrationStatus(idempotencyKey: idempotencyKey);

      final RegistrationResult? resolved = lookup.when(
        success: (RegistrationResult registration) => registration,
        failure: (_) => null,
      );

      if (resolved == null) {
        // The lookup itself failed; nothing was confirmed either way.
        return latest;
      }

      latest = resolved;
      if (resolved.outcome != RegistrationOutcome.inProgress) {
        return resolved;
      }
    }

    return latest;
  }

  String _idempotencyKeyForRegistration({
    required String email,
    required String facilityName,
    required String adminName,
    required String facilityType,
    required String phone,
    String? tenantName,
  }) {
    final String fingerprint = <String>[
      email.trim().toLowerCase(),
      facilityName.trim(),
      adminName.trim(),
      facilityType.trim(),
      phone.trim(),
      tenantName?.trim() ?? '',
    ].join('|');

    // Resubmitting the same details reuses the key, so a retry after a timeout
    // replays the original attempt. Editing any of them starts a new attempt.
    if (_pendingRegistrationFingerprint == fingerprint &&
        _pendingRegistrationKey != null) {
      return _pendingRegistrationKey!;
    }

    final String key = createIdempotencyKey();
    _pendingRegistrationFingerprint = fingerprint;
    _pendingRegistrationKey = key;
    return key;
  }

  void _clearPendingRegistration() {
    _pendingRegistrationFingerprint = null;
    _pendingRegistrationKey = null;
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (state.isSubmitting) {
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearFailure: true,
      passwordChanged: false,
    );
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
            confirmPassword: confirmPassword,
          );

      return await result.when<Future<bool>>(
        success: (_) async {
          await ref.read(sessionStateProvider.notifier).logout();
          state = state.copyWith(
            isSubmitting: false,
            clearFailure: true,
            passwordChanged: true,
          );
          return true;
        },
        failure: (AppFailure failure) async {
          state = state.copyWith(isSubmitting: false, failure: failure);
          return false;
        },
      );
    } finally {
      _finishSubmitting();
    }
  }

  Future<bool> requestPasswordReset({
    required String email,
    String? tenantId,
  }) async {
    if (state.isSubmitting) {
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearFailure: true,
      passwordResetSubmitted: false,
      clearIdentifyTenants: true,
      clearPasswordResetContacts: true,
    );

    final AuthRepository repository = ref.read(authRepositoryProvider);
    final normalizedEmail = email.trim().toLowerCase();

    try {
      if (tenantId == null || tenantId.trim().isEmpty) {
        final identifyResult = await repository.identify(
          identifier: normalizedEmail,
        );

        return await identifyResult.when<Future<bool>>(
          success: (AuthIdentifyResult result) async {
            if (result.tenants.isEmpty) {
              state = state.copyWith(
                isSubmitting: false,
                failure: const AppFailure.unauthorized(
                  code: 'auth.account_not_found',
                ),
                passwordResetSubmitted: false,
              );
              return false;
            }

            if (result.tenants.length == 1) {
              return _submitForgotPassword(
                repository: repository,
                email: normalizedEmail,
                tenantId: result.tenants.first.tenantId,
              );
            }

            state = state.copyWith(
              isSubmitting: false,
              identifyTenants: result.tenants,
            );
            return false;
          },
          failure: (AppFailure failure) async {
            state = state.copyWith(isSubmitting: false, failure: failure);
            return false;
          },
        );
      }

      return await _submitForgotPassword(
        repository: repository,
        email: normalizedEmail,
        tenantId: tenantId.trim(),
      );
    } finally {
      _finishSubmitting();
    }
  }

  Future<bool> resetPassword({
    String? token,
    String? email,
    String? code,
    required String newPassword,
    required String confirmPassword,
    String? loginPrefillIdentifier,
  }) async {
    if (state.isSubmitting) {
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearFailure: true,
      passwordResetCompleted: false,
      clearLoginPrefill: true,
    );

    try {
      final result = await ref
          .read(authRepositoryProvider)
          .resetPassword(
            token: token,
            email: email,
            code: code,
            newPassword: newPassword,
            confirmPassword: confirmPassword,
          );

      return result.when(
        success: (_) {
          final String? prefillId =
              (loginPrefillIdentifier ?? email)?.trim().toLowerCase();
          state = state.copyWith(
            isSubmitting: false,
            clearFailure: true,
            passwordResetCompleted: true,
            loginPrefillIdentifier:
                prefillId != null && prefillId.isNotEmpty ? prefillId : null,
            loginPrefillPassword: newPassword,
          );
          return true;
        },
        failure: (AppFailure failure) {
          state = state.copyWith(isSubmitting: false, failure: failure);
          return false;
        },
      );
    } finally {
      _finishSubmitting();
    }
  }

  Future<bool> verifyEmail({required String token, String? email}) async {
    if (state.isSubmitting) {
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearFailure: true,
      emailVerificationCompleted: false,
      awaitingPlatformApproval: false,
      clearPlatformAdminContacts: true,
    );

    try {
      final result = await ref
          .read(authRepositoryProvider)
          .verifyEmail(token: token, email: email);

      return result.when(
        success: (EmailVerificationResult verification) {
          state = state.copyWith(
            isSubmitting: false,
            clearFailure: true,
            emailVerificationCompleted: true,
            awaitingPlatformApproval: verification.awaitingPlatformApproval,
            platformAdminContacts: verification.platformAdminContacts,
          );
          return true;
        },
        failure: (AppFailure failure) {
          state = state.copyWith(isSubmitting: false, failure: failure);
          return false;
        },
      );
    } finally {
      _finishSubmitting();
    }
  }

  Future<bool> resendEmailVerification({required String email}) async {
    if (state.isSubmitting) {
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearFailure: true);

    try {
      final result = await ref
          .read(authRepositoryProvider)
          .resendEmailVerification(email: email);

      return result.when(
        success: (_) {
          state = state.copyWith(isSubmitting: false, clearFailure: true);
          return true;
        },
        failure: (AppFailure failure) {
          state = state.copyWith(isSubmitting: false, failure: failure);
          return false;
        },
      );
    } finally {
      _finishSubmitting();
    }
  }

  Future<bool> _submitForgotPassword({
    required AuthRepository repository,
    required String email,
    required String tenantId,
  }) async {
    final result = await repository.forgotPassword(
      email: email,
      tenantId: tenantId,
    );

    return result.when(
      success: (PasswordResetRequestResult delivery) {
        state = state.copyWith(
          isSubmitting: false,
          clearFailure: true,
          passwordResetSubmitted: true,
          clearIdentifyTenants: true,
          passwordResetMaskedEmail: delivery.maskedEmail,
          passwordResetMaskedPhone: delivery.maskedPhone,
        );
        return true;
      },
      failure: (AppFailure failure) {
        state = state.copyWith(isSubmitting: false, failure: failure);
        return false;
      },
    );
  }
}
