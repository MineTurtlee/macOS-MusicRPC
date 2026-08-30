//
//  MusicRPC.swift
//  macOS-MusicRPC
//
//  Created by Flaky le Flaker (Mineturtlee) on 29/8/26.
//

import Foundation
import Network
import Dispatch

fileprivate var logger = Loggyr("MusicRPC")

class MusicRPC {
    let queue = DispatchQueue.main
    var params = NWParameters.tcp
    var endpoint: NWEndpoint?
    var socket: NWConnection?
    var clientId: String
    
    lazy var timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
    
    // basically classmethod but wahtevrer
    static func main(clientId: String) -> MusicRPC {
        return MusicRPC(clientId: clientId)
    }
    
    func makePres(_ info: NowPlayingInfo) -> Activity {
        let startDate = Date() - TimeInterval(info.elapsedTime)
        let endDate = startDate.addingTimeInterval(TimeInterval(info.duration))
        
        return Activity(
            name: info.title,
            type: .listening,
            createdAt: .now,
            timestamps: .init(
                start: Int(startDate.timeIntervalSince1970 * 1000),
                end: Int(endDate.timeIntervalSince1970 * 1000)
            ),
            appId: self.clientId,
            statusDisplay: Activity.DisplayTypes.details,
            details: "\(info.artist) - \(info.title)",
            state: "Identifier: \(info.contentItemIdentifier)",
            buttons: [Activity.Button(label: "Guess it's on Youtube?", URL: "https://youtube.com/watch?v=\(info.contentItemIdentifier)")]
        )
    }
    
    init(clientId: String) {
        let path = FileManager.default.temporaryDirectory.path
        let endpoint = NWEndpoint.unix(path: "\(path)/discord-ipc-0")
        socket = NWConnection(to: endpoint, using: params)
        
        self.clientId = clientId
        socket?.stateUpdateHandler = stateUpdate
        
        MediaPlayr.shared.onUpdate = { [self] info in
            do {
                var activity = makePres(info)
                notPlayen: if !info.playing {
                    guard let state = activity.state else {
                        activity.state = "Paused"
                        break notPlayen
                    }
                    activity.state = "Paused | \(state)"
                }
                
                socket?.send(content: try makeRPC(rpc: activity), completion: .contentProcessed { error in
                    if let error {
                        logger.warning("i failed to update the rpc \(error.localizedDescription)")
                    }
                })
            } catch {
                logger.error("i tried updating this hsit because it updated :( \(error.localizedDescription)")
            }
        }
        
        timer.schedule(deadline: .now(), repeating: .seconds(1))
        timer.setEventHandler { [self] in
            guard let current = MediaPlayr.shared.current(), current.playing else {
                logger.info("timer tick: paused or no data, skipping send")
                return
            }
            
            logger.info("timer tick: sending update, elapsed=\(current.elapsedTime)")
            do {
                socket?.send(content: try makeRPC(rpc: makePres(current)), completion: .contentProcessed { error in
                    if let error {
                        logger.warning("i failed to update the rpc \(error.localizedDescription)")
                    }
                })
            } catch {
                logger.error("i tried updating but no worky \(error.localizedDescription)")
            }
        }
    }
    
    func start() {
        socket?.start(queue: queue)
        timer.resume()
    }
    
    func stop() {
        socket?.send(content: makeOpcode(opcode: 2), completion: .contentProcessed { error in
            if let error {
                logger.warning("wtf happened to the close request \(error.localizedDescription)")
            } else {
                logger.info("closed")
            }
        })
        socket?.cancel()
    }
    
    func stateUpdate(state: NWConnection.State) {
        switch state {
        case .cancelled:
            logger.warning("connection cancelled")
            break
        case .failed(let error):
            logger.error("connection failed: \(error)")
            break
        case .ready:
            logger.info("connection ready, gonna listen")
            handshake()
            startRecv()
            break
        case .preparing:
            logger.info("prepping the connection")
            break
        case .setup:
            logger.info("lemme start the socket")
            start()
            break
        case .waiting(let error):
            logger.warning("why the fuck is it waiting bro \(error)")
            break
        default: logger.warning("rando unknown shit appeared! state below"); print(state); break
        }
    }
    
    func handshake() {
        do {
            try socket?.send(content: makeFrame(opcode: 0, payload: JSONEncoder().encode(Handshake(version: 1, clientId: self.clientId))), completion: .contentProcessed { error in
                if let error {
                    logger.error("error handshaking: \(error.localizedDescription)")
                } else {
                    logger.info("good handshake")
                }
            })
        } catch {
            logger.error("i cant send handshek message: \(error.localizedDescription)")
        }
    }
    
    func startRecv() {
        socket?.receive(minimumIncompleteLength: 0, maximumLength: 524288, completion: { content, contentContext, isComplete, error in
            if let content, !content.isEmpty {
                print("Received: \(String(data: content, encoding: .utf8) ?? "<binary>")")
            }
            if let error {
                print("Receive error: \(error)")
                return
            }
            if !isComplete {
                self.startRecv() // keep listening
            }
        })
    }
}
