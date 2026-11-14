import SwiftUI
import Translation
import UniformTypeIdentifiers

struct LabView: View {
    @StateObject private var model = LabModel()
    @State private var preparation: TranslationSession.Configuration?
    @State private var exporting = false
    @State private var document = JSONReportDocument()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Laboratoire de traduction Apple").font(.headline)
                    Text("Ce prototype traduit des textes de contrôle. Il n'est pas encore relié aux vidéos.")
                    Text("Le système peut proposer de télécharger les langues. La stratégie choisie est une préférence : le modèle réellement utilisé n'est pas mesuré.")
                        .font(.footnote)
                }
                Section("Préparation") {
                    Picker("Préférence", selection: $model.strategy) {
                        Text("Qualité").tag(NativeStrategy.highFidelity)
                        Text("Rapidité").tag(NativeStrategy.lowLatency)
                    }.disabled(model.running || model.preparing)
                    Button("1. Préparer japonais → français") {
                        guard !AppleTranslator.shared.isBusy else {
                            model.status = "Le moteur termine encore le calcul précédent."
                            return
                        }
                        model.preparing = true
                        preparation = TranslationSession.Configuration(
                            source: Locale.Language(identifier: "ja"),
                            target: Locale.Language(identifier: "fr"),
                            preferredStrategy: model.strategy.appleValue
                        )
                    }.disabled(model.running || model.preparing)
                    if model.preparing { ProgressView("Préparation des langues…") }
                }
                Section("Contrôle de fidélité") {
                    Button("2. Tester les quatre cas prioritaires") {
                        Task { await model.run(all: false) }
                    }.disabled(model.running || model.preparing || model.cases.isEmpty)
                    DisclosureGroup("Contrôle plus complet") {
                        Button("Tester les 24 phrases") { Task { await model.run(all: true) } }
                            .disabled(model.running || model.preparing || model.cases.isEmpty)
                    }
                    Button("Arrêter", role: .destructive) { model.stop() }
                        .disabled(!model.running)
                    Text(model.status).accessibilityIdentifier("nativeStatus")
                    ForEach(model.results) { result in
                        VStack(alignment: .leading, spacing: 8) {
                            if let item = model.cases.first(where: { $0.id == result.id }) {
                                Text(item.ja)
                                Text("Sens attendu : " + item.referenceFR).font(.footnote)
                            }
                            Text(result.result ?? result.message ?? "Aucun texte reçu.")
                                .foregroundStyle(result.ok ? Color.primary : Color.red)
                            if let elapsed = result.elapsedMs {
                                Text(String(format: "%.2f s", elapsed / 1000)).font(.caption)
                            }
                        }.textSelection(.enabled)
                    }
                }
                Section("Rapport facultatif") {
                    Toggle("Inclure les traductions dans le rapport", isOn: $model.includeText)
                    Button("Exporter le rapport JSON") {
                        do { document = try model.document(); exporting = true }
                        catch { model.status = "Le rapport n'a pas pu être préparé." }
                    }.disabled(model.running || model.preparing || model.results.isEmpty)
                    Text("Les traductions sont exclues par défaut. Les résultats restent en mémoire jusqu'à l'export ou la fermeture de l'application.")
                        .font(.footnote)
                }
            }
            .navigationTitle("JPFR natif")
            .translationTask(preparation) { session in
                await model.prepare(using: session)
                preparation = nil
            }
            .fileExporter(isPresented: $exporting, document: document,
                          contentType: .json, defaultFilename: "phase2-apple-native") { outcome in
                if case .failure = outcome { model.status = "Export annulé ou indisponible." }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { model.stop() }
            }
        }
    }
}
