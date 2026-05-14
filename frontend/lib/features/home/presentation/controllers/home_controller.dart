import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/home/data/repositories/home_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_readiness_snapshot.dart';

final homeControllerProvider =
    AsyncNotifierProvider<HomeController, Result<HomeReadinessSnapshot>>(
      HomeController.new,
    );

final class HomeController
    extends AsyncNotifier<Result<HomeReadinessSnapshot>> {
  @override
  Future<Result<HomeReadinessSnapshot>> build() {
    return ref.watch(homeRepositoryProvider).loadReadiness();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<Result<HomeReadinessSnapshot>>();
    state = await AsyncValue.guard(() {
      return ref.read(homeRepositoryProvider).loadReadiness();
    });
  }
}
