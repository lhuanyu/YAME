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

    @State private var isTorchEnabled: Bool = false

    @State private var selectedCameraType: CameraType = .continuous

    @State private var taskState: VisionTaskState = .loading

    @ObservedObject var settingsManager = SettingsManager.shared

    @ObservedObject var speechSynthesizer = SpeechSynthesizer.shared

    @State private var isShowingDeviceCapabilities: Bool = false

    @State private var deviceCapabilityDetails: DeviceCapabilityDetails?

    private var toolbarItemPlacement: ToolbarItemPlacement {
        var placement: ToolbarItemPlacement = .navigation
        #if os(iOS)
            placement = .topBarLeading
        #endif
        return placement
    }

    private func updateTaskState() {
        if !camera.isRunning {
            taskState = .paused
        } else {
            switch model.evaluationState {
            case .idle:
                taskState = speechSynthesizer.isSpeaking ? .speaking : .idle
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
                        if camera.permissionGranted {
                            StateView(taskState: taskState)
                            #if os(iOS)
                                .offset(y: -40)
                            #elseif os(macOS)
                                .padding(.top, 8)
                            #endif
                                .accessibilityElement()
                                .accessibilityLabel("Status")
                                .accessibilityValue(taskState.rawValue.capitalized.localized())
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if settingsManager.subtitleEnabled {
                            SubtitleView(text: $model.output)
                                .accessibilityLabel("Subtitle")
                                .accessibilityValue(model.output)
                        }
                    }
                    .overlay(alignment: .center) {
                        if camera.authorizationStatus == .denied {
                            CameraAccessDeniedView()
                        }
                    }
                    #if os(macOS)
                    .frame(maxWidth: .infinity)
                    .frame(minWidth: 500)
                    .frame(minHeight: 375)
                    #endif
                }

                BottomControls(
                    isSpeaking: $speechSynthesizer.isSpeaking,
                    settingsManager: settingsManager,
                    cameraIsRunning: $camera.isRunning,
                    isTorchEnabled: $isTorchEnabled,
                    selectedCameraType: $selectedCameraType,
                    permissionGranted: camera.permissionGranted,
                    onSpeechToggle: {
                        if settingsManager.speechEnabled {
                            SpeechSynthesizer.shared.stop()
                        } else {
                            settingsManager.speechEnabled = true
                        }
                        hapticFeedback()
                    },
                    onCameraToggle: {
                        withAnimation {
                            if camera.isRunning {
                                model.cancel()
                                AudioServicesPlaySystemSound(1117)
                            } else {
                                model.clear()
                                AudioServicesPlaySystemSound(1118)
                            }
                            camera.isRunning.toggle()
                            updateTaskState()
                            hapticFeedback()
                        }
                    },
                    onSwitchCamera: {
                        camera.backCamera.toggle()
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
                    },
                    hapticFeedback: hapticFeedback
                )

                Spacer()
            }
            .background(.black)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                #if targetEnvironment(simulator)
                #else
                    if testDeviceCapability() {
                        await camera.startAsync()
                        camera.setSampleBufferDelegate()
                    }
                #endif
            }
            #if !os(macOS)
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            #endif
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
            .onChange(of: speechSynthesizer.isSpeaking) { _, _ in
                withAnimation {
                    updateTaskState()
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    MenuSelector(selectedTask: $selectedTask)
                        .disabled(!camera.permissionGranted)
                }
                ToolbarItem(placement: toolbarItemPlacement) {
                    ToolbarControls(
                        isTorchEnabled: $isTorchEnabled,
                        isSpeaking: $speechSynthesizer.isSpeaking,
                        settingsManager: settingsManager,
                        cameraPermissionGranted: camera.permissionGranted,
                        toggleTorch: {
                            isTorchEnabled.toggle()
                            camera.isTorchEnabled = isTorchEnabled
                            hapticFeedback()
                        },
                        toggleSpeech: {
                            settingsManager.speechEnabled.toggle()
                            if !settingsManager.speechEnabled {
                                SpeechSynthesizer.shared.stop()
                            }
                            hapticFeedback()
                        },
                        openSettings: {
                            isShowingSettings.toggle()
                        }
                    )
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
            .sheet(isPresented: $isShowingDeviceCapabilities) {
                if let details = deviceCapabilityDetails {
                    DeviceCapabilityView(details: details) {
                        Task {
                            await camera.startAsync()
                            camera.setSampleBufferDelegate()
                        }
                    }
                }
            }
        }
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

    private func testDeviceCapability() -> Bool {
        let capability = DeviceCapability.testAndFetchDetails()
        if !capability.performanceLevel.isSupported {
            deviceCapabilityDetails = capability
            isShowingDeviceCapabilities = true
            return false
        }
        return true
    }
}

#Preview {
    ContentView()
}
