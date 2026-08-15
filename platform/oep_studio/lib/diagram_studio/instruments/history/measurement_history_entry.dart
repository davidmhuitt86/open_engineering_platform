import 'package:engineering_engine/engineering_engine.dart';

/// One row of the Measurement History (WP-DS-005A "Measurement History":
/// timestamp, probe locations, measurement mode, result, engineering path
/// — all present on [MeasurementResult] itself; this wraps it with a
/// stable [id] for replay/clear-one/export addressing).
class MeasurementHistoryEntry {
  MeasurementHistoryEntry({required this.id, required this.result});

  final String id;
  final MeasurementResult result;

  Map<String, Object?> toJson() => {'id': id, 'result': result.toJson()};

  factory MeasurementHistoryEntry.fromJson(Map<String, Object?> json) => MeasurementHistoryEntry(
        id: json['id'] as String,
        result: MeasurementResult.fromJson(Map<String, Object?>.from(json['result'] as Map)),
      );
}
