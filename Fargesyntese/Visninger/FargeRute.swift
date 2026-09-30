import FargeKjerne
import SwiftUI

/// Fargeprøve som kan kopieres, dras og deles. Brukes overalt der farger vises.
struct FargeRute: View {
    let farge: Farge
    var navn: String? = nil
    var visTekst = true
    var hjørne: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: hjørne, style: .continuous)
            .fill(farge.swiftUI)
            .overlay(alignment: .bottomLeading) {
                if visTekst {
                    VStack(alignment: .leading, spacing: 0) {
                        if let navn, !navn.isEmpty { Text(navn).font(.caption.weight(.semibold)) }
                        Text(farge.hex()).font(.caption2.monospaced())
                    }
                    .foregroundStyle(farge.lesbarTekstfarge.swiftUI)
                    .padding(8)
                }
            }
            .overlay(alignment: .topTrailing) {
                if !farge.erISRGB {
                    Text("P3")
                        .font(.caption2.weight(.bold))
                        .padding(4)
                        .foregroundStyle(farge.lesbarTekstfarge.swiftUI)
                        .accessibilityLabel("Utenfor sRGB")
                }
            }
            .draggable(farge)
            .contextMenu { KopierMeny(farge: farge) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(navn ?? farge.hex())
            .accessibilityValue(Fargemodell.okLCH.tekst(for: farge))
    }
}

/// «Kopier som …»-meny, felles for kontekstmenyer og verktøylinjer.
struct KopierMeny: View {
    let farge: Farge

    var body: some View {
        Button("Kopier hex", systemImage: "doc.on.doc") { Utklippstavle.kopier(farge) }
        Menu("Kopier som") {
            ForEach(Fargemodell.allCases) { modell in
                Button(modell.tekst(for: farge)) { Utklippstavle.kopier(farge, som: modell) }
            }
        }
        ShareLink(item: farge, preview: SharePreview(farge.hex()))
    }
}
