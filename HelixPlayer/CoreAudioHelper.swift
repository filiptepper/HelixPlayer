import CoreAudio
import Foundation

public struct AudioDevice: Identifiable, Hashable {
    public var id: AudioDeviceID { deviceID }
    public let deviceID: AudioDeviceID
    public let name: String
    public let uid: String
    public let inputChannels: Int
    public let outputChannels: Int
    public let sampleRate: Double

    public func hash(into hasher: inout Hasher) {
        hasher.combine(deviceID)
    }
    
    public static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        return lhs.deviceID == rhs.deviceID
    }
}

public class CoreAudioHelper {
    public static func getAllDevices() -> [AudioDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        guard status == noErr else { return [] }
        
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs)
        guard status == noErr else { return [] }
        
        var devices: [AudioDevice] = []
        for deviceID in deviceIDs {
            // 1. Get Name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: 0
            )
            var nameCF: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            status = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &nameCF)
            let name = (status == noErr) ? (nameCF as String) : "Unknown Device"
            
            // 2. Get UID
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: 0
            )
            var uidCF: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            status = AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &uidCF)
            let uid = (status == noErr) ? (uidCF as String) : ""
            
            // 3. Channels Count
            let inputChannels = getChannelCount(deviceID: deviceID, isInput: true)
            let outputChannels = getChannelCount(deviceID: deviceID, isInput: false)
            
            // 4. Sample Rate
            var rateAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyNominalSampleRate,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: 0
            )
            var sampleRate: Double = 0.0
            var rateSize = UInt32(MemoryLayout<Double>.size)
            status = AudioObjectGetPropertyData(deviceID, &rateAddress, 0, nil, &rateSize, &sampleRate)
            
            devices.append(AudioDevice(
                deviceID: deviceID,
                name: name,
                uid: uid,
                inputChannels: inputChannels,
                outputChannels: outputChannels,
                sampleRate: sampleRate
            ))
        }
        return devices
    }
    
    private static func getChannelCount(deviceID: AudioDeviceID, isInput: Bool) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
            mElement: 0
        )
        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        guard status == noErr && size > 0 else { return 0 }
        
        let rawPtr = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { rawPtr.deallocate() }
        let bufferList = rawPtr.bindMemory(to: AudioBufferList.self, capacity: 1)
        
        status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, bufferList)
        guard status == noErr else { return 0 }
        
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        var channelCount = 0
        for buffer in buffers {
            channelCount += Int(buffer.mNumberChannels)
        }
        return channelCount
    }
    
    public static func getBufferSize(deviceID: AudioDeviceID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSize,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        var bufferSize: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &bufferSize)
        return status == noErr ? bufferSize : 0
    }
    
    public static func setBufferSize(deviceID: AudioDeviceID, size: UInt32) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSize,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        var bufferSize = size
        let dataSize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, dataSize, &bufferSize)
        return status == noErr
    }
    
    public static func destroyAllOrphanedAggregateDevices() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        guard status == noErr else { return }
        
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs)
        guard status == noErr else { return }
        
        for deviceID in deviceIDs {
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: 0
            )
            var uidCF: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            status = AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &uidCF)
            
            if status == noErr {
                let uid = uidCF as String
                if uid.hasPrefix("com.helixplayer.aggregate") {
                    print("[CoreAudioHelper] Found orphaned aggregate device: \(uid) (ID: \(deviceID)), destroying...")
                    _ = AudioHardwareDestroyAggregateDevice(deviceID)
                }
            }
        }
    }
    
    public static func createAggregateDevice(inputUID: String, outputUID: String) -> AudioDeviceID? {
        let subDevices: [[String: Any]] = [
            [
                kAudioSubDeviceUIDKey: inputUID,
                kAudioSubDeviceDriftCompensationKey: 1
            ],
            [
                kAudioSubDeviceUIDKey: outputUID,
                kAudioSubDeviceDriftCompensationKey: 0 // Clock master
            ]
        ]
        
        let uniqueUID = "com.helixplayer.aggregate.\(UUID().uuidString)"
        let desc: [String: Any] = [
            kAudioAggregateDeviceNameKey: "HelixPlayer Aggregate",
            kAudioAggregateDeviceUIDKey: uniqueUID,
            kAudioAggregateDeviceSubDeviceListKey: subDevices,
            kAudioAggregateDeviceIsPrivateKey: true // Private to process
        ]
        
        var aggregateID: AudioDeviceID = 0
        let status = AudioHardwareCreateAggregateDevice(desc as CFDictionary, &aggregateID)
        return status == noErr ? aggregateID : nil
    }
    
    public static func destroyAggregateDevice(_ deviceID: AudioDeviceID) -> Bool {
        let status = AudioHardwareDestroyAggregateDevice(deviceID)
        return status == noErr
    }
}
