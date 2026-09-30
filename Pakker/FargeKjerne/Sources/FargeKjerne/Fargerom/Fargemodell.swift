import Foundation

/// Fargemodellene brukeren kan redigere i. Gir et felles grensesnitt for
/// glidebrytere, tallfelt og tekstformatering, uavhengig av rommet.
public enum Fargemodell: String, CaseIterable, Codable, Sendable, Identifiable {
    case okLCH, okLab, cieLCH, cieLab, hsb, hsl, rgb, displayP3, cmyk

    public var id: String { rawValue }

    public var navn: String {
        switch self {
        case .okLCH: "OKLCH"
        case .okLab: "OKLab"
        case .cieLCH: "LCH"
        case .cieLab: "CIELab"
        case .hsb: "HSB"
        case .hsl: "HSL"
        case .rgb: "RGB"
        case .displayP3: "Display P3"
        case .cmyk: "CMYK"
        }
    }

    public struct Komponent: Sendable, Hashable {
        public let navn: String
        public let kortnavn: String
        public let område: ClosedRange<Double>
        /// Antall desimaler som gir meningsfull presisjon i visning.
        public let desimaler: Int
        public let erKulør: Bool
    }

    public var komponenter: [Komponent] {
        func k(_ n: String, _ kn: String, _ o: ClosedRange<Double>, _ d: Int, kulør: Bool = false) -> Komponent {
            Komponent(navn: n, kortnavn: kn, område: o, desimaler: d, erKulør: kulør)
        }
        switch self {
        case .okLCH: return [k("Lyshet", "L", 0...1, 3), k("Kroma", "C", 0...0.4, 3), k("Kulør", "H", 0...360, 1, kulør: true)]
        case .okLab: return [k("Lyshet", "L", 0...1, 3), k("Grønn–rød", "a", -0.4...0.4, 3), k("Blå–gul", "b", -0.4...0.4, 3)]
        case .cieLCH: return [k("Lyshet", "L", 0...100, 1), k("Kroma", "C", 0...150, 1), k("Kulør", "H", 0...360, 1, kulør: true)]
        case .cieLab: return [k("Lyshet", "L", 0...100, 1), k("Grønn–rød", "a", -128...127, 1), k("Blå–gul", "b", -128...127, 1)]
        case .hsb: return [k("Kulør", "H", 0...360, 0, kulør: true), k("Metning", "S", 0...1, 3), k("Lysstyrke", "B", 0...1, 3)]
        case .hsl: return [k("Kulør", "H", 0...360, 0, kulør: true), k("Metning", "S", 0...1, 3), k("Lyshet", "L", 0...1, 3)]
        case .rgb, .displayP3: return [k("Rød", "R", 0...1, 3), k("Grønn", "G", 0...1, 3), k("Blå", "B", 0...1, 3)]
        case .cmyk: return [k("Cyan", "C", 0...1, 3), k("Magenta", "M", 0...1, 3), k("Gul", "Y", 0...1, 3), k("Sort", "K", 0...1, 3)]
        }
    }

    /// Fargens komponentverdier i denne modellen.
    public func verdier(for f: Farge) -> [Double] {
        switch self {
        case .okLCH: let v = f.okLCH; return [v.l, v.c, v.h]
        case .okLab: let v = f.okLab; return [v.l, v.a, v.b]
        case .cieLCH: let v = f.cieLCH; return [v.l, v.c, v.h]
        case .cieLab: let v = f.cieLab; return [v.l, v.a, v.b]
        case .hsb: let v = f.hsb; return [v.h, v.s, v.b]
        case .hsl: let v = f.hsl; return [v.h, v.s, v.l]
        case .rgb: let v = f.sRGB; return [v.r, v.g, v.b]
        case .displayP3: let v = f.displayP3; return [v.r, v.g, v.b]
        case .cmyk: let v = f.naivCMYK; return [v.c, v.m, v.y, v.k]
        }
    }

    /// Lager en farge fra komponentverdier i denne modellen.
    public func farge(fra v: [Double], alfa: Double = 1) -> Farge {
        precondition(v.count == komponenter.count, "Feil antall komponenter for \(navn)")
        switch self {
        case .okLCH: return Farge(okLCH: OKLCH(l: v[0], c: v[1], h: v[2]), alfa: alfa)
        case .okLab: return Farge(okLab: OKLab(l: v[0], a: v[1], b: v[2]), alfa: alfa)
        case .cieLCH: return Farge(cieLCH: CIELCH(l: v[0], c: v[1], h: v[2]), alfa: alfa)
        case .cieLab: return Farge(cieLab: CIELab(l: v[0], a: v[1], b: v[2]), alfa: alfa)
        case .hsb: return Farge(hsb: HSB(h: v[0], s: v[1], b: v[2]), alfa: alfa)
        case .hsl: return Farge(hsl: HSL(h: v[0], s: v[1], l: v[2]), alfa: alfa)
        case .rgb: return Farge(sRGB: SRGB(r: v[0], g: v[1], b: v[2]), alfa: alfa)
        case .displayP3: return Farge(displayP3: DisplayP3(r: v[0], g: v[1], b: v[2]), alfa: alfa)
        case .cmyk: return Farge(naivCMYK: CMYK(c: v[0], m: v[1], y: v[2], k: v[3]), alfa: alfa)
        }
    }

    /// Tekst etter CSS Color 4 der det finnes en CSS-syntaks, ellers en lesbar notasjon.
    public func tekst(for f: Farge) -> String {
        let v = verdier(for: f)
        func t(_ i: Int, _ d: Int? = nil) -> String {
            String(format: "%.\(d ?? komponenter[i].desimaler)f", v[i])
        }
        func prosent(_ i: Int) -> String { String(format: "%.1f%%", v[i] * 100) }
        switch self {
        case .okLCH: return "oklch(\(t(0)) \(t(1)) \(t(2)))"
        case .okLab: return "oklab(\(t(0)) \(t(1)) \(t(2)))"
        case .cieLCH: return "lch(\(t(0)) \(t(1)) \(t(2)))"
        case .cieLab: return "lab(\(t(0)) \(t(1)) \(t(2)))"
        case .hsb: return "hsb(\(t(0)) \(prosent(1)) \(prosent(2)))"
        case .hsl: return "hsl(\(t(0)) \(prosent(1)) \(prosent(2)))"
        case .rgb: return "rgb(\(v.prefix(3).map { String(Int(($0.klampet(0, 1) * 255).rounded())) }.joined(separator: " ")))"
        case .displayP3: return "color(display-p3 \(t(0, 4)) \(t(1, 4)) \(t(2, 4)))"
        case .cmyk: return "cmyk(\((0..<4).map(prosent).joined(separator: " ")))"
        }
    }
}
