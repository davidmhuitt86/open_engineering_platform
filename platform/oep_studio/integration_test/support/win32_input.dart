// PRODUCT-READINESS-011 — real Windows OS-level input injection.
//
// This file exists ONLY under `integration_test/` (never imported from
// `lib/`) and is the smallest mechanism that satisfies §3/§5 of the
// PRODUCT-READINESS-011 spec: locate the app's own real, top-level HWND
// (there is exactly one — WebView2 is composition-hosted into a Flutter
// GPU texture, per this phase's own audit, not a separate child HWND —
// see the PRODUCT-READINESS-011 report's "WebView2 HWND Discovery
// Approach" section for the full architectural finding) and inject real
// `SendInput` mouse/keyboard events at real screen coordinates. This is
// not a bypass of the production interaction path: Windows itself
// dispatches these events through the normal input queue into the real
// window, indistinguishable (from the OS's point of view) from a human
// clicking — the app's own Flutter engine then performs its own real
// hit-testing and routes the event to whichever widget (a native Flutter
// widget, or the WebView2-hosting texture) occupies that screen point.
//
// Fails LOUDLY (throws) if the window cannot be found or a coordinate
// cannot be resolved — never silently falls back to a synthetic/fake
// interaction (§5's own explicit requirement).
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// The real, top-level native window `oep_studio.exe` creates
/// (`windows/runner/main.cpp`'s own `window.Create(L"oep_studio", ...)`
/// call — confirmed by this phase's own audit as the literal native
/// window title, distinct from the Flutter-level `MaterialApp.title`
/// ("OEP Studio"), which is never what a real `FindWindow` call sees).
class Win32AppWindow {
  const Win32AppWindow(this.hwnd);

  final int hwnd;

  /// Locates the real, running app's own top-level HWND by its real
  /// native window title. Throws a [StateError] (never returns a null/
  /// fake handle) if it cannot be found — §5: "must fail clearly if the
  /// expected... HWND cannot be found."
  static Win32AppWindow findRequired({String title = 'oep_studio'}) {
    final titlePtr = title.toNativeUtf16();
    try {
      final hwnd = FindWindow(nullptr, titlePtr);
      if (hwnd == 0) {
        throw StateError(
          'Win32AppWindow.findRequired: no top-level window titled "$title" was found. '
          'The real oep_studio.exe process must already be running (this integration_test '
          'binary IS that real process, per Flutter\'s own desktop integration_test '
          'architecture) before any real OS-level input can be injected.',
        );
      }
      return Win32AppWindow(hwnd);
    } finally {
      calloc.free(titlePtr);
    }
  }

  /// Attempts to bring the window to the foreground -- real OS input
  /// (`SendInput`) is delivered to whatever window currently has
  /// focus/is under the cursor, so a background window would otherwise
  /// silently receive nothing. Best-effort only: Windows enforces a
  /// foreground-lock restriction (only the process that most recently
  /// received real user input may call `SetForegroundWindow`
  /// successfully) that a headless/automation desktop session can
  /// legitimately trip even when this IS the only real top-level window
  /// and IS already receiving real input — so failure here does not
  /// throw, it only reports whether the call succeeded, and callers must
  /// not assume success is required for `SendInput` to reach this window.
  bool bringToForeground() {
    return SetForegroundWindow(hwnd) != 0;
  }

  /// The real DPI scale factor Flutter itself uses to map its own
  /// LOGICAL pixel coordinate space onto the real, PHYSICAL screen pixel
  /// space this window renders into (`GetDpiForWindow`/96.0 — 96 is the
  /// Win32-defined "100%" reference DPI). `tester.getCenter(finder)` and
  /// every other `WidgetTester` geometry query return LOGICAL pixels;
  /// every real Win32 screen coordinate (`SetCursorPos`, `ClientToScreen`)
  /// is PHYSICAL pixels -- this factor is the one, real conversion
  /// between them, never a guessed/hardcoded scale.
  double get dpiScale => GetDpiForWindow(hwnd) / 96.0;

  /// Converts a LOGICAL (Flutter) client-area offset into an absolute
  /// SCREEN coordinate, via the real `ClientToScreen` Win32 call (never a
  /// hand-computed window-position guess) and the real DPI scale above.
  ({int x, int y}) clientLogicalToScreen(double logicalX, double logicalY) {
    final scale = dpiScale;
    final point = calloc<POINT>();
    try {
      point.ref.x = (logicalX * scale).round();
      point.ref.y = (logicalY * scale).round();
      final ok = ClientToScreen(hwnd, point);
      if (ok == 0) {
        throw StateError('Win32AppWindow.clientLogicalToScreen: ClientToScreen failed for hwnd=$hwnd.');
      }
      return (x: point.ref.x, y: point.ref.y);
    } finally {
      calloc.free(point);
    }
  }

  /// A real, single left-mouse-button click (`SetCursorPos` + a real
  /// `SendInput` down/up pair) at the LOGICAL client-area position
  /// [logicalX]/[logicalY] -- this is the actual OS input-injection path,
  /// not `WidgetTester.tap`'s own synthetic, in-engine pointer-event
  /// delivery.
  void realClickAtLogical(double logicalX, double logicalY) {
    final screen = clientLogicalToScreen(logicalX, logicalY);
    final posResult = SetCursorPos(screen.x, screen.y);
    if (posResult == 0) {
      throw StateError('Win32AppWindow.realClickAtLogical: SetCursorPos($screen) failed.');
    }
    _sendMouseInput(MOUSEEVENTF_LEFTDOWN);
    // A real human click has a non-zero press duration; give the gesture
    // arena a real gap between down and up rather than back-to-back
    // synthetic events sent in the same instant.
    sleep(const Duration(milliseconds: 60));
    _sendMouseInput(MOUSEEVENTF_LEFTUP);
  }

  void _sendMouseInput(int flags) {
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_MOUSE;
      final mi = calloc<MOUSEINPUT>();
      try {
        mi.ref.dx = 0;
        mi.ref.dy = 0;
        mi.ref.mouseData = 0;
        mi.ref.dwFlags = flags;
        mi.ref.time = 0;
        mi.ref.dwExtraInfo = 0;
        input.ref.mi = mi.ref;
      } finally {
        calloc.free(mi);
      }
      final sent = SendInput(1, input, sizeOf<INPUT>());
      if (sent != 1) {
        throw StateError('Win32AppWindow._sendMouseInput: SendInput reported $sent events sent (expected 1).');
      }
    } finally {
      calloc.free(input);
    }
  }

  /// Real keyboard text entry via `SendInput`'s Unicode-packet mode
  /// (`KEYEVENTF_UNICODE`) -- delivers each real character as a genuine
  /// OS keyboard event, not a synthetic `TextEditingValue` write.
  void typeTextReal(String text) {
    for (final charCode in text.runes) {
      _sendUnicodeKey(charCode, keyUp: false);
      _sendUnicodeKey(charCode, keyUp: true);
    }
  }

  void _sendUnicodeKey(int charCode, {required bool keyUp}) {
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_KEYBOARD;
      final ki = calloc<KEYBDINPUT>();
      try {
        ki.ref.wVk = 0;
        ki.ref.wScan = charCode;
        ki.ref.dwFlags = KEYEVENTF_UNICODE | (keyUp ? KEYEVENTF_KEYUP : 0);
        ki.ref.time = 0;
        ki.ref.dwExtraInfo = 0;
        input.ref.ki = ki.ref;
      } finally {
        calloc.free(ki);
      }
      final sent = SendInput(1, input, sizeOf<INPUT>());
      if (sent != 1) {
        throw StateError('Win32AppWindow._sendUnicodeKey: SendInput reported $sent events sent (expected 1).');
      }
    } finally {
      calloc.free(input);
    }
  }
}
