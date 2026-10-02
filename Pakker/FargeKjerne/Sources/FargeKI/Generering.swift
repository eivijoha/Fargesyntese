#if canImport(FoundationModels)
import FargeKjerne
import FoundationModels
import Foundation

// Strukturert utdata for språkmodellen. Modellen velger i et kategorisk fargespråk
// (kulørfamilie, lyshetsnivå, metningsnivå) i stedet for å skrive OKLCH-tall: små modeller
// treffer dårlig på tall, og en «dyp grønn» ble ofte brun. Fargen regnes ut deterministisk.

@Generable
struct GenerertPalett {
    @Guide(description: "Kort, stemningsfull tittel på svarspråket, 1–4 ord")
    var tittel: String
    @Guide(description: "Én setning på svarspråket som forklarer hvordan fargene uttrykker verdiordene")
    var forklaring: String
    @Guide(description: "Fargene i paletten, fra dominerende til aksent", .maximumCount(10))
    var farger: [GenerertFarge]
}

/// Feltrekkefølgen er bevisst: modellen bestemmer rolle og beskriver fargen med ord før den
/// velger kategoriene, og kategoriene følger da beskrivelsen.
@Generable
struct GenerertFarge {
    @Guide(description: "Rolle i paletten", .anyOf(["primær", "sekundær", "aksent", "bakgrunn", "tekst", "støtte"]))
    var rolle: String
    @Guide(description: "Fargen beskrevet med ord, f.eks. «klar løvgrønn» eller «dyp havblå»")
    var beskrivelse: String
    @Guide(description: "Kulørfamilie", .anyOf(Kulørfamilie.allCases.map(\.rawValue)))
    var familie: String
    @Guide(description: "Lyshet", .anyOf(Lyshetsnivå.allCases.map(\.rawValue)))
    var lyshet: String
    @Guide(description: "Metning, relativt til hva fargen kan få", .anyOf(Metningsnivå.allCases.map(\.rawValue)))
    var metning: String
    @Guide(description: "Finjustering av kuløren i grader innen familien; 0 hvis familien treffer", .range(-15...15))
    var justering: Int
    @Guide(description: "Kort fargenavn på svarspråket, gjerne med natur- eller stedsassosiasjon, f.eks. «Fjordblå» eller «Lyng»")
    var navn: String
    @Guide(description: "Begrunnelse på høyst 12 ord, knyttet til verdiordene eller begrepsgrunnlaget")
    var begrunnelse: String
}

/// Språkmodellens tolkning av verdiordene. Modellen velger bare retning – kulører og uttrykk –
/// og paletten komponeres etterpå av ``Palettkomponist``.
@Generable
struct GenerertTolkning {
    @Guide(description: "Kort, stemningsfull tittel på svarspråket, 1–4 ord")
    var tittel: String
    @Guide(description: "Én setning på svarspråket om hvilket fargeuttrykk verdiordene peker mot, og hvorfor")
    var forklaring: String
    @Guide(description: "Kulørfamilien som best uttrykker det viktigste verdiordet", .anyOf(Kulørfamilie.kromatiske.map(\.rawValue)))
    var primær: String
    @Guide(description: "Kulørfamilien for det nest viktigste verdiordet – en annen enn primær", .anyOf(Kulørfamilie.kromatiske.map(\.rawValue)))
    var sekundær: String
    @Guide(description: "Uttrykkets lyshet", .anyOf(["mørk", "middels", "lys"]))
    var lyshet: String
    @Guide(description: "Uttrykkets metning", .anyOf(["dempet", "moderat", "klar", "sterk"]))
    var metning: String
    @Guide(description: "Bakgrunn: lys for åpne og lette uttrykk, mørk for dype, eksklusive eller dramatiske", .anyOf(["lys", "mørk"]))
    var bakgrunn: String
}

extension GenerertTolkning {
    /// Oppskriften: kunnskapsbasen gir rammene, modellen veier mellom kulørene. Uten treff i basen
    /// gjelder modellens valg alene.
    func tolkning(grunnlag: Begrepsgrunnlag, gamut: Gamut) -> Palettolkning {
        var o = Palettoppskrift(grunnlag: grunnlag, gamut: gamut)
        let p = Kulørfamilie(rawValue: primær), s = Kulørfamilie(rawValue: sekundær)
        let mørktUttrykk = lyshet == "mørk"
        if grunnlag.erTomt {
            if let p { o.primær = p }
            o.sekundær = s != o.primær ? s : nil
            o.metning = max(Metningsnivå(rawValue: metning) ?? .klar, .moderat)
            let ønsket: [Lyshetsnivå] = mørktUttrykk ? [.mørk, .middelsMørk] : lyshet == "lys" ? [.middels, .lys] : [.middelsMørk, .middels]
            o.lyshet = Fargespesifikasjon.klaresteLyshet(for: o.primær, blant: ønsket, i: gamut)
            o.bakgrunn = bakgrunn == "mørk" ? .mørk : .lys
        } else {
            let vektet = grunnlag.familievekter.map(\.0).filter { $0 != .nøytral }
            if let p, vektet.prefix(3).contains(p) { o.primær = p }
            if let s, s != o.primær, vektet.contains(s) {
                o.sekundær = s
            } else if o.sekundær == o.primær {
                o.sekundær = vektet.first { $0 != o.primær }
            }
            if o.aksent == o.primær || o.aksent == o.sekundær { o.aksent = nil }
            if bakgrunn == "mørk", mørktUttrykk { o.bakgrunn = .mørk }
        }
        if let harmoni = Palettoppskrift.harmoni(o.primær, o.sekundær) { o.harmoni = harmoni }
        return Palettolkning(tittel: tittel, forklaring: forklaring, oppskrift: o, kilde: .appleIntelligence)
    }
}

enum Instruksjoner {
    static var tolk: String { """
    Du er en erfaren fargedesigner. Du tolker verdiord for en visuell identitet og velger hvilke kulører \
    og hvilket uttrykk som bærer dem. Selve paletten bygges etterpå etter faste harmoniregler, så du \
    velger bare retning. Merkevaren er formålet, ikke grunnlaget: begrunn valgene i hva ordene betyr og \
    i begrepsgrunnlaget du får, ikke i bransjeklisjeer.

    Kulørfamilier: rød, korall, oransje, rav, gul, lime, grønn, blågrønn, turkis, himmelblå, blå, indigo, \
    fiolett, magenta, rosa.
    To verdiord skal gi to ulike kulører. Varme og menneskelige ord er ikke bare oransje og rav – korall, \
    rosa, rød og gul er også varme. Velg kulører med egenart, og aldri for å få brunt eller grått.
    Følg begrepsgrunnlaget når det finnes: primær hentes fra de tyngste kulørfamiliene, sekundær fra et \
    annet verdiord enn primær.
    \(Språk.svarinstruks)
    """ }

    static func tolk(verdiord: String, grunnlag: Begrepsgrunnlag) -> String {
        """
        Verdiord: \(verdiord)

        \(grunnlag.fakta)

        Tolk verdiordene: velg primær og sekundær kulørfamilie, lyshet, metning og bakgrunn.
        """
    }

    static var fargedesigner: String { """
    Du er en erfaren fargedesigner. Du oversetter verdiord og stemninger til harmoniske fargepaletter \
    som skal brukes i visuelle identiteter for digital og trykt bruk. Merkevaren er formålet, ikke \
    grunnlaget: begrunn fargene i hva ordene betyr og i begrepsgrunnlaget du får, ikke i bransjeklisjeer.

    Du beskriver hver farge i et fargespråk:
    - familie: rød, korall, oransje, rav, gul, lime, grønn, blågrønn, turkis, himmelblå, blå, indigo, \
    fiolett, magenta, rosa eller nøytral.
    - lyshet: nesten-sort, svært-mørk, mørk, middels-mørk, middels, lys, svært-lys, nesten-hvit.
    - metning: grå, svak, dempet, moderat, klar, sterk, maksimal. Metning er relativ, så «klar» er like \
    klar i alle familier.
    Farger skal ha tydelig kulør: velg moderat, klar eller sterk med mindre begrepsgrunnlaget sier dempet. \
    Brunt er oransje eller rav med mørk lyshet og moderat metning – bruk det bare når ordene handler om \
    jord, tre, lær, kaffe e.l. Natur betyr levende, klare farger. Gul og lime er klare bare som lys eller \
    svært lys; mørk gul blir oliven.
    En god palett har tydelig variasjon i lyshet. Bakgrunn: nesten-hvit (eller nesten-sort for mørke \
    uttrykk) med svak metning. Tekst: kontrasterer sterkt mot bakgrunnen.
    Følg begrepsgrunnlaget når det finnes: hent primær- og sekundærfarge fra de tyngste kulørfamiliene.
    \(Språk.svarinstruks)
    """ }

    static func forslag(verdiord: String, antall: Int, grunnlag: Begrepsgrunnlag) -> String {
        """
        Verdiord: \(verdiord)

        \(grunnlag.fakta)

        Lag en palett med nøyaktig \(antall) farger. Bruk rollene primær, sekundær, aksent, \
        bakgrunn og tekst; ved flere enn fem farger kan du legge til støtte-farger.
        """
    }

    static func justering(_ instruks: String, av palett: [Fargeforslag], grunnlag: Begrepsgrunnlag) -> String {
        """
        Nåværende palett:
        \(beskrivelse(palett))

        \(grunnlag.erTomt ? "" : grunnlag.fakta + "\n")
        Juster paletten slik: \(instruks)
        Behold antall farger og roller med mindre justeringen ber om noe annet. «Mer dempet» betyr ett \
        metningsnivå ned, «lysere» ett lyshetsnivå opp osv. Oppdater tittel og forklaring hvis stemningen endrer seg.
        """
    }

    static func beskrivelse(_ palett: [Fargeforslag]) -> String {
        palett.map { f in
            // Alltid fra selve fargen: den kan være endret av rolleregler eller hurtigjusteringer.
            let s = Fargespesifikasjon.nærmeste(f.farge)
            let just = s.justering == 0 ? "" : ", justering \(Int(s.justering))"
            return "- \(f.navn) (\(f.rolle)): \(s.familie.rawValue), \(s.lyshet.rawValue), \(s.metning.rawValue)\(just)"
        }.joined(separator: "\n")
    }
}

/// Bygger en farge fra modellens valg og håndhever begrepsgrunnlagets minste metning for rollen.
func lagFargeforslag(rolle: String, familie: String?, lyshet: String?, metning: String?, justering: Int?,
                     navn: String, begrunnelse: String, grunnlag: Begrepsgrunnlag, gamut: Gamut) -> Fargeforslag? {
    guard let familie = familie.flatMap(Kulørfamilie.init(rawValue:)),
          let lyshet = lyshet.flatMap(Lyshetsnivå.init(rawValue:)),
          var metning = metning.flatMap(Metningsnivå.init(rawValue:))
    else { return nil }
    if familie != .nøytral, let minst = grunnlag.minsteMetning(for: rolle), metning < minst { metning = minst }
    let spes = grunnlag.utenUønsketBrunt(
        Fargespesifikasjon(familie: familie, lyshet: lyshet, metning: metning, justering: Double(justering ?? 0)),
        rolle: rolle, gamut: gamut)
    return Fargeforslag(navn: navn, rolle: rolle, begrunnelse: begrunnelse, farge: spes.farge(i: gamut), spesifikasjon: spes)
}

extension GenerertPalett {
    func forslag(grunnlag: Begrepsgrunnlag, gamut: Gamut) -> PalettForslag {
        PalettForslag(tittel: tittel, forklaring: forklaring,
                      farger: farger.compactMap {
                          lagFargeforslag(rolle: $0.rolle, familie: $0.familie, lyshet: $0.lyshet, metning: $0.metning,
                                          justering: $0.justering, navn: $0.navn, begrunnelse: $0.begrunnelse,
                                          grunnlag: grunnlag, gamut: gamut)
                      },
                      kilde: .appleIntelligence, grunnlag: grunnlag.begreper.map(\.id))
            .medRolleregler()
    }
}

extension GenerertPalett.PartiallyGenerated {
    /// Fargene så snart familie, lyshet og metning er strømmet inn.
    func forslag(grunnlag: Begrepsgrunnlag, gamut: Gamut) -> PalettForslag {
        PalettForslag(tittel: tittel ?? "", forklaring: forklaring ?? "",
                      farger: (farger ?? []).compactMap {
                          lagFargeforslag(rolle: $0.rolle ?? "", familie: $0.familie, lyshet: $0.lyshet, metning: $0.metning,
                                          justering: $0.justering, navn: $0.navn ?? "", begrunnelse: $0.begrunnelse ?? "",
                                          grunnlag: grunnlag, gamut: gamut)
                      },
                      kilde: .appleIntelligence, grunnlag: grunnlag.begreper.map(\.id))
    }
}
#endif
