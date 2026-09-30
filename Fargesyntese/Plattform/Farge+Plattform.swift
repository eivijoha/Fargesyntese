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
    var swiftUI: Color {
        Color(.sRGBLinear, red: r, green: g, blue: b, opacity: alfa)
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

/// Dra-og-slipp og deling: andre apper får hex-tekst; Fargesyntese selv får full presisjon.
nonisolated extension Farge: @retroactive Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .fargesynteseFarge)
        ProxyRepresentation(exporting: { $0.hex(medAlfa: $0.alfa < 1) })
    }
}

nonisolated extension PalettFarge: @retroactive Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .fargesynteseFarge)
        ProxyRepresentation(exporting: { $0.farge.hex(medAlfa: $0.farge.alfa < 1) })
    }
}

nonisolated extension UTType {
    /// Deklarert som eksportert type i Info.plist.
    static let fargesynteseFarge = UTType(exportedAs: "no.engenett.fargesyntese.farge")
}
