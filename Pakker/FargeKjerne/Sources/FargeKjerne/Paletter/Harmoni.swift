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

/// Hvilken fargesirkel kulørvinklene måles i. Valget avgjør hva som er «motsatt» farge.
public enum Fargesirkel: String, CaseIterable, Codable, Sendable, Identifiable {
    /// OKLCH: perseptuelt jevne vinkler; lyshet og kroma holdes fast, så fargene veier likt.
    case okLCH
    /// CIE LCH (D50): Lab-basert, som i Photoshop og fargemålingsverktøy.
    case cieLCH
    /// HSL-sirkelen fra RGB – skjermsirkelen i de fleste designverktøy (blå ↔ gul).
    case hsl
    /// RYB – kunstnersirkelen (Itten): rød ↔ grønn, gul ↔ fiolett, blå ↔ oransje.
    case ryb

    public var id: String { rawValue }

    public var navn: String {
        switch self {
        case .okLCH: "OKLCH (perseptuell)"
        case .cieLCH: "CIE LCH (Lab)"
        case .hsl: "HSL (RGB-skjerm)"
        case .ryb: "RYB (kunstnersirkel)"
        }
    }

    public var forklaring: String {
        switch self {
        case .okLCH: "Perseptuelt like vinkler, og lyshet og metning holdes fast, så fargene veier likt."
        case .cieLCH: "Lab-basert sirkel, som i Photoshop og fargemåling. Lyshet og kroma holdes fast."
        case .hsl: "Den tradisjonelle RGB-sirkelen fra skjermverden. Blå er komplementær til gul."
        case .ryb: "Kunstnersirkelen med rød, gul og blå som primærfarger. Blå er komplementær til oransje."
        }
    }

    /// Fargens vinkel i denne sirkelen (grader).
    public func vinkel(for farge: Farge) -> Double {
        switch self {
        case .okLCH: farge.okLCH.h
        case .cieLCH: farge.cieLCH.h
        case .hsl: farge.hsl.h
        case .ryb: RYB.fraRGBKulør(farge.hsl.h)
        }
    }

    /// Grunnfargen flyttet til en ny vinkel i denne sirkelen (lyshet/metning bevares i sirkelens rom).
    public func farge(_ grunn: Farge, vinkel: Double, gamut: Gamut = .displayP3) -> Farge {
        let v = Harmoni.normaliser(vinkel)
        switch self {
        case .okLCH:
            var lch = grunn.okLCH
            lch.h = v
            return Farge(okLCH: lch, alfa: grunn.alfa).gamutKartlagt(til: gamut)
        case .cieLCH:
            var lch = grunn.cieLCH
            lch.h = v
            return Farge(cieLCH: lch, alfa: grunn.alfa).gamutKartlagt(til: gamut)
        case .hsl:
            var hsl = grunn.hsl
            hsl.h = v
            return Farge(hsl: hsl, alfa: grunn.alfa)
        case .ryb:
            var hsl = grunn.hsl
            hsl.h = RYB.tilRGBKulør(v)
            return Farge(hsl: hsl, alfa: grunn.alfa)
        }
    }

    /// Farge for å tegne sirkelen ved en vinkel, med grunnfargens lyshet/metning der det gir mening.
    public func ringfarge(vinkel: Double, grunn: Farge) -> Farge {
        switch self {
        case .okLCH:
            let g = grunn.okLCH
            return Farge(okLCH: OKLCH(l: g.l, c: max(g.c, 0.08), h: vinkel)).gamutKartlagt(til: .displayP3)
        case .cieLCH:
            let g = grunn.cieLCH
            return Farge(cieLCH: CIELCH(l: g.l, c: max(g.c, 30), h: vinkel)).gamutKartlagt(til: .displayP3)
        case .hsl: return Farge(hsl: HSL(h: vinkel, s: 0.85, l: 0.55))
        case .ryb: return Farge(hsl: HSL(h: RYB.tilRGBKulør(vinkel), s: 0.85, l: 0.55))
        }
    }
}

/// Stykkevis lineær avbildning mellom RYB-kunstnersirkelen og RGB/HSL-kulør.
/// Ankerpunkter (RYB → RGB): rød 0→0, oransje 60→35, gul 120→60, grønn 180→120,
/// blå 240→225, fiolett 300→275.
public enum RYB {
    static let anker: [(ryb: Double, rgb: Double)] = [(0, 0), (60, 35), (120, 60), (180, 120), (240, 225), (300, 275), (360, 360)]

    public static func tilRGBKulør(_ ryb: Double) -> Double {
        interpoler(Harmoni.normaliser(ryb), fra: \.ryb, til: \.rgb)
    }

    public static func fraRGBKulør(_ rgb: Double) -> Double {
        interpoler(Harmoni.normaliser(rgb), fra: \.rgb, til: \.ryb)
    }

    private static func interpoler(_ v: Double, fra: KeyPath<(ryb: Double, rgb: Double), Double>,
                                   til: KeyPath<(ryb: Double, rgb: Double), Double>) -> Double {
        for (a, b) in zip(anker, anker.dropFirst()) where v >= a[keyPath: fra] && v <= b[keyPath: fra] {
            let t = (v - a[keyPath: fra]) / (b[keyPath: fra] - a[keyPath: fra])
            return Harmoni.normaliser(a[keyPath: til] + t * (b[keyPath: til] - a[keyPath: til]))
        }
        return v
    }
}

public extension Harmoni {
    /// Fargene i harmonien, med grunnfargen først (for analog: i midten).
    func farger(fra grunnfarge: Farge, antall: Int = 3, vinkel: Double? = nil,
                sirkel: Fargesirkel = .okLCH, gamut: Gamut = .displayP3) -> [Farge] {
        let basis = sirkel.vinkel(for: grunnfarge)
        return forskyvninger(antall: antall, vinkel: vinkel).map { d in
            d == 0 ? grunnfarge : sirkel.farge(grunnfarge, vinkel: basis + d, gamut: gamut)
        }
    }

    internal static func normaliser(_ h: Double) -> Double {
        (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }
}
