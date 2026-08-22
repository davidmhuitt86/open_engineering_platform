import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/web_surface/web_surface.dart';

/// AP-STUDIO-WEB-SURFACE-001 — model-level tests: local/remote
/// classification and bridge-authorization defaults. No WebView
/// internals touched, per this task's own "do not create brittle tests
/// against WebView2's rendering internals" instruction.
void main() {
  group('classifyWebSurfaceUrl', () {
    test('file:// URLs classify as local', () {
      expect(classifyWebSurfaceUrl('file:///C:/some/path/index.html'), WebSurfaceKind.local);
    });

    test('https:// URLs classify as remote', () {
      expect(classifyWebSurfaceUrl('https://example.com'), WebSurfaceKind.remote);
    });

    test('http:// URLs classify as remote', () {
      expect(classifyWebSurfaceUrl('http://example.com'), WebSurfaceKind.remote);
    });

    test('an unparseable/schemeless string classifies as remote (fails safe, not local)', () {
      expect(classifyWebSurfaceUrl('not a url at all'), WebSurfaceKind.remote);
    });
  });

  group('WebSurface', () {
    test('a local surface is never bridge-authorized by default', () {
      final surface = WebSurface(id: 'a', title: 'A', initialUrl: 'file:///x/index.html');
      expect(surface.kind, WebSurfaceKind.local);
      expect(surface.bridgeAuthorized, isFalse, reason: 'arbitrary local content must not automatically gain OEP access');
    });

    test('a remote surface is never bridge-authorized by default', () {
      final surface = WebSurface(id: 'b', title: 'B', initialUrl: 'https://example.com');
      expect(surface.kind, WebSurfaceKind.remote);
      expect(surface.bridgeAuthorized, isFalse);
    });

    test('copyWith preserves kind and bridge authorization, changes only title', () {
      final surface = WebSurface(id: 'c', title: 'Old', initialUrl: 'https://example.com');
      final renamed = surface.copyWith(title: 'New');
      expect(renamed.title, 'New');
      expect(renamed.id, surface.id);
      expect(renamed.kind, surface.kind);
      expect(renamed.bridgeAuthorized, surface.bridgeAuthorized);
    });

    test('defaults to WebSurfaceApplication.generic when not specified', () {
      final surface = WebSurface(id: 'd', title: 'D', initialUrl: 'https://example.com');
      expect(surface.application, WebSurfaceApplication.generic);
      expect(surface.bridgeAuthorized, isFalse);
    });
  });

  group('WebSurface.bridgeAuthorized (AP-STUDIO-WEB-SURFACE-002, structural enforcement)', () {
    test('legacyV2 application is bridge-authorized', () {
      final surface = WebSurface(
        id: 'v2',
        title: 'Legacy V2',
        initialUrl: 'file:///v2/index.html',
        application: WebSurfaceApplication.legacyV2,
      );
      expect(surface.bridgeAuthorized, isTrue);
    });

    test('generic application is never bridge-authorized, even with a local file:// URL', () {
      final surface = WebSurface(
        id: 'local',
        title: 'Local',
        initialUrl: 'file:///v2/index.html',
        application: WebSurfaceApplication.generic,
      );
      expect(surface.bridgeAuthorized, isFalse,
          reason: 'bridgeAuthorized is derived from application alone, not from URL/kind');
    });

    test('copyWith cannot change application (and therefore cannot change bridgeAuthorized)', () {
      final v2 = WebSurface(id: 'v2', title: 'Legacy V2', initialUrl: 'file:///v2/index.html', application: WebSurfaceApplication.legacyV2);
      final renamed = v2.copyWith(title: 'Renamed');
      expect(renamed.application, WebSurfaceApplication.legacyV2);
      expect(renamed.bridgeAuthorized, isTrue);
    });
  });
}
