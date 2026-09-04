import 'dart:convert';

import 'knowledge_definitions.dart';
import 'quantity.dart';

/// Compiled Knowledge Package identity, trust state, and content
/// (AP-EK-013 §4–7, §30). This is the package the runtime activates —
/// never the Reference Library's own authoring YAML (AP-EK-001 §"the
/// runtime never reads authoring YAML").
///
/// For the first vertical slice, packages are compiled/staged locally
/// (AP-EK-020 §41 permits a local trusted package source); the package
/// *shape* — manifest identity, units, dimensions, component models,
/// laws, equations, constraints, provenance, content hash, trust state —
/// follows AP-EK-013 so that a real Reference-Compiler-produced package
/// can later be substituted without changing this contract.

/// AP-EK-013 §30 trust states.
enum PackageTrustState {
  unverified,
  hashVerified,
  signatureVerified,
  validated,
  active,
  rejected,
}

class KnowledgePackageManifest {
  final String packageId;
  final String packageName;
  final String packageVersion;
  final String schemaVersion;
  final String sourceKnowledgeVersion;
  final String compilerVersion;
  final String createdUtc;
  final String? contentHash;
  final String? signature;
  final String publisherId;

  const KnowledgePackageManifest({
    required this.packageId,
    required this.packageName,
    required this.packageVersion,
    required this.schemaVersion,
    required this.sourceKnowledgeVersion,
    required this.compilerVersion,
    required this.createdUtc,
    required this.publisherId,
    this.contentHash,
    this.signature,
  });

  Map<String, Object?> toJson() => {
    'packageId': packageId,
    'packageName': packageName,
    'packageVersion': packageVersion,
    'schemaVersion': schemaVersion,
    'sourceKnowledgeVersion': sourceKnowledgeVersion,
    'compilerVersion': compilerVersion,
    'createdUtc': createdUtc,
    'contentHash': contentHash,
    'signature': signature,
    'publisherId': publisherId,
  };

  factory KnowledgePackageManifest.fromJson(Map<String, Object?> json) =>
      KnowledgePackageManifest(
        packageId: json['packageId'] as String,
        packageName: json['packageName'] as String,
        packageVersion: json['packageVersion'] as String,
        schemaVersion: json['schemaVersion'] as String,
        sourceKnowledgeVersion: json['sourceKnowledgeVersion'] as String,
        compilerVersion: json['compilerVersion'] as String,
        createdUtc: json['createdUtc'] as String,
        publisherId: json['publisherId'] as String,
        contentHash: json['contentHash'] as String?,
        signature: json['signature'] as String?,
      );
}

/// A fully-parsed, not-yet-activated compiled knowledge package: the
/// deliverable of "Load → Parse" in AP-EK-013 §8's activation sequence.
class KnowledgePackage {
  final KnowledgePackageManifest manifest;
  final List<Dimension> dimensions;
  final List<Unit> units;
  final List<ComponentModel> componentModels;
  final List<EngineeringLaw> laws;
  final List<Equation> equations;
  final List<ConstraintDefinition> constraints;
  final List<ProvenanceRecord> provenance;

  /// Whether this package was activated in an explicit
  /// unsigned-development-mode exception (AP-EK-013 §43: "Development/
  /// test modes may permit explicitly configured unsigned packages, but
  /// that exception must be visible in runtime state").
  final bool developmentModeUnsigned;

  const KnowledgePackage({
    required this.manifest,
    required this.dimensions,
    required this.units,
    required this.componentModels,
    required this.laws,
    required this.equations,
    required this.constraints,
    required this.provenance,
    this.developmentModeUnsigned = false,
  });

  /// Canonical serialization (AP-EK-013 §27): fixed field/collection
  /// ordering (each collection sorted by id), so equivalent content
  /// always produces byte-identical JSON regardless of authoring or
  /// in-memory ordering — required for [contentHash] and reproducibility.
  Map<String, Object?> toCanonicalJson() {
    final sortedDimensions = [...dimensions]
      ..sort((a, b) => a.id.compareTo(b.id));
    final sortedUnits = [...units]..sort((a, b) => a.id.compareTo(b.id));
    final sortedModels = [...componentModels]
      ..sort((a, b) => a.id.compareTo(b.id));
    final sortedLaws = [...laws]..sort((a, b) => a.id.compareTo(b.id));
    final sortedEquations = [...equations]
      ..sort((a, b) => a.id.compareTo(b.id));
    final sortedConstraints = [...constraints]
      ..sort((a, b) => a.id.compareTo(b.id));
    final sortedProvenance = [...provenance]
      ..sort((a, b) => a.id.compareTo(b.id));
    return {
      'manifest': {
        ...manifest.toJson()
          ..remove('contentHash')
          ..remove('signature'),
      },
      'dimensions': sortedDimensions.map((d) => d.toJson()).toList(),
      'units': sortedUnits.map((u) => u.toJson()).toList(),
      'componentModels': sortedModels.map((m) => m.toJson()).toList(),
      'laws': sortedLaws.map((l) => l.toJson()).toList(),
      'equations': sortedEquations.map((e) => e.toJson()).toList(),
      'constraints': sortedConstraints.map((c) => c.toJson()).toList(),
      'provenance': sortedProvenance.map((p) => p.toJson()).toList(),
    };
  }

  /// Deterministic content hash over the canonical serialization
  /// (AP-EK-013 §28). BLAKE3 is the specified primary algorithm; this
  /// implementation uses the specified SHA-256 fallback (no BLAKE3
  /// package dependency exists yet in this repository) — disclosed as an
  /// explicit, tracked deviation in the AP-EK-020 final report.
  String computeContentHash() {
    final canonicalBytes = utf8.encode(
      jsonEncode(_sortKeysDeep(toCanonicalJson())),
    );
    return sha256Hex(canonicalBytes);
  }

  Map<String, Object?> toJson() => {
    ...toCanonicalJson(),
    'manifest': manifest.toJson(),
    'developmentModeUnsigned': developmentModeUnsigned,
  };

  factory KnowledgePackage.fromJson(
    Map<String, Object?> json,
  ) => KnowledgePackage(
    manifest: KnowledgePackageManifest.fromJson(
      Map<String, Object?>.from(json['manifest'] as Map),
    ),
    dimensions: (json['dimensions'] as List)
        .map((d) => Dimension.fromJson(Map<String, Object?>.from(d as Map)))
        .toList(),
    units: (json['units'] as List)
        .map((u) => Unit.fromJson(Map<String, Object?>.from(u as Map)))
        .toList(),
    componentModels: (json['componentModels'] as List)
        .map(
          (m) => ComponentModel.fromJson(Map<String, Object?>.from(m as Map)),
        )
        .toList(),
    laws: (json['laws'] as List)
        .map(
          (l) => EngineeringLaw.fromJson(Map<String, Object?>.from(l as Map)),
        )
        .toList(),
    equations: (json['equations'] as List)
        .map((e) => Equation.fromJson(Map<String, Object?>.from(e as Map)))
        .toList(),
    constraints: (json['constraints'] as List)
        .map(
          (c) => ConstraintDefinition.fromJson(
            Map<String, Object?>.from(c as Map),
          ),
        )
        .toList(),
    provenance: (json['provenance'] as List)
        .map(
          (p) => ProvenanceRecord.fromJson(Map<String, Object?>.from(p as Map)),
        )
        .toList(),
    developmentModeUnsigned: json['developmentModeUnsigned'] as bool? ?? false,
  );
}

Object? _sortKeysDeep(Object? value) {
  if (value is Map) {
    final sortedKeys = value.keys.map((k) => k as String).toList()..sort();
    return {for (final k in sortedKeys) k: _sortKeysDeep(value[k])};
  }
  if (value is List) {
    return value.map(_sortKeysDeep).toList();
  }
  return value;
}

/// Minimal dependency-free SHA-256 (FIPS 180-4). Kept local rather than
/// adding `package:crypto` so the knowledge-package hash requirement can
/// be satisfied without expanding the package's dependency surface for
/// the first vertical slice.
String sha256Hex(List<int> message) {
  const List<int> k = [
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5, //
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];
  var h0 = 0x6a09e667, h1 = 0xbb67ae85, h2 = 0x3c6ef372, h3 = 0xa54ff53a;
  var h4 = 0x510e527f, h5 = 0x9b05688c, h6 = 0x1f83d9ab, h7 = 0x5be0cd19;

  final ml = message.length * 8;
  final padded = List<int>.from(message)..add(0x80);
  while (padded.length % 64 != 56) {
    padded.add(0);
  }
  for (var shift = 56; shift >= 0; shift -= 8) {
    padded.add((ml >> shift) & 0xff);
  }

  int rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xffffffff;

  for (var chunkStart = 0; chunkStart < padded.length; chunkStart += 64) {
    final w = List<int>.filled(64, 0);
    for (var i = 0; i < 16; i++) {
      final o = chunkStart + i * 4;
      w[i] =
          (padded[o] << 24) |
          (padded[o + 1] << 16) |
          (padded[o + 2] << 8) |
          padded[o + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }

    var a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;
    for (var i = 0; i < 64; i++) {
      final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      final ch = (e & f) ^ ((~e & 0xffffffff) & g);
      final temp1 = (h + s1 + ch + k[i] + w[i]) & 0xffffffff;
      final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xffffffff;
      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xffffffff;
    }
    h0 = (h0 + a) & 0xffffffff;
    h1 = (h1 + b) & 0xffffffff;
    h2 = (h2 + c) & 0xffffffff;
    h3 = (h3 + d) & 0xffffffff;
    h4 = (h4 + e) & 0xffffffff;
    h5 = (h5 + f) & 0xffffffff;
    h6 = (h6 + g) & 0xffffffff;
    h7 = (h7 + h) & 0xffffffff;
  }

  return [
    h0,
    h1,
    h2,
    h3,
    h4,
    h5,
    h6,
    h7,
  ].map((v) => v.toRadixString(16).padLeft(8, '0')).join();
}
