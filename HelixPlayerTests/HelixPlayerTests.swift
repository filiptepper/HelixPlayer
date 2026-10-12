import XCTest
import AVFoundation
@testable import HelixPlayer

final class HelixPlayerTests: XCTestCase {
    func testCoreAudioDeviceFetching() {
        let devices = CoreAudioHelper.getAllDevices()
        XCTAssertFalse(devices.isEmpty, "System should report at least one audio device (e.g., system output).")
        for dev in devices {
            XCTAssertFalse(dev.name.isEmpty, "Device must have a non-empty name.")
            XCTAssertFalse(dev.uid.isEmpty, "Device must have a non-empty UID.")
        }
    }
    
    func testBufferSizeHelpers() {
        let devices = CoreAudioHelper.getAllDevices()
        guard let testDevice = devices.first(where: { $0.outputChannels > 0 }) else { return }
        let currentSize = CoreAudioHelper.getBufferSize(deviceID: testDevice.deviceID)
        XCTAssertGreaterThan(currentSize, 0, "Buffer size should be greater than 0.")
    }
    
    func testAudioEngineManagerInitialization() {
        let manager = AudioEngineManager()
        XCTAssertFalse(manager.isRunning, "Engine should not be running immediately upon initialization.")
        XCTAssertFalse(manager.isBypassed, "Engine should not be bypassed upon initialization.")
    }
    
    func testBypassToggle() {
        let manager = AudioEngineManager()
        XCTAssertFalse(manager.isBypassed)
        manager.toggleBypass()
        XCTAssertTrue(manager.isBypassed)
    }
    
    func testMultiChannelOutputRoutingWithAudioUnit() {
        let engine = AVAudioEngine()
        let delayComponent = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_Delay,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        
        let expectation = self.expectation(description: "AudioUnit instantiated")
        AVAudioUnit.instantiate(with: delayComponent, options: []) { au, error in
            XCTAssertNotNil(au)
            guard let au = au else {
                expectation.fulfill()
                return
            }
            engine.attach(au)
            
            let stereoFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 2, interleaved: false)!
            let layout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | 4)!
            let fourChannelFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 48000,
                interleaved: false,
                channelLayout: layout
            )
            
            engine.connect(au, to: engine.mainMixerNode, format: stereoFormat)
            engine.connect(engine.mainMixerNode, to: engine.outputNode, format: fourChannelFormat)
            
            XCTAssertNoThrow(engine.prepare())
            do {
                try engine.start()
                engine.stop()
            } catch {
                XCTFail("Failed to start engine: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testMultiOutputDetection() {
        let multiOutput = AudioDevice(
            deviceID: 999,
            name: "OBS Recorder",
            uid: "~:AMS2_StackedOutput:0",
            inputChannels: 0,
            outputChannels: 2,
            sampleRate: 48000
        )
        let standardDevice = AudioDevice(
            deviceID: 998,
            name: "BlackHole 2ch",
            uid: "BlackHole2ch_UID",
            inputChannels: 2,
            outputChannels: 2,
            sampleRate: 48000
        )
        XCTAssertTrue(multiOutput.isMultiOutput)
        XCTAssertFalse(standardDevice.isMultiOutput)
    }
    
    func testMultiOutputHandling() {
        let devices = CoreAudioHelper.getAllDevices()
        if let multiOutput = devices.first(where: { $0.isMultiOutput }) {
            let subUIDs = CoreAudioHelper.getSubDeviceUIDs(for: multiOutput.deviceID)
            XCTAssertFalse(subUIDs.isEmpty, "Multi-Output device should have unpacked subdevices.")
            
            if let inputDev = devices.first(where: { $0.inputChannels > 0 }) {
                let aggID = CoreAudioHelper.createAggregateDevice(
                    inputUID: inputDev.uid,
                    outputUID: multiOutput.uid
                )
                XCTAssertNotNil(aggID, "Aggregate device creation with Multi-Output should succeed.")
                if let id = aggID {
                    _ = CoreAudioHelper.destroyAggregateDevice(id)
                }
            }
        } else {
            let result = CoreAudioHelper.createAggregateDevice(
                inputUID: "BuiltInMicrophoneDevice",
                outputUID: "~:AMS2_StackedOutput:9999"
            )
            XCTAssertNil(result, "Non-existent Multi-Output device should fail gracefully.")
        }
    }
}
