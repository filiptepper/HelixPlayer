import Foundation
import AVFoundation
import CoreAudio
import AudioToolbox
import Combine
import Accelerate

public class AudioEngineManager: ObservableObject {
    @Published public var isRunning = false
    @Published public var inputLevel: Float = 0.0
    @Published public var outputLevel: Float = 0.0
    @Published public var helixUnit: AVAudioUnit? = nil
    
    // Status text to show in the UI for debugging and state updates
    @Published public var statusMessage: String = "Initializing..."
    @Published public var availableDevices: [AudioDevice] = []
    @Published public var isHelixAvailable = true
    @Published public var micPermissionDenied = false
    
    @Published public var selectedInputDevice: AudioDevice? = nil {
        didSet {
            log("Selected Input Device changed: \(selectedInputDevice?.name ?? "None")")
            triggerReconfiguration()
        }
    }
    @Published public var selectedOutputDevice: AudioDevice? = nil {
        didSet {
            log("Selected Output Device changed: \(selectedOutputDevice?.name ?? "None")")
            triggerReconfiguration()
        }
    }
    @Published public var selectedInputChannel: Int = 0 {
        didSet {
            log("Selected Input Channel changed: \(selectedInputChannel + 1)")
            triggerReconfiguration()
        }
    }
    @Published public var selectedBufferSize: UInt32 = 128 {
        didSet {
            log("Selected Buffer Size changed: \(selectedBufferSize)")
            let input = selectedInputDevice
            let output = selectedOutputDevice
            let size = selectedBufferSize
            audioQueue.async { [weak self] in
                self?.updateDeviceBufferSize(input: input, output: output, size: size)
            }
        }
    }
    @Published public var isBypassed = false {
        didSet {
            log("Bypass toggled: \(isBypassed)")
            helixUnit?.auAudioUnit.shouldBypassEffect = isBypassed
        }
    }
    
    private var engine = AVAudioEngine()
    private var aggregateDeviceID: AudioDeviceID? = nil
    private var isConfiguring = false
    private var shouldStartAfterConfig = false
    private var configVersion = 0
    private var activityToken: NSObjectProtocol? = nil
    
    private let audioQueue = DispatchQueue(label: "com.helixplayer.audioQueue", qos: .userInitiated)
    private var meterTimer: Timer?
    private var rawInputLevel: Float = 0.0
    private var rawOutputLevel: Float = 0.0
    
    public static let availableBufferSizes: [UInt32] = [32, 64, 128, 256, 512]
    
    private static let logFormatter = ISO8601DateFormatter()
    
    private func log(_ message: String) {
        let timestamp = Self.logFormatter.string(from: Date())
        print("[\(timestamp)] [AudioEngineManager] \(message)")
        fflush(stdout)
    }
    
    public init() {
        log("Initializing AudioEngineManager...")
        
        // Clean up any stale aggregate devices left over from previous app runs or crashes
        CoreAudioHelper.destroyAllOrphanedAggregateDevices()
        
        availableDevices = CoreAudioHelper.getAllDevices()
        log("Available audio devices: \(availableDevices.map { "\($0.name) (I:\($0.inputChannels), O:\($0.outputChannels))" })")
        
        selectedInputDevice = availableDevices.first(where: { $0.inputChannels > 0 })
        selectedOutputDevice = availableDevices.first(where: { $0.outputChannels > 0 })
        log("Default Input Device: \(selectedInputDevice?.name ?? "None")")
        log("Default Output Device: \(selectedOutputDevice?.name ?? "None")")
        
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.log("AVAudioEngineConfigurationChange Notification received.")
            
            // Update cached devices
            self.availableDevices = CoreAudioHelper.getAllDevices()
            
            if self.isConfiguring {
                self.log("Ignoring configuration change notification because active setup is in progress.")
                return
            }
            
            let devices = self.availableDevices
            
            if let selectedInput = self.selectedInputDevice {
                let stillExists = devices.contains(where: { 
                    $0.deviceID == selectedInput.deviceID && 
                    $0.sampleRate == selectedInput.sampleRate && 
                    $0.inputChannels == selectedInput.inputChannels 
                })
                if !stillExists {
                    self.log("Selected input device changed or no longer exists. Reconfiguring...")
                    self.triggerReconfiguration()
                    return
                }
            }
            
            if let selectedOutput = self.selectedOutputDevice {
                let stillExists = devices.contains(where: { 
                    $0.deviceID == selectedOutput.deviceID && 
                    $0.sampleRate == selectedOutput.sampleRate && 
                    $0.outputChannels == selectedOutput.outputChannels 
                })
                if !stillExists {
                    self.log("Selected output device changed or no longer exists. Reconfiguring...")
                    self.triggerReconfiguration()
                    return
                }
            }
            
            self.log("Selected devices are still valid and unchanged. Skipping redundant reconfiguration.")
        }
        
        self.statusMessage = "Ready. Select devices and Start Engine."
    }
    
    deinit {
        stopEngine()
        cleanupAggregateDevice()
        meterTimer?.invalidate()
    }
    
    public func checkAndRequestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.micPermissionDenied = !granted
                    completion(granted)
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.micPermissionDenied = true
                self.statusMessage = "Microphone access denied in System Settings."
                completion(false)
            }
        @unknown default:
            completion(false)
        }
    }
    
    public func startEngine() {
        log("startEngine() called. current status: isRunning=\(isRunning)")
        guard !isRunning else { return }
        
        checkAndRequestMicrophoneAccess { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                self.log("Cannot start engine: Microphone permission denied.")
                return
            }
            
            self.shouldStartAfterConfig = true
            
            if self.helixUnit != nil && (self.selectedInputDevice?.deviceID == self.selectedOutputDevice?.deviceID || self.aggregateDeviceID != nil) {
                self.log("Audio Unit already loaded. Starting engine directly...")
                do {
                    try self.engine.start()
                    self.isRunning = true
                    self.statusMessage = "Engine active."
                    self.startMeterTimer()
                    self.log("AVAudioEngine started successfully.")
                    
                    self.activityToken = ProcessInfo.processInfo.beginActivity(
                        options: [.userInitiated, .idleSystemSleepDisabled],
                        reason: "Live Audio Hosting"
                    )
                } catch {
                    self.log("Direct engine start failed: \(error). Reconfiguring graph...")
                    self.triggerReconfiguration()
                }
            } else {
                self.log("Engine or Audio Unit requires configuration. Triggering reconfiguration...")
                self.triggerReconfiguration()
            }
        }
    }
    
    public func stopEngine() {
        log("stopEngine() called.")
        shouldStartAfterConfig = false
        guard isRunning else { return }
        
        log("Stopping engine...")
        engine.stop()
        isRunning = false
        statusMessage = "Engine stopped."
        stopMeterTimer()
        
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
    }
    
    public func toggleBypass() {
        isBypassed.toggle()
    }
    
    private func triggerReconfiguration() {
        configVersion += 1
        let currentVersion = configVersion
        log("triggerReconfiguration() triggered. New Version ID: \(currentVersion)")
        
        isConfiguring = true
        let wasRunning = isRunning
        if wasRunning {
            log("Engine was running, updating state on main thread before stopping...")
            isRunning = false
            statusMessage = "Stopping engine..."
            stopMeterTimer()
            if let token = activityToken {
                ProcessInfo.processInfo.endActivity(token)
                activityToken = nil
            }
            shouldStartAfterConfig = true
        }
        
        statusMessage = "Configuring Audio Devices..."
        
        // Capture properties for thread safety
        let input = selectedInputDevice
        let output = selectedOutputDevice
        let inputChannel = selectedInputChannel
        let bufferSize = selectedBufferSize
        let existingUnit = helixUnit
        
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            if wasRunning {
                self.log("Stopping hardware engine in background...")
                self.engine.stop()
                self.engine.reset()
            }
            
            self.cleanupAggregateDevice()
            
            self.setupAudioGraphAsync(
                version: currentVersion,
                input: input,
                output: output,
                inputChannel: inputChannel,
                bufferSize: bufferSize,
                existingUnit: existingUnit
            )
        }
    }
    
    private func updateDeviceBufferSize(input: AudioDevice?, output: AudioDevice?, size: UInt32) {
        log("Updating device buffer sizes to \(size)...")
        if let device = output {
            let success = CoreAudioHelper.setBufferSize(deviceID: device.deviceID, size: size)
            log("Set output device \(device.name) buffer size success: \(success)")
        }
        if let device = input {
            let success = CoreAudioHelper.setBufferSize(deviceID: device.deviceID, size: size)
            log("Set input device \(device.name) buffer size success: \(success)")
        }
    }
    
    private func cleanupAggregateDevice() {
        if let aggregateID = aggregateDeviceID {
            log("Cleaning up aggregate device with ID \(aggregateID)...")
            let success = CoreAudioHelper.destroyAggregateDevice(aggregateID)
            log("Destroy aggregate device success: \(success)")
            aggregateDeviceID = nil
        }
    }
    
    private func setupAudioGraphAsync(
        version: Int,
        input: AudioDevice?,
        output: AudioDevice?,
        inputChannel: Int,
        bufferSize: UInt32,
        existingUnit: AVAudioUnit?
    ) {
        log("setupAudioGraphAsync() started for Version: \(version)")
        engine = AVAudioEngine()
        cleanupAggregateDevice()
        
        guard let input = input, let output = output else {
            log("Setup aborted: Input or Output device is nil.")
            DispatchQueue.main.async {
                self.statusMessage = "Error: Input/Output device not selected."
                self.isConfiguring = false
            }
            return
        }
        
        log("Configuring routing: Input=\(input.name), Output=\(output.name)")
        var targetDeviceID = output.deviceID
        
        if input.deviceID != output.deviceID {
            log("Input and Output physical devices are different. Creating programmatic aggregate device...")
            if let aggregateID = CoreAudioHelper.createAggregateDevice(inputUID: input.uid, outputUID: output.uid) {
                self.aggregateDeviceID = aggregateID
                targetDeviceID = aggregateID
                log("Successfully created aggregate device. New ID: \(aggregateID)")
            } else {
                log("Failed to create aggregate device. Falling back to direct output routing.")
            }
        } else {
            log("Input and Output are on the same physical device ID \(output.deviceID). Skipping aggregate device.")
        }
        
        if let outputUnit = engine.outputNode.audioUnit {
            var deviceID = targetDeviceID
            let deviceSize = UInt32(MemoryLayout<AudioDeviceID>.size)
            log("Setting current device ID \(deviceID) on outputNode HAL AudioUnit...")
            let status = AudioUnitSetProperty(
                outputUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &deviceID,
                deviceSize
            )
            log("AudioUnitSetProperty CurrentDevice status code: \(status)")
        } else {
            log("Error: engine.outputNode.audioUnit is nil, cannot set hardware device ID.")
        }
        
        if let inputUnit = engine.inputNode.audioUnit {
            var deviceID = targetDeviceID
            let deviceSize = UInt32(MemoryLayout<AudioDeviceID>.size)
            log("Setting current device ID \(deviceID) on inputNode HAL AudioUnit...")
            let status = AudioUnitSetProperty(
                inputUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &deviceID,
                deviceSize
            )
            log("AudioUnitSetProperty CurrentDevice (inputNode) status code: \(status)")
            
            var channelMap: [Int32] = [Int32(inputChannel)]
            let channelMapSize = UInt32(MemoryLayout<Int32>.size * channelMap.count)
            let mapStatus = AudioUnitSetProperty(
                inputUnit,
                kAudioOutputUnitProperty_ChannelMap,
                kAudioUnitScope_Input,
                1,
                &channelMap,
                channelMapSize
            )
            log("AudioUnitSetProperty ChannelMap (inputNode) status code: \(mapStatus)")
        } else {
            log("Error: engine.inputNode.audioUnit is nil, cannot set hardware device ID.")
        }
        
        updateDeviceBufferSize(input: input, output: output, size: bufferSize)
        
        func configureAndStartEngine(with au: AVAudioUnit) {
            self.log("Attaching Audio Unit to AVAudioEngine...")
            if let oldEngine = au.engine, oldEngine !== self.engine {
                oldEngine.detach(au)
            }
            if au.engine !== self.engine {
                self.engine.attach(au)
            }
            
            self.log("Querying AVAudioEngine hardware formats...")
            let hardwareInputFormat = self.engine.inputNode.inputFormat(forBus: 0)
            let hardwareOutputFormat = self.engine.outputNode.outputFormat(forBus: 0)
            
            self.log("Hardware input format: \(hardwareInputFormat)")
            self.log("Hardware output format: \(hardwareOutputFormat)")
            
            let sampleRate = hardwareInputFormat.sampleRate > 0 ? hardwareInputFormat.sampleRate : (hardwareOutputFormat.sampleRate > 0 ? hardwareOutputFormat.sampleRate : 48000.0)
            guard let monoFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: false
            ),
            let stereoFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 2,
                interleaved: false
            ) else {
                self.log("Error: Failed to create audio formats.")
                DispatchQueue.main.async {
                    self.statusMessage = "Error: Invalid audio format."
                    self.isConfiguring = false
                }
                return
            }
            
            self.log("Connecting nodes: engine.inputNode -> AudioUnit...")
            self.engine.connect(self.engine.inputNode, to: au, format: monoFormat)
            
            self.log("Connecting nodes: AudioUnit -> engine.mainMixerNode...")
            self.engine.connect(au, to: self.engine.mainMixerNode, format: stereoFormat)
            
            self.log("Connecting nodes: engine.mainMixerNode -> engine.outputNode...")
            self.engine.connect(self.engine.mainMixerNode, to: self.engine.outputNode, format: hardwareOutputFormat)
            
            self.log("Installing real-time VU meter taps...")
            self.installMeterTaps()
            
            self.log("Preparing AVAudioEngine...")
            self.engine.prepare()
            
            var startedSuccessfully = false
            var startErrorMsg: String? = nil
            
            if self.shouldStartAfterConfig {
                self.log("Start engine flag is active. Starting engine now...")
                do {
                    try self.engine.start()
                    startedSuccessfully = true
                    self.log("AVAudioEngine started successfully.")
                } catch {
                    startErrorMsg = error.localizedDescription
                    self.log("Failed to start AVAudioEngine: \(error)")
                }
            }
            
            DispatchQueue.main.async {
                self.isConfiguring = false
                if self.shouldStartAfterConfig {
                    if startedSuccessfully {
                        self.isRunning = true
                        self.statusMessage = "Engine active."
                        self.startMeterTimer()
                        self.activityToken = ProcessInfo.processInfo.beginActivity(
                            options: [.userInitiated, .idleSystemSleepDisabled],
                            reason: "Live Audio Hosting"
                        )
                    } else {
                        self.statusMessage = "Start failed: \(startErrorMsg ?? "Unknown error")"
                        self.isRunning = false
                    }
                    self.shouldStartAfterConfig = false
                } else {
                    self.statusMessage = "Audio Unit loaded."
                }
                self.log("Configuring setup completed.")
            }
        }
        
        if let existingUnit = existingUnit {
            self.log("Reusing already instantiated Audio Unit.")
            configureAndStartEngine(with: existingUnit)
            return
        }
        
        // Define plugin (Helix Native)
        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_MusicEffect, // aumf
            componentSubType: 0x36485041,              // '6HPA' (Helix Native)
            componentManufacturer: 0x4c534958,         // 'LSIX' (Line 6)
            componentFlags: 0,
            componentFlagsMask: 0
        )
        
        let component = AudioComponentFindNext(nil, &desc)
        if component == nil {
            log("Helix Native component was not found in system scan.")
            DispatchQueue.main.async {
                self.statusMessage = "Helix Native not installed."
                self.isHelixAvailable = false
                self.isConfiguring = false
            }
            return
        } else {
            log("Line 6 Helix Native component found successfully.")
            DispatchQueue.main.async {
                self.isHelixAvailable = true
            }
        }
        
        DispatchQueue.main.async {
            self.statusMessage = "Loading Audio Unit..."
        }
        log("Calling AVAudioUnit.instantiate asynchronously...")
        
        AVAudioUnit.instantiate(with: desc, options: []) { [weak self] (audioUnit, error) in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let self = self else { return }
                
                self.log("AVAudioUnit.instantiate completion block called for Version \(version). Current Version: \(self.configVersion)")
                
                guard self.configVersion == version else {
                    self.log("Discarding instantiated Audio Unit because Version ID changed (\(version) != \(self.configVersion)).")
                    return
                }
                
                guard let au = audioUnit else {
                    let errMsg = error?.localizedDescription ?? "Unknown error"
                    self.log("Failed to instantiate Audio Unit: \(errMsg)")
                    DispatchQueue.main.async {
                        self.statusMessage = "Load failed: \(errMsg)"
                        self.isConfiguring = false
                    }
                    return
                }
                
                self.log("Audio Unit instantiated successfully.")
                DispatchQueue.main.async {
                    self.helixUnit = au
                }
                configureAndStartEngine(with: au)
            }
        }
    }
    
    private func startMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isRunning else { return }
            self.inputLevel = self.rawInputLevel
            self.outputLevel = self.rawOutputLevel
        }
    }
    
    private func stopMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = nil
        inputLevel = 0.0
        outputLevel = 0.0
        rawInputLevel = 0.0
        rawOutputLevel = 0.0
    }

    private func installMeterTaps() {
        let bufferSize: AVAudioFrameCount = 1024
        
        engine.inputNode.removeTap(onBus: 0)
        engine.mainMixerNode.removeTap(onBus: 0)
        
        engine.inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: nil) { [weak self] (buffer, _) in
            guard let self = self else { return }
            self.rawInputLevel = self.calculateRMS(buffer: buffer)
        }
        
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: bufferSize, format: nil) { [weak self] (buffer, _) in
            guard let self = self else { return }
            self.rawOutputLevel = self.calculateRMS(buffer: buffer)
        }
    }
    
    private func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0.0 }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard channelCount > 0, frameLength > 0 else { return 0.0 }
        
        var maxRms: Float = 0.0
        for ch in 0..<channelCount {
            var rms: Float = 0.0
            vDSP_rmsqv(channelData[ch], 1, &rms, vDSP_Length(frameLength))
            if rms > maxRms {
                maxRms = rms
            }
        }
        return maxRms
    }
}

