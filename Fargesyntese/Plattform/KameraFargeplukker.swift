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
    @ObservationIgnored private var enhet: AVCaptureDevice?

    /// Om kameraet har en lyskilde (bakkamera på iPhone/iPad, Continuity-iPhone på Mac).
    private(set) var harLykt = false
    private(set) var lyktPå = false
    /// Lysstyrke 0…1 (der enheten støtter trinnløs styrke).
    private(set) var lyktNivå: Float = 1
    /// Zoom relativt til vanlig 1×-utsnitt (0,5 = ultravidvinkel på iPhone).
    private(set) var zoom: CGFloat = 1
    @ObservationIgnored private var grunnZoom: CGFloat = 1
    @ObservationIgnored private var zoomVedStart: CGFloat = 1

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

    /// Slår lykten av/på med valgt styrke. Jevnt, kjent lys gir mer stabile målinger
    /// i mørke omgivelser; merk at lyktens fargetemperatur også påvirker resultatet.
    func settLykt(på: Bool, nivå: Float? = nil) {
        guard let enhet, enhet.hasTorch else { return }
        if let nivå { lyktNivå = min(max(nivå, 0.05), 1) }
        let styrke = lyktNivå
        kø.async {
            guard (try? enhet.lockForConfiguration()) != nil else { return }
            defer { enhet.unlockForConfiguration() }
            if på {
                #if os(iOS)
                try? enhet.setTorchModeOn(level: min(styrke, AVCaptureDevice.maxAvailableTorchLevel))
                #else
                if enhet.isTorchModeSupported(.on) { enhet.torchMode = .on }
                #endif
            } else if enhet.isTorchModeSupported(.off) {
                enhet.torchMode = .off
            }
        }
        lyktPå = på
    }

    func stopp() {
        if lyktPå { settLykt(på: false) }
        let økt = self.økt
        kø.async { økt.stopRunning() }
    }

    /// Velger kamera. På iPhone foretrekkes de virtuelle multikameraene, som automatisk bytter til
    /// ultravidvinkel (makro) på kort hold – vidvinkelen alene fokuserer ikke nærmere enn ca. 15–20 cm.
    private static func velgKamera() -> AVCaptureDevice? {
        #if os(iOS)
        let typer: [AVCaptureDevice.DeviceType] = [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera]
        let søk = AVCaptureDevice.DiscoverySession(deviceTypes: typer, mediaType: .video, position: .back)
        for type in typer {
            if let enhet = søk.devices.first(where: { $0.deviceType == type }) { return enhet }
        }
        #endif
        return AVCaptureDevice.default(for: .video)
    }

    /// Kontinuerlig autofokus med vekt på korte avstander, og kontinuerlig eksponering.
    /// Returnerer zoomfaktoren som tilsvarer vanlig 1×.
    @discardableResult
    private static func stillInnFokus(_ enhet: AVCaptureDevice) -> CGFloat {
        var grunn: CGFloat = 1
        guard (try? enhet.lockForConfiguration()) != nil else { return grunn }
        defer { enhet.unlockForConfiguration() }
        if enhet.isFocusModeSupported(.continuousAutoFocus) { enhet.focusMode = .continuousAutoFocus }
        if enhet.isExposureModeSupported(.continuousAutoExposure) { enhet.exposureMode = .continuousAutoExposure }
        #if os(iOS)
        // Virtuelt multikamera: start på vanlig 1×-utsnitt (første overgang), og la iOS bytte til
        // ultravidvinkel automatisk når motivet er for nært for vidvinkelen (som makro i Kamera-appen).
        if let overgang = enhet.virtualDeviceSwitchOverVideoZoomFactors.first {
            grunn = CGFloat(truncating: overgang)
            enhet.videoZoomFactor = grunn
            if enhet.activePrimaryConstituentDeviceSwitchingBehavior != .unsupported {
                enhet.setPrimaryConstituentDeviceSwitchingBehavior(.auto, restrictedSwitchingBehaviorConditions: [])
            }
        }
        if enhet.isAutoFocusRangeRestrictionSupported { enhet.autoFocusRangeRestriction = .near }
        if enhet.isSmoothAutoFocusSupported { enhet.isSmoothAutoFocusEnabled = false }
        #endif
        return grunn
    }

    #if os(iOS)
    /// Knip i forhåndsvisningen: `skala` er relativ til zoomen da knipet startet.
    func knip(_ skala: CGFloat, begynner: Bool) {
        if begynner { zoomVedStart = zoom }
        settZoom(zoomVedStart * skala)
    }

    /// Setter zoom relativt til 1× (0,5× … 10×, innenfor det kameraet støtter).
    func settZoom(_ relativ: CGFloat) {
        guard let enhet else { return }
        let minst = enhet.minAvailableVideoZoomFactor / grunnZoom
        let mest = min(enhet.maxAvailableVideoZoomFactor / grunnZoom, 10)
        let ny = min(max(relativ, minst), mest)
        zoom = ny
        let faktor = ny * grunnZoom
        kø.async {
            guard (try? enhet.lockForConfiguration()) != nil else { return }
            enhet.videoZoomFactor = faktor
            enhet.unlockForConfiguration()
        }
    }
    #endif

    /// Fokus og eksponering på punktet brukeren trykket på (normaliserte enhetskoordinater).
    private func fokuser(på punkt: CGPoint) {
        guard let enhet else { return }
        kø.async {
            guard (try? enhet.lockForConfiguration()) != nil else { return }
            defer { enhet.unlockForConfiguration() }
            if enhet.isFocusPointOfInterestSupported {
                enhet.focusPointOfInterest = punkt
                if enhet.isFocusModeSupported(.continuousAutoFocus) { enhet.focusMode = .continuousAutoFocus }
            }
            if enhet.isExposurePointOfInterestSupported {
                enhet.exposurePointOfInterest = punkt
                if enhet.isExposureModeSupported(.continuousAutoExposure) { enhet.exposureMode = .continuousAutoExposure }
            }
        }
    }

    /// Flytter målpunktet og fanger fargen der fra neste bilde.
    /// - Parameters:
    ///   - enhetspunkt: normalisert punkt (0…1) i kamerabufferens koordinater.
    ///   - visningspunkt: samme punkt i forhåndsvisningen, for markøren.
    func plukk(enhetspunkt: CGPoint, visningspunkt: CGPoint) {
        markør = visningspunkt
        fokuser(på: enhetspunkt)
        leser.sett(mål: enhetspunkt, fang: true)
    }

    /// Fanger fargen i gjeldende målpunkt (utløserknappen).
    func fang() {
        if let gjeldende { vedFangst?(gjeldende) }
    }

    /// Målpunkt, fokus og eksponering tilbake til midten av bildet.
    func tilbakestillMarkør() {
        let midten = CGPoint(x: 0.5, y: 0.5)
        markør = nil
        fokuser(på: midten)
        leser.sett(mål: midten, fang: false)
    }

    private func konfigurer() {
        økt.beginConfiguration()
        defer { økt.commitConfiguration() }
        økt.sessionPreset = .high
        guard let enhet = Self.velgKamera(),
              let inn = try? AVCaptureDeviceInput(device: enhet), økt.canAddInput(inn)
        else { return }
        grunnZoom = Self.stillInnFokus(enhet)
        zoom = 1
        økt.addInput(inn)
        self.enhet = enhet
        harLykt = enhet.hasTorch
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
    /// (skala relativt til start av knipet, om knipet nettopp begynte)
    var vedKnip: (CGFloat, Bool) -> Void = { _, _ in }
    var vedDobbelttrykk: () -> Void = {}

    final class Visning: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var lag: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        var vedTrykk: (CGPoint, CGPoint) -> Void = { _, _ in }
        var vedKnip: (CGFloat, Bool) -> Void = { _, _ in }
        var vedDobbelttrykk: () -> Void = {}

        @objc func trykket(_ g: UITapGestureRecognizer) {
            let p = g.location(in: self)
            vedTrykk(lag.captureDevicePointConverted(fromLayerPoint: p), p)
        }

        @objc func knepet(_ g: UIPinchGestureRecognizer) {
            switch g.state {
            case .began: vedKnip(g.scale, true)
            case .changed: vedKnip(g.scale, false)
            default: break
            }
        }

        @objc func dobbelttrykket(_ g: UITapGestureRecognizer) { vedDobbelttrykk() }
    }

    func makeUIView(context: Context) -> Visning {
        let v = Visning()
        v.lag.session = økt
        v.lag.videoGravity = .resizeAspectFill
        let enkelt = UITapGestureRecognizer(target: v, action: #selector(Visning.trykket(_:)))
        let dobbelt = UITapGestureRecognizer(target: v, action: #selector(Visning.dobbelttrykket(_:)))
        dobbelt.numberOfTapsRequired = 2
        enkelt.require(toFail: dobbelt)
        v.addGestureRecognizer(enkelt)
        v.addGestureRecognizer(dobbelt)
        v.addGestureRecognizer(UIPinchGestureRecognizer(target: v, action: #selector(Visning.knepet(_:))))
        v.isAccessibilityElement = true
        v.accessibilityLabel = "Kamerabilde. Trykk for å plukke fargen der, knip for å zoome."
        return v
    }

    func updateUIView(_ uiView: Visning, context: Context) {
        uiView.vedTrykk = vedTrykk
        uiView.vedKnip = vedKnip
        uiView.vedDobbelttrykk = vedDobbelttrykk
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
