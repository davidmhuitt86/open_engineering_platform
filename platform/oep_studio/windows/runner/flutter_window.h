#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // The window is created invisible and only shown from the engine's
  // "next frame" callback (OnCreate, below) -- if the engine's first frame
  // never completes (a GPU/rendering-surface init failure, observed on at
  // least one real hybrid-GPU laptop as a window that exists, at the
  // correct size/position, but stays permanently invisible with no error
  // and no crash -- diagnosed via EnumWindows/IsWindowVisible, not
  // reproducible from the Dart side at all), that callback simply never
  // fires and the app looks like it "won't open," forever, with nothing
  // for the user to see or report. This timer is a fallback only: if the
  // window still isn't visible a few seconds after creation, show it
  // anyway, so a rendering failure surfaces as a visibly broken/blank
  // window (something to screenshot and report) instead of a silent,
  // invisible hang indistinguishable from the app never having started.
  static constexpr UINT_PTR kFallbackShowTimerId = 1;
  static constexpr UINT kFallbackShowTimeoutMs = 4000;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
