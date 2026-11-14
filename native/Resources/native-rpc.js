(function (root) {
  'use strict';
  const P = root.JPFRNativeProtocol;
  function createBridge(sendNative, options = {}) {
    const timeoutMs = options.timeoutMs ?? 35000;
    let active = null;
    function cancelNative(id) {
      const request = {version: 1, id: crypto.randomUUID(), method: 'cancel', targetRequestID: id};
      return Promise.resolve().then(() => sendNative(request)).then(reply => P.validateReply(reply, request));
    }
    async function invoke(value) {
      let request;
      try { request = P.validateRequest(value); }
      catch { return P.failure(P.validID(value?.id) ? value.id : 'invalid', 'invalid-request', 'Demande invalide.'); }
      if (request.method === 'cancel') {
        if (active?.request.id === request.targetRequestID)
          active.finish(P.failure(active.request.id, 'cancelled', 'Traduction arrêtée.'));
        return new Promise(resolve => {
          let settled = false;
          const done = result => { if (settled) return; settled = true; clearTimeout(timer); resolve(result); };
          const timer = setTimeout(() => done(P.failure(request.id, 'timeout', 'Arrêt demandé, confirmation native absente.')), Math.min(timeoutMs, 5000));
          Promise.resolve().then(() => sendNative(request)).then(reply => {
            try { done(P.validateReply(reply, request)); }
            catch { done(P.failure(request.id, 'invalid-reply', 'Confirmation native invalide.')); }
          }, () => done(P.failure(request.id, 'native-unavailable', 'La partie native ne répond pas.')));
        });
      }
      if (active) return P.failure(request.id, 'busy', 'Un calcul est déjà en cours.');
      return new Promise(resolve => {
        let settled = false;
        const job = {request, finish};
        const timer = setTimeout(() => {
          finish(P.failure(request.id, 'timeout', 'Le moteur natif ne répond pas dans le délai.'));
          void cancelNative(request.id).catch(() => {});
        }, timeoutMs);
        function finish(reply) {
          if (settled) return;
          settled = true;
          clearTimeout(timer);
          if (active === job) active = null;
          resolve(reply);
        }
        active = job;
        Promise.resolve().then(() => sendNative(request)).then(reply => {
          try { finish(P.validateReply(reply, request)); }
          catch { finish(P.failure(request.id, 'invalid-reply', 'La réponse du moteur ne correspond pas à la demande.')); }
        }, () => finish(P.failure(request.id, 'native-unavailable',
          "La partie native est indisponible. Ce test nécessite l'application et son extension installées.")));
      });
    }
    return Object.freeze({invoke});
  }
  root.JPFRNativeRPC = Object.freeze({createBridge});
})(globalThis);
