#if SIRKELEKSPORT
import CoreGraphics
import FargeKjerne
import Foundation
import UniformTypeIdentifiers

/// Fargesirkelen fra Harmoni som vektorgrafikk (SVG og PDF) – laget til arbeidet med app-ikonet.
/// Avslått: kompileres bare med betingelsen `SIRKELEKSPORT` (legg den til under Build Settings ›
/// Active Compilation Conditions for Debug, så dukker «Eksporter sirkelen» opp under fargesirkelen).
/// Geometrien er den samme som i ``Fargesirkelvisning``.
struct Fargesirkeltegning {
    struct Markør { var vinkel: Double; var farge: Farge; var erGrunn: Bool }

    /// Ringens farge for hvert segment (startvinkel i grader, 0 = opp, med klokka).
    var segmenter: [(vinkel: Double, farge: Farge)]
    /// Tegnes i denne rekkefølgen (siste øverst), som i Canvas-visningen.
    var markører: [Markør]
    var midt: Farge

    static let antallSegmenter = 120
    static let side: Double = 1024

    // Mål relativt til radius r = side/2, som i visningen (der r ≈ 110 pt).
    private var r: Double { Self.side / 2 }
    private var senter: Double { Self.side / 2 }

    init(grunnfarge: Farge, farger: [Farge], sirkel: Fargesirkel, ringfarge: ((Double) -> Farge)?, midtfarge: Farge?) {
        segmenter = (0..<Self.antallSegmenter).map { i in
            let a = Double(i) / Double(Self.antallSegmenter) * 360
            return (a, ringfarge?(a) ?? sirkel.ringfarge(vinkel: a, grunn: grunnfarge))
        }
        let midt = midtfarge ?? grunnfarge
        markører = farger.reversed().map { Markør(vinkel: sirkel.vinkel(for: $0), farge: $0, erGrunn: $0 == midt) }
        self.midt = midt
    }

    private func punkt(_ vinkel: Double, _ radius: Double) -> CGPoint {
        let v = (vinkel - 90) * .pi / 180
        return CGPoint(x: senter + cos(v) * radius, y: senter + sin(v) * radius)
    }

    private var indre: Double { r * 0.65 }
    private var ytre: Double { r * 0.95 }
    /// Litt overlapp mellom segmentene, så det ikke blir hårfine sprekker.
    private var segmentbredde: Double { 360 / Double(Self.antallSegmenter) + 0.4 }
    private var linjebredde: Double { r / 110 }

    // MARK: SVG

    var svg: String {
        func f(_ x: Double) -> String { String(format: "%.2f", x) }
        func hex(_ farge: Farge) -> String { farge.gamutKartlagt(til: .sRGB).hex() }
        var ut = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="\(Int(Self.side))" height="\(Int(Self.side))" viewBox="0 0 \(Int(Self.side)) \(Int(Self.side))">
          <g id="ring">

        """
        for s in segmenter {
            let a0 = s.vinkel, a1 = s.vinkel + segmentbredde
            let p0 = punkt(a0, ytre), p1 = punkt(a1, ytre), p2 = punkt(a1, indre), p3 = punkt(a0, indre)
            ut += "    <path fill=\"\(hex(s.farge))\" d=\"M\(f(p0.x)) \(f(p0.y)) A\(f(ytre)) \(f(ytre)) 0 0 1 \(f(p1.x)) \(f(p1.y)) L\(f(p2.x)) \(f(p2.y)) A\(f(indre)) \(f(indre)) 0 0 0 \(f(p3.x)) \(f(p3.y)) Z\"/>\n"
        }
        ut += "  </g>\n  <g id=\"markorer\">\n"
        for m in markører {
            let p = punkt(m.vinkel, r * 0.8)
            let d = m.erGrunn ? r * 0.26 : r * 0.19
            ut += "    <line x1=\"\(f(senter))\" y1=\"\(f(senter))\" x2=\"\(f(p.x))\" y2=\"\(f(p.y))\" stroke=\"#000000\" stroke-opacity=\"0.35\" stroke-width=\"\(f(linjebredde))\"/>\n"
            ut += "    <circle cx=\"\(f(p.x))\" cy=\"\(f(p.y))\" r=\"\(f(d / 2))\" fill=\"\(hex(m.farge))\" stroke=\"#FFFFFF\" stroke-width=\"\(f(linjebredde * (m.erGrunn ? 3 : 2)))\"/>\n"
        }
        ut += "  </g>\n"
        ut += "  <circle id=\"midt\" cx=\"\(f(senter))\" cy=\"\(f(senter))\" r=\"\(f(r * 0.34))\" fill=\"\(hex(midt))\"/>\n</svg>\n"
        return ut
    }

    // MARK: PDF (vektor, farger i Display P3)

    var pdf: Data {
        let data = NSMutableData()
        var boks = CGRect(x: 0, y: 0, width: Self.side, height: Self.side)
        guard let forbruker = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: forbruker, mediaBox: &boks, nil),
              let p3 = CGColorSpace(name: CGColorSpace.displayP3)
        else { return Data() }
        func farge(_ f: Farge) -> CGColor {
            let v = f.gamutKartlagt(til: .displayP3).displayP3
            return CGColor(colorSpace: p3, components: [v.r, v.g, v.b, 1])!
        }
        ctx.beginPDFPage(nil)
        // PDF har origo nede til venstre; speil så vinklene blir som i SVG og i appen.
        ctx.translateBy(x: 0, y: Self.side)
        ctx.scaleBy(x: 1, y: -1)
        for s in segmenter {
            let a0 = (s.vinkel - 90) * .pi / 180, a1 = (s.vinkel + segmentbredde - 90) * .pi / 180
            let sti = CGMutablePath()
            sti.addArc(center: CGPoint(x: senter, y: senter), radius: ytre, startAngle: a0, endAngle: a1, clockwise: false)
            sti.addArc(center: CGPoint(x: senter, y: senter), radius: indre, startAngle: a1, endAngle: a0, clockwise: true)
            sti.closeSubpath()
            ctx.addPath(sti)
            ctx.setFillColor(farge(s.farge))
            ctx.fillPath()
        }
        for m in markører {
            let p = punkt(m.vinkel, r * 0.8)
            ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.35))
            ctx.setLineWidth(linjebredde)
            ctx.move(to: CGPoint(x: senter, y: senter))
            ctx.addLine(to: p)
            ctx.strokePath()
            let d = m.erGrunn ? r * 0.26 : r * 0.19
            let rute = CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)
            ctx.setFillColor(farge(m.farge))
            ctx.fillEllipse(in: rute)
            ctx.setStrokeColor(CGColor(gray: 1, alpha: 1))
            ctx.setLineWidth(linjebredde * (m.erGrunn ? 3 : 2))
            ctx.strokeEllipse(in: rute)
        }
        let m = r * 0.34
        ctx.setFillColor(farge(midt))
        ctx.fillEllipse(in: CGRect(x: senter - m, y: senter - m, width: m * 2, height: m * 2))
        ctx.endPDFPage()
        ctx.closePDF()
        return data as Data
    }
}
#endif
