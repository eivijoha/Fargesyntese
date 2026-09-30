import FargeKjerne
import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Faglig vurdering av en palett: harmoni, kontrast (WCAG) og bruk.
public struct PalettVurdering: Sendable, Hashable {
    public var oppsummering: String
    public var styrker: [String]
    public var svakheter: [String]
    public var forslag: [String]
    /// Deterministiske fakta som vurderingen bygger på (vises også i appen).
    public var fakta: [String]
    public var kilde: PalettForslag.Kilde
}

public enum Palettvurderer {
    /// Kontrastfakta og kulørfordeling beregnet presist – dette er grunnlaget modellen
    /// resonnerer over, så den ikke må regne selv.
    public static func fakta(for palett: Palett) -> [String] {
        let f = palett.farger
        var ut = f.map { "\($0.visningsnavn): \(Fargebeskrivelse.beskriv($0.farge)), \($0.farge.hex())" }

        var par: [(String, Kontrasttest)] = []
        for i in f.indices {
            for j in f.indices where j > i {
                let t = Kontrasttest(forgrunn: f[i].farge, bakgrunn: f[j].farge)
                par.append(("\(f[i].visningsnavn) mot \(f[j].visningsnavn)", t))
            }
        }
        let godkjente = par.filter { $0.1.består(.aaTekst) }
        ut.append("Fargepar som består WCAG AA for tekst (4,5:1): \(godkjente.count) av \(par.count)")
        ut += par.sorted { $0.1.forhold > $1.1.forhold }.prefix(8).map { "\($0.0): \($0.1.formatert) (\($0.1.sammendrag))" }

        let lysheter = f.map(\.farge.okLCH.l)
        if let min = lysheter.min(), let maks = lysheter.max() {
            ut.append(String(format: "Lyshetsspenn (OKLCH): %.2f–%.2f", min, maks))
        }
        let kromatiske = f.filter { $0.farge.okLCH.c >= 0.03 }
        ut.append("Kulører: " + (kromatiske.isEmpty ? "ingen (kun nøytrale)" :
            Set(kromatiske.map { Fargebeskrivelse.kulørnavn($0.farge.okLCH.h) }).sorted().joined(separator: ", ")))
        let utenforSRGB = f.filter { !$0.farge.erISRGB }
        if !utenforSRGB.isEmpty {
            ut.append("Utenfor sRGB (bare P3-skjermer viser riktig): " + utenforSRGB.map(\.visningsnavn).joined(separator: ", "))
        }
        return ut
    }

    public static func vurder(_ palett: Palett, bruk: String? = nil) async throws -> PalettVurdering {
        let fakta = fakta(for: palett)
        #if canImport(FoundationModels)
        if KIStatus.gjeldende.erKlar {
            let økt = LanguageModelSession(tools: [KontrastVerktøy(palett: palett)], instructions: """
            Du er en erfaren fargedesigner og tilgjengelighetsekspert. Du vurderer fargepaletter \
            ærlig og konkret: harmoni, stemning, hierarki, og lesbarhet etter WCAG 2.2 \
            (4,5:1 for vanlig tekst, 3:1 for stor tekst og grafikk, 7:1 for AAA). \
            Bruk faktaene du får – ikke regn ut kontrast selv. Trenger du kontrasten for et par \
            som ikke er oppgitt, bruk verktøyet «kontrast». Svar på norsk bokmål, kort og presist.
            """)
            do {
                let svar = try await økt.respond(
                    to: "Vurder paletten «\(palett.navn)»\(bruk.map { " til bruk i: \($0)" } ?? "").\n\nFakta:\n"
                        + fakta.map { "- \($0)" }.joined(separator: "\n"),
                    generating: GenerertVurdering.self,
                    options: GenerationOptions(temperature: 0.4)
                )
                let v = svar.content
                return PalettVurdering(oppsummering: v.oppsummering, styrker: v.styrker, svakheter: v.svakheter,
                                       forslag: v.forslag, fakta: fakta, kilde: .appleIntelligence)
            } catch {
                throw KIFeil.fra(error)
            }
        }
        #endif
        return regelbasert(palett, fakta: fakta)
    }

    /// Enkel vurdering uten språkmodell.
    static func regelbasert(_ palett: Palett, fakta: [String]) -> PalettVurdering {
        let f = palett.farger.map(\.farge)
        var styrker: [String] = [], svakheter: [String] = [], forslag: [String] = []
        let lys = f.map(\.okLCH.l)
        let spenn = (lys.max() ?? 0) - (lys.min() ?? 0)
        if spenn >= 0.5 { styrker.append("God spredning i lyshet gir tydelig hierarki.") }
        else { svakheter.append("Lite spenn i lyshet gjør det vanskelig å skape kontrast."); forslag.append("Legg til en tydelig lys og en tydelig mørk farge.") }
        let bestePar = f.indices.flatMap { i in f.indices.filter { $0 > i }.map { Kontrasttest(forgrunn: f[i], bakgrunn: f[$0]) } }
        if bestePar.contains(where: { $0.består(.aaTekst) }) { styrker.append("Minst ett fargepar kan brukes til brødtekst (WCAG AA).") }
        else { svakheter.append("Ingen fargepar når 4,5:1 – paletten egner seg ikke til tekst alene."); forslag.append("Bruk «Mer kontrast» eller legg til sort/hvit tekstfarge.") }
        if f.contains(where: { !$0.erISRGB }) { forslag.append("Noen farger er utenfor sRGB; kontroller dem på en vanlig skjerm og i trykk.") }
        return PalettVurdering(oppsummering: "Regelbasert vurdering (Apple Intelligence er ikke tilgjengelig).",
                               styrker: styrker, svakheter: svakheter, forslag: forslag, fakta: fakta, kilde: .leksikon)
    }
}

#if canImport(FoundationModels)
@Generable
struct GenerertVurdering {
    @Guide(description: "Helhetsvurdering i to–tre setninger")
    var oppsummering: String
    @Guide(description: "Konkrete styrker ved paletten", .maximumCount(4))
    var styrker: [String]
    @Guide(description: "Konkrete svakheter, særlig kontrast og lesbarhet", .maximumCount(4))
    var svakheter: [String]
    @Guide(description: "Konkrete forbedringsforslag, gjerne med fargenavn og retning (lysere, mørkere, varmere …)", .maximumCount(4))
    var forslag: [String]
}

/// Lar modellen slå opp WCAG-kontrasten mellom to farger i paletten (eller hex-verdier).
struct KontrastVerktøy: Tool {
    let palett: Palett
    let name = "kontrast"
    let description = "Regner ut WCAG-kontrastforholdet mellom to farger, angitt med navn fra paletten eller som hex (#RRGGBB)."

    @Generable
    struct Arguments {
        @Guide(description: "Forgrunnsfarge: navn fra paletten eller hex")
        var forgrunn: String
        @Guide(description: "Bakgrunnsfarge: navn fra paletten eller hex")
        var bakgrunn: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let fg = finn(arguments.forgrunn), let bg = finn(arguments.bakgrunn) else {
            return "Fant ikke fargen. Bruk et navn fra paletten eller hex."
        }
        let t = Kontrasttest(forgrunn: fg, bakgrunn: bg)
        let krav = WCAGKrav.allCases.map { "\($0.navn): \(t.består($0) ? "bestått" : "ikke bestått")" }
        return "Kontrast \(t.formatert). " + krav.joined(separator: ", ")
    }

    private func finn(_ tekst: String) -> Farge? {
        let t = tekst.trimmingCharacters(in: .whitespaces)
        return palett.farger.first { $0.visningsnavn.localizedCaseInsensitiveCompare(t) == .orderedSame }?.farge
            ?? Fargetolk.tolk(t)
    }
}
#endif
