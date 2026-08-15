import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/workbench/dock/dock_manager.dart';
import 'package:oep_studio/workbench/dock/dock_panel_client.dart';
import 'package:oep_studio/workbench/dock/dock_region.dart';
import 'package:oep_studio/workbench/dock/dock_state.dart';

class _FakeClient extends DockPanelClient {
  const _FakeClient(this.id, this.title);
  @override
  final String id;
  @override
  final String title;
  @override
  IconData get icon => Icons.circle;
  @override
  Widget buildPanel(BuildContext context) => Text('panel-$id');
}

Widget _harness(Widget child) => MaterialApp(
      home: Scaffold(
        body: Stack(children: [child]),
      ),
    );

void main() {
  late Directory tempDir;
  var counter = 0;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dock_region_test_');
    counter = 0;
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // Every DockManager below gets its own file in the test's temp
  // directory, never the app's real SettingsStorage.root() — fire-and-
  // forget persistence must not touch a real user profile during tests.
  File nextFile() => File('${tempDir.path}/dock-${counter++}.json');

  group('DockRegion', () {
    testWidgets('renders nothing when hidden', (tester) async {
      final manager = DockManager(dockId: 'x', file: nextFile());
      final registry = DockPanelClientRegistry()..register(const _FakeClient('a', 'Alpha'));
      await tester.pumpWidget(_harness(DockRegion(manager: manager, registry: registry)));
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('renders nothing when the registry is empty even if visible', (tester) async {
      final manager = DockManager(dockId: 'x', file: nextFile())..show(null);
      final registry = DockPanelClientRegistry();
      await tester.pumpWidget(_harness(DockRegion(manager: manager, registry: registry)));
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('shows tabs for every registered client and the active panel content', (tester) async {
      final manager = DockManager(dockId: 'x', file: nextFile())..show('a');
      final registry = DockPanelClientRegistry()
        ..register(const _FakeClient('a', 'Alpha'))
        ..register(const _FakeClient('b', 'Beta'));
      await tester.pumpWidget(_harness(DockRegion(manager: manager, registry: registry)));
      await tester.pump();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('panel-a'), findsOneWidget);
      expect(find.text('panel-b'), findsNothing);
    });

    testWidgets('tapping a tab switches the active panel', (tester) async {
      final manager = DockManager(dockId: 'x', file: nextFile())..show('a');
      final registry = DockPanelClientRegistry()
        ..register(const _FakeClient('a', 'Alpha'))
        ..register(const _FakeClient('b', 'Beta'));
      await tester.pumpWidget(_harness(DockRegion(manager: manager, registry: registry)));
      await tester.pump();

      await tester.tap(find.text('Beta'));
      await tester.pump();

      expect(find.text('panel-b'), findsOneWidget);
      expect(find.text('panel-a'), findsNothing);
      expect(manager.state.activeClientId, 'b');
    });

    testWidgets('renders as a Positioned strip for bottom/left/right sides', (tester) async {
      for (final side in [DockSide.bottom, DockSide.left, DockSide.right]) {
        final manager = DockManager(dockId: 'x-$side', file: nextFile())
          ..show('a')
          ..setSide(side);
        final registry = DockPanelClientRegistry()..register(const _FakeClient('a', 'Alpha'));
        await tester.pumpWidget(_harness(DockRegion(manager: manager, registry: registry)));
        await tester.pump();
        expect(find.text('Alpha'), findsOneWidget, reason: 'side=$side');
        expect(find.byType(Positioned), findsWidgets, reason: 'side=$side');
      }
    });

    testWidgets('floating side renders a titled, closable frame', (tester) async {
      final manager = DockManager(dockId: 'x', file: nextFile())
        ..show('a')
        ..setSide(DockSide.floating);
      final registry = DockPanelClientRegistry()..register(const _FakeClient('a', 'Alpha'));
      await tester.pumpWidget(_harness(DockRegion(manager: manager, registry: registry)));
      await tester.pump();

      expect(find.text('panel-a'), findsOneWidget);
      // Floating frame has a "Dock to bottom" and "Hide" affordance.
      expect(find.byTooltip('Dock to bottom'), findsWidgets);
      expect(find.byTooltip('Hide'), findsWidgets);

      await tester.tap(find.byTooltip('Hide').first);
      await tester.pump();
      expect(manager.state.visible, isFalse);
    });

    testWidgets('auto-hide pin toggles autoHide state', (tester) async {
      final manager = DockManager(dockId: 'x', file: nextFile())..show('a');
      final registry = DockPanelClientRegistry()..register(const _FakeClient('a', 'Alpha'));
      await tester.pumpWidget(_harness(DockRegion(manager: manager, registry: registry)));
      await tester.pump();

      expect(manager.state.autoHide, isFalse);
      await tester.tap(find.byTooltip('Enable auto-hide'));
      await tester.pump();
      expect(manager.state.autoHide, isTrue);
    });

    testWidgets('float/dock toggle button switches side', (tester) async {
      final manager = DockManager(dockId: 'x', file: nextFile())..show('a');
      final registry = DockPanelClientRegistry()..register(const _FakeClient('a', 'Alpha'));
      await tester.pumpWidget(_harness(DockRegion(manager: manager, registry: registry)));
      await tester.pump();

      expect(manager.state.side, DockSide.bottom);
      await tester.tap(find.byTooltip('Float'));
      await tester.pump();
      expect(manager.state.side, DockSide.floating);
    });

    testWidgets('resize grip drag updates dock size for a bottom dock', (tester) async {
      final manager = DockManager(dockId: 'x', file: nextFile())..show('a');
      final registry = DockPanelClientRegistry()..register(const _FakeClient('a', 'Alpha'));
      await tester.pumpWidget(_harness(DockRegion(manager: manager, registry: registry)));
      await tester.pump();

      final initialSize = manager.state.size;
      final grip = find.byWidgetPredicate((w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeUpDown);
      expect(grip, findsOneWidget);
      await tester.drag(grip, const Offset(0, -40));
      await tester.pump();
      expect(manager.state.size, greaterThan(initialSize));
    });
  });
}
