//
//  DeviceCapabilityView.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/17.
//

import SwiftUI

struct DeviceCapabilityView: View {

    @Environment(\.dismiss) private var dismiss

    let performanceLevel: DevicePerformanceLevel
    let memoryGB: Double
    let freeMemoryGB: Double
    let hasMetal: Bool
    let supportsNeuralEngine: Bool

    var forceStartHandler: (() -> Void)?

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "iphone.gen3")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundColor(colorForLevel(performanceLevel))
                .padding(.top, 24)

            Text("Device Capability Test")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .padding(.bottom, 4)

            Label {
                Text(LocalizedStringKey(performanceLevel.rawValue.capitalized))
                    .font(.title2)
                    .fontWeight(.bold)
            } icon: {
                Circle()
                    .fill(colorForLevel(performanceLevel))
                    .frame(width: 16, height: 16)
            }
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                capabilityRow(
                    title: "Total Memory", value: String(format: "%.1f GB", memoryGB),
                    systemImage: "memorychip")
                Divider()
                capabilityRow(
                    title: "Free Memory", value: String(format: "%.1f GB", freeMemoryGB),
                    systemImage: "gauge")
                Divider()
                capabilityRow(
                    title: "Metal Supported",
                    value: hasMetal
                        ? NSLocalizedString("Yes", comment: "")
                        : NSLocalizedString("No", comment: ""),
                    systemImage: "cube")
                Divider()
                capabilityRow(
                    title: "Neural Engine Supported",
                    value: supportsNeuralEngine
                        ? NSLocalizedString("Yes", comment: "")
                        : NSLocalizedString("No", comment: ""),
                    systemImage: "brain.head.profile")
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color(.black).opacity(0.06), radius: 8, x: 0, y: 2)
            )
            .padding(.horizontal)

            Text(resultMessage(for: performanceLevel))
                .font(.headline)
                .foregroundColor(colorForLevel(performanceLevel))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, 8)

            Spacer()

            Button(action: {
                if performanceLevel.isSupported {
                    dismiss()
                } else {
                    dismiss()
                    forceStartHandler?()
                }
            }) {
                Text(
                    LocalizedStringKey(
                        performanceLevel.isSupported ? "Continue" : "Continue Anyway")
                )
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(performanceLevel.isSupported ? Color.accentColor : Color.red)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }

    }

    // Color for each performance level
    private func colorForLevel(_ level: DevicePerformanceLevel) -> Color {
        switch level {
        case .unsupported: return .red
        case .minimal: return .orange
        case .recommended: return .blue
        case .optimal: return .green
        }
    }

    // Result message for user
    private func resultMessage(for level: DevicePerformanceLevel) -> LocalizedStringKey {
        switch level {
        case .unsupported:
            return "Your device is not supported. The app may not run properly."
        case .minimal:
            return "Your device meets the minimal requirements. Performance may be limited."
        case .recommended:
            return
                "Your device is recommended for running the app. You should have a good experience."
        case .optimal:
            return "Your device is optimal for this app. Enjoy the best experience!"
        }
    }

    // Modern capability row
    @ViewBuilder
    private func capabilityRow(title: LocalizedStringKey, value: String, systemImage: String)
        -> some View
    {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
    }
}

// Convenience initializer for DeviceCapabilityDetails
extension DeviceCapabilityView {
    init(details: DeviceCapabilityDetails, forceStartHandler: (() -> Void)? = nil) {
        self.performanceLevel = details.performanceLevel
        self.memoryGB = details.memoryGB
        self.freeMemoryGB = details.freeMemoryGB
        self.hasMetal = details.hasMetal
        self.supportsNeuralEngine = details.supportsNeuralEngine
        self.forceStartHandler = forceStartHandler
    }
}

// Preview for SwiftUI canvas
#Preview {
    DeviceCapabilityView(details: DeviceCapability.testAndFetchDetails())
}
