import FargeKjerne
import SwiftUI

/// Fargeprøve som kan kopieres, dras og deles. Brukes overalt der farger vises.
struct FargeRute: View {
    let farge: Farge
    var navn: String? = nil
    var visTekst = true
    var hjørne: CGFloat = 12
    /// Rette hjørner nederst (når ruten sitter oppå et felt, som i Studio).
    var retteBunnhjørner = false
    /// Ekstra innrykk for P3-merket (store flater, som i Studio).
    var ekstraMerkeInnrykk: CGFloat = 0
    /// Vis «P3»-merket for farger utenfor sRGB.
    var visMerke = true
    /// Valgfrie handlinger i kontekstmenyen (trykk og hold / høyreklikk).
    var leggIPalett: ((Farge) -> Void)? = nil
    var fjern: (() -> Void)? = nil
    var navngi: (() -> Void)? = nil
    /// Når satt, dras fargen med navn (mellom paletter); ellers som ren farge.
    var palettFarge: PalettFarge? = nil
    /// Ekstra menypunkter (f.eks. «Flytt til …»).
    var ekstraMeny: AnyView? = nil

    var body: some View {
        if let palettFarge {
            rute.draggable(palettFarge) { FargeRute(farge: farge, visTekst: false, hjørne: 8).frame(width: 56, height: 56) }
        } else {
            rute.draggable(farge)
        }
    }

    private var form: UnevenRoundedRectangle {
        let bunn = retteBunnhjørner ? 0 : hjørne
        return UnevenRoundedRectangle(topLeadingRadius: hjørne, bottomLeadingRadius: bunn,
                                      bottomTrailingRadius: bunn, topTrailingRadius: hjørne, style: .continuous)
    }

    private var rute: some View {
        form
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
                if visMerke && !farge.erISRGB {
                    // Varseltrekant: fargen ligger utenfor sRGB og vises ulikt på vanlige skjermer.
                    // Ikon og tekst når det er plass, bare ikonet på små prøver.
                    ViewThatFits(in: .horizontal) {
                        Label("P3", systemImage: "exclamationmark.triangle.fill").labelStyle(.titleAndIcon)
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                        .font(.caption2.weight(.bold))
                        .imageScale(.small)
                        // Innrykket følger hjørneradiusen, så merket ikke klippes av det avrundede hjørnet.
                        .padding(min(hjørne * 0.3 + 4, 6) + ekstraMerkeInnrykk)
                        .foregroundStyle(farge.lesbarTekstfarge.swiftUI)
                        .accessibilityLabel("Utenfor sRGB")
                }
            }
            .contextMenu {
                if let navngi {
                    Button("Gi navn …", systemImage: "character.cursor.ibeam", action: navngi)
                }
                if let leggIPalett {
                    Button("Legg i palett …", systemImage: "plus.square.on.square") { leggIPalett(farge) }
                }
                KopierMeny(farge: farge)
                if let ekstraMeny { ekstraMeny }
                if let fjern {
                    Button("Fjern", systemImage: "trash", role: .destructive, action: fjern)
                }
            }
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
