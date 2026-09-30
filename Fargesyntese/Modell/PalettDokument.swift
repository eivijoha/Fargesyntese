import FargeKjerne
import Foundation
import SwiftData

/// Persistert palett. Fargene lagres som JSON-kodet `[PalettFarge]` i ett felt:
/// det er robust mot modellendringer og kompatibelt med CloudKit-synk senere
/// (alle felt har standardverdier, ingen unike begrensninger).
@Model
final class PalettDokument {
    var id: UUID = UUID()
    var navn: String = ""
    var opprettet: Date = Date.now
    var endret: Date = Date.now
    private var fargeData: Data = Data()

    init(navn: String, farger: [PalettFarge] = []) {
        self.id = UUID()
        self.navn = navn
        self.farger = farger
    }

    convenience init(_ palett: Palett) {
        self.init(navn: palett.navn, farger: palett.farger)
    }

    var farger: [PalettFarge] {
        get { (try? JSONDecoder().decode([PalettFarge].self, from: fargeData)) ?? [] }
        set {
            fargeData = (try? JSONEncoder().encode(newValue)) ?? Data()
            endret = .now
        }
    }

    var palett: Palett { Palett(id: id, navn: navn, farger: farger) }
}

/// En enkeltfarge lagret uten palett («Enkeltfarger»).
@Model
final class LagretFarge {
    var id: UUID = UUID()
    var opprettet: Date = Date.now
    private var data: Data = Data()

    init(_ farge: PalettFarge) {
        self.id = farge.id
        self.palettFarge = farge
    }

    var palettFarge: PalettFarge {
        get { (try? JSONDecoder().decode(PalettFarge.self, from: data)) ?? PalettFarge(id: id, farge: Farge(lineærR: 0, g: 0, b: 0)) }
        set { data = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}

/// Felles lagring for app og App Intents (intents kjører i appens prosess).
enum Lagring {
    static let container: ModelContainer = {
        do {
            // CloudKit må slås av eksplisitt: appen har iCloud-rettighet (for profilmappen i
            // iCloud Drive), og da forsøker SwiftData ellers å synke via CloudKit – som ikke er
            // aktivert – og krasjer ved oppstart.
            let oppsett = ModelConfiguration(cloudKitDatabase: .none)
            return try ModelContainer(for: PalettDokument.self, LagretFarge.self, configurations: oppsett)
        } catch {
            fatalError("Kunne ikke åpne palettlageret: \(error)")
        }
    }()
}
