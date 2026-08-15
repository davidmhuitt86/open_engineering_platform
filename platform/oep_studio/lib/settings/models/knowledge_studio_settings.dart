import 'settings_enums.dart';

/// Settings > Knowledge Studio (SDD-023): "Autosave, OCR Overlay,
/// Evidence Colors, Default Zoom, Context Display, Entity Display,
/// Review Preferences." Knowledge Session-scoped preferences (SDD-023
/// Knowledge Session Configuration) remain out of scope here — this
/// model holds only User Configuration-scoped *defaults* for a new
/// session, not any single session's own state.
class KnowledgeStudioSettings {
  const KnowledgeStudioSettings({
    required this.autosaveEnabled,
    required this.ocrOverlayVisibleByDefault,
    required this.highContrastEvidenceColors,
    required this.defaultZoom,
    required this.contextDisplay,
    required this.entityDisplay,
    required this.reviewSortPreference,
  });

  factory KnowledgeStudioSettings.defaults() => const KnowledgeStudioSettings(
    autosaveEnabled: true,
    ocrOverlayVisibleByDefault: true,
    highContrastEvidenceColors: false,
    defaultZoom: 1.0,
    contextDisplay: ContextDisplayMode.tree,
    entityDisplay: EntityDisplayMode.grouped,
    reviewSortPreference: ReviewSortPreference.newestFirst,
  );

  final bool autosaveEnabled;
  final bool ocrOverlayVisibleByDefault;
  final bool highContrastEvidenceColors;
  final double defaultZoom;
  final ContextDisplayMode contextDisplay;
  final EntityDisplayMode entityDisplay;
  final ReviewSortPreference reviewSortPreference;

  KnowledgeStudioSettings copyWith({
    bool? autosaveEnabled,
    bool? ocrOverlayVisibleByDefault,
    bool? highContrastEvidenceColors,
    double? defaultZoom,
    ContextDisplayMode? contextDisplay,
    EntityDisplayMode? entityDisplay,
    ReviewSortPreference? reviewSortPreference,
  }) {
    return KnowledgeStudioSettings(
      autosaveEnabled: autosaveEnabled ?? this.autosaveEnabled,
      ocrOverlayVisibleByDefault: ocrOverlayVisibleByDefault ?? this.ocrOverlayVisibleByDefault,
      highContrastEvidenceColors: highContrastEvidenceColors ?? this.highContrastEvidenceColors,
      defaultZoom: defaultZoom ?? this.defaultZoom,
      contextDisplay: contextDisplay ?? this.contextDisplay,
      entityDisplay: entityDisplay ?? this.entityDisplay,
      reviewSortPreference: reviewSortPreference ?? this.reviewSortPreference,
    );
  }

  Map<String, dynamic> toJson() => {
    'autosaveEnabled': autosaveEnabled,
    'ocrOverlayVisibleByDefault': ocrOverlayVisibleByDefault,
    'highContrastEvidenceColors': highContrastEvidenceColors,
    'defaultZoom': defaultZoom,
    'contextDisplay': contextDisplay.name,
    'entityDisplay': entityDisplay.name,
    'reviewSortPreference': reviewSortPreference.name,
  };

  factory KnowledgeStudioSettings.fromJson(Map<String, dynamic> json) {
    final defaults = KnowledgeStudioSettings.defaults();
    return KnowledgeStudioSettings(
      autosaveEnabled: json['autosaveEnabled'] as bool? ?? defaults.autosaveEnabled,
      ocrOverlayVisibleByDefault: json['ocrOverlayVisibleByDefault'] as bool? ?? defaults.ocrOverlayVisibleByDefault,
      highContrastEvidenceColors: json['highContrastEvidenceColors'] as bool? ?? defaults.highContrastEvidenceColors,
      defaultZoom: (json['defaultZoom'] as num?)?.toDouble() ?? defaults.defaultZoom,
      contextDisplay: ContextDisplayMode.values.firstWhere(
        (value) => value.name == json['contextDisplay'],
        orElse: () => defaults.contextDisplay,
      ),
      entityDisplay: EntityDisplayMode.values.firstWhere(
        (value) => value.name == json['entityDisplay'],
        orElse: () => defaults.entityDisplay,
      ),
      reviewSortPreference: ReviewSortPreference.values.firstWhere(
        (value) => value.name == json['reviewSortPreference'],
        orElse: () => defaults.reviewSortPreference,
      ),
    );
  }
}
