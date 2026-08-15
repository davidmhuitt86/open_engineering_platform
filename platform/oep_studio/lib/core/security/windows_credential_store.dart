import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'credential_models.dart';
import 'credential_store.dart';
import 'windows_credential_bindings.dart';
import 'windows_credential_native_types.dart';

/// The Windows backend of `CredentialStore` (Work Package 018
/// STUDIO-TASK-000057), storing secrets in Windows Credential Manager
/// via `advapi32.dll`'s Unicode Credential Manager functions through
/// `dart:ffi` — the same native-interop approach already used
/// throughout OEP for the Foundation Bridge. No ATL, no COM, no
/// external process, no additional C++ runtime dependency, and no
/// third-party plugin: this file and `windows_credential_bindings.dart`/
/// `windows_credential_native_types.dart` are the entire implementation.
///
/// Every credential's Windows target name is prefixed
/// (`oep_studio/credential/<providerId>`) so [listCredentials] can
/// enumerate *only Studio's own* credentials — `CredEnumerateW` with no
/// filter would return every credential on the system (saved Wi-Fi
/// passwords, other applications' secrets, etc.), which Studio must
/// never read or expose.
class WindowsCredentialStore implements CredentialStore {
  WindowsCredentialStore({WindowsCredentialBindings? bindings}) : _bindings = bindings ?? WindowsCredentialBindings.load();

  static const _targetPrefix = 'oep_studio/credential/';

  final WindowsCredentialBindings _bindings;

  String _targetNameFor(String providerId) => '$_targetPrefix$providerId';

  @override
  Future<void> saveCredential({required String providerId, required String secret}) async {
    final targetNamePointer = _targetNameFor(providerId).toNativeUtf16();
    final secretBytes = Uint8List.fromList(utf8.encode(secret));
    final blobPointer = malloc<Uint8>(secretBytes.isEmpty ? 1 : secretBytes.length);
    blobPointer.asTypedList(secretBytes.length).setAll(0, secretBytes);
    final credentialPointer = malloc<CredentialNative>();

    try {
      final credential = credentialPointer.ref;
      credential.flags = 0;
      credential.type = credTypeGeneric;
      credential.targetName = targetNamePointer;
      credential.comment = nullptr;
      credential.lastWritten.dwLowDateTime = 0;
      credential.lastWritten.dwHighDateTime = 0;
      credential.credentialBlobSize = secretBytes.length;
      credential.credentialBlob = blobPointer;
      credential.persist = credPersistLocalMachine;
      credential.attributeCount = 0;
      credential.attributes = nullptr;
      credential.targetAlias = nullptr;
      credential.userName = nullptr;

      final ok = _bindings.credWrite(credentialPointer, 0);
      if (ok == 0) {
        throw CredentialStoreException(_describeLastError('save', providerId));
      }
    } finally {
      malloc.free(targetNamePointer);
      malloc.free(blobPointer);
      malloc.free(credentialPointer);
    }
  }

  @override
  Future<String?> readCredential(String providerId) async {
    final targetNamePointer = _targetNameFor(providerId).toNativeUtf16();
    final outCredential = malloc<Pointer<CredentialNative>>();

    try {
      final ok = _bindings.credRead(targetNamePointer, credTypeGeneric, 0, outCredential);
      if (ok == 0) {
        final error = _bindings.getLastError();
        if (error == errorNotFound) return null;
        throw CredentialStoreException(_describe('read', providerId, error));
      }

      final credential = outCredential.value.ref;
      final bytes = credential.credentialBlob.asTypedList(credential.credentialBlobSize);
      final secret = utf8.decode(bytes);
      _bindings.credFree(outCredential.value.cast());
      return secret;
    } finally {
      malloc.free(targetNamePointer);
      malloc.free(outCredential);
    }
  }

  @override
  Future<void> deleteCredential(String providerId) async {
    final targetNamePointer = _targetNameFor(providerId).toNativeUtf16();
    try {
      final ok = _bindings.credDelete(targetNamePointer, credTypeGeneric, 0);
      if (ok == 0) {
        final error = _bindings.getLastError();
        if (error == errorNotFound) return; // already gone — a no-op, not a failure
        throw CredentialStoreException(_describe('delete', providerId, error));
      }
    } finally {
      malloc.free(targetNamePointer);
    }
  }

  @override
  Future<List<CredentialSummary>> listCredentials() async {
    final filterPointer = '$_targetPrefix*'.toNativeUtf16();
    final countPointer = malloc<Uint32>();
    final credentialsPointer = malloc<Pointer<Pointer<CredentialNative>>>();

    try {
      final ok = _bindings.credEnumerate(filterPointer, 0, countPointer, credentialsPointer);
      if (ok == 0) {
        final error = _bindings.getLastError();
        if (error == errorNotFound) return const []; // nothing stored yet
        throw CredentialStoreException(_describe('list', '(all)', error));
      }

      final count = countPointer.value;
      final array = credentialsPointer.value;
      final summaries = <CredentialSummary>[];
      for (var i = 0; i < count; i++) {
        final credential = array[i].ref;
        final targetName = Utf16Pointer(credential.targetName).toDartString();
        if (targetName.startsWith(_targetPrefix)) {
          summaries.add(CredentialSummary(providerId: targetName.substring(_targetPrefix.length)));
        }
      }
      _bindings.credFree(array.cast());
      return summaries;
    } finally {
      malloc.free(filterPointer);
      malloc.free(countPointer);
      malloc.free(credentialsPointer);
    }
  }

  String _describeLastError(String operation, String providerId) => _describe(operation, providerId, _bindings.getLastError());

  String _describe(String operation, String providerId, int errorCode) =>
      'Windows Credential Manager $operation failed for "$providerId" (Win32 error $errorCode).';
}
