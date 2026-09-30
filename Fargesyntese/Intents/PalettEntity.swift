import AppIntents
import CoreSpotlight
import CoreTransferable
import FargeKjerne
import Foundation
import SwiftData

/// Paletter eksponert for Snarveier, Spotlight og Siri.
///
/// `IndexedEntity` gjør at paletter indekseres i Spotlight og kan refereres til
/// av Siri med personlig kontekst («lag en overgang fra Fjord-paletten …»).
/// `Transferable` gjør at Siri/Snarveier kan sende paletten videre til andre apper.
struct PalettEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Palett", numericFormat: "\(placeholder: .int) paletter")
    static let defaultQuery = PalettQuery()

    let id: UUID
    @Property(title: "Navn") var navn: String
    @Property(title: "Farger (hex)") var hexverdier: [String]

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(navn)", subtitle: "\(hexverdier.count) farger")
    }

    init(_ dokument: PalettDokument) {
        id = dokument.id
        navn = dokument.navn
        hexverdier = dokument.farger.map { $0.farge.hex() }
    }
}

extension PalettEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { $0.hexverdier.joined(separator: "\n") }
    }
}

struct PalettQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [PalettEntity] {
        try hent(#Predicate { identifiers.contains($0.id) })
    }

    @MainActor
    func entities(matching string: String) async throws -> [PalettEntity] {
        try hent(#Predicate { $0.navn.localizedStandardContains(string) })
    }

    @MainActor
    func suggestedEntities() async throws -> [PalettEntity] {
        try hent(nil)
    }

    @MainActor
    private func hent(_ predikat: Predicate<PalettDokument>?) throws -> [PalettEntity] {
        var beskrivelse = FetchDescriptor(predicate: predikat, sortBy: [SortDescriptor(\.endret, order: .reverse)])
        beskrivelse.fetchLimit = 50
        return try Lagring.container.mainContext.fetch(beskrivelse).map(PalettEntity.init)
    }
}

enum Spotlight {
    /// Kalles etter lagring slik at Siri og Spotlight ser oppdaterte paletter.
    static func indekser(_ dokumenter: [PalettDokument]) async {
        try? await CSSearchableIndex.default().indexAppEntities(dokumenter.map(PalettEntity.init))
    }
}
