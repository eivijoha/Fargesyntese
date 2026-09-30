import FargeKjerne
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Kopiering etter plattformkonvensjon: ett element med både fargeobjekt
/// (limes inn som farge i Keynote, Pages, Figma m.fl.) og tekst (limes inn i kode).
enum Utklippstavle {
    static func kopier(_ farge: Farge, som modell: Fargemodell? = nil) {
        let tekst = modell?.tekst(for: farge) ?? farge.hex(medAlfa: farge.alfa < 1)
        #if canImport(UIKit)
        let leverandør = NSItemProvider(object: farge.plattform)
        leverandør.registerObject(tekst as NSString, visibility: .all)
        UIPasteboard.general.itemProviders = [leverandør]
        #elseif canImport(AppKit)
        let tavle = NSPasteboard.general
        tavle.clearContents()
        tavle.writeObjects([farge.plattform])
        tavle.setString(tekst, forType: .string)
        #endif
    }

    /// Kopierer paletten som SVG-fargeprøver. Figma, Illustrator og Sketch lager
    /// fylte former med riktige farger når dette limes inn.
    static func kopierSVG(_ palett: Palett) {
        let data = Eksportformat.svg.data(for: palett)
        let tekst = String(decoding: data, as: UTF8.self)
        #if canImport(UIKit)
        UIPasteboard.general.items = [["public.svg-image": data, "public.utf8-plain-text": tekst]]
        #elseif canImport(AppKit)
        let tavle = NSPasteboard.general
        tavle.clearContents()
        tavle.setData(data, forType: NSPasteboard.PasteboardType("public.svg-image"))
        tavle.setString(tekst, forType: .string)
        #endif
    }

    static func kopierTekst(_ tekst: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = tekst
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(tekst, forType: .string)
        #endif
    }

    /// Kopierer en hel palett som tekstlinjer (én farge per linje).
    static func kopier(_ palett: Palett, som modell: Fargemodell? = nil) {
        let linjer = palett.farger.map { f in
            let verdi = modell?.tekst(for: f.farge) ?? f.farge.hex()
            return f.navn.isEmpty ? verdi : "\(f.navn)\t\(verdi)"
        }.joined(separator: "\n")
        #if canImport(UIKit)
        UIPasteboard.general.string = linjer
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(linjer, forType: .string)
        #endif
    }

    /// Leser flere farger: fargeobjekter hvis det er flere, ellers én farge per tekstlinje.
    static func limInnListe() -> [PalettFarge] {
        #if canImport(UIKit)
        let objekter = UIPasteboard.general.colors ?? []
        let tekst = UIPasteboard.general.string
        #elseif canImport(AppKit)
        let objekter = NSPasteboard.general.readObjects(forClasses: [NSColor.self]) as? [NSColor] ?? []
        let tekst = NSPasteboard.general.string(forType: .string)
        #endif
        if objekter.count > 1 {
            return objekter.compactMap { Farge(cgFarge: $0.cgColor) }.map { PalettFarge(farge: $0) }
        }
        let fraTekst = tekst.map(Fargetolk.tolkListe) ?? []
        if !fraTekst.isEmpty { return fraTekst }
        return limInn().map { [PalettFarge(farge: $0)] } ?? []
    }

    /// Leser en farge fra utklippstavlen: fargeobjekt først, deretter hex/CSS-tekst.
    static func limInn() -> Farge? {
        #if canImport(UIKit)
        if let c = UIPasteboard.general.color { return Farge(cgFarge: c.cgColor) }
        return UIPasteboard.general.string.flatMap(Fargetolk.tolk)
        #elseif canImport(AppKit)
        if let c = NSColor(from: .general) { return Farge(cgFarge: c.cgColor) }
        return NSPasteboard.general.string(forType: .string).flatMap(Fargetolk.tolk)
        #endif
    }
}
