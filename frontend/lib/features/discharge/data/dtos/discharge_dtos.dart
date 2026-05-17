import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/ipd/data/dtos/ipd_dtos.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';

typedef DischargeJsonMap = Map<String, Object?>;

final class DischargeAdmissionDetailDto {
  const DischargeAdmissionDetailDto({
    required this.responseData,
    this.pharmacyOrders = const <DischargeRelatedRecord>[],
    this.invoices = const <DischargeRelatedRecord>[],
    this.billingDataUnavailable = false,
    this.pharmacyDataUnavailable = false,
  });

  final Object? responseData;
  final List<DischargeRelatedRecord> pharmacyOrders;
  final List<DischargeRelatedRecord> invoices;
  final bool billingDataUnavailable;
  final bool pharmacyDataUnavailable;

  DischargeAdmissionDetail toEntity() {
    final DischargeJsonMap response = _expectMap(responseData);
    final DischargeJsonMap data = _map(response['data']);
    final IpdAdmissionDetail ipd = IpdAdmissionDetailDto.fromResponse(
      responseData,
    ).toEntity();
    final DischargeJsonMap tenant = _map(data['tenant']);
    final DischargeJsonMap facility = _map(data['facility']);
    final DischargeJsonMap patient = _map(data['patient']);
    final DischargeJsonMap encounter = _map(data['encounter']);
    final DischargeJsonMap activeBedAssignment = _map(
      data['active_bed_assignment'],
    );
    final DischargeJsonMap bed = _map(activeBedAssignment['bed']);
    final DischargeJsonMap room = _map(bed['room']);

    return DischargeAdmissionDetail(
      ipd: ipd,
      tenantId: _string(tenant['id']),
      facilityId: _string(facility['id']),
      patientId:
          _string(data['patient_display_id']) ??
          _string(patient['id']) ??
          ipd.summary.patientId,
      encounterId:
          _string(data['encounter_display_id']) ??
          _string(encounter['id']) ??
          ipd.summary.encounterId,
      roomId: _string(room['id']),
      roomName: _string(room['name']),
      pharmacyOrders: pharmacyOrders,
      invoices: invoices,
      billingDataUnavailable: billingDataUnavailable,
      pharmacyDataUnavailable: pharmacyDataUnavailable,
    );
  }
}

List<DischargeRelatedRecord> decodeDischargePharmacyOrders(
  Object? responseData,
) {
  final DischargeJsonMap response = _expectMap(responseData);
  return _list(response['data'])
      .map(
        (DischargeJsonMap json) => DischargeRelatedRecord(
          id:
              _string(json['human_friendly_id']) ??
              _string(json['id']) ??
              '',
          kind: 'pharmacy_order',
          status: _string(json['status']),
          title:
              _string(json['order_number']) ??
              _string(json['human_friendly_id']) ??
              _string(json['id']),
          subtitle: _string(json['patient_display_name']),
          createdAt: _date(json['ordered_at']) ?? _date(json['created_at']),
          updatedAt: _date(json['updated_at']),
        ),
      )
      .where((DischargeRelatedRecord item) => item.id.isNotEmpty)
      .toList(growable: false);
}

List<DischargeRelatedRecord> decodeDischargeInvoices(Object? responseData) {
  final DischargeJsonMap response = _expectMap(responseData);
  return _list(response['data'])
      .map(
        (DischargeJsonMap json) => DischargeRelatedRecord(
          id:
              _string(json['human_friendly_id']) ??
              _string(json['id']) ??
              '',
          kind: 'invoice',
          status: _string(json['status']),
          billingStatus: _string(json['billing_status']),
          title:
              _string(json['invoice_number']) ??
              _string(json['human_friendly_id']) ??
              _string(json['id']),
          amount: _number(json['total_amount']),
          currency: _string(json['currency']),
          createdAt: _date(json['issued_at']) ?? _date(json['created_at']),
          updatedAt: _date(json['updated_at']),
        ),
      )
      .where((DischargeRelatedRecord item) => item.id.isNotEmpty)
      .toList(growable: false);
}

List<DischargeDrugOption> decodeDischargeDrugOptions(Object? responseData) {
  final DischargeJsonMap response = _expectMap(responseData);
  return _list(response['data'])
      .map(
        (DischargeJsonMap json) => DischargeDrugOption(
          id:
              _string(json['human_friendly_id']) ??
              _string(json['id']) ??
              '',
          name: _string(json['name']),
          form: _string(json['form']),
          strength: _string(json['strength']),
        ),
      )
      .where((DischargeDrugOption item) => item.id.isNotEmpty)
      .toList(growable: false);
}

DischargeJsonMap _expectMap(Object? value) {
  if (value is DischargeJsonMap) {
    return value;
  }

  throw const FormatException('Expected response object.');
}

DischargeJsonMap _map(Object? value) {
  return value is DischargeJsonMap ? value : <String, Object?>{};
}

List<DischargeJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <DischargeJsonMap>[];
  }

  return value.whereType<DischargeJsonMap>().toList(growable: false);
}

String? _string(Object? value) {
  if (value == null) {
    return null;
  }

  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime? _date(Object? value) {
  final String? normalized = _string(value);
  if (normalized == null) {
    return null;
  }

  return DateTime.tryParse(normalized);
}

num? _number(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value);
  }
  return null;
}
