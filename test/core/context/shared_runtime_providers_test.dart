import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/services/engineering_project_service.dart';
import 'package:oep_studio/diagram_studio/instruments/multimeter/multimeter_controller.dart';
import 'package:oep_studio/diagram_studio/simulation/diagram_simulation_service.dart';

/// OEP Context & Capability Service -- Phase 2, Part 10 "State
/// identity": proves `diagramSimulationServiceProvider`/
/// `multimeterRuntimeServiceProvider` each expose exactly ONE
/// authoritative runtime instance -- the specific failure mode this
/// phase's own brief calls out by name ("Do not accidentally create
/// DiagramStudio MultimeterController A and Shared MultimeterController B").
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('diagramSimulationServiceProvider returns null before the engine is bootstrapped -- never a fabricated instance', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(engineeringProjectServiceProvider).engine, isNull, reason: 'no diagram action has happened yet');
    expect(container.read(diagramSimulationServiceProvider), isNull);
  });

  test('multimeterRuntimeServiceProvider returns null before the engine is bootstrapped, for the same reason', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(multimeterRuntimeServiceProvider), isNull);
  });

  test('reading diagramSimulationServiceProvider twice returns the SAME instance, not two divergent ones', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(engineeringProjectServiceProvider.notifier).ensureEngineStarted();

    final first = container.read(diagramSimulationServiceProvider);
    final second = container.read(diagramSimulationServiceProvider);
    expect(first, isNotNull);
    expect(identical(first, second), isTrue);
  });

  test('reading multimeterRuntimeServiceProvider twice returns the SAME instance -- one authoritative Multimeter', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(engineeringProjectServiceProvider.notifier).ensureEngineStarted();

    final first = container.read(multimeterRuntimeServiceProvider);
    final second = container.read(multimeterRuntimeServiceProvider);
    expect(first, isNotNull);
    expect(identical(first, second), isTrue,
        reason: 'this is exactly the "MultimeterController A vs. B" failure mode this phase must prevent');
  });

  test('a mutation through one read of the shared Multimeter is visible through a later, independent read', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(engineeringProjectServiceProvider.notifier).ensureEngineStarted();

    final multimeter = container.read(multimeterRuntimeServiceProvider)!;
    multimeter.setType(multimeter.selectedType); // no-op mutation-shaped call to prove liveness
    multimeter.setProbeA(null);

    // A completely separate `container.read` call -- simulating a
    // different widget/service reaching the provider independently --
    // must observe the exact same object, not a fresh reconstruction.
    final laterRead = container.read(multimeterRuntimeServiceProvider)!;
    expect(identical(multimeter, laterRead), isTrue);
  });
}
