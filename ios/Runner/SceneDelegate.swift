import Flutter
import UIKit
import UserNotifications

class SceneDelegate: FlutterSceneDelegate {
  /// Must stay in sync with `BootLink._entryKey` on the Dart side, including
  /// the `flutter.` prefix the preferences bridge expects.
  static let entryKey = "flutter.rw_grid_entry"

  private static let directKeys = ["deep_link", "target", "url", "deeplink", "link"]
  private static let nestedKeys = ["payload", "data"]

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard
      let response = connectionOptions.notificationResponse,
      let entry = Self.entry(
        inside: response.notification.request.content.userInfo
      )
    else { return }

    let defaults = UserDefaults.standard
    defaults.set(entry, forKey: Self.entryKey)
    defaults.synchronize()

    #if DEBUG
    NSLog("[mrs:scene] parked launch entry")
    #endif
  }

  private static func entry(inside payload: [AnyHashable: Any]) -> String? {
    if let direct = trimmedValue(in: payload) { return direct }

    for branch in nestedKeys {
      if let nested = payload[branch] as? [AnyHashable: Any],
         let value = trimmedValue(in: nested) {
        return value
      }
    }
    return nil
  }

  private static func trimmedValue(in source: [AnyHashable: Any]) -> String? {
    for key in directKeys {
      guard let raw = source[key] as? String else { continue }
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }
    return nil
  }
}
