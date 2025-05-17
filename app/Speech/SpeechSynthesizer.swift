//
//  SpeechSynthesizer.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/14.
//

import AVFoundation
import SwiftUI

final class SpeechSynthesizer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    static let shared = SpeechSynthesizer()

    var isEnabled: Bool {
        SettingsManager.shared.speechEnabled
    }

    @Published var isSpeaking: Bool = false
    
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

        init() {
            // Read default settings from UserDefaults
            if let savedRate = UserDefaults.standard.object(forKey: "speechRate") as? Double {
                rate = Float(savedRate)
            }
        }
    }

    private var currentConfig = Config()
    private var speechFinishedContinuation: CheckedContinuation<Void, Never>?

    func speak(_ text: String, config: Config? = nil) {
        print("Speaking: \(text)")

        let cfg = config ?? currentConfig
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = cfg.rate
        utterance.volume = cfg.volume
        utterance.pitchMultiplier = cfg.pitchMultiplier
        utterance.voice = .siri
        isSpeaking = true
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
        isSpeaking = false
    }
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance
    ) {
        // Extendable: Speech cancellation callback
        speechFinishedContinuation?.resume()
        speechFinishedContinuation = nil
        isSpeaking = false
    }
}

extension AVSpeechSynthesisVoice {

    static var siri: AVSpeechSynthesisVoice? {
        let availableVoices = AVSpeechSynthesisVoice.speechVoices()
        let currentLocaleID = Locale.current.identifier.replacingOccurrences(of: "_", with: "-").lowercased()

        if let exactMatch = availableVoices.first(where: {
            $0.language.lowercased() == currentLocaleID &&
            $0.identifier.lowercased().contains("com.apple.ttsbundle.siri")
        }) {
            return exactMatch
        }

        if let languageCode = Locale.current.languageCode?.lowercased() {
            if let partialMatch = availableVoices.first(where: {
                $0.language.lowercased().hasPrefix(languageCode) &&
                $0.identifier.lowercased().contains("com.apple.ttsbundle.siri")
            }) {
                return partialMatch
            }
        }

        return AVSpeechSynthesisVoice(language: currentLocaleID)
    }
}
