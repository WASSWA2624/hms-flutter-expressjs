import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';

@immutable
final class UserProfileRecord {
  const UserProfileRecord({
    required this.id,
    required this.userId,
    this.facilityId,
    this.firstName,
    this.middleName,
    this.lastName,
    this.gender,
    this.dateOfBirth,
  });

  final String id;
  final String userId;
  final String? facilityId;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? gender;
  final DateTime? dateOfBirth;

  String? get fullName {
    final List<String> parts = <String>[
      if (_hasText(firstName)) firstName!.trim(),
      if (_hasText(middleName)) middleName!.trim(),
      if (_hasText(lastName)) lastName!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  UserProfileRecord copyWith({
    String? firstName,
    String? middleName,
    String? lastName,
    String? gender,
    DateTime? dateOfBirth,
  }) {
    return UserProfileRecord(
      id: id,
      userId: userId,
      facilityId: facilityId,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    );
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

@immutable
final class UserProfileDraft {
  const UserProfileDraft({
    this.firstName,
    this.middleName,
    this.lastName,
    this.gender,
  });

  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? gender;
}

@immutable
final class UserProfileView {
  const UserProfileView({required this.session, this.record});

  final AuthSession session;
  final UserProfileRecord? record;

  AuthUserProfile get profile =>
      session.user ?? AuthUserProfile(email: session.subject);

  List<String> get roles => profile.roles;

  List<AppPermission> get permissions {
    final List<AppPermission> sorted =
        session.permissions.toList(growable: false)
          ..sort((AppPermission left, AppPermission right) {
            return left.value.compareTo(right.value);
          });
    return sorted;
  }
}
