//
//  ToolbarControls.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/16.
//

import SwiftUI

struct ToolbarControls: View {
    @Binding var isTorchEnabled: Bool
    @Binding var isSpeaking: Bool
    @ObservedObject var settingsManager: SettingsManager
    var cameraPermissionGranted: Bool
    var toggleTorch: () -> Void
    var toggleSpeech: () -> Void
    var openSettings: () -> Void

    var body: some View {
        HStack {
            Button(action: toggleTorch) {
                Image(systemName: isTorchEnabled ? "bolt.circle" : "bolt.slash.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel(isTorchEnabled ? "Turn off flashlight" : "Turn on flashlight")
            .accessibilityHint("Double tap to toggle the flashlight.")

            Button(action: toggleSpeech) {
                Image(
                    systemName: settingsManager.speechEnabled
                        ? "speaker.circle" : "speaker.slash.circle"
                )
                .font(.system(size: 16))
                .foregroundStyle(.white)
            }
            .accessibilityLabel(settingsManager.speechEnabled ? "Disable speech" : "Enable speech")
            .accessibilityHint("Double tap to toggle speech output.")
        }
        .disabled(!cameraPermissionGranted)
    }
}
