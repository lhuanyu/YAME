//
//  BottomControls.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/16.
//

import SwiftUI
import enum Video.CameraType

struct BottomControls: View {
    @Binding var isSpeaking: Bool
    @ObservedObject var settingsManager: SettingsManager
    @Binding var cameraIsRunning: Bool
    @Binding var isTorchEnabled: Bool
    @Binding var selectedCameraType: CameraType
    var permissionGranted: Bool
    var onSpeechToggle: () -> Void
    var onCameraToggle: () -> Void
    var onSwitchCamera: () -> Void
    var hapticFeedback: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSpeechToggle) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .frame(width: 50, height: 50)
                    if settingsManager.speechEnabled {
                        if isSpeaking {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .symbolEffect(.bounce)
                        } else {
                            Image(systemName: "speaker.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    } else {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 60, height: 60)
            .accessibilityLabel(
                settingsManager.speechEnabled
                    ? (isSpeaking ? "Speaking" : "Speech enabled") : "Speech disabled"
            )
            .accessibilityHint("Double tap to toggle speech output.")

            Spacer()

            Button(action: onCameraToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 3)
                        .frame(width: 80, height: 80)
                    RoundedRectangle(cornerRadius: cameraIsRunning ? 5 : 34)
                        .fill(Color(.red))
                        .frame(width: cameraIsRunning ? 30 : 68, height: cameraIsRunning ? 30 : 68)
                        .shadow(color: .black.opacity(0.2), radius: 2)
                        .animation(.easeInOut(duration: 0.3), value: cameraIsRunning)
                }
            }
            .accessibilityLabel(cameraIsRunning ? "Pause camera" : "Start camera")
            .accessibilityHint(
                cameraIsRunning
                    ? "Double tap to pause video analysis." : "Double tap to start video analysis.")

            Spacer()

            #if os(iOS)
                Button(action: onSwitchCamera) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .frame(width: 50, height: 50)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 60, height: 60)
                .accessibilityLabel("Switch camera")
                .accessibilityHint("Double tap to switch between front and back camera.")
            #endif
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .disabled(!permissionGranted)
    }
}
