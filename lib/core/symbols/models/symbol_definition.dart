import 'symbol_category.dart';
import 'symbol_geometry.dart';
import 'symbol_port.dart';
import 'symbol_rendering_metadata.dart';
import 'symbol_validation_rules.dart';

/// A data-driven Engineering Symbol definition (SDD-028).
///
/// "Symbols are data. Never code." Every field here is authored as JSON
/// under `assets/symbols/` — there are no hardcoded symbol classes.
class SymbolDefinition {
  final String identifier;
  final String name;
  final SymbolCategory category;
  final String description;
  final List<String> aliases;
  final List<SymbolStandard> standards;
  final SymbolGeometry geometry;
  final List<SymbolPort> ports;
  final SymbolRenderingMetadata rendering;
  final SymbolValidationRules validationRules;

  const SymbolDefinition({
    required this.identifier,
    required this.name,
    required this.category,
    this.description = '',
    this.aliases = const [],
    this.standards = const [],
    required this.geometry,
    this.ports = const [],
    this.rendering = const SymbolRenderingMetadata(),
    this.validationRules = const SymbolValidationRules(),
  });

  /// The synthetic definition used whenever a node references a symbol id
  /// the library does not recognize (SDD-028: "Unknown Symbols remain
  /// valid... preserve evidence... may later be classified.").
  factory SymbolDefinition.unknown(String identifier) => SymbolDefinition(
        identifier: identifier,
        name: 'Unknown Symbol ($identifier)',
        category: SymbolCategory.general,
        description: 'No symbol definition registered for "$identifier".',
        geometry: const SymbolGeometry(
          kind: GeometryKind.svgAsset,
          assetPath: 'assets/symbols/generic_module.svg',
        ),
      );

  Map<String, Object?> toJson() => {
        'identifier': identifier,
        'name': name,
        'category': category.name,
        'description': description,
        'aliases': aliases,
        'standards': standards.map((s) => s.name).toList(),
        'geometry': geometry.toJson(),
        'ports': ports.map((p) => p.toJson()).toList(),
        'rendering': rendering.toJson(),
        'validationRules': validationRules.toJson(),
      };

  factory SymbolDefinition.fromJson(Map<String, Object?> json) {
    return SymbolDefinition(
      identifier: json['identifier'] as String,
      name: json['name'] as String,
      category: SymbolCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => SymbolCategory.general,
      ),
      description: json['description'] as String? ?? '',
      aliases: List<String>.from(json['aliases'] as List? ?? const []),
      standards: (json['standards'] as List? ?? const [])
          .map((s) => SymbolStandard.values.firstWhere(
                (v) => v.name == s,
                orElse: () => SymbolStandard.custom,
              ))
          .toList(),
      geometry:
          SymbolGeometry.fromJson(Map<String, Object?>.from(json['geometry'] as Map)),
      ports: (json['ports'] as List? ?? const [])
          .map((p) => SymbolPort.fromJson(Map<String, Object?>.from(p as Map)))
          .toList(),
      rendering: json['rendering'] == null
          ? const SymbolRenderingMetadata()
          : SymbolRenderingMetadata.fromJson(
              Map<String, Object?>.from(json['rendering'] as Map)),
      validationRules: json['validationRules'] == null
          ? const SymbolValidationRules()
          : SymbolValidationRules.fromJson(
              Map<String, Object?>.from(json['validationRules'] as Map)),
    );
  }
}
