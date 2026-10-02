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
    var lagre: ((Farge) -> Void)? = nil
    var leggIPalett: ((Farge) -> Void)? = nil
    var fjern: (() -> Void)? = nil
    var navngi: (() -> Void)? = nil
    /// Når satt, dras fargen med navn (mellom paletter); ellers som ren farge.
    var palettFarge: PalettFarge? = nil
    /// Ekstra menypunkter (f.eks. «Flytt til …»).
    var ekstraMeny: AnyView? = nil

    /// Valgene vises i en boble ved prøven (trykk og hold) i stedet for som kontekstmeny.
    /// Brukes i lister/skjemaer: der gjelder iOS' kontekstmeny hele raden, så menyen og
    /// forhåndsvisningen kan høre til feil prøve når flere står på samme rad.
    var valgBoble = false
    @State private var visValg = false

    var body: some View {
        #if os(macOS)
        // På Mac kan alle prøver dras (til paletter, fargebrønner og andre apper), og valgene ligger i
        // høyreklikkmenyen – der gjelder menyen bare prøven, ikke hele raden som på iOS.
        let boble = false
        #else
        let boble = valgBoble
        #endif
        if boble {
            rute
                .onLongPressGesture(minimumDuration: 0.35) { visValg = true }
                .sensoryFeedback(.impact(weight: .medium), trigger: visValg) { _, ny in ny }
                .popover(isPresented: $visValg, arrowEdge: .bottom) {
                    FargeValgBoble(farge: farge, lagre: lagre, leggIPalett: leggIPalett) { visValg = false }
                        .presentationCompactAdaptation(.popover)
                }
                .accessibilityAction(named: "Valg for fargen") { visValg = true }
        } else {
            #if os(macOS)
            medMeny.onDrag { dragLeverandør(farge: farge, palettFarge: palettFarge) } preview: {
                FargeRute(farge: farge, visTekst: false, hjørne: 8).frame(width: 56, height: 56)
            }
            #else
            if let palettFarge {
                medMeny.draggable(palettFarge) { FargeRute(farge: farge, visTekst: false, hjørne: 8).frame(width: 56, height: 56) }
            } else {
                medMeny.draggable(farge)
            }
            #endif
        }
    }

    private var medMeny: some View {
        rute
            .contextMenu {
                if let navngi {
                    Button("Gi navn …", systemImage: "character.cursor.ibeam", action: navngi)
                }
                if let lagre {
                    Button("Lagre som enkeltfarge", systemImage: "plus.square") { lagre(farge) }
                }
                if let leggIPalett {
                    Button("Legg i palett …", systemImage: "plus.square.on.square") { leggIPalett(farge) }
                }
                KopierMeny(farge: farge)
                KopierTilMeny(farger: [palettFarge ?? PalettFarge(navn: navn ?? "", farge: farge)], navn: navn ?? "")
                if let ekstraMeny { ekstraMeny }
                if let fjern {
                    Button("Fjern", systemImage: "trash", role: .destructive, action: fjern)
                }
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
                        if let rep = palettFarge?.representasjon {
                            Text(rep.romnavn).font(.caption2.weight(.medium)).lineLimit(1)
                            Text(rep.tekst).font(.caption2.monospaced()).lineLimit(1).minimumScaleFactor(0.6)
                        }
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

/// Valg for én fargeprøve, vist i en boble ved prøven: stor forhåndsvisning av nøyaktig
/// den trykkede fargen, og lagring/kopiering.
struct FargeValgBoble: View {
    let farge: Farge
    var lagre: ((Farge) -> Void)?
    var leggIPalett: ((Farge) -> Void)?
    var lukk: () -> Void
    @State private var lagret = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(farge.swiftUI)
                .frame(width: 220, height: 96)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(farge.hex()).font(.callout.monospaced().weight(.semibold))
                        Text(Fargemodell.okLCH.tekst(for: farge)).font(.caption2.monospaced())
                    }
                    .foregroundStyle(farge.lesbarTekstfarge.swiftUI)
                    .padding(10)
                }
            VStack(alignment: .leading, spacing: 4) {
                if let lagre {
                    Button(lagret ? "Lagret" : "Lagre som enkeltfarge", systemImage: lagret ? "checkmark.square.fill" : "plus.square") {
                        lagre(farge)
                        lagret = true
                        // Lukk før navnearket for den nye fargen vises.
                        Task { try? await Task.sleep(for: .seconds(0.4)); lukk() }
                    }
                    .disabled(lagret)
                    .sensoryFeedback(.success, trigger: lagret) { _, ny in ny }
                }
                if let leggIPalett {
                    Button("Legg i palett …", systemImage: "plus.square.on.square") {
                        lukk()
                        leggIPalett(farge)
                    }
                }
                Button("Kopier hex", systemImage: "doc.on.doc") {
                    Utklippstavle.kopier(farge)
                    lukk()
                }
            }
            .buttonStyle(.borderless)
            .labelStyle(JustertEtikett())
        }
        .padding(16)
    }
}

/// Etikett med fast ikonbredde, så teksten i en knappeliste står på linje.
private struct JustertEtikett: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            // Ikonet i aksentfarge, teksten i vanlig tekstfarge (blå tekst leses dårlig på glassbakgrunn).
            configuration.icon.frame(width: 24).foregroundStyle(.tint)
            configuration.title.foregroundStyle(.primary)
        }
        .frame(minHeight: 36)
    }
}
