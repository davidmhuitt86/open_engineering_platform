import 'dart:ffi';

import '../foundation/oep_api_native_types.dart';
import '../foundation/oep_api_types.dart';
import 'object_category.dart';

/// A read-only summary of an Engineering Object, as the Object Explorer
/// (STUDIO-TASK-000006) and Property Inspector display it.
///
/// Mirrors `oep_object_info_t` (`oep_api.h`, Work Package 012/Work
/// Package 004) field-for-field.
class EngineeringObjectSummary {
  const EngineeringObjectSummary({
    required this.objectId,
    required this.category,
    required this.name,
    required this.author,
    required this.version,
    this.description = '',
    this.tags = const [],
  });

  /// Decodes an `oep_object_info_t` (via [OepObjectInfoNative]) into a
  /// plain Dart model. The only place in Studio that reads this
  /// struct's fields — everything above the Foundation Bridge works
  /// with the resulting [EngineeringObjectSummary] instead.
  factory EngineeringObjectSummary.fromNative(OepObjectInfoNative native) {
    final tagCount = native.tagCount.clamp(0, oepMaxObjectTags);
    final tags = <String>[
      for (var i = 0; i < tagCount; i++) decodeFixedCString(native.tags[i], oepMaxTagLength),
    ];

    return EngineeringObjectSummary(
      objectId: decodeFixedCString(native.objectId, oepMaxObjectId),
      category: ObjectCategory.fromNative(native.objectType),
      name: decodeFixedCString(native.name, oepMaxObjectName),
      author: decodeFixedCString(native.author, oepMaxObjectAuthor),
      version: decodeFixedCString(native.version, oepMaxObjectVersion),
      description: decodeFixedCString(native.description, oepMaxObjectDescription),
      tags: tags,
    );
  }

  final String objectId;
  final ObjectCategory category;
  final String name;
  final String author;
  final String version;
  final String description;
  final List<String> tags;
}
