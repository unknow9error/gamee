import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let speechSynthesizer = AVSpeechSynthesizer()
  private var speechChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "tiny_trails/speech",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    speechChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(false)
        return
      }
      let arguments = call.arguments as? [String: Any]
      let language = arguments?["language"] as? String ?? "ru"
      switch call.method {
      case "isAvailable":
        result(self.voice(for: language) != nil)
      case "speak":
        guard let text = arguments?["text"] as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.count <= 1000,
              let voice = self.voice(for: language) else {
          result(false)
          return
        }
        self.speechSynthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = 0.43
        utterance.pitchMultiplier = 1.06
        utterance.volume = 0.8
        self.speechSynthesizer.speak(utterance)
        result(true)
      case "stop":
        self.speechSynthesizer.stopSpeaking(at: .immediate)
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func voice(for language: String) -> AVSpeechSynthesisVoice? {
    let locales = ["ru": "ru-RU", "kk": "kk-KZ", "en": "en-US"]
    guard let locale = locales[language] else { return nil }
    let installed = AVSpeechSynthesisVoice.speechVoices()
    return installed.first(where: { $0.language == locale })
      ?? installed.first(where: { $0.language.hasPrefix(language + "-") })
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    speechSynthesizer.stopSpeaking(at: .immediate)
    super.applicationWillResignActive(application)
  }
}
