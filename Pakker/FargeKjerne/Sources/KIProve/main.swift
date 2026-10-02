import FargeKI
import FargeKjerne
import Foundation

// Bruk:
//   swift run kiprove forslag "trygg, varm, nordisk" [antall]
//   swift run kiprove juster "trygg, varm" "mer som en skandinavisk kafé"
//   swift run kiprove navngi "#1B3A6B" "#F2B84B" ...
//   swift run kiprove vurder "#1B3A6B" "#F2B84B" ...

func skriv(_ f: PalettForslag) {
    print("\n\(f.tittel) [\(f.kilde.rawValue)]\n\(f.forklaring)")
    for c in f.farger {
        let kontrast = Kontrasttest(forgrunn: c.farge, bakgrunn: Farge(hex: "#FFFFFF")!).formatert
        print("  \(c.farge.hex())  \(c.navn) (\(c.rolle)) – \(Fargebeskrivelse.beskriv(c.farge)), mot hvitt \(kontrast)")
        if !c.begrunnelse.isEmpty { print("           \(c.begrunnelse)") }
    }
}

@MainActor
func vent(på samtale: PalettSamtale) async {
    while samtale.arbeider { try? await Task.sleep(for: .milliseconds(100)) }
    if let feil = samtale.feil { print("FEIL: \(feil.localizedDescription)") }
}

/// Faste verdiord: mest abstrakte ord slik virksomheter bruker dem, og noen konkrete med forventet
/// kulørområde (OKLCH-grader) for primærfargen.
let evalsett: [(ord: String, primær: [ClosedRange<Double>])] = [
    ("pålitelig, innovativ, inkluderende", []),
    ("raus, nær, kompetent", []),
    ("ambisiøs, modig, åpen", []),
    ("profesjonell, tilgjengelig, engasjert", []),
    ("respekt, kvalitet, samarbeid", []),
    ("nyskapende, bærekraftig, ansvarlig", []),
    ("ekte, jordnær, stolt", []),
    ("omsorg, trygghet, glede", []),
    ("trygg, varm, nordisk", []),
    ("menneskelig, nær, varm", []),
    ("tradisjon, håndverk, kvalitet", []),
    ("lokal, ærlig, solid", []),
    ("leken, modig", []),
    ("luksus, eleganse", []),
    ("verdiskapende, helhetlig, fremragende", []),
    ("natur, frisk, grønn", [115...185]),
    ("hav, frihet", [180...275]),
    ("energi, sport", [15...110]),
    ("tillit, kunnskap", [220...290]),
    ("høst, lun", [20...95]),
    ("teknologi, presisjon", [200...300]),
]

/// Kjører evalsettet og måler det en brukbar palett må ha: få brune og grå toner, kulørspredning mellom
/// primær, sekundær og aksent, lesbar tekst, og hovedfarger som synes mot bakgrunnen.
func evaluer(runder: Int) async {
    var farger = 0, brune = 0, gråaktige = 0, forventet = 0, treff = 0
    var paletter = 0, ensfargede = 0, tekstOK = 0, primærOK = 0, hovedfarger = 0, hovedOK = 0
    for (ord, primær) in evalsett {
        for _ in 0..<runder {
            guard let f = try? await Verdiordtjeneste.beste().forslag(for: ord, antall: 5) else { print("FEIL: \(ord)"); continue }
            paletter += 1
            let bakgrunn = f.bakgrunn ?? Farge(hex: "#FFFFFF")!
            let kjerne = f.farger.filter { !["bakgrunn", "tekst"].contains($0.rolle.lowercased()) }
            var linje = [String]()
            for c in kjerne {
                let lch = c.farge.okLCH
                farger += 1
                let brun = (30...90).contains(lch.h) && lch.l < 0.62 && lch.c > 0.02 && lch.c < 0.13
                if brun { brune += 1 }
                if lch.c < 0.05 { gråaktige += 1 }
                hovedfarger += 1
                if c.farge.wcagKontrast(mot: bakgrunn) >= 3 { hovedOK += 1 }
                linje.append("\(c.farge.hex())\(brun ? "ᵇ" : "")\(lch.c < 0.05 ? "ᵍ" : "")")
            }
            // Ensfarget: alle hovedfargene innenfor 25° og med liten forskjell i lyshet.
            let h = kjerne.map { $0.farge.okLCH }
            let spredning = h.flatMap { a in h.map { b in min(abs(a.h - b.h), 360 - abs(a.h - b.h)) } }.max() ?? 0
            let lysspenn = (h.map(\.l).max() ?? 0) - (h.map(\.l).min() ?? 0)
            let ensfarget = spredning < 25 && lysspenn < 0.15
            if ensfarget { ensfargede += 1 }
            if let t = f.farger.first(where: { $0.rolle.lowercased() == "tekst" }), t.farge.wcagKontrast(mot: bakgrunn) >= 4.5 { tekstOK += 1 }
            var merke = ""
            if let p = f.farger.first(where: { $0.rolle.lowercased() == "primær" }) {
                if p.farge.wcagKontrast(mot: bakgrunn) >= 3 { primærOK += 1 }
                if !primær.isEmpty {
                    forventet += 1
                    let hp = p.farge.okLCH.h
                    if primær.contains(where: { $0.contains(hp) }) && p.farge.okLCH.c >= 0.05 { treff += 1; merke = " ✓" } else { merke = " ✗" }
                }
            }
            let harmoni = f.oppskrift.map { " [\($0.harmoni.rawValue)\($0.bakgrunn == .mørk ? ", mørk" : "")]" } ?? ""
            print("\(ord.padding(toLength: 40, withPad: " ", startingAt: 0)) \(linje.joined(separator: " "))\(ensfarget ? " ENSFARGET" : "")\(merke)\(harmoni)")
        }
    }
    func pst(_ a: Int, _ b: Int) -> String { String(format: "%.0f %%", 100 * Double(a) / Double(max(b, 1))) }
    print("""

    Primær i forventet kulør: \(treff)/\(forventet)
    Brune toner: \(pst(brune, farger))  ·  lite kulør (C<0,05): \(pst(gråaktige, farger))  ·  ensfargede paletter: \(ensfargede)/\(paletter)
    Tekst ≥ 4,5:1 mot bakgrunn: \(tekstOK)/\(paletter)  ·  primær ≥ 3:1: \(primærOK)/\(paletter)  ·  hovedfarger ≥ 3:1: \(pst(hovedOK, hovedfarger))
    """)
}

let arg = Array(CommandLine.arguments.dropFirst())
print("Status: \(KIStatus.gjeldende.forklaring)")

switch arg.first {
case "forslag":
    let samtale = await PalettSamtale()
    let start = Date()
    await samtale.foreslå(verdiord: arg[1], antall: arg.count > 2 ? Int(arg[2]) ?? 5 : 5)
    await vent(på: samtale)
    if let f = await samtale.forslag { skriv(f) }
    print(String(format: "\n(%.1f s)", Date().timeIntervalSince(start)))
case "juster":
    let samtale = await PalettSamtale()
    await samtale.foreslå(verdiord: arg[1], antall: 5)
    await vent(på: samtale)
    if let f = await samtale.forslag { skriv(f) }
    for instruks in arg.dropFirst(2) {
        print("\n>>> \(instruks)")
        await samtale.juster(instruks)
        await vent(på: samtale)
        if let f = await samtale.forslag { skriv(f) }
    }
case "navngi":
    let farger = arg.dropFirst().compactMap(Fargetolk.tolk)
    let navn = try await Fargenavngiver.navngi(farger)
    for (f, n) in zip(farger, navn) { print("  \(f.hex())  \(n)  (\(Fargebeskrivelse.beskriv(f)))") }
case "vurder":
    let farger = arg.dropFirst().compactMap(Fargetolk.tolk)
    let palett = Palett(navn: "Test", farger: farger.map { PalettFarge(navn: Fargebeskrivelse.beskriv($0), farge: $0) })
    let v = try await Palettvurderer.vurder(palett)
    print("\nFakta:\n" + v.fakta.map { "  • \($0)" }.joined(separator: "\n"))
    print("\n\(v.oppsummering)")
    print("Styrker:\n" + v.styrker.map { "  + \($0)" }.joined(separator: "\n"))
    print("Svakheter:\n" + v.svakheter.map { "  – \($0)" }.joined(separator: "\n"))
    print("Forslag:\n" + v.forslag.map { "  → \($0)" }.joined(separator: "\n"))
case "beskriv":
    for tekst in arg.dropFirst() {
        let b = await Fargebeskriver.farge(fra: tekst)
        print("  \(tekst.padding(toLength: 28, withPad: " ", startingAt: 0)) \(b.farge.hex())  \(Fargemodell.okLCH.tekst(for: b.farge))  \(b.spesifikasjon.tekst)  «\(b.navn)» [\(b.kilde.rawValue)]")
    }
case "eval":
    await evaluer(runder: arg.count > 1 ? Int(arg[1]) ?? 1 : 1)
default:
    print("Bruk: kiprove forslag|juster|navngi|vurder|eval …")
}

// Diagnose: ett enkelt kall uten strømming.
if arg.first == "enkel" {
    let start = Date()
    do {
        let f = try await AppleIntelligenceTolker().forslag(for: arg[1], antall: arg.count > 2 ? Int(arg[2]) ?? 5 : 5)
        skriv(f)
        if let o = f.oppskrift { print("  Oppskrift: \(o.primær.rawValue) + \(o.sekundær?.rawValue ?? "–") · \(o.harmoni.rawValue) · \(o.samklang.rawValue) · \(o.lyshet.rawValue) · \(o.metning.rawValue) · bakgrunn \(o.bakgrunn.rawValue)") }
    } catch { print("FEIL: \(error)") }
    print(String(format: "\n(%.1f s)", Date().timeIntervalSince(start)))
}
