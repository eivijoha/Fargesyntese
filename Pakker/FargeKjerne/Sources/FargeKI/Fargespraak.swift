import FargeKjerne
import Foundation

/// Et kategorisk fargespråk som språkmodellen og kunnskapsgrunnlaget deler.
///
/// Små språkmodeller treffer dårlig når de skal skrive OKLCH-tall direkte (en «dyp grønn» ble ofte
/// brun). I stedet velger modellen kulørfamilie, lyshetsnivå og metningsnivå, og fargen regnes ut
/// deterministisk. Metning er *relativ*: «klar» er en fast andel av den høyeste kromaen gamut tillater
/// for akkurat den lysheten og kuløren, så en klar gul og en klar blå blir like «klare».
public enum Kulørfamilie: String, CaseIterable, Codable, Sendable {
    case rød, korall, oransje, rav, gul, lime, grønn, blågrønn, turkis, himmelblå, blå, indigo, fiolett, magenta, rosa, nøytral

    /// OKLCH-kulør (grader) for familiens midtpunkt. `nil` for nøytral.
    public var kulør: Double? {
        switch self {
        case .rød: 27
        case .korall: 42
        case .oransje: 64
        case .rav: 82
        case .gul: 98
        case .lime: 125
        case .grønn: 145
        case .blågrønn: 168
        case .turkis: 195
        case .himmelblå: 228
        case .blå: 255
        case .indigo: 275
        case .fiolett: 302
        case .magenta: 330
        case .rosa: 355
        case .nøytral: nil
        }
    }

    /// Navn på appens språk.
    public var navn: String {
        if Språk.erNorsk { return rawValue }
        switch self {
        case .rød: return "red"
        case .korall: return "coral"
        case .oransje: return "orange"
        case .rav: return "amber"
        case .gul: return "yellow"
        case .lime: return "lime"
        case .grønn: return "green"
        case .blågrønn: return "teal"
        case .turkis: return "turquoise"
        case .himmelblå: return "sky blue"
        case .blå: return "blue"
        case .indigo: return "indigo"
        case .fiolett: return "violet"
        case .magenta: return "magenta"
        case .rosa: return "pink"
        case .nøytral: return "neutral"
        }
    }

    /// Familiene med kulør, i rekkefølge rundt sirkelen.
    public static let kromatiske: [Kulørfamilie] = allCases.filter { $0 != .nøytral }

    /// Familien `steg` plasser videre rundt sirkelen (negativ = mot klokka).
    public func nabo(_ steg: Int) -> Kulørfamilie {
        guard let i = Self.kromatiske.firstIndex(of: self) else { return self }
        let n = Self.kromatiske.count
        return Self.kromatiske[((i + steg) % n + n) % n]
    }

    /// Nærmeste familie for en OKLCH-kulør.
    public static func nærmeste(kulør h: Double) -> Kulørfamilie {
        kromatiske.min { a, b in vinkelavstand(a.kulør!, h) < vinkelavstand(b.kulør!, h) }!
    }
}

func vinkelavstand(_ a: Double, _ b: Double) -> Double {
    let d = abs(a - b).truncatingRemainder(dividingBy: 360)
    return min(d, 360 - d)
}

public enum Lyshetsnivå: String, CaseIterable, Codable, Sendable, Comparable {
    case nestenSort = "nesten-sort", sværtMørk = "svært-mørk", mørk, middelsMørk = "middels-mørk",
         middels, lys, sværtLys = "svært-lys", nestenHvit = "nesten-hvit"

    public var lyshet: Double {
        switch self {
        case .nestenSort: 0.20
        case .sværtMørk: 0.30
        case .mørk: 0.42
        case .middelsMørk: 0.53
        case .middels: 0.64
        case .lys: 0.76
        case .sværtLys: 0.87
        case .nestenHvit: 0.96
        }
    }

    public static func < (a: Lyshetsnivå, b: Lyshetsnivå) -> Bool { a.lyshet < b.lyshet }

    public static func nærmeste(_ l: Double) -> Lyshetsnivå {
        allCases.min { abs($0.lyshet - l) < abs($1.lyshet - l) }!
    }
}

public enum Metningsnivå: String, CaseIterable, Codable, Sendable, Comparable {
    case grå, svak, dempet, moderat, klar, sterk, maksimal

    /// Andel av høyeste kroma innenfor gamut ved fargens lyshet og kulør.
    public var andel: Double {
        switch self {
        case .grå: 0.0
        case .svak: 0.12
        case .dempet: 0.28
        case .moderat: 0.48
        case .klar: 0.70
        case .sterk: 0.88
        case .maksimal: 1.0
        }
    }

    public static func < (a: Metningsnivå, b: Metningsnivå) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }

    public static func nærmeste(andel: Double) -> Metningsnivå {
        allCases.min { abs($0.andel - andel) < abs($1.andel - andel) }!
    }
}

/// Fargen uttrykt i fargespråket. `justering` finjusterer kuløren innenfor familien (grader).
public struct Fargespesifikasjon: Hashable, Codable, Sendable {
    public var familie: Kulørfamilie
    public var lyshet: Lyshetsnivå
    public var metning: Metningsnivå
    public var justering: Double

    public init(familie: Kulørfamilie, lyshet: Lyshetsnivå, metning: Metningsnivå, justering: Double = 0) {
        self.familie = familie
        self.lyshet = lyshet
        self.metning = metning
        self.justering = justering
    }

    /// Nøytrale farger får en svak varm tone (som papir) i stedet for helt grått.
    static let nøytralKulør = 80.0

    public func farge(i gamut: Gamut = .displayP3) -> Farge {
        let l = lyshet.lyshet
        guard let basis = familie.kulør else {
            return Farge(okLCH: OKLCH(l: l, c: familie == .nøytral && metning > .grå ? 0.01 : 0.0, h: Self.nøytralKulør))
        }
        let h = (basis + max(-15, min(15, justering)) + 360).truncatingRemainder(dividingBy: 360)
        let c = Farge.maksKroma(lyshet: l, kulør: h, i: gamut) * metning.andel
        return Farge(okLCH: OKLCH(l: l, c: c, h: h)).gamutKartlagt(til: gamut)
    }

    /// Lysheten blant `kandidater` der familien kan bli mest mettet (gul er klarest lys, blå mørkere).
    public static func klaresteLyshet(for familie: Kulørfamilie, blant kandidater: [Lyshetsnivå], i gamut: Gamut = .displayP3) -> Lyshetsnivå {
        guard let h = familie.kulør, !kandidater.isEmpty else { return kandidater.first ?? .middels }
        return kandidater.max { Farge.maksKroma(lyshet: $0.lyshet, kulør: h, i: gamut) < Farge.maksKroma(lyshet: $1.lyshet, kulør: h, i: gamut) }!
    }

    /// Varme familier i for mørke lysheter blir brune eller oliven. Gul må være svært lys
    /// og lime lys for å se klare ut; korall, oransje og rav tåler middels.
    public var blirBrun: Bool {
        switch familie {
        case .gul: lyshet < .sværtLys
        case .lime: lyshet < .lys
        case .korall, .oransje, .rav: lyshet < .middels
        default: false
        }
    }

    /// Fargen beskrevet i fargespråket (nærmeste familie og nivåer), f.eks. for justeringer.
    public static func nærmeste(_ farge: Farge, i gamut: Gamut = .displayP3) -> Fargespesifikasjon {
        let lch = farge.okLCH
        let lyshet = Lyshetsnivå.nærmeste(lch.l)
        guard lch.c >= 0.02 else { return .init(familie: .nøytral, lyshet: lyshet, metning: lch.c < 0.006 ? .grå : .svak) }
        let familie = Kulørfamilie.nærmeste(kulør: lch.h)
        let maks = Farge.maksKroma(lyshet: lch.l, kulør: lch.h, i: gamut)
        var justering = lch.h - familie.kulør!
        if justering > 180 { justering -= 360 }
        if justering < -180 { justering += 360 }
        return .init(familie: familie, lyshet: lyshet,
                     metning: Metningsnivå.nærmeste(andel: maks > 0 ? min(lch.c / maks, 1) : 0),
                     justering: justering.rounded())
    }

    /// Kort tekst, f.eks. «grønn · middels · klar».
    public var tekst: String { "\(familie.rawValue) · \(lyshet.rawValue) · \(metning.rawValue)" }
}
