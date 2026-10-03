import FargeKI
import FargeKjerne
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Palettoversikt som kort i en rullevisning (ikke `List`): i en `List` tar raden over
/// dra-gesten, slik at enkeltfarger ikke kan dras ut av den. Her kan hver fargeprøve dras,
/// og hvert kort tar imot farger som slippes på det.
struct PalettListe: View {
    /// I palettkolonnen på Mac: «Ny palett» ligger i listen, ikke i verktøylinjen (knapper fra en
    /// lukket inspektør blir ellers hengende igjen når vinduet gjøres smalt).
    var iKolonne = false
    @Environment(\.modelContext) private var kontekst
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @Query(sort: \PalettDokument.opprettet, order: .reverse) private var paletter: [PalettDokument]
    @Query(sort: \LagretFarge.opprettet, order: .reverse) private var enkeltfarger: [LagretFarge]
    /// Navigasjonssti: oversikten fyller hele hovedvisningen (også på Mac og iPad), valgt palett åpnes over.
    @State private var sti: [Valg] = []
    @State private var målrettet: Valg?
    @State private var slettes: PalettDokument?
    @State private var omdøpes: PalettDokument?
    @State private var vurderes: PalettDokument?
    @State private var matrise: PalettDokument?
    @State private var visVerdiord = false
    @State private var visNyPalett = false
    @State private var nyPalettNavn = ""

    enum Valg: Hashable {
        case enkeltfarger
        case palett(PalettDokument)
    }

    private var nyPalettMeny: some View {
        Menu("Ny palett", systemImage: "plus") {
            Button("Ny tom palett …", systemImage: "square.dashed") {
                nyPalettNavn = ""
                visNyPalett = true
            }
            Button("Ny palett fra verdiord (KI)", systemImage: "sparkles") { visVerdiord = true }
        }
    }

    var body: some View {
        NavigationStack(path: $sti) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if !arbeidsbenk.målinger.isEmpty {
                        MidlertidigeFarger()
                            .padding(12)
                            .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.sekundærTekst.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 3])))
                    }
                    kort(.enkeltfarger) {
                        EnkeltfargerRad(farger: enkeltfarger.map(\.palettFarge), paletter: paletter, velg: velgFarge)
                    } slipp: { farger in
                        flyttTilEnkeltfarger(farger, i: kontekst)
                    }

                    GradientSeksjon()

                    HStack {
                        Text("Paletter").font(.title3.weight(.semibold))
                        Spacer()
                        if iKolonne { nyPalettMeny.labelStyle(.iconOnly).menuIndicator(.hidden).fixedSize() }
                    }
                    .padding(.top, 8)
                    if paletter.isEmpty {
                        Text("Ingen paletter ennå. Trykk + for en tom palett eller en palett fra verdiord, eller lag en fra Studio, Overgang eller Utplukk.")
                            .font(.callout)
                            .foregroundStyle(Color.sekundærTekst)
                    }
                    // Rutenett som tilpasser seg bredden: én kolonne på iPhone, flere på iPad og Mac.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12, alignment: .top)],
                              alignment: .leading, spacing: 12) {
                        ForEach(paletter) { p in
                            SveipForÅSlette(slett: { slettes = p }) {
                                kort(.palett(p)) {
                                    PalettRad(dokument: p, velg: velgFarge)
                                } slipp: { farger in
                                    flytt(farger, til: p, i: kontekst)
                                }
                                .contextMenu {
                                    Button("Vurder paletten", systemImage: "text.magnifyingglass") { vurderes = p }
                                        .disabled(p.farger.isEmpty)
                                    Button("Kontrastmatrise", systemImage: "square.grid.3x3.fill") { matrise = p }
                                        .disabled(p.farger.count < 2)
                                    Button("Skriv ut …", systemImage: "printer") { PalettUtskrift.skrivUt(p.palett) }
                                        .disabled(p.farger.isEmpty)
                                    Divider()
                                    Button("Gi nytt navn …", systemImage: "character.cursor.ibeam") { omdøpes = p }
                                    KopierTilMeny(farger: p.farger, navn: p.navn)
                                    Button("Slett palett", systemImage: "trash", role: .destructive) { slettes = p }
                                }
                            }
                        }
                    }
                    Label(Lagring.synkroniserer ? "Paletter, gradienter og enkeltfarger synkroniseres via iCloud."
                                                : "Paletter, gradienter og enkeltfarger lagres bare på denne enheten.",
                          systemImage: Lagring.synkroniserer ? "icloud" : "iphone")
                        .font(.footnote)
                        .foregroundStyle(Color.sekundærTekst)
                        .padding(.top, 8)
                    Utviklerlinje()
                }
                .padding()
            }
            .background(Color(white: 0.5).opacity(0.06))
            .navigationTitle("Paletter")
            .toolbar {
                if !iKolonne { nyPalettMeny }
            }
            .sheet(isPresented: $visVerdiord) {
                NavigationStack {
                    VerdiordVisning()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Lukk") { visVerdiord = false } }
                        }
                }
            }
            .omdøpPalett($omdøpes)
            .sheet(item: $vurderes) { PalettVurderingArk(palett: $0.palett) }
            .sheet(item: $matrise) { KontrastmatriseArk(palett: $0.palett) }
            .alert("Ny palett", isPresented: $visNyPalett) {
                TextField("Navn", text: $nyPalettNavn)
                Button("Avbryt", role: .cancel) {}
                Button("Opprett") {
                    let navn = nyPalettNavn.trimmingCharacters(in: .whitespacesAndNewlines)
                    let p = PalettDokument(navn: navn.isEmpty ? String(localized: "Ny palett") : navn)
                    kontekst.insert(p)
                    velg(.palett(p))
                }
            } message: {
                Text("Gi paletten et navn. Du kan endre det senere.")
            }
            .confirmationDialog("Slette «\(slettes?.navn ?? "")»?", isPresented: Binding(get: { slettes != nil }, set: { if !$0 { slettes = nil } }),
                                titleVisibility: .visible) {
                Button("Slett palett", role: .destructive) {
                    if let p = slettes {
                        sti.removeAll { $0 == .palett(p) }
                        kontekst.delete(p)
                    }
                }
            } message: {
                Text("Fargene i paletten slettes også. Dette kan ikke angres.")
            }
            .navigationDestination(for: Valg.self) { v in
                Group {
                    switch v {
                    case .enkeltfarger: EnkeltfargerVisning()
                    case .palett(let p): PalettDetalj(dokument: p)
                    }
                }
                .environment(\.iPalettkolonne, iKolonne)
                // Vinduets egen tilbakepil (fra kolonnens navigasjon) skjules; knappen over brukes i stedet.
                .navigationBarBackButtonHidden(iKolonne)
                // I palettkolonnen på Mac vises ingen navigasjonslinje med tilbakeknapp; lag en selv.
                .safeAreaInset(edge: .top, spacing: 0) {
                    if iKolonne {
                        HStack {
                            Button { sti.removeAll() } label: {
                                Label("Alle paletter", systemImage: "chevron.left")
                            }
                            .buttonStyle(.borderless)
                            .keyboardShortcut("[", modifiers: .command)
                            .help("Tilbake til alle paletter (⌘[)")
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.bar)
                    }
                }
            }
        }
    }

    private func velg(_ v: Valg) {
        sti = [v]
    }

    /// Trykk på en fargeprøve: fargen blir aktiv. I palettkolonnen blir du der du er; på egen
    /// Paletter-fane går appen til Studio, som når en farge velges inne i en palett.
    private func velgFarge(_ farge: Farge) {
        arbeidsbenk.aktivFarge = farge
        if !iKolonne { arbeidsbenk.valgtFane = .studio }
    }

    /// Kort som kan trykkes (åpner) og som tar imot slippede farger.
    private func kort<Innhold: View>(_ v: Valg, @ViewBuilder innhold: () -> Innhold,
                                     slipp: @escaping ([PalettFarge]) -> Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            innhold()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.tertiærTekst)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(målrettet == v ? Color.accentColor : .clear,
                              lineWidth: målrettet == v ? 3 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture { velg(v) }
        .tarImotFarger { farger in
            slipp(farger)
        } isTargeted: { over in
            målrettet = over ? v : (målrettet == v ? nil : målrettet)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { velg(v) }
    }
}

/// Dra og slipp flytter: fargen legges i målet og fjernes der den kom fra (en annen palett eller
/// Enkeltfarger). Farger uten kilde i appen (fra Studio, andre apper eller tekst) legges bare til.
@discardableResult
func flytt(_ farger: [PalettFarge], til mål: PalettDokument, i kontekst: ModelContext) -> Bool {
    let eksisterende = Set(mål.farger.map(\.id))
    let nye = farger.filter { !eksisterende.contains($0.id) }
    guard leggTil(nye, i: mål) else { return false }
    fjernFraKilder(nye, i: kontekst, unntattPalett: mål)
    return true
}

@discardableResult
func flyttTilEnkeltfarger(_ farger: [PalettFarge], i kontekst: ModelContext) -> Bool {
    let lagrede = Set(((try? kontekst.fetch(FetchDescriptor<LagretFarge>())) ?? []).map(\.id))
    let nye = farger.filter { !lagrede.contains($0.id) }
    guard !nye.isEmpty else { return false }
    lagreEnkeltfarger(nye, i: kontekst, navngi: false)
    fjernFraKilder(nye, i: kontekst, beholdEnkeltfarger: true)
    return true
}

/// Fjerner fargene (etter id) fra paletter og enkeltfarger de ligger i.
private func fjernFraKilder(_ farger: [PalettFarge], i kontekst: ModelContext,
                            unntattPalett: PalettDokument? = nil, beholdEnkeltfarger: Bool = false) {
    let ider = Set(farger.map(\.id))
    for p in (try? kontekst.fetch(FetchDescriptor<PalettDokument>())) ?? [] where p.id != unntattPalett?.id {
        if p.farger.contains(where: { ider.contains($0.id) }) {
            p.farger.removeAll { ider.contains($0.id) }
        }
    }
    if !beholdEnkeltfarger {
        for lagret in (try? kontekst.fetch(FetchDescriptor<LagretFarge>())) ?? [] where ider.contains(lagret.id) {
            kontekst.delete(lagret)
        }
    }
}

/// Lagrer farger som enkeltfarger (uten palett), med nye identiteter.
/// Lagrer farger som enkeltfarger. Én ny farge lagres med en gang og åpner så et ark for å gi den
/// navn (Avbryt beholder den uten navn), så fargen aldri går tapt om arket ikke kan vises.
func lagreEnkeltfarger(_ farger: [PalettFarge], i kontekst: ModelContext, navngi: Bool = true) {
    let nye = farger.map { LagretFarge($0.kopi) }
    for f in nye { kontekst.insert(f) }
    if navngi, nye.count == 1, let ny = nye.first, ny.palettFarge.navn.isEmpty {
        Arbeidsbenk.delt.navngiNy(ny)
    }
}

struct EnkeltfargerRad: View {
    let farger: [PalettFarge]
    let paletter: [PalettDokument]
    var velg: (Farge) -> Void = { _ in }
    @Environment(\.modelContext) private var kontekst

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Enkeltfarger", systemImage: "square.fill").font(.headline)
                Spacer()
                Text("\(farger.count)").font(.caption).foregroundStyle(Color.sekundærTekst).monospacedDigit()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(farger.prefix(60)) { pf in
                        FargeRute(farge: pf.farge, navn: pf.navn, visTekst: false, hjørne: 6,
                                  fjern: { slettEnkeltfarge(pf.id, i: kontekst) },
                                  palettFarge: pf, ekstraMeny: AnyView(FlyttMeny(farge: pf, fra: nil)))
                            .frame(width: 36, height: 36)
                            .onTapGesture { velg(pf.farge) }
                            .accessibilityAction(named: "Gjør til aktiv farge") { velg(pf.farge) }
                    }
                    if farger.isEmpty {
                        Text("Farger lagret uten palett havner her").font(.caption).foregroundStyle(Color.sekundærTekst)
                    }
                }
            }
        }
    }
}

/// Alle enkeltfarger som rutenett.
struct EnkeltfargerVisning: View {
    @Environment(\.modelContext) private var kontekst
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @Query(sort: \LagretFarge.opprettet, order: .reverse) private var lagrede: [LagretFarge]
    @State private var leggIPalett: [PalettFarge]?
    @State private var navngis: LagretFarge?
    @Environment(\.iPalettkolonne) private var iKolonne

    private let rutenett = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: rutenett, spacing: 10) {
                ForEach(lagrede) { lagret in
                    let pf = lagret.palettFarge
                    FargeRute(farge: pf.farge, navn: pf.navn,
                              leggIPalett: { _ in leggIPalett = [pf] },
                              fjern: { kontekst.delete(lagret) },
                              navngi: { navngis = lagret }, palettFarge: pf)
                        .aspectRatio(1, contentMode: .fit)
                        .onTapGesture {
                            arbeidsbenk.aktivFarge = pf.farge
                            // I palettkolonnen blir du der du er; ellers vises fargen i Studio.
                            if !iKolonne { arbeidsbenk.valgtFane = .studio }
                        }
                }
            }
            .padding()
        }
        .overlay {
            if lagrede.isEmpty {
                ContentUnavailableView("Ingen enkeltfarger", systemImage: "square.dashed",
                                       description: Text("Lagre en farge uten palett fra Studio, Utplukk eller «Legg i palett»."))
            }
        }
        .navigationTitle("Enkeltfarger")
        .tarImotFarger { farger in
            flyttTilEnkeltfarger(farger, i: kontekst)
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Lagre aktiv farge", systemImage: "plus") {
                    lagreEnkeltfarger([PalettFarge(farge: arbeidsbenk.aktivFarge)], i: kontekst)
                }
                Button("Lim inn farger", systemImage: "doc.on.clipboard") {
                    lagreEnkeltfarger(Utklippstavle.limInnListe(), i: kontekst)
                }
                Button("Legg alle i palett", systemImage: "square.and.arrow.down.on.square") {
                    leggIPalett = lagrede.map(\.palettFarge)
                }
                .disabled(lagrede.isEmpty)
            }
        }
        .sheet(isPresented: Binding(get: { leggIPalett != nil }, set: { if !$0 { leggIPalett = nil } })) {
            VelgPalettArk(farger: leggIPalett ?? [], tilbyEnkeltfarger: false)
        }
        .sheet(item: $navngis) { lagret in
            NavngiArk(farge: lagret.palettFarge) { navn in
                var pf = lagret.palettFarge
                pf.navn = navn
                lagret.palettFarge = pf
            }
        }
    }
}

/// Legger slippede farger i en palett. Farger som allerede finnes i paletten (samme id) hoppes over,
/// så et slipp tilbake på samme palett ikke lager duplikater.
@discardableResult
func leggTil(_ farger: [PalettFarge], i dokument: PalettDokument) -> Bool {
    let eksisterende = Set(dokument.farger.map(\.id))
    let nye = farger.filter { !eksisterende.contains($0.id) }.map(\.kopi)
    guard !nye.isEmpty else { return false }
    dokument.farger += nye
    return true
}

/// Rad i palettlisten: navn og små fargeprøver som kan dras til andre paletter.
struct PalettRad: View {
    let dokument: PalettDokument
    /// Trykk på en fargeprøve velger fargen (resten av kortet åpner paletten).
    var velg: (Farge) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dokument.navn.isEmpty ? String(localized: "Uten navn") : dokument.navn).font(.headline)
                Spacer()
                Text("\(dokument.farger.count)").font(.caption).foregroundStyle(Color.sekundærTekst).monospacedDigit()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(dokument.farger) { pf in
                        FargeRute(farge: pf.farge, navn: pf.navn, visTekst: false, hjørne: 6,
                                  fjern: { dokument.farger.removeAll { $0.id == pf.id } }, palettFarge: pf,
                                  ekstraMeny: AnyView(FlyttMeny(farge: pf, fra: dokument)))
                            .frame(width: 36, height: 36)
                            .onTapGesture { velg(pf.farge) }
                            .accessibilityAction(named: "Gjør til aktiv farge") { velg(pf.farge) }
                    }
                    if dokument.farger.isEmpty {
                        Text("Slipp farger her").font(.caption).foregroundStyle(Color.sekundærTekst)
                    }
                }
            }
        }
    }
}

struct PalettStripe: View {
    let farger: [Farge]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(farger.enumerated()), id: \.offset) { $1.swiftUI }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct PalettDetalj: View {
    @Bindable var dokument: PalettDokument
    @Environment(\.modelContext) private var kontekst
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    /// Filen som eksporteres (ett av eksportformatene eller PDF) – én filvelger for alle.
    @State private var eksport: (data: Data, filnavn: String)?
    @State private var visSkala: PalettFarge?
    @State private var visKontrast = false
    @State private var vurdering: PalettVurdering?
    @State private var kiArbeider = false
    @State private var kiFeil: String?
    @State private var navngisPalettfarge: PalettFarge?
    /// I palettkolonnen på Mac: handlingene ligger i en rad under tittelen, ikke i vinduets verktøylinje.
    @Environment(\.iPalettkolonne) private var iKolonne
    @State private var redigererNavn = false
    @FocusState private var navnIFokus: Bool

    private func startNavneredigering() {
        redigererNavn = true
        // Fokus etter at feltet er på plass.
        Task { @MainActor in navnIFokus = true }
    }

    private let rutenett = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    var body: some View {
        ScrollView {
            // Tittel med blyant: trykk på blyanten (eller tittelen) for å endre navnet.
            HStack(spacing: 8) {
                if redigererNavn {
                    TextField("Navn på paletten", text: $dokument.navn)
                        .textFieldStyle(.plain)
                        .focused($navnIFokus)
                        .submitLabel(.done)
                        .onSubmit { redigererNavn = false }
                } else {
                    Text(dokument.navn.isEmpty ? String(localized: "Uten navn") : dokument.navn)
                        .foregroundStyle(dokument.navn.isEmpty ? Color.sekundærTekst : Color.primary)
                        .onTapGesture { startNavneredigering() }
                }
                Button {
                    if redigererNavn { redigererNavn = false } else { startNavneredigering() }
                } label: {
                    Image(systemName: redigererNavn ? "checkmark.circle.fill" : "pencil")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help(redigererNavn ? "Ferdig" : "Endre navnet")
                .accessibilityLabel(redigererNavn ? "Ferdig med navnet" : "Endre navnet på paletten")
                Spacer(minLength: 0)
            }
            .font(.title2.weight(.semibold))
            .padding(.horizontal)
            .padding(.top, 28)
            .onChange(of: navnIFokus) { _, fokus in if !fokus { redigererNavn = false } }
            if iKolonne {
                HStack(spacing: 14) { handlinger }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .menuIndicator(.hidden)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }
            LazyVGrid(columns: rutenett, spacing: 10) {
                ForEach(dokument.farger) { pf in
                    // Fargerutens egen meny (høyreklikk / trykk og hold) har Slett; den overstyrer en ytre meny.
                    FargeRute(farge: pf.farge, navn: pf.navn,
                              fjern: { dokument.farger.removeAll { $0.id == pf.id } },
                              navngi: { navngisPalettfarge = pf }, palettFarge: pf,
                              ekstraMeny: AnyView(Group {
                                  Button("Lag toneskala", systemImage: "square.3.layers.3d") { visSkala = pf }
                                  FlyttMeny(farge: pf, fra: dokument)
                              }))
                        .aspectRatio(1, contentMode: .fit)
                        .onTapGesture {
                            arbeidsbenk.aktivFarge = pf.farge
                            // I palettkolonnen blir du der du er; ellers vises fargen i Studio.
                            if !iKolonne { arbeidsbenk.valgtFane = .studio }
                        }
                }
            }
            .padding()
        }
        // Navnet står i tittelfeltet; navigasjonslinjen viser det ikke i tillegg.
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .tarImotFarger { farger in
            flytt(farger, til: dokument, i: kontekst)
        }
        // ⌘P skriver ut denne paletten.
        .focusedSceneValue(\.palettutskrift, Palettutskrift(id: dokument.id, navn: dokument.navn) { dokument.palett })
        .toolbar {
            if !iKolonne {
                ToolbarItemGroup { handlinger }
            }
        }
        .fileExporter(
            isPresented: Binding(get: { eksport != nil }, set: { if !$0 { eksport = nil } }),
            document: eksport.map { EksportDokument(data: $0.data) },
            contentType: .data,
            defaultFilename: eksport?.filnavn ?? eksportnavn
        ) { _ in eksport = nil }
        .sheet(item: $visSkala) { pf in
            ToneskalaArk(grunnfarge: pf) { nye in dokument.farger += nye }
        }
        .sheet(isPresented: $visKontrast) { KontrastmatriseArk(palett: dokument.palett) }
        .sheet(item: $navngisPalettfarge) { pf in
            NavngiArk(farge: pf) { navn in
                var f = dokument.farger
                if let i = f.firstIndex(where: { $0.id == pf.id }) { f[i].navn = navn }
                dokument.farger = f
            }
        }
        .sheet(item: $vurdering) { VurderingArk(vurdering: $0) }
        .alert("KI", isPresented: Binding(get: { kiFeil != nil }, set: { if !$0 { kiFeil = nil } })) {
            Button("OK") {}
        } message: { Text(kiFeil ?? "") }
    }

    /// Knappene for paletten: i verktøylinjen, eller i en rad under tittelen i palettkolonnen.
    @ViewBuilder private var handlinger: some View {
        Button("Legg til aktiv farge", systemImage: "plus") {
            dokument.farger.append(PalettFarge(farge: arbeidsbenk.aktivFarge))
        }
        .help("Legg til aktiv farge")
        Button("Lim inn farger", systemImage: "doc.on.clipboard") {
            dokument.farger += Utklippstavle.limInnListe()
        }
        .help("Lim inn farger")
        Button("Kontrast", systemImage: "circle.lefthalf.filled") { visKontrast = true }
            .disabled(dokument.farger.count < 2)
            .help("Kontrastmatrise")
        Button {
            Task { await vurder() }
        } label: {
            if kiArbeider { ProgressView().controlSize(.small) } else { Label("Vurder paletten", systemImage: "text.magnifyingglass") }
        }
        .disabled(dokument.farger.isEmpty || kiArbeider)
        .help("Vurder paletten")
        Button("Skriv ut …", systemImage: "printer") { PalettUtskrift.skrivUt(dokument.palett) }
            .disabled(dokument.farger.isEmpty)
            .help("Skriv ut paletten (A4, fargeflater i CIELab)")
        Menu("Eksporter", systemImage: "square.and.arrow.up") {
            ForEach(Eksportformat.allCases) { f in
                Button(f.navn) { eksport = (f.data(for: dokument.palett), "\(eksportnavn).\(f.filendelse)") }
            }
            Button("PDF med fargeflater (A4)") { eksport = (PalettUtskrift.pdf(for: dokument.palett), "\(eksportnavn).pdf") }
                .disabled(dokument.farger.isEmpty)
            Divider()
            Button("Kopier alle som hex") { Utklippstavle.kopier(dokument.palett) }
            Button("Kopier alle som OKLCH") { Utklippstavle.kopier(dokument.palett, som: .okLCH) }
            KopierTilMeny(farger: dokument.farger, navn: dokument.navn)
        }
        .help("Eksporter og kopier")
    }

    /// Filnavn uten tegn som ikke tåles i filnavn, og aldri tomt (ellers blir filen skjult, f.eks. «.ase»).
    private var eksportnavn: String {
        let rent = dokument.navn.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return rent.isEmpty ? String(localized: "Uten navn") : rent
    }

    private func vurder() async {
        kiArbeider = true
        defer { kiArbeider = false }
        do { vurdering = try await Palettvurderer.vurder(dokument.palett) }
        catch { kiFeil = error.localizedDescription }
    }
}

/// Vurderer paletten når arket åpnes (fra palettens meny i oversikten), med fremdrift mens det pågår.
struct PalettVurderingArk: View {
    let palett: Palett
    @State private var vurdering: PalettVurdering?
    @State private var feil: String?
    @Environment(\.dismiss) private var lukk

    var body: some View {
        NavigationStack {
            Group {
                if let vurdering {
                    Form { PalettVurderingInnhold(vurdering: vurdering) }.formStyle(.grouped)
                } else if let feil {
                    ContentUnavailableView("Kunne ikke vurdere paletten", systemImage: "xmark.circle", description: Text(feil))
                } else {
                    ProgressView("Vurderer «\(palett.navn)» …").frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Vurdering")
            .toolbar { Button("Ferdig") { lukk() } }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 520)
        #endif
        .task {
            do { vurdering = try await Palettvurderer.vurder(palett) }
            catch { feil = error.localizedDescription }
        }
    }
}

struct VurderingArk: View {
    let vurdering: PalettVurdering
    @Environment(\.dismiss) private var lukk

    var body: some View {
        NavigationStack {
            Form { PalettVurderingInnhold(vurdering: vurdering) }
                .formStyle(.grouped)
                .navigationTitle("Vurdering")
                .toolbar { Button("Ferdig") { lukk() } }
        }
    }
}

extension PalettVurdering: @retroactive Identifiable {
    public var id: String { oppsummering + fakta.joined() }
}

struct EksportDokument: FileDocument {
    static let readableContentTypes: [UTType] = [.data]
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

/// Legg farger i en ny palett (med eget navn) eller i en eksisterende.
struct VelgPalettArk: View {
    let farger: [PalettFarge]
    var foreslåttNavn: String = ""
    /// Vis «Lagre uten palett» (skjules når kilden allerede er enkeltfargene).
    var tilbyEnkeltfarger = true
    @Environment(\.modelContext) private var kontekst
    @Environment(\.dismiss) private var lukk
    @Query(sort: \PalettDokument.opprettet, order: .reverse) private var paletter: [PalettDokument]
    @State private var nyttNavn = ""
    @FocusState private var navnIFokus: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PalettStripe(farger: farger.map(\.farge)).frame(height: 32)
                }
                if tilbyEnkeltfarger {
                    Section {
                        Button(farger.count == 1 ? "Lagre som enkeltfarge" : "Lagre som \(farger.count) enkeltfarger",
                               systemImage: "plus.square") {
                            lagreEnkeltfarger(farger, i: kontekst)
                            lukk()
                        }
                    } footer: { Group {
                        Text("Lagres uten palett, under «Enkeltfarger» i Paletter.")
                    }.foregroundStyle(Color.sekundærTekst) }
                }
                Seksjon("Ny palett") {
                    TextField("Navn på paletten", text: $nyttNavn)
                        .focused($navnIFokus)
                        .submitLabel(.done)
                        .onSubmit(opprett)
                    Button("Opprett og legg til", systemImage: "plus.square.fill.on.square.fill", action: opprett)
                        .disabled(nyttNavn.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if !paletter.isEmpty {
                    Seksjon("Eksisterende paletter") {
                        ForEach(paletter) { p in
                            Button {
                                p.farger += farger.map(\.kopi)
                                lukk()
                            } label: {
                                HStack {
                                    Text(p.navn.isEmpty ? String(localized: "Uten navn") : p.navn).foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(p.farger.count)").foregroundStyle(Color.sekundærTekst).monospacedDigit()
                                    PalettStripe(farger: p.farger.map(\.farge)).frame(width: 90, height: 20)
                                }
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(farger.count == 1 ? "Lagre farge" : "Lagre \(farger.count) farger")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { lukk() } } }
            .onAppear {
                nyttNavn = foreslåttNavn
                if paletter.isEmpty { navnIFokus = true }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func opprett() {
        let navn = nyttNavn.trimmingCharacters(in: .whitespaces)
        guard !navn.isEmpty else { return }
        kontekst.insert(PalettDokument(navn: navn, farger: farger.map(\.kopi)))
        lukk()
    }
}

/// Lys–mørk-skala (50…950) rundt en farge.
struct ToneskalaArk: View {
    let grunnfarge: PalettFarge
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    var leggTil: ([PalettFarge]) -> Void
    @Environment(\.dismiss) private var lukk
    @State private var antall = 11
    @State private var demping = 0.6

    private var toner: [Farge] {
        let lysheter = antall == 11 ? Toneskala.standardLysheter : Toneskala.jevn(antall: antall)
        return Toneskala(lysheter: lysheter, kromaDemping: demping, gamut: arbeidsbenk.gamut).toner(for: grunnfarge.farge).map(arbeidsbenk.begrens)
    }

    var body: some View {
        NavigationStack {
            Form {
                Stepper("Trinn: \(antall)", value: $antall, in: 3...21)
                VStack(alignment: .leading) {
                    Text("Kromademping mot ytterpunktene")
                    Slider(value: $demping, in: 0...1)
                }
                PalettStripe(farger: toner).frame(height: 64)
            }
            .formStyle(.grouped)
            .navigationTitle("Toneskala")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { lukk() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Legg til") {
                        let basis = grunnfarge.visningsnavn
                        leggTil(toner.enumerated().map { i, f in
                            PalettFarge(navn: "\(basis) \(i + 1)", farge: f, opphav: .toneskala)
                        })
                        lukk()
                    }
                }
            }
        }
    }
}

/// «Flytt til» en annen palett. Uten `fra` (enkeltfarger) vises «Legg i palett».
/// «Kopier til» er forbeholdt kopiering til andre programmer (`KopierTilMeny`).
struct FlyttMeny: View {
    let farge: PalettFarge
    let fra: PalettDokument?
    @Query(sort: \PalettDokument.opprettet, order: .reverse) private var paletter: [PalettDokument]

    var body: some View {
        let andre = paletter.filter { $0.id != fra?.id }
        if !andre.isEmpty {
            if fra == nil {
                Menu("Legg i palett", systemImage: "plus.square.on.square") {
                    ForEach(andre) { p in Button(p.navn.isEmpty ? String(localized: "Uten navn") : p.navn) { leggTil([farge], i: p) } }
                }
            }
            if let fra {
                Menu("Flytt til", systemImage: "arrow.right.square") {
                    ForEach(andre) { p in
                        Button(p.navn.isEmpty ? String(localized: "Uten navn") : p.navn) {
                            if leggTil([farge], i: p) { fra.farger.removeAll { $0.id == farge.id } }
                        }
                    }
                }
            }
        }
    }
}

/// Gi en farge navn, med fargebeskrivelse som hjelp og forslag fra KI.
struct NavngiArk: View {
    let farge: PalettFarge
    /// Tittel og avbrytknapp; for nye farger «Ny enkeltfarge» og «Hopp over».
    var tittel: LocalizedStringKey = "Gi navn"
    var avbryt: LocalizedStringKey = "Avbryt"
    var lagre: (String) -> Void
    @Environment(\.dismiss) private var lukk
    @State private var navn = ""
    @State private var foreslår = false
    @FocusState private var fokus: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        FargeRute(farge: farge.farge, visTekst: false, hjørne: 8).frame(width: 56, height: 40)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(farge.farge.hex()).font(.callout.monospaced())
                            Text(Fargebeskrivelse.beskriv(farge.farge)).font(.caption).foregroundStyle(Color.sekundærTekst)
                        }
                    }
                    TextField("Navn, f.eks. «Fjordblå»", text: $navn)
                        .focused($fokus)
                        .submitLabel(.done)
                        .onSubmit(lagreOgLukk)
                }
                Section {
                    Button {
                        Task { await foreslå() }
                    } label: {
                        if foreslår { ProgressView() } else { Label("Foreslå navn", systemImage: "sparkles") }
                    }
                    .disabled(foreslår)
                } footer: { Group {
                    Text("Forslaget lages med Apple Intelligence på enheten når det er tilgjengelig.")
                }.foregroundStyle(Color.sekundærTekst) }
            }
            .formStyle(.grouped)
            .navigationTitle(tittel)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(avbryt) { lukk() } }
                ToolbarItem(placement: .confirmationAction) { Button("Lagre", action: lagreOgLukk) }
            }
            .onAppear {
                navn = farge.navn
                fokus = true
            }
        }
        .presentationDetents([.medium])
    }

    private func lagreOgLukk() {
        lagre(navn.trimmingCharacters(in: .whitespacesAndNewlines))
        lukk()
    }

    private func foreslå() async {
        foreslår = true
        defer { foreslår = false }
        let beskrivelse = Fargebeskrivelse.beskriv(farge.farge)
        let reserve = beskrivelse.prefix(1).uppercased() + beskrivelse.dropFirst()
        navn = (try? await Fargenavngiver.navngi([farge.farge]).first) ?? reserve
    }
}

/// Omdøping av palett i en dialog med tekstfelt.
private struct OmdøpPalett: ViewModifier {
    @Binding var palett: PalettDokument?
    @State private var navn = ""

    func body(content: Content) -> some View {
        content
            .alert("Gi paletten navn", isPresented: Binding(get: { palett != nil }, set: { if !$0 { palett = nil } })) {
                TextField("Navn", text: $navn)
                Button("Avbryt", role: .cancel) {}
                Button("Lagre") {
                    let rent = navn.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let palett, !rent.isEmpty { palett.navn = rent }
                }
            }
            .onChange(of: palett) { _, ny in navn = ny?.navn ?? "" }
    }
}

extension View {
    func omdøpPalett(_ palett: Binding<PalettDokument?>) -> some View { modifier(OmdøpPalett(palett: palett)) }
}

/// «<appnavn> er utviklet av …» – appnavnet hentes fra bunten, så det følger med ved navnebytte.
struct Utviklerlinje: View {
    private var appnavn: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "Kolorist"
    }
    private var versjon: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
    }

    @State private var visMetoder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(appnavn) er utviklet av Eivind Arnstein Johansen – Institutt for design, NTNU.")
            if !versjon.isEmpty { Text("Versjon \(versjon)") }
            Button("Metoder og kilder", systemImage: "books.vertical") { visMetoder = true }
                .buttonStyle(.borderless)
                .padding(.top, 6)
        }
        .sheet(isPresented: $visMetoder) { MetoderArk() }
        .font(.footnote)
        .foregroundStyle(Color.sekundærTekst)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}

/// Sveip til venstre på et kort for å vise «Slett» (iPhone/iPad). Kortene ligger i en rullevisning,
/// ikke en `List` (der tar raden over dra-gesten for fargeprøvene), så sveipet er laget her.
/// Et langt sveip sletter direkte; slettingen bekreftes av kalleren.
struct SveipForÅSlette<Innhold: View>: View {
    var slett: () -> Void
    @ViewBuilder var innhold: Innhold

    #if os(iOS)
    @State private var åpen = false
    /// Sveipet mens fingeren er nede. Nullstilles av seg selv om gesten avbrytes (f.eks. av rulling).
    @GestureState private var drag: CGFloat = 0
    private let knappebredde: CGFloat = 88

    private var forskyvning: CGFloat { min(0, (åpen ? -knappebredde : 0) + drag) }

    private func sett(åpen nyÅpen: Bool) {
        withAnimation(.snappy(duration: 0.25)) { åpen = nyÅpen }
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if forskyvning < 0 {
                Button(role: .destructive) {
                    sett(åpen: false)
                    slett()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash").font(.title3)
                        Text("Slett").font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: max(knappebredde - 8, -forskyvning - 8))
                    .frame(maxHeight: .infinity)
                    .background(Color.feil, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            innhold
                // Når knappen vises, lukker et trykk på kortet sveipet i stedet for å åpne paletten.
                // (Før offset, så laget følger kortet og ikke dekker slett-knappen.)
                .overlay {
                    if åpen {
                        Color.clear.contentShape(Rectangle()).onTapGesture { sett(åpen: false) }
                    }
                }
                .offset(x: forskyvning)
                .animation(.snappy(duration: 0.2), value: drag == 0)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .updating($drag) { g, tilstand, _ in
                    // Bare tydelig vannrette sveip; loddrette lar rullevisningen rulle.
                    guard abs(g.translation.width) > abs(g.translation.height) * 1.5 else { return }
                    tilstand = g.translation.width
                }
                .onEnded { g in
                    guard abs(g.translation.width) > abs(g.translation.height) * 1.5 else { return }
                    let mål = (åpen ? -knappebredde : 0) + g.translation.width
                    if mål < -knappebredde * 2.5 {
                        sett(åpen: false)
                        slett()
                    } else {
                        sett(åpen: mål < -knappebredde / 2)
                    }
                }
        )
        .accessibilityAction(named: "Slett") { slett() }
    }
    #else
    // Mac: slett via høyreklikkmenyen.
    var body: some View { innhold }
    #endif
}

extension EnvironmentValues {
    /// Visningen ligger i palettkolonnen på Mac (uten egen verktøylinje).
    @Entry var iPalettkolonne = false
}

/// Sletter en enkeltfarge (lagret uten palett) ut fra id-en.
func slettEnkeltfarge(_ id: UUID, i kontekst: ModelContext) {
    for lagret in (try? kontekst.fetch(FetchDescriptor<LagretFarge>())) ?? [] where lagret.id == id {
        kontekst.delete(lagret)
    }
}
