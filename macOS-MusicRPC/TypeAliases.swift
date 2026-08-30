//
//  TypeAliases.swift
//  macOS-MusicRPC
//
//  Created by Flaky le Flaker (Mineturtlee) on 29/8/26.
//

import Foundation

let executableDir = Bundle.main.executablePath
let bundledDir = URL(fileURLWithPath: "/usr/local/share/musicrpc")

let scriptPath = bundledDir.appendingPathComponent("mediaremote-adapter.pl").path
let frameworkPath = bundledDir.appendingPathComponent("MediaRemoteAdapter.framework").path
let testPath = bundledDir.appendingPathComponent("MediaRemoteAdapterTestClient").path
