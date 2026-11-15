/// Deterministic pure Dart HTTP and Dio resilience mock engine with configurable
/// latency jitter, fault injection, rate limiting, and offline cache fallback.
library;

export 'src/engine/resilience_mock_engine.dart';
export 'src/models/fault_injection_policy.dart';
export 'src/models/mock_http_models.dart';
export 'src/models/resilience_telemetry_snapshot.dart';
export 'src/routing/mock_route_definition.dart';
