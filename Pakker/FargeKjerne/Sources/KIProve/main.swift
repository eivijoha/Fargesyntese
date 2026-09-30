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
default:
    print("Bruk: kiprove forslag|juster|navngi|vurder …")
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
