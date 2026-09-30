import FargeKjerne
import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Én farge ut fra en beskrivelse, f.eks. «dyp havblå», «støvete rosa» eller «klar løvgrønn».
public struct BeskrevetFarge: Sendable, Hashable {
    public var farge: Farge
    public var navn: String
    public var spesifikasjon: Fargespesifikasjon
    public var kilde: PalettForslag.Kilde
    /// Begrepene i kunnskapsbasen beskrivelsen traff.
    public var grunnlag: [String]
}

/// Oversetter en fritekstbeskrivelse til én farge via fargespråket. Fargen regnes ut i OKLCH.
/// Apple Intelligence tolker nyanser når den er tilgjengelig; ellers brukes kunnskapsbasen og
/// faste modifikatorord (lys, mørk, dyp, pastell, dempet, klar …).
public enum Fargebeskriver {
    public static func farge(fra beskrivelse: String, gamut: Gamut = .displayP3) async -> BeskrevetFarge {
        #if canImport(FoundationModels)
        if KIStatus.gjeldende.erKlar {
            // Ved enhver modellfeil (også avvisning fra sikkerhetsfilteret) gir regelbasert tolkning
            // likevel en farge – brukeren ba bare om én farge.
            if let farge = try? await medSpråkmodell(beskrivelse, gamut: gamut) { return farge }
        }
        #endif
        return regelbasert(beskrivelse, gamut: gamut)
    }

    // MARK: Regelbasert

    static let lyshetsord: [(String, Lyshetsnivå)] = [
        ("nesten sort", .nestenSort), ("nesten svart", .nestenSort), ("almost black", .nestenSort),
        ("nesten hvit", .nestenHvit), ("almost white", .nestenHvit), ("off-white", .nestenHvit),
        ("svært mørk", .sværtMørk), ("veldig mørk", .sværtMørk), ("very dark", .sværtMørk),
        ("svært lys", .sværtLys), ("veldig lys", .sværtLys), ("very light", .sværtLys),
        ("dyp", .mørk), ("dypt", .mørk), ("deep", .mørk), ("mørk", .mørk), ("mørke", .mørk), ("dark", .mørk),
        ("pastell", .sværtLys), ("pastel", .sværtLys), ("blek", .sværtLys), ("pale", .sværtLys),
        ("lys", .lys), ("lyse", .lys), ("light", .lys), ("middels", .middels), ("medium", .middels),
    ]
    static let metningsord: [(String, Metningsnivå)] = [
        ("neon", .maksimal), ("selvlysende", .maksimal), ("fluorescent", .maksimal),
        ("intens", .sterk), ("sterk", .sterk), ("mettet", .sterk), ("vivid", .sterk), ("intense", .sterk), ("saturated", .sterk),
        ("klar", .klar), ("frisk", .klar), ("bright", .klar), ("clear", .klar),
        ("støvete", .dempet), ("dempet", .dempet), ("dus", .dempet), ("matt", .dempet), ("dusty", .dempet), ("muted", .dempet), ("soft", .moderat),
        ("gråaktig", .svak), ("grålig", .svak), ("greyish", .svak), ("grayish", .svak),
    ]

    /// Eksplisitte modifikatorord i beskrivelsen. Disse følges alltid, også når språkmodellen
    /// har valgt noe annet («pastell» er svært lys, «neon» er maksimal metning).
    struct Modifikatorer {
        var lyshet: Lyshetsnivå?
        var metning: Metningsnivå?
        var maksMetning: Metningsnivå?
        var justering: Double?
    }

    static func modifikatorer(i beskrivelse: String) -> Modifikatorer {
        let tekst = " " + beskrivelse.lowercased().map { $0.isLetter || $0 == "-" ? $0 : " " }.reduce(into: "") { $0.append($1) } + " "
        func finn<T>(_ liste: [(String, T)]) -> T? { liste.first { tekst.contains(" \($0.0) ") || tekst.contains(" \($0.0)") && $0.0.count >= 5 }?.1 }
        var m = Modifikatorer(lyshet: finn(lyshetsord), metning: finn(metningsord))
        if tekst.contains(" pastell") || tekst.contains(" pastel") { m.maksMetning = .moderat }
        // «Varm» og «kald» vrir kuløren litt mot rødt eller blått.
        if tekst.contains(" varm ") || tekst.contains(" warm ") { m.justering = -8 }
        if tekst.contains(" kald ") || tekst.contains(" kjølig ") || tekst.contains(" cool ") || tekst.contains(" cold ") { m.justering = 8 }
        return m
    }

    static func bruk(_ m: Modifikatorer, på spes: Fargespesifikasjon) -> Fargespesifikasjon {
        var s = spes
        if let l = m.lyshet { s.lyshet = l }
        if let mt = m.metning, s.familie != .nøytral { s.metning = mt }
        if let maks = m.maksMetning { s.metning = min(s.metning, maks) }
        // «Neon», «intens» uten lyshetsord: velg nabolysheten der familien er klarest (neon oransje blir ellers brunlig).
        if m.lyshet == nil, let mt = m.metning, mt >= .sterk {
            let alle = Lyshetsnivå.allCases
            let i = alle.firstIndex(of: s.lyshet)!
            let naboer = alle[max(0, i - 1)...min(alle.count - 1, i + 1)]
            s.lyshet = Fargespesifikasjon.klaresteLyshet(for: s.familie, blant: Array(naboer))
        }
        if let j = m.justering, s.justering == 0 { s.justering = j }
        return s
    }

    static func regelbasert(_ beskrivelse: String, gamut: Gamut) -> BeskrevetFarge {
        let grunnlag = Fargesemantikk.oppslag(beskrivelse)
        let hoved = grunnlag.begreper.first
        let familie = grunnlag.familievekter.first(where: { $0.0 != .nøytral })?.0
            ?? (grunnlag.familievekter.first?.0 ?? .nøytral)
        let m = modifikatorer(i: beskrivelse)
        let metning = m.metning ?? hoved?.metning.first ?? .klar
        let lyshet = m.lyshet
            ?? (m.maksMetning != nil ? .sværtLys : Fargespesifikasjon.klaresteLyshet(for: familie, blant: hoved?.lyshet ?? [.middelsMørk, .middels, .lys], i: gamut))
        let spes = bruk(m, på: Fargespesifikasjon(familie: familie, lyshet: lyshet, metning: familie == .nøytral ? .grå : metning))
        let navn = beskrivelse.trimmingCharacters(in: .whitespacesAndNewlines)
        return BeskrevetFarge(farge: spes.farge(i: gamut), navn: navn.prefix(1).uppercased() + navn.dropFirst(),
                              spesifikasjon: spes, kilde: .leksikon, grunnlag: grunnlag.begreper.map(\.id))
    }

    // MARK: Språkmodell

    #if canImport(FoundationModels)
    static func medSpråkmodell(_ beskrivelse: String, gamut: Gamut) async throws -> BeskrevetFarge {
        let grunnlag = Fargesemantikk.oppslag(beskrivelse)
        let økt = LanguageModelSession(instructions: Instruksjoner.fargedesigner)
        let svar = try await økt.respond(
            to: """
            Beskrivelse av én farge: \(beskrivelse)

            \(grunnlag.fakta)

            Velg den ene fargen som best treffer beskrivelsen. Ord som lys, mørk, dyp, pastell, dempet, \
            klar og neon skal styre lyshet og metning direkte.
            """,
            generating: GenerertEnkeltfarge.self,
            options: GenerationOptions(temperature: 0.3)
        )
        let g = svar.content
        guard let familie = Kulørfamilie(rawValue: g.familie), let lyshet = Lyshetsnivå(rawValue: g.lyshet),
              let metning = Metningsnivå(rawValue: g.metning)
        else { return regelbasert(beskrivelse, gamut: gamut) }
        var m = modifikatorer(i: beskrivelse)
        if m.maksMetning != nil, m.lyshet == nil { m.lyshet = .sværtLys }
        let spes = bruk(m, på: Fargespesifikasjon(familie: familie, lyshet: lyshet, metning: metning, justering: Double(g.justering)))
        return BeskrevetFarge(farge: spes.farge(i: gamut), navn: g.navn, spesifikasjon: spes, kilde: .appleIntelligence,
                              grunnlag: grunnlag.begreper.map(\.id))
    }
    #endif
}

#if canImport(FoundationModels)
@Generable
struct GenerertEnkeltfarge {
    @Guide(description: "Kulørfamilie", .anyOf(Kulørfamilie.allCases.map(\.rawValue)))
    var familie: String
    @Guide(description: "Lyshet", .anyOf(Lyshetsnivå.allCases.map(\.rawValue)))
    var lyshet: String
    @Guide(description: "Metning, relativt til hva fargen kan få", .anyOf(Metningsnivå.allCases.map(\.rawValue)))
    var metning: String
    @Guide(description: "Finjustering av kuløren i grader innen familien; 0 hvis familien treffer", .range(-15...15))
    var justering: Int
    @Guide(description: "Kort fargenavn på svarspråket, f.eks. «Havblå» eller «Støvete rosa»")
    var navn: String
}
#endif
