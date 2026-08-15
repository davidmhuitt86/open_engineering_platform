import 'dart:ffi';

import 'package:ffi/ffi.dart' show Utf16;

/// Native struct/typedef layer mirroring `wincred.h`/`minwinbase.h`
/// field-for-field (Work Package 018 STUDIO-TASK-000057), the same
/// role `oep_api_native_types.dart` plays for the Foundation Bridge:
/// this file (and `windows_credential_bindings.dart`) are the only
/// places in Studio that reference these native layout details.
///
/// Uses only `advapi32.dll`'s Unicode ("W") Credential Manager
/// functions — `CredWriteW`/`CredReadW`/`CredDeleteW`/`CredEnumerateW` —
/// no ATL, no COM, no C++ runtime beyond what `dart:ffi` itself already
/// requires.

/// Mirrors `FILETIME` (`minwinbase.h`).
final class FiletimeNative extends Struct {
  @Uint32()
  external int dwLowDateTime;

  @Uint32()
  external int dwHighDateTime;
}

/// Mirrors `CREDENTIALW` (`wincred.h`). `Attributes` is always passed
/// as `nullptr`/ignored — Studio stores one opaque secret blob per
/// credential, nothing structured enough to need attributes.
final class CredentialNative extends Struct {
  @Uint32()
  external int flags;

  @Uint32()
  external int type;

  external Pointer<Utf16> targetName;

  external Pointer<Utf16> comment;

  external FiletimeNative lastWritten;

  @Uint32()
  external int credentialBlobSize;

  external Pointer<Uint8> credentialBlob;

  @Uint32()
  external int persist;

  @Uint32()
  external int attributeCount;

  external Pointer<Void> attributes;

  external Pointer<Utf16> targetAlias;

  external Pointer<Utf16> userName;
}

/// `CRED_TYPE_GENERIC` — a plain, opaque credential (as opposed to a
/// domain password/certificate type), the correct type for an
/// application-defined secret like an API key.
const int credTypeGeneric = 1;

/// `CRED_PERSIST_LOCAL_MACHINE` — survives across sessions/reboots for
/// the current Windows user, without roaming to other machines (unlike
/// `CRED_PERSIST_ENTERPRISE`), matching a locally-installed desktop
/// app's expectations.
const int credPersistLocalMachine = 2;

/// `CRED_ENUMERATE_ALL_CREDENTIALS` — passed to `CredEnumerateW` so a
/// `null` filter enumerates every credential rather than requiring a
/// wildcard target name (only meaningful together with a null filter).
const int credEnumerateAllCredentials = 0x1;

typedef CredWriteWNative = Int32 Function(Pointer<CredentialNative> credential, Uint32 flags);
typedef CredWriteWDart = int Function(Pointer<CredentialNative> credential, int flags);

typedef CredReadWNative =
    Int32 Function(Pointer<Utf16> targetName, Uint32 type, Uint32 flags, Pointer<Pointer<CredentialNative>> credential);
typedef CredReadWDart =
    int Function(Pointer<Utf16> targetName, int type, int flags, Pointer<Pointer<CredentialNative>> credential);

typedef CredDeleteWNative = Int32 Function(Pointer<Utf16> targetName, Uint32 type, Uint32 flags);
typedef CredDeleteWDart = int Function(Pointer<Utf16> targetName, int type, int flags);

typedef CredFreeNative = Void Function(Pointer<Void> buffer);
typedef CredFreeDart = void Function(Pointer<Void> buffer);

typedef CredEnumerateWNative =
    Int32 Function(
      Pointer<Utf16> filter,
      Uint32 flags,
      Pointer<Uint32> count,
      Pointer<Pointer<Pointer<CredentialNative>>> credentials,
    );
typedef CredEnumerateWDart =
    int Function(
      Pointer<Utf16> filter,
      int flags,
      Pointer<Uint32> count,
      Pointer<Pointer<Pointer<CredentialNative>>> credentials,
    );

/// `ERROR_NOT_FOUND` (`winerror.h`) — the specific Win32 error
/// `CredReadW`/`CredDeleteW` report when no credential exists for the
/// given target name, distinct from every other failure.
const int errorNotFound = 1168;

/// `kernel32.dll`'s `GetLastError`, for a professional message when a
/// Credential Manager call fails for a reason other than "not found".
typedef GetLastErrorNative = Uint32 Function();
typedef GetLastErrorDart = int Function();
