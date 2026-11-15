import 'package:dio_resilience_mock/dio_resilience_mock.dart';
import 'package:test/test.dart';

void main() {
  group('Static Route Registration and Matching', () {
    test('onGet returns registered payload and status', () async {
      final engine = ResilienceMockEngine();
      engine.onGet('/api/v1/health', {'status': 'healthy'});

      final response = await engine.execute(
        MockHttpRequest(method: 'GET', path: '/api/v1/health'),
      );

      expect(response.statusCode, equals(200));
      expect(response.isSuccess, isTrue);
      expect(response.data, equals({'status': 'healthy'}));
      expect(response.isFaultInjected, isFalse);
      expect(response.isFromOfflineCache, isFalse);
    });

    test('onPost returns registered 201 created status and body', () async {
      final engine = ResilienceMockEngine();
      engine.onPost('/api/v1/items', {'id': 'item-1'}, statusCode: 201);

      final response = await engine.execute(
        MockHttpRequest(
          method: 'POST',
          path: '/api/v1/items',
          body: {'name': 'New Item'},
        ),
      );

      expect(response.statusCode, equals(201));
      expect(response.isSuccess, isTrue);
      expect(response.data, equals({'id': 'item-1'}));
    });

    test('onPut returns registered status and body', () async {
      final engine = ResilienceMockEngine();
      engine.onPut('/api/v1/items/1', {'updated': true});

      final response = await engine.execute(
        MockHttpRequest(
          method: 'PUT',
          path: '/api/v1/items/1',
          body: {'name': 'Updated'},
        ),
      );

      expect(response.statusCode, equals(200));
      expect(response.data, equals({'updated': true}));
    });

    test('onDelete returns registered status and body', () async {
      final engine = ResilienceMockEngine();
      engine.onDelete('/api/v1/items/1', {'deleted': true});

      final response = await engine.execute(
        MockHttpRequest(method: 'DELETE', path: '/api/v1/items/1'),
      );

      expect(response.statusCode, equals(200));
      expect(response.data, equals({'deleted': true}));
    });

    test('Unmatched route returns HTTP 404 and increments unmatchedRoutes',
        () async {
      final engine = ResilienceMockEngine();
      engine.onGet('/api/v1/exists', {'ok': true});

      final response = await engine.execute(
        MockHttpRequest(method: 'GET', path: '/api/v1/not-found'),
      );

      expect(response.statusCode, equals(404));
      expect(response.isSuccess, isFalse);
      expect(engine.telemetry.unmatchedRoutes, equals(1));
      expect(engine.telemetry.successfulResponses, equals(0));
    });

    test('Normalizes lowercase HTTP method in request and route definition',
        () async {
      final engine = ResilienceMockEngine();
      engine.onGet('/api/ping', {'ping': 'pong'});

      final response = await engine.execute(
        MockHttpRequest(method: 'get', path: '/api/ping'),
      );

      expect(response.statusCode, equals(200));
      expect(response.data, equals({'ping': 'pong'}));
    });
  });

  group('Dynamic Path Parameter Extraction', () {
    test('extracts single dynamic segment parameter correctly', () async {
      final engine = ResilienceMockEngine();
      engine.registerRoute(
        'GET',
        '/vehicles/:vehicleId/telemetry',
        (request, params) {
          return MockHttpResponse(
            statusCode: 200,
            data: {
              'vehicleId': params['vehicleId'],
              'speed': 80,
            },
          );
        },
      );

      final response = await engine.execute(
        MockHttpRequest(
          method: 'GET',
          path: '/vehicles/VH-4402/telemetry',
        ),
      );

      expect(response.statusCode, equals(200));
      expect(
          response.data,
          equals({
            'vehicleId': 'VH-4402',
            'speed': 80,
          }));
    });

    test('extracts multiple dynamic segment parameters', () async {
      final engine = ResilienceMockEngine();
      engine.registerRoute(
        'GET',
        '/tenants/:tenantId/users/:userId/roles',
        (request, params) {
          return MockHttpResponse(
            statusCode: 200,
            data: {
              'tenant': params['tenantId'],
              'user': params['userId'],
            },
          );
        },
      );

      final response = await engine.execute(
        MockHttpRequest(
          method: 'GET',
          path: '/tenants/org-99/users/usr-12/roles',
        ),
      );

      expect(response.statusCode, equals(200));
      expect(
          response.data,
          equals({
            'tenant': 'org-99',
            'user': 'usr-12',
          }));
    });
  });

  group('Latency Jitter Simulation', () {
    test('simulates deterministic latency within bounds', () async {
      const minLatency = Duration(milliseconds: 10);
      const maxLatency = Duration(milliseconds: 30);

      final engine = ResilienceMockEngine(
        initialPolicy: FaultInjectionPolicy(
          minLatency: minLatency,
          maxLatency: maxLatency,
        ),
        randomSeed: 12345,
      );

      engine.onGet('/api/data', {'status': 'ok'});

      final response = await engine.execute(
        MockHttpRequest(method: 'GET', path: '/api/data'),
      );

      expect(
        response.simulatedLatency.inMicroseconds,
        greaterThanOrEqualTo(minLatency.inMicroseconds),
      );
      expect(
        response.simulatedLatency.inMicroseconds,
        lessThanOrEqualTo(maxLatency.inMicroseconds),
      );
      expect(engine.telemetry.totalSimulatedLatency,
          equals(response.simulatedLatency));
    });
  });

  group('Fault Injection and Chaos Testing', () {
    test('forced HTTP 503 injection marks isFaultInjected as true', () async {
      final engine = ResilienceMockEngine(
        initialPolicy: FaultInjectionPolicy(
          forcedStatusCode: 503,
          serveCachedOnFailure: false,
        ),
      );
      engine.onGet('/api/service', {'status': 'ok'});

      final response = await engine.execute(
        MockHttpRequest(method: 'GET', path: '/api/service'),
      );

      expect(response.statusCode, equals(503));
      expect(response.isFaultInjected, isTrue);
      expect(response.isSuccess, isFalse);
      expect(engine.telemetry.injectedFaults, equals(1));
    });

    test('forced HTTP 429 rate limiting injection', () async {
      final engine = ResilienceMockEngine(
        initialPolicy: FaultInjectionPolicy(
          forcedStatusCode: 429,
          serveCachedOnFailure: false,
        ),
      );
      engine.onPost('/api/orders', {'created': true});

      final response = await engine.execute(
        MockHttpRequest(method: 'POST', path: '/api/orders'),
      );

      expect(response.statusCode, equals(429));
      expect(response.isFaultInjected, isTrue);
      expect(engine.telemetry.injectedFaults, equals(1));
    });

    test('probabilistic fault injection with fixed seed is deterministic',
        () async {
      final engine = ResilienceMockEngine(
        initialPolicy: FaultInjectionPolicy(
          failureProbability: 0.5,
          failureStatusCode: 500,
          serveCachedOnFailure: false,
        ),
        randomSeed: 999,
      );
      engine.onGet('/api/test', {'value': 1});

      var failures = 0;
      var successes = 0;

      for (var i = 0; i < 20; i++) {
        final res = await engine.execute(
          MockHttpRequest(method: 'GET', path: '/api/test'),
        );
        if (res.isFaultInjected) {
          failures++;
          expect(res.statusCode, equals(500));
        } else {
          successes++;
          expect(res.statusCode, equals(200));
        }
      }

      expect(failures, greaterThan(0));
      expect(successes, greaterThan(0));
      expect(engine.telemetry.totalRequests, equals(20));
      expect(engine.telemetry.injectedFaults, equals(failures));
      expect(engine.telemetry.successfulResponses, equals(successes));
    });
  });

  group('Offline Cache Fallback', () {
    test(
        'returns cached response when simulateOffline is true and cache is warmed',
        () async {
      final engine = ResilienceMockEngine();
      engine.onGet('/api/v1/profile', {'name': 'Alice', 'role': 'Admin'});

      // Warm cache with a successful request.
      final warmRes = await engine.execute(
        MockHttpRequest(method: 'GET', path: '/api/v1/profile'),
      );
      expect(warmRes.statusCode, equals(200));
      expect(warmRes.isFromOfflineCache, isFalse);

      // Now disconnect the network.
      engine.updatePolicy(
        FaultInjectionPolicy(
          simulateOffline: true,
          serveCachedOnFailure: true,
        ),
      );

      final cachedRes = await engine.execute(
        MockHttpRequest(method: 'GET', path: '/api/v1/profile'),
      );

      expect(cachedRes.statusCode, equals(200));
      expect(cachedRes.isFromOfflineCache, isTrue);
      expect(cachedRes.isFaultInjected, isFalse);
      expect(cachedRes.data, equals({'name': 'Alice', 'role': 'Admin'}));
      expect(engine.telemetry.offlineCacheHits, equals(1));
    });

    test('disabling serveCachedOnFailure returns error status when offline',
        () async {
      final engine = ResilienceMockEngine();
      engine.onGet('/api/v1/data', {'key': 'val'});

      // Warm cache.
      await engine.execute(
        MockHttpRequest(method: 'GET', path: '/api/v1/data'),
      );

      // Offline without cache serving.
      engine.updatePolicy(
        FaultInjectionPolicy(
          simulateOffline: true,
          serveCachedOnFailure: false,
          failureStatusCode: 503,
        ),
      );

      final res = await engine.execute(
        MockHttpRequest(method: 'GET', path: '/api/v1/data'),
      );

      expect(res.statusCode, equals(503));
      expect(res.isFaultInjected, isTrue);
      expect(res.isFromOfflineCache, isFalse);
      expect(engine.telemetry.offlineCacheHits, equals(0));
      expect(engine.telemetry.injectedFaults, equals(1));
    });

    test('non-GET requests never serve from offline cache', () async {
      final engine = ResilienceMockEngine();
      engine.onGet('/api/v1/items', [
        {'id': 1}
      ]);
      engine.onPost('/api/v1/items', {'id': 2});

      // Warm GET cache.
      await engine.execute(
        MockHttpRequest(method: 'GET', path: '/api/v1/items'),
      );

      // Set offline.
      engine.updatePolicy(
        FaultInjectionPolicy(
          simulateOffline: true,
          serveCachedOnFailure: true,
        ),
      );

      final postRes = await engine.execute(
        MockHttpRequest(method: 'POST', path: '/api/v1/items'),
      );

      expect(postRes.statusCode, equals(503));
      expect(postRes.isFaultInjected, isTrue);
      expect(postRes.isFromOfflineCache, isFalse);
    });

    test('clearCache purges stored GET responses', () async {
      final engine = ResilienceMockEngine();
      engine.onGet('/api/v1/cached', {'cached': true});

      await engine.execute(
        MockHttpRequest(method: 'GET', path: '/api/v1/cached'),
      );
      expect(engine.hasCached('GET:/api/v1/cached'), isTrue);

      engine.clearCache();
      expect(engine.hasCached('GET:/api/v1/cached'), isFalse);
    });
  });

  group('Telemetry Metrics and Reset', () {
    test('tracks counters correctly and resets them', () async {
      final engine = ResilienceMockEngine(
        initialPolicy: FaultInjectionPolicy(
          forcedStatusCode: 500,
          serveCachedOnFailure: false,
          minLatency: const Duration(milliseconds: 5),
          maxLatency: const Duration(milliseconds: 5),
        ),
      );

      engine.onGet('/ping', {'pong': true});

      await engine.execute(MockHttpRequest(method: 'GET', path: '/ping'));
      await engine.execute(MockHttpRequest(method: 'GET', path: '/ping'));

      final snapshot = engine.telemetry;
      expect(snapshot.totalRequests, equals(2));
      expect(snapshot.injectedFaults, equals(2));
      expect(snapshot.successfulResponses, equals(0));
      expect(snapshot.faultRate, equals(1.0));
      expect(snapshot.averageLatency.inMilliseconds, equals(5));

      engine.resetTelemetry();
      final resetSnapshot = engine.telemetry;
      expect(resetSnapshot.totalRequests, equals(0));
      expect(resetSnapshot.injectedFaults, equals(0));
      expect(resetSnapshot.totalSimulatedLatency, equals(Duration.zero));
      expect(resetSnapshot.averageLatency, equals(Duration.zero));
      expect(resetSnapshot.faultRate, equals(0.0));
    });
  });

  group('Model Equality, HashCode, CopyWith and Validation', () {
    test('FaultInjectionPolicy value equality, copyWith, and assertions', () {
      final policy1 = FaultInjectionPolicy(
        minLatency: const Duration(milliseconds: 10),
        maxLatency: const Duration(milliseconds: 20),
        simulateOffline: false,
        forcedStatusCode: 429,
        failureProbability: 0.25,
        failureStatusCode: 503,
        serveCachedOnFailure: true,
      );

      final policy2 = FaultInjectionPolicy(
        minLatency: const Duration(milliseconds: 10),
        maxLatency: const Duration(milliseconds: 20),
        simulateOffline: false,
        forcedStatusCode: 429,
        failureProbability: 0.25,
        failureStatusCode: 503,
        serveCachedOnFailure: true,
      );

      expect(policy1, equals(policy2));
      expect(policy1.hashCode, equals(policy2.hashCode));
      expect(policy1.toString(), contains('FaultInjectionPolicy'));

      final modified = policy1.copyWith(
        forcedStatusCode: 500,
        simulateOffline: true,
      );
      expect(modified.forcedStatusCode, equals(500));
      expect(modified.simulateOffline, isTrue);
      expect(modified.minLatency, equals(const Duration(milliseconds: 10)));

      final clearedForced = modified.copyWith(clearForcedStatusCode: true);
      expect(clearedForced.forcedStatusCode, isNull);

      // Assertions
      expect(
        () => FaultInjectionPolicy(
          minLatency: const Duration(seconds: 2),
          maxLatency: const Duration(seconds: 1),
        ),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => FaultInjectionPolicy(failureProbability: -0.1),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => FaultInjectionPolicy(failureProbability: 1.5),
        throwsA(isA<AssertionError>()),
      );
    });

    test('MockHttpRequest value equality, copyWith, cacheKey and headers', () {
      final req1 = MockHttpRequest(
        method: 'post',
        path: '/api/v1/orders',
        queryParameters: {'sort': 'desc'},
        headers: {'content-type': 'application/json'},
        body: {'orderId': 101},
      );

      final req2 = MockHttpRequest(
        method: 'POST',
        path: '/api/v1/orders',
        queryParameters: {'sort': 'desc'},
        headers: {'content-type': 'application/json'},
        body: {'orderId': 101},
      );

      expect(req1, equals(req2));
      expect(req1.hashCode, equals(req2.hashCode));
      expect(req1.method, equals('POST'));
      expect(req1.cacheKey, equals('POST:/api/v1/orders'));
      expect(req1.toString(), contains('MockHttpRequest'));

      final modifiedReq = req1.copyWith(path: '/api/v2/orders');
      expect(modifiedReq.path, equals('/api/v2/orders'));
      expect(modifiedReq.method, equals('POST'));
      expect(modifiedReq.body, equals({'orderId': 101}));
    });

    test('MockHttpResponse value equality, isSuccess, and copyWith', () {
      final res1 = MockHttpResponse(
        statusCode: 200,
        data: {'ok': true},
        headers: {'x-custom': 'val'},
        simulatedLatency: const Duration(milliseconds: 5),
        isFromOfflineCache: false,
        isFaultInjected: false,
      );

      final res2 = MockHttpResponse(
        statusCode: 200,
        data: {'ok': true},
        headers: {'x-custom': 'val'},
        simulatedLatency: const Duration(milliseconds: 5),
        isFromOfflineCache: false,
        isFaultInjected: false,
      );

      expect(res1, equals(res2));
      expect(res1.hashCode, equals(res2.hashCode));
      expect(res1.isSuccess, isTrue);
      expect(res1.toString(), contains('MockHttpResponse'));

      final updated = res1.copyWith(statusCode: 503, isFaultInjected: true);
      expect(updated.statusCode, equals(503));
      expect(updated.isSuccess, isFalse);
      expect(updated.isFaultInjected, isTrue);
    });

    test('ResilienceTelemetrySnapshot value equality, copyWith, and metrics',
        () {
      const snap1 = ResilienceTelemetrySnapshot(
        totalRequests: 10,
        successfulResponses: 8,
        injectedFaults: 2,
        offlineCacheHits: 1,
        unmatchedRoutes: 0,
        totalSimulatedLatency: Duration(milliseconds: 100),
      );

      const snap2 = ResilienceTelemetrySnapshot(
        totalRequests: 10,
        successfulResponses: 8,
        injectedFaults: 2,
        offlineCacheHits: 1,
        unmatchedRoutes: 0,
        totalSimulatedLatency: Duration(milliseconds: 100),
      );

      expect(snap1, equals(snap2));
      expect(snap1.hashCode, equals(snap2.hashCode));
      expect(snap1.averageLatency, equals(const Duration(milliseconds: 10)));
      expect(snap1.faultRate, equals(0.2));
      expect(snap1.toString(), contains('ResilienceTelemetrySnapshot'));

      final modified = snap1.copyWith(totalRequests: 20);
      expect(modified.totalRequests, equals(20));
      expect(modified.successfulResponses, equals(8));
    });
  });
}
