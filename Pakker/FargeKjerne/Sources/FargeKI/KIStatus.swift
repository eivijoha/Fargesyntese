import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Språket appen vises på (norsk eller engelsk), som også styrer språket i KI-svarene.
public enum Språk {
    public static var erNorsk: Bool {
        let språk = Bundle.main.preferredLocalizations.first ?? Locale.current.language.languageCode?.identifier ?? "nb"
        return ["nb", "no", "nn"].contains(where: { språk.hasPrefix($0) })
    }

    static var lokale: Locale { erNorsk ? Locale(identifier: "nb_NO") : Locale(identifier: "en_US") }

    /// Linje som legges til i KI-instruksjonene.
    static var svarinstruks: String { erNorsk ? "Svar alltid på norsk bokmål." : "Always answer in English." }
}

/// Om Apple Intelligence (Foundation Models) kan brukes nå, med forklaring til brukeren.
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
            return modell.supportsLocale(Språk.lokale) ? .klar : .språkStøttesIkke
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
        case .klar: String(localized: "Apple Intelligence er klar. Alt skjer på enheten.", bundle: .module)
        case .enhetStøttesIkke: String(localized: "Denne enheten støtter ikke Apple Intelligence. Fargesyntese bruker det innebygde leksikonet i stedet.", bundle: .module)
        case .ikkeSlåttPå: String(localized: "Slå på Apple Intelligence i Innstillinger for å få KI-forslag. Inntil da brukes det innebygde leksikonet.", bundle: .module)
        case .modellenLastes: String(localized: "Språkmodellen lastes ned eller gjøres klar. Prøv igjen om litt – leksikonet brukes så lenge.", bundle: .module)
        case .språkStøttesIkke: String(localized: "Apple Intelligence støtter ikke språket ditt på denne enheten ennå. Leksikonet brukes i stedet.", bundle: .module)
        case .utilgjengelig(let årsak): String(localized: "Apple Intelligence er ikke tilgjengelig (\(årsak)). Leksikonet brukes i stedet.", bundle: .module)
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
        case .avvist: String(localized: "Modellen ville ikke svare på denne forespørselen. Prøv å formulere den annerledes.", bundle: .module)
        case .forLangSamtale: String(localized: "Samtalen ble for lang for modellen. Start et nytt forslag.", bundle: .module)
        case .opptatt: String(localized: "Modellen er opptatt med en annen forespørsel. Prøv igjen om et øyeblikk.", bundle: .module)
        case .reserveBrukt(let årsak): String(localized: "Apple Intelligence svarte ikke (\(årsak)). Forslaget under er fra det innebygde leksikonet.", bundle: .module)
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
                return .annet(String(localized: "Språkmodellen feilet: \(beskrivelse)", bundle: .module))
            }
        }
        #endif
        return .annet(feil.localizedDescription)
    }
}
