#if canImport(FoundationModels)
import FargeKjerne
import FoundationModels
import Foundation

/// Ett enkelt forslag uten samtale – brukes av App Intents og Snarveier.
/// For den interaktive flyten (oppskrift som kan endres, og justeringer), se ``PalettSamtale``.
public struct AppleIntelligenceTolker: VerdiordTolker {
    public init() {}

    public func forslag(for verdiord: String, antall: Int) async throws -> PalettForslag {
        let grunnlag = Fargesemantikk.oppslag(verdiord)
        var forslag = try await Self.tolk(verdiord, grunnlag: grunnlag, gamut: .displayP3)
            .forslag(antall: antall, grunnlag: grunnlag)
        if let navn = try? await Fargenavngiver.navngi(forslag.farger.map(\.farge), tema: verdiord) {
            for (i, n) in navn.enumerated() where i < forslag.farger.count { forslag.farger[i].navn = n }
        }
        return forslag
    }

    /// Språkmodellen veier verdiordene og velger retning; fargene regnes ut av ``Palettkomponist``.
    static func tolk(_ verdiord: String, grunnlag: Begrepsgrunnlag, gamut: Gamut) async throws -> Palettolkning {
        let økt = LanguageModelSession(instructions: Instruksjoner.tolk)
        do {
            let svar = try await økt.respond(
                to: Instruksjoner.tolk(verdiord: verdiord, grunnlag: grunnlag),
                generating: GenerertTolkning.self,
                options: GenerationOptions(temperature: 0.7)
            )
            return svar.content.tolkning(grunnlag: grunnlag, gamut: gamut)
        } catch {
            throw KIFeil.fra(error)
        }
    }
}
#endif
