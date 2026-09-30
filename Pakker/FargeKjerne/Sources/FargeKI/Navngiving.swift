import FargeKjerne
import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Gir fargene i en palett beskrivende norske navn.
///
/// Modellen får en deterministisk beskrivelse av hver farge («lys dempet blågrønn») i tillegg
/// til tallene, fordi en liten modell treffer mye bedre på ord enn på OKLCH-verdier.
/// Uten Apple Intelligence brukes beskrivelsen selv, med stor forbokstav.
public enum Fargenavngiver {
    public static func navngi(_ farger: [Farge], tema: String? = nil) async throws -> [String] {
        let reserve = farger.map { Fargebeskrivelse.beskriv($0).prefix(1).uppercased() + Fargebeskrivelse.beskriv($0).dropFirst() }
        #if canImport(FoundationModels)
        guard KIStatus.gjeldende.erKlar, !farger.isEmpty else { return reserve }
        let liste = farger.enumerated().map { i, f in
            "\(i + 1). \(Fargebeskrivelse.beskriv(f)) (\(f.hex()), \(Fargemodell.okLCH.tekst(for: f)))"
        }.joined(separator: "\n")
        let økt = LanguageModelSession(instructions: """
        Du navngir farger for designere. Navnene skal være korte (ett eller to ord), norske, \
        stemningsfulle og treffende for fargen, gjerne med natur- eller stedsassosiasjoner \
        (f.eks. «Fjordblå», «Lyng», «Havre», «Nordlys»). Hvert navn skal være unikt i paletten. \
        Svar på norsk bokmål.
        """)
        do {
            let svar = try await økt.respond(
                to: "Gi hver av disse \(farger.count) fargene et navn, i samme rekkefølge\(tema.map { ". Tema: \($0)" } ?? ""):\n\(liste)",
                generating: Navneliste.self,
                options: GenerationOptions(temperature: 0.6)
            )
            let navn = svar.content.navn
            // Fyll inn med beskrivelsen hvis modellen ga for få navn.
            return farger.indices.map { i in i < navn.count && !navn[i].isEmpty ? navn[i] : reserve[i] }
        } catch {
            throw KIFeil.fra(error)
        }
        #else
        return reserve
        #endif
    }
}

#if canImport(FoundationModels)
@Generable
struct Navneliste {
    @Guide(description: "Ett navn per farge, i samme rekkefølge som fargene ble gitt")
    var navn: [String]
}
#endif
