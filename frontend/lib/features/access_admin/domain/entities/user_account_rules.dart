/// Account field rules shared with
/// `backend/src/modules/user/schemas/user.schema.js` (`USER_FIELD_LIMITS` and
/// `USER_EMAIL_PATTERN`).
///
/// The access-admin form validates with these values so it never accepts input
/// the API rejects. Change both files together.
abstract final class UserAccountRules {
  static const int nameMaxLength = 120;
  static const int positionTitleMaxLength = 120;
  static const int emailMaxLength = 255;
  static const int maxRoles = 50;

  static final RegExp emailPattern = RegExp(
    r"^[A-Za-z0-9._%+'-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*\.[A-Za-z]{2,}$",
  );
}
