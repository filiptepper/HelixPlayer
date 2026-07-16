import SwiftUI

func silenceDuplicateClassWarnings() {
    let pipe = Pipe()
    let origStderr = dup(STDERR_FILENO)
    
    // Redirect stderr to our pipe
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
    
    // Read from the pipe asynchronously
    let readHandle = pipe.fileHandleForReading
    Thread.detachNewThread {
        var buffer = [UInt8](repeating: 0, count: 4096)
        var pendingData = Data()
        
        while true {
            let bytesRead = read(readHandle.fileDescriptor, &buffer, buffer.count)
            if bytesRead <= 0 { break }
            
            pendingData.append(buffer, count: bytesRead)
            
            // Process all complete lines in the buffer
            while let newlineIndex = pendingData.firstIndex(of: 10) { // ASCII '\n'
                let lineData = pendingData.prefix(upTo: newlineIndex + 1)
                pendingData.removeSubrange(..<lineData.count)
                
                if let lineStr = String(data: lineData, encoding: .utf8) {
                    if lineStr.contains("Class L6HttpRequestHandler is implemented in both") {
                        // Silence this warning
                        continue
                    }
                    
                    // Write back other output to the original stderr
                    lineData.withUnsafeBytes { bufferPointer in
                        _ = write(origStderr, bufferPointer.baseAddress!, lineData.count)
                    }
                } else {
                    // If it's not valid UTF-8, write it directly
                    lineData.withUnsafeBytes { bufferPointer in
                        _ = write(origStderr, bufferPointer.baseAddress!, lineData.count)
                    }
                }
            }
        }
    }
}

@main
struct HelixPlayerApp: App {
    init() {
        silenceDuplicateClassWarnings()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
