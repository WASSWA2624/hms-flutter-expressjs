import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Returns true when a failure represents missing access rather than a broken
/// session (for example module entitlement or RBAC denials).
bool isWorkspaceAccessDeniedFailure(AppFailure failure) {
  return failure.category == AppFailureCategory.unauthorized ||
      failure.category == AppFailureCategory.forbidden;
}

/// Maps a paged API result to an empty page when the request fails, preserving
/// pagination metadata for the requested query.
AppPage<T> workspacePageOrEmptyOnFailure<T>(
  Result<AppPage<T>> result,
  AppPageRequest request,
) {
  return result.when(
    success: (AppPage<T> page) => page,
    failure: (_) =>
        AppPage<T>(items: List<T>.empty(), request: request, totalItemCount: 0),
  );
}

/// Picks the first bootstrap failure that should block the workspace shell.
///
/// Access-denied failures are ignored so partial data can still render when one
/// of several bootstrap calls is forbidden for the current role.
AppFailure? firstBlockingWorkspaceBootstrapFailure(
  Iterable<AppFailure?> failures,
) {
  for (final AppFailure? failure in failures) {
    if (failure == null || isWorkspaceAccessDeniedFailure(failure)) {
      continue;
    }
    return failure;
  }
  return null;
}

/// Avoids showing "Sign-in required" while the shell still reports an active
/// session. Transient bootstrap 401s can occur when many workspace providers
/// start concurrently before the auth interceptor attaches a bearer token.
AppFailure normalizeWorkspaceBootstrapFailure(AppFailure failure) {
  if (failure.category != AppFailureCategory.unauthorized) {
    return failure;
  }

  return AppFailure.network(
    code: 'workspace.bootstrap_auth_unavailable',
    statusCode: failure.statusCode,
  );
}
