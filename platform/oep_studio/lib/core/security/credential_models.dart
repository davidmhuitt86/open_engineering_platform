/// A credential entry's identity, returned by `CredentialStore.listCredentials`
/// (Work Package 018 STUDIO-TASK-000057) — never the secret itself.
/// Deliberately minimal: callers that need to know "is a credential
/// configured for X" use this; nothing in Studio ever needs to
/// enumerate secret *values*.
class CredentialSummary {
  const CredentialSummary({required this.providerId});

  final String providerId;
}

/// A `CredentialStore` operation failure (Work Package 018) — a
/// read/write/delete/enumerate call to the OS credential facility
/// failed. Translated from whatever native error occurred into a
/// professional message; never a raw Win32 error code reaching the UI.
class CredentialStoreException implements Exception {
  const CredentialStoreException(this.message);

  final String message;

  @override
  String toString() => 'CredentialStoreException: $message';
}
