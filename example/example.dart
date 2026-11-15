import 'dart:async';

import 'package:dio_resilience_mock/dio_resilience_mock.dart';

Future<void> main() async {
  print('=== Dio Resilience Mock Engine Demo ===');

  // Initialize engine with a deterministic seed and baseline policy.
  final engine = ResilienceMockEngine(
    initialPolicy: FaultInjectionPolicy(
      minLatency: const Duration(milliseconds: 10),
      maxLatency: const Duration(milliseconds: 25),
    ),
    randomSeed: 42,
  );

  // 1. Register routes with dynamic path parameters and standard handlers.
  engine.onGet('/api/v1/vehicles/:vehicleId/telemetry', {
    'vehicleId': 'VH-9021',
    'status': 'OPERATIONAL',
    'batteryLevel': 94.5,
    'speedKmh': 62.0,
  });

  engine.registerRoute('POST', '/api/v1/commands', (request, params) {
    return MockHttpResponse(
      statusCode: 202,
      data: {
        'commandId': 'CMD-108',
        'status': 'QUEUED',
        'payload': request.body,
      },
    );
  });

  // 2. Execute healthy GET request (populates the cache).
  print('\n[Step 1] Executing healthy GET request...');
  final initialReq = MockHttpRequest(
    method: 'GET',
    path: '/api/v1/vehicles/VH-9021/telemetry',
  );
  final initialRes = await engine.execute(initialReq);
  print('Status: ${initialRes.statusCode}');
  print('Latency: ${initialRes.simulatedLatency.inMilliseconds}ms');
  print('Data: ${initialRes.data}');
  print('Cached fallback active: ${initialRes.isFromOfflineCache}');

  // 3. Simulate HTTP 503 Service Unavailable fault injection.
  print('\n[Step 2] Injecting forced HTTP 503 fault without cache fallback...');
  engine.updatePolicy(
    engine.policy.copyWith(
      forcedStatusCode: 503,
      serveCachedOnFailure: false,
    ),
  );

  final faultRes = await engine.execute(
    MockHttpRequest(
      method: 'POST',
      path: '/api/v1/commands',
      body: {'action': 'RECALIBRATE'},
    ),
  );
  print('Status: ${faultRes.statusCode}');
  print('Fault injected: ${faultRes.isFaultInjected}');
  print('Data: ${faultRes.data}');

  // 4. Simulate complete network disconnection with offline cache fallback.
  print('\n[Step 3] Simulating offline mode with cache fallback...');
  engine.updatePolicy(
    FaultInjectionPolicy(
      simulateOffline: true,
      serveCachedOnFailure: true,
      minLatency: const Duration(milliseconds: 5),
      maxLatency: const Duration(milliseconds: 15),
    ),
  );

  final offlineCachedRes = await engine.execute(initialReq);
  print('Status: ${offlineCachedRes.statusCode}');
  print('Served from offline cache: ${offlineCachedRes.isFromOfflineCache}');
  print('Fault injected: ${offlineCachedRes.isFaultInjected}');
  print('Data: ${offlineCachedRes.data}');

  // 5. Demonstrate HTTP 429 Rate Limiting fault injection.
  print('\n[Step 4] Simulating HTTP 429 Rate Limiting...');
  engine.updatePolicy(
    FaultInjectionPolicy(
      forcedStatusCode: 429,
      serveCachedOnFailure: false,
    ),
  );
  final rateLimitedRes = await engine.execute(
    MockHttpRequest(
      method: 'GET',
      path: '/api/v1/vehicles/VH-9021/telemetry',
    ),
  );
  print('Status: ${rateLimitedRes.statusCode}');
  print('Fault injected: ${rateLimitedRes.isFaultInjected}');

  // 6. Inspect telemetry counters.
  print('\n[Step 5] Resilience Engine Telemetry Report:');
  final snapshot = engine.telemetry;
  print('Total requests: ${snapshot.totalRequests}');
  print('Successful responses: ${snapshot.successfulResponses}');
  print('Injected faults: ${snapshot.injectedFaults}');
  print('Offline cache hits: ${snapshot.offlineCacheHits}');
  print(
      'Average simulated latency: ${snapshot.averageLatency.inMicroseconds}us');
  print('Fault rate: ${(snapshot.faultRate * 100).toStringAsFixed(1)}%');
  print('Telemetry toString: $snapshot');

  print('\n=== Demo Completed Successfully ===');
}
