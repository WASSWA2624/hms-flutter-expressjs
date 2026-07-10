import 'package:flutter/foundation.dart';

enum TenantSubscriptionHeaderState {
  unknown,
  active,
  expiringSoon,
  expired;

  bool get isHydrated => this != TenantSubscriptionHeaderState.unknown;

  static TenantSubscriptionHeaderState fromServer(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'active':
        return TenantSubscriptionHeaderState.active;
      case 'expiring_soon':
        return TenantSubscriptionHeaderState.expiringSoon;
      case 'expired':
        return TenantSubscriptionHeaderState.expired;
      default:
        return TenantSubscriptionHeaderState.unknown;
    }
  }
}

@immutable
final class PlatformAdminContact {
  const PlatformAdminContact({this.email, this.phone});

  final String? email;
  final String? phone;

  bool get hasContact =>
      (email?.trim().isNotEmpty ?? false) ||
      (phone?.trim().isNotEmpty ?? false);

  factory PlatformAdminContact.fromJson(Map<String, Object?>? json) {
    if (json == null) {
      return const PlatformAdminContact();
    }

    return PlatformAdminContact(
      email: _string(json['email']),
      phone: _string(json['phone']),
    );
  }

  static String? _string(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

@immutable
final class OrgAdminContact {
  const OrgAdminContact({
    this.id,
    this.fullName,
    this.email,
    this.phone,
    this.roleName,
  });

  final String? id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? roleName;

  bool get hasContact =>
      (fullName?.trim().isNotEmpty ?? false) ||
      (email?.trim().isNotEmpty ?? false) ||
      (phone?.trim().isNotEmpty ?? false);

  String get displayName {
    final String? name = fullName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final String? mail = email?.trim();
    if (mail != null && mail.isNotEmpty) {
      return mail;
    }
    return roleName?.trim().isNotEmpty == true ? roleName!.trim() : 'Administrator';
  }

  factory OrgAdminContact.fromJson(Map<String, Object?>? json) {
    if (json == null) {
      return const OrgAdminContact();
    }
    return OrgAdminContact(
      id: _string(json['id']),
      fullName:
          _string(json['full_name']) ??
          _string(json['fullName']) ??
          _composeName(json),
      email: _string(json['email']),
      phone: _string(json['phone']),
      roleName: _string(json['role_name']) ?? _string(json['roleName']),
    );
  }

  static List<OrgAdminContact> listFromJson(Object? value) {
    if (value is! Iterable) {
      return const <OrgAdminContact>[];
    }
    final List<OrgAdminContact> contacts = <OrgAdminContact>[];
    for (final Object? entry in value) {
      if (entry is! Map) {
        continue;
      }
      final OrgAdminContact contact = OrgAdminContact.fromJson(
        Map<String, Object?>.from(entry),
      );
      if (contact.hasContact) {
        contacts.add(contact);
      }
    }
    return contacts;
  }

  static String? _composeName(Map<String, Object?> json) {
    final List<String> parts = <String>[
      ?_string(json['first_name'] ?? json['firstName']),
      ?_string(json['middle_name'] ?? json['middleName']),
      ?_string(json['last_name'] ?? json['lastName']),
    ];
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' ');
  }

  static String? _string(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

@immutable
final class PlatformBankTransferDetails {
  const PlatformBankTransferDetails({
    this.accountName,
    this.bankName,
    this.branch,
    this.accountNumber,
    this.swiftCode,
    this.iban,
  });

  final String? accountName;
  final String? bankName;
  final String? branch;
  final String? accountNumber;
  final String? swiftCode;
  final String? iban;

  bool get hasDetails =>
      (accountName?.isNotEmpty ?? false) ||
      (bankName?.isNotEmpty ?? false) ||
      (accountNumber?.isNotEmpty ?? false);

  factory PlatformBankTransferDetails.fromJson(Map<String, Object?>? json) {
    if (json == null) {
      return const PlatformBankTransferDetails();
    }

    return PlatformBankTransferDetails(
      accountName: _string(json['account_name']),
      bankName: _string(json['bank_name']),
      branch: _string(json['branch']),
      accountNumber: _string(json['account_number']),
      swiftCode: _string(json['swift_code']),
      iban: _string(json['iban']),
    );
  }

  static String? _string(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

@immutable
final class TenantSubscriptionSummary {
  const TenantSubscriptionSummary({
    this.subscriptionId,
    this.status,
    this.planId,
    this.planLabel,
    this.tierCode,
    this.endDate,
    this.daysUntilExpiry,
    this.expiringSoonDays = 14,
    this.headerState = TenantSubscriptionHeaderState.unknown,
    this.nextPlanId,
    this.nextPlanLabel,
    this.nextTierCode,
  });

  final String? subscriptionId;
  final String? status;
  final String? planId;
  final String? planLabel;
  final String? tierCode;
  final DateTime? endDate;
  final int? daysUntilExpiry;
  final int expiringSoonDays;
  final TenantSubscriptionHeaderState headerState;
  final String? nextPlanId;
  final String? nextPlanLabel;
  final String? nextTierCode;

  bool get canUpgrade =>
      (nextPlanLabel?.trim().isNotEmpty ?? false) ||
      (nextTierCode?.trim().isNotEmpty ?? false);

  factory TenantSubscriptionSummary.fromJson(Map<String, Object?>? json) {
    if (json == null) {
      return const TenantSubscriptionSummary();
    }

    return TenantSubscriptionSummary(
      subscriptionId: _string(json['subscription_id']),
      status: _string(json['status']),
      planId: _string(json['plan_id']),
      planLabel: _string(json['plan_label']),
      tierCode: _string(json['tier_code']),
      endDate: _dateTime(json['end_date']),
      daysUntilExpiry: _int(json['days_until_expiry']),
      expiringSoonDays: _int(json['expiring_soon_days']) ?? 14,
      headerState: TenantSubscriptionHeaderState.fromServer(
        _string(json['header_state']),
      ),
      nextPlanId: _string(json['next_plan_id']),
      nextPlanLabel: _string(json['next_plan_label']),
      nextTierCode: _string(json['next_tier_code']),
    );
  }

  static String? _string(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _int(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value');
  }

  static DateTime? _dateTime(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value.toUtc();
    }
    return DateTime.tryParse(value.toString())?.toUtc();
  }
}
