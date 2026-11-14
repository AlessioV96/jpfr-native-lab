import Foundation
import SafariServices

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        guard let item = context.inputItems.first as? NSExtensionItem,
              let body = item.userInfo?[SFExtensionMessageKey],
              JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body),
              data.count <= 8192,
              let request = try? JSONDecoder().decode(NativeRequest.self, from: data) else {
            respond(.failure(id: "invalid", code: "invalid-request",
                             message: "Demande native invalide."), to: context)
            return
        }
        Task { @MainActor in
            let reply = await AppleTranslator.shared.handle(request)
            self.respond(reply, to: context)
        }
    }

    private func respond(_ reply: NativeReply, to context: NSExtensionContext) {
        guard let data = try? JSONEncoder().encode(reply),
              let body = try? JSONSerialization.jsonObject(with: data) else {
            context.cancelRequest(withError: CocoaError(.coderInvalidValue))
            return
        }
        let item = NSExtensionItem()
        item.userInfo = [SFExtensionMessageKey: body]
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }
}
