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
}
