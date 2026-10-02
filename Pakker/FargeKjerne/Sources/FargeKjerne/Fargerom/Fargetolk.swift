import Foundation

/// Tolker fargetekst slik designere limer den inn: hex, CSS Color 4-funksjoner
/// (`rgb()`, `hsl()`, `hwb()`, `lab()`, `lch()`, `oklab()`, `oklch()`, `color()`),
/// CSS-navn og appens egne notasjoner (`hsb()`, `cmyk()`).
///
/// All tekst som ``Fargemodell/tekst(for:)`` produserer, kan leses tilbake.
public enum Fargetolk {
    /// Leser én farge. Hvis teksten ikke er en ren farge (f.eks. `--merkevare: #2F7FD8;`),
    /// brukes første farge som finnes i den.
    public static func tolk(_ tekst: String) -> Farge? {
        if let f = tolkEksakt(tekst) { return f }
        guard let treff = finnFarge(i: tekst) else { return nil }
        return tolkEksakt(String(tekst[treff]))
    }

    private static func tolkEksakt(_ tekst: String) -> Farge? {
        let s = tekst.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ";"))).lowercased()
        if s.isEmpty { return nil }
        if let f = Farge(hex: s) { return f }
        if let f = navngitte[s] { return f }
        guard let parentes = s.firstIndex(of: "("), s.hasSuffix(")") else { return nil }
        let funksjon = String(s[..<parentes]).trimmingCharacters(in: .whitespaces)
        let innhold = String(s[s.index(after: parentes)..<s.index(before: s.endIndex)])
        return tolkFunksjon(funksjon, innhold)
    }

    /// Finner alle farger i en tekstblokk – én per linje – med eventuelle navn.
    /// Takler bl.a. Kolorist sin «Navn⇥#hex», CSS-variabler (`--navn: #hex;`) og rene lister.
    public static func tolkListe(_ tekst: String) -> [PalettFarge] {
        tekst.split(whereSeparator: \.isNewline).compactMap { linje in
            let l = String(linje)
            guard let treff = finnFarge(i: l), let farge = tolkEksakt(String(l[treff])) else { return nil }
            var navn = l
            navn.removeSubrange(treff)
            let skilletegn = CharacterSet.whitespaces.union(CharacterSet(charactersIn: ":;,=-\t\"'"))
            return PalettFarge(navn: navn.trimmingCharacters(in: skilletegn), farge: farge, opphav: .manuell)
        }
    }

    private static func finnFarge(i linje: String) -> Range<String.Index>? {
        let funksjoner = "(?:rgba?|hsla?|hsb|hsv|hwb|lab|lch|oklab|oklch|color|cmyk|device-cmyk)\\([^)]*\\)"
        if let r = linje.range(of: funksjoner, options: [.regularExpression, .caseInsensitive]) { return r }
        if let r = linje.range(of: "#?\\b[0-9a-fA-F]{8}\\b|#?\\b[0-9a-fA-F]{6}\\b|#[0-9a-fA-F]{3,4}\\b", options: .regularExpression) { return r }
        return nil
    }

    // MARK: - Funksjoner

    private enum Token {
        case tall(Double), prosent(Double), vinkel(Double), ingen

        /// Tall eller prosent skalert slik at 100 % = `full`.
        func verdi(full: Double) -> Double {
            switch self {
            case .tall(let v), .vinkel(let v): v
            case .prosent(let p): p / 100 * full
            case .ingen: 0
            }
        }

        /// Kulør i grader.
        var grader: Double {
            switch self {
            case .tall(let v), .vinkel(let v): v
            case .prosent(let p): p / 100 * 360
            case .ingen: 0
            }
        }
    }

    private static func tokens(_ s: String) -> [Token]? {
        var ut: [Token] = []
        for del in s.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\t" }) {
            var t = String(del)
            if t == "none" { ut.append(.ingen); continue }
            if t.hasSuffix("%") {
                t.removeLast()
                guard let v = Double(t) else { return nil }
                ut.append(.prosent(v)); continue
            }
            let enheter: [(String, Double)] = [("grad", 0.9), ("deg", 1), ("rad", 180 / .pi), ("turn", 360)]
            if let (enhet, faktor) = enheter.first(where: { t.hasSuffix($0.0) }) {
                guard let v = Double(t.dropLast(enhet.count)) else { return nil }
                ut.append(.vinkel(v * faktor)); continue
            }
            guard let v = Double(t) else { return nil }
            ut.append(.tall(v))
        }
        return ut
    }

    private static func tolkFunksjon(_ navn: String, _ innhold: String) -> Farge? {
        var deler = innhold.split(separator: "/", maxSplits: 1).map(String.init)
        let alfaTekst = deler.count > 1 ? deler.removeLast() : nil
        var hoved = deler.first ?? ""

        // color(display-p3 1 0 0)
        var rom: String?
        if navn == "color" {
            let ord = hoved.split(separator: " ", maxSplits: 1).map(String.init)
            guard ord.count == 2 else { return nil }
            rom = ord[0]
            hoved = ord[1]
        }
        guard var k = tokens(hoved) else { return nil }

        // Gammel syntaks: rgba(r, g, b, a)
        if alfaTekst == nil, ["rgb", "rgba", "hsl", "hsla"].contains(navn), k.count == 4 {
            let a = k.removeLast()
            return tolkFunksjon(navn, hovedTekst(k) + " / " + tokenTekst(a))
        }
        let alfa = alfaTekst.flatMap(tokens)?.first?.verdi(full: 1) ?? 1

        switch navn {
        case "rgb", "rgba":
            guard k.count == 3 else { return nil }
            let v = k.map { $0.verdi(full: 255) / 255 }
            return Farge(sRGB: SRGB(r: v[0], g: v[1], b: v[2]), alfa: alfa)
        case "hsl", "hsla":
            guard k.count == 3 else { return nil }
            return Farge(hsl: HSL(h: k[0].grader, s: prosentverdi(k[1]), l: prosentverdi(k[2])), alfa: alfa)
        case "hsb", "hsv":
            guard k.count == 3 else { return nil }
            return Farge(hsb: HSB(h: k[0].grader, s: prosentverdi(k[1]), b: prosentverdi(k[2])), alfa: alfa)
        case "hwb":
            guard k.count == 3 else { return nil }
            let w = prosentverdi(k[1]), b = prosentverdi(k[2])
            if w + b >= 1 { let g = w / (w + b); return Farge(sRGB: SRGB(r: g, g: g, b: g), alfa: alfa) }
            let ren = Farge(hsl: HSL(h: k[0].grader, s: 1, l: 0.5)).sRGB
            let f = { (c: Double) in c * (1 - w - b) + w }
            return Farge(sRGB: SRGB(r: f(ren.r), g: f(ren.g), b: f(ren.b)), alfa: alfa)
        case "lab":
            guard k.count == 3 else { return nil }
            return Farge(cieLab: CIELab(l: k[0].verdi(full: 100), a: k[1].verdi(full: 125), b: k[2].verdi(full: 125)), alfa: alfa)
        case "lch":
            guard k.count == 3 else { return nil }
            return Farge(cieLCH: CIELCH(l: k[0].verdi(full: 100), c: k[1].verdi(full: 150), h: k[2].grader), alfa: alfa)
        case "oklab":
            guard k.count == 3 else { return nil }
            return Farge(okLab: OKLab(l: k[0].verdi(full: 1), a: k[1].verdi(full: 0.4), b: k[2].verdi(full: 0.4)), alfa: alfa)
        case "oklch":
            guard k.count == 3 else { return nil }
            return Farge(okLCH: OKLCH(l: k[0].verdi(full: 1), c: k[1].verdi(full: 0.4), h: k[2].grader), alfa: alfa)
        case "cmyk", "device-cmyk":
            guard k.count == 4 else { return nil }
            let v = k.map { $0.verdi(full: 1) }
            return Farge(naivCMYK: CMYK(c: v[0], m: v[1], y: v[2], k: v[3]), alfa: alfa)
        case "color":
            guard k.count == 3 else { return nil }
            let v = k.map { $0.verdi(full: 1) }
            switch rom {
            case "srgb": return Farge(sRGB: SRGB(r: v[0], g: v[1], b: v[2]), alfa: alfa)
            case "srgb-linear": return Farge(lineærR: v[0], g: v[1], b: v[2], alfa: alfa)
            case "display-p3": return Farge(displayP3: DisplayP3(r: v[0], g: v[1], b: v[2]), alfa: alfa)
            case "xyz", "xyz-d65": return Farge(xyz: XYZ(x: v[0], y: v[1], z: v[2]), alfa: alfa)
            case "xyz-d50":
                let d65 = Matriser.d50TilD65 * Vektor3(v[0], v[1], v[2])
                return Farge(xyz: XYZ(x: d65.x, y: d65.y, z: d65.z), alfa: alfa)
            #if canImport(CoreGraphics)
            case "a98-rgb": return Farge(komponenter: v, i: .adobeRGB, alfa: alfa)
            case "rec2020": return Farge(komponenter: v, i: .rec2020, alfa: alfa)
            case "prophoto-rgb": return Farge(komponenter: v, i: .proPhotoRGB, alfa: alfa)
            #endif
            default: return nil
            }
        default:
            return nil
        }
    }

    /// HSL/HSB: CSS Color 4 tillater både «50%» og «50» for metning/lyshet.
    private static func prosentverdi(_ t: Token) -> Double {
        if case .tall(let v) = t { return v > 1 ? v / 100 : v }
        return t.verdi(full: 1)
    }

    private static func tokenTekst(_ t: Token) -> String {
        switch t {
        case .tall(let v), .vinkel(let v): "\(v)"
        case .prosent(let p): "\(p)%"
        case .ingen: "none"
        }
    }

    private static func hovedTekst(_ k: [Token]) -> String { k.map(tokenTekst).joined(separator: " ") }

    /// CSS-grunnfargene og noen vanlige navn. Utvides ved behov.
    static let navngitte: [String: Farge] = [
        "black": "#000000", "white": "#FFFFFF", "red": "#FF0000", "green": "#008000", "blue": "#0000FF",
        "yellow": "#FFFF00", "cyan": "#00FFFF", "aqua": "#00FFFF", "magenta": "#FF00FF", "fuchsia": "#FF00FF",
        "gray": "#808080", "grey": "#808080", "silver": "#C0C0C0", "maroon": "#800000", "olive": "#808000",
        "lime": "#00FF00", "navy": "#000080", "purple": "#800080", "teal": "#008080", "orange": "#FFA500",
        "rebeccapurple": "#663399", "transparent": "#00000000",
    ].compactMapValues { Farge(hex: $0) }
}
