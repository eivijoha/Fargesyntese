import Foundation

/// En farge, lagret kanonisk som **lineær, utvidet sRGB** (D65-hvitpunkt).
///
/// Verdier utenfor 0…1 er lovlige og betyr at fargen ligger utenfor sRGB-gamut
/// (f.eks. mettede Display P3-farger fra kamera eller skjerm). All konvertering
/// mellom fargemodeller går via denne representasjonen, slik at ingen informasjon
/// klippes før det er nødvendig (visning, hex-eksport, CMYK).
public struct Farge: Hashable, Codable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var alfa: Double

    /// Lineære sRGB-komponenter (ikke gammakodet).
    public init(lineærR r: Double, g: Double, b: Double, alfa: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.alfa = alfa
    }

    var lineær: Vektor3 { Vektor3(r, g, b) }

    init(lineær v: Vektor3, alfa: Double = 1) {
        self.init(lineærR: v.x, g: v.y, b: v.z, alfa: alfa)
    }
}

// MARK: - Gamut

public extension Farge {
    /// Om fargen kan vises i sRGB uten klipping (med liten toleranse for avrunding).
    var erISRGB: Bool {
        let e = 1e-6
        return [r, g, b].allSatisfy { $0 >= -e && $0 <= 1 + e }
    }

    /// Om fargen kan vises i Display P3 uten klipping.
    var erIDisplayP3: Bool {
        let p = displayP3Lineær
        let e = 1e-6
        return [p.x, p.y, p.z].allSatisfy { $0 >= -e && $0 <= 1 + e }
    }
}

// MARK: - Hex

public extension Farge {
    /// Leser `#RGB`, `#RGBA`, `#RRGGBB` eller `#RRGGBBAA` (med eller uten `#`).
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 || s.count == 4 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6 || s.count == 8, let verdi = UInt64(s, radix: 16) else { return nil }
        let harAlfa = s.count == 8
        let rå = harAlfa ? verdi : (verdi << 8 | 0xFF)
        let kanal = { (skift: UInt64) in Double((rå >> skift) & 0xFF) / 255 }
        self.init(sRGB: SRGB(r: kanal(24), g: kanal(16), b: kanal(8)), alfa: kanal(0))
    }

    /// Hex-streng med Display P3-verdier (slik Figma og Sketch viser farger i P3-dokumenter).
    /// Farger utenfor P3 gamut-kartlegges først.
    func p3Hex() -> String {
        let p = gamutKartlagt(til: .displayP3).displayP3
        return "#" + [p.r, p.g, p.b].map { String(format: "%02X", Int(($0.klampet(0, 1) * 255).rounded())) }.joined()
    }

    /// Hex-streng i sRGB. Farger utenfor gamut blir først gamut-kartlagt (CSS Color 4).
    func hex(medAlfa: Bool = false) -> String {
        let s = gamutKartlagt(til: .sRGB).sRGB
        let tall = [s.r, s.g, s.b] + (medAlfa ? [alfa] : [])
        return "#" + tall.map { String(format: "%02X", Int(($0.klampet(0, 1) * 255).rounded())) }.joined()
    }
}

// MARK: - Hjelpere

extension Double {
    func klampet(_ lav: Double, _ høy: Double) -> Double { Swift.min(Swift.max(self, lav), høy) }
}

/// Liten 3-vektor for matriseregning uten avhengigheter (simd er ikke Double-vennlig på tvers av alle mål).
struct Vektor3: Hashable, Sendable {
    var x, y, z: Double
    init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
}

struct Matrise3: Sendable {
    let rader: [[Double]]
    init(_ rader: [[Double]]) { self.rader = rader }

    static func * (m: Matrise3, v: Vektor3) -> Vektor3 {
        let r = m.rader
        return Vektor3(
            r[0][0] * v.x + r[0][1] * v.y + r[0][2] * v.z,
            r[1][0] * v.x + r[1][1] * v.y + r[1][2] * v.z,
            r[2][0] * v.x + r[2][1] * v.y + r[2][2] * v.z
        )
    }

    static func * (a: Matrise3, b: Matrise3) -> Matrise3 {
        Matrise3((0..<3).map { i in (0..<3).map { j in (0..<3).reduce(0) { $0 + a.rader[i][$1] * b.rader[$1][j] } } })
    }

    /// Invers via kofaktorer. Brukes for å utlede motsatte konverteringsmatriser
    /// i stedet for å hardkode dem (unngår avrundingsinkonsistens).
    var invertert: Matrise3 {
        let m = rader
        let c00 = m[1][1] * m[2][2] - m[1][2] * m[2][1]
        let c01 = m[1][2] * m[2][0] - m[1][0] * m[2][2]
        let c02 = m[1][0] * m[2][1] - m[1][1] * m[2][0]
        let det = m[0][0] * c00 + m[0][1] * c01 + m[0][2] * c02
        let c10 = m[0][2] * m[2][1] - m[0][1] * m[2][2]
        let c11 = m[0][0] * m[2][2] - m[0][2] * m[2][0]
        let c12 = m[0][1] * m[2][0] - m[0][0] * m[2][1]
        let c20 = m[0][1] * m[1][2] - m[0][2] * m[1][1]
        let c21 = m[0][2] * m[1][0] - m[0][0] * m[1][2]
        let c22 = m[0][0] * m[1][1] - m[0][1] * m[1][0]
        return Matrise3([
            [c00 / det, c10 / det, c20 / det],
            [c01 / det, c11 / det, c21 / det],
            [c02 / det, c12 / det, c22 / det],
        ])
    }
}
