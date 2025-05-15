//
//  SpeechSynthesizer.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/14.
//

import AVFoundation
import SwiftUI

final class SpeechSynthesizer: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    static let shared = SpeechSynthesizer()

    var isEnabled: Bool {
        ///Get AppStorage value
        UserDefaults.standard.bool(forKey: "speechEnabled")
    }

    static private(set) var isSpeaking: Bool = false {
        didSet {
            NotificationCenter.default.post(name: .speechSynthesizerSpeakingChanged, object: nil)
        }
    }
    private let synthesizer = AVSpeechSynthesizer()
    private override init() {
        super.init()
        synthesizer.delegate = self
        // Load current configuration during initialization
        currentConfig = Config()
    }

    struct Config {
        var rate: Float = AVSpeechUtteranceDefaultSpeechRate
        var volume: Float = 1.0
        var pitchMultiplier: Float = 1.0
        var language: String = Locale.current.identifier

        init() {
            // Read default settings from UserDefaults
            if let savedRate = UserDefaults.standard.object(forKey: "speechRate") as? Double {
                rate = Float(savedRate)
            }
        }
    }

    let voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)

    private var currentConfig = Config()
    private var speechFinishedContinuation: CheckedContinuation<Void, Never>?

    func speak(_ text: String, config: Config? = nil) {
        print("Speaking: \(text)")

        let cfg = config ?? currentConfig
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = cfg.rate
        utterance.volume = cfg.volume
        utterance.pitchMultiplier = cfg.pitchMultiplier
        utterance.voice = voice
        Self.isSpeaking = true
        synthesizer.speak(utterance)
    }

    @MainActor
    func speakAndWait(_ text: String, config: Config? = nil) async {
        await withCheckedContinuation { continuation in
            self.speechFinishedContinuation = continuation
            self.speak(text, config: config)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func updateConfig(_ config: Config) {
        currentConfig = config
    }

    // MARK: - AVSpeechSynthesizerDelegate Optional Implementation
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance
    ) {
        // Extendable: Speech completion callback
        speechFinishedContinuation?.resume()
        speechFinishedContinuation = nil
        Self.isSpeaking = false
    }
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance
    ) {
        // Extendable: Speech cancellation callback
        speechFinishedContinuation?.resume()
        speechFinishedContinuation = nil
        Self.isSpeaking = false
    }
}

// 通知名称扩展
extension Notification.Name {
    static let speechSynthesizerSpeakingChanged = Notification.Name(
        "speechSynthesizerSpeakingChanged")
}
