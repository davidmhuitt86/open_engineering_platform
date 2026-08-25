import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'web_browser_settings.dart';
import 'web_browser_settings_storage.dart';

/// One shared, app-wide [WebBrowserSettings] instance — read by every
/// [WebSurfaceView] tab and written by its settings menu. Starts at the
/// defaults and repopulates itself once the persisted file loads (the
/// same "start default, restore asynchronously" shape
/// `workspaceTabsControllerProvider` already established), so no widget
/// needs to await anything to render.
class WebBrowserSettingsNotifier extends Notifier<WebBrowserSettings> {
  WebBrowserSettingsNotifier({WebBrowserSettingsStorage storage = const WebBrowserSettingsStorage()}) : _storage = storage;

  final WebBrowserSettingsStorage _storage;

  /// Guards against the same race `WorkspaceTabsController.restore()`
  /// already guards against: [build]'s own async restore is in flight
  /// the moment this notifier is created, so a real [update] call
  /// landing before that load resolves must win — otherwise the restore
  /// would overwrite the user's own, later, explicit change back to
  /// whatever was on disk before it.
  bool _userChangedBeforeRestore = false;

  @override
  WebBrowserSettings build() {
    unawaited(_restore());
    return const WebBrowserSettings();
  }

  Future<void> _restore() async {
    final loaded = await _storage.load();
    if (_userChangedBeforeRestore) return;
    state = loaded;
  }

  void update({String? homepageUrl, bool? searchOnTypedText}) {
    _userChangedBeforeRestore = true;
    state = state.copyWith(homepageUrl: homepageUrl, searchOnTypedText: searchOnTypedText);
    unawaited(_storage.save(state));
  }
}

final webBrowserSettingsProvider = NotifierProvider<WebBrowserSettingsNotifier, WebBrowserSettings>(
  WebBrowserSettingsNotifier.new,
);
