import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Om Apple Intelligence (Foundation Models) kan brukes nå, med norsk forklaring til brukeren.
public enum KIStatus: Sendable, Equatable {
    case klar
    case enhetStøttesIkke
    case ikkeSlåttPå
    case modellenLastes
    case språkStøttesIkke
    case utilgjengelig(String)

    public static var gjeldende: KIStatus {
        #if canImport(FoundationModels)
        let modell = SystemLanguageModel.default
        switch modell.availability {
        case .available:
            return modell.supportsLocale(Locale(identifier: "nb_NO")) ? .klar : .språkStøttesIkke
        case .unavailable(.deviceNotEligible): return .enhetStøttesIkke
        case .unavailable(.appleIntelligenceNotEnabled): return .ikkeSlåttPå
        case .unavailable(.modelNotReady): return .modellenLastes
        case .unavailable(let årsak): return .utilgjengelig(String(describing: årsak))
        }
        #else
        return .enhetStøttesIkke
        #endif
    }

    public var erKlar: Bool { self == .klar }

    public var forklaring: String {
        switch self {
        case .klar: "Apple Intelligence er klar. Alt skjer på enheten."
        case .enhetStøttesIkke: "Denne enheten støtter ikke Apple Intelligence. Fargesyntese bruker det innebygde leksikonet i stedet."
        case .ikkeSlåttPå: "Slå på Apple Intelligence i Innstillinger for å få KI-forslag. Inntil da brukes det innebygde leksikonet."
        case .modellenLastes: "Språkmodellen lastes ned eller gjøres klar. Prøv igjen om litt – leksikonet brukes så lenge."
        case .språkStøttesIkke: "Apple Intelligence støtter ikke norsk på denne enheten ennå. Leksikonet brukes i stedet."
        case .utilgjengelig(let årsak): "Apple Intelligence er ikke tilgjengelig (\(årsak)). Leksikonet brukes i stedet."
        }
    }
}

/// Feil fra språkmodellen, oversatt til noe brukeren kan handle på.
public enum KIFeil: LocalizedError, Sendable {
    case ikkeTilgjengelig(KIStatus)
    case avvist
    case forLangSamtale
    case opptatt
    case reserveBrukt(String)
    case annet(String)

    public var errorDescription: String? {
        switch self {
        case .ikkeTilgjengelig(let status): status.forklaring
        case .avvist: "Modellen ville ikke svare på denne forespørselen. Prøv å formulere den annerledes."
        case .forLangSamtale: "Samtalen ble for lang for modellen. Start et nytt forslag."
        case .opptatt: "Modellen er opptatt med en annen forespørsel. Prøv igjen om et øyeblikk."
        case .reserveBrukt(let årsak): "Apple Intelligence svarte ikke (\(årsak)). Forslaget under er fra det innebygde leksikonet."
        case .annet(let tekst): tekst
        }
    }

    static func fra(_ feil: any Error) -> KIFeil {
        if let feil = feil as? KIFeil { return feil }
        #if canImport(FoundationModels)
        if let g = feil as? LanguageModelSession.GenerationError {
            switch g {
            case .guardrailViolation, .refusal: return .avvist
            case .exceededContextWindowSize: return .forLangSamtale
            case .concurrentRequests, .rateLimited: return .opptatt
            case .unsupportedLanguageOrLocale: return .ikkeTilgjengelig(.språkStøttesIkke)
            case .assetsUnavailable: return .ikkeTilgjengelig(.modellenLastes)
            default:
                let beskrivelse = g.errorDescription ?? g.failureReason ?? "ukjent modellfeil"
                return .annet("Språkmodellen feilet: \(beskrivelse)")
            }
        }
        #endif
        return .annet(feil.localizedDescription)
    }
}
