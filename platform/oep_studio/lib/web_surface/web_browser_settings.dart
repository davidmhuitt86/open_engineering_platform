/// User-configurable behavior for generic Web Surface tabs
/// ([WebSurfaceView]) — deliberately just two fields, mirroring every
/// other "small JSON, write on every change" settings shape already in
/// this codebase (`WorkspaceTabsStorage`, `WebSurfaceTabsStorage`).
///
/// [homepageUrl] is what a brand-new blank Web Surface tab loads
/// (previously hard-coded to `about:blank`). [searchOnTypedText]
/// controls how the address bar interprets text that isn't itself a
/// URL: when `true`, it's sent to a Google search; when `false`, it's
/// treated as a literal address (the previous, only behavior).
class WebBrowserSettings {
  const WebBrowserSettings({this.homepageUrl = 'about:blank', this.searchOnTypedText = true});

  final String homepageUrl;
  final bool searchOnTypedText;

  WebBrowserSettings copyWith({String? homepageUrl, bool? searchOnTypedText}) => WebBrowserSettings(
        homepageUrl: homepageUrl ?? this.homepageUrl,
        searchOnTypedText: searchOnTypedText ?? this.searchOnTypedText,
      );

  Map<String, Object?> toJson() => {'homepageUrl': homepageUrl, 'searchOnTypedText': searchOnTypedText};

  static WebBrowserSettings fromJson(Object? json) {
    if (json is! Map) return const WebBrowserSettings();
    final homepageUrl = json['homepageUrl'];
    final searchOnTypedText = json['searchOnTypedText'];
    return WebBrowserSettings(
      homepageUrl: homepageUrl is String && homepageUrl.trim().isNotEmpty ? homepageUrl : 'about:blank',
      searchOnTypedText: searchOnTypedText is bool ? searchOnTypedText : true,
    );
  }
}
