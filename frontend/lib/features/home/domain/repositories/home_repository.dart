import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_readiness_snapshot.dart';

abstract interface class HomeRepository {
  Future<Result<HomeReadinessSnapshot>> loadReadiness();
}
