import Foundation

// Lysrefleksjonsverdi (LRV) og flatekontrast, slik arkitekter og universell utforming bruker det.
// LRV er CIE-luminansen Y i prosent (0 = sort, 100 = referansehvitt), som på malingskart og i
// NS 11001 / BS 8300. Kontrasten mellom to flater oppgis som forskjell i LRV-poeng
// (BS 8300: minst 30 poeng) og som Michelson-kontrast (Y₁ − Y₂)/(Y₁ + Y₂), som
// Byggforsk og NS 11001 bruker for luminanskontrast (minst 0,4 for viktige flater, 0,8 for tekst).

public extension Farge {
    /// Lysrefleksjonsverdi 0…100: CIE Y relativt til referansehvitt, for fargen slik den vises i sRGB.
    var lrv: Double { klippet(til: .sRGB).luminans * 100 }
}

/// Kontrast mellom to flater etter LRV-forskjell og Michelson-kontrast.
public struct Flatekontrast: Sendable, Hashable {
    public let a: Farge
    public let b: Farge

    public init(_ a: Farge, _ b: Farge) {
        self.a = a
        self.b = b
    }

    /// Forskjell i LRV-poeng (0…100).
    public var lrvForskjell: Double { abs(a.lrv - b.lrv) }

    /// Michelson-kontrast (Y₁ − Y₂)/(Y₁ + Y₂), 0…1.
    public var michelson: Double {
        let y1 = a.lrv, y2 = b.lrv
        return y1 + y2 > 0 ? abs(y1 - y2) / (y1 + y2) : 0
    }

    public func består(_ krav: Flatekrav) -> Bool {
        switch krav {
        case .lrv30: lrvForskjell >= 30
        case .luminans04: michelson >= 0.4
        case .luminans08: michelson >= 0.8
        }
    }

    /// Justerer `a` i lyshet (OKLCH) til kravet er oppfylt, i retningen som krever minst endring.
    public func rettet(for krav: Flatekrav, gamut: Gamut = .displayP3) -> Farge {
        if består(krav) { return a }
        let lch = a.okLCH
        var beste: Farge?
        var minsteAvstand = Double.infinity
        for retning in [1.0, -1.0] {
            var l = lch.l
            for _ in 0..<80 {
                l += retning * 0.0125
                guard (0...1).contains(l) else { break }
                let kandidat = Farge(okLCH: OKLCH(l: l, c: lch.c, h: lch.h), alfa: a.alfa).gamutKartlagt(til: gamut)
                if Flatekontrast(kandidat, b).består(krav) {
                    let avstand = abs(l - lch.l)
                    if avstand < minsteAvstand { minsteAvstand = avstand; beste = kandidat }
                    break
                }
            }
        }
        return beste ?? (b.lrv > 50 ? Farge(lineærR: 0, g: 0, b: 0) : Farge(lineærR: 1, g: 1, b: 1))
    }
}

/// Krav til kontrast mellom flater i bygg.
public enum Flatekrav: String, CaseIterable, Sendable, Identifiable {
    /// BS 8300 / malingskart: minst 30 LRV-poeng mellom tilstøtende flater.
    case lrv30
    /// NS 11001 og Byggforsk: luminanskontrast minst 0,4 for viktige flater (dør mot vegg, håndlist, trinnmarkering).
    case luminans04
    /// Luminanskontrast minst 0,8 for tekst og symboler på skilt.
    case luminans08

    public var id: String { rawValue }

    public var navn: String {
        switch self {
        case .lrv30: String(localized: "Flater, 30 LRV-poeng", bundle: .module)
        case .luminans04: String(localized: "Viktige flater, 0,4", bundle: .module)
        case .luminans08: String(localized: "Skilt og tekst, 0,8", bundle: .module)
        }
    }

    public var kilde: String {
        switch self {
        case .lrv30: "BS 8300"
        case .luminans04, .luminans08: "NS 11001"
        }
    }

    public var kravtekst: String {
        switch self {
        case .lrv30: String(localized: "minst 30 poeng forskjell i LRV", bundle: .module)
        case .luminans04: String(localized: "luminanskontrast minst 0,4", bundle: .module)
        case .luminans08: String(localized: "luminanskontrast minst 0,8", bundle: .module)
        }
    }
}
