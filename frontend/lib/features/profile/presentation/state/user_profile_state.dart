import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/features/profile/domain/entities/user_profile_entities.dart';

@immutable
final class UserProfileState {
  const UserProfileState({
    required this.view,
    this.isSaving = false,
  });

  final UserProfileView view;
  final bool isSaving;

  UserProfileState copyWith({
    UserProfileView? view,
    bool? isSaving,
  }) {
    return UserProfileState(
      view: view ?? this.view,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}
