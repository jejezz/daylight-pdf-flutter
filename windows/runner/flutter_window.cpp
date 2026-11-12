#include "flutter_window.h"

#include <optional>

// 창을 띄우는 일은 Dart(main.dart)가 맡지만, 그 앞에서 Dart가 실패하거나 멈추면 창 없이 프로세스만 남는다
// (Windows 10 보고). 이 시간 안에 창이 보이지 않으면 러너가 직접 띄운다.
static constexpr UINT_PTR kShowFallbackTimer = 0xDA71;
static constexpr UINT kShowFallbackMs = 10000;

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // window_manager controls when the window is shown (see main.dart: it calls
  // show() only after placement finishes and a post-placement frame renders).
  // Showing here on the first frame would show the window before it moves to
  // its final monitor/scale, causing a flash/resize jump (window_manager
  // README: "Make sure you don't call Show() in windows/runner/flutter_window.cpp").

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  ::SetTimer(GetHandle(), kShowFallbackTimer, kShowFallbackMs, nullptr);

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_TIMER:
      if (wparam == kShowFallbackTimer) {
        ::KillTimer(hwnd, kShowFallbackTimer);
        if (!::IsWindowVisible(hwnd)) {
          ::ShowWindow(hwnd, SW_SHOWNORMAL);
          ::SetForegroundWindow(hwnd);
        }
        return 0;
      }
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
