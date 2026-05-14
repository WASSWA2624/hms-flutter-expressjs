import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/errors/result.dart';
import 'package:flutter_template/features/home/domain/entities/home_readiness_snapshot.dart';
import 'package:flutter_template/features/home/domain/repositories/home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return const HomeRepositoryImpl();
});

final class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl();

  @override
  Future<Result<HomeReadinessSnapshot>> loadReadiness() async {
    return const Result<HomeReadinessSnapshot>.success(
      HomeReadinessSnapshot.ready(),
    );
  }
}
