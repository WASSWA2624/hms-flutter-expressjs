import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/home/data/repositories/home_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';

final homeControllerProvider =
    FutureProvider.family<Result<HomeDashboard>, HomeDashboardRequest>((
      ref,
      request,
    ) {
      return ref.watch(homeRepositoryProvider).loadDashboard(request);
    });
