import CoreGraphics
import CoreText
import FargeKjerne
import Foundation

/// A4-PDF av en palett: fargeflatene er fylt i CIELab (D50), slik at PDF-en bærer Lab-verdiene direkte
/// (trykkeriets RIP eller et fargestyrt program regner dem om til sitt eget rom). Under hver flate står
/// navnet, verdiene fra fargemodellen fargen ble definert i, verdiene i valgt fargerom (eller nærmeste
/// tone i valgt fargebibliotek) og CIELab-verdien. Tegnes med CoreGraphics og CoreText – likt på iOS og macOS.
nonisolated enum PalettPDF {
    /// Én fargeflate med tekstlinjer under.
    struct Felt: Sendable {
        var lab: CIELab
        var navn: String?
        /// (ledetekst, verdi), f.eks. («OKLCH», «oklch(0.593 0.156 253.9)»).
        var rader: [(String, String)]
    }

    /// A4 i punkter (210 × 297 mm).
    static let side = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
    private static let marg: CGFloat = 42
    private static let kolonner = 3
    private static let mellomrom: CGFloat = 14
    /// Luft mellom radene (under teksten til én rad og over flatene i neste).
    private static let radavstand: CGFloat = 22
    private static let flatehøyde: CGFloat = 80

    static func lag(tittel: String, undertittel: String, felt: [Felt], sidetekst: (Int, Int) -> String) -> Data {
        let data = NSMutableData()
        guard let mottaker = CGDataConsumer(data: data as CFMutableData) else { return Data() }
        var boks = side
        let info: [CFString: Any] = [kCGPDFContextTitle: tittel, kCGPDFContextCreator: "Kolorist"]
        guard let ctx = CGContext(consumer: mottaker, mediaBox: &boks, info as CFDictionary) else { return Data() }

        let bredde = (side.width - 2 * marg - CGFloat(kolonner - 1) * mellomrom) / CGFloat(kolonner)
        let tekster = felt.map { tekst(for: $0) }
        let teksthøyder = tekster.map { høyde(av: $0, bredde: bredde) }

        // Første gjennomgang: hvilke rader havner på hvilken side.
        let toppFørste = marg + 30 + 16 + 22   // tittel, undertittel og luft
        let toppNeste = marg + 24
        let bunn = side.height - marg - 14     // plass til sidetall
        var sider: [[(rad: Int, y: CGFloat)]] = [[]]
        var y = toppFørste
        let antallRader = (felt.count + kolonner - 1) / kolonner
        for rad in 0..<antallRader {
            let indekser = (rad * kolonner)..<min(felt.count, (rad + 1) * kolonner)
            let radhøyde = flatehøyde + 6 + (indekser.map { teksthøyder[$0] }.max() ?? 0)
            if y + radhøyde > bunn, !(sider.last?.isEmpty ?? true) {
                sider.append([])
                y = toppNeste
            }
            sider[sider.count - 1].append((rad, y))
            y += radhøyde + radavstand
        }

        let lab = CGColorSpace(labWhitePoint: [0.9642, 1.0, 0.8249], blackPoint: [0, 0, 0], range: [-128, 127, -128, 127])
        for (sidenr, rader) in sider.enumerated() {
            ctx.beginPDFPage(nil)
            if sidenr == 0 {
                tegn(tittel, font: font(20, fet: true), farge: 0, i: ctx, x: marg, topp: marg, bredde: side.width - 2 * marg)
                tegn(undertittel, font: font(8.5), farge: 0.4, i: ctx, x: marg, topp: marg + 30, bredde: side.width - 2 * marg)
            } else {
                tegn(tittel, font: font(11, fet: true), farge: 0, i: ctx, x: marg, topp: marg, bredde: side.width - 2 * marg)
            }
            for (rad, topp) in rader {
                for kolonne in 0..<kolonner {
                    let i = rad * kolonner + kolonne
                    guard i < felt.count else { break }
                    let x = marg + CGFloat(kolonne) * (bredde + mellomrom)
                    // PDF-koordinater har origo nede til venstre.
                    let flate = CGRect(x: x, y: side.height - topp - flatehøyde, width: bredde, height: flatehøyde)
                    let l = felt[i].lab
                    if let lab, let farge = CGColor(colorSpace: lab, components: [CGFloat(l.l), CGFloat(l.a), CGFloat(l.b), 1]) {
                        ctx.setFillColor(farge)
                        ctx.fill(flate)
                    }
                    // Tynn kant, så lyse flater synes mot papiret.
                    ctx.setStrokeColor(gray: 0, alpha: 0.18)
                    ctx.setLineWidth(0.5)
                    ctx.stroke(flate.insetBy(dx: 0.25, dy: 0.25))
                    tegn(tekster[i], i: ctx, x: x, topp: topp + flatehøyde + 6, bredde: bredde)
                }
            }
            tegn(sidetekst(sidenr + 1, sider.count), font: font(7.5), farge: 0.5, i: ctx,
                 x: marg, topp: side.height - marg, bredde: side.width - 2 * marg, høyrestilt: true)
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return data as Data
    }

    // MARK: - Tekst

    private static func font(_ størrelse: CGFloat, fet: Bool = false) -> CTFont {
        CTFontCreateUIFontForLanguage(fet ? .emphasizedSystem : .system, størrelse, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, størrelse, nil)
    }

    private static func attributter(_ font: CTFont, grå: CGFloat) -> [NSAttributedString.Key: Any] {
        [NSAttributedString.Key(kCTFontAttributeName as String): font,
         NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: grå, alpha: 1)]
    }

    /// Navn (fet) og radene som «ledetekst» (grå) over «verdi».
    private static func tekst(for felt: Felt) -> NSAttributedString {
        let t = NSMutableAttributedString()
        if let navn = felt.navn, !navn.isEmpty {
            t.append(NSAttributedString(string: navn + "\n", attributes: attributter(font(9.5, fet: true), grå: 0)))
        }
        for (i, (ledetekst, verdi)) in felt.rader.enumerated() {
            t.append(NSAttributedString(string: ledetekst + "\n", attributes: attributter(font(7), grå: 0.45)))
            t.append(NSAttributedString(string: verdi + (i < felt.rader.count - 1 ? "\n" : ""), attributes: attributter(font(8.5), grå: 0.1)))
        }
        return t
    }

    private static func høyde(av tekst: NSAttributedString, bredde: CGFloat) -> CGFloat {
        let ramme = CTFramesetterCreateWithAttributedString(tekst)
        let størrelse = CTFramesetterSuggestFrameSizeWithConstraints(ramme, CFRange(location: 0, length: tekst.length), nil,
                                                                    CGSize(width: bredde, height: .greatestFiniteMagnitude), nil)
        return ceil(størrelse.height)
    }

    private static func tegn(_ streng: String, font: CTFont, farge: CGFloat, i ctx: CGContext,
                             x: CGFloat, topp: CGFloat, bredde: CGFloat, høyrestilt: Bool = false) {
        let tekst = NSAttributedString(string: streng, attributes: attributter(font, grå: farge))
        guard høyrestilt else { return tegn(tekst, i: ctx, x: x, topp: topp, bredde: bredde) }
        // Én linje, høyrejustert: mål bredden og tegn fra høyre kant.
        let linje = CTLineCreateWithAttributedString(tekst)
        var stigning: CGFloat = 0
        let b = CGFloat(CTLineGetTypographicBounds(linje, &stigning, nil, nil))
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: x + bredde - b, y: side.height - topp - stigning)
        CTLineDraw(linje, ctx)
        ctx.restoreGState()
    }

    /// Tegner teksten med øverste kant ved `topp` (målt ovenfra), brutt innenfor `bredde`.
    private static func tegn(_ tekst: NSAttributedString, i ctx: CGContext, x: CGFloat, topp: CGFloat, bredde: CGFloat) {
        let h = høyde(av: tekst, bredde: bredde) + 2
        let ramme = CTFramesetterCreateWithAttributedString(tekst)
        let sti = CGPath(rect: CGRect(x: x, y: side.height - topp - h, width: bredde, height: h), transform: nil)
        let frame = CTFramesetterCreateFrame(ramme, CFRange(location: 0, length: tekst.length), sti, nil)
        ctx.saveGState()
        ctx.textMatrix = .identity
        CTFrameDraw(frame, ctx)
        ctx.restoreGState()
    }
}
