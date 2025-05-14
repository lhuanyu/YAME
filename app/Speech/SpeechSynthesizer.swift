//
//  SpeechSynthesizer.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/14.
//

import AVFoundation

final class SpeechSynthesizer: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    static let shared = SpeechSynthesizer()
    static private(set) var isSpeaking: Bool = false {
        didSet {
            NotificationCenter.default.post(name: .speechSynthesizerSpeakingChanged, object: nil)
        }
    }
    private let synthesizer = AVSpeechSynthesizer()
    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    struct Config {
        var rate: Float = AVSpeechUtteranceDefaultSpeechRate
        var volume: Float = 1.0
        var pitchMultiplier: Float = 1.0
        var language: String = Locale.current.identifier
    }

    let voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)

    private var currentConfig = Config()
    private var speechFinishedContinuation: CheckedContinuation<Void, Never>?

    func speak(_ text: String, config: Config? = nil) {
        print("Speaking: \(text)")
        
        let utterance = AVSpeechUtterance(string: text)
        let cfg = config ?? currentConfig
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

    // MARK: - AVSpeechSynthesizerDelegate 可选实现
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance
    ) {
        // 可扩展：播报完成回调
        speechFinishedContinuation?.resume()
        speechFinishedContinuation = nil
        Self.isSpeaking = false
    }
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance
    ) {
        // 可扩展：播报取消回调
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
