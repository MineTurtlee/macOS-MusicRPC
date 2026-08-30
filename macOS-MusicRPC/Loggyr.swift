//
//  Loggyr.swift
//  macOS-MusicRPC
//
//  Created by Flaky le Flaker (Mineturtlee) on 29/8/26.
//

import Foundation

struct Loggyr {
    let name: String
    
    init(name: String) {
        self.name = name
    }
    
    init(_ name: String) {
        self.name = name
    }
    
    private func log(_ messaj: String, _ level: Level) {
        print("[\(Date.now.ISO8601Format())] [\(level.rawValue)] [\(self.name)] \(messaj)")
    }
    
    func trace(_ messaj: String) {
        log(messaj, .trace)
    }
    
    func debug(_ messaj: String) {
        log(messaj, .debug)
    }
    
    func info(_ messaj: String) {
        log(messaj, .info)
    }
    
    func notice(_ messaj: String) {
        log(messaj, .notice)
    }
    
    func warning(_ messaj: String) {
        log(messaj, .warning)
    }
    
    func error(_ messaj: String) {
        log(messaj, .error)
    }
    
    func fault(_ messaj: String) {
        log(messaj, .fault)
    }
    
    func critical(_ messaj: String) {
        log(messaj, .critical)
    }
    
    enum Level: String {
        case trace = "Trace"
        case debug = "Debug"
        case info = "Info"
        case notice = "Notice"
        case warning = "Warning"
        case error = "Error"
        case fault = "Fault"
        case critical = "Critical"
    }
}
