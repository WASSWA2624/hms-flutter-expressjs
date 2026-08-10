import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/hr/data/dtos/hr_dtos.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/settings/domain/settings_staff_self_models.dart';

final settingsStaffSelfRepositoryProvider =
    Provider<SettingsStaffSelfRepository>((Ref ref) {
      return SettingsStaffSelfRepository(
        apiClient: ref.watch(apiClientProvider),
      );
    });

final class SettingsStaffSelfRepository {
  const SettingsStaffSelfRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<Result<List<HrStaffLeave>>> listMyLeaves({String? status}) {
    return _apiClient.get<List<HrStaffLeave>>(
      ApiEndpoints.apiV1(<String>[HmsApiResource.staffLeaves.path, 'me']),
      queryParameters: <String, Object?>{
        'limit': 200,
        'order': 'desc',
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      },
      decoder: (Object? data) => HrStaffLeavePageDto.fromResponse(data).items,
    );
  }

  Future<Result<Object?>> createMyLeave(Map<String, Object?> payload) {
    return _apiClient.post<Object?>(
      ApiEndpoints.apiV1(<String>[HmsApiResource.staffLeaves.path, 'me']),
      data: payload,
      decoder: (Object? data) => data,
    );
  }

  Future<Result<List<SettingsStaffShift>>> listMyShifts({
    required DateTime from,
    required DateTime to,
  }) {
    return _apiClient.get<List<SettingsStaffShift>>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.shiftAssignments.path,
        'me',
      ]),
      queryParameters: <String, Object?>{
        'limit': 200,
        'start_from': from.toUtc().toIso8601String(),
        'start_to': DateTime(
          to.year,
          to.month,
          to.day,
          23,
          59,
          59,
        ).toUtc().toIso8601String(),
      },
      decoder: _decodeShifts,
    );
  }

  static List<SettingsStaffShift> _decodeShifts(Object? responseData) {
    if (responseData is! Map) {
      return const <SettingsStaffShift>[];
    }
    final Object? raw = responseData['data'];
    if (raw is! List) {
      return const <SettingsStaffShift>[];
    }
    final List<SettingsStaffShift> items = <SettingsStaffShift>[];
    for (final Object? entry in raw) {
      if (entry is! Map) {
        continue;
      }
      final Map<String, Object?> json = Map<String, Object?>.from(entry);
      final Object? shiftRaw = json['shift'];
      final Map<String, Object?> shift = shiftRaw is Map
          ? Map<String, Object?>.from(shiftRaw)
          : const <String, Object?>{};
      final DateTime? start = _parseDate(shift['start_time']);
      final DateTime? end = _parseDate(shift['end_time']);
      if (start == null || end == null) {
        continue;
      }
      final String id =
          (json['human_friendly_id'] ?? json['id'] ?? '').toString().trim();
      if (id.isEmpty) {
        continue;
      }
      items.add(
        SettingsStaffShift(
          id: id,
          displayId: json['human_friendly_id']?.toString(),
          shiftType: shift['shift_type']?.toString(),
          status: shift['status']?.toString(),
          start: start,
          end: end,
        ),
      );
    }
    return items;
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse(value.toString());
  }
}
