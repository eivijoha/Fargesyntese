#if canImport(FoundationModels)
import FargeKjerne
import FoundationModels
import Foundation

// Strukturert utdata for språkmodellen. Modellen svarer i OKLCH fordi det er det
// mest forutsigbare rommet å resonnere i (lyshet, metning og kulør er uavhengige).

@Generable
struct GenerertPalett {
    @Guide(description: "Kort, stemningsfull tittel på norsk bokmål, 1–4 ord")
    var tittel: String
    @Guide(description: "Én setning på norsk som forklarer hvordan fargene uttrykker verdiordene")
    var forklaring: String
    @Guide(description: "Fargene i paletten, fra dominerende til aksent", .maximumCount(10))
    var farger: [GenerertFarge]
}

/// Feltrekkefølgen er bevisst: modellen genererer i denne rekkefølgen, og treffer bedre
/// på tallene når den først har bestemt rolle og beskrevet fargen med ord.
@Generable
struct GenerertFarge {
    @Guide(description: "Rolle i paletten", .anyOf(["primær", "sekundær", "aksent", "bakgrunn", "tekst", "støtte"]))
    var rolle: String
    @Guide(description: "Fargen beskrevet med ord: lyshet, metning og kulør, f.eks. «mørk dempet skogsgrønn» eller «nesten hvit, varm»")
    var beskrivelse: String
    @Guide(description: "OKLCH-lyshet, 0 er sort og 1 er hvit", .range(0.0...1.0))
    var lyshet: Double
    @Guide(description: "OKLCH-kroma: 0 er grå, 0.05 dempet, 0.12 klar, 0.2 svært mettet", .range(0.0...0.25))
    var kroma: Double
    @Guide(description: "OKLCH-kulør i grader, se kulørkartet", .range(0.0...360.0))
    var kulør: Double
    @Guide(description: "Kort norsk fargenavn, gjerne med natur- eller stedsassosiasjon, f.eks. «Fjordblå» eller «Lyng»")
    var navn: String
    @Guide(description: "Begrunnelse på høyst 12 ord, knyttet til verdiordene")
    var begrunnelse: String
}

enum Instruksjoner {
    static let fargedesigner = """
    Du er en erfaren fargedesigner og merkevarestrateg i Norden. Du oversetter verdiord \
    og stemninger til harmoniske fargepaletter for digital og trykt bruk, og tar hensyn til \
    fargepsykologi, norske kulturelle konnotasjoner, kontrast og lesbarhet.

    Farger angis i OKLCH: lyshet 0–1, kroma 0–0.37, kulør i grader.
    Kulørkart: 25 rød, 55 oransje, 90 gul, 130 lysegrønn, 150 grønn, 190 turkis, \
    240 blå, 265 indigo, 300 fiolett, 340 rosa.
    Jordfarger og brunt: kulør 40–80, lyshet 0.35–0.55, kroma 0.04–0.10. \
    Pastell: lyshet over 0.85, kroma under 0.08. Dempede, nordiske toner: kroma 0.02–0.07.
    En god palett har tydelig variasjon i lyshet. Bakgrunn: nesten hvit (lyshet 0.95–0.99, kroma under 0.02) \
    eller, for mørke uttrykk, nesten sort (lyshet under 0.22). Tekst skal kontrastere sterkt mot bakgrunnen.
    Svar alltid på norsk bokmål.
    """

    static func forslag(verdiord: String, antall: Int) -> String {
        """
        Verdiord: \(verdiord)
        Lag en palett med nøyaktig \(antall) farger. Bruk rollene primær, sekundær, aksent, \
        bakgrunn og tekst; ved flere enn fem farger kan du legge til støtte-farger.
        """
    }

    static func justering(_ instruks: String, av palett: [Fargeforslag]) -> String {
        """
        Nåværende palett:
        \(beskrivelse(palett))

        Juster paletten slik: \(instruks)
        Behold antall farger og roller med mindre justeringen ber om noe annet. \
        Oppdater tittel og forklaring hvis stemningen endrer seg.
        """
    }

    static func beskrivelse(_ palett: [Fargeforslag]) -> String {
        palett.map { f in
            "- \(f.navn) (\(f.rolle)): \(Fargemodell.okLCH.tekst(for: f.farge)), \(Fargebeskrivelse.beskriv(f.farge))"
        }.joined(separator: "\n")
    }
}

extension GenerertFarge {
    var fargeforslag: Fargeforslag {
        Fargeforslag(navn: navn, rolle: rolle, begrunnelse: begrunnelse,
                     farge: Farge(okLCH: OKLCH(l: lyshet, c: kroma, h: kulør)).gamutKartlagt(til: .displayP3))
    }
}

extension GenerertFarge.PartiallyGenerated {
    /// Fargen så snart alle tre tallene er strømmet inn.
    var fargeforslag: Fargeforslag? {
        guard let lyshet, let kroma, let kulør else { return nil }
        return Fargeforslag(navn: navn ?? "", rolle: rolle ?? "", begrunnelse: begrunnelse ?? "",
                            farge: Farge(okLCH: OKLCH(l: lyshet, c: kroma, h: kulør)).gamutKartlagt(til: .displayP3))
    }
}

extension GenerertPalett {
    var forslag: PalettForslag {
        PalettForslag(tittel: tittel, forklaring: forklaring, farger: farger.map(\.fargeforslag), kilde: .appleIntelligence)
            .medRolleregler()
    }
}

extension GenerertPalett.PartiallyGenerated {
    var forslag: PalettForslag {
        PalettForslag(tittel: tittel ?? "", forklaring: forklaring ?? "",
                      farger: (farger ?? []).compactMap(\.fargeforslag), kilde: .appleIntelligence)
    }
}
#endif
