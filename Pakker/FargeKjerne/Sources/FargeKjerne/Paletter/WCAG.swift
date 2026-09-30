import Foundation

/// WCAG 2.2-krav til kontrast (suksesskriteriene 1.4.3, 1.4.6 og 1.4.11).
public enum WCAGKrav: String, CaseIterable, Sendable, Identifiable, Codable {
    /// 1.4.3 AA, vanlig tekst.
    case aaTekst
    /// 1.4.3 AA, stor tekst (≥ 24 px, eller ≥ 18,66 px fet).
    case aaStorTekst
    /// 1.4.6 AAA, vanlig tekst.
    case aaaTekst
    /// 1.4.6 AAA, stor tekst.
    case aaaStorTekst
    /// 1.4.11 AA, grafiske objekter og brukergrensesnittkomponenter.
    case aaGrafikk

    public var id: String { rawValue }

    public var minimum: Double {
        switch self {
        case .aaTekst, .aaaStorTekst: 4.5
        case .aaStorTekst, .aaGrafikk: 3
        case .aaaTekst: 7
        }
    }

    public var nivå: String {
        switch self {
        case .aaTekst, .aaStorTekst, .aaGrafikk: "AA"
        case .aaaTekst, .aaaStorTekst: "AAA"
        }
    }

    public var navn: String {
        switch self {
        case .aaTekst: "Tekst AA"
        case .aaStorTekst: "Stor tekst AA"
        case .aaaTekst: "Tekst AAA"
        case .aaaStorTekst: "Stor tekst AAA"
        case .aaGrafikk: "Grafikk og UI AA"
        }
    }

    public var suksesskriterium: String {
        switch self {
        case .aaTekst, .aaStorTekst: "1.4.3"
        case .aaaTekst, .aaaStorTekst: "1.4.6"
        case .aaGrafikk: "1.4.11"
        }
    }
}

/// Resultatet av en kontrasttest mellom forgrunn og bakgrunn.
public struct Kontrasttest: Sendable, Hashable {
    public let forgrunn: Farge
    public let bakgrunn: Farge
    /// WCAG-kontrastforhold 1…21.
    public let forhold: Double

    public init(forgrunn: Farge, bakgrunn: Farge) {
        self.forgrunn = forgrunn
        self.bakgrunn = bakgrunn
        // Gjennomsiktig forgrunn legges over bakgrunnen først (slik den faktisk vises).
        self.forhold = forgrunn.lagtOver(bakgrunn).wcagKontrast(mot: bakgrunn)
    }

    public func består(_ krav: WCAGKrav) -> Bool {
        // WCAG sier eksplisitt at forholdet ikke skal avrundes opp (4,499 består ikke 4,5).
        forhold >= krav.minimum
    }

    /// De strengeste kravene som bestås, f.eks. «AAA» eller «AA stor tekst».
    public var sammendrag: String {
        if består(.aaaTekst) { return "AAA" }
        if består(.aaTekst) { return "AA" }
        if består(.aaStorTekst) { return "AA stor tekst" }
        return "Består ikke"
    }

    /// Forholdet formatert som WCAG-verktøy gjør det, f.eks. «4,52:1».
    public var formatert: String {
        let avkortet = (forhold * 100).rounded(.down) / 100
        return avkortet.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "nb_NO"))) + ":1"
    }

    /// Forslag til justert forgrunn som oppfyller kravet (bevarer kulør og kroma).
    public func rettet(for krav: WCAGKrav) -> Farge {
        forgrunn.medKontrast(mot: bakgrunn, minst: krav.minimum + 0.01)
    }
}

public extension Farge {
    /// Alfa-komposisjon i lineært lys (som nettlesere gjør for sRGB er det i gammarommet;
    /// forskjellen er liten for kontrastformål, og lineært er fysisk riktig).
    func lagtOver(_ bakgrunn: Farge) -> Farge {
        guard alfa < 1 else { return self }
        let a = alfa
        return Farge(lineærR: r * a + bakgrunn.r * (1 - a), g: g * a + bakgrunn.g * (1 - a),
                     b: b * a + bakgrunn.b * (1 - a), alfa: 1)
    }
}

public extension Palett {
    /// Alle ordnede par (forgrunn, bakgrunn) av ulike farger i paletten.
    var kontrastmatrise: [[Kontrasttest]] {
        farger.map { fg in farger.map { bg in Kontrasttest(forgrunn: fg.farge, bakgrunn: bg.farge) } }
    }
}
