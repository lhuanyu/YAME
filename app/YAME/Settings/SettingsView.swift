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

    @State var isShowingCapabilityTest = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $settingsManager.speechEnabled) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                            Text("Speech Enabled")
                        }
                    }
                    .accessibilityLabel("Speech enabled")
                    .accessibilityHint("Double tap to toggle speech output.")
                    .onChange(of: settingsManager.speechEnabled) { _, newValue in
                        if !newValue && SpeechSynthesizer.shared.isSpeaking {
                            SpeechSynthesizer.shared.stop()
                        }
                    }

                    if settingsManager.speechEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "speedometer")
                                Text("Speech Rate")
                                Spacer()
                                Text(speechRateDescription)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Speech rate")
                            .accessibilityValue(speechRateDescription)

                            HStack {
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
                            }
                            HStack {
                                Spacer()
                                Button {
                                    settingsManager.speechRate = defaultRate
                                    updateSpeechConfig()
                                } label: {
                                    Text("Restore")
                                        .font(.caption)
                                }
                                .accessibilityLabel("Restore default speech rate")
                                .accessibilityHint("Double tap to reset speech rate to default.")
                            }
                        }
                    }

                    Toggle(isOn: $settingsManager.subtitleEnabled) {
                        HStack {
                            Image(systemName: "captions.bubble.fill")
                            Text("Subtitle")
                        }
                    }
                    .accessibilityLabel("Subtitle enabled")
                    .accessibilityHint("Double tap to toggle subtitle display.")

                    Button {
                        isShowingCapabilityTest = true
                    } label: {
                        HStack {
                            Image(systemName: "cpu.fill")
                            Text("Device Capability Test")
                        }
                    }
                    .foregroundColor(.primary)
                    .accessibilityLabel("Device Capability Test")
                    .accessibilityHint("Double tap to test device capabilities.")

                }

                Section(header: Text("About")) {
                    /// AcknowList
                    NavigationLink {
                        if let list = AcknowParser.defaultAcknowList() {
                            let acknowledgements = list.acknowledgements + [.fastVLM]
                            AcknowListSwiftUIView(acknowledgements: acknowledgements)
                        }
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
                            string: "https://apps.apple.com/app/id6745918382?action=write-review")
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
                    HStack {
                        Image(systemName: "app.fill")
                        Text("YAME")
                            .font(.headline)
                        Spacer()
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
            .onAppear {
                updateSpeechConfig()
            }
            .sheet(isPresented: $isShowingCapabilityTest) {
                DeviceCapabilityView(details: DeviceCapability.testAndFetchDetails())
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
