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

    @State private var isShowingSettings: Bool = false

    // Add state variables for flashlight and speech
    @State private var isTorchEnabled: Bool = false
    @AppStorage("speechEnabled") private var speechEnabled: Bool = true

    @State private var selectedCameraType: CameraType = .continuous
    @State private var isSpeaking: Bool = false

    @State private var taskState: VisionTaskState = .loading

    var toolbarItemPlacement: ToolbarItemPlacement {
        var placement: ToolbarItemPlacement = .navigation
        #if os(iOS)
            placement = .topBarLeading
        #endif
        return placement
    }

    func updateTaskState() {
        if !camera.isRunning {
            taskState = .paused
        } else {
            switch model.evaluationState {
            case .idle:
                taskState = isSpeaking ? .speaking : .idle
            case .generatingResponse:
                taskState = .thinking
            case .processingPrompt:
                taskState = .seeing
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                if let framesToDisplay {
                    VideoFrameView(
                        frames: framesToDisplay,
                        cameraType: selectedCameraType,
                        action: { frame in
                            processSingleFrame(frame)
                        }
                    )
                    #if os(iOS)
                        .aspectRatio(3 / 4, contentMode: .fit)
                    #else
                        .aspectRatio(4 / 3, contentMode: .fit)
                        .frame(maxWidth: 750)
                    #endif
                    .overlay(alignment: .topLeading) {
                        #if DEBUG
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
                                    .padding([.top, .leading], 8)
                            }
                        #endif
                    }
                    .overlay(alignment: .top) {
                        stateView
                    }
                    .overlay(alignment: .bottom) {
                        SubtitleView(text: $model.output)
                    }

                    #if os(macOS)
                        .frame(maxWidth: .infinity)
                        .frame(minWidth: 500)
                        .frame(minHeight: 375)
                    #endif
                }

                bottomControls

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                #if targetEnvironment(simulator)

                #else
                    await camera.startAsync()
                    try? await Task.sleep(for: .milliseconds(100))
                    await model.load()
                    camera.setSampleBufferDelegate()
                #endif
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
                            updateTaskState()
                        }
                    }
                    isSpeaking = SpeechSynthesizer.isSpeaking
                }
                .background(.black)
                .onDisappear {
                    // Resumes normal idle timer behavior
                    UIApplication.shared.isIdleTimerDisabled = false
                    NotificationCenter.default.removeObserver(
                        self, name: .speechSynthesizerSpeakingChanged, object: nil
                    )
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
            .onChange(of: model.evaluationState) { _, _ in
                withAnimation {
                    updateTaskState()
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    menu
                }
                ToolbarItem(placement: toolbarItemPlacement) {
                    HStack {
                        Button {
                            isTorchEnabled.toggle()
                            camera.isTorchEnabled = isTorchEnabled
                            hapticFeedback()
                        } label: {
                            ZStack {

                                Image(systemName: isTorchEnabled ? "bolt.circle" : "bolt.slash.circle")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                            }
                        }

                        // Speech toggle
                        Button {
                            speechEnabled.toggle()
                            hapticFeedback()
                        } label: {
                            ZStack {
                                Image(
                                    systemName: speechEnabled
                                        ? "speaker.circle" : "speaker.slash.circle"
                                )
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                            }
                        }
                    }

                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingSettings.toggle()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial.opacity(0.4))
                                .frame(width: 36, height: 36)
                                .environment(\.colorScheme, .dark)
                            
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)

                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
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
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial.opacity(0.4))
                    .frame(width: 36, height: 36)
                    .environment(\.colorScheme, .dark)

                if let selectedTaskIcon = selectedTask.symbol {
                    Image(systemName: selectedTaskIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    var stateView: some View {
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
        .padding(.top, 10)
    }

    var bottomControls: some View {
        HStack(spacing: 0) {
            Button(action: {
                SpeechSynthesizer.shared.stop()
                hapticFeedback()
            }) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .frame(width: 50, height: 50)

                    if isSpeaking {
                        Image(systemName: "speaker.wave.3.fill")
                            .symbolEffect(.bounce)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "speaker.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 60, height: 60)

            Spacer()

            Button(action: {
                if camera.isRunning {
                    model.cancel()
                }
                camera.isRunning.toggle()
                hapticFeedback()
            }) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.8), lineWidth: 3)
                        .frame(width: 80, height: 80)

                    Circle()
                        .fill(
                            camera.isRunning
                                ? Color(.red)
                                : Color.white.opacity(0.9)
                        )
                        .frame(width: 68, height: 68)
                        .shadow(color: .black.opacity(0.2), radius: 2)
                }
            }

            Spacer()

            #if os(iOS)
                Button(action: {
                    camera.backCamera.toggle()
                    // Reset torch when switching camera since it only works on back camera
                    if !camera.backCamera && isTorchEnabled {
                        isTorchEnabled = false
                        camera.isTorchEnabled = false
                    }
                    hapticFeedback()
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .frame(width: 50, height: 50)

                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 60, height: 60)
            #endif
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
    }

    func analyzeVideoFrames(_ frames: AsyncStream<CVImageBuffer>) async {
        for await frame in frames {
            guard camera.isRunning else {
                continue
            }
            let userInput = UserInput(
                prompt: .text("\(selectedTask.prompt) \(selectedTask.promptSuffix)"),
                images: [.ciImage(CIImage(cvPixelBuffer: frame))]
            )
            // generate output for a frame and wait for generation to complete
            let t = await model.generate(userInput)
            _ = await t.result
            // Wait for speech to finish
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

    /// Provide haptic feedback
    func hapticFeedback() {
        #if !os(macOS)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        #endif
    }
}

#Preview {
    ContentView()
}
