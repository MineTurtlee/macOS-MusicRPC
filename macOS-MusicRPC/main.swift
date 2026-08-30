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

guard CommandLine.arguments.count > 1 else {
    logger.critical("syntex: \(CommandLine.arguments[0]) <id>")
    fatalError()
}

if !executableDir.path().starts(with: "/usr/local/bin") || !executableDir.path().starts(with: "/usr/bin") {
    logger.critical("come back after you installed this, it's not standalone")
    fatalError()
}

if !FileManager.default.fileExists(atPath: scriptPath) || !FileManager.default.fileExists(atPath: frameworkPath, isDirectory: dir) {
    logger.critical("either of the two resources aren't bundled, bundle and come back to me later")
    fatalError()
}

MediaPlayr.shared.startStreaming()

let rpc = MusicRPC.main()
rpc.start()

logger.info("running, waiting for now-playing changes + discord ipc traffic")
RunLoop.main.run()
