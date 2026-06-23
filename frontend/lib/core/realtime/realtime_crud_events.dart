/// Matches audit-driven CRUD websocket events emitted as `{entity}.{operation}`.
abstract final class RealtimeCrudEvents {
  static const Set<String> operationSuffixes = <String>{
    '.created',
    '.updated',
    '.deleted',
    '.canceled',
    '.rescheduled',
    '.activated',
    '.deactivated',
  };

  static bool matches(String event) {
    final String normalized = event.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final List<String> parts = normalized.split('.');
    if (parts.length != 2 || parts.any((String part) => part.trim().isEmpty)) {
      return false;
    }

    return operationSuffixes.contains('.${parts[1]}');
  }
}
