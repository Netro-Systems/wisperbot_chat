/// Named paths exposed by the WisperBot visitor API.
abstract final class ApiEndpoints {
  ApiEndpoints._();

  /// Creates or restores an identity-scoped visitor session.
  static const String session = '/widget/v1/session';

  /// Sends visitor messages and polls for conversation updates.
  static const String messages = '/widget/v1/messages';

  /// Publishes visitor typing state.
  static const String typing = '/widget/v1/typing';

  /// Requests transfer to human support.
  static const String handoff = '/widget/v1/handoff';

  /// Marks unread agent messages as seen/read.
  static const String read = '/widget/v1/read';

  /// Resolves an API [path] below [baseUrl] without discarding its prefix.
  ///
  /// For example, a base URL ending in `/base/` and [session] resolve to
  /// `/base/widget/v1/session`.
  static Uri resolve(Uri baseUrl, String path) {
    final prefix = baseUrl.path.endsWith('/')
        ? baseUrl.path.substring(0, baseUrl.path.length - 1)
        : baseUrl.path;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return baseUrl.replace(path: '$prefix$normalizedPath');
  }
}
