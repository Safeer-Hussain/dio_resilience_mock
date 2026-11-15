/// Configuration models for fault injection, chaos engineering, and latency jitter.
library;

/// Immutable policy configuring network chaos, latency jitter, and offline simulation.
class FaultInjectionPolicy {
  /// Creates a new [FaultInjectionPolicy] instance.
  ///
  /// Asserts that [maxLatency] is greater than or equal to [minLatency], and that
  /// [failureProbability] is between 0.0 and 1.0 (inclusive).
  FaultInjectionPolicy({
    this.minLatency = Duration.zero,
    this.maxLatency = Duration.zero,
    this.simulateOffline = false,
    this.forcedStatusCode,
    this.failureProbability = 0.0,
    this.failureStatusCode = 503,
    this.serveCachedOnFailure = true,
  })  : assert(
          maxLatency >= minLatency,
          'maxLatency must be greater than or equal to minLatency',
        ),
        assert(
          failureProbability >= 0.0 && failureProbability <= 1.0,
          'failureProbability must be between 0.0 and 1.0',
        );

  /// The minimum simulated delay duration applied to requests.
  final Duration minLatency;

  /// The maximum simulated delay duration applied to requests.
  final Duration maxLatency;

  /// Whether to simulate complete network disconnection.
  final bool simulateOffline;

  /// Optional forced HTTP status code override, such as 503 or 429.
  final int? forcedStatusCode;

  /// Probability between 0.0 and 1.0 of injecting a failure into a request.
  final double failureProbability;

  /// HTTP status code returned when a failure is probabilistically injected.
  final int failureStatusCode;

  /// Whether to serve the last successful cached GET payload when offline or faulted.
  final bool serveCachedOnFailure;

  /// Creates a copy of this policy with the given fields replaced.
  FaultInjectionPolicy copyWith({
    Duration? minLatency,
    Duration? maxLatency,
    bool? simulateOffline,
    int? forcedStatusCode,
    bool clearForcedStatusCode = false,
    double? failureProbability,
    int? failureStatusCode,
    bool? serveCachedOnFailure,
  }) {
    return FaultInjectionPolicy(
      minLatency: minLatency ?? this.minLatency,
      maxLatency: maxLatency ?? this.maxLatency,
      simulateOffline: simulateOffline ?? this.simulateOffline,
      forcedStatusCode: clearForcedStatusCode
          ? null
          : (forcedStatusCode ?? this.forcedStatusCode),
      failureProbability: failureProbability ?? this.failureProbability,
      failureStatusCode: failureStatusCode ?? this.failureStatusCode,
      serveCachedOnFailure: serveCachedOnFailure ?? this.serveCachedOnFailure,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FaultInjectionPolicy &&
        other.minLatency == minLatency &&
        other.maxLatency == maxLatency &&
        other.simulateOffline == simulateOffline &&
        other.forcedStatusCode == forcedStatusCode &&
        other.failureProbability == failureProbability &&
        other.failureStatusCode == failureStatusCode &&
        other.serveCachedOnFailure == serveCachedOnFailure;
  }

  @override
  int get hashCode => Object.hash(
        minLatency,
        maxLatency,
        simulateOffline,
        forcedStatusCode,
        failureProbability,
        failureStatusCode,
        serveCachedOnFailure,
      );

  @override
  String toString() {
    return 'FaultInjectionPolicy('
        'minLatency: $minLatency, '
        'maxLatency: $maxLatency, '
        'simulateOffline: $simulateOffline, '
        'forcedStatusCode: $forcedStatusCode, '
        'failureProbability: $failureProbability, '
        'failureStatusCode: $failureStatusCode, '
        'serveCachedOnFailure: $serveCachedOnFailure)';
  }
}
