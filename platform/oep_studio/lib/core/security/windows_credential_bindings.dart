import 'dart:ffi';
import 'dart:io';

import 'windows_credential_native_types.dart';

/// Loads `advapi32.dll` (present on every Windows install — no
/// bundling, no separate build step, unlike the Foundation Bridge's own
/// `oep_foundation_bridge.dll`) and exposes typed Dart wrappers for the
/// four Credential Manager functions Studio needs. Performs no
/// marshaling beyond what `dart:ffi` does automatically — string
/// conversion, memory allocation/freeing, and error translation belong
/// to `WindowsCredentialStore`, mirroring `OepApiBindings`/
/// `FoundationBridge`'s own split.
class WindowsCredentialBindings {
  factory WindowsCredentialBindings.load() {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows Credential Manager is only available on Windows.');
    }
    final library = DynamicLibrary.open('advapi32.dll');
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    return WindowsCredentialBindings._(library, kernel32);
  }

  WindowsCredentialBindings._(this._library, this._kernel32)
    : credWrite = _library.lookupFunction<CredWriteWNative, CredWriteWDart>('CredWriteW'),
      credRead = _library.lookupFunction<CredReadWNative, CredReadWDart>('CredReadW'),
      credDelete = _library.lookupFunction<CredDeleteWNative, CredDeleteWDart>('CredDeleteW'),
      credFree = _library.lookupFunction<CredFreeNative, CredFreeDart>('CredFree'),
      credEnumerate = _library.lookupFunction<CredEnumerateWNative, CredEnumerateWDart>('CredEnumerateW'),
      getLastError = _kernel32.lookupFunction<GetLastErrorNative, GetLastErrorDart>('GetLastError');

  // ignore: unused_field
  final DynamicLibrary _library;
  // ignore: unused_field
  final DynamicLibrary _kernel32;

  final CredWriteWDart credWrite;
  final CredReadWDart credRead;
  final CredDeleteWDart credDelete;
  final CredFreeDart credFree;
  final CredEnumerateWDart credEnumerate;
  final GetLastErrorDart getLastError;
}
