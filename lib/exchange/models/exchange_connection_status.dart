/// The result of a connectivity check against the Engineering Exchange's
/// REST API (WP-EXC-010), mirroring `AcquisitionConnectionStatus`'s own
/// shape for the same reason: a separate REST-backed service, not an
/// in-process FFI library like the Foundation Bridge.
enum ExchangeConnectionStatus { notTested, connected, networkError, serviceError }
