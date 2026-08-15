import 'dart:convert';
import 'dart:io';

import '../../settings/services/settings_storage.dart';
import 'chain_of_custody_record.dart';

/// Local JSON persistence for [ChainOfCustodyRecord]s, keyed by Vault
/// Entry id -- one file (`chain_of_custody.json`), mirroring
/// `WorkspaceStateStorage`'s own "one small JSON file per concern"
/// precedent. See [ChainOfCustodyRecord]'s own doc comment for why this
/// is local-only rather than a backend API call.
abstract final class ChainOfCustodyStorage {
  static File _file() =>
      File('${SettingsStorage.root().path}${Platform.pathSeparator}chain_of_custody.json');

  static Future<Map<String, ChainOfCustodyRecord>> _loadAll() async {
    final file = _file();
    if (!file.existsSync()) return {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return {};
      return decoded.map(
        (key, value) => MapEntry(key, ChainOfCustodyRecord.fromJson(value as Map<String, Object?>)),
      );
    } on FormatException {
      return {};
    }
  }

  static Future<void> save(String vaultEntryId, ChainOfCustodyRecord record) async {
    final all = await _loadAll();
    all[vaultEntryId] = record;
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(encoder.convert(all.map((key, value) => MapEntry(key, value.toJson()))));
  }

  static Future<ChainOfCustodyRecord?> forVaultEntry(String vaultEntryId) async {
    final all = await _loadAll();
    return all[vaultEntryId];
  }
}
