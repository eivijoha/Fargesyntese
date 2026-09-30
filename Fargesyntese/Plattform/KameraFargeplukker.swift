@preconcurrency import AVFoundation
import FargeKjerne
import SwiftUI

/// Leser fargen i et valgt punkt i kamerabildet fortløpende (iPhone, iPad og Mac via
/// innebygd kamera eller Continuity Camera). Trykk/klikk i bildet flytter punktet og fanger fargen.
///
/// Fargen er et gjennomsnitt av et lite felt for å dempe støy. Kamerabufferens
/// fargerom (sRGB eller Display P3) leses fra bufferens metadata.
/// NB: automatisk hvitbalanse påvirker resultatet – lås av hvitbalanse er planlagt.
@Observable
final class KameraFargeplukker {
    private(set) var gjeldende: Farge?
    private(set) var tilgangNektet = false
    /// Markørens plassering i forhåndsvisningen (SwiftUI-punkter); nil = midten.
    private(set) var markør: CGPoint?
    let økt = AVCaptureSession()
    /// Kalles på hovedtråden når et trykk/klikk har fanget en farge.
    @ObservationIgnored var vedFangst: ((Farge) -> Void)?

    @ObservationIgnored private let leser = BufferLeser()
    @ObservationIgnored private let kø = DispatchQueue(label: "no.engenett.fargesyntese.kamera")
    @ObservationIgnored private var erKonfigurert = false

    func start() async {
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            tilgangNektet = true
            return
        }
        if !erKonfigurert { konfigurer() }
        leser.vedFarge = { [weak self] farge, erFangst in
            Task { @MainActor in
                self?.gjeldende = farge
                if erFangst { self?.vedFangst?(farge) }
            }
        }
        let økt = self.økt
        kø.async { økt.startRunning() }
    }

    func stopp() {
        let økt = self.økt
        kø.async { økt.stopRunning() }
    }

    /// Flytter målpunktet og fanger fargen der fra neste bilde.
    /// - Parameters:
    ///   - enhetspunkt: normalisert punkt (0…1) i kamerabufferens koordinater.
    ///   - visningspunkt: samme punkt i forhåndsvisningen, for markøren.
    func plukk(enhetspunkt: CGPoint, visningspunkt: CGPoint) {
        markør = visningspunkt
        leser.sett(mål: enhetspunkt, fang: true)
    }

    /// Fanger fargen i gjeldende målpunkt (utløserknappen).
    func fang() {
        if let gjeldende { vedFangst?(gjeldende) }
    }

    func tilbakestillMarkør() {
        markør = nil
        leser.sett(mål: CGPoint(x: 0.5, y: 0.5), fang: false)
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
///
/// Bufferne er ikke rotert, så de ligger i sensorens orientering – samme koordinatsystem
/// som `AVCaptureVideoPreviewLayer.captureDevicePointConverted(fromLayerPoint:)` gir.
nonisolated private final class BufferLeser: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    var vedFarge: (@Sendable (Farge, Bool) -> Void)?
    private var sist = Date.distantPast
    private let lås = NSLock()
    private var mål = CGPoint(x: 0.5, y: 0.5)
    private var ventendeFangst = false

    func sett(mål nytt: CGPoint, fang: Bool) {
        lås.withLock {
            mål = CGPoint(x: min(max(nytt.x, 0), 1), y: min(max(nytt.y, 0), 1))
            ventendeFangst = fang
            sist = .distantPast  // les neste bilde med en gang
        }
    }

    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let (punkt, fangst, forTidlig) = lås.withLock { () -> (CGPoint, Bool, Bool) in
            let forTidlig = Date.now.timeIntervalSince(sist) <= 0.1
            if forTidlig { return (mål, false, true) }
            sist = .now
            defer { ventendeFangst = false }
            return (mål, ventendeFangst, false)
        }
        guard !forTidlig, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
        let bredde = CVPixelBufferGetWidth(buffer), høyde = CVPixelBufferGetHeight(buffer)
        let radbytes = CVPixelBufferGetBytesPerRow(buffer)
        let piksler = base.assumingMemoryBound(to: UInt8.self)

        // Gjennomsnitt i lineært lys over et 9×9-felt rundt målpunktet.
        let halv = 4
        let cx = min(max(Int(punkt.x * Double(bredde)), halv), bredde - 1 - halv)
        let cy = min(max(Int(punkt.y * Double(høyde)), halv), høyde - 1 - halv)
        var sum = (r: 0.0, g: 0.0, b: 0.0), antall = 0.0
        for y in (cy - halv)...(cy + halv) {
            for x in (cx - halv)...(cx + halv) {
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
        vedFarge?(farge, fangst)
    }

    private static func lineær(_ v: UInt8) -> Double {
        let c = Double(v) / 255
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
}

// MARK: - Forhåndsvisning

#if canImport(UIKit)
/// Forhåndsvisning som melder trykk som (enhetspunkt, visningspunkt).
struct KameraForhåndsvisning: UIViewRepresentable {
    let økt: AVCaptureSession
    var vedTrykk: (CGPoint, CGPoint) -> Void = { _, _ in }

    final class Visning: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var lag: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        var vedTrykk: (CGPoint, CGPoint) -> Void = { _, _ in }

        @objc func trykket(_ g: UITapGestureRecognizer) {
            let p = g.location(in: self)
            vedTrykk(lag.captureDevicePointConverted(fromLayerPoint: p), p)
        }
    }

    func makeUIView(context: Context) -> Visning {
        let v = Visning()
        v.lag.session = økt
        v.lag.videoGravity = .resizeAspectFill
        v.addGestureRecognizer(UITapGestureRecognizer(target: v, action: #selector(Visning.trykket(_:))))
        v.isAccessibilityElement = true
        v.accessibilityLabel = "Kamerabilde. Trykk for å plukke fargen der."
        return v
    }

    func updateUIView(_ uiView: Visning, context: Context) {
        uiView.vedTrykk = vedTrykk
    }
}
#elseif canImport(AppKit)
struct KameraForhåndsvisning: NSViewRepresentable {
    let økt: AVCaptureSession
    var vedTrykk: (CGPoint, CGPoint) -> Void = { _, _ in }

    final class Visning: NSView {
        let lag: AVCaptureVideoPreviewLayer
        var vedTrykk: (CGPoint, CGPoint) -> Void = { _, _ in }

        init(økt: AVCaptureSession) {
            lag = AVCaptureVideoPreviewLayer(session: økt)
            super.init(frame: .zero)
            lag.videoGravity = .resizeAspectFill
            layer = lag
            wantsLayer = true
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) er ikke støttet") }

        override func mouseDown(with event: NSEvent) {
            // Visning og lag har begge origo nede til venstre; SwiftUI har origo oppe til venstre.
            let p = convert(event.locationInWindow, from: nil)
            vedTrykk(lag.captureDevicePointConverted(fromLayerPoint: p), CGPoint(x: p.x, y: bounds.height - p.y))
        }

        override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    }

    func makeNSView(context: Context) -> Visning { Visning(økt: økt) }

    func updateNSView(_ nsView: Visning, context: Context) {
        nsView.vedTrykk = vedTrykk
    }
}
#endif
