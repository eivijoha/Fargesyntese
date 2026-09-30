import Foundation

enum TekstEksport {
    private static func navn(_ p: Palett) -> [String] {
        Identifikator.unike(p.farger.enumerated().map { i, f in Identifikator.kebab(f.navn, reserve: "farge-\(i + 1)") })
    }

    static func css(_ p: Palett) -> String {
        let n = navn(p)
        let sRGB = zip(n, p.farger).map { "  --\($0): \($1.farge.hex(medAlfa: $1.farge.alfa < 1));" }
        let oklch = zip(n, p.farger).map { "    --\($0): \(Fargemodell.okLCH.tekst(for: $1.farge));" }
        return """
        /* \(p.navn) – eksportert fra Fargesyntese */
        :root {
        \(sRGB.joined(separator: "\n"))
        }

        @supports (color: oklch(0 0 0)) {
          :root {
        \(oklch.joined(separator: "\n"))
          }
        }

        """
    }

    /// W3C Design Tokens Community Group-format (2025.10), fargeverdier som objekter med fargerom.
    static func designTokens(_ p: Palett) -> Data {
        var gruppe: [String: Any] = ["$type": "color", "$description": p.navn]
        for (n, f) in zip(navn(p), p.farger) {
            let lch = f.farge.okLCH
            gruppe[n] = [
                "$value": [
                    "colorSpace": "oklch",
                    "components": [lch.l, lch.c, lch.h].map { ($0 * 10000).rounded() / 10000 },
                    "alpha": f.farge.alfa,
                    "hex": f.farge.hex(),
                ] as [String: Any],
            ]
        }
        let rot = [Identifikator.kebab(p.navn, reserve: "palett"): gruppe]
        return (try? JSONSerialization.data(withJSONObject: rot, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }

    static func gpl(_ p: Palett) -> String {
        var linjer = ["GIMP Palette", "Name: \(p.navn)", "Columns: \(min(max(p.farger.count, 1), 16))", "#"]
        for f in p.farger {
            let s = f.farge.gamutKartlagt(til: .sRGB).sRGB
            let k = [s.r, s.g, s.b].map { Int(($0.klampet(0, 1) * 255).rounded()) }
            linjer.append(String(format: "%3d %3d %3d\t%@", k[0], k[1], k[2], f.visningsnavn))
        }
        return linjer.joined(separator: "\n") + "\n"
    }

    static func swiftUI(_ p: Palett) -> String {
        let typenavn = Identifikator.camel(p.navn, reserve: "palett").prefix(1).uppercased()
            + Identifikator.camel(p.navn, reserve: "palett").dropFirst()
        let egenskaper = zip(p.farger.indices, p.farger).map { i, f -> String in
            let id = Identifikator.camel(f.navn, reserve: "farge\(i + 1)")
            let d = f.farge.gamutKartlagt(til: .displayP3).displayP3
            let v = [d.r, d.g, d.b].map { String(format: "%.4f", $0.klampet(0, 1)) }
            return "    static let \(id) = Color(.displayP3, red: \(v[0]), green: \(v[1]), blue: \(v[2]), opacity: \(String(format: "%.3f", f.farge.alfa))) // \(f.farge.hex())"
        }
        return """
        // \(p.navn) – eksportert fra Fargesyntese
        import SwiftUI

        enum \(typenavn) {
        \(egenskaper.joined(separator: "\n"))
        }

        """
    }
}
