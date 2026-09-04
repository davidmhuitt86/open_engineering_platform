import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../knowledge_runtime_errors.dart';
import '../models/knowledge_package.dart';
import 'minimal_zip_reader.dart';

/// Reads a compiled `.oerp` Knowledge Package (produced by
/// `knowledge/reference_library/compiler/`) into a [KnowledgePackage]
/// (AP-EK-020 Part A / AP-EK-013 §8 "Package Loading").
///
/// A `.oerp` is a deterministic ZIP containing, among other members
/// (`reference.db`, `search.idx`, `graph.idx`, `assets/`, `license/`,
/// `localization/`) that this reader does not need for the Knowledge
/// Runtime:
///
/// - `manifest.json` — package identity (id/version/publisher/...),
///   already produced by `compiler/manifest.py`.
/// - `runtime.json` — the AP-EK-013 registry-shaped payload
///   (dimensions/units/componentModels/laws/equations/constraints/
///   provenance), produced by `compiler/runtime_export.py` — the
///   Reference Compiler extension this reader was built to consume.
/// - `signature/UNSIGNED` — present exactly when the package is not
///   digitally signed (`compiler/build.py`'s `_stage_package`); its
///   presence/absence is this reader's [KnowledgePackage.developmentModeUnsigned]
///   signal. A signed package would instead carry `signature/<name>.sig`,
///   which this reader does not yet verify — see [OerpReaderException]
///   below and the AP-EK-020 final report's Ed25519 gap.
///
/// This reader performs schema/parse validation only; integrity
/// (content hash) and trust (signature) verification remain
/// [KnowledgeRuntime.activate]'s responsibility (AP-EK-013 §9-§10) —
/// this class hands it a parsed, not-yet-activated [KnowledgePackage].
class OerpReader {
  const OerpReader();

  static const _requiredEntries = ['manifest.json', 'runtime.json'];

  /// Parses [bytes] as a `.oerp` archive. Throws [KnowledgeRuntimeException]
  /// (`packageInvalid`) for anything structurally wrong — a missing
  /// required member, unparseable JSON, or an unsupported `runtime.json`
  /// schema version — never silently substituting a default.
  KnowledgePackage readBytes(Uint8List bytes) {
    final MinimalZipReader zip;
    try {
      zip = MinimalZipReader(bytes);
    } on FormatException catch (e) {
      throw KnowledgeRuntimeException(
        KnowledgeRuntimeErrorCode.packageInvalid,
        'Not a valid .oerp archive: $e',
      );
    }

    for (final required in _requiredEntries) {
      if (!zip.containsEntry(required)) {
        throw KnowledgeRuntimeException(
          KnowledgeRuntimeErrorCode.packageInvalid,
          '.oerp archive is missing required member "$required".',
        );
      }
    }

    final Map<String, Object?> manifestJson;
    final Map<String, Object?> runtimeJson;
    try {
      manifestJson =
          jsonDecode(zip.readEntryAsString('manifest.json'))
              as Map<String, Object?>;
      runtimeJson =
          jsonDecode(zip.readEntryAsString('runtime.json'))
              as Map<String, Object?>;
    } on FormatException catch (e) {
      throw KnowledgeRuntimeException(
        KnowledgeRuntimeErrorCode.packageInvalid,
        'Malformed JSON in .oerp archive: $e',
      );
    }

    final schemaVersion = runtimeJson['schemaVersion'] as String?;
    if (schemaVersion == null) {
      throw const KnowledgeRuntimeException(
        KnowledgeRuntimeErrorCode.packageInvalid,
        'runtime.json is missing schemaVersion.',
      );
    }

    // A signed package (a `signature/*.sig` member instead of
    // `signature/UNSIGNED`) is intentionally not treated as verified
    // here — this reader has no Ed25519 trust-store, so it reports
    // developmentModeUnsigned=false for a signed package, which makes
    // KnowledgeRuntime.activate's "declares a signature but no
    // verification exists" refusal apply (see knowledge_runtime.dart) —
    // the same "never silently trust" property the Dart fixture path
    // already enforces.
    final isUnsigned = zip.containsEntry('signature/UNSIGNED');

    final merged = <String, Object?>{
      'manifest': {
        'packageId': manifestJson['package_id'],
        'packageName': manifestJson['package_name'],
        'packageVersion': manifestJson['version'],
        'schemaVersion': schemaVersion,
        'sourceKnowledgeVersion':
            '${manifestJson['package_id']}@${manifestJson['version']}',
        'compilerVersion': manifestJson['compiler_version'],
        'createdUtc': '${manifestJson['build_date']}T00:00:00Z',
        'publisherId': manifestJson['publisher'],
        'contentHash': null,
        'signature': isUnsigned ? null : 'present',
      },
      'dimensions': runtimeJson['dimensions'],
      'units': runtimeJson['units'],
      'componentModels': runtimeJson['componentModels'],
      'laws': runtimeJson['laws'],
      'equations': runtimeJson['equations'],
      'constraints': runtimeJson['constraints'],
      'provenance': runtimeJson['provenance'],
      'developmentModeUnsigned': isUnsigned,
    };

    try {
      return KnowledgePackage.fromJson(merged);
    } on TypeError catch (e) {
      throw KnowledgeRuntimeException(
        KnowledgeRuntimeErrorCode.packageInvalid,
        'runtime.json content does not match the expected KnowledgePackage shape: $e',
      );
    }
  }

  /// Reads a `.oerp` file from disk.
  KnowledgePackage readFile(File file) => readBytes(file.readAsBytesSync());
}
