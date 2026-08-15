import 'package:engineering_engine/engineering_engine.dart';

/// A named, recallable probe placement (WP-DS-005A "Measurement
/// Bookmarks": named bookmarks, grouped bookmarks, project persistence,
/// quick recall).
class MeasurementBookmark {
  const MeasurementBookmark({
    required this.id,
    required this.name,
    required this.probeA,
    required this.probeB,
    required this.type,
    this.group = 'Ungrouped',
  });

  final String id;
  final String name;
  final String group;
  final ProbePoint probeA;
  final ProbePoint probeB;
  final MeasurementType type;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'group': group,
        'probeA': probeA.toJson(),
        'probeB': probeB.toJson(),
        'type': type.name,
      };

  factory MeasurementBookmark.fromJson(Map<String, Object?> json) => MeasurementBookmark(
        id: json['id'] as String,
        name: json['name'] as String,
        group: json['group'] as String? ?? 'Ungrouped',
        probeA: ProbePoint.fromJson(Map<String, Object?>.from(json['probeA'] as Map)),
        probeB: ProbePoint.fromJson(Map<String, Object?>.from(json['probeB'] as Map)),
        type: MeasurementType.values.firstWhere((t) => t.name == json['type']),
      );
}
