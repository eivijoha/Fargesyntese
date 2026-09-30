import Foundation

/// Presise, forutsigbare palettjusteringer i OKLCH. Virker uten KI og brukes
/// som hurtigknapper («varmere», «mer kontrast» …).
public enum Justering: String, CaseIterable, Sendable, Identifiable {
    case varmere, kaldere, lysere, mørkere, merMettet, dempet, merKontrast

    public var id: String { rawValue }

    public var navn: String {
        switch self {
        case .varmere: String(localized: "Varmere", bundle: .module)
        case .kaldere: String(localized: "Kaldere", bundle: .module)
        case .lysere: String(localized: "Lysere", bundle: .module)
        case .mørkere: String(localized: "Mørkere", bundle: .module)
        case .merMettet: String(localized: "Mer mettet", bundle: .module)
        case .dempet: String(localized: "Dempet", bundle: .module)
        case .merKontrast: String(localized: "Mer kontrast", bundle: .module)
        }
    }

    public var symbol: String {
        switch self {
        case .varmere: "sun.max"
        case .kaldere: "snowflake"
        case .lysere: "circle.lefthalf.filled"
        case .mørkere: "circle.righthalf.filled"
        case .merMettet: "drop.fill"
        case .dempet: "drop"
        case .merKontrast: "circle.lefthalf.striped.horizontal"
        }
    }

    public func bruk(på farger: [Farge], gamut: Gamut = .displayP3) -> [Farge] {
        let snittL = farger.map(\.okLCH.l).reduce(0, +) / Double(max(farger.count, 1))
        return farger.map { f in
            var c = f.okLCH
            switch self {
            case .varmere: c.h = Self.drei(c.h, mot: 60, grader: 12)
            case .kaldere: c.h = Self.drei(c.h, mot: 240, grader: 12)
            case .lysere: c.l += (1 - c.l) * 0.18
            case .mørkere: c.l -= c.l * 0.15
            case .merMettet: c.c *= 1.25
            case .dempet: c.c *= 0.75
            case .merKontrast: c.l = (snittL + (c.l - snittL) * 1.3).klampet(0.05, 0.99)
            }
            // Akromatiske farger har ingen meningsfull kulør å dreie.
            if f.okLCH.c < 0.02 && (self == .varmere || self == .kaldere) { c = f.okLCH }
            return Farge(okLCH: c, alfa: f.alfa).gamutKartlagt(til: gamut)
        }
    }

    /// Dreier kulør `grader` mot `mål` langs korteste vei, uten å skyte over.
    static func drei(_ h: Double, mot mål: Double, grader: Double) -> Double {
        var d = (mål - h).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        let steg = min(abs(d), grader) * (d < 0 ? -1 : 1)
        return (h + steg + 360).truncatingRemainder(dividingBy: 360)
    }
}

public extension Farge {
    /// Justerer lysheten (OKLCH) til kontrasten mot `bakgrunn` når minst `mål` (WCAG),
    /// i den retningen som gir kontrast. Kulør og kroma bevares så langt gamut tillater.
    func medKontrast(mot bakgrunn: Farge, minst mål: Double = 4.5) -> Farge {
        if wcagKontrast(mot: bakgrunn) >= mål { return self }
        let lch = okLCH
        let mørkere = bakgrunn.luminans > 0.18
        var l = lch.l
        for _ in 0..<60 {
            l += mørkere ? -0.015 : 0.015
            guard (0...1).contains(l) else { break }
            let kandidat = Farge(okLCH: OKLCH(l: l, c: lch.c, h: lch.h), alfa: alfa).gamutKartlagt(til: .displayP3)
            if kandidat.wcagKontrast(mot: bakgrunn) >= mål { return kandidat }
        }
        return mørkere ? Farge(lineærR: 0, g: 0, b: 0) : Farge(lineærR: 1, g: 1, b: 1)
    }
}
