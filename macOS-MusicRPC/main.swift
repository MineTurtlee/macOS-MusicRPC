//
//  main.swift
//  macOS-MusicRPC
//
//  Created by Flaky le Flaker (Mineturtlee) on 29/8/26.
//
import Foundation

fileprivate let logger = Loggyr("main")

let dir = UnsafeMutablePointer<ObjCBool>.allocate(capacity: 1)
dir[0] = true

// if CommandLine.arguments.count <= 1 {
//     logger.critical("syntex: \(CommandLine.arguments[0]) <id>")
//     exit(1)
// }
    
if !(executableDir?.starts(with: "/usr/local/bin") ?? false) && !(executableDir?.starts(with: "/usr/bin") ?? false) {
    logger.critical("come back after you installed this, it's not standalone")
    exit(1)
}

if !FileManager.default.fileExists(atPath: scriptPath) || !FileManager.default.fileExists(atPath: frameworkPath, isDirectory: dir) {
    logger.critical("either of the two resources aren't bundled, bundle and come back to me later")
    exit(1)
}

MediaPlayr.shared.startStreaming()
    
let rpc: MusicRPC
let clientId: String
if CommandLine.arguments.count <= 1 {
    clientId = "1485996871536218283"
} else {
    clientId = CommandLine.arguments[1]
}
rpc = MusicRPC.main(clientId: clientId)
rpc.start()
    
logger.info("running, waiting for now-playing changes + discord ipc traffic")
RunLoop.main.run()
