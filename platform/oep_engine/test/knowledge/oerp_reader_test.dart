import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// Builds a minimal, valid, STORED-only (uncompressed) ZIP archive
/// in-memory — enough to exercise [MinimalZipReader]/[OerpReader]
/// deterministically without depending on the Python Reference
/// Compiler being available in the test environment. `crc32` fields
/// are left at 0 (this reader — like the real .oerp reader's actual
/// use — never validates them; that's outside AP-EK-013's scope).
///
/// Genuine end-to-end proof against a *really* Python-compiled `.oerp`
/// (Reference Library -> Compiler -> .oerp -> this reader -> Runtime
/// -> AnalysisEngine -> 1.2 A / 14.4 W) lives in
/// `tool/verify_oerp_reader.dart` — a manual/CI script, not a
/// `flutter test`, because SDD-R010 §16 forbids committing compiled
/// `.oerp` output to the repository (`knowledge/reference_library/
/// .gitignore`), so no fixture `.oerp` can ship with this test suite.
Uint8List _buildStoredZip(Map<String, List<int>> entries) {
  final localHeaders = <List<int>>[];
  final centralHeaders = <List<int>>[];
  var offset = 0;

  void writeUint16(List<int> out, int value) {
    out.add(value & 0xff);
    out.add((value >> 8) & 0xff);
  }

  void writeUint32(List<int> out, int value) {
    out.add(value & 0xff);
    out.add((value >> 8) & 0xff);
    out.add((value >> 16) & 0xff);
    out.add((value >> 24) & 0xff);
  }

  final fileBytes = <List<int>>[];

  for (final entry in entries.entries) {
    final nameBytes = utf8.encode(entry.key);
    final data = entry.value;

    final local = <int>[];
    writeUint32(local, 0x04034b50);
    writeUint16(local, 20); // version needed
    writeUint16(local, 0); // flags
    writeUint16(local, 0); // compression method: stored
    writeUint16(local, 0); // mod time
    writeUint16(local, 0x21); // mod date
    writeUint32(local, 0); // crc32 (unchecked by this reader)
    writeUint32(local, data.length); // compressed size
    writeUint32(local, data.length); // uncompressed size
    writeUint16(local, nameBytes.length);
    writeUint16(local, 0); // extra length
    local.addAll(nameBytes);

    final central = <int>[];
    writeUint32(central, 0x02014b50);
    writeUint16(central, 20); // version made by
    writeUint16(central, 20); // version needed
    writeUint16(central, 0); // flags
    writeUint16(central, 0); // compression method
    writeUint16(central, 0); // mod time
    writeUint16(central, 0x21); // mod date
    writeUint32(central, 0); // crc32
    writeUint32(central, data.length);
    writeUint32(central, data.length);
    writeUint16(central, nameBytes.length);
    writeUint16(central, 0); // extra length
    writeUint16(central, 0); // comment length
    writeUint16(central, 0); // disk number start
    writeUint16(central, 0); // internal attrs
    writeUint32(central, 0); // external attrs
    writeUint32(central, offset); // local header offset
    central.addAll(nameBytes);

    localHeaders.add(local);
    fileBytes.add(data);
    centralHeaders.add(central);
    offset += local.length + data.length;
  }

  final centralDirStart = offset;
  final centralDirBytes = centralHeaders.expand((c) => c).toList();

  final eocd = <int>[];
  writeUint32(eocd, 0x06054b50);
  writeUint16(eocd, 0); // disk number
  writeUint16(eocd, 0); // disk with central dir
  writeUint16(eocd, entries.length); // entries on this disk
  writeUint16(eocd, entries.length); // total entries
  writeUint32(eocd, centralDirBytes.length);
  writeUint32(eocd, centralDirStart);
  writeUint16(eocd, 0); // comment length

  final out = <int>[];
  for (var i = 0; i < localHeaders.length; i++) {
    out.addAll(localHeaders[i]);
    out.addAll(fileBytes[i]);
  }
  out.addAll(centralDirBytes);
  out.addAll(eocd);
  return Uint8List.fromList(out);
}

Uint8List _buildOerpBytes({bool signed = false}) {
  final manifest = jsonEncode({
    'package_id': 'electrical-core-test',
    'package_name': 'Test Package',
    'version': '1.0.0',
    'publisher': 'Test Publisher',
    'compiler_version': '0.2.0',
    'build_date': '2026-09-04',
  });
  final runtime = jsonEncode({
    'schemaVersion': '1.0.0',
    'dimensions': [
      {
        'id': 'dimension.voltage',
        'name': 'Voltage',
        'exponents': {'kg': 1, 'm': 2, 's': -3, 'a': -1},
      },
    ],
    'units': [
      {
        'id': 'unit.volt',
        'symbol': 'V',
        'dimensionId': 'dimension.voltage',
        'scaleToBase': 1.0,
        'aliases': [],
      },
    ],
    'componentModels': <Object?>[],
    'laws': <Object?>[],
    'equations': <Object?>[],
    'constraints': <Object?>[],
    'provenance': <Object?>[],
  });

  final entries = <String, List<int>>{
    'manifest.json': utf8.encode(manifest),
    'runtime.json': utf8.encode(runtime),
    if (!signed) 'signature/UNSIGNED': utf8.encode('unsigned'),
    if (signed) 'signature/package.sig': utf8.encode('fake-signature-bytes'),
  };
  return _buildStoredZip(entries);
}

void main() {
  group('MinimalZipReader', () {
    test('reads back a stored entry byte-for-byte', () {
      final zip = MinimalZipReader(
        _buildStoredZip({'hello.txt': utf8.encode('hello world')}),
      );
      expect(zip.readEntryAsString('hello.txt'), 'hello world');
    });

    test('lists multiple entries', () {
      final zip = MinimalZipReader(
        _buildStoredZip({
          'a.txt': utf8.encode('a'),
          'b/c.txt': utf8.encode('bc'),
        }),
      );
      expect(zip.entryNames.toSet(), {'a.txt', 'b/c.txt'});
      expect(zip.readEntryAsString('b/c.txt'), 'bc');
    });

    test('throws for a missing entry', () {
      final zip = MinimalZipReader(
        _buildStoredZip({'a.txt': utf8.encode('a')}),
      );
      expect(() => zip.readEntry('missing.txt'), throwsArgumentError);
    });

    test('throws FormatException for non-ZIP bytes', () {
      expect(
        () => MinimalZipReader(Uint8List.fromList([1, 2, 3, 4])),
        throwsFormatException,
      );
    });
  });

  group('OerpReader', () {
    test(
      'reads a valid unsigned .oerp into a development-mode KnowledgePackage',
      () {
        final package = const OerpReader().readBytes(_buildOerpBytes());
        expect(package.manifest.packageId, 'electrical-core-test');
        expect(package.manifest.packageVersion, '1.0.0');
        expect(package.developmentModeUnsigned, isTrue);
        expect(package.units.single.id, 'unit.volt');
        expect(package.dimensions.single.id, 'dimension.voltage');
      },
    );

    test('a signed .oerp is read but not marked development-mode-unsigned', () {
      final package = const OerpReader().readBytes(
        _buildOerpBytes(signed: true),
      );
      expect(package.developmentModeUnsigned, isFalse);
      expect(package.manifest.signature, isNotNull);
    });

    test('signed .oerp still cannot activate without a trust store', () {
      final package = const OerpReader().readBytes(
        _buildOerpBytes(signed: true),
      );
      expect(
        () => KnowledgeRuntime.activate(
          package,
          allowUnsignedDevelopmentPackages: true,
        ),
        throwsA(
          isA<KnowledgeRuntimeException>().having(
            (e) => e.code,
            'code',
            KnowledgeRuntimeErrorCode.packageSignatureInvalid,
          ),
        ),
      );
    });

    test('an unsigned .oerp activates end-to-end through OerpReader', () {
      final package = const OerpReader().readBytes(_buildOerpBytes());
      final runtime = KnowledgeRuntime.activate(
        package,
        allowUnsignedDevelopmentPackages: true,
      );
      expect(runtime.identity.packageId, 'electrical-core-test');
      expect(runtime.getUnit('unit.volt').symbol, 'V');
    });

    test('missing runtime.json is rejected as packageInvalid', () {
      final bytes = _buildStoredZip({'manifest.json': utf8.encode('{}')});
      expect(
        () => const OerpReader().readBytes(bytes),
        throwsA(
          isA<KnowledgeRuntimeException>().having(
            (e) => e.code,
            'code',
            KnowledgeRuntimeErrorCode.packageInvalid,
          ),
        ),
      );
    });

    test(
      'malformed JSON is rejected as packageInvalid, not silently defaulted',
      () {
        final bytes = _buildStoredZip({
          'manifest.json': utf8.encode('not json'),
          'runtime.json': utf8.encode('{}'),
        });
        expect(
          () => const OerpReader().readBytes(bytes),
          throwsA(
            isA<KnowledgeRuntimeException>().having(
              (e) => e.code,
              'code',
              KnowledgeRuntimeErrorCode.packageInvalid,
            ),
          ),
        );
      },
    );
  });
}
