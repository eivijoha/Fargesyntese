import Foundation

/// Filformater for palett-eksport. Hver sak gir filendelse, UTI og innhold.
public enum Eksportformat: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Adobe Swatch Exchange – Photoshop, Illustrator, InDesign, Affinity, Procreate (import).
    case ase
    /// CSS custom properties med `oklch()` og sRGB-reserve.
    case css
    /// W3C Design Tokens (DTCG) JSON – Figma Tokens/Tokens Studio, Style Dictionary.
    case designTokens
    /// GIMP/Inkscape/Krita-palett.
    case gpl
    /// SwiftUI-kode (`Color` med Display P3).
    case swiftUI
    /// Ren tekstliste med hex-verdier.
    case hexListe

    public var id: String { rawValue }

    public var navn: String {
        switch self {
        case .ase: "Adobe Swatch Exchange (.ase)"
        case .css: "CSS-variabler (.css)"
        case .designTokens: "Design Tokens (.tokens.json)"
        case .gpl: "GIMP-palett (.gpl)"
        case .swiftUI: "SwiftUI (.swift)"
        case .hexListe: "Hex-liste (.txt)"
        }
    }

    public var filendelse: String {
        switch self {
        case .ase: "ase"
        case .css: "css"
        case .designTokens: "tokens.json"
        case .gpl: "gpl"
        case .swiftUI: "swift"
        case .hexListe: "txt"
        }
    }

    public var mimeType: String {
        switch self {
        case .ase: "application/octet-stream"
        case .css: "text/css"
        case .designTokens: "application/json"
        case .gpl, .hexListe: "text/plain"
        case .swiftUI: "text/x-swift"
        }
    }

    public func data(for palett: Palett) -> Data {
        switch self {
        case .ase: ASEEksport.data(for: palett)
        case .css: Data(TekstEksport.css(palett).utf8)
        case .designTokens: TekstEksport.designTokens(palett)
        case .gpl: Data(TekstEksport.gpl(palett).utf8)
        case .swiftUI: Data(TekstEksport.swiftUI(palett).utf8)
        case .hexListe: Data(palett.farger.map { $0.farge.hex() }.joined(separator: "\n").utf8)
        }
    }
}

/// Lager trygge identifikatorer (kebab-/camelCase) fra fargenavn.
enum Identifikator {
    static func kebab(_ s: String, reserve: String) -> String {
        let foldet = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "nb"))
            .replacingOccurrences(of: "æ", with: "ae").replacingOccurrences(of: "ø", with: "o").replacingOccurrences(of: "å", with: "a")
        let deler = foldet.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        return deler.isEmpty ? reserve : deler.joined(separator: "-")
    }

    static func camel(_ s: String, reserve: String) -> String {
        let deler = kebab(s, reserve: reserve).split(separator: "-").map(String.init)
        guard let første = deler.first else { return reserve }
        var id = første + deler.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        if id.first?.isNumber == true { id = "farge" + id }
        return id
    }

    /// Sikrer unike navn ved å legge på løpenummer.
    static func unike(_ navn: [String]) -> [String] {
        var sett: [String: Int] = [:]
        return navn.map { n in
            let antall = sett[n, default: 0]
            sett[n] = antall + 1
            return antall == 0 ? n : "\(n)-\(antall + 1)"
        }
    }
}
