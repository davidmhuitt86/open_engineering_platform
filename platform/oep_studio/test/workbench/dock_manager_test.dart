import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/workbench/dock/dock_manager.dart';
import 'package:oep_studio/workbench/dock/dock_state.dart';

/// WP-DS-006: DockManager show/hide/toggle/select/side/autoHide/size/
/// floating-bounds behavior and its own persistence, against real files in
/// a temp directory (no mocks — matches perspective_manager_test.dart's
/// established convention). Every mutating call fire-and-forgets a write
/// (same precedent as PerspectiveManager.activate), so every test that
/// mutates state waits a beat before finishing, exactly like
/// perspective_manager_test.dart already does — otherwise the write can
/// race tearDown's directory deletion.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dock_manager_test_');
  });

  tearDown(() async {
    // Give any still-in-flight fire-and-forget persist a chance to land
    // before the directory disappears out from under it.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File file() => File('${tempDir.path}/dock.json');

  group('DockManager', () {
    test('starts with the documented initial state (visible: false, side: bottom)', () {
      final manager = DockManager(dockId: 'test', file: file());
      expect(manager.state.visible, isFalse);
      expect(manager.state.side, DockSide.bottom);
    });

    test('show makes it visible and resolves a hidden side to bottom', () async {
      final manager = DockManager(dockId: 'test', file: file());
      manager.show('client-a');
      expect(manager.state.visible, isTrue);
      expect(manager.state.side, DockSide.bottom);
      expect(manager.state.activeClientId, 'client-a');
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });

    test('hide sets side to hidden and visible to false', () async {
      final manager = DockManager(dockId: 'test', file: file())..show('a');
      manager.hide();
      expect(manager.state.visible, isFalse);
      expect(manager.state.side, DockSide.hidden);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });

    test('toggleVisible flips between shown and hidden', () async {
      final manager = DockManager(dockId: 'test', file: file());
      manager.toggleVisible('a');
      expect(manager.state.visible, isTrue);
      manager.toggleVisible('a');
      expect(manager.state.visible, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });

    test('selectClient updates activeClientId and shows the dock', () async {
      final manager = DockManager(dockId: 'test', file: file());
      manager.selectClient('b');
      expect(manager.state.activeClientId, 'b');
      expect(manager.state.visible, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });

    test('setSide to hidden also clears visibility; other sides keep visible', () async {
      final manager = DockManager(dockId: 'test', file: file());
      manager.setSide(DockSide.right);
      expect(manager.state.side, DockSide.right);
      expect(manager.state.visible, isTrue);
      manager.setSide(DockSide.hidden);
      expect(manager.state.visible, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });

    test('setSize clamps to [160, 800]', () async {
      final manager = DockManager(dockId: 'test', file: file());
      manager.setSize(10);
      expect(manager.state.size, 160);
      manager.setSize(5000);
      expect(manager.state.size, 800);
      manager.setSize(300);
      expect(manager.state.size, 300);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });

    test('setFloatingBounds clamps width/height and moves left/top freely', () async {
      final manager = DockManager(dockId: 'test', file: file());
      manager.setFloatingBounds(left: 50, top: 60, width: 10, height: 5000);
      expect(manager.state.floatingLeft, 50);
      expect(manager.state.floatingTop, 60);
      expect(manager.state.floatingWidth, 280);
      expect(manager.state.floatingHeight, 900);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });

    test('every mutation notifies listeners', () async {
      final manager = DockManager(dockId: 'test', file: file());
      var notified = 0;
      manager.addListener(() => notified++);
      manager.show('a');
      manager.setAutoHide(true);
      manager.setSize(400);
      expect(notified, 3);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });

    test('persists state to its own file and DockManager.load restores it', () async {
      final f = file();
      final manager = DockManager(dockId: 'test', file: f);
      manager.show('client-x');
      manager.setSide(DockSide.right);
      manager.setAutoHide(true);
      manager.setSize(444);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(f.existsSync(), isTrue);

      final loaded = await DockManager.load('test', file: f);
      expect(loaded.state.visible, isTrue);
      expect(loaded.state.side, DockSide.right);
      expect(loaded.state.autoHide, isTrue);
      expect(loaded.state.size, 444);
      expect(loaded.state.activeClientId, 'client-x');
    });

    test('DockManager.load falls back to initial state when no file exists', () async {
      final loaded = await DockManager.load('never-written', file: file());
      expect(loaded.state.visible, isFalse);
      expect(loaded.state.side, DockSide.bottom);
    });

    test('DockManager.load falls back to initial state on corrupt JSON', () async {
      final f = file();
      f.parent.createSync(recursive: true);
      f.writeAsStringSync('{not valid json');
      final loaded = await DockManager.load('test', file: f);
      expect(loaded.state.visible, isFalse);
    });

    test('two independently keyed DockManagers persist to independent files', () async {
      final fileA = File('${tempDir.path}/a.json');
      final fileB = File('${tempDir.path}/b.json');
      final a = DockManager(dockId: 'a', file: fileA)..show('x');
      final b = DockManager(dockId: 'b', file: fileB)..setSide(DockSide.left);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(fileA.existsSync(), isTrue);
      expect(fileB.existsSync(), isTrue);
      expect(a.state.side, isNot(DockSide.left));
      expect(b.state.visible, isTrue);
      // b was never shown/hidden explicitly beyond setSide(left), which
      // makes it visible; a's own file must not reflect b's side change.
      final loadedA = await DockManager.load('a', file: fileA);
      expect(loadedA.state.side, DockSide.bottom);
    });
  });
}
