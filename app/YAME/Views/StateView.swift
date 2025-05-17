//
//  StateView.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/16.
//

import SwiftUI

struct StateView: View {
    let taskState: VisionTaskState

    var body: some View {
        HStack(spacing: 8) {
            if taskState == .loading || taskState == .seeing {
                ProgressView()
                    .tint(taskState.foregroundColor)
                    .controlSize(.small)
            } else if !taskState.symbolName.isEmpty {
                Image(systemName: taskState.symbolName)
                    .font(.caption)
            }
            Text(taskState.rawValue.capitalized.localized())
        }
        .foregroundStyle(taskState.foregroundColor)
        .font(.caption.weight(.semibold))
        .padding(.vertical, 6.0)
        .padding(.horizontal, 10.0)
        .background {
            #if os(iOS)
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .fill(taskState.backgroundColor)
                            .blendMode(.plusLighter)
                    }
                    .environment(\.colorScheme, .dark)
            #else
                Capsule()
                    .fill(taskState.backgroundColor)
            #endif
        }
        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}
