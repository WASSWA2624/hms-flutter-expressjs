import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';

abstract interface class HomeRepository {
  Future<Result<HomeDashboard>> loadDashboard(HomeDashboardRequest request);
}
