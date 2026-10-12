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
    public var isMultiOutput: Bool {
        uid.hasPrefix("~:AMS2_StackedOutput")
    }

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
    
    public static func getChannelCount(deviceID: AudioDeviceID, isInput: Bool) -> Int {
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
    
    public static func getDeviceID(for uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        guard status == noErr else { return nil }
        
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs)
        guard status == noErr else { return nil }
        
        for deviceID in deviceIDs {
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: 0
            )
            var uidCF: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            if AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &uidCF) == noErr {
                if (uidCF as String) == uid {
                    return deviceID
                }
            }
        }
        return nil
    }
    
    public static func getSubDeviceUIDs(for deviceID: AudioDeviceID) -> [String] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyOwnedObjects,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &size)
        guard status == noErr && size > 0 else { return [] }
        
        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var objectIDs = [AudioObjectID](repeating: 0, count: count)
        let err = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &objectIDs)
        guard err == noErr else { return [] }
        
        var uids: [String] = []
        for objID in objectIDs {
            var classID: AudioClassID = 0
            var classSize = UInt32(MemoryLayout<AudioClassID>.size)
            var classAddr = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyClass,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectGetPropertyData(objID, &classAddr, 0, nil, &classSize, &classID) == noErr {
                // 'asub' = 0x61737562 (kAudioSubDeviceClassID)
                if classID == 0x61737562 {
                    var uidAddr = AudioObjectPropertyAddress(
                        mSelector: kAudioDevicePropertyDeviceUID,
                        mScope: kAudioObjectPropertyScopeGlobal,
                        mElement: kAudioObjectPropertyElementMain
                    )
                    var cfStr: Unmanaged<CFString>?
                    var strSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
                    if AudioObjectGetPropertyData(objID, &uidAddr, 0, nil, &strSize, &cfStr) == noErr,
                       let uid = cfStr?.takeRetainedValue() as String? {
                        uids.append(uid)
                    }
                }
            }
        }
        return uids
    }
    
    public static func createAggregateDevice(inputUID: String, outputUID: String) -> AudioDeviceID? {
        var outputUIDs: [String] = []
        if outputUID.hasPrefix("~:AMS2_StackedOutput") {
            if let outDeviceID = getDeviceID(for: outputUID) {
                outputUIDs = getSubDeviceUIDs(for: outDeviceID)
            }
            if outputUIDs.isEmpty {
                print("[CoreAudioHelper] Unable to unpack subdevices for Multi-Output device (\(outputUID)).")
                return nil
            }
            print("[CoreAudioHelper] Unpacked Multi-Output device into subdevices: \(outputUIDs)")
        } else {
            outputUIDs = [outputUID]
        }
        
        // Always place inputUID as the first subdevice (index 0) so that:
        // 1. Selected input channels match inputUID starting at channel 0
        // 2. The physical input device acts as clock master (drift = 0)
        var subDevices: [[String: Any]] = [
            [
                kAudioSubDeviceUIDKey: inputUID,
                kAudioSubDeviceDriftCompensationKey: 0
            ]
        ]
        
        for uid in outputUIDs {
            if uid != inputUID {
                subDevices.append([
                    kAudioSubDeviceUIDKey: uid,
                    kAudioSubDeviceDriftCompensationKey: 1
                ])
            }
        }
        
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
