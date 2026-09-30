import FargeKI
import FargeKjerne
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PalettListe: View {
    @Environment(\.modelContext) private var kontekst
    @Query(sort: \PalettDokument.endret, order: .reverse) private var paletter: [PalettDokument]
    @State private var valgt: PalettDokument?

    var body: some View {
        NavigationSplitView {
            List(selection: $valgt) {
                ForEach(paletter) { p in
                    NavigationLink(value: p) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(p.navn.isEmpty ? "Uten navn" : p.navn).font(.headline)
                            PalettStripe(farger: p.farger.map(\.farge)).frame(height: 24)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { indekser in indekser.map { paletter[$0] }.forEach(kontekst.delete) }
            }
            .navigationTitle("Paletter")
            .overlay {
                if paletter.isEmpty {
                    ContentUnavailableView("Ingen paletter ennå", systemImage: "swatchpalette",
                                           description: Text("Lag en fra Studio, Overgang, Kamera eller Verdiord."))
                }
            }
            .toolbar {
                Button("Ny palett", systemImage: "plus") {
                    let p = PalettDokument(navn: "Ny palett")
                    kontekst.insert(p)
                    valgt = p
                }
            }
        } detail: {
            if let valgt { PalettDetalj(dokument: valgt) } else { Text("Velg en palett").foregroundStyle(.secondary) }
        }
    }
}

struct PalettStripe: View {
    let farger: [Farge]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(farger.indices, id: \.self) { farger[$0].swiftUI }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct PalettDetalj: View {
    @Bindable var dokument: PalettDokument
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @State private var eksportformat: Eksportformat?
    @State private var visSkala: PalettFarge?
    @State private var visKontrast = false
    @State private var vurdering: PalettVurdering?
    @State private var foreslåtteNavn: [String]?
    @State private var kiArbeider = false
    @State private var kiFeil: String?

    private let rutenett = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: rutenett, spacing: 10) {
                ForEach(dokument.farger) { pf in
                    FargeRute(farge: pf.farge, navn: pf.navn)
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
        .dropDestination(for: Farge.self) { farger, _ in
            dokument.farger += farger.map { PalettFarge(farge: $0) }
            return true
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Legg til aktiv farge", systemImage: "plus") {
                    dokument.farger.append(PalettFarge(farge: arbeidsbenk.aktivFarge))
                }
                Button("Lim inn farger", systemImage: "doc.on.clipboard") {
                    dokument.farger += Utklippstavle.limInnListe()
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
                                p.farger += farger
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
            .navigationTitle(farger.count == 1 ? "Legg farge i palett" : "Legg \(farger.count) farger i palett")
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
        kontekst.insert(PalettDokument(navn: navn, farger: farger))
        lukk()
    }
}

/// Lys–mørk-skala (50…950) rundt en farge.
struct ToneskalaArk: View {
    let grunnfarge: PalettFarge
    var leggTil: ([PalettFarge]) -> Void
    @Environment(\.dismiss) private var lukk
    @State private var antall = 11
    @State private var demping = 0.6

    private var toner: [Farge] {
        let lysheter = antall == 11 ? Toneskala.standardLysheter : Toneskala.jevn(antall: antall)
        return Toneskala(lysheter: lysheter, kromaDemping: demping).toner(for: grunnfarge.farge)
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
