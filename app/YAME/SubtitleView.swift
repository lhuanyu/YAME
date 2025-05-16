//
//  SubtitleView.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/15.
//

import SwiftUI

struct SubtitleView: View {
    @Binding var text: String

    var body: some View {
        if !text.isEmpty {
            Text(text)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        }
                }
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                .lineLimit(nil)
                .animation(.easeInOut(duration: 0.25), value: text)
                .padding(.bottom)
                .padding(.horizontal)
        }

    }
}


#Preview {
    SubtitleView(text: .constant("Hello, World!Hello, World!Hello, World!Hello, World!Hello, World!Hello, World!Hello, World!Hello, World!Hello, World!Hello, World!Hello, World!Hello, World!Hello, World!"))
}
