//
//  SettingsView.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/14.
//

import AVFoundation
import SwiftUI

struct SettingsView: View {
    // 使用AppStorage持久化设置
    @AppStorage("speechEnabled") private var speechEnabled = true
    @AppStorage("speechRate") private var speechRate: Double = Double(
        AVSpeechUtteranceDefaultSpeechRate)

    // 语速最小值、最大值和默认值常量
    private let minRate: Double = 0.1
    private let maxRate: Double = 1.0
    private let defaultRate: Double = Double(AVSpeechUtteranceDefaultSpeechRate)

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Speech")) {
                    Toggle("Speech Enabled", isOn: $speechEnabled)
                        .onChange(of: speechEnabled) { _, newValue in
                            if !newValue && SpeechSynthesizer.isSpeaking {
                                SpeechSynthesizer.shared.stop()
                            }
                        }

                    if speechEnabled {
                        VStack {
                            HStack {
                                Text("Speech Rate")
                                Spacer()
                                Text(speechRateDescription)
                                    .foregroundStyle(.secondary)
                            }

                            Slider(value: $speechRate, in: minRate...maxRate) {
                                Text("Speech Rate")
                            } minimumValueLabel: {
                                Image(systemName: "tortoise")
                            } maximumValueLabel: {
                                Image(systemName: "hare")
                            }
                            .onChange(of: speechRate) { _, newRate in
                                updateSpeechConfig()
                            }

                            Button("Restore") {
                                speechRate = defaultRate
                                updateSpeechConfig()
                            }
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }

                Section(header: Text("About")) {
                    VStack(alignment: .leading) {
                        Text("YAME")
                            .font(.headline)
                        Text(appVersionAndBuild)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                // 加载时应用设置到语音合成器
                updateSpeechConfig()
            }
        }
    }
    
    var appVersionAndBuild: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    // 格式化语速描述
    private var speechRateDescription: String {
        if speechRate < defaultRate - 0.2 {
            return "Very Slow"
        } else if speechRate < defaultRate - 0.1 {
            return "Slow"
        } else if speechRate > defaultRate + 0.2 {
            return "Very Fast"
        } else if speechRate > defaultRate + 0.1 {
            return "Fast"
        } else {
            return "Normal"
        }
    }

    // 更新语音配置
    private func updateSpeechConfig() {
        var config = SpeechSynthesizer.Config()
        config.rate = Float(speechRate)
        SpeechSynthesizer.shared.updateConfig(config)
    }
}

#Preview {
    SettingsView()
}
