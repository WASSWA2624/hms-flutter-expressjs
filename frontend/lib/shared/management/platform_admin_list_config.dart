import 'package:hosspi_hms/shared/data/app_pagination.dart';

/// Shared list settings for Super Admin platform management dialogs.
abstract final class PlatformAdminListConfig {
  static const int pageSize = AppPageRequest.maxPageSize;

  static const AppPageRequest initialPageRequest = AppPageRequest(
    pageSize: pageSize,
  );
}
