import 'dart:typed_data';

import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/services.dart' show rootBundle;

/// AP-EK-020 (packaging finalization) — the one seam between "where the
/// electrical-core [KnowledgePackage] comes from" and everything that
/// consumes it ([electricalCoreRuntimeProvider]). Deliberately the
/// smallest abstraction that lets production and tests diverge: a single
/// async method, no generalized dependency-injection framework.
///
/// **Production → [AssetKnowledgePackageSource]** (a bundled, compiled
/// `.oerp`, read through the real [OerpReader]). **Unit tests → a fixture
/// implementation** may stand in wherever a test needs a
/// [KnowledgePackage] without Flutter's asset-loading machinery — see
/// `test/diagram_studio/analysis/knowledge_package_source_test.dart`.
/// Production code must never depend on
/// `buildElectricalCorePackage()` (the Dart fixture,
/// `engineering_engine`'s own test infrastructure — see its own updated
/// doc comment) — this abstraction is what makes that boundary
/// structural rather than a convention someone could quietly violate.
abstract class KnowledgePackageSource {
  Future<KnowledgePackage> loadElectricalCorePackage();
}

/// The production source: reads the compiled `.oerp` Flutter bundles as
/// an ordinary asset (`pubspec.yaml`'s `assets:` — see that file's own
/// comment for why the compiled package can't be referenced directly out
/// of `knowledge/reference_library/dist/`, and
/// `tool/generate_knowledge_asset.dart` for how it gets staged into
/// `assets/knowledge/` before every `flutter run`/`flutter build`).
///
/// Fails explicitly (a real [KnowledgeRuntimeException], not a caught-
/// and-swallowed error) if the asset is missing or malformed — this is
/// the one place a packaging failure (the generator script was never
/// run, or produced something [OerpReader] can't parse) surfaces as a
/// loud, diagnosable error instead of silently falling back to the Dart
/// fixture, which would hide the failure and quietly reintroduce two
/// competing knowledge authorities (§ AP-EK-020's own "no production
/// shortcut" principle).
class AssetKnowledgePackageSource implements KnowledgePackageSource {
  const AssetKnowledgePackageSource({this.assetPath = defaultAssetPath});

  static const defaultAssetPath = 'assets/knowledge/core_reference_v1.oerp';

  /// Overridable only so a test can point at a deliberately-nonexistent
  /// path to exercise the missing-asset failure path (§
  /// `knowledge_package_source_test.dart`) without needing to delete the
  /// real, developer-generated asset out from under every other test.
  /// Production always uses [defaultAssetPath] (the constructor default)
  /// — nothing in `main.dart`/the provider graph ever passes a different
  /// value.
  final String assetPath;

  @override
  Future<KnowledgePackage> loadElectricalCorePackage() async {
    final ByteData data;
    try {
      data = await rootBundle.load(assetPath);
    } catch (error) {
      throw KnowledgeRuntimeException(
        KnowledgeRuntimeErrorCode.packageNotFound,
        'Knowledge package asset "$assetPath" could not be loaded — run '
        '`dart run tool/generate_knowledge_asset.dart` from '
        'platform/oep_studio (compiles the Reference Library into this '
        'asset), then rebuild. Underlying error: $error',
      );
    }
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    // OerpReader itself already throws KnowledgeRuntimeException
    // (packageInvalid) for anything structurally wrong with the archive
    // — deliberately not caught/rewrapped here, so that specific error
    // code/message reaches the caller unchanged.
    return const OerpReader().readBytes(bytes);
  }
}
