import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/instruments/core/engineering_instrument.dart';

class _FakeInstrument extends EngineeringInstrument {
  const _FakeInstrument(this.id);

  @override
  final String id;

  @override
  String get title => 'Fake $id';

  @override
  IconData get icon => Icons.science_outlined;

  @override
  Widget buildPanel(BuildContext context) => Text('panel-$id');
}

void main() {
  test('InstrumentRegistry registers and looks up instruments by id', () {
    final registry = InstrumentRegistry();
    expect(registry.isEmpty, isTrue);

    registry.register(const _FakeInstrument('a'));
    expect(registry.isEmpty, isFalse);
    expect(registry.all.length, 1);
    expect(registry.byId('a')?.title, 'Fake a');
    expect(registry.byId('missing'), isNull);
  });

  test('InstrumentRegistry throws on duplicate id registration', () {
    final registry = InstrumentRegistry();
    registry.register(const _FakeInstrument('a'));
    expect(() => registry.register(const _FakeInstrument('a')), throwsStateError);
  });

  test('InstrumentRegistry.unregister removes and notifies listeners', () {
    final registry = InstrumentRegistry();
    registry.register(const _FakeInstrument('a'));
    var notified = 0;
    registry.addListener(() => notified++);

    registry.unregister('a');
    expect(registry.isEmpty, isTrue);
    expect(notified, 1);

    // Unregistering something already gone must not notify again.
    registry.unregister('a');
    expect(notified, 1);
  });

  test('EngineeringInstrument.shortcutLabel defaults to null', () {
    expect(const _FakeInstrument('a').shortcutLabel, isNull);
  });
}
