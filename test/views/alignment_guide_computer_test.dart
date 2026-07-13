import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('AlignmentGuideComputer', () {
    test('finds a vertical guide when left edges nearly align', () {
      const dragged = Rect2D(left: 101, top: 0, right: 201, bottom: 100);
      const sibling = Rect2D(left: 100, top: 300, right: 200, bottom: 400);
      final guides = AlignmentGuideComputer.computeGuides(
        draggedBounds: dragged,
        siblingBounds: [sibling],
      );
      expect(guides.any((g) => g.axis == GridAxis.vertical && g.position == 100), isTrue);
    });

    test('finds no guides beyond the threshold', () {
      const dragged = Rect2D(left: 150, top: 0, right: 250, bottom: 100);
      const sibling = Rect2D(left: 0, top: 300, right: 100, bottom: 400);
      final guides = AlignmentGuideComputer.computeGuides(
        draggedBounds: dragged,
        siblingBounds: [sibling],
        threshold: 4,
      );
      expect(guides, isEmpty);
    });

    test('snapToGuides nudges the candidate position to align exactly', () {
      final snapped = AlignmentGuideComputer.snapToGuides(
        candidatePosition: const Point2D(102, 500),
        width: 100,
        height: 100,
        siblingBounds: const [Rect2D(left: 100, top: 0, right: 200, bottom: 100)],
      );
      expect(snapped.dx, 100); // left edges now aligned exactly
      expect(snapped.dy, 500); // y untouched — no vertical match
    });
  });
}
