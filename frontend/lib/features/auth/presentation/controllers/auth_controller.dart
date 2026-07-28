import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hosspi_hms/features/auth/domain/entities/auth_identify_result.dart';
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
    this.identifyTenants = const <AuthTenantOption>[],
  });

  final bool isSubmitting;
  final AppFailure? failure;
  final bool registrationSubmitted;
  final bool passwordChanged;
  final bool passwordResetSubmitted;
  final bool passwordResetCompleted;
  final bool emailVerificationCompleted;
  final List<AuthTenantOption> identifyTenants;

  AuthControllerState copyWith({
    bool? isSubmitting,
    AppFailure? failure,
    bool clearFailure = false,
    bool? registrationSubmitted,
    bool? passwordChanged,
    bool? passwordResetSubmitted,
    bool? passwordResetCompleted,
    bool? emailVerificationCompleted,
    List<AuthTenantOption>? identifyTenants,
    bool clearIdentifyTenants = false,
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
      identifyTenants: clearIdentifyTenants
          ? const <AuthTenantOption>[]
          : identifyTenants ?? this.identifyTenants,
    );
  }
}

final class AuthController extends Notifier<AuthControllerState> {
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

  void clearIdentifyTenants() {
    if (state.identifyTenants.isEmpty) {
      return;
    }

    state = state.copyWith(clearIdentifyTenants: true);
  }

  void clearPasswordResetSubmitted() {
    if (!state.passwordResetSubmitted) {
      return;
    }

    state = state.copyWith(passwordResetSubmitted: false);
  }

  void clearPasswordResetCompleted() {
    if (!state.passwordResetCompleted) {
      return;
    }

    state = state.copyWith(passwordResetCompleted: false);
  }

  void clearEmailVerificationCompleted() {
    if (!state.emailVerificationCompleted) {
      return;
    }

    state = state.copyWith(emailVerificationCompleted: false);
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
      state = state.copyWith(isSubmitting: false);
      rethrow;
    }
  }

  Future<bool> register({
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
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearFailure: true,
      registrationSubmitted: false,
    );
    final result = await ref
        .read(authRepositoryProvider)
        .register(
          email: email,
          password: password,
          facilityName: facilityName,
          adminName: adminName,
          facilityType: facilityType,
          phone: phone,
          tenantName: tenantName,
          location: location,
          interests: interests,
        );

    return result.when(
      success: (_) {
        state = state.copyWith(
          isSubmitting: false,
          clearFailure: true,
          registrationSubmitted: false,
        );
        return true;
      },
      failure: (AppFailure failure) {
        state = state.copyWith(isSubmitting: false, failure: failure);
        return false;
      },
    );
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
    final result = await ref
        .read(authRepositoryProvider)
        .changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
          confirmPassword: confirmPassword,
        );

    return result.when(
      success: (_) async {
        await ref.read(sessionStateProvider.notifier).logout();
        state = state.copyWith(
          isSubmitting: false,
          clearFailure: true,
          passwordChanged: true,
        );
        return true;
      },
      failure: (AppFailure failure) {
        state = state.copyWith(isSubmitting: false, failure: failure);
        return false;
      },
    );
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
    );

    final AuthRepository repository = ref.read(authRepositoryProvider);
    final normalizedEmail = email.trim().toLowerCase();

    if (tenantId == null || tenantId.trim().isEmpty) {
      final identifyResult = await repository.identify(
        identifier: normalizedEmail,
      );

      return identifyResult.when(
        success: (AuthIdentifyResult result) async {
          if (result.tenants.isEmpty) {
            state = state.copyWith(
              isSubmitting: false,
              clearFailure: true,
              passwordResetSubmitted: true,
            );
            return true;
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
        failure: (AppFailure failure) {
          state = state.copyWith(isSubmitting: false, failure: failure);
          return false;
        },
      );
    }

    return _submitForgotPassword(
      repository: repository,
      email: normalizedEmail,
      tenantId: tenantId.trim(),
    );
  }

  Future<bool> resetPassword({
    String? token,
    String? email,
    String? code,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (state.isSubmitting) {
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearFailure: true,
      passwordResetCompleted: false,
    );

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
        state = state.copyWith(
          isSubmitting: false,
          clearFailure: true,
          passwordResetCompleted: true,
        );
        return true;
      },
      failure: (AppFailure failure) {
        state = state.copyWith(isSubmitting: false, failure: failure);
        return false;
      },
    );
  }

  Future<bool> verifyEmail({required String token, String? email}) async {
    if (state.isSubmitting) {
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearFailure: true,
      emailVerificationCompleted: false,
    );

    final result = await ref
        .read(authRepositoryProvider)
        .verifyEmail(token: token, email: email);

    return result.when(
      success: (_) {
        state = state.copyWith(
          isSubmitting: false,
          clearFailure: true,
          emailVerificationCompleted: true,
        );
        return true;
      },
      failure: (AppFailure failure) {
        state = state.copyWith(isSubmitting: false, failure: failure);
        return false;
      },
    );
  }

  Future<bool> resendEmailVerification({required String email}) async {
    if (state.isSubmitting) {
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearFailure: true);

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
      success: (_) {
        state = state.copyWith(
          isSubmitting: false,
          clearFailure: true,
          passwordResetSubmitted: true,
          clearIdentifyTenants: true,
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
