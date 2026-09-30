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
                Menu("Eksporter", systemImage: "square.and.arrow.up") {
                    ForEach(Eksportformat.allCases) { f in
                        Button(f.navn) { eksportformat = f }
                    }
                    Divider()
                    Button("Kopier alle som hex") { Utklippstavle.kopier(dokument.palett) }
                    Button("Kopier alle som OKLCH") { Utklippstavle.kopier(dokument.palett, som: .okLCH) }
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
    }
}

struct EksportDokument: FileDocument {
    static let readableContentTypes: [UTType] = [.data]
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

/// Velg (eller opprett) palett å legge farger i.
struct VelgPalettArk: View {
    let farger: [PalettFarge]
    @Environment(\.modelContext) private var kontekst
    @Environment(\.dismiss) private var lukk
    @Query(sort: \PalettDokument.endret, order: .reverse) private var paletter: [PalettDokument]

    var body: some View {
        NavigationStack {
            List {
                Button("Ny palett", systemImage: "plus") {
                    kontekst.insert(PalettDokument(navn: "Ny palett", farger: farger))
                    lukk()
                }
                ForEach(paletter) { p in
                    Button {
                        p.farger += farger
                        lukk()
                    } label: {
                        HStack {
                            Text(p.navn)
                            Spacer()
                            PalettStripe(farger: p.farger.map(\.farge)).frame(width: 100, height: 20)
                        }
                    }
                }
            }
            .navigationTitle("Legg i palett")
            .toolbar { Button("Avbryt") { lukk() } }
        }
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
