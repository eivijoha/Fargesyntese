#if canImport(FoundationModels)
import FargeKjerne
import FoundationModels
import Foundation

/// Ett enkelt forslag uten samtale – brukes av App Intents og Snarveier.
/// For den interaktive flyten (strømming og justeringer), se ``PalettSamtale``.
public struct AppleIntelligenceTolker: VerdiordTolker {
    public init() {}

    public func forslag(for verdiord: String, antall: Int) async throws -> PalettForslag {
        let økt = LanguageModelSession(instructions: Instruksjoner.fargedesigner)
        let grunnlag = Fargesemantikk.oppslag(verdiord)
        do {
            let svar = try await økt.respond(
                to: Instruksjoner.forslag(verdiord: verdiord, antall: antall, grunnlag: grunnlag),
                generating: GenerertPalett.self,
                options: GenerationOptions(temperature: 0.7)
            )
            return svar.content.forslag(grunnlag: grunnlag, gamut: .displayP3)
        } catch {
            throw KIFeil.fra(error)
        }
    }
}
#endif
