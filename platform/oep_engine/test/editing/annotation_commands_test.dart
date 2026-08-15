import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  late EditingSession session;
  const annotation = DiagramAnnotation(
    id: 'ann1',
    type: AnnotationType.textLabel,
    text: 'Hello',
    position: Point2D(10, 20),
  );

  setUp(() {
    final graph = (GraphBuilder(id: 'g')
          ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A'))
        .build();
    session = EditingSession.initial(graph);
  });

  group('CreateAnnotationCommand / DeleteAnnotationCommand', () {
    test('create adds the annotation to layout; revert removes it', () {
      final command = CreateAnnotationCommand(annotation);
      final after = command.apply(session);
      expect(after.layout.annotationOf('ann1'), annotation);

      final reverted = command.revert(after);
      expect(reverted.layout.annotationOf('ann1'), isNull);
    });

    test('delete removes the annotation; revert restores it exactly', () {
      final withAnnotation = session.copyWith(layout: session.layout.withAnnotation(annotation));
      final command = DeleteAnnotationCommand('ann1');
      final after = command.apply(withAnnotation);
      expect(after.layout.annotationOf('ann1'), isNull);

      final reverted = command.revert(after);
      expect(reverted.layout.annotationOf('ann1'), annotation);
    });
  });

  group('UpdateAnnotationCommand', () {
    test('patches position/rotation/text and reverts exactly', () {
      final withAnnotation = session.copyWith(layout: session.layout.withAnnotation(annotation));
      final command = UpdateAnnotationCommand(
        'ann1',
        position: const Point2D(100, 200),
        rotation: 45,
        text: 'Updated',
      );
      final after = command.apply(withAnnotation);
      final updated = after.layout.annotationOf('ann1')!;
      expect(updated.position, const Point2D(100, 200));
      expect(updated.rotation, 45);
      expect(updated.text, 'Updated');

      final reverted = command.revert(after);
      expect(reverted.layout.annotationOf('ann1'), annotation);
    });

    test('unset fields leave that property untouched', () {
      final withAnnotation = session.copyWith(layout: session.layout.withAnnotation(annotation));
      final command = UpdateAnnotationCommand('ann1', text: 'Only text changes');
      final after = command.apply(withAnnotation);
      final updated = after.layout.annotationOf('ann1')!;
      expect(updated.text, 'Only text changes');
      expect(updated.position, annotation.position);
      expect(updated.rotation, annotation.rotation);
    });
  });

  group('Clipboard copy/paste/duplicate support annotations', () {
    test('ClipboardExtraction pulls selected annotations from layout', () {
      final withAnnotation = session.copyWith(layout: session.layout.withAnnotation(annotation));
      final entry = ClipboardExtraction.extract(
        withAnnotation,
        const GraphSelection(annotationIds: {'ann1'}),
      );
      expect(entry.annotations.single.text, 'Hello');
    });

    test('PasteCommand id-remaps and offsets pasted annotations; revert removes them', () {
      final entry = ClipboardEntry(annotations: [annotation]);
      final command = PasteCommand(entry, offset: const Point2D(5, 5));
      final after = command.apply(session);
      expect(command.pastedAnnotationIds, hasLength(1));
      final pastedId = command.pastedAnnotationIds.single;
      expect(pastedId, isNot('ann1'), reason: 'fresh id generated');
      final pasted = after.layout.annotationOf(pastedId)!;
      expect(pasted.position, const Point2D(15, 25));
      expect(pasted.text, 'Hello');

      final reverted = command.revert(after);
      expect(reverted.layout.annotationOf(pastedId), isNull);
    });

    test('DeleteManyCommand deletes annotations and restores them on revert', () {
      final withAnnotation = session.copyWith(layout: session.layout.withAnnotation(annotation));
      final command = DeleteManyCommand(annotationIds: {'ann1'});
      final after = command.apply(withAnnotation);
      expect(after.layout.annotationOf('ann1'), isNull);

      final reverted = command.revert(after);
      expect(reverted.layout.annotationOf('ann1'), annotation);
    });
  });
}
