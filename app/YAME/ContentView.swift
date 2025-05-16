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

    @State private var selectedCameraType: CameraType = .continuous
    @State private var isSpeaking: Bool = false

    @State private var taskState: VisionTaskState = .loading

    @ObservedObject var settingsManager = SettingsManager.shared

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
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .frame(maxWidth: 750)
                    #endif
                    .accessibilityLabel("Video preview")
                    .accessibilityHint("Double tap to analyze the current frame.")
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
                                    .accessibilityHidden(true)
                            }
                        #endif
                    }
                    .overlay(alignment: .top) {
                        stateView
                            .offset(y: -40)
                            .accessibilityElement()
                            .accessibilityLabel("Status")
                            .accessibilityValue(taskState.rawValue.capitalized.localized())
                    }
                    .overlay(alignment: .bottom) {
                        if settingsManager.captionEnabled {
                            SubtitleView(text: $model.output)
                                .accessibilityLabel("Subtitle")
                                .accessibilityValue(model.output)
                        }
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
            .onChange(of: model.evaluationState) { oldValue, newValue in
                guard oldValue != newValue else { return }
                if newValue == .generatingResponse {
                    AudioServicesPlaySystemSound(1306)
                } else if newValue == .processingPrompt {
                    AudioServicesPlaySystemSound(1306)
                }
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
                            Image(systemName: isTorchEnabled ? "bolt.circle" : "bolt.slash.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                        }
                        .accessibilityLabel(
                            isTorchEnabled ? "Turn off flashlight" : "Turn on flashlight"
                        )
                        .accessibilityHint("Double tap to toggle the flashlight.")

                        // Speech toggle
                        Button {
                            settingsManager.speechEnabled.toggle()
                            if !settingsManager.speechEnabled {
                                SpeechSynthesizer.shared.stop()
                            }
                            hapticFeedback()
                        } label: {
                            Image(
                                systemName: settingsManager.speechEnabled
                                    ? "speaker.circle" : "speaker.slash.circle"
                            )
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                        }
                        .accessibilityLabel(
                            settingsManager.speechEnabled ? "Disable speech" : "Enable speech"
                        )
                        .accessibilityHint("Double tap to toggle speech output.")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingSettings.toggle()
                    } label: {
                        Image(systemName: "gear.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Double tap to open settings.")
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
                    HStack {
                        Image(systemName: task.symbol ?? "questionmark.circle")
                        Text(task.name)
                    }
                }
                .accessibilityLabel(task.name)
            }
        } label: {
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
        .accessibilityLabel("Change vision task type. Current task is \(selectedTask.name)")
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
    }

    var bottomControls: some View {
        HStack(spacing: 0) {
            Button(action: {
                if settingsManager.speechEnabled {
                    SpeechSynthesizer.shared.stop()
                } else {
                    settingsManager.speechEnabled = true
                }
                hapticFeedback()
            }) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .frame(width: 50, height: 50)

                    if settingsManager.speechEnabled {
                        if isSpeaking {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .symbolEffect(.bounce)
                        } else {
                            Image(systemName: "speaker.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    } else {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 60, height: 60)
            .accessibilityLabel(
                settingsManager.speechEnabled
                    ? (isSpeaking ? "Speaking" : "Speech enabled") : "Speech disabled"
            )
            .accessibilityHint("Double tap to toggle speech output.")

            Spacer()

            Button(action: {
                withAnimation {
                    if camera.isRunning {
                        model.cancel()
                        /// play pause sound
                        AudioServicesPlaySystemSound(1117)
                    } else {
                        model.clear()
                        /// play record sound
                        AudioServicesPlaySystemSound(1118)
                    }
                    camera.isRunning.toggle()
                    updateTaskState()
                    hapticFeedback()
                }
            }) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 3)
                        .frame(width: 80, height: 80)

                    // Animated shape that morphs between circle and square
                    RoundedRectangle(cornerRadius: camera.isRunning ? 5 : 34)
                        .fill(
                            Color(.red)
                        )
                        .frame(
                            width: camera.isRunning ? 30 : 68, height: camera.isRunning ? 30 : 68
                        )
                        .shadow(color: .black.opacity(0.2), radius: 2)
                        .animation(.easeInOut(duration: 0.3), value: camera.isRunning)
                }
            }
            .accessibilityLabel(camera.isRunning ? "Pause camera" : "Start camera")
            .accessibilityHint(
                camera.isRunning
                    ? "Double tap to pause video analysis." : "Double tap to start video analysis.")

            Spacer()

            #if os(iOS)
                Button(action: {
                    camera.backCamera.toggle()
                    // Reset torch when switching camera since it only works on back camera
                    if !camera.backCamera, isTorchEnabled {
                        isTorchEnabled = false
                        camera.isTorchEnabled = false
                    }
                    if !camera.isRunning {
                        model.clear()
                        camera.isRunning = true
                        AudioServicesPlaySystemSound(1118)
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
                .accessibilityLabel("Switch camera")
                .accessibilityHint("Double tap to switch between front and back camera.")
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
            if camera.isRunning && SpeechSynthesizer.shared.isEnabled {
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
