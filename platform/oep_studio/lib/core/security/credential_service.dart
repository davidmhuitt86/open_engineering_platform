import 'dart:io';

import 'credential_store.dart';
import 'windows_credential_store.dart';

/// Selects the `CredentialStore` backend for the current platform (Work
/// Package 018 STUDIO-TASK-000057). Every caller — `AnthropicProvider`,
/// the Artificial Intelligence settings page, and any future credential
/// consumer — reaches a backend only through [instance], never by
/// constructing `WindowsCredentialStore` (or a future
/// `MacosCredentialStore`/`LinuxCredentialStore`) directly.
///
/// Only Windows is implemented today, matching Studio's own current
/// scope (`FoundationBridge`/`OepApiBindings` are equally
/// Windows-only). macOS Keychain (`Security.framework`) and Linux
/// Secret Service (`libsecret`/D-Bus) are natural future backends
/// behind this same [CredentialStore] interface — adding one means
/// implementing the interface and extending the platform switch below;
/// nothing above this file changes. See
/// `docs/ANTHROPIC_PROVIDER.md` § Architectural Observations.
abstract final class CredentialService {
  static final CredentialStore instance = _select();

  static CredentialStore _select() {
    if (Platform.isWindows) return WindowsCredentialStore();
    throw UnsupportedError(
      'No CredentialStore backend is implemented for this platform yet '
      '(only Windows is supported today).',
    );
  }
}
