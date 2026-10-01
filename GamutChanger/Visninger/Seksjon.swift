import SwiftUI

/// `Section` med overskrift i sekundærtekstfargen som oppfyller WCAG AA (systemets grå
/// seksjonsoverskrifter er ca. 3,4:1 i lys modus).
struct Seksjon<Innhold: View>: View {
    private let tittel: Text
    private let innhold: Innhold

    init(_ tittel: LocalizedStringKey, @ViewBuilder innhold: () -> Innhold) {
        self.tittel = Text(tittel)
        self.innhold = innhold()
    }

    /// Uttoner for kjøretidstekst; literaler går til `LocalizedStringKey`-varianten og lokaliseres.
    @_disfavoredOverload
    init<S: StringProtocol>(_ tittel: S, @ViewBuilder innhold: () -> Innhold) {
        self.tittel = Text(tittel)
        self.innhold = innhold()
    }

    var body: some View {
        Section {
            innhold
        } header: {
            tittel.foregroundStyle(Color.sekundærTekst)
        }
    }
}
