import 'dart:convert';
import 'dart:io';

import '../models/engineering_project.dart';
import '../models/engineering_project_exception.dart';

/// Local JSON persistence for [EngineeringProject]s (WORK_PACKAGE_025,
/// ENGINE-TASK-000118) — one file per project under
/// `%APPDATA%/oep_studio/projects/<id>.json`, mirroring
/// `KnowledgeSessionStorage`'s existing file-per-record convention
/// (a project has no attached files of its own, unlike a Knowledge
/// Session's Source Materials, so a flat file suffices — no
/// subdirectory needed).
abstract final class EngineeringProjectStorage {
  static Directory root() {
    final base =
        Platform.environment['APPDATA'] ?? Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
    return Directory('$base${Platform.pathSeparator}oep_studio${Platform.pathSeparator}projects');
  }

  static File _file(String projectId) => File('${root().path}${Platform.pathSeparator}$projectId.json');

  static Future<void> save(EngineeringProject project) async {
    try {
      await root().create(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      await _file(project.id).writeAsString(encoder.convert(project.toJson()));
    } on IOException catch (error) {
      throw EngineeringProjectException('Couldn\'t save project "${project.name}": ${error.toString()}');
    }
  }

  static Future<EngineeringProject> load(String projectId) async {
    final file = _file(projectId);
    if (!file.existsSync()) {
      throw const EngineeringProjectException('That project could not be found.');
    }
    final String contents;
    try {
      contents = await file.readAsString();
    } on IOException catch (error) {
      throw EngineeringProjectException('Couldn\'t read project file: ${error.toString()}');
    }
    try {
      return EngineeringProject.fromJson(jsonDecode(contents) as Map<String, dynamic>);
    } on FormatException catch (error) {
      throw EngineeringProjectException(
        'This project file is corrupted and could not be loaded (${error.message}).',
      );
    } on TypeError {
      throw const EngineeringProjectException('This project file is corrupted and could not be loaded.');
    }
  }

  /// Lists every persisted project, most-recently-modified first.
  /// Corrupted files are skipped rather than blocking the listing —
  /// mirrors `KnowledgeSessionStorage.listAll`'s degradation strategy.
  static Future<List<EngineeringProject>> listAll() async {
    final directory = root();
    if (!directory.existsSync()) return const [];
    final projects = <EngineeringProject>[];
    for (final entry in directory.listSync()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      final id = entry.uri.pathSegments.last.replaceAll('.json', '');
      try {
        projects.add(await load(id));
      } on EngineeringProjectException {
        continue;
      }
    }
    projects.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return projects;
  }

  static Future<void> delete(String projectId) async {
    final file = _file(projectId);
    if (!file.existsSync()) return;
    try {
      await file.delete();
    } on IOException catch (error) {
      throw EngineeringProjectException('Couldn\'t delete project: ${error.toString()}');
    }
  }
}
