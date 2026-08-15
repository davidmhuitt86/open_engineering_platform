import 'dart:convert';
import 'dart:io';

/// Local "Remember Me" session state (OEP First Startup UI, Phase 0A) —
/// `%APPDATA%/oep_studio/auth_session.json`, mirroring
/// `SettingsStorage`'s own file-location convention exactly. Stores
/// only the remembered *username* — never a password, never the
/// credential hash (that stays exclusively in `CredentialStore`/Windows
/// Credential Manager). Losing or corrupting this file only means the
/// user is asked to sign in again; it carries no secret.
abstract final class AuthSessionStorage {
  static Directory _root() {
    final base = Platform.environment['APPDATA'] ?? Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
    return Directory('$base${Platform.pathSeparator}oep_studio');
  }

  static File _file() => File('${_root().path}${Platform.pathSeparator}auth_session.json');

  static Future<String?> readRememberedUsername() async {
    final file = _file();
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) return decoded['rememberedUsername'] as String?;
      return null;
    } on FormatException {
      return null;
    }
  }

  static Future<void> setRememberedUsername(String? username) async {
    await _root().create(recursive: true);
    await _file().writeAsString(jsonEncode({'rememberedUsername': username}));
  }
}
