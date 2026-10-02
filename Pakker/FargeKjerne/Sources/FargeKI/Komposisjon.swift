import FargeKjerne
import Foundation

// Verdiord → palett i to trinn: først en *tolkning* (hvilke kulører og hvilket uttrykk ordene peker mot –
// fra kunnskapsbasen, eventuelt veid av språkmodellen), så en *komposisjon* etter faste regler.
// Komposisjonen er deterministisk: harmoniprinsipp, felles valør eller metning, én aksent, en tydelig
// lys eller mørk bakgrunn og garantert lesbar tekst. Språkmodellen velger bare retning; den regner
// aldri ut farger og kan derfor ikke gi brune, grå eller uleselige paletter.

/// Hvordan kulørene i paletten forholder seg til hverandre på fargesirkelen (OKLCH).
public enum Harmoniprinsipp: String, CaseIterable, Codable, Sendable, Identifiable {
    case monokrom, analog, komplementær, splittkomplementær = "splitt-komplementær", triade

    public var id: String { rawValue }

    public var navn: String {
        switch self {
        case .monokrom: String(localized: "Monokrom", bundle: .module)
        case .analog: String(localized: "Analog", bundle: .module)
        case .komplementær: String(localized: "Komplementær", bundle: .module)
        case .splittkomplementær: String(localized: "Splittkomplementær", bundle: .module)
        case .triade: String(localized: "Triade", bundle: .module)
        }
    }

    /// Prinsippet som passer best til vinkelen mellom to kulører.
    static func klassifiser(vinkel: Double) -> Harmoniprinsipp {
        switch abs(vinkel) {
        case ..<15: .monokrom
        case ..<75: .analog
        case ..<135: .triade
        case ..<165: .splittkomplementær
        default: .komplementær
        }
    }
}

/// Hva hovedfargene har felles.
public enum Samklang: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Samme lyshet (valør); kulørene skiller fargene.
    case likValør = "lik-valør"
    /// Samme metning; lysheten varierer og gir hierarki.
    case likMetning = "lik-metning"

    public var id: String { rawValue }

    public var navn: String {
        switch self {
        case .likValør: String(localized: "Lik valør", bundle: .module)
        case .likMetning: String(localized: "Lik metning", bundle: .module)
        }
    }
}

public enum Bakgrunnstype: String, CaseIterable, Codable, Sendable, Identifiable {
    case lys, mørk

    public var id: String { rawValue }

    public var navn: String {
        switch self {
        case .lys: String(localized: "Lys", bundle: .module)
        case .mørk: String(localized: "Mørk", bundle: .module)
        }
    }
}

/// Oppskriften en palett komponeres etter. Kulørene kommer fra verdiordene; resten er valg brukeren kan endre.
public struct Palettoppskrift: Hashable, Codable, Sendable {
    /// Kuløren som bærer det viktigste verdiordet.
    public var primær: Kulørfamilie
    /// Kuløren for det nest viktigste verdiordet, når ordene peker mot flere.
    public var sekundær: Kulørfamilie?
    /// Aksent som kunnskapsbasen knytter til begrepet (f.eks. gul til natur).
    public var aksent: Kulørfamilie?
    public var harmoni: Harmoniprinsipp
    public var samklang: Samklang
    /// Lysheten til primærfargen.
    public var lyshet: Lyshetsnivå
    public var metning: Metningsnivå
    public var bakgrunn: Bakgrunnstype
    /// Kuløren som får være brun (jord, tre, lær …). Uten denne løftes varme, mørke farger ut av det brune.
    public var brunt: Kulørfamilie?

    public init(primær: Kulørfamilie, sekundær: Kulørfamilie? = nil, aksent: Kulørfamilie? = nil,
                harmoni: Harmoniprinsipp = .analog, samklang: Samklang = .likMetning,
                lyshet: Lyshetsnivå = .middelsMørk, metning: Metningsnivå = .klar,
                bakgrunn: Bakgrunnstype = .lys, brunt: Kulørfamilie? = nil) {
        self.primær = primær
        self.sekundær = sekundær
        self.aksent = aksent
        self.harmoni = harmoni
        self.samklang = samklang
        self.lyshet = lyshet
        self.metning = metning
        self.bakgrunn = bakgrunn
        self.brunt = brunt
    }

    /// Oppskrift rett fra kunnskapsbasen: de tyngste kulørene, begrepets lyshet og metning,
    /// og harmoniprinsippet som følger av vinkelen mellom kulørene.
    public init(grunnlag: Begrepsgrunnlag, gamut: Gamut = .displayP3) {
        let familier = grunnlag.familievekter.map(\.0).filter { $0 != .nøytral }
        let hoved = grunnlag.begreper.first
        let primær = familier.first ?? .blå
        // Sekundær helst fra et annet verdiord enn det som ga primærfargen, så to ord gir to kulører.
        let fraAndreOrd = grunnlag.begreper.dropFirst().compactMap { b in
            b.sorterteFamilier.map(\.0).first { $0 != .nøytral && $0 != primær }
        }.first
        let sekundær = fraAndreOrd ?? familier.dropFirst().first
        let lysheter = (hoved?.lyshet ?? [.middelsMørk, .middels]).filter { (.mørk ... .lys).contains($0) }
        let brunt = grunnlag.begreper.first { $0.brunt == true }
            .flatMap { b in b.sorterteFamilier.map(\.0).first { [.korall, .oransje, .rav, .gul].contains($0) } }

        self.init(
            primær: primær,
            sekundær: sekundær,
            aksent: grunnlag.begreper.flatMap(\.aksent).first { $0 != primær && $0 != sekundær && $0 != .nøytral },
            harmoni: Self.harmoni(primær, sekundær) ?? Harmoniprinsipp(rawValue: hoved?.harmoni ?? "") ?? .analog,
            lyshet: brunt == primær ? (lysheter.min() ?? .mørk)
                : Fargespesifikasjon.klaresteLyshet(for: primær, blant: lysheter.isEmpty ? [.middelsMørk, .middels] : lysheter, i: gamut),
            metning: max(hoved?.metning.first ?? .klar, grunnlag.minsteMetning),
            // Mørk bakgrunn bare når begrepet selv er mørkt (natt, luksus, mystisk …).
            bakgrunn: (hoved?.lyshet.max()).map { $0 <= .mørk } == true ? .mørk : .lys,
            brunt: brunt
        )
    }

    static func harmoni(_ a: Kulørfamilie, _ b: Kulørfamilie?) -> Harmoniprinsipp? {
        guard let h1 = a.kulør, let h2 = b?.kulør else { return nil }
        return .klassifiser(vinkel: fortegnsvinkel(fra: h1, til: h2))
    }
}

/// Vinkelen fra `a` til `b` rundt fargesirkelen, i −180…180.
func fortegnsvinkel(fra a: Double, til b: Double) -> Double {
    var d = (b - a).truncatingRemainder(dividingBy: 360)
    if d > 180 { d -= 360 }
    if d < -180 { d += 360 }
    return d
}

extension Fargespesifikasjon {
    /// Spesifikasjon for en vilkårlig kulør: nærmeste familie pluss finjustering.
    init(kulør: Double, lyshet: Lyshetsnivå, metning: Metningsnivå) {
        let h = (kulør.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let familie = Kulørfamilie.nærmeste(kulør: h)
        self.init(familie: familie, lyshet: lyshet, metning: metning, justering: fortegnsvinkel(fra: familie.kulør!, til: h).rounded())
    }

    /// Laveste lyshet der familien ser klar ut (ikke brun eller oliven). `nil` når alle lysheter er klare.
    static func minsteKlareLyshet(for familie: Kulørfamilie) -> Lyshetsnivå? {
        switch familie {
        case .gul: .sværtLys
        case .lime: .lys
        case .korall, .oransje, .rav: .middels
        default: nil
        }
    }
}

extension Lyshetsnivå {
    /// Nivået `steg` trinn lysere (negativt = mørkere), innenfor svært-mørk … svært-lys.
    func flyttet(_ steg: Int) -> Lyshetsnivå {
        let alle = Self.allCases
        return alle[max(1, min(alle.count - 2, alle.firstIndex(of: self)! + steg))]
    }
}

/// Bygger paletten fra en oppskrift.
public enum Palettkomponist {
    /// Minste kontrast mot bakgrunnen: tekst (WCAG AAA) og hovedfarger (WCAG 1.4.11, grafikk og stor tekst).
    public static let tekstkontrast = 7.0
    public static let fargekontrast = 3.0

    /// Fargene i rekkefølgen primær, sekundær, aksent, bakgrunn, tekst og deretter støttefarger.
    public static func komponer(_ o: Palettoppskrift, antall: Int, grunnlag: Begrepsgrunnlag = Begrepsgrunnlag(treff: []),
                                gamut: Gamut = .displayP3) -> [Fargeforslag] {
        let h1 = o.primær.kulør ?? Kulørfamilie.blå.kulør!
        let vinkel = o.sekundær?.kulør.map { fortegnsvinkel(fra: h1, til: $0) }
        let retning: Double = (vinkel ?? 1) < 0 ? -1 : 1
        // Når ordenes to kulører allerede står i det valgte forholdet, brukes de som de er.
        let naturlig = vinkel.map { Harmoniprinsipp.klassifiser(vinkel: $0) == o.harmoni } ?? false

        // Kulører for sekundær, aksent og første støttefarge.
        let hSek: Double, hAks: Double, hStøtte: Double
        var aksentFraBegrep = false
        switch o.harmoni {
        case .monokrom:
            (hSek, hAks, hStøtte) = (h1, h1, h1)
        case .analog:
            let d = naturlig ? vinkel! : 30 * retning
            hSek = h1 + d
            hStøtte = h1 - d
            if let a = o.aksent?.kulør {
                hAks = a
                aksentFraBegrep = true
            } else {
                // Analog med komplementær aksent: motsatt av midten mellom de to hovedfargene.
                hAks = h1 + d / 2 + 180
            }
        case .komplementær:
            hSek = h1
            hAks = naturlig ? h1 + vinkel! : h1 + 180
            hStøtte = hAks
        case .splittkomplementær:
            let d = naturlig ? vinkel! : 150 * retning
            (hSek, hAks, hStøtte) = (h1 + d, h1 - d, h1)
        case .triade:
            let d = naturlig ? vinkel! : 120 * retning
            (hSek, hAks, hStøtte) = (h1 + d, h1 - d, h1)
        }

        let mørkBakgrunn = o.bakgrunn == .mørk
        // Bakgrunn og tekst: samme kulør som primærfargen, nesten uten kroma.
        let bakgrunn = Farge(okLCH: OKLCH(l: mørkBakgrunn ? 0.19 : 0.97, c: mørkBakgrunn ? 0.02 : 0.012, h: h1)).gamutKartlagt(til: gamut)
        let tekst = Farge(okLCH: OKLCH(l: mørkBakgrunn ? 0.94 : 0.24, c: mørkBakgrunn ? 0.015 : 0.03, h: h1))
            .gamutKartlagt(til: gamut).medKontrast(mot: bakgrunn, minst: tekstkontrast)

        // Lysheter. Mot mørk bakgrunn må hovedfargene være lyse nok til å synes.
        var nøkkel = min(max(o.lyshet, .mørk), .lys)
        if mørkBakgrunn { nøkkel = max(nøkkel, .middels) }
        // Sekundærfargen ligger ett til to trinn fra primær, støttefargen på den andre siden eller imellom.
        let tonesteg = mørkBakgrunn ? (nøkkel <= .middels ? 1 : -1) : (nøkkel <= .middelsMørk ? 2 : -2)
        let støttesteg = mørkBakgrunn ? (nøkkel <= .middels ? 2 : 1) : (tonesteg > 0 ? 1 : -1)
        func sammeKulør(_ a: Double, _ b: Double) -> Bool { vinkelavstand(a, b) < 10 }
        func kanBliBrun(_ familie: Kulørfamilie) -> Bool { familie == o.brunt }

        let aksentlysheter: [Lyshetsnivå] = mørkBakgrunn ? [.middels, .lys, .sværtLys] : [.middelsMørk, .middels, .lys]
        func klarest(_ h: Double, _ nivåer: [Lyshetsnivå]) -> Lyshetsnivå {
            Fargespesifikasjon.klaresteLyshet(for: Fargespesifikasjon(kulør: h, lyshet: .middels, metning: .klar).familie, blant: nivåer, i: gamut)
        }

        var plan: [(rolle: String, spes: Fargespesifikasjon, sikreKontrast: Bool)] = []
        switch o.samklang {
        case .likMetning:
            plan.append(("primær", .init(kulør: h1, lyshet: nøkkel, metning: o.metning), true))
            // En tone av primærfargen (samme kulør) er en lysere eller mørkere flatefarge og slipper kontrastkravet.
            plan.append(("sekundær", .init(kulør: hSek, lyshet: nøkkel.flyttet(tonesteg), metning: o.metning), !sammeKulør(hSek, h1)))
            plan.append(("aksent", .init(kulør: hAks, lyshet: klarest(hAks, aksentlysheter), metning: max(o.metning, .klar)), true))
            plan.append(("støtte", .init(kulør: hStøtte, lyshet: nøkkel.flyttet(støttesteg), metning: o.metning), true))
        case .likValør:
            // Felles lyshet høy nok til at ingen av hovedkulørene blir brune (gul får likevel gå sin egen vei).
            var felles = nøkkel
            for h in [h1, hSek] {
                let familie = Fargespesifikasjon(kulør: h, lyshet: nøkkel, metning: o.metning).familie
                if !kanBliBrun(familie), let minst = Fargespesifikasjon.minsteKlareLyshet(for: familie) { felles = max(felles, min(minst, .lys)) }
            }
            let sterkere = Metningsnivå.allCases[min(Metningsnivå.allCases.firstIndex(of: o.metning)! + 1, Metningsnivå.allCases.count - 1)]
            plan.append(("primær", .init(kulør: h1, lyshet: felles, metning: o.metning), true))
            // Tone i tone (samme kulør som primær) må skilles i lyshet.
            plan.append(("sekundær", .init(kulør: hSek, lyshet: sammeKulør(hSek, h1) ? felles.flyttet(tonesteg) : felles, metning: o.metning), !sammeKulør(hSek, h1)))
            plan.append(("aksent", .init(kulør: hAks, lyshet: sammeKulør(hAks, h1) ? klarest(hAks, aksentlysheter) : felles, metning: max(sterkere, .klar)), true))
            plan.append(("støtte", .init(kulør: hStøtte, lyshet: sammeKulør(hStøtte, h1) || sammeKulør(hStøtte, hSek) ? felles.flyttet(støttesteg) : felles,
                                         metning: o.metning), true))
        }
        // Flere støttefarger: lyse og mørke toner av hovedkulørene (flater, rammer, fremheving).
        let flate: Lyshetsnivå = mørkBakgrunn ? .sværtMørk : .sværtLys
        let dyp: Lyshetsnivå = mørkBakgrunn ? .lys : .mørk
        plan.append(("støtte", .init(kulør: h1, lyshet: flate, metning: .dempet), false))
        plan.append(("støtte", .init(kulør: hSek, lyshet: sammeKulør(hSek, h1) ? dyp.flyttet(mørkBakgrunn ? 1 : -1) : dyp, metning: o.metning), false))
        plan.append(("støtte", .init(kulør: hAks, lyshet: flate, metning: .dempet), false))
        plan.append(("støtte", .init(kulør: hAks, lyshet: dyp, metning: o.metning), false))

        // Brunvakt: bare kuløren oppskriften åpner for får være brun, og bare én gang.
        var bruntBrukt = false
        func utenBrunt(_ spes: Fargespesifikasjon) -> Fargespesifikasjon {
            var spes = spes
            let varm = [Kulørfamilie.korall, .oransje, .rav, .gul].contains(spes.familie)
            if spes.blirBrun, kanBliBrun(spes.familie), !bruntBrukt { bruntBrukt = true; return spes }
            // Varme kulører med lav metning blir terrakotta og beige; de trenger klarhet (flatetoner unntatt).
            if varm, spes.metning > .dempet, spes.metning < .klar { spes.metning = .klar }
            guard spes.blirBrun else { return spes }
            var ny = spes
            ny.lyshet = Fargespesifikasjon.klaresteLyshet(for: spes.familie, blant: [.middels, .lys, .sværtLys], i: gamut)
            return ny
        }

        /// Hovedfargene skal kunne brukes til grafikk og stor tekst mot bakgrunnen. Gul og lime beholdes
        /// klare selv om de ikke når kravet – mørkere ville de blitt oliven.
        func lesbar(_ spes: Fargespesifikasjon) -> (Farge, Fargespesifikasjon) {
            let farge = spes.farge(i: gamut)
            let justert = farge.medKontrast(mot: bakgrunn, minst: fargekontrast).gamutKartlagt(til: gamut)
            guard justert != farge else { return (farge, spes) }
            let ny = Fargespesifikasjon.nærmeste(justert, i: gamut)
            if ny.blirBrun, !(kanBliBrun(ny.familie) && spes.blirBrun) { return (farge, spes) }
            return (justert, ny)
        }

        func ord(for familie: Kulørfamilie?) -> String? {
            guard let familie else { return nil }
            return grunnlag.treff.first { ($0.begrep.familier[familie.rawValue] ?? 0) >= 0.5 }?.ord
        }
        func kontrasttekst(_ f: Farge) -> String {
            f.wcagKontrast(mot: bakgrunn).formatted(.number.precision(.fractionLength(1))) + ":1"
        }

        var resultat: [Fargeforslag] = []
        func legg(_ rolle: String, _ farge: Farge, _ spes: Fargespesifikasjon?, _ begrunnelse: String) {
            let beskrivelse = Fargebeskrivelse.beskriv(farge)
            resultat.append(Fargeforslag(navn: beskrivelse.prefix(1).uppercased() + beskrivelse.dropFirst(), rolle: rolle,
                                         begrunnelse: begrunnelse, farge: farge, spesifikasjon: spes))
        }

        for (rolle, råSpes, sikre) in plan {
            let (farge, spes) = sikre ? lesbar(utenBrunt(råSpes)) : { let s = utenBrunt(råSpes); return (s.farge(i: gamut), s) }()
            // Støttefarger som faller sammen med en farge som allerede er med, hoppes over.
            if rolle == "støtte", resultat.contains(where: { $0.farge.deltaE2000(til: farge) < 4 }) { continue }
            let begrunnelse: String
            switch rolle {
            case "primær":
                begrunnelse = ord(for: o.primær).map { String(localized: "Hovedfarge fra «\($0)».", bundle: .module) }
                    ?? String(localized: "Hovedfarge for verdiordene.", bundle: .module)
            case "sekundær":
                if naturlig, o.harmoni != .komplementær, let ordet = ord(for: o.sekundær) {
                    begrunnelse = String(localized: "Fra «\(ordet)».", bundle: .module)
                } else {
                    switch o.harmoni {
                    case .monokrom, .komplementær: begrunnelse = String(localized: "Tone i tone med hovedfargen.", bundle: .module)
                    case .analog: begrunnelse = String(localized: "Nabokulør til hovedfargen.", bundle: .module)
                    case .splittkomplementær: begrunnelse = String(localized: "Splittkomplementær til hovedfargen.", bundle: .module)
                    case .triade: begrunnelse = String(localized: "Andre farge i triaden.", bundle: .module)
                    }
                }
            case "aksent":
                if aksentFraBegrep, let ordet = ord(for: o.aksent) {
                    begrunnelse = String(localized: "Aksent fra «\(ordet)». Brukes sparsomt.", bundle: .module)
                } else if o.harmoni == .komplementær, naturlig, let ordet = ord(for: o.sekundær) {
                    begrunnelse = String(localized: "Komplementær aksent fra «\(ordet)». Brukes sparsomt.", bundle: .module)
                } else {
                    switch o.harmoni {
                    case .monokrom: begrunnelse = String(localized: "Hovedkuløren på sitt klareste, som aksent.", bundle: .module)
                    case .analog, .komplementær: begrunnelse = String(localized: "Komplementær aksent. Brukes sparsomt.", bundle: .module)
                    case .splittkomplementær: begrunnelse = String(localized: "Splittkomplementær aksent. Brukes sparsomt.", bundle: .module)
                    case .triade: begrunnelse = String(localized: "Tredje farge i triaden, som aksent.", bundle: .module)
                    }
                }
            default:
                begrunnelse = spes.metning <= .dempet
                    ? String(localized: "Rolig tone til flater og rammer.", bundle: .module)
                    : String(localized: "Støttefarge i samme harmoni.", bundle: .module)
            }
            legg(rolle, farge, spes, begrunnelse)
            // Bakgrunn og tekst kommer rett etter aksenten.
            if rolle == "aksent" {
                legg("bakgrunn", bakgrunn, nil, mørkBakgrunn
                     ? String(localized: "Mørk bakgrunn med et hint av hovedfargen.", bundle: .module)
                     : String(localized: "Lys bakgrunn med et hint av hovedfargen.", bundle: .module))
                legg("tekst", tekst, nil, String(localized: "Tekst med \(kontrasttekst(tekst)) kontrast mot bakgrunnen.", bundle: .module))
            }
        }
        return Array(resultat.prefix(max(antall, 3)))
    }
}

/// Tolkningen av verdiordene: tittel, forklaring og oppskrift.
public struct Palettolkning: Sendable, Hashable {
    public var tittel: String
    public var forklaring: String
    public var oppskrift: Palettoppskrift
    public var kilde: PalettForslag.Kilde

    public init(tittel: String, forklaring: String, oppskrift: Palettoppskrift, kilde: PalettForslag.Kilde) {
        self.tittel = tittel
        self.forklaring = forklaring
        self.oppskrift = oppskrift
        self.kilde = kilde
    }

    /// Tolkning rett fra kunnskapsbasen, uten språkmodell.
    public init(grunnlag: Begrepsgrunnlag, gamut: Gamut = .displayP3) {
        let o = Palettoppskrift(grunnlag: grunnlag, gamut: gamut)
        self.init(
            tittel: grunnlag.erTomt ? String(localized: "Nøytral start", bundle: .module)
                : grunnlag.begreper.prefix(3).map { $0.visningsnavn.capitalized }.joined(separator: " · "),
            forklaring: grunnlag.erTomt
                ? String(localized: "Fant ingen kjente verdiord – her er et nøytralt utgangspunkt.", bundle: .module)
                : String(localized: "Bygget fra kunnskapsbasen: \(o.primær.navn)\(o.sekundær.map { " + " + $0.navn } ?? "").", bundle: .module),
            oppskrift: o, kilde: .leksikon)
    }

    public func forslag(antall: Int, grunnlag: Begrepsgrunnlag, gamut: Gamut = .displayP3) -> PalettForslag {
        PalettForslag(tittel: tittel, forklaring: forklaring,
                      farger: Palettkomponist.komponer(oppskrift, antall: antall, grunnlag: grunnlag, gamut: gamut),
                      kilde: kilde, grunnlag: grunnlag.begreper.map(\.id), oppskrift: oppskrift)
    }
}
