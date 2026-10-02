import AVFoundation
import UIKit
import CoreImage

// Renders only normal capture callbacks. No PC-frame selection here.
final class CameraModel: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "vcam.camera")
    private let lock = NSLock()
    private let context = CIContext()
    private var configured = false
    private var wanted = false
    private var frame: UIImage?
    private var status = "Camera stopped"
    private var callbacks = 0
    private var replaced = 0
    func latest() -> (UIImage?, String) {
        lock.lock(); defer { lock.unlock() }; return (frame, status)
    }
    private func report(_ value: String) { lock.lock(); status = value; lock.unlock() }
    func start() {
        queue.async {
            self.wanted = true
            AVCaptureDevice.requestAccess(for: .video) { allowed in
                self.queue.async {
                    guard self.wanted else { return }
                    guard allowed else { self.report("Camera permission denied — enable in Settings"); return }
                    do {
                        if !self.configured { try self.configure() }
                        if !self.session.isRunning { self.session.startRunning() }
                        self.report("Waiting for camera callbacks")
                    } catch { self.report("Camera error: \(error.localizedDescription)") }
                }
            }
        }
    }
    func stop() {
        queue.async {
            self.wanted = false
            if self.session.isRunning { self.session.stopRunning() }
            self.report("Camera stopped")
        }
    }
    private func configure() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw NSError(domain: "Camera", code: 1)
        }
        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        session.beginConfiguration(); defer { session.commitConfiguration() }
        session.sessionPreset = .hd1280x720
        guard session.canAddInput(input) else { throw NSError(domain: "Camera", code: 2) }
        session.addInput(input)
        guard session.canAddOutput(output) else {
            session.removeInput(input); throw NSError(domain: "Camera", code: 3)
        }
        session.addOutput(output)
        output.setSampleBufferDelegate(self, queue: queue)
        if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        configured = true
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ci = CIImage(cvPixelBuffer: pixel)
        guard let cg = context.createCGImage(ci, from: ci.extent) else { return }
        callbacks += 1
        if VCWasSubstituted(sampleBuffer) { replaced += 1 }
        let pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        lock.lock()
        frame = UIImage(cgImage: cg)
        status = "Callback \(callbacks) · replaced \(replaced) · \(CVPixelBufferGetWidth(pixel))×\(CVPixelBufferGetHeight(pixel)) · PTS \(String(format: "%.2f", pts))"
        lock.unlock()
        if callbacks % 30 == 0 { print("[TEST] callbacks \(callbacks), replaced \(replaced)") }
    }
}
