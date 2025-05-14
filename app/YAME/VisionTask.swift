//
//  Promts.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/14.
//

import SwiftUI
import Localize_Swift

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
    
    ///识别剪刀石头布
    static let rockPaperScissors = VisionTask(
        name: "Rock Paper Scissors".localized(),
        prompt: "Identify the hand gesture in the image.".localized(),
        promptSuffix: "Output should be one of 'rock', 'paper', or 'scissors'.".localized(),
        symbol: "hand.wave",
        provider: .system
    )
    
    ///数手指
    static let countFingers = VisionTask(
        name: "Count Fingers".localized(),
        prompt: "How many fingers am I holding up?".localized(),
        promptSuffix: "Respond with a single number. If no hands are detected, respond with 0.".localized(),
        symbol: "hand.raised.fingers.spread",
        provider: .system
    )
    
    ///识别文字
    static let recognizeText = VisionTask(
        name: "Recognize Text".localized(),
        prompt: "Recognize the text in the image.".localized(),
        promptSuffix: "Output should be the recognized text.".localized(),
        symbol: "doc.plaintext",
        provider: .system
    )
    
    ///识别交通信号，要给出全部的信息
    static let identifyTrafficSignal = VisionTask(
        name: "Identify Traffic Signal".localized(),
        prompt: "Identify the traffic signal in the image.".localized(),
        promptSuffix: "Output should include the color and shape of the signal.".localized(),
        symbol: "car",
        provider: .system
    )
    
    ///Facial expression
    static let facialExpression = VisionTask(
        name: "Facial Expression".localized(),
        prompt: "Identify the facial expression in the image.".localized(),
        promptSuffix: "Output should be short and concise.".localized(),
        symbol: "face.smiling".localized(),
        provider: .system
    )
    
    static let allTasks: [VisionTask] = [
        describeImage,
        rockPaperScissors,
        countFingers,
        recognizeText,
        identifyTrafficSignal,
        facialExpression
    ]
    
}
