//
//  CameraAccessDeniedView.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/16.
//

import SwiftUI

struct CameraAccessDeniedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "video.slash.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .foregroundColor(.white)
                .padding(.top, 16)
            Text("Camera access denied")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Text("Please allow camera access in Settings to use this feature.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button {
                #if os(iOS)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                #endif
            } label: {
                Text("Go to Settings")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 24)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel("Go to Settings")
            Spacer()
        }
    }
}
