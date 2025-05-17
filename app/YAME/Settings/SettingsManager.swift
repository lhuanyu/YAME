//
//  SettingsManager.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/14.
//


import SwiftUI
import AVFoundation

class SettingsManager: ObservableObject {
    
    @AppStorage("speechEnabled") var speechEnabled = true
    @AppStorage("speechRate") var speechRate: Double = Double(
        AVSpeechUtteranceDefaultSpeechRate)
    
    @AppStorage("subtitleEnabled") var subtitleEnabled = true
    
    static let shared = SettingsManager()
    
}
