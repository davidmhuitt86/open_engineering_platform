import 'package:engineering_engine/engineering_engine.dart';

/// AP-DS-004: Package Manifest — bookkeeping about an export bundle's
/// contents, not engineering data. Deliberately simple per the task
/// spec's own instruction ("this is bookkeeping, not engineering data,
/// keep it simple").
class PackageManifest {
  final String diagramTitle;
  final DateTime generatedAt;
  final List<String> includedReports;
  final TitleBlock titleBlockSnapshot;

  const PackageManifest({
    required this.diagramTitle,
    required this.generatedAt,
    required this.includedReports,
    required this.titleBlockSnapshot,
  });

  Map<String, Object?> toJson() => {
        'diagramTitle': diagramTitle,
        'generatedAt': generatedAt.toIso8601String(),
        'includedReports': includedReports,
        'titleBlockSnapshot': titleBlockSnapshot.toJson(),
      };

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# Package Manifest');
    buffer.writeln();
    buffer.writeln('- Diagram: $diagramTitle');
    buffer.writeln('- Generated: ${generatedAt.toIso8601String()}');
    buffer.writeln('- Drawing Number: ${titleBlockSnapshot.drawingNumber}');
    buffer.writeln('- Revision: ${titleBlockSnapshot.revision}');
    buffer.writeln();
    buffer.writeln('## Included Deliverables');
    buffer.writeln();
    if (includedReports.isEmpty) {
      buffer.writeln('_None selected._');
    } else {
      for (final r in includedReports) {
        buffer.writeln('- $r');
      }
    }
    return buffer.toString();
  }
}
