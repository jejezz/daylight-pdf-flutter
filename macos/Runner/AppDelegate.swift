import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override init() {
    super.init()
    // Finder가 여는 파일(더블클릭, "다음으로 열기", Dock에 끌어놓기)은 시작하자마자 올 수 있으므로 일찍 등록한다.
    addApplicationLifecycleDelegate(IncomingFilesBridge.shared)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

/// macOS가 이 앱으로 연 파일을 Dart(`lib/platform/incoming_files.dart`)에 넘긴다.
/// macOS는 명령줄 인자로 파일을 주지 않고 `application(_:open:)`으로 준다. FlutterAppDelegate가 그것을
/// `handleOpenURLs`로 넘겨 주므로 그 훅만 쓴다(기본 앱으로 지정하는 API는 부르지 않는다 — 사용자가 Finder에서 고른다).
/// Dart가 `initialFiles`를 부르기 전에 온 파일은 모아 두었다가 그때 넘기고, 그 뒤에 온 파일은 `filesOpened`로 보낸다.
final class IncomingFilesBridge: NSObject, FlutterAppLifecycleDelegate {
  static let shared = IncomingFilesBridge()

  private var channel: FlutterMethodChannel?
  private var pending: [String] = []
  private var dartReady = false

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "art.zoomon.daylightpdf/incoming", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self, call.method == "initialFiles" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.dartReady = true
      let files = self.pending
      self.pending = []
      result(files)
    }
    self.channel = channel
  }

  // 셀렉터를 못 박아 둔다: Swift가 ObjC 이름 `handleOpenURLs:`를 `handleOpen(_:)`로 바꿔 들여오므로, 이름이 어긋나 안 불리는 일이 없게.
  @objc(handleOpenURLs:)
  func handleOpen(_ urls: [URL]) -> Bool {
    let paths = urls.filter { $0.isFileURL }.map { $0.path }
    if paths.isEmpty { return false }
    if dartReady, let channel = channel {
      channel.invokeMethod("filesOpened", arguments: paths)
    } else {
      pending.append(contentsOf: paths)
    }
    return true
  }
}
