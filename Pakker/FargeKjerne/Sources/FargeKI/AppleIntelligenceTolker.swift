#if canImport(FoundationModels)
import FargeKjerne
import FoundationModels
import Foundation

/// Bruker Apples språkmodell på enheten (Foundation Models) med strukturert utdata.
/// Modellen svarer i OKLCH, som vi deretter gamut-kartlegger til Display P3.
public struct AppleIntelligenceTolker: VerdiordTolker {
    public init() {}

    public static var erTilgjengelig: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    @Generable
    struct GenerertPalett {
        @Guide(description: "Kort, stemningsfull tittel på norsk bokmål for paletten")
        var tittel: String
        @Guide(description: "Én til to setninger på norsk som forklarer hvordan fargene uttrykker verdiordene")
        var forklaring: String
        @Guide(description: "Fargene i paletten, fra dominerende til aksent")
        var farger: [GenerertFarge]
    }

    @Generable
    struct GenerertFarge {
        @Guide(description: "Beskrivende fargenavn på norsk, f.eks. «Fjordblå»")
        var navn: String
        @Guide(description: "Rolle i paletten: primær, sekundær, aksent, bakgrunn eller tekst")
        var rolle: String
        @Guide(description: "Kort begrunnelse knyttet til ett eller flere av verdiordene")
        var begrunnelse: String
        @Guide(description: "OKLCH-lyshet, 0 er sort og 1 er hvit", .range(0.0...1.0))
        var lyshet: Double
        @Guide(description: "OKLCH-kroma (fargemetning), 0 er grå og 0.37 er svært mettet", .range(0.0...0.37))
        var kroma: Double
        @Guide(description: "OKLCH-kulør i grader: 30 rød, 70 oransje, 100 gul, 145 grønn, 200 turkis, 260 blå, 310 fiolett, 350 rosa", .range(0.0...360.0))
        var kulør: Double
    }

    private static let instruksjoner = """
    Du er en erfaren fargedesigner og merkevarestrateg i Norden. Du oversetter verdiord \
    og stemninger til harmoniske fargepaletter for digital og trykt bruk. Ta hensyn til \
    fargepsykologi, kulturelle konnotasjoner i Norge, kontrast og lesbarhet. \
    Svar alltid på norsk bokmål.
    """

    public func forslag(for verdiord: String, antall: Int) async throws -> PalettForslag {
        let økt = LanguageModelSession(instructions: Self.instruksjoner)
        let svar = try await økt.respond(
            to: "Lag en palett med nøyaktig \(antall) farger for verdiordene: \(verdiord)",
            generating: GenerertPalett.self
        )
        let p = svar.content
        return PalettForslag(
            tittel: p.tittel,
            forklaring: p.forklaring,
            farger: p.farger.map {
                Fargeforslag(
                    navn: $0.navn, rolle: $0.rolle, begrunnelse: $0.begrunnelse,
                    farge: Farge(okLCH: OKLCH(l: $0.lyshet, c: $0.kroma, h: $0.kulør)).gamutKartlagt(til: .displayP3)
                )
            },
            kilde: .appleIntelligence
        )
    }
}
#endif
