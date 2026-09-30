import FargeKI
import FargeKjerne
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Palettoversikt som kort i en rullevisning (ikke `List`): i en `List` tar raden over
/// dra-gesten, slik at enkeltfarger ikke kan dras ut av den. Her kan hver fargeprøve dras,
/// og hvert kort tar imot farger som slippes på det.
struct PalettListe: View {
    @Environment(\.modelContext) private var kontekst
    @Query(sort: \PalettDokument.endret, order: .reverse) private var paletter: [PalettDokument]
    @Query(sort: \LagretFarge.opprettet, order: .reverse) private var enkeltfarger: [LagretFarge]
    /// Navigasjonssti: oversikten fyller hele hovedvisningen (også på Mac og iPad), valgt palett åpnes over.
    @State private var sti: [Valg] = []
    @State private var målrettet: Valg?
    @State private var slettes: PalettDokument?
    @State private var omdøpes: PalettDokument?
    @State private var visVerdiord = false

    enum Valg: Hashable {
        case enkeltfarger
        case palett(PalettDokument)
    }

    var body: some View {
        NavigationStack(path: $sti) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    kort(.enkeltfarger) {
                        EnkeltfargerRad(farger: enkeltfarger.map(\.palettFarge), paletter: paletter)
                    } slipp: { farger in
                        flyttTilEnkeltfarger(farger, i: kontekst)
                    }

                    Text("Paletter").font(.title3.weight(.semibold)).padding(.top, 8)
                    if paletter.isEmpty {
                        Text("Ingen paletter ennå. Trykk + for en tom palett eller en palett fra verdiord, eller lag en fra Studio, Overgang eller Utplukk.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    // Rutenett som tilpasser seg bredden: én kolonne på iPhone, flere på iPad og Mac.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12, alignment: .top)],
                              alignment: .leading, spacing: 12) {
                        ForEach(paletter) { p in
                            kort(.palett(p)) {
                                PalettRad(dokument: p)
                            } slipp: { farger in
                                flytt(farger, til: p, i: kontekst)
                            }
                            .contextMenu {
                                Button("Gi nytt navn …", systemImage: "character.cursor.ibeam") { omdøpes = p }
                                Button("Slett palett", systemImage: "trash", role: .destructive) { slettes = p }
                            }
                        }
                    }
                    Label(Lagring.synkroniserer ? "Paletter og enkeltfarger synkroniseres via iCloud."
                                                : "Paletter og enkeltfarger lagres bare på denne enheten.",
                          systemImage: Lagring.synkroniserer ? "icloud" : "iphone")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding()
            }
            .background(Color(white: 0.5).opacity(0.06))
            .navigationTitle("Paletter")
            .toolbar {
                Menu("Ny palett", systemImage: "plus") {
                    Button("Ny tom palett", systemImage: "square.dashed") {
                        let p = PalettDokument(navn: "Ny palett")
                        kontekst.insert(p)
                        velg(.palett(p))
                    }
                    Button("Ny palett fra verdiord (KI)", systemImage: "sparkles") { visVerdiord = true }
                }
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
                switch v {
                case .enkeltfarger: EnkeltfargerVisning()
                case .palett(let p): PalettDetalj(dokument: p)
                }
            }
        }
    }

    private func velg(_ v: Valg) {
        sti = [v]
    }

    /// Kort som kan trykkes (åpner) og som tar imot slippede farger.
    private func kort<Innhold: View>(_ v: Valg, @ViewBuilder innhold: () -> Innhold,
                                     slipp: @escaping ([PalettFarge]) -> Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            innhold()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
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
        .dropDestination(for: PalettFarge.self) { farger, _ in
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
    lagreEnkeltfarger(nye, i: kontekst)
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
func lagreEnkeltfarger(_ farger: [PalettFarge], i kontekst: ModelContext) {
    for f in farger { kontekst.insert(LagretFarge(f.kopi)) }
}

struct EnkeltfargerRad: View {
    let farger: [PalettFarge]
    let paletter: [PalettDokument]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Enkeltfarger", systemImage: "bookmark.fill").font(.headline)
                Spacer()
                Text("\(farger.count)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(farger.prefix(60)) { pf in
                        FargeRute(farge: pf.farge, navn: pf.navn, visTekst: false, hjørne: 6,
                                  palettFarge: pf, ekstraMeny: AnyView(FlyttMeny(farge: pf, fra: nil)))
                            .frame(width: 36, height: 36)
                    }
                    if farger.isEmpty {
                        Text("Farger lagret uten palett havner her").font(.caption).foregroundStyle(.secondary)
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
                            arbeidsbenk.valgtFane = .studio
                        }
                }
            }
            .padding()
        }
        .overlay {
            if lagrede.isEmpty {
                ContentUnavailableView("Ingen enkeltfarger", systemImage: "bookmark",
                                       description: Text("Lagre en farge uten palett fra Studio, Utplukk eller «Legg i palett»."))
            }
        }
        .navigationTitle("Enkeltfarger")
        .dropDestination(for: PalettFarge.self) { farger, _ in
            flyttTilEnkeltfarger(farger, i: kontekst)
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Lagre aktiv farge", systemImage: "bookmark") {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dokument.navn.isEmpty ? "Uten navn" : dokument.navn).font(.headline)
                Spacer()
                Text("\(dokument.farger.count)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(dokument.farger) { pf in
                        FargeRute(farge: pf.farge, navn: pf.navn, visTekst: false, hjørne: 6, palettFarge: pf,
                                  ekstraMeny: AnyView(FlyttMeny(farge: pf, fra: dokument)))
                            .frame(width: 36, height: 36)
                    }
                    if dokument.farger.isEmpty {
                        Text("Slipp farger her").font(.caption).foregroundStyle(.secondary)
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
    @State private var eksportformat: Eksportformat?
    @State private var visSkala: PalettFarge?
    @State private var visKontrast = false
    @State private var vurdering: PalettVurdering?
    @State private var foreslåtteNavn: [String]?
    @State private var kiArbeider = false
    @State private var kiFeil: String?
    @State private var navngisPalettfarge: PalettFarge?
    @State private var omdøpes: PalettDokument?

    private let rutenett = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: rutenett, spacing: 10) {
                ForEach(dokument.farger) { pf in
                    FargeRute(farge: pf.farge, navn: pf.navn,
                              navngi: { navngisPalettfarge = pf }, palettFarge: pf,
                              ekstraMeny: AnyView(FlyttMeny(farge: pf, fra: dokument)))
                        .aspectRatio(1, contentMode: .fit)
                        .onTapGesture {
                            arbeidsbenk.aktivFarge = pf.farge
                            arbeidsbenk.valgtFane = .studio
                        }
                        .contextMenu {
                            KopierMeny(farge: pf.farge)
                            Button("Lag toneskala", systemImage: "square.3.layers.3d") { visSkala = pf }
                            Button("Fjern", systemImage: "trash", role: .destructive) {
                                dokument.farger.removeAll { $0.id == pf.id }
                            }
                        }
                }
            }
            .padding()
        }
        .navigationTitle($dokument.navn)
        .dropDestination(for: PalettFarge.self) { farger, _ in
            flytt(farger, til: dokument, i: kontekst)
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Legg til aktiv farge", systemImage: "plus") {
                    dokument.farger.append(PalettFarge(farge: arbeidsbenk.aktivFarge))
                }
                Button("Lim inn farger", systemImage: "doc.on.clipboard") {
                    dokument.farger += Utklippstavle.limInnListe()
                }
                if dokument.farger.contains(where: { !$0.farge.erISRGB }) {
                    Button("Tilpass til sRGB", systemImage: "square.dashed.inset.filled") {
                        var f = dokument.farger
                        for i in f.indices { f[i].farge = f[i].farge.gamutKartlagt(til: .sRGB) }
                        dokument.farger = f
                    }
                    .help("Gamut-kartlegg farger utenfor sRGB (bevarer lyshet og kulør)")
                }
                Button("Kontrast", systemImage: "circle.lefthalf.filled") { visKontrast = true }
                    .disabled(dokument.farger.count < 2)
                Menu {
                    Button("Gi fargene navn", systemImage: "character.cursor.ibeam") { Task { await navngi() } }
                    Button("Vurder paletten", systemImage: "text.magnifyingglass") { Task { await vurder() } }
                } label: {
                    if kiArbeider { ProgressView() } else { Label("KI", systemImage: "sparkles") }
                }
                .disabled(dokument.farger.isEmpty || kiArbeider)
                Button("Gi nytt navn", systemImage: "character.cursor.ibeam") { omdøpes = dokument }
                Menu("Eksporter", systemImage: "square.and.arrow.up") {
                    ForEach(Eksportformat.allCases) { f in
                        Button(f.navn) { eksportformat = f }
                    }
                    Divider()
                    Button("Kopier alle som hex") { Utklippstavle.kopier(dokument.palett) }
                    Button("Kopier alle som OKLCH") { Utklippstavle.kopier(dokument.palett, som: .okLCH) }
                    Button("Kopier som SVG (lim inn i Figma/Illustrator)") { Utklippstavle.kopierSVG(dokument.palett) }
                }
            }
        }
        .fileExporter(
            isPresented: Binding(get: { eksportformat != nil }, set: { if !$0 { eksportformat = nil } }),
            document: eksportformat.map { EksportDokument(data: $0.data(for: dokument.palett)) },
            contentType: .data,
            defaultFilename: "\(dokument.navn).\(eksportformat?.filendelse ?? "")"
        ) { _ in eksportformat = nil }
        .sheet(item: $visSkala) { pf in
            ToneskalaArk(grunnfarge: pf) { nye in dokument.farger += nye }
        }
        .sheet(isPresented: $visKontrast) { KontrastmatriseArk(palett: dokument.palett) }
        .omdøpPalett($omdøpes)
        .sheet(item: $navngisPalettfarge) { pf in
            NavngiArk(farge: pf) { navn in
                var f = dokument.farger
                if let i = f.firstIndex(where: { $0.id == pf.id }) { f[i].navn = navn }
                dokument.farger = f
            }
        }
        .sheet(item: $vurdering) { VurderingArk(vurdering: $0) }
        .confirmationDialog("Bruke foreslåtte navn?", isPresented: Binding(get: { foreslåtteNavn != nil }, set: { if !$0 { foreslåtteNavn = nil } }),
                            titleVisibility: .visible) {
            Button("Bruk navnene") {
                if let navn = foreslåtteNavn {
                    var f = dokument.farger
                    for i in f.indices where i < navn.count { f[i].navn = navn[i] }
                    dokument.farger = f
                }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text(foreslåtteNavn?.joined(separator: " · ") ?? "")
        }
        .alert("KI", isPresented: Binding(get: { kiFeil != nil }, set: { if !$0 { kiFeil = nil } })) {
            Button("OK") {}
        } message: { Text(kiFeil ?? "") }
    }

    private func navngi() async {
        kiArbeider = true
        defer { kiArbeider = false }
        do { foreslåtteNavn = try await Fargenavngiver.navngi(dokument.farger.map(\.farge), tema: dokument.navn) }
        catch { kiFeil = error.localizedDescription }
    }

    private func vurder() async {
        kiArbeider = true
        defer { kiArbeider = false }
        do { vurdering = try await Palettvurderer.vurder(dokument.palett) }
        catch { kiFeil = error.localizedDescription }
    }
}

struct VurderingArk: View {
    let vurdering: PalettVurdering
    @Environment(\.dismiss) private var lukk

    var body: some View {
        NavigationStack {
            List {
                Section { Text(vurdering.oppsummering) }
                punktliste("Styrker", vurdering.styrker, symbol: "plus.circle.fill", farge: .green)
                punktliste("Svakheter", vurdering.svakheter, symbol: "exclamationmark.triangle.fill", farge: .orange)
                punktliste("Forslag", vurdering.forslag, symbol: "arrow.right.circle.fill", farge: .blue)
                Section {
                    DisclosureGroup("Fakta vurderingen bygger på") {
                        ForEach(vurdering.fakta, id: \.self) { Text($0).font(.callout) }
                    }
                } footer: {
                    Text(vurdering.kilde == .appleIntelligence
                         ? "Laget med Apple Intelligence på enheten. Kontrasttallene er beregnet eksakt."
                         : "Regelbasert vurdering.")
                }
            }
            .navigationTitle("Vurdering")
            .toolbar { Button("Ferdig") { lukk() } }
        }
    }

    @ViewBuilder
    private func punktliste(_ tittel: String, _ punkter: [String], symbol: String, farge: Color) -> some View {
        if !punkter.isEmpty {
            Section(tittel) {
                ForEach(punkter, id: \.self) { p in
                    Label { Text(p) } icon: { Image(systemName: symbol).foregroundStyle(farge) }
                }
            }
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
    @Query(sort: \PalettDokument.endret, order: .reverse) private var paletter: [PalettDokument]
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
                               systemImage: "bookmark") {
                            lagreEnkeltfarger(farger, i: kontekst)
                            lukk()
                        }
                    } footer: {
                        Text("Lagres uten palett, under «Enkeltfarger» i Paletter.")
                    }
                }
                Section("Ny palett") {
                    TextField("Navn på paletten", text: $nyttNavn)
                        .focused($navnIFokus)
                        .submitLabel(.done)
                        .onSubmit(opprett)
                    Button("Opprett og legg til", systemImage: "plus.square.fill.on.square.fill", action: opprett)
                        .disabled(nyttNavn.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if !paletter.isEmpty {
                    Section("Eksisterende paletter") {
                        ForEach(paletter) { p in
                            Button {
                                p.farger += farger.map(\.kopi)
                                lukk()
                            } label: {
                                HStack {
                                    Text(p.navn.isEmpty ? "Uten navn" : p.navn).foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(p.farger.count)").foregroundStyle(.secondary).monospacedDigit()
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
        return Toneskala(lysheter: lysheter, kromaDemping: demping, gamut: arbeidsbenk.gamut).toner(for: grunnfarge.farge)
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

/// «Kopier til» / «Flytt til» en annen palett. Uten `fra` (enkeltfarger) vises «Legg i palett».
struct FlyttMeny: View {
    let farge: PalettFarge
    let fra: PalettDokument?
    @Query(sort: \PalettDokument.endret, order: .reverse) private var paletter: [PalettDokument]

    var body: some View {
        let andre = paletter.filter { $0.id != fra?.id }
        if !andre.isEmpty {
            Menu(fra == nil ? "Legg i palett" : "Kopier til", systemImage: fra == nil ? "plus.square.on.square" : "doc.on.doc") {
                ForEach(andre) { p in Button(p.navn.isEmpty ? "Uten navn" : p.navn) { leggTil([farge], i: p) } }
            }
            if let fra {
                Menu("Flytt til", systemImage: "arrow.right.square") {
                    ForEach(andre) { p in
                        Button(p.navn.isEmpty ? "Uten navn" : p.navn) {
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
                            Text(Fargebeskrivelse.beskriv(farge.farge)).font(.caption).foregroundStyle(.secondary)
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
                } footer: {
                    Text("Forslaget lages med Apple Intelligence på enheten når det er tilgjengelig.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Gi navn")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { lukk() } }
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
