/// Resilience mock engine simulating latency jitter, chaos, and offline caching.
library;

import 'dart:async';
import 'dart:math';

import '../models/fault_injection_policy.dart';
import '../models/mock_http_models.dart';
import '../models/resilience_telemetry_snapshot.dart';
import '../routing/mock_route_definition.dart';

/// Deterministic HTTP and Dio mock engine with resilience and chaos capabilities.
class ResilienceMockEngine {
  /// Creates a new [ResilienceMockEngine] instance.
  ///
  /// Provide an optional [randomSeed] to make latency jitter and probabilistic
  /// fault injection deterministic across test runs.
  ResilienceMockEngine({
    FaultInjectionPolicy? initialPolicy,
    int? randomSeed,
  })  : _policy = initialPolicy ?? FaultInjectionPolicy(),
        _random = Random(randomSeed);

  FaultInjectionPolicy _policy;
  final Random _random;
  final List<MockRouteDefinition> _routes = [];
  final Map<String, MockHttpResponse> _cache = {};

  int _totalRequests = 0;
  int _successfulResponses = 0;
  int _injectedFaults = 0;
  int _offlineCacheHits = 0;
  int _unmatchedRoutes = 0;
  Duration _totalSimulatedLatency = Duration.zero;

  /// The active fault injection and latency policy.
  FaultInjectionPolicy get policy => _policy;

  /// Updates the active fault injection and latency policy.
  void updatePolicy(FaultInjectionPolicy newPolicy) {
    _policy = newPolicy;
  }

  /// Registers a custom [MockRouteHandler] for the specified [method] and [pathPattern].
  void registerRoute(
    String method,
    String pathPattern,
    MockRouteHandler handler,
  ) {
    _routes.add(MockRouteDefinition(
      method: method,
      pathPattern: pathPattern,
      handler: handler,
    ));
  }

  /// Registers a GET route returning the given [responseBody] and [statusCode].
  void onGet(
    String pathPattern,
    Object? responseBody, {
    int statusCode = 200,
    Map<String, String> headers = const {},
  }) {
    registerRoute('GET', pathPattern, (request, pathParams) {
      return MockHttpResponse(
        statusCode: statusCode,
        data: responseBody,
        headers: headers,
      );
    });
  }

  /// Registers a POST route returning the given [responseBody] and [statusCode].
  void onPost(
    String pathPattern,
    Object? responseBody, {
    int statusCode = 201,
    Map<String, String> headers = const {},
  }) {
    registerRoute('POST', pathPattern, (request, pathParams) {
      return MockHttpResponse(
        statusCode: statusCode,
        data: responseBody,
        headers: headers,
      );
    });
  }

  /// Registers a PUT route returning the given [responseBody] and [statusCode].
  void onPut(
    String pathPattern,
    Object? responseBody, {
    int statusCode = 200,
    Map<String, String> headers = const {},
  }) {
    registerRoute('PUT', pathPattern, (request, pathParams) {
      return MockHttpResponse(
        statusCode: statusCode,
        data: responseBody,
        headers: headers,
      );
    });
  }

  /// Registers a DELETE route returning the given [responseBody] and [statusCode].
  void onDelete(
    String pathPattern,
    Object? responseBody, {
    int statusCode = 200,
    Map<String, String> headers = const {},
  }) {
    registerRoute('DELETE', pathPattern, (request, pathParams) {
      return MockHttpResponse(
        statusCode: statusCode,
        data: responseBody,
        headers: headers,
      );
    });
  }

  /// Executes an HTTP request through the resilience engine.
  ///
  /// Applies simulated latency jitter, evaluates fault injection policies,
  /// serves offline cache fallback when applicable, routes healthy requests,
  /// and updates telemetry counters.
  Future<MockHttpResponse> execute(MockHttpRequest request) async {
    // 1. Calculate deterministic jittered delay between minLatency and maxLatency.
    Duration delay = Duration.zero;
    if (_policy.maxLatency > Duration.zero) {
      if (_policy.maxLatency == _policy.minLatency) {
        delay = _policy.minLatency;
      } else {
        final diffMicros = _policy.maxLatency.inMicroseconds -
            _policy.minLatency.inMicroseconds;
        final jitter = _random.nextInt(diffMicros + 1);
        delay = _policy.minLatency + Duration(microseconds: jitter);
      }
    } else if (_policy.minLatency > Duration.zero) {
      delay = _policy.minLatency;
    }

    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    _totalRequests++;
    _totalSimulatedLatency += delay;

    // 2. Evaluate fault injection conditions.
    var isFault = false;
    int? faultCode;

    if (_policy.simulateOffline) {
      isFault = true;
      faultCode = _policy.forcedStatusCode ?? _policy.failureStatusCode;
    } else if (_policy.forcedStatusCode != null) {
      isFault = true;
      faultCode = _policy.forcedStatusCode;
    } else if (_policy.failureProbability > 0.0) {
      final sample = _random.nextDouble();
      if (sample < _policy.failureProbability) {
        isFault = true;
        faultCode = _policy.failureStatusCode;
      }
    }

    // 3. Fall back to offline cache if fault active and cached response exists.
    if (isFault) {
      if (request.method == 'GET' &&
          _policy.serveCachedOnFailure &&
          _cache.containsKey(request.cacheKey)) {
        _offlineCacheHits++;
        final cached = _cache[request.cacheKey]!;
        return cached.copyWith(
          simulatedLatency: delay,
          isFromOfflineCache: true,
          isFaultInjected: false,
        );
      }

      // 4. Injected fault response.
      _injectedFaults++;
      final resolvedCode = faultCode ?? _policy.failureStatusCode;
      return MockHttpResponse(
        statusCode: resolvedCode,
        data: _policy.simulateOffline
            ? {'error': 'Offline: network connection unavailable'}
            : {'error': 'Fault injected with status code $resolvedCode'},
        headers: const {'content-type': 'application/json'},
        simulatedLatency: delay,
        isFromOfflineCache: false,
        isFaultInjected: true,
      );
    }

    // 5. Match route.
    MockRouteDefinition? matchedRoute;
    Map<String, String> pathParams = const {};

    for (final route in _routes) {
      if (route.matches(request.method, request.path)) {
        matchedRoute = route;
        pathParams = route.extractPathParams(request.path);
        break;
      }
    }

    if (matchedRoute == null) {
      _unmatchedRoutes++;
      return MockHttpResponse(
        statusCode: 404,
        data: {
          'error': 'Not Found',
          'method': request.method,
          'path': request.path,
        },
        headers: const {'content-type': 'application/json'},
        simulatedLatency: delay,
        isFromOfflineCache: false,
        isFaultInjected: false,
      );
    }

    final response = await matchedRoute.handler(request, pathParams);
    final responseWithLatency = response.copyWith(
      simulatedLatency: delay,
    );

    if (responseWithLatency.isSuccess) {
      _successfulResponses++;
      if (request.method == 'GET') {
        _cache[request.cacheKey] = responseWithLatency;
      }
    }

    return responseWithLatency;
  }

  /// Whether a cached response is currently stored for [cacheKey].
  bool hasCached(String cacheKey) => _cache.containsKey(cacheKey);

  /// Retrieves the cached response for [cacheKey], or null if absent.
  MockHttpResponse? getCached(String cacheKey) => _cache[cacheKey];

  /// Manually stores a [response] into the cache for [cacheKey].
  void cacheResponse(String cacheKey, MockHttpResponse response) {
    _cache[cacheKey] = response;
  }

  /// Returns a snapshot of the current engine telemetry counters and metrics.
  ResilienceTelemetrySnapshot get telemetry => ResilienceTelemetrySnapshot(
        totalRequests: _totalRequests,
        successfulResponses: _successfulResponses,
        injectedFaults: _injectedFaults,
        offlineCacheHits: _offlineCacheHits,
        unmatchedRoutes: _unmatchedRoutes,
        totalSimulatedLatency: _totalSimulatedLatency,
      );

  /// Clears all cached response payloads.
  void clearCache() {
    _cache.clear();
  }

  /// Resets all telemetry counters and simulated latency totals to zero.
  void resetTelemetry() {
    _totalRequests = 0;
    _successfulResponses = 0;
    _injectedFaults = 0;
    _offlineCacheHits = 0;
    _unmatchedRoutes = 0;
    _totalSimulatedLatency = Duration.zero;
  }
}
