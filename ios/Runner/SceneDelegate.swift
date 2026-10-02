import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// Mirrors the Dart side of `pubget/fan_work_reader`.
  ///
  /// iOS has no equivalent of Android's `FLAG_SECURE`. The reader instead asks
  /// for protection, and while the app resigns active an opaque view is laid
  /// over the window: that is when iOS captures the image it keeps in the app
  /// switcher. The shield is removed the moment the app is active again, so it
  /// never hides the reader itself.
  private var readerShield: UIView?
  private var protectRequested = false

  private static let readerChannelName = "pubget/fan_work_reader"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    registerReaderChannel()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(showReaderShield),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(hideReaderShield),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  private func registerReaderChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: SceneDelegate.readerChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setProtected" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.setProtected(call.arguments as? Bool ?? false)
      result(nil)
    }
  }

  private func setProtected(_ enabled: Bool) {
    protectRequested = enabled
    if !enabled {
      hideReaderShield()
    }
  }

  @objc private func showReaderShield() {
    guard protectRequested, readerShield == nil, let window = window else { return }
    let shield = UIView(frame: window.bounds)
    shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    shield.backgroundColor = .systemBackground
    window.addSubview(shield)
    readerShield = shield
  }

  @objc private func hideReaderShield() {
    readerShield?.removeFromSuperview()
    readerShield = nil
  }
}
