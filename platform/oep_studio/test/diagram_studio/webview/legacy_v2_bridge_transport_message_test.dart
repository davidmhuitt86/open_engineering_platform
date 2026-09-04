import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/webview/legacy_v2_bridge_transport.dart';

/// AP-DIAGRAM-V2-WEBVIEW-001 — message-model tests for the transport
/// layer. Deliberately does not construct a `WebviewController` or a
/// `LegacyV2BridgeTransport` (no WebView internals) — only the pure
/// `fromJson` parsing this task's own message model requires.
void main() {
  group('V2ModuleMovedMessage.fromJson', () {
    test('decodes id/x/y from a moduleMoved payload', () {
      final message = V2ModuleMovedMessage.fromJson(
          {'id': 'cdi-unit', 'x': 120, 'y': 80.5});
      expect(message.v2ModuleId, 'cdi-unit');
      expect(message.x, 120.0);
      expect(message.y, 80.5);
    });

    test('accepts integer x/y (V2 sends whole-pixel grid-snapped values)', () {
      final message =
          V2ModuleMovedMessage.fromJson({'id': 'battery', 'x': 0, 'y': 0});
      expect(message.x, 0.0);
      expect(message.y, 0.0);
    });
  });

  group('V2ModuleCreatedMessage.fromJson', () {
    test('decodes id/label/category/x/y from a moduleCreated payload', () {
      final message = V2ModuleCreatedMessage.fromJson({
        'id': 'gnd-1',
        'label': 'Ground Point',
        'category': 'ground',
        'x': 10,
        'y': 20,
      });
      expect(message.v2ModuleId, 'gnd-1');
      expect(message.label, 'Ground Point');
      expect(message.category, 'ground');
      expect(message.x, 10.0);
      expect(message.y, 20.0);
    });
  });

  group('V2ModuleDeletedMessage.fromJson', () {
    test('decodes id from a moduleDeleted payload', () {
      final message = V2ModuleDeletedMessage.fromJson({'id': 'gnd-1'});
      expect(message.v2ModuleId, 'gnd-1');
    });
  });

  group('V2ModulePropertiesChangedMessage.fromJson', () {
    test('decodes id/label/category from a modulePropertiesChanged payload',
        () {
      final message = V2ModulePropertiesChangedMessage.fromJson({
        'id': 'gnd-1',
        'label': 'Chassis Ground',
        'category': 'ground',
      });
      expect(message.v2ModuleId, 'gnd-1');
      expect(message.label, 'Chassis Ground');
      expect(message.category, 'ground');
    });
  });

  group('V2WireCreatedMessage.fromJson', () {
    test(
        'decodes id/endpoints/terminals/label/color from a wireCreated payload',
        () {
      final message = V2WireCreatedMessage.fromJson({
        'id': 'wire-1',
        'fromModuleId': 'gnd-1',
        'fromTerminal': 'A',
        'toModuleId': 'gnd-2',
        'toTerminal': 'B',
        'label': 'Bridging Wire',
        'color': 'G',
      });
      expect(message.v2WireId, 'wire-1');
      expect(message.fromModuleId, 'gnd-1');
      expect(message.fromTerminal, 'A');
      expect(message.toModuleId, 'gnd-2');
      expect(message.toTerminal, 'B');
      expect(message.label, 'Bridging Wire');
      expect(message.color, 'G');
    });
  });

  group('V2StatusMessage.fromJson', () {
    test('decodes a full status snapshot', () {
      final status = V2StatusMessage.fromJson(
          {'selM': 'ecm', 'moduleCount': 12, 'wireCount': 34});
      expect(status.selectedModuleId, 'ecm');
      expect(status.moduleCount, 12);
      expect(status.wireCount, 34);
    });

    test('decodes a snapshot with no module selected', () {
      final status = V2StatusMessage.fromJson(
          {'selM': null, 'moduleCount': 12, 'wireCount': 34});
      expect(status.selectedModuleId, isNull);
    });

    // AP-DIAGRAM-V2-BRIDGE-007 — `editMode` is V2's own global
    // (`js/editor/module-editor.js`'s `toggleEdit()`), display-only; see
    // the interaction-parity architecture doc for why it is decoded here
    // but never consulted by any handler.
    test('decodes editMode true/false', () {
      expect(
          V2StatusMessage.fromJson({
            'selM': null,
            'moduleCount': 0,
            'wireCount': 0,
            'editMode': true
          }).editMode,
          isTrue);
      expect(
          V2StatusMessage.fromJson({
            'selM': null,
            'moduleCount': 0,
            'wireCount': 0,
            'editMode': false
          }).editMode,
          isFalse);
    });

    test(
        'editMode defaults to null when absent from the payload (older injected script, or V2 not yet initialized)',
        () {
      final status = V2StatusMessage.fromJson(
          {'selM': null, 'moduleCount': 0, 'wireCount': 0});
      expect(status.editMode, isNull);
    });
  });
}
