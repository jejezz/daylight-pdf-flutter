#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <cwchar>

#include "flutter_window.h"
#include "utils.h"

// Windows는 기본으로 Impeller를 끈다(Skia): 켜면 창이 뜨기까지 약 1.5초 더 걸렸다(릴리스 빌드 측정, CLAUDE.md 참고).
// 환경변수 DAYLIGHT_IMPELLER 로 바꿔 시험할 수 있다: 1/true = 켬, 0/false = 끔, 없으면 끔.
// [열기]로 띄우는 새 창(자식 프로세스)도 환경변수를 물려받으므로 같은 설정으로 뜬다.
static flutter::ImpellerSwitch ImpellerSwitchFromEnvironment() {
  wchar_t value[16] = {};
  const DWORD length = ::GetEnvironmentVariableW(L"DAYLIGHT_IMPELLER", value, 16);
  if (length == 0 || length >= 16) return flutter::ImpellerSwitch::Disabled;
  if (wcscmp(value, L"0") == 0 || _wcsicmp(value, L"false") == 0) return flutter::ImpellerSwitch::Disabled;
  if (wcscmp(value, L"1") == 0 || _wcsicmp(value, L"true") == 0) return flutter::ImpellerSwitch::Enabled;
  return flutter::ImpellerSwitch::Disabled;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));
  project.set_impeller_switch(ImpellerSwitchFromEnvironment());

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Daylight PDF", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
