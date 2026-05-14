import 'package:flutter_template/core/errors/result.dart';
import 'package:flutter_template/features/home/domain/entities/home_readiness_snapshot.dart';

abstract interface class HomeRepository {
  Future<Result<HomeReadinessSnapshot>> loadReadiness();
}
