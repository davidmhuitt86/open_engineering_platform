import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/web_surface/web_browser_settings.dart';
import 'package:oep_studio/web_surface/web_browser_settings_provider.dart';
import 'package:oep_studio/web_surface/web_browser_settings_storage.dart';

import '../support/isolated_settings_storage.dart';

/// Focused tests for the browser Homepage/Search-on-typed-text settings
/// added to the generic Web Surface (`WebSurfaceView`). The widget's own
/// address-bar routing logic (`_navigate`/`_looksLikeAddress`) is
/// exercised indirectly here at the settings/persistence layer only —
/// mounting the real WebView-backed widget under `flutter test` is
/// unreliable (the same WebView2-under-test constraint every Diagram
/// Studio test in this suite already documents).
void main() {
  group('WebBrowserSettings', () {
    test('defaults to about:blank and search-on-typed-text enabled', () {
      const settings = WebBrowserSettings();
      expect(settings.homepageUrl, 'about:blank');
      expect(settings.searchOnTypedText, isTrue);
    });

    test('toJson/fromJson round-trips', () {
      const settings = WebBrowserSettings(homepageUrl: 'https://example.com', searchOnTypedText: false);
      final restored = WebBrowserSettings.fromJson(settings.toJson());
      expect(restored.homepageUrl, 'https://example.com');
      expect(restored.searchOnTypedText, isFalse);
    });

    test('fromJson falls back to defaults for malformed/missing data', () {
      expect(WebBrowserSettings.fromJson(null).homepageUrl, 'about:blank');
      expect(WebBrowserSettings.fromJson(<String, Object?>{}).searchOnTypedText, isTrue);
      expect(WebBrowserSettings.fromJson({'homepageUrl': '', 'searchOnTypedText': 'not-a-bool'}).homepageUrl, 'about:blank');
    });

    test('copyWith updates only the given field', () {
      const settings = WebBrowserSettings(homepageUrl: 'https://a.com', searchOnTypedText: true);
      final updated = settings.copyWith(searchOnTypedText: false);
      expect(updated.homepageUrl, 'https://a.com');
      expect(updated.searchOnTypedText, isFalse);
    });
  });

  group('WebBrowserSettingsStorage (real, isolated storage)', () {
    test('load returns defaults when no file exists', () async {
      useIsolatedSettingsStorage();
      final loaded = await const WebBrowserSettingsStorage().load();
      expect(loaded.homepageUrl, 'about:blank');
    });

    test('save then load round-trips through a real file', () async {
      useIsolatedSettingsStorage();
      const storage = WebBrowserSettingsStorage();
      await storage.save(const WebBrowserSettings(homepageUrl: 'https://oep.example', searchOnTypedText: false));

      final loaded = await storage.load();
      expect(loaded.homepageUrl, 'https://oep.example');
      expect(loaded.searchOnTypedText, isFalse);
    });
  });

  group('webBrowserSettingsProvider', () {
    test('update() mutates state and persists via the injected storage', () async {
      final storage = _FakeWebBrowserSettingsStorage();
      final container = ProviderContainer(
        overrides: [webBrowserSettingsProvider.overrideWith(() => WebBrowserSettingsNotifier(storage: storage))],
      );
      addTearDown(container.dispose);

      container.read(webBrowserSettingsProvider.notifier).update(homepageUrl: 'https://home.example', searchOnTypedText: false);
      await pumpEventQueue();

      expect(container.read(webBrowserSettingsProvider).homepageUrl, 'https://home.example');
      expect(container.read(webBrowserSettingsProvider).searchOnTypedText, isFalse);
      expect(storage.saved?.homepageUrl, 'https://home.example');
    });

    test('restores persisted settings once, on first read', () async {
      final storage = _FakeWebBrowserSettingsStorage()
        ..saved = const WebBrowserSettings(homepageUrl: 'https://restored.example', searchOnTypedText: false);
      final container = ProviderContainer(
        overrides: [webBrowserSettingsProvider.overrideWith(() => WebBrowserSettingsNotifier(storage: storage))],
      );
      addTearDown(container.dispose);

      container.read(webBrowserSettingsProvider); // triggers restore
      await pumpEventQueue();

      expect(container.read(webBrowserSettingsProvider).homepageUrl, 'https://restored.example');
    });
  });
}

class _FakeWebBrowserSettingsStorage extends WebBrowserSettingsStorage {
  WebBrowserSettings? saved;

  @override
  Future<WebBrowserSettings> load() async => saved ?? const WebBrowserSettings();

  @override
  Future<void> save(WebBrowserSettings settings) async {
    saved = settings;
  }
}
