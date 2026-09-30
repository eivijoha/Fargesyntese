@preconcurrency import AVFoundation
import FargeKjerne
import SwiftUI

/// Leser fargen i midten av kamerabildet fortløpende (iPhone, iPad og Mac via
/// innebygd kamera eller Continuity Camera).
///
/// Fargen er et gjennomsnitt av et lite felt for å dempe støy. Kamerabufferens
/// fargerom (sRGB eller Display P3) leses fra bufferens metadata.
/// NB: automatisk hvitbalanse påvirker resultatet – lås av hvitbalanse er planlagt.
@Observable
final class KameraFargeplukker {
    private(set) var gjeldende: Farge?
    private(set) var tilgangNektet = false
    let økt = AVCaptureSession()

    @ObservationIgnored private let leser = BufferLeser()
    @ObservationIgnored private let kø = DispatchQueue(label: "no.engenett.fargesyntese.kamera")
    @ObservationIgnored private var erKonfigurert = false

    func start() async {
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            tilgangNektet = true
            return
        }
        if !erKonfigurert { konfigurer() }
        leser.vedFarge = { [weak self] farge in
            Task { @MainActor in self?.gjeldende = farge }
        }
        let økt = self.økt
        kø.async { økt.startRunning() }
    }

    func stopp() {
        let økt = self.økt
        kø.async { økt.stopRunning() }
    }

    private func konfigurer() {
        økt.beginConfiguration()
        defer { økt.commitConfiguration() }
        økt.sessionPreset = .high
        guard let enhet = AVCaptureDevice.default(for: .video),
              let inn = try? AVCaptureDeviceInput(device: enhet), økt.canAddInput(inn)
        else { return }
        økt.addInput(inn)
        let ut = AVCaptureVideoDataOutput()
        ut.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        ut.alwaysDiscardsLateVideoFrames = true
        ut.setSampleBufferDelegate(leser, queue: kø)
        if økt.canAddOutput(ut) { økt.addOutput(ut) }
        erKonfigurert = true
    }
}

/// Kjører på kamerakøen; rapporterer en farge omtrent 10 ganger i sekundet.
nonisolated private final class BufferLeser: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    var vedFarge: (@Sendable (Farge) -> Void)?
    private var sist = Date.distantPast

    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard Date.now.timeIntervalSince(sist) > 0.1,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }
        sist = .now

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
        let bredde = CVPixelBufferGetWidth(buffer), høyde = CVPixelBufferGetHeight(buffer)
        let radbytes = CVPixelBufferGetBytesPerRow(buffer)
        let piksler = base.assumingMemoryBound(to: UInt8.self)

        // Gjennomsnitt i lineært lys over et 9×9-felt i midten.
        let halv = 4
        var sum = (r: 0.0, g: 0.0, b: 0.0), antall = 0.0
        for y in (høyde / 2 - halv)...(høyde / 2 + halv) {
            for x in (bredde / 2 - halv)...(bredde / 2 + halv) {
                let p = piksler + y * radbytes + x * 4  // BGRA
                sum.b += Self.lineær(p[0]); sum.g += Self.lineær(p[1]); sum.r += Self.lineær(p[2])
                antall += 1
            }
        }
        let gamma = { (v: Double) in v <= 0.0031308 ? v * 12.92 : 1.055 * pow(v, 1 / 2.4) - 0.055 }
        let (r, g, b) = (gamma(sum.r / antall), gamma(sum.g / antall), gamma(sum.b / antall))

        let primærer = CVBufferCopyAttachment(buffer, kCVImageBufferColorPrimariesKey, nil) as? String
        let farge = primærer == (kCVImageBufferColorPrimaries_P3_D65 as String)
            ? Farge(displayP3: DisplayP3(r: r, g: g, b: b))
            : Farge(sRGB: SRGB(r: r, g: g, b: b))
        vedFarge?(farge)
    }

    private static func lineær(_ v: UInt8) -> Double {
        let c = Double(v) / 255
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
}

// MARK: - Forhåndsvisning

#if canImport(UIKit)
struct KameraForhåndsvisning: UIViewRepresentable {
    let økt: AVCaptureSession

    final class Visning: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var lag: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> Visning {
        let v = Visning()
        v.lag.session = økt
        v.lag.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: Visning, context: Context) {}
}
#elseif canImport(AppKit)
struct KameraForhåndsvisning: NSViewRepresentable {
    let økt: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        let lag = AVCaptureVideoPreviewLayer(session: økt)
        lag.videoGravity = .resizeAspectFill
        v.layer = lag
        v.wantsLayer = true
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
