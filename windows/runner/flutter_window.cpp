#include "flutter_window.h"

#include <optional>
#include <string>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

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
  RegisterMediaKeys();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  UnregisterMediaKeys();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_HOTKEY && flutter_controller_) {
    const char* action = nullptr;
    switch (wparam) {
      case 1:
        action = "playPause";
        break;
      case 2:
        action = "stop";
        break;
      case 3:
        action = "next";
        break;
      case 4:
        action = "previous";
        break;
    }

    if (action != nullptr) {
      flutter::MethodChannel<> channel(
          flutter_controller_->engine()->messenger(),
          "com.tuneify/media_keys", &flutter::StandardMethodCodec::GetInstance());
      channel.InvokeMethod(
          "mediaKey",
          std::make_unique<flutter::EncodableValue>(std::string(action)));
      return 0;
    }
  }

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
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::RegisterMediaKeys() {
  HWND window = GetHandle();
  media_keys_registered_ = true;
  const bool all_registered =
      RegisterHotKey(window, 1, MOD_NOREPEAT, VK_MEDIA_PLAY_PAUSE) &&
      RegisterHotKey(window, 2, MOD_NOREPEAT, VK_MEDIA_STOP) &&
      RegisterHotKey(window, 3, MOD_NOREPEAT, VK_MEDIA_NEXT_TRACK) &&
      RegisterHotKey(window, 4, MOD_NOREPEAT, VK_MEDIA_PREV_TRACK);

  if (!all_registered) {
    UnregisterMediaKeys();
  }
}

void FlutterWindow::UnregisterMediaKeys() {
  if (!media_keys_registered_) {
    return;
  }

  HWND window = GetHandle();
  UnregisterHotKey(window, 1);
  UnregisterHotKey(window, 2);
  UnregisterHotKey(window, 3);
  UnregisterHotKey(window, 4);
  media_keys_registered_ = false;
}
