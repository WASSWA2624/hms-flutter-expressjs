/// Outcome of POST /auth/verify-email.
final class EmailVerificationResult {
  const EmailVerificationResult({
    required this.awaitingPlatformApproval,
    this.platformAdminContacts = const <AuthPlatformAdminContact>[],
  });

  final bool awaitingPlatformApproval;
  final List<AuthPlatformAdminContact> platformAdminContacts;
}

/// Platform admin contact shown when activation is still pending.
final class AuthPlatformAdminContact {
  const AuthPlatformAdminContact({this.fullName, this.email, this.phone});

  final String? fullName;
  final String? email;
  final String? phone;

  bool get hasContactDetails {
    final String? trimmedEmail = email?.trim();
    final String? trimmedPhone = phone?.trim();
    return (trimmedEmail != null && trimmedEmail.isNotEmpty) ||
        (trimmedPhone != null && trimmedPhone.isNotEmpty);
  }

  factory AuthPlatformAdminContact.fromJson(Object? raw) {
    if (raw is! Map) {
      return const AuthPlatformAdminContact();
    }

    final Map<Object?, Object?> map = raw;
    String? read(String key) {
      final Object? value = map[key];
      if (value == null) {
        return null;
      }
      final String text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    return AuthPlatformAdminContact(
      fullName: read('full_name') ?? read('fullName') ?? read('name'),
      email: read('email'),
      phone: read('phone'),
    );
  }

  static List<AuthPlatformAdminContact> listFromResponseData(Object? data) {
    if (data is! Map) {
      return const <AuthPlatformAdminContact>[];
    }

    final Map<Object?, Object?> map = data;
    final Object? contactsRaw =
        map['platform_admin_contacts'] ?? map['platformAdminContacts'];
    if (contactsRaw is List) {
      final List<AuthPlatformAdminContact> contacts = contactsRaw
          .map(AuthPlatformAdminContact.fromJson)
          .where((AuthPlatformAdminContact contact) => contact.hasContactDetails)
          .toList(growable: false);
      if (contacts.isNotEmpty) {
        return contacts;
      }
    }

    final AuthPlatformAdminContact single = AuthPlatformAdminContact.fromJson(
      map['platform_admin_contact'] ?? map['platformAdminContact'],
    );
    if (single.hasContactDetails) {
      return <AuthPlatformAdminContact>[single];
    }

    return const <AuthPlatformAdminContact>[];
  }
}
