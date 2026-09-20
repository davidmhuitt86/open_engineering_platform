import 'evidence_annotation_status.dart';
import 'evidence_origin.dart';

/// One free-form observation about a region: a stable machine-readable
/// [key], its [value], and optionally how to read it ([valueType]) and a
/// [unit] (WP-INGEST-013).
///
/// Deliberately tiny. There is no validation engine, no unit conversion,
/// no enumerations, no ontology-defined types, and no confidence -- and
/// no canonical vocabulary of keys: an engineer may create any key. The
/// eventual domain vocabulary (wires, connectors, pins, ...) is to be
/// *discovered* from real annotation work first, not defined here.
class AnnotationProperty {
  const AnnotationProperty({
    required this.key,
    this.value = '',
    this.valueType = valueTypeText,
    this.unit,
    this.source,
  });

  /// The small initial set of value types. Purely a hint for how [value]
  /// should be read -- nothing validates [value] against it.
  static const String valueTypeText = 'text';
  static const String valueTypeNumber = 'number';
  static const String valueTypeBoolean = 'boolean';
  static const List<String> valueTypes = [
    valueTypeText,
    valueTypeNumber,
    valueTypeBoolean
  ];

  /// Stable, machine-readable identity, e.g. `part_number`. Always the
  /// output of [normalizeKey] when produced through the editing paths.
  final String key;
  final String value;

  /// `null` is read as [valueTypeText].
  final String? valueType;
  final String? unit;

  /// Optional provenance of this one value (e.g. `"human"`, a model
  /// identity, an OCR run). Free-form; nothing interprets it.
  final String? source;

  /// Typed reads over the string [value]; `null` when it does not parse.
  /// The persisted form stays the string -- these never mutate it.
  double? get numericValue => double.tryParse(value.trim());
  bool? get booleanValue {
    switch (value.trim().toLowerCase()) {
      case 'true':
        return true;
      case 'false':
        return false;
    }
    return null;
  }

  /// `"Part Number"` -> `"part_number"`: lower-case, runs of anything
  /// that is not a letter/digit collapsed to one underscore, no leading
  /// or trailing underscore. The UI may show a friendlier label, but the
  /// persisted identity is this stable form.
  static String normalizeKey(String raw) {
    final lowered = raw.trim().toLowerCase();
    final collapsed = lowered.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return collapsed.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  AnnotationProperty copyWith(
      {String? key,
      String? value,
      String? valueType,
      String? unit,
      String? source,
      bool clearUnit = false}) {
    return AnnotationProperty(
      key: key ?? this.key,
      value: value ?? this.value,
      valueType: valueType ?? this.valueType,
      unit: clearUnit ? null : (unit ?? this.unit),
      source: source ?? this.source,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AnnotationProperty &&
      other.key == key &&
      other.value == value &&
      other.valueType == valueType &&
      other.unit == unit &&
      other.source == source;

  @override
  int get hashCode => Object.hash(key, value, valueType, unit, source);

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        'valueType': valueType,
        'unit': unit,
        if (source != null) 'source': source,
      };

  factory AnnotationProperty.fromJson(Map<String, dynamic> json) {
    return AnnotationProperty(
      key: json['key'] as String,
      value: json['value'] as String? ?? '',
      valueType: json['valueType'] as String?,
      unit: json['unit'] as String?,
      source: json['source'] as String?,
    );
  }
}

/// WP-INGEST-013: what an engineer has recorded about *what a region is*
/// beyond its spatial evidence -- "`EvidenceRegion` answers WHERE;
/// annotation answers WHAT and WHAT IS KNOWN ABOUT IT."
///
/// Carried by an `EvidenceRegion` as one optional payload (absent on
/// every region saved before this work package, and on any region nobody
/// has added a property to), so it lives, is saved, reloaded, and is
/// deleted with the region through the existing Knowledge Session path --
/// no second persistence mechanism. Its [id] is minted once and never
/// changes on later edits.
///
/// The universal fields are not duplicated here: **Type** and **Name**
/// remain the region's classification label (`"<Type>: <name>"`, WP-012)
/// and **Description / Notes** remain `EvidenceRegion.notes`. This class
/// adds only what did not exist: the open-ended [properties] list.
///
/// A `KnowledgeCandidate` is *not* a copy of this: the candidate is the
/// proposed engineering entity derived from the observation and is linked
/// to the region by an `EvidenceLink`; properties stay with the human
/// observation and are never turned into Repository fields automatically.
class EvidenceAnnotation {
  const EvidenceAnnotation({
    required this.id,
    this.properties = const [],
    this.type,
    this.name,
    this.description,
    this.origin,
    this.authorId,
    this.status,
    this.regionId,
  });

  final String id;
  final List<AnnotationProperty> properties;

  /// INGEST-012 Observation universal fields -- all optional so one shape
  /// holds an unclassified human annotation, a classified one, a machine
  /// observation and a future LLM observation without schema changes.
  ///
  /// A free-form type name: usually a `KnowledgeCandidateType.name`
  /// (`component`, `text`, ...), but any string (e.g. `wire`) is valid --
  /// the vocabulary is not frozen here.
  final String? type;
  final String? name;
  final String? description;

  /// Who/what produced this observation ([EvidenceOrigin.human],
  /// [EvidenceOrigin.machine], [EvidenceOrigin.llm]); `null` = unrecorded.
  final EvidenceOrigin? origin;

  /// Annotator identity, or (later) a model identity/version.
  final String? authorId;
  final EvidenceAnnotationStatus? status;

  /// Provenance: the `EvidenceRegion.id` this observation interprets.
  final String? regionId;

  EvidenceAnnotation copyWith({
    List<AnnotationProperty>? properties,
    String? type,
    String? name,
    String? description,
    EvidenceOrigin? origin,
    String? authorId,
    EvidenceAnnotationStatus? status,
    String? regionId,
  }) =>
      EvidenceAnnotation(
        id: id,
        properties: properties ?? this.properties,
        type: type ?? this.type,
        name: name ?? this.name,
        description: description ?? this.description,
        origin: origin ?? this.origin,
        authorId: authorId ?? this.authorId,
        status: status ?? this.status,
        regionId: regionId ?? this.regionId,
      );

  EvidenceAnnotation withPropertyAdded(AnnotationProperty property) =>
      copyWith(properties: [...properties, property]);

  /// Replaces the property at [index]. A no-op for an out-of-range index.
  EvidenceAnnotation withPropertyUpdated(
      int index, AnnotationProperty property) {
    if (index < 0 || index >= properties.length) return this;
    final next = [...properties];
    next[index] = property;
    return copyWith(properties: next);
  }

  /// Removes the property at [index]. A no-op for an out-of-range index.
  EvidenceAnnotation withPropertyRemoved(int index) {
    if (index < 0 || index >= properties.length) return this;
    return copyWith(properties: [...properties]..removeAt(index));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'properties': [for (final property in properties) property.toJson()],
        if (type != null) 'type': type,
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (origin != null) 'origin': origin!.name,
        if (authorId != null) 'authorId': authorId,
        if (status != null) 'status': status!.name,
        if (regionId != null) 'regionId': regionId,
      };

  /// A missing `properties` key resolves to an empty list.
  factory EvidenceAnnotation.fromJson(Map<String, dynamic> json) {
    return EvidenceAnnotation(
      id: json['id'] as String,
      properties: [
        for (final entry in (json['properties'] as List<dynamic>? ?? const []))
          AnnotationProperty.fromJson(entry as Map<String, dynamic>),
      ],
      type: json['type'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      origin: json['origin'] == null
          ? null
          : EvidenceOrigin.values.byName(json['origin'] as String),
      authorId: json['authorId'] as String?,
      status: json['status'] == null
          ? null
          : EvidenceAnnotationStatus.values.byName(json['status'] as String),
      regionId: json['regionId'] as String?,
    );
  }
}

/// INGEST-012 vocabulary: an [EvidenceAnnotation] *is* the Observation --
/// the structured interpretation of an `EvidenceRegion` -- kept under its
/// WP-INGEST-013 storage name so persisted sessions stay valid.
typedef Observation = EvidenceAnnotation;
typedef ObservationProperty = AnnotationProperty;

/// Optional, non-authoritative property-key suggestions per observation
/// type (configuration only; the persistence model never depends on it).
const Map<String, List<String>> observationPropertySuggestions = {
  'wire': ['color', 'gauge', 'label', 'function'],
  'component': ['part_number', 'manufacturer'],
  'connector': ['connector_type', 'part_number', 'manufacturer', 'pin_count'],
  'measurement': ['value', 'unit'],
  'specification': ['parameter', 'value', 'unit'],
};
