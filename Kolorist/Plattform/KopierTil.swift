import CoreGraphics
import ImageIO
import FargeKjerne
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// «Kopier til …»: farger på utklippstavlen i formatet målprogrammet tar imot ved innliming.
///
/// - Figma, Sketch, Affinity: SVG – limes inn som former med riktig fyll.
/// - Illustrator, InDesign: PDF – vektorformer i fargens eget fargerom, også CMYK med ICC-profil.
///   (Adobe har ikke noe felles utklippsformat for fargeprøver; ASE-eksporten er veien inn i
///   fargeprøvepanelet.)
/// - Photoshop: PDF (limes inn som formlag, smartobjekt eller piksler – Photoshop spør), PNG som
///   reserve, og hex uten «#» som tekst til hex-feltet i fargevelgeren.
/// - CSS og SwiftUI: kode.
/// Alle mål får i tillegg tekst (hex), så innliming i et tekstfelt også gir mening.
enum Kopimål: String, CaseIterable, Identifiable {
    case figma, illustrator, indesign, photoshop, sketchAffinity, css, swiftUI

    var id: String { rawValue }

    var navn: String {
        switch self {
        case .figma: "Figma"
        case .illustrator: "Illustrator"
        case .indesign: "InDesign"
        case .photoshop: "Photoshop"
        case .sketchAffinity: "Sketch / Affinity"
        case .css: "CSS"
        case .swiftUI: "SwiftUI"
        }
    }

    var forklaring: String {
        switch self {
        case .figma, .sketchAffinity: String(localized: "Som former (SVG)")
        case .illustrator, .indesign: String(localized: "Som vektorformer (PDF), med fargerom og ICC")
        case .photoshop: String(localized: "Som formlag (PDF), og hex til fargevelgeren")
        case .css: String(localized: "Som variabler")
        case .swiftUI: String(localized: "Som Color-konstanter")
        }
    }

    var symbol: String {
        switch self {
        case .figma, .sketchAffinity: "square.on.circle"
        case .illustrator, .indesign: "doc.richtext"
        case .photoshop: "photo"
        case .css, .swiftUI: "chevron.left.forwardslash.chevron.right"
        }
    }
}

/// Undermeny «Kopier til» for én farge eller en hel palett.
struct KopierTilMeny: View {
    let farger: [PalettFarge]
    var navn: String = ""

    var body: some View {
        Menu("Kopier til", systemImage: "arrow.up.doc.on.clipboard") {
            ForEach(Kopimål.allCases) { mål in
                Button {
                    Utklippstavle.kopier(farger, navn: navn, til: mål)
                } label: {
                    Label { Text(mål.navn); Text(mål.forklaring) } icon: { Image(systemName: mål.symbol) }
                }
            }
        }
    }
}

extension Utklippstavle {
    static func kopier(_ farger: [PalettFarge], navn: String, til mål: Kopimål) {
        guard !farger.isEmpty else { return }
        let palett = Palett(navn: navn.isEmpty ? String(localized: "Kolorist") : navn, farger: farger)
        let hex = farger.map { $0.farge.hex(medAlfa: $0.farge.alfa < 1) }.joined(separator: "\n")
        var typer: [(String, Data)] = []
        let tekst: String
        switch mål {
        case .figma, .sketchAffinity:
            let svg = Eksportformat.svg.data(for: palett)
            typer.append(("public.svg-image", svg))
            // Figma og Sketch leser SVG-koden fra teksten på utklippstavlen.
            tekst = String(decoding: svg, as: UTF8.self)
        case .illustrator, .indesign:
            typer.append(("com.adobe.pdf", Fargeprøvepdf.data(for: farger)))
            tekst = hex
        case .photoshop:
            // Photoshop limer inn grafikk fra utklippstavlen: PDF gir valget «Formlag» (vektor med
            // riktig fyll), PNG er reserve. Teksten (hex uten #) brukes når man limer i hex-feltet.
            typer.append(("com.adobe.pdf", Fargeprøvepdf.data(for: farger)))
            if let png = Fargeprøvepdf.png(for: farger) { typer.append(("public.png", png)) }
            tekst = farger.map { String($0.farge.hex().dropFirst()) }.joined(separator: "\n")
        case .css:
            tekst = String(decoding: Eksportformat.css.data(for: palett), as: UTF8.self)
        case .swiftUI:
            tekst = String(decoding: Eksportformat.swiftUI.data(for: palett), as: UTF8.self)
        }
        #if canImport(UIKit)
        var element: [String: Any] = ["public.utf8-plain-text": tekst]
        for (type, data) in typer { element[type] = data }
        UIPasteboard.general.items = [element]
        #elseif canImport(AppKit)
        let tavle = NSPasteboard.general
        tavle.clearContents()
        for (type, data) in typer { tavle.setData(data, forType: NSPasteboard.PasteboardType(type)) }
        tavle.setString(tekst, forType: .string)
        #endif
    }
}

/// Fargeprøver som PDF (vektor): én flate per farge, i fargens eget fargerom. Farger lagret i en
/// ICC-profil (f.eks. CMYK) tegnes med de lagrede verdiene i den profilen; ellers sRGB, eller
/// Display P3 for farger utenfor sRGB.
enum Fargeprøvepdf {
    static let rute: CGFloat = 96, mellomrom: CGFloat = 8

    static func data(for farger: [PalettFarge]) -> Data {
        let data = NSMutableData()
        var boks = CGRect(x: 0, y: 0, width: CGFloat(farger.count) * (rute + mellomrom) - mellomrom, height: rute)
        guard let forbruker = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: forbruker, mediaBox: &boks, nil)
        else { return Data() }
        ctx.beginPDFPage(nil)
        for (i, pf) in farger.enumerated() {
            ctx.setFillColor(cgFarge(pf))
            ctx.fill(CGRect(x: CGFloat(i) * (rute + mellomrom), y: 0, width: rute, height: rute))
        }
        ctx.endPDFPage()
        ctx.closePDF()
        return data as Data
    }

    /// Samme fargeprøver som PNG (for programmer som bare tar imot punktgrafikk).
    static func png(for farger: [PalettFarge], skala: CGFloat = 2) -> Data? {
        let b = Int((CGFloat(farger.count) * (rute + mellomrom) - mellomrom) * skala), h = Int(rute * skala)
        guard let rom = CGColorSpace(name: CGColorSpace.displayP3),
              let ctx = CGContext(data: nil, width: b, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: rom,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.scaleBy(x: skala, y: skala)
        for (i, pf) in farger.enumerated() {
            ctx.setFillColor(cgFarge(pf))
            ctx.fill(CGRect(x: CGFloat(i) * (rute + mellomrom), y: 0, width: rute, height: rute))
        }
        guard let bilde = ctx.makeImage() else { return nil }
        let data = NSMutableData()
        guard let mål = CGImageDestinationCreateWithData(data as CFMutableData, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(mål, bilde, nil)
        return CGImageDestinationFinalize(mål) ? data as Data : nil
    }

    static func cgFarge(_ pf: PalettFarge) -> CGColor {
        let alfa = CGFloat(pf.farge.alfa)
        if let rep = pf.representasjon, case .icc(let id, _) = rep.rom,
           let rom = ProfilBibliotek.delt.profil(id: id)?.fargerom, rom.numberOfComponents == rep.verdier.count,
           let c = CGColor(colorSpace: rom, components: rep.verdier.map { CGFloat($0) } + [alfa]) {
            return c
        }
        if pf.farge.erISRGB {
            let v = pf.farge.sRGB
            return CGColor(srgbRed: v.r, green: v.g, blue: v.b, alpha: alfa)
        }
        let v = pf.farge.gamutKartlagt(til: .displayP3).displayP3
        return CGColor(colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!, components: [v.r, v.g, v.b, alfa])!
    }
}
