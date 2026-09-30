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
        do {
            let svar = try await økt.respond(
                to: Instruksjoner.forslag(verdiord: verdiord, antall: antall),
                generating: GenerertPalett.self,
                options: GenerationOptions(temperature: 0.8)
            )
            return svar.content.forslag
        } catch {
            throw KIFeil.fra(error)
        }
    }
}
#endif
