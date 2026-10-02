import Foundation
import Network
import UIKit
import ImageIO

// All network state and JPEG decoding live on one serial queue.
// The UI consumes one latest-frame slot; it never queues every decoded image.
final class PCFrameReceiver {
    struct Snapshot {
        let image: UIImage?
        let status: String
    }
    private let queue = DispatchQueue(label: "vcam.receiver")
    private let lock = NSLock()
    private var snapshot = Snapshot(image: nil, status: "Disconnected")
    private var connection: NWConnection?
    private var generation = 0
    private var running = false
    private var host = ""
    private var port: UInt16 = 5055
    private var width = 0
    private var height = 0
    private var lastNumber: UInt64?
    private var lastTimestamp: UInt64?
    private var lastReceive = Date()
    private var received = 0
    private var reportStart = Date()
    private var watchdog: DispatchSourceTimer?

    func latest() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return snapshot
    }

    private func publish(_ status: String, image: UIImage? = nil) {
        lock.lock()
        snapshot = Snapshot(image: image ?? snapshot.image, status: status)
        lock.unlock()
    }

    func connect(host: String, port: UInt16) {
        queue.async {
            self.running = true
            self.host = host
            self.port = port
            self.begin()
        }
    }

    func stop() {
        queue.async {
            self.running = false
            self.generation += 1
            self.watchdog?.cancel()
            self.watchdog = nil
            self.connection?.cancel()
            self.connection = nil
            self.publish("Disconnected · last image frozen")
        }
    }

    private func begin() {
        generation += 1
        let token = generation
        watchdog?.cancel()
        connection?.cancel()
        lastNumber = nil
        lastTimestamp = nil
        received = 0
        reportStart = Date()
        lastReceive = Date()
        let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        self.connection = connection
        publish("Connecting to \(host):\(port)")
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self, token == self.generation else { return }
            switch state {
            case .ready:
                print("[iOS] Connected to \(self.host)")
                self.readHello(token)
            case .failed(let error): self.fail(token, error.localizedDescription)
            case .waiting(let error): self.publish("Waiting: \(error.localizedDescription)")
            default: break
            }
        }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            guard let self = self, token == self.generation else { return }
            if Date().timeIntervalSince(self.lastReceive) > 5 { self.fail(token, "5s stream timeout") }
        }
        watchdog = timer
        timer.resume()
        connection.start(queue: queue)
    }

    private func fail(_ token: Int, _ reason: String) {
        guard generation == token else { return }
        print("[iOS] \(reason)")
        generation += 1
        let retryToken = generation
        watchdog?.cancel()
        watchdog = nil
        connection?.cancel()
        connection = nil
        publish("\(reason) · frozen · retry in 2s")
        queue.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self, self.running, self.generation == retryToken else { return }
            self.begin()
        }
    }

    private func read(_ count: Int, token: Int, done: @escaping (Data) -> Void) {
        connection?.receive(minimumIncompleteLength: count, maximumLength: count) { [weak self] data, _, complete, error in
            guard let self = self, self.generation == token else { return }
            if let data = data, data.count == count {
                done(data)
            } else {
                self.fail(token, error?.localizedDescription ?? (complete ? "Sender disconnected" : "Truncated packet"))
            }
        }
    }

    private func readHello(_ token: Int) {
        read(16, token: token) { data in
            let bytes = [UInt8](data)
            let width = Int(Self.integer(bytes, 6, 2))
            let height = Int(Self.integer(bytes, 8, 2))
            let fps = Self.integer(bytes, 12, 4)
            guard Array(bytes[0..<4]) == Array("VCAM".utf8), Self.integer(bytes, 4, 2) == 1,
                  Self.integer(bytes, 10, 2) == 1, (1...1920).contains(width),
                  (1...1920).contains(height), (1000...60000).contains(fps) else {
                self.fail(token, "Unsupported handshake")
                return
            }
            self.width = width
            self.height = height
            self.readFrame(token)
        }
    }

    private func readFrame(_ token: Int) {
        read(20, token: token) { header in
            let bytes = [UInt8](header)
            let number = Self.integer(bytes, 0, 8)
            let timestamp = Self.integer(bytes, 8, 8)
            let length = Int(Self.integer(bytes, 16, 4))
            guard (1...8*1024*1024).contains(length),
                  self.lastNumber.map({ number > $0 }) ?? true,
                  self.lastTimestamp.map({ timestamp >= $0 }) ?? true else {
                self.fail(token, "Invalid frame header")
                return
            }
            self.read(length, token: token) { data in
                autoreleasepool {
                    // Inspect encoded dimensions before allocating a decoded bitmap.
                    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                          (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue == self.width,
                          (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue == self.height,
                          let cgImage = CGImageSourceCreateImageAtIndex(source, 0,
                            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else {
                        self.fail(token, "Invalid image or dimensions")
                        return
                    }
                    self.lastNumber = number
                    self.lastTimestamp = timestamp
                    self.lastReceive = Date()
                    self.received += 1
                    let elapsed = max(0.001, Date().timeIntervalSince(self.reportStart))
                    let status = String(format: "%dx%d · frame %llu · %.1f received fps", self.width, self.height, number, Double(self.received) / elapsed)
                    self.publish(status, image: UIImage(cgImage: cgImage))
                    if number % 30 == 0 { print("[iOS] Received frame \(number); sender PTS \(timestamp) us") }
                    self.readFrame(token)
                }
            }
        }
    }

    private static func integer(_ bytes: [UInt8], _ offset: Int, _ count: Int) -> UInt64 {
        bytes[offset..<offset+count].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }
}
