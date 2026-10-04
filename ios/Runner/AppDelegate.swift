import Flutter
import LocalAuthentication
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var securityChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "app.kasaran/local_security",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    securityChannel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "hasDeviceLock":
        var error: NSError?
        let configured = LAContext().canEvaluatePolicy(
          .deviceOwnerAuthentication,
          error: &error
        )
        result(configured)
      case "protectDirectory", "protectFile":
        guard let args = call.arguments as? [String: String],
              let path = args["path"], self.isPrivatePath(path) else {
          result(FlutterError(code: "UNSAFE_PATH", message: "Local database path is not private", details: nil))
          return
        }
        do {
          try self.protectAndExclude(path)
          result(nil)
        } catch {
          result(FlutterError(code: "FILE_PROTECTION", message: "Local database file protection failed", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func isPrivatePath(_ path: String) -> Bool {
    guard let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      return false
    }
    let candidate = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    let privateRoot = root.resolvingSymlinksInPath().standardizedFileURL.path
    return candidate == privateRoot || candidate.hasPrefix(privateRoot + "/")
  }

  private func protectAndExclude(_ path: String) throws {
    guard FileManager.default.fileExists(atPath: path) else {
      throw CocoaError(.fileNoSuchFile)
    }
    try FileManager.default.setAttributes(
      [.protectionKey: FileProtectionType.complete], ofItemAtPath: path
    )
    var url = URL(fileURLWithPath: path)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try url.setResourceValues(values)
  }
}
