/// Resolves one visitor endpoint below the canonical `/widget/v1` base path.
Uri widgetEndpoint(Uri baseUrl, String path) {
  final prefix = baseUrl.path.endsWith('/')
      ? baseUrl.path.substring(0, baseUrl.path.length - 1)
      : baseUrl.path;
  return baseUrl.replace(path: '$prefix/widget/v1/$path');
}

/// Builds the minimal documented headers for a visitor request.
///
/// Native clients cannot truthfully supply browser Origin or Referer values,
/// so those headers are deliberately absent.
Map<String, String> widgetHeaders({
  String? token,
  bool jsonBody = true,
}) =>
    <String, String>{
      'Accept': 'application/json',
      if (jsonBody) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'X-Widget-Token': token,
    };
