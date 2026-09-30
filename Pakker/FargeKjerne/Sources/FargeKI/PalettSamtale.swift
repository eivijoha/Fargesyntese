import FargeKjerne
import Foundation
import Observation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Interaktiv palettbygging med språkmodellen på enheten.
///
/// - Forslag og justeringer strømmes: `forslag` oppdateres fortløpende mens modellen skriver,
///   så fargene dukker opp én etter én.
/// - Samtalen husker tidligere runder, slik at «litt mer dempet» forstås i sammenheng.
/// - Hurtigjusteringer (``Justering``) gjøres deterministisk i OKLCH og virker uten KI.
/// - Uten Apple Intelligence brukes ``LeksikonTolker`` for første forslag.
@MainActor
@Observable
public final class PalettSamtale {
    public private(set) var forslag: PalettForslag?
    public private(set) var arbeider = false
    public private(set) var feil: KIFeil?
    /// Brukerens instrukser så langt, i rekkefølge (vises som samtalelogg).
    public private(set) var logg: [String] = []
    public private(set) var status: KIStatus = .gjeldende
    /// Gamut fargene holdes innenfor (sRGB når appen er begrenset til det).
    public var gamut: Gamut = .displayP3 {
        didSet { if let f = forslag { forslag = f.begrenset(til: gamut) } }
    }

    #if canImport(FoundationModels)
    @ObservationIgnored private var økt: LanguageModelSession?
    #endif
    @ObservationIgnored private var oppgave: Task<Void, Never>?

    public init() {}

    public var kanJustereMedKI: Bool { status.erKlar && forslag != nil }

    /// Laster modellen i forkant, så første svar kommer raskere. Kall når skjermen vises.
    public func forvarm() {
        status = .gjeldende
        #if canImport(FoundationModels)
        guard status.erKlar else { return }
        if økt == nil { økt = Self.nyØkt() }
        økt?.prewarm()
        #endif
    }

    public func foreslå(verdiord: String, antall: Int) {
        logg = [verdiord]
        kjør {
            #if canImport(FoundationModels)
            if self.status.erKlar {
                self.økt = Self.nyØkt()
                do {
                    try await self.strøm(Instruksjoner.forslag(verdiord: verdiord, antall: antall))
                    return
                } catch let feil where !(feil is CancellationError) && !KIFeil.fra(feil).erBrukerrettet {
                    // Uventet modellfeil (f.eks. manglende modellressurser): vis leksikonforslag
                    // i stedet for bare en feilmelding, og si ifra.
                    self.forslag = try await LeksikonTolker().forslag(for: verdiord, antall: antall).begrenset(til: self.gamut).begrenset(til: self.gamut)
                    self.feil = .reserveBrukt(KIFeil.fra(feil).localizedDescription)
                    return
                }
            }
            #endif
            self.forslag = try await LeksikonTolker().forslag(for: verdiord, antall: antall).begrenset(til: self.gamut)
        }
    }

    /// Fritekst-justering via språkmodellen, f.eks. «mer som en skandinavisk kafé».
    public func juster(_ instruks: String) {
        guard let nå = forslag else { return }
        logg.append(instruks)
        kjør {
            #if canImport(FoundationModels)
            guard self.status.erKlar else { throw KIFeil.ikkeTilgjengelig(self.status) }
            let prompt = Instruksjoner.justering(instruks, av: nå.farger)
            do {
                try await self.strøm(prompt)
            } catch let feil where KIFeil.fra(feil).erForLang {
                // Start en ny økt med gjeldende palett som kontekst og prøv én gang til.
                self.økt = Self.nyØkt()
                try await self.strøm(prompt)
            }
            #else
            throw KIFeil.ikkeTilgjengelig(self.status)
            #endif
        }
    }

    /// Presis justering i OKLCH, uten språkmodell.
    public func bruk(_ justering: Justering) {
        guard var f = forslag else { return }
        let nye = justering.bruk(på: f.farger.map(\.farge), gamut: gamut)
        for i in f.farger.indices { f.farger[i].farge = nye[i] }
        forslag = f.medRolleregler().begrenset(til: gamut)
        logg.append(justering.navn)
    }

    public func avbryt() {
        oppgave?.cancel()
        arbeider = false
    }

    // MARK: - Intern

    private func kjør(_ arbeid: @escaping @MainActor () async throws -> Void) {
        oppgave?.cancel()
        feil = nil
        arbeider = true
        oppgave = Task {
            defer { self.arbeider = false }
            do {
                try await arbeid()
            } catch is CancellationError {
            } catch {
                if self.feil == nil { self.feil = KIFeil.fra(error) }
            }
        }
    }

    #if canImport(FoundationModels)
    private static func nyØkt() -> LanguageModelSession {
        LanguageModelSession(instructions: Instruksjoner.fargedesigner)
    }

    private func strøm(_ prompt: String) async throws {
        guard let økt else { return }
        let strøm = økt.streamResponse(to: prompt, generating: GenerertPalett.self, options: GenerationOptions(temperature: 0.8))
        var siste: GenerertPalett.PartiallyGenerated?
        for try await øyeblikk in strøm {
            try Task.checkCancellation()
            siste = øyeblikk.content
            let delvis = øyeblikk.content.forslag.begrenset(til: gamut)
            // Behold forrige forslag på skjermen til de første nye fargene er klare.
            if !delvis.farger.isEmpty || forslag == nil { forslag = delvis }
        }
        // Siste øyeblikksbilde er det komplette svaret; rollereglene brukes først nå.
        if let siste { forslag = siste.forslag.medRolleregler().begrenset(til: gamut) }
    }
    #endif
}

extension KIFeil {
    var erForLang: Bool { if case .forLangSamtale = self { true } else { false } }

    /// Feil som skyldes forespørselen selv, og som brukeren bør se i stedet for et reserveforslag.
    var erBrukerrettet: Bool {
        switch self {
        case .avvist, .opptatt: true
        default: false
        }
    }
}
