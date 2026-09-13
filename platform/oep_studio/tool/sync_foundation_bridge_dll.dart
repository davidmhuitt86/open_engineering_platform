// ignore_for_file: avoid_print
import 'dart:io';

/// WP-EXC-013A: makes the checked-in `oep_foundation_bridge.dll` (at this
/// package's root — where `dart:ffi`'s bare `DynamicLibrary.open(
/// 'oep_foundation_bridge.dll')` resolves it via the current working
/// directory when `flutter test` runs) reproducible from a normal build,
/// instead of a one-off manual copy.
///
/// The canonical build (documented in `docs/FOUNDATION_BRIDGE.md` §
/// "Native DLL") is `flutter build windows [--debug|--release]`, which
/// compiles `native/foundation_bridge/` via `windows/CMakeLists.txt` and
/// copies the result next to `oep_studio.exe` under
/// `build/windows/x64/runner/{Debug,Release}/oep_foundation_bridge.dll`.
/// That build output is git-ignored (`/build/` in `.gitignore`) and was
/// never the same file as the tracked root-level copy — nothing kept
/// them in sync, which is why the root copy silently went stale after
/// the Foundation API moved on (see `docs/tasks/WP-EXC-013A.md` for the
/// full root-cause history).
///
/// This script copies the freshest available canonical build output over
/// the tracked root copy. It does not build anything itself — run
/// `flutter build windows --debug` (or `--release`) first.
///
/// Usage: `dart run tool/sync_foundation_bridge_dll.dart [--release]`
Future<void> main(List<String> args) async {
  final release = args.contains('--release');
  final configs = release ? ['Release', 'Debug'] : ['Debug', 'Release'];

  final packageRoot = Directory.current;
  File? source;
  for (final config in configs) {
    final candidate = File(
      '${packageRoot.path}${Platform.pathSeparator}build${Platform.pathSeparator}windows${Platform.pathSeparator}'
      'x64${Platform.pathSeparator}runner${Platform.pathSeparator}$config${Platform.pathSeparator}oep_foundation_bridge.dll',
    );
    if (candidate.existsSync()) {
      source = candidate;
      break;
    }
  }

  if (source == null) {
    stderr.writeln(
      'No canonical oep_foundation_bridge.dll build output found under '
      'build/windows/x64/runner/{Debug,Release}/. Run `flutter build '
      'windows --debug` first (see docs/FOUNDATION_BRIDGE.md).',
    );
    exit(1);
  }

  final destination = File('${packageRoot.path}${Platform.pathSeparator}oep_foundation_bridge.dll');
  final sourceBytes = await source.readAsBytes();
  final alreadyCurrent = destination.existsSync() && _bytesEqual(await destination.readAsBytes(), sourceBytes);

  if (alreadyCurrent) {
    print('oep_foundation_bridge.dll is already in sync with ${source.path}.');
    return;
  }

  await destination.writeAsBytes(sourceBytes, flush: true);
  print('Synced oep_foundation_bridge.dll from ${source.path} (${sourceBytes.length} bytes).');
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
