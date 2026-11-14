import Foundation
import SwiftUI
import Translation
import UniformTypeIdentifiers

struct LabCase: Codable, Identifiable {
    let id: String
    let ja: String
    let referenceFR: String
    let facts: String
}

struct LabResult: Codable, Identifiable {
    let id: String
    let ok: Bool
    let strategy: NativeStrategy
    let elapsedMs: Double?
    let errorCode: String?
    let message: String?
    let result: String?
}

struct LabReport: Codable {
    let version = "0.1.0-native"
    let provider = "AppleTranslation"
    let direction = "ja-fr"
    let deviceSystem: String
    let runtimeTarget: String
    let nativeTranslationCompleted: Bool
    let date: String
    let state: String
    let requestedStrategy: NativeStrategy
    let effectiveModelMeasured = false
    let qualityQualified = false
    let textIncluded: Bool
    let results: [LabResult]
}

struct JSONReportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@MainActor
final class LabModel: ObservableObject {
    @Published var strategy: NativeStrategy = .highFidelity
    @Published var includeText = false
    @Published var status = "Préparez d'abord les langues, puis lancez les quatre cas prioritaires."
    @Published var running = false
    @Published var preparing = false
    @Published var results: [LabResult] = []
    @Published var cases: [LabCase] = []
    @Published var state = "idle"
    private var generation = 0
    private var activeRequestID: String?
    private var runStrategy: NativeStrategy = .highFidelity

    init() {
        do {
            guard let url = Bundle.main.url(forResource: "native-cases", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            cases = try JSONDecoder().decode([LabCase].self, from: Data(contentsOf: url))
        } catch {
            status = "Le corpus de contrôle manque dans l'application. Le test est indisponible."
        }
    }

    func prepare(using session: TranslationSession) async {
        defer { preparing = false }
        do {
            try await session.prepareTranslation()
            AppleTranslator.shared.discardIdleSession()
            status = "Préparation terminée. Vous pouvez lancer les quatre cas."
        } catch {
            status = "Préparation interrompue ou langues indisponibles. Aucun résultat de qualité n'est validé."
        }
    }

    func run(all: Bool) async {
        guard !running, !preparing, !cases.isEmpty else { return }
        generation += 1
        let ticket = generation
        let selected = strategy
        runStrategy = selected
        let priorities: Set<String> = ["val-tarif", "val-lettre", "val-famille", "val-pluie"]
        let items = all ? cases : cases.filter { priorities.contains($0.id) }
        results = []
        state = "running"
        running = true
        defer { if generation == ticket { running = false } }
        for (index, item) in items.enumerated() {
            guard generation == ticket, !Task.isCancelled else { return }
            status = "Traduction \(index + 1) sur \(items.count)…"
            let id = UUID().uuidString
            activeRequestID = id
            let request = NativeRequest(version: 1, id: id, method: .translate,
                                        strategy: selected, text: item.ja, targetRequestID: nil)
            let reply = await AppleTranslator.shared.handle(request)
            guard generation == ticket, !Task.isCancelled else { return }
            activeRequestID = nil
            results.append(LabResult(id: item.id, ok: reply.ok, strategy: selected,
                                     elapsedMs: reply.elapsedMs, errorCode: reply.errorCode,
                                     message: reply.message, result: reply.text))
            if !reply.ok {
                state = "error"
                status = reply.message ?? "Le test n'a pas abouti."
                return
            }
        }
        state = "complete"
        status = "Calculs terminés. Comparez les traductions : terminer ne prouve pas leur fidélité."
    }

    func stop() {
        guard running else { return }
        generation += 1
        if let activeRequestID { AppleTranslator.shared.cancel(id: activeRequestID) }
        activeRequestID = nil
        running = false
        state = "cancelled"
        status = "Arrêt demandé. Les réponses tardives sont ignorées."
    }

    func document() throws -> JSONReportDocument {
        let rows = results.map { x in
            LabResult(id: x.id, ok: x.ok, strategy: x.strategy, elapsedMs: x.elapsedMs,
                      errorCode: x.errorCode, message: x.message, result: includeText ? x.result : nil)
        }
        #if targetEnvironment(simulator)
        let runtimeTarget = "iOS Simulator"
        #else
        let runtimeTarget = "iOS device"
        #endif
        let report = LabReport(deviceSystem: ProcessInfo.processInfo.operatingSystemVersionString,
                               runtimeTarget: runtimeTarget,
                               nativeTranslationCompleted: results.contains { $0.ok },
                               date: ISO8601DateFormatter().string(from: Date()), state: state,
                               requestedStrategy: runStrategy, textIncluded: includeText, results: rows)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return JSONReportDocument(data: try encoder.encode(report))
    }
}
