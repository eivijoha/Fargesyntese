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

/// Tolker fri tekst som farge: hex nå, CSS-funksjoner (oklch(), lab(), rgb()) er neste steg.
enum Fargetolk {
    static func tolk(_ tekst: String) -> Farge? {
        Farge(hex: tekst.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
