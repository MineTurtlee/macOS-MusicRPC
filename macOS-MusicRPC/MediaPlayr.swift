//
//  MediaPlayr.swift
//  macOS-MusicRPC
//
//  Created by Flaky le Flaker (Mineturtlee) on 29/8/26.
//

import Foundation

fileprivate var logger = Loggyr("MediaPlayr")

/*
 {
    "type":"data",
    "diff":false,
    "payload": {
        "playbackRate":1,
        "playing":true,
        "elapsedTime":99.926677651999995,
        "timestamp":"2026-08-29T14:49:50Z",
        "bundleIdentifier":"com.apple.controlcenter",
        "processIdentifier":501,
        "artworkData":"",
        "title":"Sacred Play Secret Place - (加减法 Remix) || Hot Music TikTok Douyin 2025",
        "totalQueueCount":2,
        "artworkMimeType":"image\/jpeg",
        "duration":239.566,
        "artist":"1 Giờ Chill",
        "queueIndex":0,
        "contentItemIdentifier":"kjf-dglwNuw"
    }
  }
 */

struct NowPlayingInfo: Equatable {
    let title: String
    let artist: String
    let album: String
    let playing: Bool
    let playbackRate: Float
    var elapsedTime: Float
    let totalQueueCount: Int
    let queueIndex: Int
    let contentItemIdentifier: String // this is the youtube link
    let duration: Float
    let artworkData: String?
    let artworkMimeType: String?
    let bundleIdentifier: String?
}

final class MediaPlayr {
    static let shared = MediaPlayr()

    private var process: Process?
    private var pipe: Pipe?
    private var buffer = Data()
    private var lastKnownState: [String: Any] = [:]
    private var lastEmittedInfo: NowPlayingInfo?
    private var pendingPauseWorkItem: DispatchWorkItem?
    private let pauseHoldDelay: TimeInterval = 0.4

    /// Latest known now-playing info, always available even before the
    /// next onUpdate fires — e.g. useful right after startStreaming() or
    /// for anything that wants to poll instead of subscribe.
    private(set) var currentSnapshot: NowPlayingInfo?
    private var currentCapturedAt: Date?

    // Called every time a new now-playing payload comes in
    var onUpdate: ((NowPlayingInfo) -> Void)?

    private init() {
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            logger.critical("missing \(scriptPath)")
            fatalError()
        }
        guard FileManager.default.fileExists(atPath: frameworkPath) else {
            logger.critical("missing \(frameworkPath)")
            fatalError()
        }

        logger.info("resolved bundled paths ok")
    }

    /// Kick off `mediaremote-adapter.pl stream` as a subprocess and start
    /// parsing its stdout line by line. Each line is one JSON object.
    func startStreaming() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        task.arguments = [scriptPath, frameworkPath, testPath, "stream", "--no-diff"]

        let outPipe = Pipe()
        task.standardOutput = outPipe

        // Anything on stderr is non-fatal per the README, but log it anyway
        let errPipe = Pipe()
        task.standardError = errPipe
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            logger.warning("perl stderr: \(text.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.consume(data)
        }

        do {
            try task.run()
            logger.info("perl stream process started, pid \(task.processIdentifier)")
        } catch {
            logger.critical("failed to launch perl: \(error)")
            fatalError()
        }

        self.process = task
        self.pipe = outPipe
    }

    func stopStreaming() {
        process?.terminate()
        process = nil
        pipe = nil
    }

    /// mediaremote-adapter.pl writes one JSON object per line. Since
    /// availableData can hand us partial lines, buffer until we see
    /// a full newline-terminated chunk.
    private func consume(_ data: Data) {
        buffer.append(data)

        while let newlineRange = buffer.range(of: Data([0x0A])) { // "\n"
            let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<newlineRange.upperBound)

            guard !lineData.isEmpty else { continue }
            handle(line: lineData)
        }
    }

    private func handle(line: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else {
            logger.warning("couldn't parse line: \(String(data: line, encoding: .utf8) ?? "<binary>")")
            return
        }

        // stream payload shape: { "type": "data", "diff": bool, "payload": {...} }
        guard let payload = json["payload"] as? [String: Any] else { return }
        let isDiff = json["diff"] as? Bool ?? false

        if isDiff {
            // Merge partial payload into last known state. A JSON `null`
            // for a key means that field vanished — remove it.
            for (key, value) in payload {
                if value is NSNull {
                    lastKnownState.removeValue(forKey: key)
                } else {
                    lastKnownState[key] = value
                }
            }
        } else {
            // Full snapshot — replace state entirely
            lastKnownState = payload
        }

        let title = lastKnownState["title"] as? String ?? "Unknown Title"
        let artist = lastKnownState["artist"] as? String ?? "Unknown Artist"
        let album = lastKnownState["album"] as? String ?? "Unknown Album"
        let playing = lastKnownState["playing"] as? Bool ?? false
        let playbackRate = (lastKnownState["playbackRate"] as? NSNumber)?.floatValue ?? 1
        let elapsedTime = (lastKnownState["elapsedTime"] as? NSNumber)?.floatValue ?? 0
        let totalQueueCount = lastKnownState["totalQueueCount"] as? Int ?? 1
        let queueIndex = lastKnownState["queueIndex"] as? Int ?? 0
        let duration = (lastKnownState["duration"] as? NSNumber)?.floatValue ?? 0
        let contentItemIdentifier = lastKnownState["contentItemIdentifier"] as? String ?? "Not found"
        let bundleIdentifier = lastKnownState["bundleIdentifier"] as? String
        let artworkMimeType = lastKnownState["artworkMimeType"] as? String
        let artworkDataRaw = lastKnownState["artworkData"] as? String
        // adapter sends "" (empty string) rather than omitting the key
        // when artwork isn't loaded yet — normalize that to nil
        let artworkData = (artworkDataRaw?.isEmpty ?? true) ? nil : artworkDataRaw

        let info = NowPlayingInfo(
            title: title,
            artist: artist,
            album: album,
            playing: playing,
            playbackRate: playbackRate,
            elapsedTime: elapsedTime,
            totalQueueCount: totalQueueCount,
            queueIndex: queueIndex,
            contentItemIdentifier: contentItemIdentifier,
            duration: duration,
            artworkData: artworkData,
            artworkMimeType: artworkMimeType,
            bundleIdentifier: bundleIdentifier
        )

        // Only proceed when something we actually display changed —
        // ignore diffs that only touched fields like elapsedTime/timestamp
        guard info != lastEmittedInfo else { return }

        if info.playing == false {
            // A "stopped" state is often just the old track vanishing a
            // moment before the next one starts (e.g. skip/previous on
            // AirPlay-relayed sources). Hold it briefly — if a "playing"
            // update for a new track arrives before the delay elapses,
            // this pending pause gets cancelled and never emitted.
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.lastEmittedInfo = info
                self.currentSnapshot = info
                self.onUpdate?(info)
            }
            pendingPauseWorkItem?.cancel()
            pendingPauseWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + pauseHoldDelay, execute: workItem)
        } else {
            // A real "playing" update — cancel any pending pause, it's stale
            pendingPauseWorkItem?.cancel()
            pendingPauseWorkItem = nil
            lastEmittedInfo = info
            currentSnapshot = info
            currentCapturedAt = Date()
            onUpdate?(info)
        }
    }
    
    func current() -> NowPlayingInfo? {
        guard let base = currentSnapshot else { return nil }
        guard base.playing, let capturedAt = currentCapturedAt else {
            return base // paused — frozen, no extrapolation
        }
        let elapsedSinceCaptured = Date().timeIntervalSince(capturedAt)
        var live = base
        live.elapsedTime = base.elapsedTime + Float(elapsedSinceCaptured)
        return live
    }

    /// Decode artworkData (base64) into raw image bytes, if present.
    func decodedArtwork(from info: NowPlayingInfo) -> Data? {
        guard let base64 = info.artworkData else { return nil }
        return Data(base64Encoded: base64)
    }
}
