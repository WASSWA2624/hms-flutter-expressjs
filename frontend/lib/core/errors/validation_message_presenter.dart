import 'dart:convert';

import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/auth/domain/entities/email_verification_result.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

enum OrganizationDeactivatedScope { tenant, facility }

/// Presents API validation failures using localized field labels and messages.
abstract final class ValidationMessagePresenter {
  static String displayMessage(AppFailure failure, AppLocalizations l10n) {
    if (failure.fieldMessages.isNotEmpty) {
      return failure.fieldMessages.entries
          .map(
            (MapEntry<String, String> entry) => humanizeFieldMessage(
              l10n,
              field: entry.key,
              message: entry.value,
            ),
          )
          .join('\n');
    }

    if (failure.validationFields.isNotEmpty) {
      return failure.validationFields
          .map(
            (String field) =>
                l10n.validationFieldRequiredMessage(fieldLabel(l10n, field)),
          )
          .join('\n');
    }

    final String? authMessage = _authMessage(l10n, failure);
    if (authMessage != null) {
      return authMessage;
    }

    final String? detailMessage = failure.detailMessage?.trim();
    if (detailMessage != null && detailMessage.isNotEmpty) {
      final String humanized = humanizeDetailMessage(
        l10n,
        detailMessage,
        failure.validationFields,
      );
      if (humanized.isNotEmpty) {
        return humanized;
      }
    }

    return switch (failure.category) {
      AppFailureCategory.network => l10n.errorNetworkMessage,
      AppFailureCategory.timeout => l10n.errorTimeoutMessage,
      AppFailureCategory.offline => l10n.errorOfflineMessage,
      AppFailureCategory.cancelled => l10n.errorCancelledMessage,
      AppFailureCategory.unauthorized => l10n.errorUnauthorizedMessage,
      AppFailureCategory.forbidden => l10n.errorForbiddenMessage,
      AppFailureCategory.notFound => l10n.errorNotFoundMessage,
      AppFailureCategory.conflict => l10n.errorConflictMessage,
      AppFailureCategory.validation => l10n.errorValidationMessage,
      AppFailureCategory.unexpectedResponse =>
        l10n.errorUnexpectedResponseMessage,
      AppFailureCategory.storage => l10n.errorStorageMessage,
      AppFailureCategory.unexpected => l10n.errorUnexpectedMessage,
    };
  }

  static String humanizeFieldMessage(
    AppLocalizations l10n, {
    required String field,
    required String message,
  }) {
    final String trimmed = message.trim();
    if (trimmed.isEmpty) {
      return l10n.validationFieldRequiredMessage(fieldLabel(l10n, field));
    }

    if (!_looksLikeApiValidationMessage(trimmed)) {
      return trimmed;
    }

    return humanizeDetailMessage(l10n, trimmed, {field});
  }

  static String humanizeDetailMessage(
    AppLocalizations l10n,
    String message,
    Set<String> validationFields,
  ) {
    final String trimmed = message.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    if (trimmed.contains('{{')) {
      return _humanizeTemplateMessage(l10n, trimmed, validationFields);
    }

    final String? matchedField = _matchingField(trimmed, validationFields);
    if (matchedField != null) {
      return _humanizeKnownPattern(l10n, trimmed, matchedField);
    }

    final String? embeddedField = _embeddedApiField(trimmed);
    if (embeddedField != null) {
      return _humanizeKnownPattern(l10n, trimmed, embeddedField);
    }

    return trimmed;
  }

  static String? _authMessage(AppLocalizations l10n, AppFailure failure) {
    return switch (failure.code) {
      'auth.account_pending' => l10n.authAccountPendingMessage,
      'auth.account_pending_approval' => pendingApprovalMessage(
        l10n,
        contacts: platformAdminContactsFromDetail(failure.detailMessage),
      ),
      'auth.tenant_deactivated' => organizationDeactivatedMessage(
        l10n,
        scope: OrganizationDeactivatedScope.tenant,
        email: _platformAdminContactField(failure.detailMessage, 'email'),
        phone: _platformAdminContactField(failure.detailMessage, 'phone'),
      ),
      'auth.facility_deactivated' => organizationDeactivatedMessage(
        l10n,
        scope: OrganizationDeactivatedScope.facility,
        email: _platformAdminContactField(failure.detailMessage, 'email'),
        phone: _platformAdminContactField(failure.detailMessage, 'phone'),
      ),
      'auth.account_not_found' => l10n.authAccountNotFoundMessage,
      'auth.wrong_password' => l10n.authWrongPasswordMessage,
      'network.rate_limited' => _rateLimitedMessage(l10n, failure),
      'auth.reset_password.invalid_token' ||
      'auth.token_invalid' => l10n.authResetPasswordInvalidTokenMessage,
      'PERMANENT_DELETE_BLOCKED' =>
        l10n.tenantFacilityPermanentDeleteBlockedActiveSubscriptionMessage,
      'PERMANENT_DELETE_REQUIRES_SOFT_DELETE' =>
        l10n.tenantFacilityPermanentDeleteRequiresSoftDeleteMessage,
      _ => null,
    };
  }

  /// Login / verify-email copy when the account still needs platform approval.
  static String pendingApprovalMessage(
    AppLocalizations l10n, {
    String? email,
    String? phone,
    List<AuthPlatformAdminContact> contacts = const <AuthPlatformAdminContact>[],
    bool emailJustVerified = false,
  }) {
    final List<AuthPlatformAdminContact> resolvedContacts =
        <AuthPlatformAdminContact>[
          ...contacts.where(
            (AuthPlatformAdminContact contact) => contact.hasContactDetails,
          ),
        ];
    if (resolvedContacts.isEmpty) {
      final AuthPlatformAdminContact fallback = AuthPlatformAdminContact(
        email: email,
        phone: phone,
      );
      if (fallback.hasContactDetails) {
        resolvedContacts.add(fallback);
      }
    }

    final String baseMessage = emailJustVerified
        ? l10n.authEmailVerifiedAwaitingApprovalBody
        : l10n.authAccountPendingApprovalMessage;

    if (resolvedContacts.isEmpty) {
      return baseMessage;
    }

    final List<String> lines = <String>[
      baseMessage,
      l10n.authAccountPendingApprovalContactHint,
      for (final AuthPlatformAdminContact contact in resolvedContacts)
        ..._contactLines(l10n, contact),
    ];
    return lines.join('\n');
  }

  static Iterable<String> _contactLines(
    AppLocalizations l10n,
    AuthPlatformAdminContact contact,
  ) {
    final String? name = contact.fullName?.trim();
    final String? email = contact.email?.trim();
    final String? phone = contact.phone?.trim();
    return <String>[
      if (name != null && name.isNotEmpty) name,
      if (email != null && email.isNotEmpty)
        l10n.authAccountPendingApprovalEmailLine(email),
      if (phone != null && phone.isNotEmpty)
        l10n.authAccountPendingApprovalPhoneLine(phone),
    ];
  }

  /// Parses encoded platform-admin contact JSON from [AppFailure.detailMessage].
  static List<AuthPlatformAdminContact> platformAdminContactsFromDetail(
    String? detailMessage,
  ) {
    final String? raw = detailMessage?.trim();
    if (raw == null || raw.isEmpty || !raw.startsWith('{')) {
      return const <AuthPlatformAdminContact>[];
    }

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const <AuthPlatformAdminContact>[];
      }

      final Object? contactsRaw = decoded['contacts'];
      if (contactsRaw is List) {
        final List<AuthPlatformAdminContact> contacts = contactsRaw
            .map(AuthPlatformAdminContact.fromJson)
            .where((AuthPlatformAdminContact c) => c.hasContactDetails)
            .toList(growable: false);
        if (contacts.isNotEmpty) {
          return contacts;
        }
      }

      final AuthPlatformAdminContact single =
          AuthPlatformAdminContact.fromJson(decoded);
      if (single.hasContactDetails) {
        return <AuthPlatformAdminContact>[single];
      }
    } on FormatException {
      return const <AuthPlatformAdminContact>[];
    }

    return const <AuthPlatformAdminContact>[];
  }

  /// Login copy when the tenant or facility was soft-deleted.
  static String organizationDeactivatedMessage(
    AppLocalizations l10n, {
    required OrganizationDeactivatedScope scope,
    String? email,
    String? phone,
  }) {
    final String baseMessage = switch (scope) {
      OrganizationDeactivatedScope.tenant =>
        l10n.authTenantDeactivatedMessage,
      OrganizationDeactivatedScope.facility =>
        l10n.authFacilityDeactivatedMessage,
    };
    final String? trimmedEmail = email?.trim();
    final String? trimmedPhone = phone?.trim();
    final bool hasEmail = trimmedEmail != null && trimmedEmail.isNotEmpty;
    final bool hasPhone = trimmedPhone != null && trimmedPhone.isNotEmpty;

    if (!hasEmail && !hasPhone) {
      return baseMessage;
    }

    final List<String> lines = <String>[
      baseMessage,
      l10n.authOrganizationDeactivatedContactHint,
      if (hasEmail) l10n.authAccountPendingApprovalEmailLine(trimmedEmail),
      if (hasPhone) l10n.authAccountPendingApprovalPhoneLine(trimmedPhone),
    ];
    return lines.join('\n');
  }

  static String? _platformAdminContactField(
    String? detailMessage,
    String field,
  ) {
    final String? raw = detailMessage?.trim();
    if (raw == null || raw.isEmpty || !raw.startsWith('{')) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<Object?, Object?>) {
        return null;
      }
      final Object? value = decoded[field];
      if (value == null) {
        return null;
      }
      final String text = value.toString().trim();
      return text.isEmpty ? null : text;
    } on FormatException {
      return null;
    }
  }

  static String _rateLimitedMessage(AppLocalizations l10n, AppFailure failure) {
    final DateTime? resetAt = DateTime.tryParse(failure.detailMessage ?? '');
    if (resetAt != null) {
      final DateTime local = resetAt.toLocal();
      final String hour = local.hour.toString().padLeft(2, '0');
      final String minute = local.minute.toString().padLeft(2, '0');
      final String time = '$hour:$minute';
      return l10n.authRateLimitedTryAgainAtMessage(time);
    }

    return l10n.authRateLimitedMessage;
  }

  static String fieldLabel(AppLocalizations l10n, String field) {
    final String normalized = field.trim().toLowerCase();
    if (normalized.isEmpty) {
      return l10n.validationRequired;
    }

    return switch (normalized) {
      'first_name' => l10n.patientsFirstNameLabel,
      'last_name' => l10n.patientsLastNameLabel,
      'date_of_birth' => l10n.patientsDobLabel,
      'gender' => l10n.patientsGenderLabel,
      'facility_id' => l10n.patientsFacilityLabel,
      'tenant_id' => l10n.profileTenantLabel,
      'primary_phone' || 'phone' => l10n.patientsPhoneLabel,
      'primary_email' || 'email' => l10n.patientsEmailLabel,
      'primary_identifier_type' ||
      'identifier_type' => l10n.patientsIdentifierTypeLabel,
      'primary_identifier_value' ||
      'identifier_value' => l10n.patientsIdentifierValueLabel,
      'password' => l10n.authPasswordLabel,
      'old_password' => l10n.authCurrentPasswordLabel,
      'new_password' => l10n.authNewPasswordLabel,
      'name' => l10n.tenantFacilityTenantNameLabel,
      'slug' => l10n.tenantFacilityTenantSlugLabel,
      _ => AppDisplay.apiLabel(field),
    };
  }

  static bool _looksLikeApiValidationMessage(String message) {
    return _embeddedApiField(message) != null ||
        message.contains('{{') ||
        _requiredPattern.hasMatch(message) ||
        _invalidValuePattern.hasMatch(message) ||
        _invalidFormatPattern.hasMatch(message) ||
        _alreadyInUsePattern.hasMatch(message);
  }

  static String _humanizeTemplateMessage(
    AppLocalizations l10n,
    String message,
    Set<String> validationFields,
  ) {
    final String field = validationFields.isNotEmpty
        ? validationFields.first
        : 'field';
    final String label = fieldLabel(l10n, field);

    if (message.contains('{{field}}')) {
      if (_requiredPattern.hasMatch(message.replaceAll('{{field}}', label))) {
        return l10n.validationFieldRequiredMessage(label);
      }
      if (_invalidValuePattern.hasMatch(
        message.replaceAll('{{field}}', label),
      )) {
        return l10n.validationFieldInvalidMessage(label);
      }
      if (_invalidFormatPattern.hasMatch(
        message.replaceAll('{{field}}', label),
      )) {
        return l10n.validationFieldInvalidFormatMessage(label);
      }
      if (_alreadyInUsePattern.hasMatch(
        message.replaceAll('{{field}}', label),
      )) {
        return l10n.validationFieldAlreadyInUseMessage(label);
      }
    }

    return message.replaceAll('{{field}}', label);
  }

  static String _humanizeKnownPattern(
    AppLocalizations l10n,
    String message,
    String field,
  ) {
    final String label = fieldLabel(l10n, field);

    if (_requiredPattern.hasMatch(message)) {
      return l10n.validationFieldRequiredMessage(label);
    }
    if (_invalidValuePattern.hasMatch(message)) {
      return l10n.validationFieldInvalidMessage(label);
    }
    if (_invalidFormatPattern.hasMatch(message)) {
      return l10n.validationFieldInvalidFormatMessage(label);
    }
    if (_alreadyInUsePattern.hasMatch(message)) {
      return l10n.validationFieldAlreadyInUseMessage(label);
    }

    return message.replaceAll(field, label);
  }

  static String? _matchingField(String message, Set<String> validationFields) {
    for (final String field in validationFields) {
      if (message.contains(field)) {
        return field;
      }
    }
    return null;
  }

  static String? _embeddedApiField(String message) {
    final RegExpMatch? match = _apiFieldPattern.firstMatch(message);
    return match?.group(1);
  }

  static final RegExp _apiFieldPattern = RegExp(
    r'\b([a-z][a-z0-9]*(?:_[a-z0-9]+)+)\b',
  );

  static final RegExp _requiredPattern = RegExp(
    r'^.+ is required\.?$',
    caseSensitive: false,
  );

  static final RegExp _invalidValuePattern = RegExp(
    r'^Invalid value for .+\.?$',
    caseSensitive: false,
  );

  static final RegExp _invalidFormatPattern = RegExp(
    r'^Invalid .+ format\.?$',
    caseSensitive: false,
  );

  static final RegExp _alreadyInUsePattern = RegExp(
    r'^.+ is already in use\.?$',
    caseSensitive: false,
  );
}
