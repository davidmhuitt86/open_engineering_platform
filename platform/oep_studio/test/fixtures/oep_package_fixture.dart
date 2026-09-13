// WP-EXC-013's one hand-built, minimal `.oep` test fixture — a real
// package archive small enough to read in one sitting, built entirely
// in Dart source (not a checked-in binary blob) so "how it was produced"
// is simply this file itself.
//
// The manifest JSON and Repository Fragment layout (`manifest/package.json`,
// `fragment/objects/*.json`, `fragment/relationships/*.json`) are copied
// verbatim from Foundation's own test fixture
// (`platform/oep_foundation/tests/runtime/package_installation_tests.cpp`'s
// `manifest_for`/`build_demo_archive`) — not invented — so this archive
// is guaranteed to satisfy `oep::installer::extract_package`/
// `parse_oep_package_manifest`'s exact, already-tested requirements
// (PKG-002 §5's 16 required top-level fields, `publisher.id`/`.name`).
//
// The ZIP container itself is the same minimal, dependency-free, Stored
// (uncompressed) writer as that C++ file's own `build_stored_zip` —
// ported line-for-line, not reimplemented from the ZIP spec — since
// Foundation's `ZipReader` only accepts the Stored compression method
// (see that class's own documented limitation).

import 'dart:typed_data';

void _appendU16(BytesBuilder out, int value) {
  out.addByte(value & 0xFF);
  out.addByte((value >> 8) & 0xFF);
}

void _appendU32(BytesBuilder out, int value) {
  out.addByte(value & 0xFF);
  out.addByte((value >> 8) & 0xFF);
  out.addByte((value >> 16) & 0xFF);
  out.addByte((value >> 24) & 0xFF);
}

/// A minimal, Stored-only ZIP archive containing [entries] (path -> UTF-8
/// content), byte-for-byte the same layout as Foundation's own
/// `build_stored_zip` (local file headers, then a central directory, then
/// one end-of-central-directory record) — no compression, no CRC-32
/// computation (Foundation's own `ZipReader`/installer do not require
/// one either, confirmed by that builder's own `0` CRC field).
Uint8List buildStoredZip(List<MapEntry<String, String>> entries) {
  final out = BytesBuilder();
  final localHeaderOffsets = <int>[];

  for (final entry in entries) {
    final name = entry.key;
    final content = entry.value.codeUnits;
    localHeaderOffsets.add(out.length);
    _appendU32(out, 0x04034b50); // local file header signature
    _appendU16(out, 20); // version needed to extract
    _appendU16(out, 0); // general purpose bit flag
    _appendU16(out, 0); // compression method: 0 = Stored
    _appendU16(out, 0); // last mod file time
    _appendU16(out, 0); // last mod file date
    _appendU32(out, 0); // CRC-32 (not checked by the reader this targets)
    _appendU32(out, content.length); // compressed size
    _appendU32(out, content.length); // uncompressed size
    _appendU16(out, name.length); // file name length
    _appendU16(out, 0); // extra field length
    out.add(name.codeUnits);
    out.add(content);
  }

  final centralDirectoryStart = out.length;
  for (var i = 0; i < entries.length; i++) {
    final name = entries[i].key;
    final content = entries[i].value.codeUnits;
    _appendU32(out, 0x02014b50); // central directory file header signature
    _appendU16(out, 20); // version made by
    _appendU16(out, 20); // version needed to extract
    _appendU16(out, 0); // general purpose bit flag
    _appendU16(out, 0); // compression method
    _appendU16(out, 0); // last mod file time
    _appendU16(out, 0); // last mod file date
    _appendU32(out, 0); // CRC-32
    _appendU32(out, content.length); // compressed size
    _appendU32(out, content.length); // uncompressed size
    _appendU16(out, name.length); // file name length
    _appendU16(out, 0); // extra field length
    _appendU16(out, 0); // file comment length
    _appendU16(out, 0); // disk number start
    _appendU16(out, 0); // internal file attributes
    _appendU32(out, 0); // external file attributes
    _appendU32(out, localHeaderOffsets[i]); // relative offset of local header
    out.add(name.codeUnits);
  }
  final centralDirectorySize = out.length - centralDirectoryStart;

  _appendU32(out, 0x06054b50); // end of central directory signature
  _appendU16(out, 0); // number of this disk
  _appendU16(out, 0); // disk where central directory starts
  _appendU16(out, entries.length); // number of central directory records on this disk
  _appendU16(out, entries.length); // total number of central directory records
  _appendU32(out, centralDirectorySize);
  _appendU32(out, centralDirectoryStart);
  _appendU16(out, 0); // comment length

  return out.toBytes();
}

/// Verbatim copy of `package_installation_tests.cpp`'s `manifest_for` —
/// PKG-002 §5's 16 required top-level fields, minimally populated.
String demoManifestJson(String packageId) =>
    '{"schemaVersion":"1.0","packageId":"$packageId",'
    '"version":"1.0.0","publisher":{"id":"demo-publisher","name":"OEP Demo Publisher"},'
    '"title":"Engineering Demo Package","summary":"s","description":"d","category":"demonstration",'
    '"engineeringDomains":["Automotive"],"license":{},"dependencies":[],"capabilities":[],'
    '"repository":{},"statistics":{},"signatures":{},"build":{}}';

/// Verbatim copy of `package_installation_tests.cpp`'s `build_demo_archive`
/// content (two Engineering Objects, one Relationship between them) --
/// unsigned (an empty `signatures` block in the manifest above), which
/// Foundation's own trust verification accepts by default
/// (`TrustState.Unsigned`, allowed unless the repository's trust policy
/// requires signatures — see `docs/tasks/WP-EXC-013.md` §7).
Uint8List buildDemoOepPackage(String packageId) {
  const objectA = '{"objectId":"aaaaaaaa-0000-4000-8000-000000000001","objectType":"Component",'
      '"name":"Harness","description":"d","createdUtc":"2026-01-01T00:00:00Z",'
      '"lastModifiedUtc":"2026-01-01T00:00:00Z","version":"1.0.0","author":"a","tags":[]}';
  const objectB = '{"objectId":"bbbbbbbb-0000-4000-8000-000000000002","objectType":"Diagram",'
      '"name":"Wiring Diagram","description":"d","createdUtc":"2026-01-01T00:00:00Z",'
      '"lastModifiedUtc":"2026-01-01T00:00:00Z","version":"1.0.0","author":"a","tags":[]}';
  const relationship = '{"relationshipId":"cccccccc-0000-4000-8000-000000000003",'
      '"sourceObjectId":"bbbbbbbb-0000-4000-8000-000000000002",'
      '"targetObjectId":"aaaaaaaa-0000-4000-8000-000000000001",'
      '"relationshipType":"Documents","createdUtc":"2026-01-01T00:00:00Z",'
      '"author":"a","description":"d"}';

  return buildStoredZip([
    MapEntry('manifest/package.json', demoManifestJson(packageId)),
    const MapEntry('fragment/objects/a.json', objectA),
    const MapEntry('fragment/objects/b.json', objectB),
    const MapEntry('fragment/relationships/r.json', relationship),
  ]);
}

/// A deliberately unparseable ".oep" archive -- not a ZIP at all -- for
/// WP-EXC-013's own corrupt-package test.
Uint8List buildCorruptOepPackage() => Uint8List.fromList('not a zip archive'.codeUnits);
