import '../models/engineering_entity_type.dart';
import '../models/engineering_pattern.dart';

/// The Engineering Pattern Library (Work Package 014
/// STUDIO-TASK-000040): "Centralize deterministic engineering
/// recognition rules... Patterns shall be configurable. No hardcoded
/// UI logic." A static, data-driven list of [EngineeringPattern]s — the
/// *only* place regex patterns for entity recognition live. Widgets
/// never construct or reference a pattern directly; only
/// `EngineeringEntityExtractionService` reads from this library, and
/// the Property Inspector only ever looks a pattern up by the id an
/// already-extracted [EngineeringEntity] recorded.
///
/// "Initial Pattern Categories" (STUDIO-TASK-000040's own list) names
/// eleven categories; STUDIO-TASK-000038's "Detect" list names
/// fourteen entity types to "Support recognition of." This library
/// implements all fourteen — the eleven named categories plus
/// Dimensions, Tool References, Fluid Specifications, and Connector
/// Identifiers — reading "Initial" as an illustrative starting subset
/// of a still-growing list, not a hard cap on this work package's own
/// "Support recognition of" requirement. See
/// `docs/ENGINEERING_ENTITY_EXTRACTION.md` § Pattern Library.
abstract final class EngineeringPatternLibrary {
  static final List<EngineeringPattern> patterns = [
    // --- Torque Specifications ---
    EngineeringPattern(
      id: 'torque-metric',
      type: EngineeringEntityType.torqueSpecification,
      label: 'Torque (Metric)',
      regex: RegExp(r'\b\d+(?:\.\d+)?\s*N[\s.·]?m\b', caseSensitive: false),
      normalize: (text) => '${_leadingNumber(text)} Nm',
    ),
    EngineeringPattern(
      id: 'torque-imperial',
      type: EngineeringEntityType.torqueSpecification,
      label: 'Torque (Imperial)',
      regex: RegExp(r'\b\d+(?:\.\d+)?\s*(?:ft[\s.-]?lbs?|lbs?[\s.-]?ft|in[\s.-]?lbs?|lbs?[\s.-]?in)\b', caseSensitive: false),
      normalize: (text) {
        final unit = text.toLowerCase().contains('ft') ? 'ft-lb' : 'in-lb';
        return '${_leadingNumber(text)} $unit';
      },
    ),

    // --- Voltage Values ---
    EngineeringPattern(
      id: 'voltage',
      type: EngineeringEntityType.voltageValue,
      label: 'Voltage',
      regex: RegExp(r'\b\d+(?:\.\d+)?\s*[km]?V(?:AC|DC)?\b'),
      normalize: (text) {
        final match = RegExp(r'([km])?V(AC|DC)?$').firstMatch(text);
        final prefix = match?.group(1) ?? '';
        final suffix = match?.group(2) ?? '';
        return '${_leadingNumber(text)} ${prefix}V$suffix';
      },
    ),

    // --- Resistance Values ---
    EngineeringPattern(
      id: 'resistance',
      type: EngineeringEntityType.resistanceValue,
      label: 'Resistance',
      // Trailing `(?!\w)` rather than `\b`: Ω is not an ASCII word character,
      // so `\b` never matches between it and end-of-string/whitespace.
      regex: RegExp(r'\b\d+(?:\.\d+)?\s*(?:[kM]?(?:Ω|ohms?))(?!\w)', caseSensitive: false),
      normalize: (text) {
        final prefixMatch = RegExp(r'([kM])(?:Ω|ohms?)$', caseSensitive: false).firstMatch(text);
        final prefix = prefixMatch?.group(1) ?? '';
        return '${_leadingNumber(text)} $prefixΩ';
      },
    ),

    // --- Pressure Values ---
    EngineeringPattern(
      id: 'pressure',
      type: EngineeringEntityType.pressureValue,
      label: 'Pressure',
      regex: RegExp(r'\b\d+(?:\.\d+)?\s*(?:psi|bar|kPa)\b', caseSensitive: false),
      normalize: (text) {
        final lower = text.toLowerCase();
        final unit = lower.contains('psi') ? 'psi' : (lower.contains('bar') ? 'bar' : 'kPa');
        return '${_leadingNumber(text)} $unit';
      },
    ),

    // --- Temperature Values ---
    EngineeringPattern(
      id: 'temperature',
      type: EngineeringEntityType.temperatureValue,
      label: 'Temperature',
      regex: RegExp(r'-?\d+(?:\.\d+)?\s*°?\s*[CF]\b'),
      normalize: (text) {
        final unit = text.trim().substring(text.trim().length - 1).toUpperCase();
        final numberMatch = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(text);
        return '${numberMatch?.group(0) ?? text} °$unit';
      },
    ),

    // --- Dimensions ---
    EngineeringPattern(
      id: 'dimension-metric',
      type: EngineeringEntityType.dimension,
      label: 'Dimension (Metric)',
      regex: RegExp(r'\b\d+(?:\.\d+)?\s*(?:mm|cm)\b', caseSensitive: false),
      normalize: (text) {
        final unit = text.toLowerCase().contains('cm') ? 'cm' : 'mm';
        return '${_leadingNumber(text)} $unit';
      },
    ),
    EngineeringPattern(
      id: 'dimension-imperial',
      type: EngineeringEntityType.dimension,
      label: 'Dimension (Imperial)',
      regex: RegExp(r'\b\d+/\d+\s*(?:in\b|")|\b\d+(?:\.\d+)?\s*(?:in\b|")'),
      normalize: (text) => '${text.replaceAll('"', '').replaceAll(RegExp(r'\s*in\b', caseSensitive: false), '').trim()} in',
    ),

    // --- Fastener Sizes ---
    EngineeringPattern(
      id: 'fastener-metric',
      type: EngineeringEntityType.fastenerSize,
      label: 'Fastener (Metric Thread)',
      regex: RegExp(r'\bM\d+(?:\.\d+)?(?:[xX]\d+(?:\.\d+)?)?\b'),
      normalize: (text) => text.trim().toUpperCase(),
    ),
    EngineeringPattern(
      id: 'fastener-sae',
      type: EngineeringEntityType.fastenerSize,
      label: 'Fastener (SAE)',
      regex: RegExp(r'\b\d+/\d+-\d+\s*(?:UNC|UNF)?\b', caseSensitive: false),
      normalize: (text) => text.trim().toUpperCase(),
    ),

    // --- Part Numbers ---
    EngineeringPattern(
      id: 'part-number',
      type: EngineeringEntityType.partNumber,
      label: 'Part Number',
      regex: RegExp(r'\b(?=[A-Z0-9]*\d)[A-Z0-9]{4,8}-[A-Z0-9]{3,8}\b'),
      normalize: (text) => text.trim().toUpperCase(),
    ),

    // --- Tool References ---
    EngineeringPattern(
      id: 'tool-torx',
      type: EngineeringEntityType.toolReference,
      label: 'Tool (Torx)',
      regex: RegExp(r'\bT-?\d{1,2}\b'),
      normalize: (text) => 'T${RegExp(r'\d{1,2}').firstMatch(text)?.group(0) ?? ''}',
    ),
    EngineeringPattern(
      id: 'tool-socket',
      type: EngineeringEntityType.toolReference,
      label: 'Tool (Socket/Hex)',
      regex: RegExp(r'\b\d+(?:\.\d+)?\s*mm\s+(?:Socket|Hex)\b', caseSensitive: false),
      normalize: (text) => text.trim().replaceAll(RegExp(r'\s+'), ' '),
    ),

    // --- Fluid Specifications ---
    EngineeringPattern(
      id: 'fluid-sae',
      type: EngineeringEntityType.fluidSpecification,
      label: 'Fluid (SAE Viscosity)',
      regex: RegExp(r'\bSAE\s?\d{1,2}W-?\d{1,2}\b', caseSensitive: false),
      normalize: (text) => text.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' '),
    ),
    EngineeringPattern(
      id: 'fluid-dot',
      type: EngineeringEntityType.fluidSpecification,
      label: 'Fluid (DOT Brake)',
      regex: RegExp(r'\bDOT\s?[345]\b', caseSensitive: false),
      normalize: (text) => text.trim().toUpperCase(),
    ),
    EngineeringPattern(
      id: 'fluid-atf',
      type: EngineeringEntityType.fluidSpecification,
      label: 'Fluid (ATF)',
      regex: RegExp(r'\bATF\b(?:\s+Type\s+[A-Z0-9]+)?', caseSensitive: false),
      normalize: (text) => text.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase(),
    ),

    // --- Fuse Ratings ---
    EngineeringPattern(
      id: 'fuse-rating',
      type: EngineeringEntityType.fuseRating,
      label: 'Fuse Rating',
      regex: RegExp(r'\b\d{1,3}\s?A\b'),
      normalize: (text) => '${_leadingNumber(text)} A',
    ),

    // --- Connector Identifiers ---
    EngineeringPattern(
      id: 'connector-code',
      type: EngineeringEntityType.connectorIdentifier,
      label: 'Connector (Code)',
      regex: RegExp(r'\b[A-Z]\d{1,4}\b'),
      normalize: (text) => text.trim().toUpperCase(),
    ),
    EngineeringPattern(
      id: 'connector-pin',
      type: EngineeringEntityType.connectorIdentifier,
      label: 'Connector (Pin)',
      regex: RegExp(r'\bPin\s?\d{1,3}\b', caseSensitive: false),
      normalize: (text) => 'Pin ${RegExp(r'\d{1,3}').firstMatch(text)?.group(0) ?? ''}',
    ),

    // --- Wire Colors ---
    EngineeringPattern(
      id: 'wire-color',
      type: EngineeringEntityType.wireColor,
      label: 'Wire Color',
      regex: RegExp(
        r'\b(?:Red|Black|White|Blue|Green|Yellow|Orange|Brown|Gray|Grey|Purple|Violet|Pink|Tan|BLK|WHT|BLU|GRN|YEL|ORN|BRN|GRY|PPL|VIO|PNK)\b',
        caseSensitive: false,
      ),
      normalize: _normalizeWireColor,
    ),

    // --- Wire Gauges ---
    EngineeringPattern(
      id: 'wire-gauge',
      type: EngineeringEntityType.wireGauge,
      label: 'Wire Gauge (AWG)',
      regex: RegExp(r'\b\d{1,2}\s?(?:AWG|GA)\b', caseSensitive: false),
      normalize: (text) {
        final unit = text.toLowerCase().contains('awg') ? 'AWG' : 'GA';
        return '${_leadingNumber(text)} $unit';
      },
    ),
  ];

  static List<EngineeringPattern> patternsFor(EngineeringEntityType type) =>
      patterns.where((pattern) => pattern.type == type).toList();

  static EngineeringPattern? byId(String id) {
    for (final pattern in patterns) {
      if (pattern.id == id) return pattern;
    }
    return null;
  }

  static String _leadingNumber(String text) => RegExp(r'-?\d+(?:\.\d+)?').firstMatch(text)?.group(0) ?? text.trim();

  static const _colorNames = {
    'red': 'Red',
    'black': 'Black',
    'blk': 'Black',
    'white': 'White',
    'wht': 'White',
    'blue': 'Blue',
    'blu': 'Blue',
    'green': 'Green',
    'grn': 'Green',
    'yellow': 'Yellow',
    'yel': 'Yellow',
    'orange': 'Orange',
    'orn': 'Orange',
    'brown': 'Brown',
    'brn': 'Brown',
    'gray': 'Gray',
    'grey': 'Gray',
    'gry': 'Gray',
    'purple': 'Purple',
    'violet': 'Purple',
    'ppl': 'Purple',
    'vio': 'Purple',
    'pink': 'Pink',
    'pnk': 'Pink',
    'tan': 'Tan',
  };

  static String _normalizeWireColor(String text) => _colorNames[text.trim().toLowerCase()] ?? text.trim();
}
