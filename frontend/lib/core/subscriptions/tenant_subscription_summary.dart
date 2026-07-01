import 'package:flutter/foundation.dart';

enum TenantSubscriptionHeaderState {
  active,
  expiringSoon,
  expired;

  static TenantSubscriptionHeaderState fromServer(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'active':
        return TenantSubscriptionHeaderState.active;
      case 'expiring_soon':
        return TenantSubscriptionHeaderState.expiringSoon;
      case 'expired':
      default:
        return TenantSubscriptionHeaderState.expired;
    }
  }
}

@immutable
final class PlatformAdminContact {
  const PlatformAdminContact({this.email, this.phone});

  final String? email;
  final String? phone;

  bool get hasContact =>
      (email?.trim().isNotEmpty ?? false) || (phone?.trim().isNotEmpty ?? false);

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
    this.headerState = TenantSubscriptionHeaderState.expired,
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
