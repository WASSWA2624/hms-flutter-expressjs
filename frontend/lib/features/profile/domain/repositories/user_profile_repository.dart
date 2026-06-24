import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/features/profile/domain/entities/user_profile_entities.dart';

abstract interface class UserProfileRepository {
  Future<Result<UserProfileView>> loadCurrentProfile(AuthSession session);

  Future<Result<UserProfileRecord>> updateProfile(
    String profileId,
    UserProfileDraft draft,
  );
}
