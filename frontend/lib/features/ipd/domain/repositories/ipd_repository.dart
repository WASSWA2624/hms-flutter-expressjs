import 'package:hosspi_hms/core/errors/result.dart';

abstract interface class IpdRepository {
  Future<Result<void>> assignBed(
    String admissionId,
    Map<String, Object?> payload,
  );
}
