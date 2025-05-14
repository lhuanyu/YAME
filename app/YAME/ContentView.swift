//
//  ContentView.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/14.
//

import AVFoundation
import MLXLMCommon
import SwiftUI
import Video

// support swift 6
extension CVImageBuffer: @unchecked @retroactive Sendable {}
extension CMSampleBuffer: @unchecked @retroactive Sendable {}

// delay between frames -- controls the frame rate of the updates
let FRAME_DELAY = Duration.milliseconds(1)

struct ContentView: View {
    @State private var camera = CameraController()
    @State private var model = FastVLMModel()

    /// stream of frames -> VideoFrameView, see distributeVideoFrames
    @State private var framesToDisplay: AsyncStream<CVImageBuffer>?

    @State private var selectedTask: VisionTask = .describeImage

    @State private var isShowingInfo: Bool = false

    @State private var selectedCameraType: CameraType = .continuous
    @State private var isEditingPrompt: Bool = false
    @State private var isSpeaking: Bool = false

    var toolbarItemPlacement: ToolbarItemPlacement {
        var placement: ToolbarItemPlacement = .navigation
        #if os(iOS)
            placement = .topBarLeading
        #endif
        return placement
    }

    var statusTextColor: Color {
        return model.evaluationState == .processingPrompt ? .black : .white
    }

    var statusBackgroundColor: Color {
        switch model.evaluationState {
        case .idle:
            return .gray
        case .generatingResponse:
            return .green
        case .processingPrompt:
            return .yellow
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10.0) {
                        Picker("Camera Type", selection: $selectedCameraType) {
                            ForEach(CameraType.allCases, id: \.self) { cameraType in
                                Text(cameraType.rawValue.capitalized.localized()).tag(cameraType)
                            }
                        }
                        // Prevent macOS from adding a text label for the picker
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .onChange(of: selectedCameraType) { _, _ in
                            // Cancel any in-flight requests when switching modes
                            model.cancel()
                        }

                        if let framesToDisplay {
                            VideoFrameView(
                                frames: framesToDisplay,
                                cameraType: selectedCameraType,
                                action: { frame in
                                    processSingleFrame(frame)
                                }
                            )
                            // Because we're using the AVCaptureSession preset
                            // `.vga640x480`, we can assume this aspect ratio
                            .aspectRatio(4 / 3, contentMode: .fit)
                            #if os(macOS)
                                .frame(maxWidth: 750)
                            #endif
                            .overlay(alignment: .top) {
                                if !model.promptTime.isEmpty {
                                    Text("TTFT \(model.promptTime)")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                        .monospaced()
                                        .padding(.vertical, 4.0)
                                        .padding(.horizontal, 6.0)
                                        .background(alignment: .center) {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.black.opacity(0.6))
                                        }
                                        .padding(.top)
                                }
                            }
                            #if !os(macOS)
                                .overlay(alignment: .topTrailing) {
                                    CameraControlsView(
                                        backCamera: $camera.backCamera,
                                        device: $camera.device,
                                        devices: $camera.devices
                                    )
                                    .padding()
                                }
                            #endif
                            .overlay(alignment: .bottom) {
                                if selectedCameraType == .continuous {
                                    Group {
                                        if model.evaluationState == .processingPrompt {
                                            HStack {
                                                ProgressView()
                                                    .tint(self.statusTextColor)
                                                    .controlSize(.small)

                                                Text(model.evaluationState.rawValue)
                                            }
                                        } else if model.evaluationState == .idle {
                                            HStack(spacing: 6.0) {
                                                Image(systemName: "clock.fill")
                                                    .font(.caption)

                                                Text(model.evaluationState.rawValue)
                                            }
                                        } else {
                                            // I'm manually tweaking the spacing to
                                            // better match the spacing with ProgressView
                                            HStack(spacing: 6.0) {
                                                Image(systemName: "lightbulb.fill")
                                                    .font(.caption)

                                                Text(model.evaluationState.rawValue)
                                            }
                                        }
                                    }
                                    .foregroundStyle(self.statusTextColor)
                                    .font(.caption)
                                    .bold()
                                    .padding(.vertical, 6.0)
                                    .padding(.horizontal, 8.0)
                                    .background(self.statusBackgroundColor)
                                    .clipShape(.capsule)
                                    .padding(.bottom)
                                }
                            }
                            #if os(macOS)
                                .frame(maxWidth: .infinity)
                                .frame(minWidth: 500)
                                .frame(minHeight: 375)
                            #endif
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                promptSections

                Section {
                    if model.output.isEmpty && model.running {
                        ProgressView()
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                    } else {
                        ScrollView {
                            Text(model.output)
                                .foregroundStyle(isEditingPrompt ? .secondary : .primary)
                                .textSelection(.enabled)
                                #if os(macOS)
                                    .font(.headline)
                                    .fontWeight(.regular)
                                #endif
                        }
                        .frame(minHeight: 50.0, maxHeight: 200.0)
                    }
                } header: {
                    Text("Response")
                        #if os(macOS)
                            .font(.headline)
                            .padding(.bottom, 2.0)
                        #endif
                }

                #if os(macOS)
                    Spacer()
                #endif
            }

            #if os(iOS)
                .listSectionSpacing(0)
            #elseif os(macOS)
                .padding()
            #endif
            .task {
                await camera.startAsync()
                try? await Task.sleep(for: .milliseconds(100))
                await model.load()
                camera.setSampleBufferDelegate()
            }
            #if !os(macOS)
                .onAppear {
                    // Prevent the screen from dimming or sleeping due to inactivity
                    UIApplication.shared.isIdleTimerDisabled = true
                    NotificationCenter.default.addObserver(
                        forName: .speechSynthesizerSpeakingChanged, object: nil, queue: .main
                    ) { _ in
                        withAnimation {
                            isSpeaking = SpeechSynthesizer.isSpeaking
                        }
                    }
                    isSpeaking = SpeechSynthesizer.isSpeaking
                }
                .onDisappear {
                    // Resumes normal idle timer behavior
                    UIApplication.shared.isIdleTimerDisabled = false
                    NotificationCenter.default.removeObserver(
                        self, name: .speechSynthesizerSpeakingChanged, object: nil)
                }
            #endif

            // task to distribute video frames -- this will cancel
            // and restart when the view is on/off screen.  note: it is
            // important that this is here (attached to the VideoFrameView)
            // rather than the outer view because this has the correct lifecycle
            .task {
                if Task.isCancelled {
                    return
                }

                await distributeVideoFrames()
            }

            .navigationTitle("YAME")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        isShowingInfo.toggle()
                    } label: {
                        Image(systemName: "gear")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    menu
                }

            }
            .sheet(isPresented: $isShowingInfo) {
                SettingsView()
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    switch model.evaluationState {
                    case .generatingResponse:
                        Text("Thinking…")
                    case .idle:
                        if isSpeaking {
                            Text("Speaking…")
                        } else {
                            Text("Idle")
                        }
                    case .processingPrompt:
                        Text("Seeing...")
                    }
                    Spacer()
                    if isSpeaking {
                        Button(action: {
                            SpeechSynthesizer.shared.stop()
                        }) {
                            Image(systemName: "stop.circle.fill")
                                .foregroundStyle(.white)
                            Text("Stop Speaking")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(height: 60)
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    var menu: some View {
        Menu {
            ForEach(VisionTask.allTasks, id: \.self) { task in
                Button {
                    selectedTask = task
                } label: {
                    Text(task.name)
                }
            }
        } label: {
            if let selectedTaskIcon = selectedTask.symbol {
                Image(systemName: selectedTaskIcon)
            } else {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    var promptSummary: some View {
        Section("Prompt") {
            VStack(alignment: .leading, spacing: 4.0) {
                let trimmedPrompt = selectedTask.prompt.trimmingCharacters(
                    in: .whitespacesAndNewlines)
                if !trimmedPrompt.isEmpty {
                    Text(trimmedPrompt)
                        .foregroundStyle(.secondary)
                }

                let trimmedSuffix = selectedTask.promptSuffix.trimmingCharacters(
                    in: .whitespacesAndNewlines)
                if !trimmedSuffix.isEmpty {
                    Text(trimmedSuffix)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    var promptSections: some View {
        Group {
            promptSummary
        }
    }

    func analyzeVideoFrames(_ frames: AsyncStream<CVImageBuffer>) async {
        for await frame in frames {
            let userInput = UserInput(
                prompt: .text("\(selectedTask.prompt) \(selectedTask.promptSuffix)"),
                images: [.ciImage(CIImage(cvPixelBuffer: frame))]
            )
            // generate output for a frame and wait for generation to complete
            let t = await model.generate(userInput)
            _ = await t.result
            // 等待语音播报结束
            if SpeechSynthesizer.shared.isEnabled {
                await SpeechSynthesizer.shared.speakAndWait(model.output)
            }
            do {
                try await Task.sleep(for: FRAME_DELAY)
            } catch { return }
        }
    }

    func distributeVideoFrames() async {
        // attach a stream to the camera -- this code will read this
        let frames = AsyncStream<CMSampleBuffer>(bufferingPolicy: .bufferingNewest(1)) {
            camera.attach(continuation: $0)
        }

        let (framesToDisplay, framesToDisplayContinuation) = AsyncStream.makeStream(
            of: CVImageBuffer.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        self.framesToDisplay = framesToDisplay

        // Only create analysis stream if in continuous mode
        let (framesToAnalyze, framesToAnalyzeContinuation) = AsyncStream.makeStream(
            of: CVImageBuffer.self,
            bufferingPolicy: .bufferingNewest(1)
        )

        // set up structured tasks (important -- this means the child tasks
        // are cancelled when the parent is cancelled)
        async let distributeFrames: () = {
            for await sampleBuffer in frames {
                if let frame = sampleBuffer.imageBuffer {
                    framesToDisplayContinuation.yield(frame)
                    // Only send frames for analysis in continuous mode
                    if await selectedCameraType == .continuous {
                        framesToAnalyzeContinuation.yield(frame)
                    }
                }
            }

            // detach from the camera controller and feed to the video view
            await MainActor.run {
                self.framesToDisplay = nil
                self.camera.detatch()
            }

            framesToDisplayContinuation.finish()
            framesToAnalyzeContinuation.finish()
        }()

        // Only analyze frames if in continuous mode
        if selectedCameraType == .continuous {
            async let analyze: () = analyzeVideoFrames(framesToAnalyze)
            await distributeFrames
            await analyze
        } else {
            await distributeFrames
        }
    }

    /// Perform FastVLM inference on a single frame.
    /// - Parameter frame: The frame to analyze.
    func processSingleFrame(_ frame: CVImageBuffer) {
        // Reset Response UI (show spinner)
        Task { @MainActor in
            model.output = ""
        }

        // Construct request to model
        let userInput = UserInput(
            prompt: .text("\(selectedTask.prompt) \(selectedTask.promptSuffix)"),
            images: [.ciImage(CIImage(cvPixelBuffer: frame))]
        )

        // Post request to FastVLM
        Task {
            await model.generate(userInput)
        }
    }
}

#Preview {
    ContentView()
}
