/// The result of a "Test Connection" attempt against an `AiProvider`
/// (Work Package 018 STUDIO-TASK-000058): "Display: Connected,
/// Authentication Failed, Network Error, Provider Error." [notTested]
/// is this work package's own addition — the state before the engineer
/// has ever pressed "Test Connection," distinct from having tested and
/// failed.
enum AiConnectionStatus { notTested, connected, authenticationFailed, networkError, providerError }
