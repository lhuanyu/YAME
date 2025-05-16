//
//  SettingsView.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/14.
//

import AVFoundation
import AcknowList
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared

    private let minRate: Double = 0.1
    private let maxRate: Double = 1.0
    private let defaultRate: Double = .init(AVSpeechUtteranceDefaultSpeechRate)

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Speech")) {
                    Toggle("Speech Enabled", isOn: $settingsManager.speechEnabled)
                        .accessibilityLabel("Speech enabled")
                        .accessibilityHint("Double tap to toggle speech output.")
                        .onChange(of: settingsManager.speechEnabled) { _, newValue in
                            if !newValue && SpeechSynthesizer.isSpeaking {
                                SpeechSynthesizer.shared.stop()
                            }
                        }

                    if settingsManager.speechEnabled {
                        VStack {
                            HStack {
                                Text("Speech Rate")
                                Spacer()
                                Text(speechRateDescription)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Speech rate")
                            .accessibilityValue(speechRateDescription)

                            Slider(value: $settingsManager.speechRate, in: minRate...maxRate) {
                                Text("Speech Rate")
                            } minimumValueLabel: {
                                Image(systemName: "tortoise")
                            } maximumValueLabel: {
                                Image(systemName: "hare")
                            }
                            .accessibilityLabel("Adjust speech rate")
                            .accessibilityValue(speechRateDescription)
                            .onChange(of: settingsManager.speechRate) { _, _ in
                                updateSpeechConfig()
                            }

                            Button("Restore") {
                                settingsManager.speechRate = defaultRate
                                updateSpeechConfig()
                            }
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .accessibilityLabel("Restore default speech rate")
                            .accessibilityHint("Double tap to reset speech rate to default.")
                        }
                    }
                }

                Section {
                    Toggle("Subtitle", isOn: $settingsManager.captionEnabled)
                        .accessibilityLabel("Subtitle enabled")
                        .accessibilityHint("Double tap to toggle subtitle display.")
                }

                Section(header: Text("About")) {
                    /// AcknowList
                    NavigationLink {
                        AcknowListSwiftUIView()
                    } label: {
                        HStack {
                            Image(systemName: "heart.fill")
                            Text("Acknowledgements")
                        }
                    }
                    .accessibilityLabel("Acknowledgements")
                    .accessibilityHint("Double tap to view open source acknowledgements.")
                    /// Feedback
                    Button {
                        if let url = URL(
                            string: "mailto:lhuany@gmail.com?subject=Feedback for YAME")
                        {
                            #if os(iOS)
                                UIApplication.shared.open(url)
                            #elseif os(macOS)
                                NSWorkspace.shared.open(url)
                            #endif
                        }
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Feedback")
                        }
                    }
                    .foregroundColor(.primary)
                    .accessibilityLabel("Feedback")
                    .accessibilityHint("Double tap to send feedback via email.")
                    /// AppStore Rating
                    Button {
                        if let url = URL(
                            string: "https://apps.apple.com/app/id6742433200?action=write-review")
                        {
                            #if os(iOS)
                                UIApplication.shared.open(url)
                            #elseif os(macOS)
                                NSWorkspace.shared.open(url)
                            #endif
                        }
                    } label: {
                        HStack {
                            Image(systemName: "star.fill")
                            Text("Rate on AppStore")
                        }
                    }
                    .foregroundColor(.primary)
                    .accessibilityLabel("Rate on AppStore")
                    .accessibilityHint("Double tap to rate this app on the App Store.")
                    VStack(alignment: .leading) {
                        Text("YAME")
                            .font(.headline)
                        Text(appVersionAndBuild)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("App version")
                    .accessibilityValue(appVersionAndBuild)
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                updateSpeechConfig()
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    var appVersionAndBuild: String {
        let version =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    private var speechRateDescription: LocalizedStringKey {
        if settingsManager.speechRate < defaultRate - 0.2 {
            return "Very Slow"
        } else if settingsManager.speechRate < defaultRate - 0.1 {
            return "Slow"
        } else if settingsManager.speechRate > defaultRate + 0.2 {
            return "Very Fast"
        } else if settingsManager.speechRate > defaultRate + 0.1 {
            return "Fast"
        } else {
            return "Normal"
        }
    }

    // 更新语音配置
    private func updateSpeechConfig() {
        var config = SpeechSynthesizer.Config()
        config.rate = Float(settingsManager.speechRate)
        SpeechSynthesizer.shared.updateConfig(config)
    }
}

#Preview {
    SettingsView()
}
