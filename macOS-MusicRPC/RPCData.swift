//
//  RPCData.swift
//  macOS-MusicRPC
//
//  Created by Flaky le Flaker (Mineturtlee) on 29/8/26.
//

import Foundation

struct Activity: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case type
        case URL = "url"
        case createdAt = "created_at"
        case timestamps
        case appId = "application_id"
        case statusDisplay = "status_display_type"
        case details
        case detailsURL = "details_url"
        case state
        case stateURL = "state_url"
        case emoji
        case assets
        case secrets
        case instance
        case flags
        case buttons
    }
    
    var name: String
    var type: Types // edit later
    var URL: String?
    
    var createdAt: Date // has to be a timestamp in ms
    var timestamps: Timestamps? // edit later
    
    var appId: String?
    var statusDisplay: DisplayTypes? // status_display_type; come back later
    
    var details: String?
    var detailsURL: String?
    
    var state: String?
    var stateURL: String?
    
    var emoji: [Emoji]? // Come back later bish
    var party: [Party]? // come back 2
    var assets: [Assets]? // revise
    var secrets: [Secrets]? // really revisit it
    var instance: Bool?
    var flags: Int?
    var buttons: [Button]? // just come bac kplease!!!
    
    enum Types: Int, Codable {
        case playing = 0
        case streaming = 1
        case listening = 2
        case watching = 3
        case custom = 4
        case competing = 5
    }
    
    enum DisplayTypes: Int, Codable {
        case name = 0
        case state = 1
        case details = 2
    }
    
    struct Timestamps: Codable {
        var start: Int?  // unix epoch milliseconds
        var end: Int?
    }
    
    struct Emoji: Codable {
        var name: String
        var id: String?
        var animated: Bool?
    }
    
    struct Party: Codable {
        var id: String?
        var size: [Int]?
    }
    
    struct Assets: Codable {
        enum CodingKeys: String, CodingKey {
            case largeImage = "large_image"
            case largeText = "large_text"
            case smallImage = "small_image"
            case smallText = "small_text"
            case smallURL = "small_url"
            case inviteBannerImage = "invite_cover_image"
        }
        
        var largeImage: String?
        var largeText: String?
        var smallImage: String?
        var smallText: String?
        var smallURL: String?
        var inviteBannerImage: String?
    }
    
    struct Secrets: Codable {
        var join: String?
        var spectate: String?
        var match: String?
    }
    
    struct Flags: OptionSet, Codable {
        let rawValue: UInt64
        
        init(_ v: UInt64) {rawValue = v}
        
        init(rawValue: UInt64) {
            self.rawValue = rawValue
        }
        
        static let instance = Flags(1 << 0)
        static let join = Flags(1 << 1)
        static let spectate = Flags(1 << 2)
        static let joinRequest = Flags(1 << 3)
        static let sync = Flags(1 << 4)
        static let play = Flags(1 << 5)
        static let partyFriends = Flags(1 << 6)
        static let partyVC = Flags(1 << 7)
        static let embedded = Flags(1 << 8)
    }
    
    struct Button: Codable {
        enum CodingKeys: String, CodingKey {
            case label
            case URL = "url"
        }
        
        var label: String
        var URL: String
    }
}

struct ActPayload: Codable {
    var cmd: String
    var nonce: String
    var args: SetRPC
}

struct Handshake: Codable {
    enum CodingKeys: String, CodingKey {
        case version = "v"
        case clientId = "client_id"
    }
    
    var version: Int
    var clientId: String
}

struct SetRPC: Codable {
    enum CodingKeys: String, CodingKey {
        case PID = "pid"
        case activity
    }
    
    var PID = ProcessInfo.processInfo.processIdentifier
    var activity: Activity
}

func makeHandshake(payload: Handshake) throws -> Data {
    makeFrame(opcode: 0, payload: try JSONEncoder().encode(payload))
}

func makeRPC(rpc: Activity) throws -> Data {
    let presence = SetRPC(activity: rpc)
    let frame = makeFrame(opcode: 1, payload: try JSONEncoder().encode(ActPayload(cmd: "SET_ACTIVITY", nonce: "turteneezed", args: presence)))
    
    return frame
}

func makeFrame(opcode: UInt32, payload: Data) -> Data {
    var frame = makeOpcode(opcode: opcode)

    var length = UInt32(payload.count).littleEndian
    withUnsafeBytes(of: &length) { frame.append(contentsOf: $0) }

    frame.append(payload)
    return frame
}

func makeOpcode(opcode: UInt32) -> Data {
    var frame = Data()

    var op = opcode.littleEndian
    withUnsafeBytes(of: &op) { frame.append(contentsOf: $0) }
    
    return frame
}
