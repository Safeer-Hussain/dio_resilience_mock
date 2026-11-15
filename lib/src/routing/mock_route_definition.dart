/// Route definition and path pattern matching for resilience mock handlers.
library;

import 'dart:async';

import '../models/mock_http_models.dart';

/// Handler function invoked when a request matches a registered route.
typedef MockRouteHandler = FutureOr<MockHttpResponse> Function(
  MockHttpRequest request,
  Map<String, String> pathParams,
);

/// Defines a route matching an HTTP method and path pattern with dynamic parameters.
class MockRouteDefinition {
  /// Creates a new [MockRouteDefinition] instance.
  ///
  /// The [method] is normalized to uppercase.
  MockRouteDefinition({
    required String method,
    required this.pathPattern,
    required this.handler,
  })  : method = method.toUpperCase(),
        _patternSegments = _splitSegments(pathPattern);

  /// HTTP method (e.g. GET, POST, PUT, DELETE), normalized uppercase.
  final String method;

  /// Path pattern (e.g. `/api/v1/orders/:id`).
  final String pathPattern;

  /// Callback executed when this route is matched.
  final MockRouteHandler handler;

  final List<String> _patternSegments;

  static List<String> _splitSegments(String path) {
    final sanitized = path.split('?').first;
    return sanitized.split('/').where((segment) => segment.isNotEmpty).toList();
  }

  /// Determines whether this route matches the given [method] and [path].
  bool matches(String method, String path) {
    if (this.method != method.toUpperCase()) {
      return false;
    }
    final segments = _splitSegments(path);
    if (segments.length != _patternSegments.length) {
      return false;
    }
    for (var i = 0; i < segments.length; i++) {
      final patternSegment = _patternSegments[i];
      if (patternSegment.startsWith(':')) {
        continue;
      }
      if (patternSegment != segments[i]) {
        return false;
      }
    }
    return true;
  }

  /// Extracts dynamic path parameters from the provided [path].
  ///
  /// Returns an unmodifiable map of parameter names (without `:`) to values.
  Map<String, String> extractPathParams(String path) {
    final segments = _splitSegments(path);
    if (segments.length != _patternSegments.length) {
      return const {};
    }
    final params = <String, String>{};
    for (var i = 0; i < segments.length; i++) {
      final patternSegment = _patternSegments[i];
      if (patternSegment.startsWith(':')) {
        final key = patternSegment.substring(1);
        params[key] = segments[i];
      }
    }
    return Map.unmodifiable(params);
  }

  @override
  String toString() {
    return 'MockRouteDefinition(method: $method, pathPattern: $pathPattern)';
  }
}
