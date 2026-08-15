/// Validation constraints a Symbol declares about how it may be used
/// (SDD-028). Enforced by the Validation Engine, not by the Symbol itself.
class SymbolValidationRules {
  final List<String> requiredPortIds;
  final List<String> allowedConnectionTypes;
  final List<String> requiredMetadataKeys;

  const SymbolValidationRules({
    this.requiredPortIds = const [],
    this.allowedConnectionTypes = const [],
    this.requiredMetadataKeys = const [],
  });

  Map<String, Object?> toJson() => {
        'requiredPortIds': requiredPortIds,
        'allowedConnectionTypes': allowedConnectionTypes,
        'requiredMetadataKeys': requiredMetadataKeys,
      };

  factory SymbolValidationRules.fromJson(Map<String, Object?> json) {
    return SymbolValidationRules(
      requiredPortIds: List<String>.from(json['requiredPortIds'] as List? ?? const []),
      allowedConnectionTypes:
          List<String>.from(json['allowedConnectionTypes'] as List? ?? const []),
      requiredMetadataKeys:
          List<String>.from(json['requiredMetadataKeys'] as List? ?? const []),
    );
  }
}
