import Foundation
import AVFoundation
import CoreAudio
import AudioToolbox
import Combine
import Accelerate

// Lock-free single-producer single-consumer ring buffer for low-latency audio streaming
final class AudioRingBuffer {
    private let capacity: Int
    private let buffer: UnsafeMutablePointer<Float>
    private var writeHead: Int = 0
    private var readHead: Int = 0
    
    init(capacity: Int = 16384) {
        self.capacity = capacity
        self.buffer = UnsafeMutablePointer<Float>.allocate(capacity: capacity)
        self.buffer.initialize(repeating: 0, count: capacity)
    }
    
    deinit {
        buffer.deallocate()
    }
    
    func reset() {
        writeHead = 0
        readHead = 0
        buffer.initialize(repeating: 0, count: capacity)
    }
    
    func availableToRead() -> Int {
        let w = writeHead
        let r = readHead
        if w >= r {
            return w - r
        } else {
            return capacity - (r - w)
        }
    }
    
    func write(from ptr: UnsafePointer<Float>, count: Int) {
        var w = writeHead
        for i in 0..<count {
            buffer[w] = ptr[i]
            w = (w + 1) % capacity
        }
        writeHead = w
    }
    
    func read(into ptr: UnsafeMutablePointer<Float>, count: Int) {
        let avail = availableToRead()
        // Clock drift protection: if latency accumulates past ~42ms (2048 samples at 48kHz),
        // adjust read head forward to keep latency bounded to ~5.3ms (256 samples).
        if avail > 2048 {
            var newR = writeHead - 256
            if newR < 0 { newR += capacity }
            readHead = newR
        }
        
        let validAvail = availableToRead()
        let toRead = min(validAvail, count)
        var r = readHead
        for i in 0..<toRead {
            ptr[i] = buffer[r]
            r = (r + 1) % capacity
        }
        readHead = r
        
        if toRead < count {
            for i in toRead..<count {
                ptr[i] = 0
            }
        }
    }
}

// Dedicated CoreAudio HAL input capturer running on its own independent stream
final class AudioInputCapturer {
    private var unit: AudioUnit?
    private let ringBuffer: AudioRingBuffer
    private let onRMSUpdate: ((Float) -> Void)?
    
    private var bufferList: AudioBufferList
    private let sampleBuffer: UnsafeMutablePointer<Float>
    private let maxFrames: UInt32 = 4096
    
    init(
        deviceID: AudioDeviceID,
        inputChannel: Int,
        sampleRate: Float64,
        bufferSize: UInt32,
        ringBuffer: AudioRingBuffer,
        onRMSUpdate: ((Float) -> Void)?
    ) throws {
        self.ringBuffer = ringBuffer
        self.onRMSUpdate = onRMSUpdate
        
        self.sampleBuffer = UnsafeMutablePointer<Float>.allocate(capacity: Int(maxFrames))
        self.bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: maxFrames * UInt32(MemoryLayout<Float>.size),
                mData: sampleBuffer
            )
        )
        
        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        
        guard let comp = AudioComponentFindNext(nil, &desc) else {
            throw NSError(domain: "AudioInputCapturer", code: -1, userInfo: [NSLocalizedDescriptionKey: "HALOutput component not found"])
        }
        
        var unit: AudioUnit?
        var status = AudioComponentInstanceNew(comp, &unit)
        guard let unit = unit, status == noErr else {
            throw NSError(domain: "AudioInputCapturer", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to create AudioComponentInstance (\(status))"])
        }
        self.unit = unit
        
        // 1. Enable input (bus 1)
        var enableIO: UInt32 = 1
        status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enableIO, UInt32(MemoryLayout<UInt32>.size))
        guard status == noErr else { throw NSError(domain: "AudioInputCapturer", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to enable input IO"]) }
        
        // 2. Disable output (bus 0)
        enableIO = 0
        status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &enableIO, UInt32(MemoryLayout<UInt32>.size))
        guard status == noErr else { throw NSError(domain: "AudioInputCapturer", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to disable output IO"]) }
        
        // 3. Set device
        var devID = deviceID
        status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &devID, UInt32(MemoryLayout<AudioDeviceID>.size))
        guard status == noErr else { throw NSError(domain: "AudioInputCapturer", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to set input device (\(status))"]) }
        
        // 4. Set stream format (bus 1 output scope)
        var streamDesc = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        status = AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &streamDesc, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        guard status == noErr else { throw NSError(domain: "AudioInputCapturer", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to set stream format (\(status))"]) }
        
        // 5. Set channel map
        var channelMap = [Int32(inputChannel)]
        let channelMapSize = UInt32(MemoryLayout<Int32>.size * channelMap.count)
        _ = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Input, 1, &channelMap, channelMapSize)
        
        // 6. Set buffer size
        var bufSize = bufferSize
        _ = AudioUnitSetProperty(unit, kAudioDevicePropertyBufferFrameSize, kAudioUnitScope_Global, 0, &bufSize, UInt32(MemoryLayout<UInt32>.size))
        
        // 7. Set input callback
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var callbackStruct = AURenderCallbackStruct(
            inputProc: { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
                let capturer = Unmanaged<AudioInputCapturer>.fromOpaque(inRefCon).takeUnretainedValue()
                return capturer.renderCallback(ioActionFlags: ioActionFlags, inTimeStamp: inTimeStamp, inNumberFrames: inNumberFrames)
            },
            inputProcRefCon: selfPtr
        )
        status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callbackStruct, UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        guard status == noErr else { throw NSError(domain: "AudioInputCapturer", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to set input callback (\(status))"]) }
        
        // 8. Initialize
        status = AudioUnitInitialize(unit)
        guard status == noErr else { throw NSError(domain: "AudioInputCapturer", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to initialize AudioUnit (\(status))"]) }
    }
    
    deinit {
        stop()
        if let u = unit {
            AudioUnitUninitialize(u)
            AudioComponentInstanceDispose(u)
        }
        sampleBuffer.deallocate()
    }
    
    func start() throws {
        guard let u = unit else { return }
        let status = AudioOutputUnitStart(u)
        guard status == noErr else {
            throw NSError(domain: "AudioInputCapturer", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "AudioOutputUnitStart failed (\(status))"])
        }
    }
    
    func stop() {
        guard let u = unit else { return }
        AudioOutputUnitStop(u)
    }
    
    private func renderCallback(
        ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        inTimeStamp: UnsafePointer<AudioTimeStamp>,
        inNumberFrames: UInt32
    ) -> OSStatus {
        guard let u = unit else { return noErr }
        let framesToRender = min(inNumberFrames, maxFrames)
        bufferList.mBuffers.mDataByteSize = framesToRender * UInt32(MemoryLayout<Float>.size)
        
        let err = AudioUnitRender(u, ioActionFlags, inTimeStamp, 1, framesToRender, &bufferList)
        guard err == noErr else { return err }
        
        ringBuffer.write(from: sampleBuffer, count: Int(framesToRender))
        
        var rms: Float = 0.0
        vDSP_rmsqv(sampleBuffer, 1, &rms, vDSP_Length(framesToRender))
        onRMSUpdate?(rms)
        
        return noErr
    }
}

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
    private var sourceNode: AVAudioSourceNode?
    private var inputCapturer: AudioInputCapturer?
    private let ringBuffer = AudioRingBuffer(capacity: 16384)
    
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
            
            if self.helixUnit != nil && self.inputCapturer != nil {
                self.log("Audio Unit and Input Capturer already ready. Starting engine directly...")
                do {
                    try self.engine.start()
                    try self.inputCapturer?.start()
                    self.isRunning = true
                    self.statusMessage = "Engine active."
                    self.startMeterTimer()
                    self.log("AVAudioEngine and InputCapturer started successfully.")
                    
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
        
        log("Stopping engine and input capturer...")
        engine.stop()
        inputCapturer?.stop()
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
                self.inputCapturer?.stop()
                self.engine.reset()
            }
            
            self.inputCapturer = nil
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
            if device.isMultiOutput {
                let subUIDs = CoreAudioHelper.getSubDeviceUIDs(for: device.deviceID)
                for subUID in subUIDs {
                    if let subDevID = CoreAudioHelper.getDeviceID(for: subUID) {
                        let success = CoreAudioHelper.setBufferSize(deviceID: subDevID, size: size)
                        log("Set subdevice \(subUID) buffer size success: \(success)")
                    }
                }
            } else {
                let success = CoreAudioHelper.setBufferSize(deviceID: device.deviceID, size: size)
                log("Set output device \(device.name) buffer size success: \(success)")
            }
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
        ringBuffer.reset()
        cleanupAggregateDevice()
        
        guard let input = input, let output = output else {
            log("Setup aborted: Input or Output device is nil.")
            DispatchQueue.main.async {
                self.statusMessage = "Error: Input/Output device not selected."
                self.isConfiguring = false
            }
            return
        }
        
        log("Configuring routing: Input=\(input.name) (ID \(input.deviceID)), Output=\(output.name) (ID \(output.deviceID))")
        
        // Output device is directly assigned to AVAudioEngine outputNode HAL unit
        let targetDeviceID = output.deviceID
        let totalOutputChannels = CoreAudioHelper.getChannelCount(deviceID: targetDeviceID, isInput: false)
        
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
            
            // Output Channel Mapping: ensure stereo out goes to all speaker/headphone pairs
            if totalOutputChannels > 0 {
                var channelMap = [Int32](repeating: -1, count: totalOutputChannels)
                if output.isMultiOutput {
                    // Mirror stereo (Left=0, Right=1) to each stereo pair across all subdevices
                    for ch in stride(from: 0, through: totalOutputChannels - 2, by: 2) {
                        channelMap[ch] = 0     // Left
                        channelMap[ch + 1] = 1 // Right
                    }
                } else {
                    if totalOutputChannels >= 2 {
                        channelMap[0] = 0
                        channelMap[1] = 1
                    } else if totalOutputChannels == 1 {
                        channelMap[0] = 0
                    }
                }
                let channelMapSize = UInt32(MemoryLayout<Int32>.size * channelMap.count)
                let mapStatus = AudioUnitSetProperty(
                    outputUnit,
                    kAudioOutputUnitProperty_ChannelMap,
                    kAudioUnitScope_Output,
                    0,
                    &channelMap,
                    channelMapSize
                )
                log("AudioUnitSetProperty ChannelMap (outputNode) status code: \(mapStatus), map: \(channelMap)")
            }
        } else {
            log("Error: engine.outputNode.audioUnit is nil, cannot set hardware device ID.")
        }
        
        updateDeviceBufferSize(input: input, output: output, size: bufferSize)
        
        let sampleRate: Float64 = (output.sampleRate > 0) ? output.sampleRate : 48000.0
        
        // Initialize dedicated low-latency CoreAudio input capturer
        do {
            self.inputCapturer = try AudioInputCapturer(
                deviceID: input.deviceID,
                inputChannel: inputChannel,
                sampleRate: sampleRate,
                bufferSize: bufferSize,
                ringBuffer: self.ringBuffer,
                onRMSUpdate: { [weak self] rms in
                    self?.rawInputLevel = rms
                }
            )
            log("AudioInputCapturer initialized successfully.")
        } catch {
            log("Failed to initialize AudioInputCapturer: \(error)")
            DispatchQueue.main.async {
                self.statusMessage = "Input init failed: \(error.localizedDescription)"
                self.isConfiguring = false
            }
            return
        }
        
        func configureAndStartEngine(with au: AVAudioUnit) {
            self.log("Attaching Audio Unit to AVAudioEngine...")
            if let oldEngine = au.engine, oldEngine !== self.engine {
                oldEngine.detach(au)
            }
            if au.engine !== self.engine {
                self.engine.attach(au)
            }
            
            self.log("Querying AVAudioEngine hardware formats...")
            let hardwareOutputFormat = self.engine.outputNode.outputFormat(forBus: 0)
            self.log("Hardware output format: \(hardwareOutputFormat)")
            
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
            
            // Create AVAudioSourceNode pulling from the lock-free ring buffer
            let sourceNode = AVAudioSourceNode(format: monoFormat) { [weak ringBuffer = self.ringBuffer] _, _, frameCount, audioBufferList -> OSStatus in
                guard let ringBuffer = ringBuffer else { return noErr }
                let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
                if let buffer = abl.first, let ptr = buffer.mData?.assumingMemoryBound(to: Float.self) {
                    ringBuffer.read(into: ptr, count: Int(frameCount))
                }
                return noErr
            }
            self.sourceNode = sourceNode
            self.engine.attach(sourceNode)
            
            self.log("Connecting nodes: sourceNode -> AudioUnit...")
            self.engine.connect(sourceNode, to: au, format: monoFormat)
            
            self.log("Connecting nodes: AudioUnit -> engine.mainMixerNode...")
            self.engine.connect(au, to: self.engine.mainMixerNode, format: stereoFormat)
            
            self.log("Connecting nodes: engine.mainMixerNode -> engine.outputNode...")
            let outFormat = hardwareOutputFormat.channelCount > 0 ? hardwareOutputFormat : stereoFormat
            self.engine.connect(self.engine.mainMixerNode, to: self.engine.outputNode, format: outFormat)
            
            self.log("Installing real-time VU meter taps...")
            self.installMeterTaps()
            
            self.log("Preparing AVAudioEngine...")
            self.engine.prepare()
            
            // Re-assert channel map after prepare() to guarantee AUHAL does not reset to default 1:1 map
            if let outputUnit = self.engine.outputNode.audioUnit, totalOutputChannels > 0 {
                var channelMap = [Int32](repeating: -1, count: totalOutputChannels)
                if output.isMultiOutput {
                    for ch in stride(from: 0, through: totalOutputChannels - 2, by: 2) {
                        channelMap[ch] = 0
                        channelMap[ch + 1] = 1
                    }
                } else {
                    if totalOutputChannels >= 2 {
                        channelMap[0] = 0
                        channelMap[1] = 1
                    } else if totalOutputChannels == 1 {
                        channelMap[0] = 0
                    }
                }
                let mapSize = UInt32(MemoryLayout<Int32>.size * channelMap.count)
                _ = AudioUnitSetProperty(outputUnit, kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 0, &channelMap, mapSize)
                _ = AudioUnitSetProperty(outputUnit, kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Global, 0, &channelMap, mapSize)
                self.log("Post-prepare channelMap asserted: \(channelMap)")
            }
            
            var startedSuccessfully = false
            var startErrorMsg: String? = nil
            
            if self.shouldStartAfterConfig {
                self.log("Start engine flag is active. Starting engine now...")
                do {
                    try self.engine.start()
                    try self.inputCapturer?.start()
                    startedSuccessfully = true
                    self.log("AVAudioEngine and InputCapturer started successfully.")
                } catch {
                    startErrorMsg = error.localizedDescription
                    self.log("Failed to start audio engine: \(error)")
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
        engine.mainMixerNode.removeTap(onBus: 0)
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
