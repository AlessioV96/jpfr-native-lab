import Foundation
import Translation

extension NativeStrategy {
    var appleValue: TranslationSession.Strategy {
        self == .highFidelity ? .highFidelity : .lowLatency
    }
}

// Un seul travail logique par processus. L'app et l'extension restent deux
// processus distincts ; le cache n'est pas partagé entre eux.
@MainActor
final class AppleTranslator {
    static let shared = AppleTranslator()
    private let source = Locale.Language(identifier: "ja")
    private let target = Locale.Language(identifier: "fr")
    private var cachedSession: TranslationSession?
    private var cachedStrategy: NativeStrategy?
    private var activeID: String?
    private var cancellation: String?
    var isBusy: Bool { activeID != nil }

    private func session(for strategy: NativeStrategy) -> TranslationSession {
        if cachedStrategy == strategy, let cachedSession { return cachedSession }
        let result = TranslationSession(
            installedSource: source, target: target,
            preferredStrategy: strategy.appleValue
        )
        cachedSession = result
        cachedStrategy = strategy
        return result
    }

    func discardIdleSession() {
        guard activeID == nil else { return }
        cachedSession = nil
        cachedStrategy = nil
    }

    func cancel(id: String, reason: String = "cancelled") {
        guard activeID == id else { return }
        cancellation = reason
        cachedSession?.cancel()
        cachedSession = nil
        cachedStrategy = nil
        // Garder activeID jusqu'au retour de l'appel natif : cancel() est une
        // tentative d'arrêt, pas une preuve de terminaison immédiate.
    }

    func handle(_ unchecked: NativeRequest) async -> NativeReply {
        let request: NativeRequest
        do { request = try unchecked.validated() }
        catch {
            return .failure(id: NativeRequest.validID(unchecked.id) ? unchecked.id : "invalid",
                            code: "invalid-request", message: "Demande de traduction invalide.")
        }
        if request.method == .cancel {
            guard activeID == request.targetRequestID else {
                return .failure(id: request.id, code: "no-active-job", message: "Aucun calcul correspondant.")
            }
            cancel(id: request.targetRequestID!)
            return NativeReply(id: request.id, ok: true, message: "Arrêt demandé.")
        }
        guard activeID == nil else {
            return .failure(id: request.id, code: "busy", message: "Le moteur termine déjà un calcul.")
        }
        let strategy = request.strategy!
        let translation = session(for: strategy)
        // Réserver le moteur avant le premier await : la vérification de
        // disponibilité est elle-même asynchrone et doit pouvoir être arrêtée.
        activeID = request.id
        cancellation = nil
        let start = ProcessInfo.processInfo.systemUptime
        let watchdog = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(30)) }
            catch { return }
            self?.cancel(id: request.id, reason: "timeout")
        }
        defer {
            watchdog.cancel()
            activeID = nil
            cancellation = nil
        }
        let ready = await translation.isReady
        if let cancellation {
            return .failure(id: request.id, code: cancellation,
                            message: cancellation == "timeout" ? "Vérification native trop longue." : "Vérification arrêtée.")
        }
        if request.method == .status {
            return NativeReply(id: request.id, ok: true, requestedStrategy: strategy,
                               sessionReady: ready,
                               canRequestDownloads: translation.canRequestDownloads)
        }
        guard ready else {
            cachedSession = nil
            cachedStrategy = nil
            return .failure(id: request.id, code: "needs-preparation",
                            message: "Ouvrez l'application JPFR et préparez le japonais et le français.")
        }
        do {
            let result = try await translation.translate(request.text!)
            if let cancellation {
                return .failure(id: request.id, code: cancellation,
                                message: cancellation == "timeout" ? "Le calcul natif a dépassé le délai." : "Calcul arrêté.")
            }
            guard !result.targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .failure(id: request.id, code: "empty-result", message: "Le moteur n'a renvoyé aucun texte.")
            }
            return NativeReply(id: request.id, ok: true, requestedStrategy: strategy,
                               text: result.targetText,
                               elapsedMs: (ProcessInfo.processInfo.systemUptime - start) * 1000,
                               sessionReady: ready,
                               canRequestDownloads: translation.canRequestDownloads)
        } catch {
            let code = cancellation ?? "native-failure"
            return .failure(id: request.id, code: code,
                            message: code == "timeout" ? "Délai natif dépassé." :
                                code == "cancelled" ? "Calcul arrêté." :
                                "Apple n'a pas terminé la traduction. Vérifiez la préparation des langues dans l'application.")
        }
    }
}
