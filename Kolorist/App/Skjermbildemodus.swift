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
        let navn = Harmoni.jevn.navn
        let farger = Harmoni.jevn.farger(fra: Farge(hex: "#2F7FD8")!, antall: 5).map { $0.gamutKartlagt(til: .displayP3) }
        let palett = (try? kontekst.fetch(FetchDescriptor<PalettDokument>()))?.first { $0.navn == navn }
            ?? { let p = PalettDokument(navn: navn); kontekst.insert(p); return p }()
        // Setter fargene på nytt hver gang, så paletten også blir sist endret og står først.
        palett.farger = farger.map { PalettFarge(farge: $0, opphav: .manuell) }
        try? kontekst.save()
        UserDefaults.standard.set(palett.id.uuidString, forKey: "vurderingPalett")
        // `-bibliotekfil <sti>`: importer et fargebibliotek (til test i simulatoren, der dokumentvelgeren ikke virker).
        if let sti = UserDefaults.standard.string(forKey: "bibliotekfil") {
            _ = try? ProfilBibliotek.delt.importerBibliotek(fra: URL(fileURLWithPath: sti))
        }
    }
}
#endif
