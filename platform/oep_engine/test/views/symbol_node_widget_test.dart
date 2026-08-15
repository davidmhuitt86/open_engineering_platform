import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// Regression coverage for a real bug: probes (and any other future
/// click-to-place-on-a-port feature) placed by tapping a port always
/// landed on the node's own center instead, because `onPortDragStart`
/// only fires once Flutter's pan recognizer has actually recognized a
/// drag (pointer moved past the touch-slop threshold) -- a precise,
/// no-movement click never reaches it, so the tap fell through to the
/// node's own whole-node `onTap` instead. `onTapUp` (wired to the new
/// `onPortTap` callback) is what actually fires for that case.
void main() {
  const port = SymbolPort(id: 'positive', displayName: 'Positive', connectionType: 'power', x: 0.0, y: 0.5);
  const node = DiagramNodeVisual(nodeId: 'battery', symbolId: null, position: Point2D(0, 0), width: 100, height: 100);

  Widget harness({
    required VoidCallback onNodeTap,
    required void Function(PortReference) onPortTap,
    required void Function(PortReference) onPortDragStart,
    required VoidCallback onPortDragEnd,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 200,
          child: SymbolNodeWidget(
            node: node,
            ports: const [port],
            hoveredPort: null,
            onTap: onNodeTap,
            onDragStart: () {},
            onDragUpdate: (_) {},
            onDragEnd: () {},
            onPortHoverEnter: (_) {},
            onPortHoverExit: () {},
            onPortDragStart: onPortDragStart,
            onPortDragUpdate: (_) {},
            onPortDragEnd: onPortDragEnd,
            onPortTap: onPortTap,
          ),
        ),
      ),
    );
  }

  testWidgets('a plain click on a port fires onPortTap, not the node\'s own onTap', (tester) async {
    var nodeTapped = false;
    PortReference? tappedPort;
    await tester.pumpWidget(harness(
      onNodeTap: () => nodeTapped = true,
      onPortTap: (p) => tappedPort = p,
      onPortDragStart: (_) {},
      onPortDragEnd: () {},
    ));

    // The port sits at normalized (0.0, 0.5) on a 100x100 node -> local
    // (0, 50), shifted by `kNodeHitMargin` since the widget's own root
    // is inflated by that margin on every side (an edge-exit port's
    // marker, centered exactly on the card's boundary, needs the extra
    // room to stay hit-testable -- see `kNodeHitMargin`'s doc comment).
    await tester.tapAt(const Offset(kNodeHitMargin, kNodeHitMargin + 50));
    await tester.pump();

    expect(tappedPort, const PortReference(nodeId: 'battery', portId: 'positive'));
    expect(nodeTapped, isFalse, reason: 'the port marker should claim the tap, not let it fall through to the node');
  });

  testWidgets('dragging from a port still fires onPortDragStart/onPortDragEnd, not onPortTap', (tester) async {
    var dragStarted = false;
    var dragEnded = false;
    PortReference? tappedPort;
    await tester.pumpWidget(harness(
      onNodeTap: () {},
      onPortTap: (p) => tappedPort = p,
      onPortDragStart: (_) => dragStarted = true,
      onPortDragEnd: () => dragEnded = true,
    ));

    await tester.dragFrom(const Offset(kNodeHitMargin, kNodeHitMargin + 50), const Offset(40, 0));
    await tester.pump();

    expect(dragStarted, isTrue);
    expect(dragEnded, isTrue);
    expect(tappedPort, isNull, reason: 'a real drag should not also register as a tap');
  });

  testWidgets('a click well outside any port still reaches the node\'s own onTap', (tester) async {
    var nodeTapped = false;
    await tester.pumpWidget(harness(
      onNodeTap: () => nodeTapped = true,
      onPortTap: (_) {},
      onPortDragStart: (_) {},
      onPortDragEnd: () {},
    ));

    // node center, far from the port
    await tester.tapAt(const Offset(kNodeHitMargin + 50, kNodeHitMargin + 50));
    await tester.pump();

    expect(nodeTapped, isTrue);
  });

  /// Regression coverage for a real, user-reported rendering bug: each
  /// pin's real name is drawn as small text next to its dot, but was
  /// positioned INSIDE the dot's own 12x12 band -- and since the port
  /// markers are later `Stack` children than the labels, the dot
  /// painted over the label's nearer half, visually cutting every pin
  /// name in two.
  group('pin name labels', () {
    Widget labelHarness(List<SymbolPort> ports) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: SymbolNodeWidget(
                node: node,
                ports: ports,
                hoveredPort: null,
                onTap: () {},
                onDragStart: () {},
                onDragUpdate: (_) {},
                onDragEnd: () {},
                onPortHoverEnter: (_) {},
                onPortHoverExit: () {},
                onPortDragStart: (_) {},
                onPortDragUpdate: (_) {},
                onPortDragEnd: () {},
              ),
            ),
          ),
        );

    testWidgets("renders a bottom-edge pin's own real name, fully clear of its dot", (tester) async {
      const bottomPort = SymbolPort(id: 'oil', displayName: 'OIL', connectionType: 'signal', x: 0.5, y: 1.0);
      await tester.pumpWidget(labelHarness(const [bottomPort]));

      final label = find.text('OIL');
      expect(label, findsOneWidget, reason: "the port's real displayName must be visible, not just a bare dot");

      final labelRect = tester.getRect(label);
      final dotRect = tester.getRect(find.byKey(const ValueKey('port-battery-oil')));
      expect(labelRect.overlaps(dotRect), isFalse,
          reason: 'a label overlapping its own dot is painted over by it and reads as cut in half');
      expect(labelRect.bottom, lessThanOrEqualTo(dotRect.top),
          reason: 'a bottom-edge pin labels ABOVE its dot, inside the card');
    });

    testWidgets("renders a top-edge pin's name below its dot, fully clear of it", (tester) async {
      const topPort = SymbolPort(id: 'batt', displayName: 'BATT', connectionType: 'power', x: 0.5, y: 0.0);
      await tester.pumpWidget(labelHarness(const [topPort]));

      final labelRect = tester.getRect(find.text('BATT'));
      final dotRect = tester.getRect(find.byKey(const ValueKey('port-battery-batt')));
      expect(labelRect.overlaps(dotRect), isFalse);
      expect(labelRect.top, greaterThanOrEqualTo(dotRect.bottom),
          reason: 'a top-edge pin labels BELOW its dot, inside the card');
    });

    testWidgets('a side-edge pin renders no label -- no room to stack one without colliding', (tester) async {
      const sidePort = SymbolPort(id: 'positive', displayName: 'Positive', connectionType: 'power', x: 0.0, y: 0.5);
      await tester.pumpWidget(labelHarness(const [sidePort]));
      expect(find.text('Positive'), findsNothing);
    });

    testWidgets('a port with no real name renders no label -- never a fabricated one', (tester) async {
      const unnamed = SymbolPort(id: 'p1', displayName: '', connectionType: 'signal', x: 0.5, y: 1.0);
      await tester.pumpWidget(labelHarness(const [unnamed]));
      expect(find.byKey(const ValueKey('port-battery-p1')), findsOneWidget, reason: 'the dot itself still renders');
      expect(find.text('p1'), findsNothing, reason: 'the port id is not a substitute for a real name');
    });
  });
}
