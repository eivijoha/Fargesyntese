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

/// Dra-og-slipp og deling: andre apper får hex-tekst; Kolorist selv får full presisjon.
nonisolated extension Farge: @retroactive Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .koloristFarge)
        ProxyRepresentation(exporting: { $0.hex(medAlfa: $0.alfa < 1) })
    }
}

/// En farge med navn. Kan også tas imot som ren farge eller som tekst (hex/CSS) fra andre apper.
nonisolated extension PalettFarge: @retroactive Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .koloristPalettfarge)
        ProxyRepresentation(importing: { (farge: Farge) in PalettFarge(farge: farge) })
        ProxyRepresentation(exporting: { $0.farge.hex(medAlfa: $0.farge.alfa < 1) }, importing: { (tekst: String) in
            guard let f = Fargetolk.tolk(tekst) else { throw CocoaError(.coderReadCorrupt) }
            return PalettFarge(farge: f)
        })
    }

    /// Kopi med ny identitet, for innsetting i en annen palett.
    var kopi: PalettFarge { PalettFarge(navn: navn, farge: farge, opphav: opphav, representasjon: representasjon) }
}

nonisolated extension UTType {
    /// Deklarert som eksportert type i Info.plist.
    static let koloristFarge = UTType(exportedAs: "no.engenett.kolorist.farge")
    static let koloristPalettfarge = UTType(exportedAs: "no.engenett.kolorist.palettfarge")
}
