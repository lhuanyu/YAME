//
//  VideoFrameView.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/14.
//

import AVFoundation
import CoreImage
import Foundation
import SwiftUI

/// Displays a stream of video frames
public struct VideoFrameView: View {
    @Environment(\.colorScheme) private var colorScheme

    public let frames: AsyncStream<CVImageBuffer>
    public let cameraType: CameraType
    public let action: ((CVImageBuffer) -> Void)?

    @State private var hold: Bool = false
    @State private var videoFrame: CVImageBuffer?

    private var backgroundColor: Color {
        .black
    }

    public init(
        frames: AsyncStream<CVImageBuffer>,
        cameraType: CameraType,
        action: ((CVImageBuffer) -> Void)?
    ) {
        self.frames = frames
        self.cameraType = cameraType
        self.action = action
    }

    public var body: some View {
        VStack {
            if let videoFrame {
                _ImageView(image: videoFrame)
                    .overlay(alignment: .bottom) {
                        if cameraType == .single {
                            Button {
                                tap()
                            } label: {
                                if hold {
                                    Label("Resume", systemImage: "play.fill")
                                } else {
                                    Label("Capture Photo", systemImage: "camera.fill")
                                }
                            }
                            .clipShape(.capsule)
                            .buttonStyle(.borderedProminent)
                            .tint(hold ? .gray : .accentColor)
                            .foregroundColor(.white)
                            .padding()
                        }
                    }
            } else {
                // spinner before the camera comes up
                ProgressView()
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
        .clipShape(Rectangle())
        .overlay {
            // Add corner borders to the VideoFrameView
            CornerBorder(color: .white, lineWidth: 1, cornerLength: 20)
        }
        .task {
            // feed frames to the _ImageView
            if Task.isCancelled {
                return
            }
            for await frame in frames {
                if !hold {
                    videoFrame = frame
                }
            }
        }
        .onChange(of: cameraType) { _, newType in
            // No matter what, when the user switches to .continuous,
            // we need to continue showing updated frames
            if newType == .continuous {
                hold = false
            }
        }
    }

    private func tap() {
        if hold {
            // resume
            hold = false
        } else if let videoFrame {
            hold = true
            if let action {
                action(videoFrame)
            }
        }
    }
}

/// A view that draws border lines at the four corners of its container
private struct CornerBorder: View {
    let color: Color
    let lineWidth: CGFloat
    let cornerLength: CGFloat

    // Common stroke style to ensure consistent rendering
    private var strokeStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: lineWidth,
            lineCap: .square,
            lineJoin: .miter
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            // Adjusted positions to account for line width
            let adjustedLineWidth = lineWidth / 2
            let x0 = adjustedLineWidth
            let y0 = adjustedLineWidth
            let xMax = width - adjustedLineWidth
            let yMax = height - adjustedLineWidth

            ZStack {
                // Top Left Corner
                CornerShape(
                    start: CGPoint(x: x0, y: cornerLength),
                    corner: CGPoint(x: x0, y: y0),
                    end: CGPoint(x: cornerLength, y: y0)
                )
                .stroke(color, style: strokeStyle)

                // Top Right Corner
                CornerShape(
                    start: CGPoint(x: width - cornerLength, y: y0),
                    corner: CGPoint(x: xMax, y: y0),
                    end: CGPoint(x: xMax, y: cornerLength)
                )
                .stroke(color, style: strokeStyle)

                // Bottom Left Corner
                CornerShape(
                    start: CGPoint(x: x0, y: height - cornerLength),
                    corner: CGPoint(x: x0, y: yMax),
                    end: CGPoint(x: cornerLength, y: yMax)
                )
                .stroke(color, style: strokeStyle)

                // Bottom Right Corner
                CornerShape(
                    start: CGPoint(x: width - cornerLength, y: yMax),
                    corner: CGPoint(x: xMax, y: yMax),
                    end: CGPoint(x: xMax, y: height - cornerLength)
                )
                .stroke(color, style: strokeStyle)
            }
        }
    }
}

/// A shape that represents a single corner with two line segments
private struct CornerShape: Shape {
    let start: CGPoint
    let corner: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: corner)
        path.addLine(to: end)
        return path
    }
}

#if os(iOS)
    /// Internal view to display a CVImageBuffer
    private struct _ImageView: UIViewRepresentable {
        let image: Any
        var gravity = CALayerContentsGravity.resizeAspectFill

        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            view.layer.contentsGravity = gravity
            return view
        }

        func updateUIView(_ uiView: UIView, context: Context) {
            uiView.layer.contents = image
        }
    }
#else
    private struct _ImageView: NSViewRepresentable {
        let image: Any
        var gravity = CALayerContentsGravity.resizeAspectFill

        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            view.wantsLayer = true
            view.layer?.contentsGravity = gravity
            return view
        }

        func updateNSView(_ uiView: NSView, context: Context) {
            uiView.layer?.contents = image
        }
    }

#endif
