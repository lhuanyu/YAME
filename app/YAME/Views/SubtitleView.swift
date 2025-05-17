//
//  SubtitleView.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/15.
//

import SwiftUI

import SwiftUI

struct SubtitleView: View {
    @Binding var text: String
    @State private var height: CGFloat = .zero

    var body: some View {
        VStack {
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
                    .padding(.bottom)
                    .padding(.horizontal)
                    .frame(height: height)
                    .onChange(of: text) { _ , newValue in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.height = Self.calculateHeight(for: newValue)
                        }
                    }
            }
        }
    }

    static func calculateHeight(for text: String) -> CGFloat {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        label.text = text
        let horizontalPadding: CGFloat = 16 * 2 + 16 * 2 // internal + external
        let width = UIScreen.main.bounds.width - horizontalPadding
        let size = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return size.height + 10 * 2 + 16 // vertical padding + estimated extra
    }
}

#Preview {
    SubtitleView(text: .constant("Hello, World!Hello, World!Hello, World!Hello, World!Hello, World!Hello, World!Hello, World!Hello, World!Hello, World!Hello, World!Hello, World!Hello, World!Hello, World!"))
}
