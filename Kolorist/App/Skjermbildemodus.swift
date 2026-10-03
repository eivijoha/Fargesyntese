#if DEBUG
import FargeKjerne
import SwiftData
import SwiftUI

/// Debug: `-skjermbilde YES` til App Store-skjermbilder. Skrur av fokusmarkeringer og sørger for at
/// harmonipaletten «Jevn fordeling» (fem farger fra #2F7FD8) finnes og er valgt, så Vurdering › Fargesyn
/// viser samme palett på alle plattformer. Kombineres med `-startfane` og `-studioModus`.
enum Skjermbildemodus {
    static var på: Bool { UserDefaults.standard.bool(forKey: "skjermbilde") }

    static func forbered(_ kontekst: ModelContext) {
        guard på else { return }
        leggInnEksempler(kontekst)
        let navn = Harmoni.jevn.navn
        let farger = Harmoni.jevn.farger(fra: Farge(hex: "#2F7FD8")!, antall: 5).map { $0.gamutKartlagt(til: .displayP3) }
        let palett = (try? kontekst.fetch(FetchDescriptor<PalettDokument>()))?.first { $0.navn == navn }
            ?? { let p = PalettDokument(navn: navn); kontekst.insert(p); return p }()
        // Setter fargene på nytt hver gang, så de er de samme på alle plattformer.
        palett.farger = farger.map { PalettFarge(farge: $0, opphav: .manuell) }
        try? kontekst.save()
        UserDefaults.standard.set(palett.id.uuidString, forKey: "vurderingPalett")
        // `-testmaalinger YES`: noen plukkede farger, som om de kom fra kamera og bilder.
        if UserDefaults.standard.bool(forKey: "testmaalinger") {
            for hex in ["#C4553B", "#E8B04A", "#3F7D5A", "#2E5E8C", "#D9CBB4"] { Arbeidsbenk.delt.registrerMåling(Farge(hex: hex)!) }
        }
        // `-palettpdf <navn>`: skriv PDF-en av alle eksempelpalettene samlet til appens tmp-mappe (test av utskriften).
        if let navn = UserDefaults.standard.string(forKey: "palettpdf") {
            let alle = ((try? kontekst.fetch(FetchDescriptor<PalettDokument>())) ?? []).flatMap(\.farger)
            let samlet = Palett(navn: "Eksempelpaletter", farger: alle + alle.prefix(4))
            let url = FileManager.default.temporaryDirectory.appending(path: navn)
            try? PalettUtskrift.pdf(for: samlet).write(to: url)
            print("PDF:", url.path)
        }
        // `-bibliotekfil <sti>`: importer et fargebibliotek (til test i simulatoren, der dokumentvelgeren ikke virker).
        if let sti = UserDefaults.standard.string(forKey: "bibliotekfil") {
            _ = try? ProfilBibliotek.delt.importerBibliotek(fra: URL(fileURLWithPath: sti))
        }
    }

    /// Eksempelpaletter, enkeltfarger og en gradient i skjermbildelageret (i minnet), på appens språk.
    /// «Jevn fordeling» legges inn sist av `forbered` og står derfor øverst.
    private static func leggInnEksempler(_ kontekst: ModelContext) {
        guard ((try? kontekst.fetchCount(FetchDescriptor<PalettDokument>())) ?? 0) == 0 else { return }
        let engelsk = Bundle.main.preferredLocalizations.first?.hasPrefix("en") == true
        let paletter: [(String, String, [String])] = [
            ("Soloppgang", "Sunrise", ["#2B2D5C", "#7B3F6E", "#D9576B", "#F29E6D", "#F7D488"]),
            ("Skog", "Forest", ["#1E3B2B", "#2F5D3A", "#6E8B4E", "#C9B77D", "#F2EBDD"]),
            ("Nordisk kyst", "Nordic coast", ["#1F3A4D", "#3E6A80", "#8FB3C2", "#E6DCC8", "#C8553D"]),
        ]
        let nå = Date.now
        for (i, (nb, en, hex)) in paletter.enumerated() {
            let p = PalettDokument(navn: engelsk ? en : nb,
                                   farger: hex.map { PalettFarge(farge: Farge(hex: $0)!, opphav: .manuell) })
            p.opprettet = nå.addingTimeInterval(Double(i - 10) * 60)
            kontekst.insert(p)
        }
        for (i, hex) in ["#C4553B", "#2E5E8C", "#E8B04A"].enumerated() {
            let f = LagretFarge(PalettFarge(farge: Farge(hex: hex)!, opphav: .manuell))
            f.opprettet = nå.addingTimeInterval(Double(-i) * 60)
            kontekst.insert(f)
        }
        let oppsett = Gradientoppsett(fra: Farge(hex: "#1F3A4D")!, til: Farge(hex: "#F29E6D")!, antall: 7, trinn: Lyshetstrinn())
        kontekst.insert(LagretGradient(navn: engelsk ? "Dusk" : "Skumring", oppsett: oppsett))
    }
}
#endif
