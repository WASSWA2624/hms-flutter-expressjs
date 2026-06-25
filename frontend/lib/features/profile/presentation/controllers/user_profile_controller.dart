import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/profile/data/repositories/user_profile_repository_impl.dart';
import 'package:hosspi_hms/features/profile/domain/entities/user_profile_entities.dart';
import 'package:hosspi_hms/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:hosspi_hms/features/profile/presentation/state/user_profile_state.dart';

final userProfileControllerProvider =
    AsyncNotifierProvider<UserProfileController, Result<UserProfileState>>(
      UserProfileController.new,
    );

final class UserProfileController
    extends AsyncNotifier<Result<UserProfileState>> {
  UserProfileRepository get _repository =>
      ref.read(userProfileRepositoryProvider);

  @override
  Future<Result<UserProfileState>> build() {
    return _loadProfile();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<Result<UserProfileState>>();
    state = AsyncData<Result<UserProfileState>>(await _loadProfile());
  }

  Future<bool> saveProfile(UserProfileDraft draft) async {
    final Result<UserProfileState>? currentResult = state.asData?.value;
    final UserProfileState? current = currentResult?.when(
      success: (UserProfileState profileState) => profileState,
      failure: (_) => null,
    );
    final UserProfileRecord? record = current?.view.record;
    if (record == null || current == null) {
      return false;
    }

    state = AsyncData<Result<UserProfileState>>(
      Result<UserProfileState>.success(current.copyWith(isSaving: true)),
    );

    final Result<UserProfileRecord> result = await _repository.updateProfile(
      record.id,
      draft,
    );

    return result.when(
      success: (UserProfileRecord updated) async {
        await refresh();
        return true;
      },
      failure: (AppFailure failure) {
        state = AsyncData<Result<UserProfileState>>(
          Result<UserProfileState>.success(current.copyWith(isSaving: false)),
        );
        return false;
      },
    );
  }

  Future<Result<UserProfileState>> _loadProfile() async {
    final session = ref.read(sessionStateProvider).session;
    if (session == null) {
      return const Result<UserProfileState>.failure(AppFailure.unauthorized());
    }

    final Result<UserProfileView> loaded = await _repository.loadCurrentProfile(
      session,
    );

    if (loaded case ResultFailure<UserProfileView>(failure: final failure)) {
      return Result<UserProfileState>.failure(failure);
    }

    final UserProfileView view =
        (loaded as ResultSuccess<UserProfileView>).value;
    await ref.read(sessionStateProvider.notifier).persistSession(view.session);
    return Result<UserProfileState>.success(UserProfileState(view: view));
  }
}
