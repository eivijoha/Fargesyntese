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

/// Faste verdiord med forventede kulørområder (OKLCH-grader) for primærfargen, der det gir mening.
let evalsett: [(ord: String, primær: [ClosedRange<Double>])] = [
    ("natur, frisk, grønn", [115...185]),
    ("hav, frihet", [180...275]),
    ("trygg, varm, nordisk", []),
    ("leken, modig", []),
    ("energi, sport", [15...110]),
    ("ro, balanse, velvære", []),
    ("luksus, eleganse", []),
    ("bærekraft, ærlig", [110...200]),
    ("kreativ, nysgjerrig", []),
    ("tillit, kunnskap", [220...290]),
    ("sommer, glede", [60...130]),
    ("høst, lun", [20...95]),
    ("fjell, snø, klar luft", [200...280]),
    ("blomstereng", []),
    ("teknologi, presisjon", [200...300]),
]

/// Kjører evalsettet og måler: treff på forventet kulør for primærfargen, andel brune toner og
/// andel toner med lite kulør blant primær/sekundær/aksent/støtte (bakgrunn og tekst holdes utenfor).
func evaluer(runder: Int) async {
    var farger = 0, brune = 0, gråaktige = 0, forventet = 0, treff = 0
    var kromaSum = 0.0
    for (ord, primær) in evalsett {
        for _ in 0..<runder {
            guard let f = try? await Verdiordtjeneste.beste().forslag(for: ord, antall: 5) else { print("FEIL: \(ord)"); continue }
            let kjerne = f.farger.filter { !["bakgrunn", "tekst"].contains($0.rolle.lowercased()) }
            var linje = [String]()
            for c in kjerne {
                let lch = c.farge.okLCH
                farger += 1
                kromaSum += lch.c
                let brun = (30...90).contains(lch.h) && lch.l < 0.62 && lch.c > 0.02 && lch.c < 0.13
                if brun { brune += 1 }
                if lch.c < 0.05 { gråaktige += 1 }
                linje.append("\(c.farge.hex())\(brun ? "ᵇ" : "")\(lch.c < 0.05 ? "ᵍ" : "")")
            }
            var merke = ""
            if !primær.isEmpty, let p = f.farger.first(where: { $0.rolle.lowercased() == "primær" }) {
                forventet += 1
                let h = p.farge.okLCH.h
                if primær.contains(where: { $0.contains(h) }) && p.farge.okLCH.c >= 0.05 { treff += 1; merke = " ✓" } else { merke = " ✗" }
            }
            print("\(ord.padding(toLength: 24, withPad: " ", startingAt: 0)) \(linje.joined(separator: " "))\(merke)")
        }
    }
    print(String(format: "\nPrimær i forventet kulør: %d/%d  ·  brune: %.0f %%  ·  lite kulør (C<0,05): %.0f %%  ·  snittkroma: %.3f",
                 treff, forventet, 100 * Double(brune) / Double(max(farger, 1)),
                 100 * Double(gråaktige) / Double(max(farger, 1)), kromaSum / Double(max(farger, 1))))
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
        let f = try await AppleIntelligenceTolker().forslag(for: arg[1], antall: 5)
        skriv(f)
    } catch { print("FEIL: \(error)") }
    print(String(format: "\n(%.1f s)", Date().timeIntervalSince(start)))
}
