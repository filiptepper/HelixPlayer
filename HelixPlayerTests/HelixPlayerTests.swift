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
}
