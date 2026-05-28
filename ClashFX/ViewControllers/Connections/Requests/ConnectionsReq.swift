//
//  ConnectionsReq.swift
//  ClashX
//
//  Created by yicheng on 2023/7/14.
//  Copyright © 2023 west2online. All rights reserved.
//

import Foundation
import Starscream

@available(macOS 10.15, *)
class ConnectionsReq: WebSocketDelegate {
    private var socket: WebSocket?

    let decoder = JSONDecoder()
    var onSnapshotUpdate: ((ClashConnectionSnapShot) -> Void)?
    init() {
        guard let url = URL(string: ConfigManager.apiUrl.appending("/connections")) else {
            decoder.dateDecodingStrategy = .formatted(DateFormatter.js)
            return
        }
        var request = URLRequest(url: url)
        for header in ApiRequest.authHeader() {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        let socket = WebSocket(request: request)
        socket.delegate = self
        self.socket = socket
        decoder.dateDecodingStrategy = .formatted(DateFormatter.js)
    }

    func connect() {
        socket?.connect()
    }

    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected:
            Logger.log("websocketDidConnect")
        case let .disconnected(reason, code):
            Logger.log("websocketDidDisconnect: \(reason) (code=\(code))", level: .warning)
        case let .text(text):
            if let data = text.data(using: .utf8) {
                do {
                    let info = try decoder.decode(ClashConnectionSnapShot.self, from: data)
                    onSnapshotUpdate?(info)
                } catch {
                    Logger.log("decode fail: \(error)", level: .warning)
                }
            }
        case .cancelled:
            Logger.log("websocket cancelled", level: .warning)
        case .peerClosed:
            Logger.log("websocket peer closed", level: .warning)
        case let .error(error):
            Logger.log("websocket error: \(String(describing: error))", level: .warning)
        case .binary, .ping, .pong, .viabilityChanged, .reconnectSuggested:
            break
        }
    }
}
