import FargeKjerne
import Foundation

/// Deterministisk reserve når Apple Intelligence ikke er tilgjengelig (eldre enheter,
/// slått av, eller språket ikke støttet). Bruker samme kunnskapsbase som språkmodellen
/// (``Fargesemantikk``): de tyngste kulørfamiliene blir primær og sekundær, aksenten følger
/// begrepets aksent eller harmoni, og lyshet/metning hentes fra begrepene.
public struct LeksikonTolker: VerdiordTolker {
    public init() {}

    public func forslag(for verdiord: String, antall: Int) async throws -> PalettForslag {
        forslag(for: verdiord, antall: antall, gamut: .displayP3)
    }

    public func forslag(for verdiord: String, antall: Int, gamut: Gamut) -> PalettForslag {
        let grunnlag = Fargesemantikk.oppslag(verdiord)
        let hoved = grunnlag.begreper.first
        let familier = grunnlag.familievekter.map(\.0).filter { $0 != .nøytral }
        let f1 = familier.first ?? .blå
        let f2 = familier.dropFirst().first ?? f1.nabo(1)
        let f3 = familier.dropFirst(2).first ?? f1.nabo(-1)

        let metning = hoved?.metning.first ?? .klar
        let lysheter = hoved?.lyshet ?? [.middelsMørk, .middels]
        // Lysheten der primærfamilien er klarest (gul blir ellers oliven, oransje brun).
        let lyshet = Fargespesifikasjon.klaresteLyshet(for: f1, blant: lysheter, i: gamut)
        let aksentfamilie: Kulørfamilie = {
            if let a = grunnlag.begreper.flatMap(\.aksent).first(where: { $0 != f1 && $0 != .nøytral }) { return a }
            switch hoved?.harmoni {
            case "komplementær": return f1.nabo(7)
            case "triade": return f1.nabo(5)
            default: return f1.nabo(3)
            }
        }()

        func steg(_ l: Lyshetsnivå, _ n: Int) -> Lyshetsnivå {
            let alle = Lyshetsnivå.allCases
            let i = alle.firstIndex(of: l)!
            return alle[max(1, min(alle.count - 2, i + n))]
        }

        let roller: [(String, Fargespesifikasjon)] = [
            ("primær", .init(familie: f1, lyshet: lyshet, metning: metning)),
            ("sekundær", .init(familie: f2, lyshet: Fargespesifikasjon.klaresteLyshet(for: f2, blant: lysheter + [steg(lyshet, 1)], i: gamut), metning: metning)),
            ("aksent", .init(familie: aksentfamilie,
                             lyshet: Fargespesifikasjon.klaresteLyshet(for: aksentfamilie, blant: [.middelsMørk, .middels, .lys, .sværtLys], i: gamut),
                             metning: max(metning, .klar))),
            ("bakgrunn", .init(familie: f1, lyshet: .nestenHvit, metning: .svak)),
            ("tekst", .init(familie: f1, lyshet: .nestenSort, metning: .dempet)),
            ("støtte", .init(familie: f3, lyshet: Fargespesifikasjon.klaresteLyshet(for: f3, blant: lysheter, i: gamut), metning: metning)),
        ]
        let valgt = (0..<max(antall, 1)).map { roller[$0 % roller.count] }

        return PalettForslag(
            tittel: grunnlag.erTomt ? String(localized: "Nøytral start", bundle: .module)
                : grunnlag.begreper.prefix(3).map { $0.visningsnavn.capitalized }.joined(separator: " · "),
            forklaring: grunnlag.erTomt
                ? String(localized: "Fant ingen kjente verdiord – her er et nøytralt utgangspunkt.", bundle: .module)
                : String(localized: "Bygget fra kunnskapsbasen: \(f1.navn) og \(f2.navn) med \(aksentfamilie.navn) som aksent.", bundle: .module),
            farger: valgt.map { rolle, spes in
                let spes = grunnlag.utenUønsketBrunt(spes, rolle: rolle, gamut: gamut)
                var forslag = Fargeforslag(navn: "", rolle: rolle, begrunnelse: "", farge: spes.farge(i: gamut), spesifikasjon: spes)
                forslag.navn = forslag.rollenavn
                return forslag
            },
            kilde: .leksikon,
            grunnlag: grunnlag.begreper.map(\.id)
        ).medRolleregler()
    }
}
