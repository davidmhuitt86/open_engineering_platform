// ignore_for_file: avoid_print
//
// AP-EK-020 (packaging finalization) — generates the compiled `.oerp`
// Knowledge Package Studio's production runtime bundles as a Flutter
// asset, from the Reference Library source of truth.
//
// SDD-R010 §16 forbids committing compiler output
// (`knowledge/reference_library/.gitignore`: "/dist/", "*.oerp" —
// "Compiler output shall never be submitted"), so the compiled package
// cannot live in this repository as a checked-in file. It also cannot be
// referenced directly from `pubspec.yaml` at
// `../../knowledge/reference_library/dist/core_reference_v1.oerp` —
// Flutter's asset bundler silently drops any entry that resolves outside
// this package's own directory (confirmed by direct testing; the same
// finding `pubspec.yaml`'s own comment on the legacy V2 wiring app
// records for exactly this reason). This script is the bridge: it runs
// the real Python Reference Compiler against
// `knowledge/reference_library/packages/core_reference/`, then copies
// its output into `assets/knowledge/` — itself gitignored
// (`platform/oep_studio/.gitignore`) — where `pubspec.yaml` declares it
// as an ordinary Flutter asset.
//
//   source knowledge (git, canonical)
//       -> Reference Compiler (Python, this script's subprocess)
//       -> generated .oerp (gitignored build artifact)
//       -> assets/knowledge/ (gitignored, staged by this script)
//       -> Flutter asset bundling (pubspec.yaml, ordinary mechanism)
//
// Run before `flutter run`/`flutter build` (production `main.dart`'s own
// `electricalCoreRuntimeProvider` fails explicitly, not silently, if this
// hasn't been run yet — see that provider's own doc comment):
//
//   cd platform/oep_studio && dart run tool/generate_knowledge_asset.dart
//
// Requires Python 3.10+ on PATH with the Reference Library's own
// dependencies available (PyYAML, jsonschema) — no `pip install` of the
// `oep-reference` package itself is required; this script points
// `PYTHONPATH` directly at `knowledge/reference_library/tools` and
// `knowledge/reference_library` itself, the same two directories
// `pyproject.toml`'s own `[tool.setuptools.package-dir]` maps
// `oep_reference_core`/`compiler`/`validator` onto.
import 'dart:io';

const _packageId = 'core_reference';
const _oerpFileName = 'core_reference_v1.oerp';

Future<void> main() async {
  final studioRoot = Directory.current;
  final repoRoot = _findRepoRoot(studioRoot);
  if (repoRoot == null) {
    stderr.writeln(
      'Could not locate the monorepo root (looked for '
      'knowledge/reference_library/compiler above ${studioRoot.path}). '
      'Run this from platform/oep_studio.',
    );
    exitCode = 1;
    return;
  }

  final referenceLibraryDir =
      Directory('${repoRoot.path}${Platform.pathSeparator}knowledge'
          '${Platform.pathSeparator}reference_library');
  final pythonPathSeparator = Platform.isWindows ? ';' : ':';
  final pythonPath = [
    '${referenceLibraryDir.path}${Platform.pathSeparator}tools',
    referenceLibraryDir.path,
  ].join(pythonPathSeparator);

  print('Compiling "$_packageId" with the Reference Compiler...');
  final result = await Process.run(
    'python',
    ['-m', 'compiler.cli', _packageId],
    workingDirectory: referenceLibraryDir.path,
    environment: {'PYTHONPATH': pythonPath},
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    stderr.writeln(
      'Reference Compiler failed (exit ${result.exitCode}) — see output '
      'above. Is Python 3.10+ on PATH, with PyYAML/jsonschema installed?',
    );
    exitCode = 1;
    return;
  }

  final compiledFile = File(
    '${referenceLibraryDir.path}${Platform.pathSeparator}dist'
    '${Platform.pathSeparator}$_oerpFileName',
  );
  if (!compiledFile.existsSync()) {
    stderr.writeln(
      'Reference Compiler reported success but ${compiledFile.path} does '
      'not exist.',
    );
    exitCode = 1;
    return;
  }

  final assetDir = Directory('${studioRoot.path}${Platform.pathSeparator}assets'
      '${Platform.pathSeparator}knowledge');
  assetDir.createSync(recursive: true);
  final assetFile =
      File('${assetDir.path}${Platform.pathSeparator}$_oerpFileName');
  compiledFile.copySync(assetFile.path);

  final bytes = assetFile.readAsBytesSync();
  print('Staged ${assetFile.path} (${bytes.length} bytes).');
  print(
    'Run `flutter pub get` if this is the first time this asset has '
    'existed, then `flutter run`/`flutter build` as usual.',
  );
}

/// Walks upward from [start] looking for the monorepo marker
/// `knowledge/reference_library/compiler` — the same "search upward for
/// a known-relative marker path" approach
/// `legacy_v2_webview.dart`'s `_v2EntryPointUri()` already uses for
/// exactly this "don't assume a fixed relative depth" reason (works both
/// from `platform/oep_studio` directly and from any subdirectory a tool
/// script might be invoked from).
Directory? _findRepoRoot(Directory start) {
  var dir = start;
  for (var i = 0; i < 8; i++) {
    final marker = Directory(
      '${dir.path}${Platform.pathSeparator}knowledge'
      '${Platform.pathSeparator}reference_library'
      '${Platform.pathSeparator}compiler',
    );
    if (marker.existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
  return null;
}
