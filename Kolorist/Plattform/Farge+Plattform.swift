import CoreTransferable
import FargeKjerne
import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
typealias PlattformFarge = UIColor
#elseif canImport(AppKit)
import AppKit
typealias PlattformFarge = NSColor
#endif

extension Farge {
    /// SwiftUI-farge i utvidet lineær sRGB – bevarer P3-farger på skjermer som kan vise dem.
    /// Farger utenfor P3 gamut-kartlegges først (OKLCH, kulør bevares); ellers klipper skjermen
    /// hver kanal for seg, og f.eks. en brun utenfor gamut vises som rød.
    var swiftUI: Color {
        let f = erIDisplayP3 ? self : gamutKartlagt(til: .displayP3)
        return Color(.sRGBLinear, red: f.r, green: f.g, blue: f.b, opacity: alfa)
    }

    init(_ farge: Color) {
        let o = farge.resolve(in: EnvironmentValues())
        self.init(lineærR: Double(o.linearRed), g: Double(o.linearGreen), b: Double(o.linearBlue), alfa: Double(o.opacity))
    }

    var plattform: PlattformFarge {
        #if canImport(UIKit)
        UIColor(cgColor: cgFarge)
        #else
        NSColor(cgColor: cgFarge) ?? .black
        #endif
    }
}

/// Dra-og-slipp og deling: Kolorist selv får full presisjon, Mac-apper med fargebrønner får en
/// `NSColor` (Pages, Keynote, fargepanelet …), og andre apper får hex-tekst.
nonisolated extension Farge: @retroactive Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .koloristFarge)
        #if os(macOS)
        DataRepresentation(exportedContentType: .macFarge) { try $0.macFargedata() }
        #endif
        ProxyRepresentation(exporting: { $0.hex(medAlfa: $0.alfa < 1) })
    }
}

#if os(macOS)
nonisolated extension Farge {
    /// Fargen som arkivert `NSColor`, slik fargebrønner og fargepanelet på Mac tar imot ved slipp.
    /// sRGB-farger sendes som sRGB, bredere farger som Display P3 (gamut-kartlagt).
    func macFargedata() throws -> Data {
        let farge: NSColor
        if erISRGB {
            let v = sRGB
            farge = NSColor(srgbRed: v.r, green: v.g, blue: v.b, alpha: alfa)
        } else {
            let v = gamutKartlagt(til: .displayP3).displayP3
            farge = NSColor(displayP3Red: v.r, green: v.g, blue: v.b, alpha: alfa)
        }
        guard let data = farge.pasteboardPropertyList(forType: .color) as? Data else { throw CocoaError(.coderInvalidValue) }
        return data
    }
}
#endif

/// En farge med navn. Kan også tas imot som ren farge eller som tekst (hex/CSS) fra andre apper.
nonisolated extension PalettFarge: @retroactive Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .koloristPalettfarge)
        #if os(macOS)
        DataRepresentation(exportedContentType: .macFarge) { try await $0.macFargedata() }
        #endif
        ProxyRepresentation(importing: { (farge: Farge) in PalettFarge(farge: farge) })
        ProxyRepresentation(exporting: { $0.farge.hex(medAlfa: $0.farge.alfa < 1) }, importing: { (tekst: String) in
            guard let f = Fargetolk.tolk(tekst) else { throw CocoaError(.coderReadCorrupt) }
            return PalettFarge(farge: f)
        })
    }

    /// Kopi med ny identitet, for innsetting i en annen palett.
    var kopi: PalettFarge { PalettFarge(navn: navn, farge: farge, opphav: opphav, representasjon: representasjon) }
}

#if os(macOS)
nonisolated extension PalettFarge {
    /// Som ``Farge/macFargedata()``, men farger lagret i en ICC-profil (f.eks. CMYK) sendes i profilens
    /// fargerom med de lagrede verdiene, så mottakeren får både verdiene og ICC-profilen.
    func macFargedata() async throws -> Data {
        if let rep = representasjon, case .icc(let id, _) = rep.rom,
           let rom = await MainActor.run(body: { ProfilBibliotek.delt.profil(id: id)?.fargerom }),
           rom.numberOfComponents == rep.verdier.count,
           let nsRom = NSColorSpace(cgColorSpace: rom) {
            var komponenter = rep.verdier.map { CGFloat($0) } + [CGFloat(farge.alfa)]
            let nsFarge = NSColor(colorSpace: nsRom, components: &komponenter, count: komponenter.count)
            if let data = nsFarge.pasteboardPropertyList(forType: .color) as? Data { return data }
        }
        return try farge.macFargedata()
    }
}
#endif

nonisolated extension UTType {
    /// Deklarert som eksportert type i Info.plist.
    static let koloristFarge = UTType(exportedAs: "no.engenett.kolorist.farge")
    static let koloristPalettfarge = UTType(exportedAs: "no.engenett.kolorist.palettfarge")
    #if os(macOS)
    /// AppKits utklippstavletype for `NSColor` (deklarert av systemet).
    static let macFarge = UTType(NSPasteboard.PasteboardType.color.rawValue)!
    #endif
}
