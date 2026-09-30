import FargeKjerne
import Foundation

/// Deterministisk reserve når Apple Intelligence ikke er tilgjengelig (eldre enheter,
/// slått av, eller språket ikke støttet). Et lite leksikon kobler verdiord til
/// OKLCH-tendenser, og en fast harmoniregel bygger paletten.
public struct LeksikonTolker: VerdiordTolker {
    public init() {}

    struct Tendens {
        var kulør: Double
        var kroma: Double
        var lyshet: Double
    }

    /// Utvides fortløpende. Nøkler er ordstammer, så «trygghet» treffer «trygg».
    static let leksikon: [String: Tendens] = [
        "trygg": .init(kulør: 250, kroma: 0.08, lyshet: 0.45),
        "tillit": .init(kulør: 245, kroma: 0.10, lyshet: 0.45),
        "rolig": .init(kulør: 220, kroma: 0.05, lyshet: 0.75),
        "ro": .init(kulør: 210, kroma: 0.04, lyshet: 0.80),
        "varm": .init(kulør: 55, kroma: 0.12, lyshet: 0.65),
        "energi": .init(kulør: 40, kroma: 0.20, lyshet: 0.65),
        "leken": .init(kulør: 340, kroma: 0.18, lyshet: 0.70),
        "glede": .init(kulør: 95, kroma: 0.16, lyshet: 0.85),
        "nordisk": .init(kulør: 230, kroma: 0.03, lyshet: 0.85),
        "natur": .init(kulør: 140, kroma: 0.09, lyshet: 0.55),
        "bærekraft": .init(kulør: 150, kroma: 0.10, lyshet: 0.55),
        "grønn": .init(kulør: 145, kroma: 0.14, lyshet: 0.60),
        "hav": .init(kulør: 225, kroma: 0.10, lyshet: 0.50),
        "fjord": .init(kulør: 235, kroma: 0.07, lyshet: 0.45),
        "luksus": .init(kulør: 300, kroma: 0.06, lyshet: 0.25),
        "eksklusiv": .init(kulør: 80, kroma: 0.05, lyshet: 0.30),
        "innovasjon": .init(kulør: 285, kroma: 0.20, lyshet: 0.55),
        "teknologi": .init(kulør: 265, kroma: 0.16, lyshet: 0.50),
        "kreativ": .init(kulør: 320, kroma: 0.19, lyshet: 0.60),
        "profesjonell": .init(kulør: 255, kroma: 0.05, lyshet: 0.35),
        "seriøs": .init(kulør: 250, kroma: 0.04, lyshet: 0.30),
        "vennlig": .init(kulør: 65, kroma: 0.10, lyshet: 0.80),
        "omsorg": .init(kulør: 20, kroma: 0.08, lyshet: 0.80),
        "kjærlighet": .init(kulør: 15, kroma: 0.18, lyshet: 0.55),
        "styrke": .init(kulør: 25, kroma: 0.17, lyshet: 0.45),
        "mot": .init(kulør: 30, kroma: 0.20, lyshet: 0.55),
        "kunnskap": .init(kulør: 260, kroma: 0.09, lyshet: 0.40),
        "visdom": .init(kulør: 280, kroma: 0.07, lyshet: 0.35),
        "enkel": .init(kulør: 90, kroma: 0.01, lyshet: 0.90),
        "minimal": .init(kulør: 90, kroma: 0.005, lyshet: 0.92),
        "jordnær": .init(kulør: 60, kroma: 0.06, lyshet: 0.50),
        "vinter": .init(kulør: 235, kroma: 0.04, lyshet: 0.88),
        "sommer": .init(kulør: 85, kroma: 0.15, lyshet: 0.82),
        "høst": .init(kulør: 50, kroma: 0.13, lyshet: 0.50),
        "vår": .init(kulør: 130, kroma: 0.12, lyshet: 0.85),
    ]

    public func forslag(for verdiord: String, antall: Int) async throws -> PalettForslag {
        let ord = verdiord.lowercased()
            .split { !$0.isLetter }
            .map(String.init)
        let treff = ord.compactMap { o in
            Self.leksikon.first { o.hasPrefix($0.key) || $0.key.hasPrefix(o) && o.count >= 3 }
        }
        let tendenser = treff.isEmpty ? [Tendens(kulør: 240, kroma: 0.08, lyshet: 0.5)] : treff.map(\.value)

        // Sirkulært gjennomsnitt av kulør.
        let x = tendenser.map { cos($0.kulør * .pi / 180) }.reduce(0, +)
        let y = tendenser.map { sin($0.kulør * .pi / 180) }.reduce(0, +)
        var kulør = atan2(y, x) * 180 / .pi
        if kulør < 0 { kulør += 360 }
        let kroma = tendenser.map(\.kroma).reduce(0, +) / Double(tendenser.count)
        let lyshet = tendenser.map(\.lyshet).reduce(0, +) / Double(tendenser.count)

        let roller: [(String, OKLCH)] = [
            ("Primær", OKLCH(l: lyshet, c: max(kroma, 0.04), h: kulør)),
            ("Sekundær", OKLCH(l: min(lyshet + 0.15, 0.9), c: kroma * 0.7, h: kulør + 30)),
            ("Aksent", OKLCH(l: 0.68, c: max(kroma * 1.4, 0.14), h: kulør + 180)),
            ("Bakgrunn", OKLCH(l: 0.97, c: 0.01, h: kulør)),
            ("Tekst", OKLCH(l: 0.22, c: 0.02, h: kulør)),
            ("Støtte", OKLCH(l: max(lyshet - 0.15, 0.3), c: kroma, h: kulør - 30)),
        ]
        let valgt = (0..<max(antall, 1)).map { roller[$0 % roller.count] }

        return PalettForslag(
            tittel: treff.isEmpty ? "Nøytral start" : treff.map { $0.key.capitalized }.joined(separator: " · "),
            forklaring: treff.isEmpty
                ? "Fant ingen kjente verdiord – her er et nøytralt utgangspunkt."
                : "Bygget fra leksikonet: kulør rundt \(Int(kulør))°, med analog sekundærfarge og komplementær aksent.",
            farger: valgt.map { rolle, lch in
                var l = lch
                l.h = (l.h + 360).truncatingRemainder(dividingBy: 360)
                return Fargeforslag(navn: rolle, rolle: rolle.lowercased(), begrunnelse: "",
                                    farge: Farge(okLCH: l).gamutKartlagt(til: .displayP3))
            },
            kilde: .leksikon
        )
    }
}
