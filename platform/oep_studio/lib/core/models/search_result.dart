import 'package:flutter/material.dart';

import '../foundation/oep_api_native_types.dart';
import '../foundation/oep_api_types.dart';
import 'object_category.dart';
import 'relationship_type.dart';

/// The field a search query matched against. Mirrors
/// `oep_match_location_t` (`oep_api.h`, Work Package 013) 1:1, including
/// numeric values.
enum SearchMatchLocation {
  name('Name', 0),
  description('Description', 1),
  author('Author', 2),
  tags('Tags', 3),
  objectType('Object Type', 4),
  relationshipType('Relationship Type', 5);

  const SearchMatchLocation(this.label, this.nativeValue);

  final String label;
  final int nativeValue;

  static SearchMatchLocation fromNative(int value) {
    return SearchMatchLocation.values.firstWhere(
      (location) => location.nativeValue == value,
      orElse: () => SearchMatchLocation.name,
    );
  }
}

/// Whether a [SearchResult] refers to an Engineering Object or a
/// Relationship — Foundation's `SearchEngine` exposes these as two
/// separate calls (`oep_search_objects`/`oep_search_relationships`)
/// returning two distinct result types; Studio combines them into one
/// displayed list per STUDIO-TASK-000012's "Search Results" requirements,
/// tagged with which kind each row is so selecting one can navigate to
/// the right Explorer.
enum SearchResultKind { object, relationship }

/// A single search result row, as the Search Workspace displays it.
/// Mirrors the union of `oep_object_search_result_t` and
/// `oep_relationship_search_result_t` (`oep_api.h`, Work Package 013).
/// Studio never computes [matchScore] itself; it is always exactly what
/// Foundation's `SearchEngine` reports, and result ordering must never
/// be changed by Studio (STUDIO-TASK-000012: "Studio shall never
/// reorder search results").
class SearchResult {
  const SearchResult({
    required this.kind,
    required this.id,
    required this.name,
    required this.typeLabel,
    required this.matchScore,
    required this.matchLocation,
  });

  /// Decodes an `oep_object_search_result_t` (via
  /// [OepObjectSearchResultNative]). `display_name` is returned by
  /// Foundation directly — no join needed, unlike relationship hits.
  factory SearchResult.fromNativeObject(OepObjectSearchResultNative native) {
    return SearchResult(
      kind: SearchResultKind.object,
      id: decodeFixedCString(native.objectId, oepMaxObjectId),
      name: decodeFixedCString(native.displayName, oepMaxObjectName),
      typeLabel: ObjectCategory.fromNative(native.objectType).label,
      matchScore: native.matchScore,
      matchLocation: SearchMatchLocation.fromNative(native.matchLocation),
    );
  }

  /// Decodes an `oep_relationship_search_result_t` (via
  /// [OepRelationshipSearchResultNative]). Unlike an object hit,
  /// Foundation returns no display name for a relationship — [name] is
  /// built from [objectNamesById] (the Current Object List), the same
  /// join [RelationshipSummary.fromNative] performs, falling back to the
  /// raw ID if the object can't be found there.
  factory SearchResult.fromNativeRelationship(
    OepRelationshipSearchResultNative native, {
    required Map<String, String> objectNamesById,
  }) {
    final sourceId = decodeFixedCString(native.sourceObjectId, oepMaxObjectId);
    final targetId = decodeFixedCString(native.targetObjectId, oepMaxObjectId);
    final sourceName = objectNamesById[sourceId] ?? sourceId;
    final targetName = objectNamesById[targetId] ?? targetId;
    return SearchResult(
      kind: SearchResultKind.relationship,
      id: decodeFixedCString(native.relationshipId, oepMaxRelationshipId),
      name: '$sourceName → $targetName',
      typeLabel: RelationshipType.fromNative(native.relationshipType).label,
      matchScore: native.matchScore,
      matchLocation: SearchMatchLocation.fromNative(native.matchLocation),
    );
  }

  final SearchResultKind kind;
  final String id;
  final String name;
  final String typeLabel;
  final double matchScore;
  final SearchMatchLocation matchLocation;

  IconData get icon => switch (kind) {
    SearchResultKind.object => Icons.category_outlined,
    SearchResultKind.relationship => Icons.hub_outlined,
  };
}
