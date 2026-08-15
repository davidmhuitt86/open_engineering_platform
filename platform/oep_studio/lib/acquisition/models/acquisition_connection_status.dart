/// The result of a connectivity check against EAM's REST API
/// (WP-PLAT-020, mirroring `AiConnectionStatus`'s own shape — "Test
/// Connection" against an external service, not an in-process FFI
/// library like the Foundation Bridge). [notTested] is the state before
/// the engineer has ever opened the Acquisition Studio or pressed "Test
/// Connection" in Settings.
enum AcquisitionConnectionStatus { notTested, connected, networkError, serviceError }
