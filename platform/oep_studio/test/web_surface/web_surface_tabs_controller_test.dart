import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/web_surface/web_surface.dart';
import 'package:oep_studio/web_surface/web_surface_tabs_controller.dart';

/// AP-STUDIO-WEB-SURFACE-001 — tab add/activate/close semantics, tested
/// against the plain-Dart controller directly (no widget pump needed,
/// unlike `DiagramTabsController`'s own Riverpod-backed tests, since
/// this controller is deliberately not Riverpod-based — see its own doc
/// comment).
void main() {
  WebSurface surface(String id, {String url = 'https://example.com'}) =>
      WebSurface(id: id, title: id, initialUrl: url);

  test('starts empty when constructed with no initial surfaces', () {
    final tabs = WebSurfaceTabsController();
    expect(tabs.surfaces, isEmpty);
    expect(tabs.activeId, isNull);
    expect(tabs.active, isNull);
  });

  test('adding a surface activates it by default', () {
    final tabs = WebSurfaceTabsController();
    tabs.add(surface('a'));
    expect(tabs.activeId, 'a');
    tabs.add(surface('b'));
    expect(tabs.activeId, 'b', reason: 'the most recently added surface becomes active');
    expect(tabs.surfaces.map((s) => s.id), ['a', 'b']);
  });

  test('adding with activate:false does not change the active tab', () {
    final tabs = WebSurfaceTabsController();
    tabs.add(surface('a'));
    tabs.add(surface('b'), activate: false);
    expect(tabs.activeId, 'a');
    expect(tabs.surfaces.map((s) => s.id), ['a', 'b']);
  });

  test('activate switches the active tab without touching the list', () {
    final tabs = WebSurfaceTabsController();
    tabs.add(surface('a'));
    tabs.add(surface('b'));
    tabs.activate('a');
    expect(tabs.activeId, 'a');
    expect(tabs.surfaces.length, 2);
  });

  test('activate ignores an unknown id', () {
    final tabs = WebSurfaceTabsController();
    tabs.add(surface('a'));
    tabs.activate('does-not-exist');
    expect(tabs.activeId, 'a');
  });

  test('closing a non-active tab does not change which tab is active', () {
    final tabs = WebSurfaceTabsController();
    tabs.add(surface('a'));
    tabs.add(surface('b'));
    tabs.activate('a');
    tabs.close('b');
    expect(tabs.activeId, 'a');
    expect(tabs.surfaces.map((s) => s.id), ['a']);
  });

  test('closing the active tab activates its left neighbor', () {
    final tabs = WebSurfaceTabsController();
    tabs.add(surface('a'));
    tabs.add(surface('b'));
    tabs.add(surface('c'));
    tabs.activate('b');
    tabs.close('b');
    expect(tabs.activeId, 'a', reason: 'closing the active middle tab should activate the one before it');
    expect(tabs.surfaces.map((s) => s.id), ['a', 'c']);
  });

  test('closing the first (active) tab activates the new first tab', () {
    final tabs = WebSurfaceTabsController();
    tabs.add(surface('a'));
    tabs.add(surface('b'));
    tabs.activate('a');
    tabs.close('a');
    expect(tabs.activeId, 'b');
  });

  test('closing the last remaining tab leaves no active tab', () {
    final tabs = WebSurfaceTabsController();
    tabs.add(surface('a'));
    tabs.close('a');
    expect(tabs.activeId, isNull);
    expect(tabs.surfaces, isEmpty);
  });

  test('local V2-style file:// surface and a remote https:// surface classify independently', () {
    final tabs = WebSurfaceTabsController();
    tabs.add(surface('v2', url: 'file:///repo/reference/legacy_wiring_sim_v2/eke-wiring-sim/index.html'));
    tabs.add(surface('web', url: 'https://example.com'), activate: false);
    expect(tabs.surfaces[0].kind, WebSurfaceKind.local);
    expect(tabs.surfaces[1].kind, WebSurfaceKind.remote);
  });
}
