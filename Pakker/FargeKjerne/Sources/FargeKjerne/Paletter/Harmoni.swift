import Foundation

/// Klassiske fargeharmonier: farger valgt ut fra kulørvinkler rundt fargesirkelen.
public enum Harmoni: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Grunnfarge + motsatt kulør (180°).
    case komplementær
    /// Grunnfarge + de to naboene til komplementærfargen (180° ± vinkel).
    case splittKomplementær
    /// Naboer på samme side av sirkelen, med `vinkel` mellom hver.
    case analog
    /// `antall` farger jevnt fordelt rundt sirkelen (3 = triade, 4 = tetrade, 5 = pentade …).
    case jevn
    /// To komplementærpar (rektangel): 0°, vinkel, 180°, 180° + vinkel.
    case dobbeltKomplementær

    public var id: String { rawValue }

    public var navn: String {
        switch self {
        case .komplementær: "Komplementær"
        case .splittKomplementær: "Split-komplementær"
        case .analog: "Analog"
        case .jevn: "Jevn fordeling"
        case .dobbeltKomplementær: "Dobbelt komplementær"
        }
    }

    /// Om harmonien bruker valgfritt antall farger.
    public var harAntall: Bool { self == .jevn || self == .analog }
    /// Om harmonien bruker en valgfri vinkel.
    public var harVinkel: Bool { self == .splittKomplementær || self == .analog || self == .dobbeltKomplementær }

    public var standardVinkel: Double {
        switch self {
        case .splittKomplementær: 30
        case .analog: 30
        case .dobbeltKomplementær: 60
        default: 0
        }
    }

    /// Kulørforskyvninger i grader relativt til grunnfargen.
    public func forskyvninger(antall: Int = 3, vinkel: Double? = nil) -> [Double] {
        let v = vinkel ?? standardVinkel
        switch self {
        case .komplementær: return [0, 180]
        case .splittKomplementær: return [0, 180 - v, 180 + v]
        case .dobbeltKomplementær: return [0, v, 180, 180 + v]
        case .jevn:
            let n = max(antall, 2)
            return (0..<n).map { Double($0) * 360 / Double(n) }
        case .analog:
            // Symmetrisk rundt grunnfargen: -v, 0, +v (og videre utover for flere farger).
            let n = max(antall, 2)
            return (0..<n).map { (Double($0) - Double(n - 1) / 2) * v }
        }
    }
}

/// Hvilken fargesirkel kulørvinklene måles i.
public enum Fargesirkel: String, CaseIterable, Codable, Sendable, Identifiable {
    /// OKLCH: perseptuelt jevne vinkler, og lyshet/kroma holdes konstant – fargene «veier» likt.
    case okLCH
    /// HSL-sirkelen fra RGB – den tradisjonelle sirkelen i de fleste designverktøy.
    case hsl

    public var id: String { rawValue }
    public var navn: String { self == .okLCH ? "OKLCH (perseptuell)" : "HSL (tradisjonell)" }
}

public extension Harmoni {
    /// Fargene i harmonien, med grunnfargen først (for analog: i midten).
    func farger(fra grunnfarge: Farge, antall: Int = 3, vinkel: Double? = nil,
                sirkel: Fargesirkel = .okLCH, gamut: Gamut = .displayP3) -> [Farge] {
        forskyvninger(antall: antall, vinkel: vinkel).map { d in
            if d == 0 { return grunnfarge }
            switch sirkel {
            case .okLCH:
                var lch = grunnfarge.okLCH
                lch.h = Self.normaliser(lch.h + d)
                return Farge(okLCH: lch, alfa: grunnfarge.alfa).gamutKartlagt(til: gamut)
            case .hsl:
                var hsl = grunnfarge.hsl
                hsl.h = Self.normaliser(hsl.h + d)
                return Farge(hsl: hsl, alfa: grunnfarge.alfa)
            }
        }
    }

    internal static func normaliser(_ h: Double) -> Double {
        (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }
}
