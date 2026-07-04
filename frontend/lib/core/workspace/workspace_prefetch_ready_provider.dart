import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_token_provider.dart';

/// Becomes true once an authenticated session has a readable access token.
///
/// Shell navigation badges defer watching workspace controllers until this
/// provider resolves so sidebar prefetch does not race session hydration.
final workspacePrefetchReadyProvider = FutureProvider<bool>((ref) async {
  final session = ref.watch(sessionStateProvider);
  if (!session.isAuthenticated) {
    return false;
  }

  final String? token = await ref
      .read(sessionTokenProvider)
      .ensureAccessTokenReady();
  return token != null && token.isNotEmpty;
});
