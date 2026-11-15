# dio_resilience_mock

[![pub package](https://img.shields.io/pub/v/dio_resilience_mock.svg)](https://pub.dev/packages/dio_resilience_mock)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Deterministic pure Dart HTTP and Dio resilience mock engine with configurable latency jitter, fault injection, rate limiting, and offline cache fallback.

Engineered with zero external dependencies, `dio_resilience_mock` enables deterministic chaos testing and network resilience validation across all Dart and Flutter targets, including Web, WebAssembly (Wasm), Android, iOS, macOS, Linux, and Windows.

---

## Features

- Zero External Dependencies: Implemented strictly using the Dart standard library (`dart:async`, `dart:convert`, `dart:math`).
- Deterministic Latency Simulation: Inject bounded random latency jitter with optional seed control for reproducible tests.
- Chaos Fault Injection: Simulate transient server outages (HTTP 500/503), rate limiting (HTTP 429), or complete network drops.
- Probabilistic Failure Modes: Configurable failure ratios for realistic flaky network simulation.
- Offline Cache Fallback: Automatically serves the last successful cached GET payload during network outages.
- Telemetry and Metrics: Track request volume, injected fault rates, cache hits, and average simulated latency.
- Full Interoperability: Easily wrap with custom Dio interceptors, HTTP client adapters, or standalone test harnesses.

---

## Installation

Add the package to your Dart project:

```bash
dart pub add dio_resilience_mock
```

Or for Flutter projects:

```bash
flutter pub add dio_resilience_mock
```

---

## Fault Injection Policy Configuration

Network simulation behavior is driven by `FaultInjectionPolicy`:

| Property | Type | Default | Description |
|---|---|---|---|
| `minLatency` | `Duration` | `Duration.zero` | Minimum simulated network delay applied to requests. |
| `maxLatency` | `Duration` | `Duration.zero` | Maximum simulated network delay applied to requests. |
| `simulateOffline` | `bool` | `false` | When true, simulates complete loss of network connectivity. |
| `forcedStatusCode` | `int?` | `null` | Overrides the HTTP status code (for example, 503 or 429). |
| `failureProbability` | `double` | `0.0` | Probability (between 0.0 and 1.0) of randomly injecting a failure. |
| `failureStatusCode` | `int` | `503` | Status code returned when a failure is probabilistically injected. |
| `serveCachedOnFailure` | `bool` | `true` | If true, automatically serves cached GET responses during faults. |

---

## Standalone Quickstart

```dart
import 'package:dio_resilience_mock/dio_resilience_mock.dart';

Future<void> main() async {
  final engine = ResilienceMockEngine(
    initialPolicy: const FaultInjectionPolicy(
      minLatency: Duration(milliseconds: 10),
      maxLatency: Duration(milliseconds: 50),
    ),
    randomSeed: 42,
  );

  // Register a mock endpoint with dynamic parameters
  engine.onGet('/api/v1/users/:id', {'id': 'user-101', 'name': 'Alice'});

  // Warm the cache with a healthy request
  final healthyResponse = await engine.execute(
    MockHttpRequest(method: 'GET', path: '/api/v1/users/user-101'),
  );
  print('Healthy Response: ${healthyResponse.statusCode}'); // 200

  // Simulate network disconnection with offline cache fallback
  engine.updatePolicy(
    const FaultInjectionPolicy(
      simulateOffline: true,
      serveCachedOnFailure: true,
    ),
  );

  final cachedResponse = await engine.execute(
    MockHttpRequest(method: 'GET', path: '/api/v1/users/user-101'),
  );
  print('Cached Response: ${cachedResponse.statusCode}'); // 200
  print('Served From Cache: ${cachedResponse.isFromOfflineCache}'); // true

  // Inspect telemetry snapshot
  final snapshot = engine.telemetry;
  print('Total requests: ${snapshot.totalRequests}');
  print('Cache hits: ${snapshot.offlineCacheHits}');
}
```

---

## Dio Interceptor Integration

Connect `ResilienceMockEngine` to Dio via a custom `Interceptor`:

```dart
import 'package:dio/dio.dart';
import 'package:dio_resilience_mock/dio_resilience_mock.dart';

class ResilienceMockInterceptor extends Interceptor {
  ResilienceMockInterceptor(this.engine);

  final ResilienceMockEngine engine;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final mockRequest = MockHttpRequest(
      method: options.method,
      path: options.path,
      queryParameters: options.queryParameters.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      headers: options.headers.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      body: options.data,
    );

    final mockResponse = await engine.execute(mockRequest);

    if (mockResponse.isFaultInjected && mockResponse.statusCode >= 400) {
      handler.reject(
        DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: mockResponse.statusCode,
            data: mockResponse.data,
            headers: Headers.fromMap(
              mockResponse.headers.map((k, v) => MapEntry(k, [v])),
            ),
          ),
          type: DioExceptionType.badResponse,
          message: 'Injected resilience fault: HTTP ${mockResponse.statusCode}',
        ),
      );
      return;
    }

    handler.resolve(
      Response(
        requestOptions: options,
        statusCode: mockResponse.statusCode,
        data: mockResponse.data,
        headers: Headers.fromMap(
          mockResponse.headers.map((k, v) => MapEntry(k, [v])),
        ),
      ),
    );
  }
}
```

Attach the interceptor to your Dio client during testing or staging:

```dart
final dio = Dio();
final engine = ResilienceMockEngine();

dio.interceptors.add(ResilienceMockInterceptor(engine));
```

---

## Telemetry and Metrics

The engine continuously records performance and resilience metrics accessible via `engine.telemetry`:

- `totalRequests`: Total requests routed through the engine.
- `successfulResponses`: Count of HTTP 2xx responses returned.
- `injectedFaults`: Number of injected errors or chaos events.
- `offlineCacheHits`: Count of responses served via offline fallback.
- `unmatchedRoutes`: Requests that did not match any registered pattern.
- `totalSimulatedLatency`: Total duration of artificial delay.
- `averageLatency`: Computed average delay per request.
- `faultRate`: Computed ratio of injected faults to total requests.

To reset telemetry metrics between tests:

```dart
engine.resetTelemetry();
```

---

## Links and Resources

- Repository: [https://github.com/Safeer-Hussain/dio_resilience_mock](https://github.com/Safeer-Hussain/dio_resilience_mock)
- Issue Tracker: [https://github.com/Safeer-Hussain/dio_resilience_mock/issues](https://github.com/Safeer-Hussain/dio_resilience_mock/issues)
- License: [MIT License](LICENSE)
