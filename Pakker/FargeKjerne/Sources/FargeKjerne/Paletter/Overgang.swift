import Foundation

/// Overgangstoner og lys/mørk-skalaer, alltid beregnet i OKLab.
public enum Overgang {
    /// `antall` farger i like perseptuelle steg fra `start` til `slutt` (begge inkludert).
    ///
    /// Interpolasjonen skjer lineært i OKLab (ikke OKLCH), slik at overgangen går
    /// den korteste veien gjennom fargerommet uten kulør-«omveier». Alfa interpoleres lineært.
    public static func toner(fra start: Farge, til slutt: Farge, antall: Int) -> [Farge] {
        guard antall > 1 else { return antall == 1 ? [start] : [] }
        let a = start.okLab, b = slutt.okLab
        return (0..<antall).map { i in
            // Endepunktene returneres eksakt, slik at brukerens valgte farger ikke drifter.
            if i == 0 { return start }
            if i == antall - 1 { return slutt }
            let t = Double(i) / Double(antall - 1)
            return Farge(
                okLab: OKLab(l: a.l + (b.l - a.l) * t, a: a.a + (b.a - a.a) * t, b: a.b + (b.b - a.b) * t),
                alfa: start.alfa + (slutt.alfa - start.alfa) * t
            )
        }
    }

    /// Flerpunkts-overgang: like steg mellom hvert par av nøkkelfarger.
    /// `stegMellom` er antall mellomtoner mellom to nabofarger.
    public static func toner(gjennom nøkler: [Farge], stegMellom: Int) -> [Farge] {
        guard let første = nøkler.first else { return [] }
        var resultat = [første]
        for (a, b) in zip(nøkler, nøkler.dropFirst()) {
            resultat += toner(fra: a, til: b, antall: stegMellom + 2).dropFirst()
        }
        return resultat
    }
}

/// En lys-til-mørk-skala rundt en grunnfarge (à la «50…950» i designsystemer).
public struct Toneskala: Sendable {
    /// Lysestegenes OKLab-lyshet. Standard er en jevn trapp fra nesten hvit til nesten sort.
    public var lysheter: [Double]
    /// Hvor mye kroma dempes mot ytterpunktene (0 = ingen demping, 1 = full).
    /// Hindrer at lyse/mørke toner blir utmettet eller havner langt utenfor gamut.
    public var kromaDemping: Double
    public var gamut: Gamut

    public init(lysheter: [Double] = Toneskala.standardLysheter, kromaDemping: Double = 0.6, gamut: Gamut = .displayP3) {
        self.lysheter = lysheter
        self.kromaDemping = kromaDemping
        self.gamut = gamut
    }

    /// 11 trinn som tilsvarer 50, 100, 200 … 900, 950.
    public static let standardLysheter: [Double] = [0.97, 0.93, 0.87, 0.78, 0.69, 0.60, 0.51, 0.43, 0.35, 0.27, 0.20]

    /// `antall` jevne trinn mellom `lysest` og `mørkest`.
    public static func jevn(antall: Int, lysest: Double = 0.97, mørkest: Double = 0.2) -> [Double] {
        guard antall > 1 else { return [lysest] }
        return (0..<antall).map { lysest + (mørkest - lysest) * Double($0) / Double(antall - 1) }
    }

    /// Lager skalaen. Kulør holdes fast; kroma skaleres ned mot ytterpunktene
    /// med en jevn kurve, og hvert trinn gamut-kartlegges.
    public func toner(for grunnfarge: Farge) -> [Farge] {
        let g = grunnfarge.okLCH
        return lysheter.map { l in
            let avstand = abs(l - g.l) / max(g.l, 1 - g.l, 0.001)
            let faktor = 1 - kromaDemping * avstand * avstand
            return Farge(okLCH: OKLCH(l: l, c: g.c * max(faktor, 0), h: g.h), alfa: grunnfarge.alfa)
                .gamutKartlagt(til: gamut)
        }
    }

    /// Lysere og mørkere varianter av en farge i like OKLab-lyshetssteg.
    public static func variasjoner(av farge: Farge, lysere: Int, mørkere: Int, steg: Double = 0.08, gamut: Gamut = .displayP3) -> [Farge] {
        Lyshetstrinn(antallLysere: lysere, antallMørkere: mørkere, lysereSteg: steg, mørkereSteg: steg).toner(for: farge, gamut: gamut)
    }
}

/// Hvor mange lysere/mørkere varianter, og hvor store stegene er – hver retning for seg.
///
/// - ``Modus/fast``: hvert steg endrer OKLCH-lyshet med et fast antall prosentpoeng
///   (0,08 = 8 %-poeng). Gir perseptuelt like store sprang.
/// - ``Modus/relativ``: hvert steg tar en andel av avstanden som gjenstår til hvitt
///   (lysere) eller sort (mørkere). Stegene blir mindre mot ytterpunktene og treffer aldri
///   helt hvitt/sort – slik mange designsystemer bygger tint/shade.
public struct Lyshetstrinn: Hashable, Codable, Sendable {
    public enum Modus: String, CaseIterable, Codable, Sendable {
        case fast, relativ
    }

    public var antallLysere: Int
    public var antallMørkere: Int
    public var lysereSteg: Double
    public var mørkereSteg: Double
    public var modus: Modus

    public init(antallLysere: Int = 3, antallMørkere: Int = 3, lysereSteg: Double = 0.08, mørkereSteg: Double = 0.08, modus: Modus = .fast) {
        self.antallLysere = antallLysere
        self.antallMørkere = antallMørkere
        self.lysereSteg = lysereSteg
        self.mørkereSteg = mørkereSteg
        self.modus = modus
    }

    /// OKLCH-lysheter fra lysest til mørkest; grunnfargens lyshet ligger på indeks `antallLysere`.
    public func lysheter(fra l: Double) -> [Double] {
        let lysere = (1...max(antallLysere, 1)).prefix(antallLysere).map { k -> Double in
            let k = Double(k)
            switch modus {
            case .fast: return l + lysereSteg * k
            case .relativ: return 1 - (1 - l) * pow(1 - lysereSteg, k)
            }
        }
        let mørkere = (1...max(antallMørkere, 1)).prefix(antallMørkere).map { k -> Double in
            let k = Double(k)
            switch modus {
            case .fast: return l - mørkereSteg * k
            case .relativ: return l * pow(1 - mørkereSteg, k)
            }
        }
        return (lysere.reversed() + [l] + mørkere).map { $0.klampet(0, 1) }
    }

    /// Variantene fra lysest til mørkest, med grunnfargen uendret i midten.
    /// Kulør og kroma bevares; hvert trinn gamut-kartlegges.
    public func toner(for farge: Farge, gamut: Gamut = .displayP3) -> [Farge] {
        let g = farge.okLCH
        return lysheter(fra: g.l).enumerated().map { i, l in
            i == antallLysere ? farge : Farge(okLCH: OKLCH(l: l, c: g.c, h: g.h), alfa: farge.alfa).gamutKartlagt(til: gamut)
        }
    }

    /// Menneskelig beskrivelse av ett steg, f.eks. «+8 %-poeng» eller «20 % mot hvitt».
    public func stegtekst(lysere: Bool) -> String {
        let v = Int(((lysere ? lysereSteg : mørkereSteg) * 100).rounded())
        switch modus {
        case .fast: return "\(lysere ? "+" : "−")\(v) %-poeng"
        case .relativ: return "\(v) % mot \(lysere ? "hvitt" : "sort")"
        }
    }
}
