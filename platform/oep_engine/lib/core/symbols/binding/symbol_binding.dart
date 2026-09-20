import 'dart:convert';
import 'dart:io';

import '../../interfaces/symbol_provider.dart';
import '../../knowledge/knowledge_runtime.dart';
import '../../knowledge/knowledge_runtime_errors.dart';
import '../../knowledge/models/knowledge_definitions.dart';
import '../models/symbol_definition.dart';

/// Symbol Binding contract (WP-EKE-016).
///
/// ```text
/// Reference Symbol ID   (e.g. symbol.iec.resistor)  = reference / engineering meaning
/// Engine symbol id      (e.g. resistor)              = rendering definition
/// Symbol Binding                                     = explicit integration mapping
/// ```
///
/// **`Reference Symbol ID != SymbolDefinition.identifier`** unless an explicit
/// binding here says so. Nothing is inferred from names, prefixes, case,
/// aliases, file names or similarity. A binding is an integration fact, not
/// reference knowledge and not rendering data, so it lives in its own
/// declarative artifact (`assets/symbol_bindings/`), not in the Reference
/// Library, the compiled package, or `SymbolDefinition`.
///
/// Direction is Reference -> Engine only. There is deliberately no
/// Engine -> Reference lookup: an Engine definition must never become a route
/// to (or a source of) reference knowledge.

/// Why a binding could not be established or resolved.
enum SymbolBindingErrorCode {
  /// The Reference Symbol id is not in the active `KnowledgeRuntime`.
  referenceSymbolNotFound,

  /// The Reference object exists but its `objectType` is not `Symbol`.
  referenceObjectNotSymbol,

  /// The Reference Symbol has no explicit binding.
  bindingMissing,

  /// The bound Engine symbol is not registered in the `SymbolProvider`.
  engineSymbolNotFound,

  /// A Reference id (or an Engine id) participates in more than one binding.
  ambiguousBinding,

  /// Malformed binding data, an unsupported binding-file version, or a
  /// binding whose Engine id only resolves through an alias.
  invalidBinding,
}

class SymbolBindingException implements Exception {
  final SymbolBindingErrorCode code;
  final String message;

  const SymbolBindingException(this.code, this.message);

  @override
  String toString() => 'SymbolBindingException(${code.name}): $message';
}

/// One explicit Reference Symbol -> Engine symbol binding.
///
/// Cardinality (current requirement): one Reference Symbol binds to exactly
/// one Engine `SymbolDefinition`, and an Engine definition serves at most one
/// Reference Symbol. Renderer profiles (screen/print/alternate standard) do
/// not exist in the repository today and are not modelled; adding one later
/// is an additive change to this file format.
class SymbolBinding {
  final String referenceSymbolId;

  /// Exactly `SymbolDefinition.identifier` (an alias does not qualify).
  final String engineSymbolId;

  /// Free-text rationale or caveat; never interpreted.
  final String notes;

  const SymbolBinding({
    required this.referenceSymbolId,
    required this.engineSymbolId,
    this.notes = '',
  });

  Map<String, Object?> toJson() => {
    'referenceSymbolId': referenceSymbolId,
    'engineSymbolId': engineSymbolId,
    if (notes.isNotEmpty) 'notes': notes,
  };

  @override
  bool operator ==(Object other) =>
      other is SymbolBinding &&
      other.referenceSymbolId == referenceSymbolId &&
      other.engineSymbolId == engineSymbolId &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(referenceSymbolId, engineSymbolId, notes);
}

/// The validated, immutable set of explicit bindings.
class SymbolBindingRegistry {
  /// The only binding-file `version` understood.
  static const int supportedVersion = 1;

  final List<SymbolBinding> bindings;
  final Map<String, SymbolBinding> _byReferenceId;

  SymbolBindingRegistry._(this.bindings, this._byReferenceId);

  /// Validates [bindings]: non-empty exact ids, no reference id bound twice,
  /// no Engine id bound to two reference ids. Ambiguity is an error, never a
  /// silent "last wins".
  factory SymbolBindingRegistry(List<SymbolBinding> bindings) {
    final byReference = <String, SymbolBinding>{};
    final byEngine = <String, SymbolBinding>{};
    for (final b in bindings) {
      for (final id in [b.referenceSymbolId, b.engineSymbolId]) {
        if (id.isEmpty || id != id.trim()) {
          throw SymbolBindingException(
            SymbolBindingErrorCode.invalidBinding,
            'Binding ids must be non-empty and exact (no surrounding '
            'whitespace): "${b.referenceSymbolId}" -> "${b.engineSymbolId}".',
          );
        }
      }
      final existingRef = byReference[b.referenceSymbolId];
      if (existingRef != null) {
        throw SymbolBindingException(
          SymbolBindingErrorCode.ambiguousBinding,
          'Reference symbol "${b.referenceSymbolId}" is bound more than once '
          '(to "${existingRef.engineSymbolId}" and "${b.engineSymbolId}").',
        );
      }
      final existingEngine = byEngine[b.engineSymbolId];
      if (existingEngine != null) {
        throw SymbolBindingException(
          SymbolBindingErrorCode.ambiguousBinding,
          'Engine symbol "${b.engineSymbolId}" is bound to more than one '
          'Reference symbol ("${existingEngine.referenceSymbolId}" and '
          '"${b.referenceSymbolId}").',
        );
      }
      byReference[b.referenceSymbolId] = b;
      byEngine[b.engineSymbolId] = b;
    }
    final sorted = [...bindings]
      ..sort((a, b) => a.referenceSymbolId.compareTo(b.referenceSymbolId));
    return SymbolBindingRegistry._(
      List.unmodifiable(sorted),
      Map.unmodifiable(byReference),
    );
  }

  const SymbolBindingRegistry.empty()
    : bindings = const [],
      _byReferenceId = const {};

  /// Parses the binding file:
  /// `{"version": 1, "bindings": [{"referenceSymbolId": ..., "engineSymbolId": ..., "notes"?: ...}]}`.
  factory SymbolBindingRegistry.parse(String json) {
    Never invalid(String detail) => throw SymbolBindingException(
      SymbolBindingErrorCode.invalidBinding,
      'Symbol binding file is malformed: $detail',
    );
    final Object? root;
    try {
      root = jsonDecode(json);
    } on FormatException catch (e) {
      invalid('not valid JSON ($e)');
    }
    if (root is! Map<String, Object?>) invalid('top level is not an object');
    final version = root['version'];
    if (version is! int) invalid('missing integer "version"');
    if (version != supportedVersion) {
      invalid('unsupported version $version (supported: $supportedVersion)');
    }
    final raw = root['bindings'];
    if (raw is! List) invalid('missing "bindings" list');
    final parsed = <SymbolBinding>[];
    for (final entry in raw) {
      if (entry is! Map<String, Object?>) invalid('a binding is not an object');
      final ref = entry['referenceSymbolId'];
      final engine = entry['engineSymbolId'];
      final notes = entry['notes'];
      if (ref is! String || engine is! String) {
        invalid('a binding lacks string referenceSymbolId/engineSymbolId');
      }
      if (notes != null && notes is! String) invalid('"notes" must be a string');
      parsed.add(
        SymbolBinding(
          referenceSymbolId: ref,
          engineSymbolId: engine,
          notes: (notes as String?) ?? '',
        ),
      );
    }
    return SymbolBindingRegistry(parsed);
  }

  factory SymbolBindingRegistry.loadFile(File file) {
    if (!file.existsSync()) {
      throw SymbolBindingException(
        SymbolBindingErrorCode.invalidBinding,
        'Symbol binding file not found: ${file.path}',
      );
    }
    return SymbolBindingRegistry.parse(file.readAsStringSync());
  }

  /// The explicit binding for [referenceSymbolId], or `null`. Exact match
  /// only.
  SymbolBinding? lookup(String referenceSymbolId) =>
      _byReferenceId[referenceSymbolId];
}

/// The result of a successful resolution. Both identities are preserved and
/// never collapsed.
///
/// [referenceSymbol] is authoritative knowledge as exposed by
/// `KnowledgeRuntime` (identity, name, classification tags, provenance id);
/// [engineSymbol] is the renderer's definition, including its own
/// renderer-local port geometry. Neither is copied into the other, and no
/// Engineering Graph node or port is created or changed.
class ResolvedSymbolBinding {
  final SymbolBinding binding;
  final KnowledgeObject referenceSymbol;
  final SymbolDefinition engineSymbol;

  const ResolvedSymbolBinding({
    required this.binding,
    required this.referenceSymbol,
    required this.engineSymbol,
  });

  String get referenceSymbolId => referenceSymbol.id;
  String get engineSymbolId => engineSymbol.identifier;
}

/// One binding that does not currently resolve (see
/// [SymbolBindingAdapter.audit]).
class SymbolBindingIssue {
  final String referenceSymbolId;
  final SymbolBindingErrorCode code;
  final String message;

  const SymbolBindingIssue(this.referenceSymbolId, this.code, this.message);
}

/// Resolves a Reference Symbol to its Engine `SymbolDefinition` through the
/// authoritative `KnowledgeRuntime`, the existing `SymbolProvider` and an
/// explicit [SymbolBindingRegistry]. It reads no package/index/YAML data,
/// builds no registry of its own, creates no symbol, and never falls back to
/// a similar symbol.
class SymbolBindingAdapter {
  final KnowledgeRuntime runtime;
  final SymbolProvider symbols;
  final SymbolBindingRegistry bindings;

  const SymbolBindingAdapter({
    required this.runtime,
    required this.symbols,
    required this.bindings,
  });

  /// The `objectType` a Reference object must have to be bound.
  static const String symbolObjectType = 'Symbol';

  /// Resolves [referenceSymbolId]. Checks, in order: the object exists in the
  /// runtime, is a Symbol, has an explicit binding, and the bound Engine
  /// definition exists under exactly that identifier. Throws
  /// [SymbolBindingException] otherwise; an unknown symbol is never turned
  /// into a fabricated one (`SymbolProvider.resolve`'s "unknown" fallback is
  /// intentionally not used).
  ResolvedSymbolBinding resolve(String referenceSymbolId) {
    final KnowledgeObject referenceSymbol;
    try {
      referenceSymbol = runtime.getObject(referenceSymbolId);
    } on KnowledgeRuntimeException catch (e) {
      if (e.code != KnowledgeRuntimeErrorCode.referenceNotFound) rethrow;
      throw SymbolBindingException(
        SymbolBindingErrorCode.referenceSymbolNotFound,
        'No Reference object "$referenceSymbolId" in the active knowledge '
        'package.',
      );
    }
    if (referenceSymbol.objectType != symbolObjectType) {
      throw SymbolBindingException(
        SymbolBindingErrorCode.referenceObjectNotSymbol,
        'Reference object "$referenceSymbolId" is a '
        '"${referenceSymbol.objectType}", not a $symbolObjectType.',
      );
    }
    final binding = bindings.lookup(referenceSymbolId);
    if (binding == null) {
      throw SymbolBindingException(
        SymbolBindingErrorCode.bindingMissing,
        'Reference symbol "$referenceSymbolId" has no explicit Engine symbol '
        'binding; none is inferred.',
      );
    }
    final engineSymbol = symbols.lookup(binding.engineSymbolId);
    if (engineSymbol == null) {
      throw SymbolBindingException(
        SymbolBindingErrorCode.engineSymbolNotFound,
        'Reference symbol "$referenceSymbolId" is bound to Engine symbol '
        '"${binding.engineSymbolId}", which is not registered.',
      );
    }
    // SymbolProvider.lookup also matches aliases; a binding must name the
    // definition's own identifier.
    if (engineSymbol.identifier != binding.engineSymbolId) {
      throw SymbolBindingException(
        SymbolBindingErrorCode.invalidBinding,
        'Binding target "${binding.engineSymbolId}" only matches Engine '
        'symbol "${engineSymbol.identifier}" through an alias; bindings must '
        'name the identifier exactly.',
      );
    }
    return ResolvedSymbolBinding(
      binding: binding,
      referenceSymbol: referenceSymbol,
      engineSymbol: engineSymbol,
    );
  }

  /// Every registered binding that does not resolve against the active
  /// package and Engine symbols, in binding order. Empty means all resolve.
  /// (Bindings for symbols of a package that is not active are reported as
  /// `referenceSymbolNotFound`; that is information, not a failure.)
  List<SymbolBindingIssue> audit() {
    final issues = <SymbolBindingIssue>[];
    for (final b in bindings.bindings) {
      try {
        resolve(b.referenceSymbolId);
      } on SymbolBindingException catch (e) {
        issues.add(SymbolBindingIssue(b.referenceSymbolId, e.code, e.message));
      }
    }
    return List.unmodifiable(issues);
  }
}
