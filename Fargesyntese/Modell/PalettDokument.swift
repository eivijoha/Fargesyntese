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

/// Felles lagring for app og App Intents (intents kjører i appens prosess).
enum Lagring {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: PalettDokument.self)
        } catch {
            fatalError("Kunne ikke åpne palettlageret: \(error)")
        }
    }()
}
