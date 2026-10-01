import FargeKjerne
import SwiftUI

/// Kamerabildet slik det ser ut med et fargesynsavvik – åpnes fra Vurdering › Fargesyn.
/// Trykk og hold på bildet for å sammenligne med normalt syn.
struct FargesynKamera: View {
    @State var type: Fargesynstype
    @AppStorage("fargesynGrad") private var grad = 1.0
    @State private var plukker = KameraFargeplukker()
    @State private var normalt = false
    /// Venter på at et trykk skal bli et hold (sammenlign med normalt syn).
    @State private var holdOppgave: Task<Void, Never>?
    @State private var holdAvbrutt = false
    /// Sant mens fingeren/musa er nede; nullstilles også når gesten avbrytes (f.eks. av et knip).
    @GestureState private var trykker = false
    @Environment(\.dismiss) private var lukk

    var body: some View {
        NavigationStack {
            ZStack {
                kamera
                if plukker.tilgangNektet {
                    ContentUnavailableView("Ingen kameratilgang", systemImage: "camera.fill",
                                           description: Text("Gi tilgang i Innstillinger for å se omgivelsene med fargesynsfilter."))
                        .background(.regularMaterial)
                }
            }
            .ignoresSafeArea(edges: .horizontal)
            .overlay(alignment: .top) {
                Label(normalt ? String(localized: "Normalt syn") : (grad >= 1 ? type.navn : type.delvisNavn),
                      systemImage: normalt ? "eye" : "eye.fill")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(10)
                    .allowsHitTesting(false)
            }
            .safeAreaInset(edge: .bottom) { kontroller }
            .navigationTitle("Fargesyn")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Ferdig") { lukk() } }
            }
        }
        .task {
            plukker.fargesynGrad = grad
            plukker.fargesyn = type
            await plukker.start()
        }
        .onDisappear { plukker.stopp() }
        .onChange(of: type) { _, ny in if !normalt { plukker.fargesyn = ny } }
        .onChange(of: grad) { _, ny in plukker.fargesynGrad = ny }
        .onChange(of: normalt) { _, ny in plukker.fargesyn = ny ? nil : type }
        .onChange(of: trykker) { _, ny in if !ny { avsluttHold() } }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 520)
        #endif
    }

    @ViewBuilder private var kamera: some View {
        #if os(iOS)
        KameraForhåndsvisning(
            økt: plukker.økt,
            vedKnip: { skala, begynner in plukker.knip(skala, begynner: begynner) },
            vedDobbelttrykk: { plukker.settZoom(1) },
            filterlag: plukker.filterlag,
            vedOrientering: { plukker.settVisningsorientering(vinkel: $0, speilet: $1) }
        )
        .simultaneousGesture(sammenligning)
        #else
        KameraForhåndsvisning(
            økt: plukker.økt,
            filterlag: plukker.filterlag,
            vedOrientering: { plukker.settVisningsorientering(vinkel: $0, speilet: $1) }
        )
        // Forhåndsvisningen på Mac tar selv imot museklikk; et lag over bildet fanger holdet.
        .overlay { Color.clear.contentShape(Rectangle()).gesture(sammenligning) }
        #endif
    }

    /// Trykk og hold (uten å flytte fingeren) for normalt syn, slipp for å se avviket igjen.
    /// Knip og dra avbryter, så zoom ikke viser normalt syn underveis.
    private var sammenligning: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($trykker) { _, tilstand, _ in tilstand = true }
            .onChanged { g in
                if hypot(g.translation.width, g.translation.height) > 12 {
                    holdAvbrutt = true
                    holdOppgave?.cancel()
                    holdOppgave = nil
                    normalt = false
                    return
                }
                guard !holdAvbrutt, holdOppgave == nil, !normalt else { return }
                holdOppgave = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    if !Task.isCancelled, trykker { normalt = true }
                }
            }
            .onEnded { _ in avsluttHold() }
    }

    private func avsluttHold() {
        holdOppgave?.cancel()
        holdOppgave = nil
        holdAvbrutt = false
        normalt = false
    }

    private var kontroller: some View {
        VStack(spacing: 10) {
            Picker("Type", selection: $type) {
                ForEach(Fargesynstype.allCases) { Text(grad >= 1 ? $0.navn : $0.delvisNavn).tag($0) }
            }
            .pickerStyle(.menu)
            HStack(spacing: 10) {
                Text("Grad")
                Slider(value: $grad, in: 0.1...1, step: 0.1)
                Text(grad, format: .percent.precision(.fractionLength(0)))
                    .font(.callout.monospacedDigit())
                    .frame(width: 48, alignment: .trailing)
            }
            Text("Trykk og hold på bildet for å sammenligne med normalt syn.")
                .font(.footnote)
                .foregroundStyle(Color.sekundærTekst)
        }
        .padding()
        .background(.bar)
    }
}
