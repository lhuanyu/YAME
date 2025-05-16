//
//  Promts.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/14.
//

import SwiftUI

struct VisionTask: Codable, Identifiable, Hashable {
    var id: String {
        name
    }

    enum Provider: String, Codable {
        case system
        case user
    }

    var name: String
    var prompt: String
    var promptSuffix: String
    var symbol: String?
    var provider: Provider

}

extension VisionTask {
    static let describeImage = VisionTask(
        name: "Describe Image".localized(),
        prompt: "Describe the image in English.".localized(),
        promptSuffix: "Output should be brief, about 15 words or less.".localized(),
        symbol: "eye",
        provider: .system
    )

    ///Identify rock paper scissors
    static let rockPaperScissors = VisionTask(
        name: "Rock Paper Scissors".localized(),
        prompt: "Identify the hand gesture in the image.".localized(),
        promptSuffix: "Output should be one of 'rock', 'paper', or 'scissors'.".localized(),
        symbol: "hand.wave",
        provider: .system
    )

    ///Recognize text
    static let recognizeText = VisionTask(
        name: "Recognize Text".localized(),
        prompt: "Recognize the text in the image.".localized(),
        promptSuffix: "Output only the text in the image..".localized(),
        symbol: "doc.plaintext",
        provider: .system
    )

    ///Identify traffic signal, provide all information
    static let identifyTrafficSignal = VisionTask(
        name: "Identify Traffic Signal".localized(),
        prompt: "Identify the traffic signal in the image.".localized(),
        promptSuffix: "Output should include the color and shape of the signal.".localized(),
        symbol: "car",
        provider: .system
    )

    ///Facial expression
    static let facialExpression = VisionTask(
        name: "Identify Facial Expression".localized(),
        prompt: "Identify the facial expression in the image.".localized(),
        promptSuffix: "Output should be short and concise.".localized(),
        symbol: "face.smiling".localized(),
        provider: .system
    )

    static let allTasks: [VisionTask] = [
        describeImage,
        identifyTrafficSignal,
        recognizeText,
        facialExpression,
        rockPaperScissors,
    ]

}

enum VisionTaskState: String, CaseIterable {
    case loading
    case idle
    case seeing
    case thinking
    case speaking
    case paused

    var foregroundColor: Color {
        switch self {
        case .loading, .idle, .seeing, .paused:
            return .white
        case .thinking:
            return Color.white
        case .speaking:
            return Color.white
        }
    }

    var backgroundColor: Color {
        switch self {
        case .loading:
            return .secondary.opacity(0.5)
        case .idle:
            return .secondary.opacity(0.5)
        case .seeing:
            return Color.blue.opacity(0.7)
        case .thinking:
            return Color.orange.opacity(0.7)
        case .speaking:
            return Color.green.opacity(0.7)
        case .paused:
            return Color.gray.opacity(0.5)
        }
    }

    var symbolName: String {
        switch self {
        case .loading:
            return ""
        case .idle:
            return "clock.fill"
        case .seeing:
            return "eye.fill"
        case .thinking:
            return "brain.fill"
        case .speaking:
            return "waveform.circle.fill"
        case .paused:
            return "pause.fill"
        }
    }
}


extension String {

    public func localized() -> String {
        return NSLocalizedString(self, comment: "")
    }

}
