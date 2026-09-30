import Foundation

/// CSS-gradient fra en rekke farger (typisk en overgang).
///
/// Moderne nettlesere får `in oklab`, som gir nøyaktig samme interpolasjon som appen.
/// Eldre nettlesere får en reserve med tette sRGB-stopp som etterligner OKLab-kurven.
public struct CSSGradient: Hashable, Sendable {
    public enum Form: String, CaseIterable, Sendable, Identifiable {
        case lineær, radiell, konisk
        public var id: String { rawValue }
        public var navn: String { rawValue.capitalized }
    }

    public var farger: [Farge]
    public var form: Form
    /// Retning i grader for lineær (90 = mot høyre) og startvinkel for konisk.
    public var vinkel: Double
    /// Harde stopp: hver farge som et eget bånd, uten glidende overgang.
    public var trinnvis: Bool
    /// Antall stopp i reserven for eldre nettlesere.
    public var reserveStopp: Int

    public init(farger: [Farge], form: Form = .lineær, vinkel: Double = 90, trinnvis: Bool = false, reserveStopp: Int = 9) {
        self.farger = farger
        self.form = form
        self.vinkel = vinkel
        self.trinnvis = trinnvis
        self.reserveStopp = reserveStopp
    }

    private var hode: String {
        let v = "\(Int(vinkel.rounded()))deg"
        switch form {
        case .lineær: return "linear-gradient(%@\(v)"
        case .radiell: return "radial-gradient(%@circle"
        case .konisk: return "conic-gradient(%@from \(v)"
        }
    }

    private func funksjon(interpolasjon: String?, stopp: [String]) -> String {
        let h = hode.replacingOccurrences(of: "%@", with: interpolasjon.map { "in \($0) " } ?? "")
        return "\(h), \(stopp.joined(separator: ", ")))"
    }

    private static func prosent(_ t: Double) -> String {
        let p = (t * 1000).rounded() / 10
        return p == p.rounded() ? "\(Int(p))%" : "\(p)%"
    }

    /// Stopp med harde overganger: hver farge fyller sitt bånd.
    private func trinnvisStopp(_ tekst: (Farge) -> String) -> [String] {
        let n = Double(farger.count)
        return farger.enumerated().map { i, f in
            "\(tekst(f)) \(Self.prosent(Double(i) / n)) \(Self.prosent(Double(i + 1) / n))"
        }
    }

    /// Verdien alene, med OKLab-interpolasjon (CSS Color 4).
    public var moderne: String {
        let oklch = { (f: Farge) in Fargemodell.okLCH.tekst(for: f) }
        if trinnvis { return funksjon(interpolasjon: nil, stopp: trinnvisStopp(oklch)) }
        return funksjon(interpolasjon: "oklab", stopp: farger.map(oklch))
    }

    /// Reserve uten `in oklab`: tette sRGB-stopp langs OKLab-kurven.
    public var reserve: String {
        let hex = { (f: Farge) in f.hex(medAlfa: f.alfa < 1) }
        if trinnvis { return funksjon(interpolasjon: nil, stopp: trinnvisStopp(hex)) }
        let prøver = Overgang.toner(gjennom: farger, stegMellom: max(0, (reserveStopp - farger.count) / max(farger.count - 1, 1)))
        let n = Double(max(prøver.count - 1, 1))
        return funksjon(interpolasjon: nil, stopp: prøver.enumerated().map { "\(hex($1)) \(Self.prosent(Double($0) / n))" })
    }

    /// Ferdig CSS-deklarasjon med reserve først, slik at moderne nettlesere overstyrer.
    public var deklarasjon: String {
        """
        background: \(reserve);
        background: \(moderne);
        """
    }
}
