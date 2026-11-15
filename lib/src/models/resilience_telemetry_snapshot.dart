/// Telemetry snapshot and metric models for resilience simulation tracking.
library;

/// Immutable metrics snapshot capturing mock network engine activity.
class ResilienceTelemetrySnapshot {
  /// Creates a new [ResilienceTelemetrySnapshot] instance.
  const ResilienceTelemetrySnapshot({
    this.totalRequests = 0,
    this.successfulResponses = 0,
    this.injectedFaults = 0,
    this.offlineCacheHits = 0,
    this.unmatchedRoutes = 0,
    this.totalSimulatedLatency = Duration.zero,
  });

  /// Total number of requests executed through the engine.
  final int totalRequests;

  /// Total number of requests that resulted in successful (2xx) responses.
  final int successfulResponses;

  /// Total number of injected faults and chaos failures.
  final int injectedFaults;

  /// Total number of responses served from the offline cache fallback.
  final int offlineCacheHits;

  /// Total number of requests that did not match any registered route.
  final int unmatchedRoutes;

  /// Cumulative simulated network latency delay applied across all requests.
  final Duration totalSimulatedLatency;

  /// The average simulated latency per request, or [Duration.zero] if no requests ran.
  Duration get averageLatency {
    if (totalRequests == 0) return Duration.zero;
    return Duration(
      microseconds: totalSimulatedLatency.inMicroseconds ~/ totalRequests,
    );
  }

  /// The ratio of injected faults to total requests, or 0.0 if no requests ran.
  double get faultRate {
    if (totalRequests == 0) return 0.0;
    return injectedFaults / totalRequests;
  }

  /// Creates a copy of this snapshot with the given fields replaced.
  ResilienceTelemetrySnapshot copyWith({
    int? totalRequests,
    int? successfulResponses,
    int? injectedFaults,
    int? offlineCacheHits,
    int? unmatchedRoutes,
    Duration? totalSimulatedLatency,
  }) {
    return ResilienceTelemetrySnapshot(
      totalRequests: totalRequests ?? this.totalRequests,
      successfulResponses: successfulResponses ?? this.successfulResponses,
      injectedFaults: injectedFaults ?? this.injectedFaults,
      offlineCacheHits: offlineCacheHits ?? this.offlineCacheHits,
      unmatchedRoutes: unmatchedRoutes ?? this.unmatchedRoutes,
      totalSimulatedLatency:
          totalSimulatedLatency ?? this.totalSimulatedLatency,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ResilienceTelemetrySnapshot &&
        other.totalRequests == totalRequests &&
        other.successfulResponses == successfulResponses &&
        other.injectedFaults == injectedFaults &&
        other.offlineCacheHits == offlineCacheHits &&
        other.unmatchedRoutes == unmatchedRoutes &&
        other.totalSimulatedLatency == totalSimulatedLatency;
  }

  @override
  int get hashCode => Object.hash(
        totalRequests,
        successfulResponses,
        injectedFaults,
        offlineCacheHits,
        unmatchedRoutes,
        totalSimulatedLatency,
      );

  @override
  String toString() {
    return 'ResilienceTelemetrySnapshot('
        'totalRequests: $totalRequests, '
        'successfulResponses: $successfulResponses, '
        'injectedFaults: $injectedFaults, '
        'offlineCacheHits: $offlineCacheHits, '
        'unmatchedRoutes: $unmatchedRoutes, '
        'totalSimulatedLatency: $totalSimulatedLatency, '
        'averageLatency: $averageLatency, '
        'faultRate: ${(faultRate * 100).toStringAsFixed(1)}%)';
  }
}
