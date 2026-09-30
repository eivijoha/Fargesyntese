#if canImport(CoreGraphics)
import CoreGraphics
import Foundation

/// Fargestyrt utplukk fra et bilde.
///
/// Bildet tegnes én gang inn i en Float-buffer i utvidet lineær sRGB. CoreGraphics
/// bruker da bildets innebygde ICC-profil (P3 fra iPhone, Adobe RGB fra kamera osv.),
/// så fargene vi leser ut er riktige uansett kilde – og P3-farger klippes ikke.
public struct Bildeprøve: Sendable {
    public let bredde: Int
    public let høyde: Int
    /// RGBA, rad 0 er øverst i bildet, ikke-premultiplisert.
    private let piksler: [Float]

    public init?(bilde: CGImage) {
        let (w, h) = (bilde.width, bilde.height)
        guard w > 0, h > 0, let rom = CGColorSpace(name: CGColorSpace.extendedLinearSRGB) else { return nil }
        var buffer = [Float](repeating: 0, count: w * h * 4)
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.floatComponents.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
        let tegnet = buffer.withUnsafeMutableBytes { minne -> Bool in
            guard let kontekst = CGContext(data: minne.baseAddress, width: w, height: h, bitsPerComponent: 32,
                                           bytesPerRow: w * 16, space: rom, bitmapInfo: info)
            else { return false }
            kontekst.draw(bilde, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard tegnet else { return nil }
        // Fjern premultiplisering, så gjennomsnitt og k-means jobber på ekte farger.
        for i in stride(from: 0, to: buffer.count, by: 4) where buffer[i + 3] > 0 && buffer[i + 3] < 1 {
            let a = buffer[i + 3]
            buffer[i] /= a; buffer[i + 1] /= a; buffer[i + 2] /= a
        }
        bredde = w
        høyde = h
        piksler = buffer
    }

    /// Gjennomsnittsfarge (i lineært lys) i et kvadrat rundt (x, y). Origo øverst til venstre.
    public func farge(x: Int, y: Int, radius: Int = 0) -> Farge {
        var sum = (r: 0.0, g: 0.0, b: 0.0, a: 0.0), n = 0.0
        for yy in max(0, y - radius)...min(høyde - 1, y + radius) {
            for xx in max(0, x - radius)...min(bredde - 1, x + radius) {
                let i = (yy * bredde + xx) * 4
                sum.r += Double(piksler[i]); sum.g += Double(piksler[i + 1])
                sum.b += Double(piksler[i + 2]); sum.a += Double(piksler[i + 3])
                n += 1
            }
        }
        guard n > 0 else { return Farge(lineærR: 0, g: 0, b: 0) }
        return Farge(lineærR: sum.r / n, g: sum.g / n, b: sum.b / n, alfa: sum.a / n)
    }

    /// Jevnt fordelt utvalg på omtrent `maks` piksler (for palettuttrekk). Gjennomsiktige hoppes over.
    public func utvalg(maks: Int = 6000) -> [Farge] {
        let steg = max(1, Int((Double(bredde * høyde) / Double(maks)).squareRoot()))
        var ut: [Farge] = []
        for y in stride(from: steg / 2, to: høyde, by: steg) {
            for x in stride(from: steg / 2, to: bredde, by: steg) {
                let i = (y * bredde + x) * 4
                guard piksler[i + 3] > 0.5 else { continue }
                ut.append(Farge(lineærR: Double(piksler[i]), g: Double(piksler[i + 1]), b: Double(piksler[i + 2])))
            }
        }
        return ut
    }
}
#endif

/// Dominerende farger via k-means i OKLab (deterministisk, så samme bilde gir samme palett).
public enum Bildepalett {
    public struct Klynge: Sendable, Hashable {
        public var farge: Farge
        /// Andel av pikslene, 0…1.
        public var andel: Double

        public init(farge: Farge, andel: Double) {
            self.farge = farge
            self.andel = andel
        }
    }

    public static func dominerende(_ farger: [Farge], antall: Int, iterasjoner: Int = 15) -> [Klynge] {
        let punkter = farger.map { let l = $0.okLab; return Vektor3(l.l, l.a, l.b) }
        guard !punkter.isEmpty, antall > 0 else { return [] }
        let k = min(antall, punkter.count)

        func avstand2(_ a: Vektor3, _ b: Vektor3) -> Double {
            let (dl, da, db) = (a.x - b.x, a.y - b.y, a.z - b.z)
            return dl * dl + da * da + db * db
        }

        // Start: punktet nærmest snittet, deretter «lengst unna eksisterende sentre» (maximin).
        let snitt = punkter.reduce(Vektor3(0, 0, 0)) { Vektor3($0.x + $1.x, $0.y + $1.y, $0.z + $1.z) }
        let s = Vektor3(snitt.x / Double(punkter.count), snitt.y / Double(punkter.count), snitt.z / Double(punkter.count))
        var sentre = [punkter.min { avstand2($0, s) < avstand2($1, s) }!]
        var nærmeste = punkter.map { avstand2($0, sentre[0]) }
        while sentre.count < k {
            let i = nærmeste.indices.max { nærmeste[$0] < nærmeste[$1] }!
            sentre.append(punkter[i])
            for j in punkter.indices { nærmeste[j] = min(nærmeste[j], avstand2(punkter[j], punkter[i])) }
        }

        var tilhørighet = [Int](repeating: 0, count: punkter.count)
        for _ in 0..<iterasjoner {
            var endret = false
            for (j, p) in punkter.enumerated() {
                let beste = sentre.indices.min { avstand2(p, sentre[$0]) < avstand2(p, sentre[$1]) }!
                if beste != tilhørighet[j] { tilhørighet[j] = beste; endret = true }
            }
            var summer = [Vektor3](repeating: Vektor3(0, 0, 0), count: k), antallI = [Int](repeating: 0, count: k)
            for (j, p) in punkter.enumerated() {
                let c = tilhørighet[j]
                summer[c] = Vektor3(summer[c].x + p.x, summer[c].y + p.y, summer[c].z + p.z)
                antallI[c] += 1
            }
            for c in 0..<k where antallI[c] > 0 {
                let n = Double(antallI[c])
                sentre[c] = Vektor3(summer[c].x / n, summer[c].y / n, summer[c].z / n)
            }
            if !endret { break }
        }

        var størrelse = [Int](repeating: 0, count: k)
        tilhørighet.forEach { størrelse[$0] += 1 }
        return (0..<k)
            .filter { størrelse[$0] > 0 }
            .map { Klynge(farge: Farge(okLab: OKLab(l: sentre[$0].x, a: sentre[$0].y, b: sentre[$0].z)),
                          andel: Double(størrelse[$0]) / Double(punkter.count)) }
            .sorted { $0.andel > $1.andel }
    }
}
